// Keyword search → a list of videos (like searching on youtube.com), so the
// user can multi-select and copy links. Uses a pool of Data API keys
// (YT_DATA_API_KEYS, comma/newline separated) with automatic rotation on quota
// exhaustion — falling back to the user's OAuth token when no keys are set.
// search.list costs 100 quota units/page, so the key pool is preferred.
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
const SHORTS_MAX_SECONDS = 240; // <4min classified as Short (matches ranking)

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

class AllKeysExhausted extends Error {}

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

// Hydrate ids → full video metadata (snippet + duration). videos.list only
// returns existing/viewable videos, so unavailable ones are dropped.
async function hydrate(call: Caller, ids: string[]): Promise<Map<string, any>> {
  const out = new Map<string, any>();
  for (let i = 0; i < ids.length; i += 50) {
    const chunk = ids.slice(i, i + 50);
    const data = await call(
      `videos?part=snippet,contentDetails&maxResults=50&id=${chunk.join(",")}`,
    );
    for (const v of data.items ?? []) {
      const s = v.snippet ?? {};
      const th = s.thumbnails ?? {};
      const secs = durationSeconds(v.contentDetails?.duration ?? "PT0S");
      out.set(v.id, {
        videoId: v.id,
        title: s.title ?? "",
        channelTitle: s.channelTitle ?? "",
        thumbnailUrl: th.medium?.url ?? th.high?.url ?? th.default?.url ?? "",
        publishedAt: s.publishedAt ?? null,
        durationSeconds: secs,
        isShort: secs > 0 && secs < SHORTS_MAX_SECONDS,
      });
    }
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
  const q = String(body.q ?? body.query ?? "").trim();
  if (!q) return json({ error: "no_query" }, 400);
  const max = Math.max(1, Math.min(200, Number(body.max) || 50));
  const order = String(body.order ?? "relevance"); // relevance|date|viewCount|rating
  const regionCode = String(body.regionCode ?? "KR");
  // Only videos that have captions (closed captions). Note: reflects YouTube's
  // caption index (uploaded + auto-generated), so it's a best-effort filter.
  const captionsOnly = body.caption === true ||
    body.videoCaption === "closedCaption";

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

  try {
    // 1) search.list → ordered video ids (relevance = like youtube.com search).
    const ids: string[] = [];
    const seen = new Set<string>();
    let pageToken = "";
    let guard = 0;
    while (ids.length < max && guard < 5) {
      guard++;
      const p = new URLSearchParams({
        part: "id",
        type: "video",
        q,
        order,
        regionCode,
        relevanceLanguage: "ko",
        maxResults: "50",
      });
      if (captionsOnly) p.set("videoCaption", "closedCaption");
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

    if (ids.length === 0) return json({ videos: [] });

    // 2) hydrate, preserving search (relevance) order.
    const meta = await hydrate(call, ids);
    const videos = ids
      .map((id) => meta.get(id))
      .filter(Boolean)
      .slice(0, max);

    return json({ query: q, videos });
  } catch (e) {
    if (e instanceof AllKeysExhausted) {
      return json({
        error: "quota_exhausted",
        detail: "모든 API 키의 quota가 소진되었습니다. 내일 초기화되거나 키를 추가하세요.",
      }, 429);
    }
    return json({ error: "search_failed", detail: String(e) }, 500);
  }
});
