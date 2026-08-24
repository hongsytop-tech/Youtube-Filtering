// Returns a channel's most recent uploads. Input {channel, max} where channel
// is a handle (@name), channel id (UC...), or a youtube.com URL. Uses the
// user's OAuth token + the YouTube Data API. verify_jwt = false.
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

function ytGet(token: string, path: string): Promise<Response> {
  return fetch(`${YT}/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

function durationSeconds(iso: string): number {
  const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!m) return 0;
  return (+(m[1] ?? 0)) * 3600 + (+(m[2] ?? 0)) * 60 + (+(m[3] ?? 0));
}

const SHORTS_MAX_SECONDS = 240; // <4min classified as Short (matches ranking)

// Resolve the input to {channelId, uploads playlist id, title}.
async function resolveChannel(token: string, input: string): Promise<
  { id: string; uploads: string; title: string } | null
> {
  let raw = input.trim();
  let handle = "";
  let username = "";
  let channelId = "";
  let search = "";

  const uc = raw.match(/(UC[0-9A-Za-z_-]{22})/);
  if (uc) {
    channelId = uc[1];
  } else if (/\/@|^@/.test(raw)) {
    const m = raw.match(/@([^/?\s]+)/);
    if (m) handle = m[1];
  } else if (/\/user\//.test(raw)) {
    username = raw.split("/user/")[1].split(/[/?]/)[0];
  } else if (/\/c\//.test(raw)) {
    search = raw.split("/c/")[1].split(/[/?]/)[0];
  } else {
    search = raw; // bare name
  }

  const part = "part=snippet,contentDetails";
  let qs = "";
  if (channelId) qs = `channels?${part}&id=${channelId}`;
  else if (handle) qs = `channels?${part}&forHandle=@${handle}`;
  else if (username) qs = `channels?${part}&forUsername=${username}`;

  if (qs) {
    const res = await ytGet(token, qs);
    if (res.ok) {
      const item = (await res.json())?.items?.[0];
      if (item) {
        return {
          id: item.id,
          uploads: item.contentDetails?.relatedPlaylists?.uploads,
          title: item.snippet?.title ?? "",
        };
      }
    }
    // An explicit channel id that didn't resolve must NOT fall back to a name
    // search (searching the raw URL string returns an unrelated channel).
    if (channelId) return null;
    if (!search) search = handle || username || raw;
  }

  // Fallback: search for the channel by name.
  const sres = await ytGet(
    token,
    `search?part=snippet&type=channel&maxResults=1&q=${encodeURIComponent(search)}`,
  );
  if (!sres.ok) return null;
  const cid = (await sres.json())?.items?.[0]?.id?.channelId;
  if (!cid) return null;
  const cres = await ytGet(token, `channels?part=snippet,contentDetails&id=${cid}`);
  if (!cres.ok) return null;
  const item = (await cres.json())?.items?.[0];
  if (!item) return null;
  return {
    id: item.id,
    uploads: item.contentDetails?.relatedPlaylists?.uploads,
    title: item.snippet?.title ?? "",
  };
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
  const input = String(body.channel ?? "").trim();
  if (!input) return json({ error: "no_channel" }, 400);
  // Target count of videos to return (50 / 100 / 150 ...).
  const max = Math.max(1, Math.min(300, Number(body.max) || 50));

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

  const ch = await resolveChannel(token, input);
  if (!ch || !ch.uploads) {
    return json({ error: "channel_not_found", detail: "채널을 찾지 못했습니다." }, 404);
  }

  // Page through the uploads (newest first), dropping Shorts (<=60s), until we
  // have `max` regular videos or run out (bounded page count).
  const videos: unknown[] = [];
  let pageToken = "";
  let pages = 0;
  const MAX_PAGES = 8; // 8 * 50 = up to 400 uploads scanned
  while (videos.length < max && pages < MAX_PAGES) {
    pages++;
    const q = `playlistItems?part=snippet&maxResults=50&playlistId=${ch.uploads}` +
      (pageToken ? `&pageToken=${pageToken}` : "");
    const plRes = await ytGet(token, q);
    if (!plRes.ok) {
      if (videos.length === 0) {
        return json({ error: "list_failed", detail: await plRes.text() }, 500);
      }
      break;
    }
    const data = await plRes.json();
    const items = data.items ?? [];
    const ids: string[] = items
      .map((it: any) => it.snippet?.resourceId?.videoId)
      .filter(Boolean);

    // Fetch authoritative metadata for these ids. videos.list only returns
    // videos that actually exist and are viewable, so deleted / private /
    // region-blocked entries (which appear in the uploads playlist as
    // "Deleted video" / "Private video" placeholders) are naturally dropped.
    const metaById = new Map<string, any>();
    if (ids.length > 0) {
      const dRes = await ytGet(
        token,
        `videos?part=snippet,contentDetails,status&maxResults=50&id=${ids.join(",")}`,
      );
      if (dRes.ok) {
        for (const v of (await dRes.json()).items ?? []) {
          metaById.set(v.id, v);
        }
      }
    }

    // Preserve the uploads playlist order (newest first).
    for (const it of items) {
      const vid = it.snippet?.resourceId?.videoId;
      if (!vid) continue;
      const v = metaById.get(vid);
      if (!v) continue; // deleted / private / unavailable → skip
      const s = v.snippet ?? {};
      // Skip scheduled premieres / live placeholders (no real content yet).
      if (s.liveBroadcastContent && s.liveBroadcastContent !== "none") continue;
      if (v.status && v.status.uploadStatus === "rejected") continue;
      const secs = durationSeconds(v.contentDetails?.duration ?? "PT0S");
      const th = s.thumbnails ?? {};
      videos.push({
        videoId: vid,
        title: s.title ?? "",
        thumbnailUrl: th.medium?.url ?? th.high?.url ?? th.default?.url ?? "",
        publishedAt: s.publishedAt ?? null,
        channelTitle: ch.title,
        durationSeconds: secs,
        isShort: secs > 0 && secs < SHORTS_MAX_SECONDS,
      });
      if (videos.length >= max) break;
    }

    pageToken = data.nextPageToken ?? "";
    if (!pageToken) break;
  }

  // Guarantee newest-first even if the uploads playlist order is off.
  videos.sort((a: any, b: any) =>
    String(b.publishedAt ?? "").localeCompare(String(a.publishedAt ?? ""))
  );

  return json({
    channelId: ch.id,
    channelTitle: ch.title,
    videos: videos.slice(0, max),
  });
});
