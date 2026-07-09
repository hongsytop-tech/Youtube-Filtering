// Exchanges a Google OAuth authorization code for a refresh token and stores
// it (service role) so the server can fetch the user's feed later.
// verify_jwt = true → the caller must be a signed-in Supabase user.
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
// Namespaced (YT_) to avoid colliding with other apps' secrets in a shared project.
const GOOGLE_CLIENT_ID = Deno.env.get("YT_GOOGLE_CLIENT_ID")!;
const GOOGLE_CLIENT_SECRET = Deno.env.get("YT_GOOGLE_CLIENT_SECRET")!;

async function getUserId(authHeader: string): Promise<string | null> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey: SERVICE_ROLE },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return user?.id ?? null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  const userId = await getUserId(authHeader);
  if (!userId) return json({ error: "unauthorized" }, 401);

  let body: { code?: string; redirectUri?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  if (!body.code || !body.redirectUri) {
    return json({ error: "missing code/redirectUri" }, 400);
  }

  // Exchange authorization code → tokens
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code: body.code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: body.redirectUri,
      grant_type: "authorization_code",
    }),
  });
  const tokens = await tokenRes.json();
  if (!tokenRes.ok || !tokens.refresh_token) {
    return json(
      { error: "token_exchange_failed", detail: tokens },
      400,
    );
  }

  const expiresAt = new Date(
    Date.now() + (tokens.expires_in ?? 3600) * 1000,
  ).toISOString();

  // Upsert into google_tokens (service role bypasses RLS)
  const upsert = await fetch(
    `${SUPABASE_URL}/rest/v1/google_tokens?on_conflict=user_id`,
    {
      method: "POST",
      headers: {
        apikey: SERVICE_ROLE,
        Authorization: `Bearer ${SERVICE_ROLE}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify({
        user_id: userId,
        refresh_token: tokens.refresh_token,
        access_token: tokens.access_token,
        expires_at: expiresAt,
        scope: tokens.scope,
        connected: true,
        updated_at: new Date().toISOString(),
      }),
    },
  );

  if (!upsert.ok) {
    return json({ error: "store_failed", detail: await upsert.text() }, 500);
  }

  return json({ connected: true });
});
