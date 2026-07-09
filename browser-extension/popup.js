// Cross-browser (Firefox `browser.*` + Chromium `chrome.*`) popup logic.
const _b = typeof browser !== "undefined" ? browser : null;
const _c = typeof chrome !== "undefined" ? chrome : null;
const RT = (_b || _c).runtime;
const ext = {
  get: (k) => (_b ? _b.storage.local.get(k) : new Promise((r) => _c.storage.local.get(k, r))),
  set: (o) => (_b ? _b.storage.local.set(o) : new Promise((r) => _c.storage.local.set(o, r))),
  remove: (k) => (_b ? _b.storage.local.remove(k) : new Promise((r) => _c.storage.local.remove(k, r))),
  query: (q) => (_b ? _b.tabs.query(q) : new Promise((r) => _c.tabs.query(q, r))),
  exec: (id, d) =>
    _b
      ? _b.tabs.executeScript(id, d)
      : new Promise((res, rej) =>
          _c.tabs.executeScript(id, d, (r) =>
            _c.runtime.lastError ? rej(_c.runtime.lastError) : res(r),
          ),
        ),
};

const $ = (id) => document.getElementById(id);
const statusEl = $("status");
const setStatus = (m) => (statusEl.textContent = m);

async function getCfg() {
  const { ffCfg } = await ext.get("ffCfg");
  if (ffCfg?.url && ffCfg?.key) return ffCfg;
  const f = window.FF_CONFIG || {};
  if (f.SUPABASE_URL && f.SUPABASE_ANON_KEY && !f.SUPABASE_URL.includes("YOUR-")) {
    return { url: f.SUPABASE_URL.replace(/\/$/, ""), key: f.SUPABASE_ANON_KEY };
  }
  return null;
}
async function getSession() {
  const { ffSession } = await ext.get("ffSession");
  return ffSession || null;
}

async function render() {
  const cfg = await getCfg();
  const s = cfg ? await getSession() : null;
  $("settings").hidden = !!cfg;
  $("login").hidden = !cfg || !!s;
  $("collect").hidden = !s;
  if (s) $("who").textContent = `${s.email} 로그인됨`;
}

async function saveCfg() {
  const url = $("url").value.trim().replace(/\/$/, "");
  const key = $("key").value.trim();
  if (!url || !key) return setStatus("URL과 anon key를 모두 입력하세요.");
  await ext.set({ ffCfg: { url, key } });
  setStatus("설정 저장됨.");
  render();
}

async function login() {
  const cfg = await getCfg();
  const email = $("email").value.trim();
  const password = $("password").value;
  if (!email || !password) return setStatus("이메일/비밀번호를 입력하세요.");
  setStatus("로그인 중…");
  try {
    const res = await fetch(`${cfg.url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: cfg.key, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error_description || data.msg || "실패");
    await ext.set({
      ffSession: {
        email,
        access_token: data.access_token,
        refresh_token: data.refresh_token,
      },
    });
    setStatus("로그인 완료.");
    render();
  } catch (e) {
    setStatus("로그인 실패: " + e.message);
  }
}

async function refreshToken(cfg, s) {
  const res = await fetch(`${cfg.url}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: { apikey: cfg.key, "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: s.refresh_token }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error("세션 만료. 다시 로그인하세요.");
  const next = {
    email: s.email,
    access_token: data.access_token,
    refresh_token: data.refresh_token,
  };
  await ext.set({ ffSession: next });
  return next;
}

async function ingest(cfg, session, videos) {
  const call = (token) =>
    fetch(`${cfg.url}/functions/v1/ingest-feed`, {
      method: "POST",
      headers: {
        apikey: cfg.key,
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ videos }),
    });
  let res = await call(session.access_token);
  if (res.status === 401) {
    const next = await refreshToken(cfg, session);
    res = await call(next.access_token);
  }
  const data = await res.json();
  if (!res.ok) throw new Error(data.detail || data.error || "업로드 실패");
  return data;
}

let collecting = false;
async function collect() {
  if (collecting) return;
  const cfg = await getCfg();
  const session = await getSession();
  if (!cfg || !session) return;

  const tabs = await ext.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab || !/youtube\.com/.test(tab.url || "")) {
    return setStatus("먼저 이 탭에서 youtube.com 홈을 여세요.");
  }

  collecting = true;
  $("collectBtn").disabled = true;
  const scrolls = Math.max(0, Math.min(30, +$("scrolls").value || 5));
  setStatus("수집 중… (자동 스크롤)");

  const onMsg = async (msg) => {
    if (!msg || msg.type !== "ff_collected") return;
    RT.onMessage.removeListener(onMsg);
    try {
      if (!msg.videos.length) {
        setStatus("영상을 못 찾았습니다. 홈 화면인지 확인하세요.");
      } else {
        setStatus(`영상 ${msg.videos.length}개 발견. 업로드 중…`);
        const r = await ingest(cfg, session, msg.videos);
        setStatus(
          `완료! 저장 ${r.inserted}개 (쇼츠 ${r.shorts}개 포함).\n앱에서 피드를 새로고침하세요.`,
        );
      }
    } catch (e) {
      setStatus("오류: " + e.message);
    } finally {
      collecting = false;
      $("collectBtn").disabled = false;
    }
  };
  RT.onMessage.addListener(onMsg);

  try {
    await ext.exec(tab.id, { code: `window.__FF_SCROLLS=${scrolls};` });
    await ext.exec(tab.id, { file: "scrape.js" });
  } catch (e) {
    RT.onMessage.removeListener(onMsg);
    setStatus("주입 실패: " + e.message);
    collecting = false;
    $("collectBtn").disabled = false;
  }
}

$("saveBtn").addEventListener("click", saveCfg);
$("loginBtn").addEventListener("click", login);
$("collectBtn").addEventListener("click", collect);
$("editCfgBtn").addEventListener("click", async () => {
  await ext.remove("ffCfg");
  setStatus("Supabase 설정을 다시 입력하세요.");
  render();
});
$("logoutBtn").addEventListener("click", async () => {
  await ext.remove("ffSession");
  setStatus("로그아웃됨.");
  render();
});

render();
