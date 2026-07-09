// Injected into the active youtube.com tab. Scrolls a few times to load more
// of the home feed, then collects video IDs (normal + Shorts, flagged),
// and sends them back to the popup. Read-only DOM access.
(async () => {
  const scrolls = window.__FF_SCROLLS || 5;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  for (let i = 0; i < scrolls; i++) {
    window.scrollTo(0, document.documentElement.scrollHeight);
    await sleep(1200);
  }

  const map = new Map(); // id -> isShort
  const add = (id, short) => {
    if (!id) return;
    if (!map.has(id)) map.set(id, short);
    else if (short) map.set(id, true);
  };

  document.querySelectorAll('a[href*="/watch?v="]').forEach((a) => {
    const m = (a.getAttribute("href") || "").match(
      /[?&]v=([0-9A-Za-z_-]{11})/,
    );
    if (m) add(m[1], false);
  });

  document.querySelectorAll('a[href*="/shorts/"]').forEach((a) => {
    const m = (a.getAttribute("href") || "").match(
      /\/shorts\/([0-9A-Za-z_-]{11})/,
    );
    if (m) add(m[1], true);
  });

  const videos = [...map.entries()].map(([id, short]) => ({ id, short }));
  const rt = (typeof browser !== "undefined" ? browser : chrome).runtime;
  rt.sendMessage({ type: "ff_collected", videos });
})();
