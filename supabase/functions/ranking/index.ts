// Region/category popularity rankings via the YouTube Data API (public data).
// Uses a pool of Data API keys (YT_DATA_API_KEYS, comma/newline separated) with
// automatic rotation on quota exhaustion — falling back to the user's OAuth
// token when no keys are configured. Modes: categories / popular / shorts /
// categoryRankings. verify_jwt = false; user resolved from the Authorization header.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_CLIENT_ID = Deno.env.get("YT_GOOGLE_CLIENT_ID")!;
const GOOGLE_CLIENT_SECRET = Deno.env.get("YT_GOOGLE_CLIENT_SECRET")!;
const API_KEYS = (Deno.env.get("YT_DATA_API_KEYS") ?? "")
  .split(/[,\n]/)
  .map((s) => s.trim())
  .filter(Boolean);
const YT = "https://www.googleapis.com/youtube/v3";
const QUOTA_REASONS = [
  "quotaExceeded",
  "dailyLimitExceeded",
  "rateLimitExceeded",
  "userRateLimitExceeded",
];

function db(path: string, init: RequestInit): Promise<Response> {
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

async function resolveUserId(authHeader: string): Promise<string | null> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey: SERVICE_ROLE },
  });
  if (!res.ok) return null;
  return (await res.json())?.id ?? null;
}

async function accessToken(refreshToken: string): Promise<string | null> {
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  if (!res.ok) return null;
  return (await res.json())?.access_token ?? null;
}

function durationSeconds(iso: string): number {
  const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!m) return 0;
  return (+(m[1] ?? 0)) * 3600 + (+(m[2] ?? 0)) * 60 + (+(m[3] ?? 0));
}

function parseItems(items: any[]): any[] {
  return items.map((v) => {
    const s = v.snippet ?? {};
    const st = v.statistics ?? {};
    const cd = v.contentDetails ?? {};
    const th = s.thumbnails ?? {};
    const secs = durationSeconds(cd.duration ?? "PT0S");
    return {
      videoId: v.id,
      title: s.title ?? "",
      channelId: s.channelId ?? "",
      channelTitle: s.channelTitle ?? "",
      categoryId: s.categoryId ?? "",
      publishedAt: s.publishedAt ?? null,
      durationSeconds: secs,
      isShort: secs > 0 && secs <= 60, // duration heuristic (no official flag)
      viewCount: +(st.viewCount ?? 0),
      likeCount: +(st.likeCount ?? 0),
      commentCount: +(st.commentCount ?? 0),
      thumbnailUrl: th.medium?.url ?? th.high?.url ?? th.default?.url ?? "",
    };
  });
}

class AllKeysExhausted extends Error {}

/// A caller returns parsed JSON or throws. In key mode it rotates keys on quota
/// errors; in OAuth mode it uses the bearer token.
type Caller = (path: string) => Promise<any>;

function keyPoolCaller(keys: string[]): Caller {
  let cursor = 0;
  const dead = new Set<number>();
  const active = (): number | null => {
    for (let n = 0; n < keys.length; n++) {
      const idx = (cursor + n) % keys.length;
      if (!dead.has(idx)) {
        cursor = idx;
        return idx;
      }
    }
    return null;
  };
  return async (path: string) => {
    while (true) {
      const idx = active();
      if (idx === null) throw new AllKeysExhausted("all_keys_exhausted");
      const sep = path.includes("?") ? "&" : "?";
      const res = await fetch(`${YT}/${path}${sep}key=${keys[idx]}`);
      if (res.ok) return await res.json();
      const txt = await res.text();
      if (res.status === 403 && QUOTA_REASONS.some((r) => txt.includes(r))) {
        dead.add(idx);
        cursor = (idx + 1) % keys.length;
        continue; // rotate to next key
      }
      throw new Error(`yt ${res.status}: ${txt.slice(0, 200)}`);
    }
  };
}

