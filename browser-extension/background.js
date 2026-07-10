// Background: receives scraped videos from the content script and uploads them
// to Supabase (ingest-feed). Runs outside the page, so it's not subject to
// youtube.com's CSP. Handles token refresh centrally.
const api = typeof browser !== "undefined" ? browser : chrome;
const store = api.storage.local;
const get = (k) =>
  typeof browser !== "undefined"
    ? store.get(k)
    : new Promise((r) => store.get(k, r));
const set = (o) =>
  typeof browser !== "undefined"
    ? store.set(o)
    : new Promise((r) => store.set(o, r));

async function refresh(cfg, session) {
  const res = await fetch(`${cfg.url}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: { apikey: cfg.key, "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: session.refresh_token }),
  });
  const d = await res.json();
  if (!res.ok) throw new Error("세션 만료. 팝업에서 다시 로그인하세요.");
  const next = {
    email: session.email,
    access_token: d.access_token,
    refresh_token: d.refresh_token,
  };
  await set({ ffSession: next });
  return next;
}

async function upload(videos) {
  const { ffCfg: cfg, ffSession: session } = await get(["ffCfg", "ffSession"]);
  if (!cfg || !session) return { error: "설정/로그인이 필요합니다." };
  if (!videos || !videos.length) return { error: "수집된 영상이 없습니다." };

  const call = (tok) =>
    fetch(`${cfg.url}/functions/v1/ingest-feed`, {
      method: "POST",
      headers: {
        apikey: cfg.key,
        Authorization: `Bearer ${tok}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ videos }),
    });

  let res = await call(session.access_token);
  if (res.status === 401) {
    const n = await refresh(cfg, session);
    res = await call(n.access_token);
  }
  const d = await res.json();
  if (!res.ok) return { error: d.detail || d.error || "업로드 실패" };
  return d;
}

function badge(n) {
  try {
    api.browserAction.setBadgeBackgroundColor({ color: "#E01E1E" });
    api.browserAction.setBadgeText({ text: n ? String(n) : "" });
    setTimeout(() => api.browserAction.setBadgeText({ text: "" }), 5000);
  } catch (_) {}
}

api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg && msg.type === "ff_collect") {
    upload(msg.videos)
      .then((r) => {
        if (!r.error) {
          set({ ffLastAuto: Date.now() });
          badge(r.inserted);
        }
        set({ ffLastResult: { ...r, ts: Date.now() } });
        sendResponse(r);
      })
      .catch((e) => {
        set({ ffLastResult: { error: String(e), ts: Date.now() } });
        sendResponse({ error: String(e) });
      });
    return true; // async response
  }
});
