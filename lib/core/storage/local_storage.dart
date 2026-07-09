import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// shared_preferences wrapper. Stores each data type as a `List<String>`
/// where every element is a stringified JSON object.
class LocalStorage {
  LocalStorage._(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStorage> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorage._(prefs);
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getStringList(key) ?? const <String>[];
    final out = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map<String, dynamic>) out.add(decoded);
      } catch (_) {
        // skip corrupt element
      }
    }
    return out;
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> items) async {
    await _prefs.setStringList(key, items.map(jsonEncode).toList());
  }

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) async =>
      _prefs.setString(key, value);

  Future<void> remove(String key) async => _prefs.remove(key);
}
