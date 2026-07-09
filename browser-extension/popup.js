const CFG = window.FF_CONFIG || {};
const URL_BASE = (CFG.SUPABASE_URL || "").replace(/\/$/, "");
const ANON = CFG.SUPABASE_ANON_KEY || "";

const $ = (id) => document.getElementById(id);
const statusEl = $("status");
const setStatus = (msg) => (statusEl.textContent = msg);

async function getSession() {
  const { ffSession } = await browser.storage.local.get("ffSession");
  return ffSession || null;
}
async function setSession(s) {
  await browser.storage.local.set({ ffSession: s });
}

async function render() {
  if (!URL_BASE || !ANON || URL_BASE.includes("YOUR-PROJECT")) {
    setStatus("config.js에 SUPABASE_URL / ANON_KEY를 먼저 채우세요.");
    return;
  }
  const s = await getSession();
  $("login").hidden = !!s;
  $("collect").hidden = !s;
  if (s) $("who").textContent = `${s.email} 로그인됨`;
}

async function login() {
  const email = $("email").value.trim();
  const password = $("password").value;
  if (!email || !password) return setStatus("이메일/비밀번호를 입력하세요.");
  setStatus("로그인 중…");
  try {
    const res = await fetch(
      `${URL_BASE}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: { apikey: ANON, "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      },
    );
    const data = await res.json();
    if (!res.ok) throw new Error(data.error_description || data.msg || "실패");
    await setSession({
      email,
      access_token: data.access_token,
      refresh_token: data.refresh_token,
    });
    setStatus("로그인 완료.");
    render();
  } catch (e) {
    setStatus("로그인 실패: " + e.message);
  }
}

async function refreshToken(s) {
  const res = await fetch(`${URL_BASE}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: s.refresh_token }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error("세션 만료. 다시 로그인하세요.");
  const next = {
    email: s.email,
    access_token: data.access_token,
    refresh_token: data.refresh_token,
  };
  await setSession(next);
  return next;
}

async function ingest(session, videos) {
  const call = (token) =>
    fetch(`${URL_BASE}/functions/v1/ingest-feed`, {
      method: "POST",
      headers: {
        apikey: ANON,
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ videos }),
    });

  let res = await call(session.access_token);
  if (res.status === 401) {
    const next = await refreshToken(session);
    res = await call(next.access_token);
  }
  const data = await res.json();
  if (!res.ok) throw new Error(data.detail || data.error || "업로드 실패");
  return data;
}

let collecting = false;
async function collect() {
  if (collecting) return;
  const session = await getSession();
  if (!session) return;

  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab || !/youtube\.com/.test(tab.url || "")) {
    return setStatus("먼저 이 탭에서 youtube.com 홈을 여세요.");
  }

  collecting = true;
  $("collectBtn").disabled = true;
  const scrolls = Math.max(0, Math.min(30, +$("scrolls").value || 5));
  setStatus("수집 중… (자동 스크롤)");

  const onMsg = async (msg) => {
    if (msg.type !== "ff_collected") return;
    browser.runtime.onMessage.removeListener(onMsg);
    try {
      if (!msg.videos.length) {
        setStatus("영상을 못 찾았습니다. 홈 화면인지 확인하세요.");
      } else {
        setStatus(`영상 ${msg.videos.length}개 발견. 업로드 중…`);
        const r = await ingest(session, msg.videos);
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
  browser.runtime.onMessage.addListener(onMsg);

  try {
    await browser.tabs.executeScript(tab.id, {
      code: `window.__FF_SCROLLS=${scrolls};`,
    });
    await browser.tabs.executeScript(tab.id, { file: "scrape.js" });
  } catch (e) {
    browser.runtime.onMessage.removeListener(onMsg);
    setStatus("주입 실패: " + e.message);
    collecting = false;
    $("collectBtn").disabled = false;
  }
}

$("loginBtn").addEventListener("click", login);
$("collectBtn").addEventListener("click", collect);
$("logoutBtn").addEventListener("click", async () => {
  await browser.storage.local.remove("ffSession");
  setStatus("로그아웃됨.");
  render();
});

render();