function oauthCaller(token: string): Caller {
  return async (path: string) => {
    const res = await fetch(`${YT}/${path}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) return await res.json();
    throw new Error(`yt ${res.status}: ${(await res.text()).slice(0, 200)}`);
  };
}

async function popular(
  call: Caller,
  region: string,
  categoryId: string,
  max: number,
  hl: string,
): Promise<any[]> {
  const out: any[] = [];
  let pageToken = "";
  let remaining = Math.max(1, Math.min(max, 200));
  while (remaining > 0) {
    const size = Math.min(50, remaining);
    const p = new URLSearchParams({
      part: "snippet,statistics,contentDetails",
      chart: "mostPopular",
      regionCode: region,
      maxResults: String(size),
      hl,
    });
    if (categoryId) p.set("videoCategoryId", categoryId);
    if (pageToken) p.set("pageToken", pageToken);
    const data = await call(`videos?${p}`);
    const items = data.items ?? [];
    if (items.length === 0) break;
    out.push(...parseItems(items));
    pageToken = data.nextPageToken ?? "";
    remaining -= items.length;
    if (!pageToken) break;
  }
  return out;
}

async function hydrate(call: Caller, ids: string[]): Promise<any[]> {
  const out: any[] = [];
  for (let i = 0; i < ids.length; i += 50) {
    const chunk = ids.slice(i, i + 50);
    const data = await call(
      `videos?part=snippet,statistics,contentDetails&maxResults=50&id=${chunk.join(",")}`,
    );
    out.push(...parseItems(data.items ?? []));
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const userId = await resolveUserId(req.headers.get("Authorization") ?? "");
  if (!userId) return json({ error: "unauthorized" }, 401);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }

  // Build the API caller: prefer the key pool, else fall back to OAuth.
  let call: Caller;
  if (API_KEYS.length > 0) {
    call = keyPoolCaller(API_KEYS);
  } else {
    const tokRes = await db(
      `google_tokens?user_id=eq.${userId}&select=refresh_token`,
      { method: "GET" },
    );
    const refresh = (await tokRes.json())?.[0]?.refresh_token;
    if (!refresh) {
      return json({
        error: "not_connected",
        detail: "YT_DATA_API_KEYS 시크릿을 등록하거나 YouTube를 연결하세요.",
      }, 400);
    }
    const token = await accessToken(refresh);
    if (!token) return json({ error: "token_refresh_failed" }, 400);
    call = oauthCaller(token);
  }

  const mode = String(body.mode ?? "popular");
  const region = String(body.regionCode ?? "KR");
  const hl = String(body.hl ?? "ko_KR");
  const categoryId = String(body.categoryId ?? "");
  const max = Math.max(1, Math.min(Number(body.max) || 50, 200));

  try {
    if (mode === "categories") {
      const data = await call(
        `videoCategories?part=snippet&regionCode=${region}&hl=${hl}`,
      );
      const categories = (data.items ?? [])
        .filter((i: any) => i.snippet?.assignable)
        .map((i: any) => ({ id: i.id, title: i.snippet?.title ?? "" }))
        .sort((a: any, b: any) => a.title.localeCompare(b.title, "ko"));
      return json({ categories });
    }

    if (mode === "popular") {
      return json({ videos: await popular(call, region, categoryId, max, hl) });
    }

    if (mode === "shorts") {
      const days = Math.max(1, Math.min(Number(body.days) || 7, 90));
      // Real Shorts are up to 180s; search.list?videoDuration=short returns
      // <4min, so keep <=180s (60s dropped almost everything).
      const maxDur = Math.max(15, Math.min(Number(body.maxDuration) || 180, 180));
      const publishedAfter = new Date(Date.now() - days * 86400000)
        .toISOString()
        .replace(/\.\d+Z$/, "Z");
      const ids: string[] = [];
      const seen = new Set<string>();
      let pageToken = "";
      let guard = 0;
      while (ids.length < max * 2 && guard < 6) {
        guard++;
        const p = new URLSearchParams({
          part: "id",
          type: "video",
          videoDuration: "short",
          order: "viewCount",
          regionCode: region,
          maxResults: "50",
          publishedAfter,
        });
        if (categoryId) p.set("videoCategoryId", categoryId);
        if (pageToken) p.set("pageToken", pageToken);
        const data = await call(`search?${p}`);
        for (const it of data.items ?? []) {
          const vid = it.id?.videoId;
          if (vid && !seen.has(vid)) {
            seen.add(vid);
            ids.push(vid);
          }
        }
        pageToken = data.nextPageToken ?? "";
        if (!pageToken) break;
      }
      const hydrated = await hydrate(call, ids);
      const shorts = hydrated
        .filter((v) => v.durationSeconds > 0 && v.durationSeconds <= maxDur)
        .sort((a, b) => b.viewCount - a.viewCount)
        .slice(0, max);
      return json({ videos: shorts });
    }

    if (mode === "categoryRankings") {
      const perCat = Math.max(1, Math.min(Number(body.perCategory) || 15, 50));
      const catData = await call(
        `videoCategories?part=snippet&regionCode=${region}&hl=${hl}`,
      );
      const cats = (catData.items ?? [])
        .filter((i: any) => i.snippet?.assignable)
        .map((i: any) => ({ id: i.id, name: i.snippet?.title ?? "" }));
      const rankings: any[] = [];
      for (const c of cats) {
        let vids: any[] = [];
        try {
          vids = await popular(call, region, c.id, perCat, hl);
        } catch (e) {
          if (e instanceof AllKeysExhausted) throw e;
          continue; // e.g. videoChartNotFound for this category
        }
        if (vids.length === 0) continue;
        const views = vids.map((v) => v.viewCount);
        const eng = vids.map((v) =>
          v.viewCount ? (v.likeCount + v.commentCount) / v.viewCount : 0
        );
        const top = vids.reduce((a, b) => (b.viewCount > a.viewCount ? b : a));
        rankings.push({
          categoryId: c.id,
          categoryName: c.name,
          videoCount: vids.length,
          totalViews: views.reduce((a, b) => a + b, 0),
          avgViews: Math.round(views.reduce((a, b) => a + b, 0) / vids.length),
          avgLikes: Math.round(
            vids.reduce((a, b) => a + b.likeCount, 0) / vids.length,
          ),
          avgComments: Math.round(
            vids.reduce((a, b) => a + b.commentCount, 0) / vids.length,
          ),
          avgEngagement: eng.reduce((a, b) => a + b, 0) / vids.length,
          topTitle: top.title,
          topUrl: `https://www.youtube.com/watch?v=${top.videoId}`,
        });
      }
      rankings.sort((a, b) => b.totalViews - a.totalViews);
      return json({ rankings });
    }

    return json({ error: "bad_mode" }, 400);
  } catch (e) {
    if (e instanceof AllKeysExhausted) {
      return json({
        error: "quota_exhausted",
        detail: "모든 API 키의 quota가 소진되었습니다. 내일 초기화되거나 키를 추가하세요.",
      }, 429);
    }
    return json({ error: "ranking_failed", detail: String(e) }, 500);
  }
});
