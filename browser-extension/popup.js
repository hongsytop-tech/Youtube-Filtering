// Popup: Supabase config + login + auto-collect toggle. Collection itself is
// done by the content script (auto on home, or on demand via message).
const api = typeof browser !== "undefined" ? browser : chrome;
const store = api.storage.local;
const get = (k) => (typeof browser !== "undefined" ? store.get(k) : new Promise((r) => store.get(k, r)));
const set = (o) => (typeof browser !== "undefined" ? store.set(o) : new Promise((r) => store.set(o, r)));
const remove = (k) => (typeof browser !== "undefined" ? store.remove(k) : new Promise((r) => store.remove(k, r)));
const queryTabs = (q) => (typeof browser !== "undefined" ? browser.tabs.query(q) : new Promise((r) => chrome.tabs.query(q, r)));
const execScript = (id, d) =>
  typeof browser !== "undefined"
    ? browser.tabs.executeScript(id, d)
    : new Promise((res, rej) =>
        chrome.tabs.executeScript(id, d, (r) =>
          chrome.runtime.lastError ? rej(chrome.runtime.lastError) : res(r),
        ),
      );

const $ = (id) => document.getElementById(id);
const setStatus = (m) => ($("status").textContent = m);

async function getCfg() {
  const { ffCfg } = await get("ffCfg");
  if (ffCfg?.url && ffCfg?.key) return ffCfg;
  const f = window.FF_CONFIG || {};
  if (f.SUPABASE_URL && f.SUPABASE_ANON_KEY && !f.SUPABASE_URL.includes("YOUR-")) {
    return { url: f.SUPABASE_URL.replace(/\/$/, ""), key: f.SUPABASE_ANON_KEY };
  }
  return null;
}

async function render() {
  const cfg = await getCfg();
  const { ffSession, ffAuto, ffScrolls } = await get(["ffSession", "ffAuto", "ffScrolls"]);
  $("settings").hidden = !!cfg;
  $("login").hidden = !cfg || !!ffSession;
  $("collect").hidden = !ffSession;
  if (ffSession) $("who").textContent = `${ffSession.email} 로그인됨`;
  $("auto").checked = !!ffAuto;
  if (ffScrolls) $("scrolls").value = ffScrolls;
}

async function saveCfg() {
  const url = $("url").value.trim().replace(/\/$/, "");
  const key = $("key").value.trim();
  if (!url || !key) return setStatus("URL과 anon key를 모두 입력하세요.");
  await set({ ffCfg: { url, key } });
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
    await set({
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

async function collectNow() {
  const scrolls = Math.max(0, Math.min(30, +$("scrolls").value || 5));
  await set({ ffScrolls: scrolls });
  const tabs = await queryTabs({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab || !/youtube\.com/.test(tab.url || "")) {
    return setStatus("먼저 이 탭에서 youtube.com 홈을 여세요.");
  }
  setStatus("수집 중… 화면 하단 알림을 확인하세요.");
  try {
    await execScript(tab.id, { code: `window.__FF_SCROLLS=${scrolls};` });
    await execScript(tab.id, { file: "collect_inject.js" });
  } catch (e) {
    setStatus("주입 실패: " + (e.message || e) + "\n페이지를 새로고침 후 다시 시도하세요.");
  }
}

$("saveBtn").addEventListener("click", saveCfg);
$("loginBtn").addEventListener("click", login);
$("collectBtn").addEventListener("click", collectNow);
$("auto").addEventListener("change", (e) => set({ ffAuto: e.target.checked }));
$("scrolls").addEventListener("change", (e) =>
  set({ ffScrolls: Math.max(0, Math.min(30, +e.target.value || 5)) }),
);
$("editCfgBtn").addEventListener("click", async () => {
  await remove("ffCfg");
  setStatus("Supabase 설정을 다시 입력하세요.");
  render();
});
$("logoutBtn").addEventListener("click", async () => {
  await remove("ffSession");
  setStatus("로그아웃됨.");
  render();
});

render();
