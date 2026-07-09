import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';

/// Reads the deployed `version-info.json` and reports whether the running
/// bundle (compiled [Env.buildId]) is stale.
class UpdateInfo {
  const UpdateInfo({
    required this.updateAvailable,
    required this.localBuild,
    required this.remoteBuild,
  });

  final bool updateAvailable;
  final String localBuild;
  final String remoteBuild;
}

/// Invalidate this provider to force a fresh check (manual "업데이트 확인").
final updateInfoProvider = FutureProvider<UpdateInfo>((ref) async {
  final local = Env.buildId;
  if (local == 'dev') {
    // running locally / not a Pages build → nothing to compare against
    return UpdateInfo(
        updateAvailable: false, localBuild: local, remoteBuild: local);
  }
  final uri = Uri.base.resolve(
    'version-info.json?t=${DateTime.now().millisecondsSinceEpoch}',
  );
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    return UpdateInfo(
        updateAvailable: false, localBuild: local, remoteBuild: local);
  }
  final remote = '${(jsonDecode(res.body) as Map)['build'] ?? ''}';
  return UpdateInfo(
    updateAvailable: remote.isNotEmpty && remote != local,
    localBuild: local,
    remoteBuild: remote,
  );
});
