import 'dart:js_interop';

/// Google Identity Services (GIS) authorization-code client interop.
/// The GIS script (`accounts.google.com/gsi/client`) is loaded in index.html.
@JS('google.accounts.oauth2.initCodeClient')
external _CodeClient _initCodeClient(_CodeClientConfig config);

extension type _CodeClient._(JSObject _) implements JSObject {
  external void requestCode();
}

extension type _CodeClientConfig._(JSObject _) implements JSObject {
  external factory _CodeClientConfig({
    String client_id,
    String scope,
    String ux_mode,
    JSFunction callback,
  });
}

extension type _CodeResponse._(JSObject _) implements JSObject {
  external String? get code;
  external String? get error;
}

const youtubeScope = 'https://www.googleapis.com/auth/youtube.readonly';

/// Opens the Google consent popup and returns the one-time authorization code.
/// Exchange it server-side (redirect_uri = "postmessage").
void requestYoutubeAuthCode({
  required String clientId,
  required void Function(String code) onCode,
  required void Function(String error) onError,
}) {
  void handle(_CodeResponse resp) {
    final err = resp.error;
    if (err != null && err.isNotEmpty) {
      onError(err);
      return;
    }
    final code = resp.code;
    if (code != null && code.isNotEmpty) {
      onCode(code);
    } else {
      onError('no_code_returned');
    }
  }

  final client = _initCodeClient(
    _CodeClientConfig(
      client_id: clientId,
      scope: youtubeScope,
      ux_mode: 'popup',
      callback: handle.toJS,
    ),
  );
  client.requestCode();
}
