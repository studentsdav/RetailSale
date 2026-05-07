import 'dart:convert';

import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _key = 'auth_token';
  static const _roleKey = 'user_role';
  static const _permKey = 'user_permissions';
  static const _userKey = 'user_data';

  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<void> saveRole(String role) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_roleKey, role);
  }

  static Future<void> savePermissions(List<String> perms) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setStringList(_permKey, perms);
  }

  static Future<String?> getRole() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(_roleKey);
  }

  static Future<List<String>> getPermissions() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getStringList(_permKey) ?? [];
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_key);
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_permKey);
  }

  static bool isExpired(String token) {
    return Jwt.isExpired(token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final pref = await SharedPreferences.getInstance();
    final data = pref.getString(_userKey);

    if (data == null) return null;

    return jsonDecode(data);
  }
}
