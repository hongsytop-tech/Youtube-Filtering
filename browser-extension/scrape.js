// Injected into the active youtube.com tab. Scrolls a few times to load more
// of the home feed, then collects video IDs and marks Shorts using
// length-independent signals (Shorts links, Shorts shelf, SHORTS overlay,
// and portrait thumbnails). Read-only DOM access.
(async () => {
  const scrolls = window.__FF_SCROLLS || 5;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  for (let i = 0; i < scrolls; i++) {
    window.scrollTo(0, document.documentElement.scrollHeight);
    await sleep(1200);
  }

  const map = new Map(); // id -> isShort
  const mark = (id, short) => {
    if (!id) return;
    if (!map.has(id)) map.set(id, short);
    else if (short) map.set(id, true);
  };

  const RE_WATCH = /[?&]v=([0-9A-Za-z_-]{11})/;
  const RE_SHORTS = /\/shorts\/([0-9A-Za-z_-]{11})/;
  const ITEM =
    "ytd-rich-item-renderer, ytd-video-renderer, ytd-compact-video-renderer," +
    " ytd-grid-video-renderer";

  // 1) /shorts/ links → definitely a Short (any length)
  document.querySelectorAll('a[href*="/shorts/"]').forEach((a) => {
    const m = (a.getAttribute("href") || "").match(RE_SHORTS);
    if (m) mark(m[1], true);
  });

  // 2) /watch items → Short if in a Shorts shelf, has a SHORTS overlay,
  //    or the thumbnail is portrait (vertical composition).
  document.querySelectorAll('a[href*="/watch?v="]').forEach((a) => {
    const m = (a.getAttribute("href") || "").match(RE_WATCH);
    if (!m) return;
    const id = m[1];
    const item = a.closest(ITEM);
    let short = false;
    if (item) {
      if (item.closest("ytd-rich-shelf-renderer[is-shorts], ytd-reel-shelf-renderer")) {
        short = true;
      }
      if (!short && item.querySelector('[overlay-style="SHORTS"], a[href*="/shorts/"]')) {
        short = true;
      }
      if (!short) {
        const img = item.querySelector("img");
        if (img && img.naturalWidth > 0 &&
            img.naturalHeight > img.naturalWidth * 1.1) {
          short = true; // portrait thumbnail
        }
      }
    }
    mark(id, short);
  });

  const videos = [...map.entries()].map(([id, short]) => ({ id, short }));
  const rt = (typeof browser !== "undefined" ? browser : chrome).runtime;
  rt.sendMessage({ type: "ff_collected", videos });
})();
