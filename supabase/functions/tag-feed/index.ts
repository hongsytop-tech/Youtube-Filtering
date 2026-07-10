// Assigns fine-grained topic tags to the user's feed_videos rows using Claude
// Haiku, so the app can filter by sub-topics far more granular than YouTube's
// ~15 categories. Idempotent: only rows with tagged_at IS NULL are processed,
// so this is cheap to call repeatedly (a no-op once everything is tagged).
// verify_jwt = false; the user is resolved from the Authorization header.
// Requires the ANTHROPIC_API_KEY secret.
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
const MODEL = "claude-haiku-4-5";
const BATCH = 40; // videos per Claude call
const MAX_PER_RUN = 400; // cap work per invocation to bound latency/cost
const CONCURRENCY = 4;
// Bump when the prompt or taxonomy changes; rows tagged by an older version are
// automatically re-classified on subsequent runs.
const TAGGER_VERSION = 3;

// Must stay in sync with lib/core/utils/feed_topics.dart (FeedTopics).
const TOPIC_GROUPS: Record<string, string[]> = {
  "음악": ["K-POP", "팝", "힙합/랩", "R&B/소울", "록/메탈", "인디음악",
    "EDM/일렉트로닉", "재즈", "클래식", "발라드", "트로트", "OST",
    "커버/버스킹", "뮤직비디오", "음악방송", "직캠/팬캠"],
  "게임": ["FPS/슈팅", "RPG", "MOBA/AOS", "전략/시뮬레이션", "인디게임", "모바일게임",
    "공포게임", "콘솔/레트로", "e스포츠", "게임리뷰/공략", "마인크래프트", "리그오브레전드"],
  "지식/교육": ["과학", "우주/천문", "수학", "역사", "경제/금융", "주식/투자",
    "IT/프로그래밍", "AI/인공지능", "어학/외국어", "자기계발", "다큐멘터리", "인문/철학"],
  "엔터테인먼트": ["예능", "영화리뷰", "드라마리뷰", "웹예능", "챌린지/몰카", "연예/셀럽", "K-드라마"],
  "일상/인물": ["브이로그", "먹방", "ASMR", "일상", "룸투어/인테리어", "육아"],
  "뷰티/패션/라이프": ["뷰티/메이크업", "패션/스타일", "요리/레시피", "베이킹", "DIY/공예",
    "홈트/피트니스", "다이어트"],
  "스포츠": ["축구", "야구", "농구", "격투기/UFC", "골프", "등산/아웃도어", "헬스/보디빌딩"],
  "자동차/모터": ["자동차리뷰", "모터스포츠", "오토바이"],
  "여행": ["국내여행", "해외여행", "캠핑", "맛집탐방"],
  "뉴스/시사": ["정치/시사", "경제뉴스", "국제뉴스", "IT뉴스"],
  "코미디": ["개그/스탠드업", "밈/짤"],
  "반려동물": ["강아지", "고양이", "반려동물기타"],
  "영화/애니": ["애니메이션", "영화/예고편"],
};
const TOPICS: string[] = Object.values(TOPIC_GROUPS).flat();
const TAXONOMY_TEXT = Object.entries(TOPIC_GROUPS)
  .map(([g, ts]) => `- ${g}: ${ts.join(", ")}`)
  .join("\n");

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

