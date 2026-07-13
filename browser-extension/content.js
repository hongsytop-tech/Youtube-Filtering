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

// ---- transcript collection (runs in the youtube.com page = real session) ----
function ffInnertube() {
  const html = document.documentElement.innerHTML;
  const k = html.match(/"INNERTUBE_API_KEY":"([^"]+)"/);
  const v =
    html.match(/"INNERTUBE_CONTEXT_CLIENT_VERSION":"([^"]+)"/) ||
    html.match(/"clientVersion":"([^"]+)"/);
  return {
    key: (k && k[1]) || "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8",
    cver: (v && v[1]) || "2.20240101.00.00",
  };
}

async function ffFetchTranscript(id, key, cver) {
  try {
    const res = await fetch(`/youtubei/v1/player?key=${key}&prettyPrint=false`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({
        context: { client: { clientName: "WEB", clientVersion: cver, hl: "ko" } },
        videoId: id,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const tracks =
      data?.captions?.playerCaptionsTracklistRenderer?.captionTracks;
    if (!tracks || !tracks.length) return null;
    const pick =
      tracks.find((t) => t.languageCode === "ko") ||
      tracks.find((t) => t.languageCode === "en") ||
      tracks[0];
    let url = pick && pick.baseUrl;
    if (!url) return null;
    url += (url.includes("?") ? "&" : "?") + "fmt=json3";
    const cap = await fetch(url, { credentials: "include" });
    if (!cap.ok) return null;
    const cj = await cap.json();
    let text = (cj.events || [])
      .map((e) => (e.segs || []).map((s) => s.utf8 || "").join(""))
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    if (text.length > 20000) text = text.slice(0, 20000);
    return text || null;
  } catch (_) {
    return null;
  }
}

async function ffCollectTranscripts(videos, cap) {
  const { key, cver } = ffInnertube();
  const ids = videos.filter((v) => !v.short).slice(0, cap).map((v) => v.id);
  const out = [];
  const CONC = 4;
  for (let i = 0; i < ids.length; i += CONC) {
    const batch = ids.slice(i, i + CONC);
    const texts = await Promise.all(
      batch.map((id) => ffFetchTranscript(id, key, cver)),
    );
    batch.forEach((id, j) => {
      if (texts[j]) out.push({ id, transcript: texts[j] });
    });
  }
  return out;
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
    // Best-effort: grab transcripts for the collected videos and upload them.
    try {
      const ts = await ffCollectTranscripts(videos, 40);
      if (ts.length) await sendBg({ type: "ff_transcripts", items: ts });
    } catch (_) {}
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
