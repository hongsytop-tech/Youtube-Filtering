// Returns the signed-in user's subscribed channel ids, so the app can split the
// feed into 구독(subscribed) vs 비구독(recommended) videos. Uses the user's
// stored OAuth token (subscriptions.list?mine=true — 1 quota unit per page).
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
const MAX_PAGES = 40; // up to 2000 subscriptions (40 * 50)

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const userId = await resolveUserId(req.headers.get("Authorization") ?? "");
  if (!userId) return json({ error: "unauthorized" }, 401);

  const tokRes = await db(
    `google_tokens?user_id=eq.${userId}&select=refresh_token`,
    { method: "GET" },
  );
  const refresh = (await tokRes.json())?.[0]?.refresh_token;
  if (!refresh) {
    return json(
      { error: "not_connected", detail: "먼저 마이 탭에서 YouTube를 연결하세요." },
      400,
    );
  }
  const token = await accessToken(refresh);
  if (!token) return json({ error: "token_refresh_failed" }, 400);

  try {
    const channels: { id: string; title: string }[] = [];
    const seen = new Set<string>();
    let pageToken = "";
    for (let page = 0; page < MAX_PAGES; page++) {
      const p = new URLSearchParams({
        part: "snippet",
        mine: "true",
        maxResults: "50",
        order: "alphabetical",
      });
      if (pageToken) p.set("pageToken", pageToken);
      const res = await fetch(`${YT}/subscriptions?${p}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        throw new Error(`subscriptions: ${(await res.text()).slice(0, 200)}`);
      }
      const data = await res.json();
      for (const it of data.items ?? []) {
        const id = it.snippet?.resourceId?.channelId;
        if (id && !seen.has(id)) {
          seen.add(id);
          channels.push({ id, title: it.snippet?.title ?? "" });
        }
      }
      pageToken = data.nextPageToken ?? "";
      if (!pageToken) break;
    }
    return json({
      channelIds: channels.map((c) => c.id),
      channels,
      count: channels.length,
    });
  } catch (e) {
    return json({ error: "subscriptions_failed", detail: String(e) }, 500);
  }
});
