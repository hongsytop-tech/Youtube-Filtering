import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_service.dart';
import '../services/gis_interop.dart';

class YoutubeConnectState {
  const YoutubeConnectState({
    this.loading = false,
    this.connected = false,
    this.error,
    this.message,
  });

  final bool loading;
  final bool connected;
  final String? error;
  final String? message;

  YoutubeConnectState copyWith({
    bool? loading,
    bool? connected,
    Object? error = _sentinel,
    Object? message = _sentinel,
  }) {
    return YoutubeConnectState(
      loading: loading ?? this.loading,
      connected: connected ?? this.connected,
      error: error == _sentinel ? this.error : error as String?,
      message: message == _sentinel ? this.message : message as String?,
    );
  }

  static const _sentinel = Object();
}

final youtubeConnectProvider =
    StateNotifierProvider<YoutubeConnectNotifier, YoutubeConnectState>(
  (ref) => YoutubeConnectNotifier(),
);

class YoutubeConnectNotifier extends StateNotifier<YoutubeConnectState> {
  YoutubeConnectNotifier() : super(const YoutubeConnectState());

  Future<void> connect() async {
    if (!SupabaseService.isSignedIn) {
      state = state.copyWith(error: '먼저 로그인해 주세요.');
      return;
    }
    if (Env.googleClientId.isEmpty) {
      state = state.copyWith(error: 'GOOGLE_WEB_CLIENT_ID가 설정되지 않았습니다.');
      return;
    }

    state = state.copyWith(loading: true, error: null, message: null);

    final completer = Completer<String>();
    requestYoutubeAuthCode(
      clientId: Env.googleClientId,
      onCode: (c) {
        if (!completer.isCompleted) completer.complete(c);
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      final code = await completer.future;
      // 1) exchange code → refresh token (server stores it)
      await SupabaseService.client.functions.invoke(
        'connect-youtube',
        body: {'code': code, 'redirectUri': 'postmessage'},
      );
      state = state.copyWith(connected: true, message: '연결됨. 피드를 가져오는 중…');
      // 2) trigger the first feed fetch for this user
      await SupabaseService.client.functions.invoke('fetch-feed', body: {});
      state = state.copyWith(
        loading: false,
        message: '연결 완료! 피드 탭을 새로고침하세요.',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }
}