function chunk<T>(arr: T[], n: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

type Row = { video_id: string; title: string; channel_title: string };

// Ask Claude Haiku to tag one batch. Returns video_id -> topics[].
async function tagBatch(rows: Row[]): Promise<Map<string, string[]>> {
  const list = rows
    .map((r, i) => `${i}. 제목: ${r.title} | 채널: ${r.channel_title}`)
    .join("\n");
  const prompt =
    "당신은 유튜브 영상 분류기입니다. 각 영상을 업로드한 **채널의 종류가 아니라 영상의 " +
    "실제 내용(주제)** 기준으로 분류하세요.\n\n" +
    "[규칙]\n" +
    "- 뉴스/시사 채널이라도 내용이 축구 경기면 '축구', 주식 시황이면 '주식/투자'처럼 " +
    "실제 소재로 분류합니다.\n" +
    "- 방송/엔터라도 음악방송(뮤직뱅크·인기가요·엠카운트다운 등)이면 '음악방송', " +
    "뮤직비디오면 '뮤직비디오', 무대 직캠이면 '직캠/팬캠'으로 구분합니다.\n" +
    "- **선수·팀 이름이나 경기 용어(8강·PK·해트트릭·리그·MVP 등)가 나오면 " +
    "'축구/뉴스'가 아니라 해당 스포츠 종목으로 분류하세요.** " +
    "예: 손흥민·음바페·메시·호날두·EPL·월드컵 → '축구'; " +
    "오타니·류현진·MLB·KBO → '야구'; 르브론·NBA → '농구'.\n" +
    "- 가장 구체적으로 맞는 주제를 1~3개 고르세요. 여러 소재가 겹치면 함께 붙여도 됩니다 " +
    "(예: K-POP 음악방송 → ['음악방송','K-POP']).\n" +
    "- 애매하면 더 적게, 목록에 정말 맞는 게 없으면 빈 배열로 두세요.\n" +
    "- 반드시 아래 목록에 있는 정확한 주제명만 사용하세요.\n\n" +
    "[예시]\n" +
    "- '[속보] 손흥민 멀티골 토트넘 역전승' (SBS뉴스) → ['축구']\n" +
    "- 'PK 실축 후 1골 1도움, 메시 따라잡은 음바페의 8강전' (풋볼리뷰) → ['축구']\n" +
    "- '뮤직뱅크 1위 아이브 I AM 무대' (KBS Kpop) → ['음악방송','K-POP']\n" +
    "- 'IVE 아이브 - I AM MV' (스타쉽엔터) → ['뮤직비디오','K-POP']\n" +
    "- '오늘의 증시 코스피 급등 브리핑' (한국경제TV) → ['주식/투자','경제뉴스']\n" +
    "- '챗GPT로 코딩 자동화하는 법' (개발자유튜버) → ['AI/인공지능','IT/프로그래밍']\n\n" +
    `[주제 목록]\n${TAXONOMY_TEXT}\n\n[분류할 영상]\n${list}`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 4096,
      tools: [{
        name: "submit_tags",
        description: "각 영상의 인덱스에 세부 주제를 부여합니다.",
        input_schema: {
          type: "object",
          properties: {
            assignments: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  i: { type: "integer", description: "영상 인덱스" },
                  topics: {
                    type: "array",
                    items: { type: "string", enum: TOPICS },
                  },
                },
                required: ["i", "topics"],
              },
            },
          },
          required: ["assignments"],
        },
      }],
      tool_choice: { type: "tool", name: "submit_tags" },
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const block = (data.content ?? []).find((c: any) => c.type === "tool_use");
  const assignments = block?.input?.assignments ?? [];
  const out = new Map<string, string[]>();
  const allowed = new Set(TOPICS);
  for (const a of assignments) {
    const row = rows[a.i];
    if (!row) continue;
    const topics = (a.topics ?? []).filter((t: string) => allowed.has(t));
    out.set(row.video_id, [...new Set(topics)]);
  }
  return out;
}

async function mapLimit<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const idx = next++;
      results[idx] = await fn(items[idx]);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, worker),
  );
  return results;
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

  // Pull rows that still need (re)tagging: never tagged, or tagged by an older
  // classifier version. Most recent first.
  const res = await db(
    `feed_videos?user_id=eq.${userId}` +
      `&or=(tagger_version.is.null,tagger_version.neq.${TAGGER_VERSION})` +
      `&select=video_id,title,channel_title` +
      `&order=published_at.desc&limit=${MAX_PER_RUN}`,
    { method: "GET" },
  );
  if (!res.ok) return json({ error: "query_failed", detail: await res.text() }, 500);
  const rows: Row[] = await res.json();
  if (rows.length === 0) return json({ untagged: 0, tagged: 0 });

  const now = new Date().toISOString();
  let tagged = 0;
  try {
    const batches = chunk(rows, BATCH);
    const maps = await mapLimit(batches, CONCURRENCY, tagBatch);
    // Build one upsert covering every processed row (empty topics still marks
    // the row tagged so it isn't reprocessed).
    const merged = new Map<string, string[]>();
    for (const m of maps) for (const [k, v] of m) merged.set(k, v);
    const updates = rows.map((r) => ({
      user_id: userId,
      video_id: r.video_id,
      topics: merged.get(r.video_id) ?? [],
      tagged_at: now,
      tagger_version: TAGGER_VERSION,
    }));
    tagged = updates.filter((u) => u.topics.length > 0).length;

    for (const group of chunk(updates, 200)) {
      const up = await db("feed_videos?on_conflict=user_id,video_id", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates" },
        body: JSON.stringify(group),
      });
      if (!up.ok) return json({ error: "update_failed", detail: await up.text() }, 500);
    }
  } catch (e) {
    return json({ error: "tag_failed", detail: String(e) }, 500);
  }

  // `more` tells the client another batch remains (we hit the per-run cap).
  return json({
    untagged: rows.length,
    processed: rows.length,
    tagged,
    more: rows.length >= MAX_PER_RUN,
  });
});
