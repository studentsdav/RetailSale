import 'dart:convert';

import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class TokenStorage {
  static const _key = 'auth_token';
  static const _roleKey = 'user_role';
  static const _permKey = 'user_permissions';
  static const _userKey = 'user_data';
  static const _sessionTimeKey = 'session_login_time';

  static Future<void> saveLoginTime([DateTime? time]) async {
    final prefs = await SharedPreferences.getInstance();
    final loginTime = time ?? DateTime.now();
    await prefs.setString(_sessionTimeKey, loginTime.toIso8601String());
  }

  static Future<DateTime> getLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_sessionTimeKey);
    if (str != null) {
      final dt = DateTime.tryParse(str);
      if (dt != null) return dt;
    }
    final now = DateTime.now();
    await prefs.setString(_sessionTimeKey, now.toIso8601String());
    return now;
  }

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
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_permKey);
    await prefs.remove(_sessionTimeKey);
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

  static Future<String?> getOutletCode() async {
    final user = await getUser();
    if (user != null && user['outlet_code'] != null && user['outlet_code'].toString().isNotEmpty) {
      return user['outlet_code'].toString();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('outlet_code') ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : null);
  }

  static Future<void> saveOutletCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('outlet_code', code);
    final user = await getUser();
    if (user != null) {
      user['outlet_code'] = code;
      await saveUser(user);
    }
  }

  static Future<String> getBusinessModule() async {
    final user = await getUser();
    return (user?['business_module'] ?? user?['outlet_module'] ?? user?['outlet_type'] ?? 'ALL').toString().toUpperCase();
  }

  static Future<bool> isRestaurantModuleActive() async {
    final mod = await getBusinessModule();
    return mod == 'ALL' || mod == 'RESTAURANT' || mod == 'HOTEL' || mod == 'CAFE' || mod == 'DINE_IN';
  }
}
