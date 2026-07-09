import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';

/// Reads the deployed `version-info.json` and reports whether the running
/// bundle (compiled [Env.buildId]) is stale.
class UpdateInfo {
  const UpdateInfo({required this.updateAvailable, required this.remoteBuild});
  final bool updateAvailable;
  final String remoteBuild;
}

final updateInfoProvider = FutureProvider<UpdateInfo>((ref) async {
  if (Env.buildId == 'dev') {
    return const UpdateInfo(updateAvailable: false, remoteBuild: 'dev');
  }
  try {
    final uri = Uri.base.resolve(
      'version-info.json?t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return UpdateInfo(updateAvailable: false, remoteBuild: Env.buildId);
    }
    final remote = '${(jsonDecode(res.body) as Map)['build'] ?? ''}';
    return UpdateInfo(
      updateAvailable: remote.isNotEmpty && remote != Env.buildId,
      remoteBuild: remote,
    );
  } catch (_) {
    return UpdateInfo(updateAvailable: false, remoteBuild: Env.buildId);
  }
});
