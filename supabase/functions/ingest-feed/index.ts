// Receives {videos:[{id, short}]} scraped from the YouTube home feed by the
// browser extension, enriches each via the YouTube Data API (using the user's
// stored OAuth token), marks Shorts (<= 60s or shorts-sourced), and upserts
// ALL into feed_videos so the app can include/exclude Shorts via a toggle.
// verify_jwt = false; the user is resolved manually from the Authorization header.
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
const SHORTS_MAX_SECONDS = 60; // <=60s is always treated as a Short
const SHORTS_PROBE_MAX = 180; // 61–180s: confirm via the /shorts/ URL
const PROBE_CONCURRENCY = 8;

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

function chunk<T>(arr: T[], n: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

function durationSeconds(iso: string): number {
  const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!m) return 0;
  return (+(m[1] ?? 0)) * 3600 + (+(m[2] ?? 0)) * 60 + (+(m[3] ?? 0));
}

// A video is a Short iff youtube.com/shorts/<id> resolves (200) instead of
// redirecting to /watch. The most reliable Shorts signal (Shorts can be up
// to 3 minutes, so duration alone is not enough).
async function isShortByUrl(id: string): Promise<boolean> {
  try {
    const res = await fetch(`https://www.youtube.com/shorts/${id}`, {
      method: "HEAD",
      redirect: "manual",
    });
    // 200 => Short; 3xx (redirect to watch) => regular video
    return res.status === 200;
  } catch {
    return false;
  }
}

