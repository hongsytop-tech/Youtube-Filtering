import 'package:web/web.dart' as web;

/// Force the browser/PWA to reload. With `--pwa-strategy none` there is no
/// service worker, so a reload fetches the freshly deployed bundle.
void reloadApp() => web.window.location.reload();

/// Session-scoped guard so the auto-updater reloads at most once per build.
String? sessionGet(String key) => web.window.sessionStorage.getItem(key);
void sessionSet(String key, String value) =>
    web.window.sessionStorage.setItem(key, value);
