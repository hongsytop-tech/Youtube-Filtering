// Receives {items:[{id, transcript}]} scraped by the extension (from the user's
// real YouTube session) and stores each transcript on the matching feed_videos
// row. Update-only (PATCH) so it never inserts phantom rows.
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
  const items = Array.isArray(body.items) ? body.items : [];
  if (items.length === 0) return json({ received: 0, updated: 0 });

  let updated = 0;
  const CONC = 6;
  for (let i = 0; i < items.length; i += CONC) {
    const batch = items.slice(i, i + CONC);
    const results = await Promise.all(
      batch.map(async (it: any) => {
        const id = String(it?.id ?? "");
        const transcript = String(it?.transcript ?? "");
        if (!id || !transcript) return false;
        const res = await db(
          `feed_videos?user_id=eq.${userId}&video_id=eq.${id}`,
          {
            method: "PATCH",
            headers: { Prefer: "return=minimal" },
            body: JSON.stringify({ transcript }),
          },
        );
        return res.ok;
      }),
    );
    updated += results.filter(Boolean).length;
  }

  return json({ received: items.length, updated });
});
