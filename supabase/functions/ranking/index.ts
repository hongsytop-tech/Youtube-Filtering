// Region/category popularity rankings via the YouTube Data API (public charts),
// using the user's stored OAuth token. Modes:
//   categories       -> assignable video categories for a region
//   popular          -> mostPopular chart (region [+ category])
//   shorts           -> search.list videoDuration=short, sorted by views
//   categoryRankings -> aggregate mostPopular across all categories
// verify_jwt = false; user resolved from the Authorization header.
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
const YT = "https://www.googleapis.com/youtube/v3";

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

function ytGet(token: string, path: string): Promise<Response> {
  return fetch(`${YT}/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

function parseItems(items: any[]): any[] {
  return items.map((v) => {
    const s = v.snippet ?? {};
    const st = v.statistics ?? {};
    const cd = v.contentDetails ?? {};
    const th = s.thumbnails ?? {};
    return {
      videoId: v.id,
      title: s.title ?? "",
      channelId: s.channelId ?? "",
      channelTitle: s.channelTitle ?? "",
      categoryId: s.categoryId ?? "",
      publishedAt: s.publishedAt ?? null,
      durationSeconds: durationSeconds(cd.duration ?? "PT0S"),
      viewCount: +(st.viewCount ?? 0),
      likeCount: +(st.likeCount ?? 0),
      commentCount: +(st.commentCount ?? 0),
      thumbnailUrl: th.medium?.url ?? th.high?.url ?? th.default?.url ?? "",
    };
  });
}

async function popular(
  token: string,
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
    const res = await ytGet(token, `videos?${p}`);
    if (!res.ok) {
      if (out.length === 0) throw new Error(await res.text());
      break;
    }
    const data = await res.json();
    const items = data.items ?? [];
    if (items.length === 0) break;
    out.push(...parseItems(items));
    pageToken = data.nextPageToken ?? "";
    remaining -= items.length;
    if (!pageToken) break;
  }
  return out;
}

async function hydrate(token: string, ids: string[]): Promise<any[]> {
  const out: any[] = [];
  for (let i = 0; i < ids.length; i += 50) {
    const chunk = ids.slice(i, i + 50);
    const res = await ytGet(
      token,
      `videos?part=snippet,statistics,contentDetails&maxResults=50&id=${chunk.join(",")}`,
    );
    if (res.ok) out.push(...parseItems((await res.json()).items ?? []));
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

  const tokRes = await db(
    `google_tokens?user_id=eq.${userId}&select=refresh_token`,
    { method: "GET" },
  );
  const refresh = (await tokRes.json())?.[0]?.refresh_token;
  if (!refresh) {
    return json({ error: "not_connected", detail: "먼저 YouTube를 연결하세요." }, 400);
  }
  const token = await accessToken(refresh);
  if (!token) return json({ error: "token_refresh_failed" }, 400);

  const mode = String(body.mode ?? "popular");
  const region = String(body.regionCode ?? "KR");
  const hl = String(body.hl ?? "ko_KR");
  const categoryId = String(body.categoryId ?? "");
  const max = Math.max(1, Math.min(Number(body.max) || 50, 200));

  try {
    if (mode === "categories") {
      const p = new URLSearchParams({ part: "snippet", regionCode: region, hl });
      const res = await ytGet(token, `videoCategories?${p}`);
      if (!res.ok) return json({ error: "categories_failed", detail: await res.text() }, 500);
      const items = (await res.json()).items ?? [];
      const categories = items
        .filter((i: any) => i.snippet?.assignable)
        .map((i: any) => ({ id: i.id, title: i.snippet?.title ?? "" }))
        .sort((a: any, b: any) => a.title.localeCompare(b.title, "ko"));
      return json({ categories });
    }

    if (mode === "popular") {
      const videos = await popular(token, region, categoryId, max, hl);
      return json({ videos });
    }

    if (mode === "shorts") {
      const days = Math.max(1, Math.min(Number(body.days) || 7, 90));
      const maxDur = Math.max(15, Math.min(Number(body.maxDuration) || 60, 180));
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
        const res = await ytGet(token, `search?${p}`);
        if (!res.ok) {
          if (ids.length === 0) return json({ error: "search_failed", detail: await res.text() }, 500);
          break;
        }
        const data = await res.json();
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
      const hydrated = await hydrate(token, ids);
      const shorts = hydrated
        .filter((v) => v.durationSeconds > 0 && v.durationSeconds <= maxDur)
        .sort((a, b) => b.viewCount - a.viewCount)
        .slice(0, max);
      return json({ videos: shorts });
    }

    if (mode === "categoryRankings") {
      const perCat = Math.max(1, Math.min(Number(body.perCategory) || 15, 50));
      const catRes = await ytGet(
        token,
        `videoCategories?part=snippet&regionCode=${region}&hl=${hl}`,
      );
      if (!catRes.ok) return json({ error: "categories_failed" }, 500);
      const cats = ((await catRes.json()).items ?? [])
        .filter((i: any) => i.snippet?.assignable)
        .map((i: any) => ({ id: i.id, name: i.snippet?.title ?? "" }));
      const rankings: any[] = [];
      for (const c of cats) {
        let vids: any[] = [];
        try {
          vids = await popular(token, region, c.id, perCat, hl);
        } catch {
          continue;
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
    return json({ error: "ranking_failed", detail: String(e) }, 500);
  }
});