async function probeShorts(ids: string[]): Promise<Set<string>> {
  const out = new Set<string>();
  for (let i = 0; i < ids.length; i += PROBE_CONCURRENCY) {
    const batch = ids.slice(i, i + PROBE_CONCURRENCY);
    const results = await Promise.all(batch.map((id) => isShortByUrl(id)));
    batch.forEach((id, j) => {
      if (results[j]) out.add(id);
    });
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

  // Reclassify mode: (1) backfill missing durations via the YouTube API so the
  // <=60s rule catches Shorts, then (2) confirm 61–180s rows via /shorts/.
  if (body.reclassify) {
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

    try {
      // 1) rows missing duration → fetch it
      const nullRes = await db(
        `feed_videos?user_id=eq.${userId}&duration_seconds=is.null&select=video_id`,
        { method: "GET" },
      );
      const nullIds: string[] = (await nullRes.json()).map((r: any) => r.video_id);
      const durById = new Map<string, number>();
      for (const group of chunk(nullIds, 50)) {
        const qs = new URLSearchParams({
          part: "contentDetails",
          id: group.join(","),
          maxResults: "50",
        });
        const res = await fetch(`${YT}/videos?${qs}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!res.ok) throw new Error(await res.text());
        for (const v of (await res.json()).items ?? []) {
          durById.set(v.id, durationSeconds(v.contentDetails?.duration ?? "PT0S"));
        }
      }

      // 2) existing 61–180s non-short rows
      const midRes = await db(
        `feed_videos?user_id=eq.${userId}&is_short=eq.false` +
          `&duration_seconds=gt.${SHORTS_MAX_SECONDS}` +
          `&duration_seconds=lte.${SHORTS_PROBE_MAX}&select=video_id`,
        { method: "GET" },
      );
      const midIds: string[] = (await midRes.json()).map((r: any) => r.video_id);

      // probe 61–180s (backfilled + existing) via /shorts/
      const probeCands = [
        ...[...durById.entries()]
            .filter(([, s]) => s > SHORTS_MAX_SECONDS && s <= SHORTS_PROBE_MAX)
            .map(([id]) => id),
        ...midIds,
      ];
      const probed = await probeShorts(probeCands);

      // 3) build column-limited upserts (updates only provided columns)
      const updates: unknown[] = [];
      for (const [id, secs] of durById) {
        updates.push({
          user_id: userId,
          video_id: id,
          duration_seconds: secs,
          is_short: (secs > 0 && secs <= SHORTS_MAX_SECONDS) || probed.has(id),
        });
      }
      for (const id of midIds) {
        if (probed.has(id)) {
          updates.push({ user_id: userId, video_id: id, is_short: true });
        }
      }
      if (updates.length > 0) {
        const up = await db("feed_videos?on_conflict=user_id,video_id", {
          method: "POST",
          headers: { Prefer: "resolution=merge-duplicates" },
          body: JSON.stringify(updates),
        });
        if (!up.ok) return json({ error: "update_failed", detail: await up.text() }, 500);
      }
      const shortsMarked = updates.filter((u: any) => u.is_short).length;
      return json({
        backfilled: durById.size,
        probed: probeCands.length,
        updated: updates.length,
        shortsMarked,
      });
    } catch (e) {
      return json({ error: "reclassify_failed", detail: String(e) }, 500);
    }
  }

  // Accept {videos:[{id, short}]} (preferred) or legacy {videoIds:[...]}.
  const shortById = new Map<string, boolean>();
  if (Array.isArray(body.videos)) {
    for (const v of body.videos) {
      if (v?.id) shortById.set(String(v.id), !!v.short);
    }
  }
  for (const id of body.videoIds ?? []) {
    if (id && !shortById.has(String(id))) shortById.set(String(id), false);
  }
  const ids = [...shortById.keys()];
  if (ids.length === 0) return json({ received: 0, inserted: 0 });

  // Look up the user's OAuth refresh token (for metadata enrichment).
  const tokRes = await db(
    `google_tokens?user_id=eq.${userId}&select=refresh_token`,
    { method: "GET" },
  );
  const toks = await tokRes.json();
  const refresh = toks?.[0]?.refresh_token;
  if (!refresh) {
    return json(
      { error: "not_connected", detail: "먼저 앱에서 YouTube를 연결하세요." },
      400,
    );
  }
  const token = await accessToken(refresh);
  if (!token) return json({ error: "token_refresh_failed" }, 400);

  // Phase 1: enrich metadata via the YouTube API.
  const metas: {
    v: Record<string, any>;
    secs: number;
  }[] = [];
  try {
    for (const group of chunk(ids, 50)) {
      const qs = new URLSearchParams({
        part: "snippet,contentDetails",
        id: group.join(","),
        maxResults: "50",
      });
      const res = await fetch(`${YT}/videos?${qs}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      for (const v of data.items ?? []) {
        metas.push({
          v,
          secs: durationSeconds(v.contentDetails?.duration ?? "PT0S"),
        });
      }
    }
  } catch (e) {
    return json({ error: "enrich_failed", detail: String(e) }, 500);
  }

  // Phase 2: for 61–180s videos not already known to be Shorts, confirm via
  // the /shorts/ URL (Shorts can be up to 3 minutes).
  const probeIds = metas
    .filter((m) =>
      !(shortById.get(m.v.id) ?? false) &&
      m.secs > SHORTS_MAX_SECONDS &&
      m.secs <= SHORTS_PROBE_MAX
    )
    .map((m) => m.v.id);
  const probedShorts = await probeShorts(probeIds);

  // Phase 3: build rows.
  const rows: unknown[] = [];
  let shorts = 0;
  for (const { v, secs } of metas) {
    const isShort =
      (shortById.get(v.id) ?? false) ||
      (secs > 0 && secs <= SHORTS_MAX_SECONDS) ||
      probedShorts.has(v.id);
    if (isShort) shorts++;
    const s = v.snippet ?? {};
    const th = s.thumbnails ?? {};
    rows.push({
      user_id: userId,
      video_id: v.id,
      title: s.title ?? "",
      channel_id: s.channelId ?? "",
      channel_title: s.channelTitle ?? "",
      thumbnail_url: th.medium?.url ?? th.high?.url ?? th.default?.url ?? "",
      category_id: s.categoryId ?? "",
      published_at: s.publishedAt ?? null,
      duration_seconds: secs,
      is_short: isShort,
      fetched_at: new Date().toISOString(),
    });
  }

  if (rows.length > 0) {
    const up = await db("feed_videos?on_conflict=user_id,video_id", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify(rows),
    });
    if (!up.ok) return json({ error: "upsert_failed", detail: await up.text() }, 500);
  }

  return json({
    received: ids.length,
    inserted: rows.length,
    shorts,
  });
});
