// Fetches each connected user's subscription uploads from the YouTube Data API
// and writes them into feed_videos (service role).
//
// Auth (verify_jwt = false):
//   - cron: header `x-scheduler-secret: <SCHEDULER_SECRET>` → all users
//   - client: valid Supabase `Authorization` bearer → just that user
// Self-contained (no local imports) so it deploys via the dashboard editor.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-scheduler-secret",
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
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID")!;
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET")!;
const SCHEDULER_SECRET = Deno.env.get("SCHEDULER_SECRET")!;

const YT = "https://www.googleapis.com/youtube/v3";
const MAX_CHANNELS = 40; // quota guard
const UPLOADS_PER_CHANNEL = 5;

interface TokenRow {
  user_id: string;
  refresh_token: string;
}

async function db(path: string, init: RequestInit): Promise<Response> {
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

async function ytGet(
  token: string,
  path: string,
  params: Record<string, string>,
): Promise<any> {
  const qs = new URLSearchParams(params).toString();
  const res = await fetch(`${YT}/${path}?${qs}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`${path}: ${await res.text()}`);
  return res.json();
}

function chunk<T>(arr: T[], n: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

async function fetchForUser(userId: string, refreshToken: string) {
  const token = await accessToken(refreshToken);
  if (!token) throw new Error("token refresh failed");

  // 1) Subscriptions → channel ids
  const subs = await ytGet(token, "subscriptions", {
    part: "snippet",
    mine: "true",
    maxResults: "50",
    order: "unread",
  });
  const channelIds: string[] = (subs.items ?? [])
    .map((it: any) => it.snippet?.resourceId?.channelId)
    .filter(Boolean)
    .slice(0, MAX_CHANNELS);
  if (channelIds.length === 0) return 0;

  // 2) Uploads playlist id per channel
  const uploadPlaylists: string[] = [];
  for (const group of chunk(channelIds, 50)) {
    const ch = await ytGet(token, "channels", {
      part: "contentDetails",
      id: group.join(","),
      maxResults: "50",
    });
    for (const c of ch.items ?? []) {
      const pl = c.contentDetails?.relatedPlaylists?.uploads;
      if (pl) uploadPlaylists.push(pl);
    }
  }

  // 3) Recent video ids from each uploads playlist
  const videoIds = new Set<string>();
  for (const pl of uploadPlaylists) {
    try {
      const items = await ytGet(token, "playlistItems", {
        part: "contentDetails",
        playlistId: pl,
        maxResults: String(UPLOADS_PER_CHANNEL),
      });
      for (const it of items.items ?? []) {
        const vid = it.contentDetails?.videoId;
        if (vid) videoIds.add(vid);
      }
    } catch (_) {
      // skip a bad playlist, keep going
    }
  }
  if (videoIds.size === 0) return 0;

  // 4) videos.list for snippet + categoryId
  const rows: any[] = [];
  for (const group of chunk([...videoIds], 50)) {
    const vids = await ytGet(token, "videos", {
      part: "snippet",
      id: group.join(","),
      maxResults: "50",
    });
    for (const v of vids.items ?? []) {
      const s = v.snippet ?? {};
      const thumbs = s.thumbnails ?? {};
      rows.push({
        user_id: userId,
        video_id: v.id,
        title: s.title ?? "",
        channel_id: s.channelId ?? "",
        channel_title: s.channelTitle ?? "",
        thumbnail_url:
          thumbs.medium?.url ?? thumbs.high?.url ?? thumbs.default?.url ?? "",
        category_id: s.categoryId ?? "",
        published_at: s.publishedAt ?? null,
        fetched_at: new Date().toISOString(),
      });
    }
  }

  // 5) Upsert into feed_videos
  if (rows.length > 0) {
    const res = await db("feed_videos?on_conflict=user_id,video_id", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify(rows),
    });
    if (!res.ok) throw new Error(`upsert: ${await res.text()}`);
  }
  return rows.length;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const schedulerSecret = req.headers.get("x-scheduler-secret");
  const isCron = schedulerSecret && schedulerSecret === SCHEDULER_SECRET;

  let targets: TokenRow[] = [];
  try {
    if (isCron) {
      const res = await db(
        "google_tokens?connected=eq.true&select=user_id,refresh_token",
        { method: "GET" },
      );
      targets = await res.json();
    } else {
      const userId = await resolveUserId(req.headers.get("Authorization") ?? "");
      if (!userId) return json({ error: "unauthorized" }, 401);
      const res = await db(
        `google_tokens?user_id=eq.${userId}&select=user_id,refresh_token`,
        { method: "GET" },
      );
      targets = await res.json();
    }
  } catch (e) {
    return json({ error: "load_tokens_failed", detail: String(e) }, 500);
  }

  const results: Record<string, unknown> = {};
  for (const t of targets) {
    try {
      results[t.user_id] = await fetchForUser(t.user_id, t.refresh_token);
    } catch (e) {
      results[t.user_id] = `error: ${String(e)}`;
    }
  }

  return json({ processed: targets.length, results });
});
