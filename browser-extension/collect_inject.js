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
  const FF_MWEB = /(^|\.)m\.youtube\.com$/.test(location.hostname);
  async function ffFetchOne(id, key, cver, diag) {
    try {
      const client = FF_MWEB
        ? { clientName: "MWEB", clientVersion: cver, hl: "ko", gl: "KR" }
        : { clientName: "WEB", clientVersion: cver, hl: "ko", gl: "KR" };
      // Same-origin (relative) to avoid cross-origin/CORB on m.youtube.com.
      const res = await fetch(
        `/youtubei/v1/player?key=${key}&prettyPrint=false`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          credentials: "include",
          body: JSON.stringify({ context: { client }, videoId: id }),
        },
      );
      if (!res.ok) {
        diag.playerErr = (diag.playerErr || 0) + 1;
        diag.lastErr = "player " + res.status;
        return null;
      }
      diag.playerOk++;
      const data = await res.json();
      const tracks =
        data?.captions?.playerCaptionsTracklistRenderer?.captionTracks;
      if (!tracks || !tracks.length) return null;
      diag.hadTracks++;
      const pick =
        tracks.find((t) => t.languageCode === "ko") ||
        tracks.find((t) => t.languageCode === "en") ||
        tracks[0];
      let url = pick && pick.baseUrl;
      if (!url) return null;
      url += (url.includes("?") ? "&" : "?") + "fmt=json3";
      const cap = await fetch(url, { credentials: "include" });
      if (!cap.ok) {
        diag.capErr = (diag.capErr || 0) + 1;
        diag.lastErr = "caption " + cap.status;
        return null;
      }
      const cj = await cap.json();
      let text = (cj.events || [])
        .map((e) => (e.segs || []).map((s) => s.utf8 || "").join(""))
        .join(" ")
        .replace(/\s+/g, " ")
        .trim();
      if (text.length > 20000) text = text.slice(0, 20000);
      if (text) {
        diag.gotText++;
        return text;
      }
      return null;
    } catch (e) {
      diag.threw = (diag.threw || 0) + 1;
      diag.lastErr = String(e).slice(0, 60);
      return null;
    }
  }
  async function ffCollectTranscripts(vids, cap) {
    const { key, cver } = ffInnertube();
    const ids = vids.filter((v) => !v.short).slice(0, cap).map((v) => v.id);
    const diag = {
      mweb: FF_MWEB ? 1 : 0,
      keyFound: /^AIza/.test(key) ? 1 : 0,
      attempted: ids.length,
      playerOk: 0,
      hadTracks: 0,
      gotText: 0,
    };
    const out = [];
    const CONC = 4;
    for (let i = 0; i < ids.length; i += CONC) {
      const batch = ids.slice(i, i + CONC);
      const texts = await Promise.all(
        batch.map((id) => ffFetchOne(id, key, cver, diag)),
      );
      batch.forEach((id, j) => {
        if (texts[j]) out.push({ id, transcript: texts[j] });
      });
    }
    return { items: out, diag };
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
      ? `피드필터: ${r.inserted}개 저장 완료 (자막 수집 중…)`
      : `피드필터: ${(r && r.error) || "업로드 실패"}`,
  );
  try {
    const { items: ts, diag } = await ffCollectTranscripts(videos, 40);
    // Always report (even 0) so the popup shows a diagnostic and Invocations
    // records the call.
    await send({ type: "ff_transcripts", items: ts, diag });
    toast(
      `자막 진단: 시도 ${diag.attempted} / 플레이어 ${diag.playerOk} / ` +
        `트랙 ${diag.hadTracks} / 텍스트 ${diag.gotText}`,
    );
  } catch (e) {
    toast("자막 오류: " + String(e).slice(0, 60));
  }
  window.scrollTo(0, y0);
})();
