import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny JSON key-value store backed by SharedPreferences (local, lightweight).
class Store {
  static late SharedPreferences _p;

  static Future<void> init() async =>
      _p = await SharedPreferences.getInstance();

  static T? read<T>(String key) {
    final s = _p.getString(key);
    if (s == null) return null;
    return jsonDecode(s) as T;
  }

  static Future<void> write(String key, Object value) =>
      _p.setString(key, jsonEncode(value));

  static Future<void> remove(String key) => _p.remove(key);

  static Set<String> get keys => _p.getKeys();
}
