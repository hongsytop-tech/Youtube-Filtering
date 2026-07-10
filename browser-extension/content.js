// Runs on youtube.com. Auto-collects the home feed on visit (throttled) and
// on demand from the popup. Scrapes video IDs (Shorts flagged) and hands them
// to the background script for upload. Read-only DOM access.
const api = typeof browser !== "undefined" ? browser : chrome;
const store = api.storage.local;
const getLocal = (k) =>
  typeof browser !== "undefined"
    ? store.get(k)
    : new Promise((r) => store.get(k, r));
const sendBg = (msg) =>
  typeof browser !== "undefined"
    ? browser.runtime.sendMessage(msg)
    : new Promise((r) => chrome.runtime.sendMessage(msg, r));

const COOLDOWN_MS = 10 * 60 * 1000; // auto-collect at most once / 10 min

function collectVideos() {
  const map = new Map();
  const mark = (id, s) => {
    if (!id) return;
    if (!map.has(id)) map.set(id, s);
    else if (s) map.set(id, true);
  };
  const RE_W = /[?&]v=([0-9A-Za-z_-]{11})/;
  const RE_S = /\/shorts\/([0-9A-Za-z_-]{11})/;
  const ITEM =
    "ytd-rich-item-renderer, ytd-video-renderer, ytd-compact-video-renderer," +
    " ytd-grid-video-renderer";

  document.querySelectorAll('a[href*="/shorts/"]').forEach((a) => {
    const m = (a.getAttribute("href") || "").match(RE_S);
    if (m) mark(m[1], true);
  });
  document.querySelectorAll('a[href*="/watch?v="]').forEach((a) => {
    const m = (a.getAttribute("href") || "").match(RE_W);
    if (!m) return;
    const item = a.closest(ITEM);
    let short = false;
    if (item) {
      if (item.closest("ytd-rich-shelf-renderer[is-shorts], ytd-reel-shelf-renderer")) short = true;
      if (!short && item.querySelector('[overlay-style="SHORTS"], a[href*="/shorts/"]')) short = true;
      if (!short) {
        const img = item.querySelector("img");
        if (img && img.naturalWidth > 0 && img.naturalHeight > img.naturalWidth * 1.1) short = true;
      }
    }
    mark(m[1], short);
  });
  return [...map.entries()].map(([id, short]) => ({ id, short }));
}

function toast(text) {
  try {
    const d = document.createElement("div");
    d.textContent = text;
    d.style.cssText =
      "position:fixed;left:50%;bottom:88px;transform:translateX(-50%);" +
      "background:#111;color:#fff;padding:10px 16px;border-radius:20px;" +
      "z-index:2147483647;font-size:14px;box-shadow:0 2px 8px rgba(0,0,0,.4)";
    document.body.appendChild(d);
    setTimeout(() => d.remove(), 3500);
  } catch (_) {}
}

let running = false;
async function scrollAndCollect(scrolls, reason) {
  if (running) return;
  running = true;
  try {
    const y0 = window.scrollY;
    for (let i = 0; i < scrolls; i++) {
      window.scrollTo(0, document.documentElement.scrollHeight);
      await new Promise((r) => setTimeout(r, 1200));
    }
    const videos = collectVideos();
    if (reason === "manual") toast(`피드필터: ${videos.length}개 수집 중…`);
    const r = await sendBg({ type: "ff_collect", videos });
    if (r && !r.error) toast(`피드필터: ${r.inserted}개 저장 완료`);
    else if (r && r.error) toast(`피드필터: ${r.error}`);
    window.scrollTo(0, y0);
  } finally {
    running = false;
  }
}

// Auto-collect when the home feed is opened (throttled).
(async () => {
  if (location.pathname !== "/") return;
  const s = await getLocal([
    "ffCfg",
    "ffSession",
    "ffAuto",
    "ffLastAuto",
    "ffScrolls",
  ]);
  if (!s.ffAuto || !s.ffCfg || !s.ffSession) return;
  if (s.ffLastAuto && Date.now() - s.ffLastAuto < COOLDOWN_MS) return;
  await new Promise((r) => setTimeout(r, 3500)); // let the feed render
  if (location.pathname !== "/") return;
  scrollAndCollect(s.ffScrolls || 5, "auto");
})();

// Manual trigger from the popup.
api.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === "ff_scrape_now") {
    getLocal(["ffScrolls"]).then((s) => scrollAndCollect(s.ffScrolls || 5, "manual"));
  }
});
