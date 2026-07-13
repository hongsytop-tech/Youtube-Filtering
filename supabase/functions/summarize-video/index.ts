// On-demand AI summary for one video. Prefers the collected transcript; falls
// back to the video's description (via the YouTube API) when no transcript
// exists. Caches the result on the feed_videos row so re-taps are free.
// verify_jwt = false; user resolved from the Authorization header.
// Requires ANTHROPIC_API_KEY (+ YT OAuth for the description fallback).
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
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const GOOGLE_CLIENT_ID = Deno.env.get("YT_GOOGLE_CLIENT_ID") ?? "";
const GOOGLE_CLIENT_SECRET = Deno.env.get("YT_GOOGLE_CLIENT_SECRET") ?? "";
const YT = "https://www.googleapis.com/youtube/v3";
const MODEL = "claude-haiku-4-5";

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

async function describe(userId: string, videoId: string): Promise<string | null> {
  const tokRes = await db(
    `google_tokens?user_id=eq.${userId}&select=refresh_token`,
    { method: "GET" },
  );
  const refresh = (await tokRes.json())?.[0]?.refresh_token;
  if (!refresh) return null;
  const token = await accessToken(refresh);
  if (!token) return null;
  const qs = new URLSearchParams({ part: "snippet", id: videoId });
  const res = await fetch(`${YT}/videos?${qs}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  const s = (await res.json())?.items?.[0]?.snippet;
  if (!s) return null;
  const parts = [
    `제목: ${s.title ?? ""}`,
    `채널: ${s.channelTitle ?? ""}`,
    s.tags?.length ? `태그: ${s.tags.slice(0, 15).join(", ")}` : "",
    `설명:\n${s.description ?? ""}`,
  ].filter(Boolean);
  return parts.join("\n");
}

async function summarize(
  title: string,
  content: string,
  fromTranscript: boolean,
): Promise<string> {
  const src = fromTranscript
    ? "아래는 영상의 자막(스크립트)입니다."
    : "자막이 없어 영상 설명(description) 기준입니다. 추정이 섞일 수 있음을 감안하세요.";
  const prompt =
    `유튜브 영상 "${title}"의 내용을 한국어로 요약하세요.\n${src}\n\n` +
    "형식:\n- 첫 줄에 한 문장 요약(TL;DR)\n- 그 아래 핵심 내용 3~6개를 불릿으로\n" +
    "간결하고 사실 위주로. 내용이 부족하면 무리하게 지어내지 마세요.\n\n" +
    `[내용]\n${content.slice(0, 8000)}`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 900,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const text = (data.content ?? [])
    .filter((c: any) => c.type === "text")
    .map((c: any) => c.text)
    .join("")
    .trim();
  return text;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!ANTHROPIC_API_KEY) {
    return json(
      { error: "no_api_key", detail: "ANTHROPIC_API_KEY 시크릿이 필요합니다." },
      400,
    );
  }

  const userId = await resolveUserId(req.headers.get("Authorization") ?? "");
  if (!userId) return json({ error: "unauthorized" }, 401);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const videoId = String(body.videoId ?? "");
  if (!videoId) return json({ error: "no_video" }, 400);

  // Existing feed_videos row (may be absent for link-added favorites).
  const rowRes = await db(
    `feed_videos?user_id=eq.${userId}&video_id=eq.${videoId}` +
      `&select=title,transcript,summary`,
    { method: "GET" },
  );
  const row = (await rowRes.json())?.[0];

  if (row?.summary) {
    return json({ summary: row.summary, cached: true });
  }

  const title = row?.title ?? "";
  let content: string | null = row?.transcript ?? null;
  let fromTranscript = !!content;
  if (!content) {
    content = await describe(userId, videoId);
    fromTranscript = false;
  }
  if (!content) {
    return json({
      error: "no_content",
      detail: "요약할 자막이나 설명을 찾지 못했습니다.",
    }, 404);
  }

  let summary: string;
  try {
    summary = await summarize(title, content, fromTranscript);
  } catch (e) {
    return json({ error: "summarize_failed", detail: String(e) }, 500);
  }
  if (!summary) return json({ error: "empty_summary" }, 500);

  // Cache on the row when it exists (update-only).
  if (row) {
    await db(`feed_videos?user_id=eq.${userId}&video_id=eq.${videoId}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        summary,
        summarized_at: new Date().toISOString(),
      }),
    });
  }

  return json({ summary, source: fromTranscript ? "transcript" : "description" });
});
