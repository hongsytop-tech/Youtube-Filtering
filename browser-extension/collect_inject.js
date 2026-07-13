// Injected on demand by the popup (executeScript) so manual collection works
// even on a tab opened before the extension was installed. Scrapes the home
// feed, sends it to the background for upload, and toasts the result.
(async () => {
  const send = (m) =>
    typeof browser !== "undefined"
      ? browser.runtime.sendMessage(m)
      : new Promise((r) => chrome.runtime.sendMessage(m, r));

  const scrolls = window.__FF_SCROLLS || 5;

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

  toast("피드필터: 수집 중…");
  const y0 = window.scrollY;
  for (let i = 0; i < scrolls; i++) {
    window.scrollTo(0, document.documentElement.scrollHeight);
    await new Promise((r) => setTimeout(r, 1200));
  }
  const videos = collectVideos();
  const r = await send({ type: "ff_collect", videos });
  toast(
    r && !r.error
      ? `피드필터: ${r.inserted}개 저장 완료 (앱 피드 새로고침)`
      : `피드필터: ${(r && r.error) || "업로드 실패"}`,
  );
  window.scrollTo(0, y0);
})();
