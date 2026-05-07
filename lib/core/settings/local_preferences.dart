import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/settings/app_branding_model.dart';

class LocalPreferences {
  static const _showNotificationsKey = 'show_notifications';
  static const _themeKey = 'app_theme_key';
  static const _brandingKey = 'app_branding';
  static const _touchModeKey = 'touch_mode_enabled';
  static const _defaultStartupScreenKey = 'default_startup_screen';

  static Future<bool> getShowNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showNotificationsKey) ?? true;
  }

  static Future<void> setShowNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showNotificationsKey, value);
  }

  static Future<bool> getTouchMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_touchModeKey) ?? false;
  }

  static Future<void> setTouchMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_touchModeKey, value);
  }

  static Future<String> getDefaultStartupScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultStartupScreenKey) ?? 'INVENTORY_DASHBOARD';
  }

  static Future<void> setDefaultStartupScreen(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultStartupScreenKey, value);
  }

  static Future<String> getThemeKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? AppBrandingModel.defaults().themeKey;
  }

  static Future<void> setThemeKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value);
  }

  static Future<AppBrandingModel> getAppBranding() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_brandingKey);

    if (raw == null || raw.trim().isEmpty) {
      return AppBrandingModel.defaults();
    }

    try {
      return AppBrandingModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return AppBrandingModel.defaults();
    }
  }

  static Future<void> setAppBranding(AppBrandingModel value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandingKey, jsonEncode(value.toJson()));
    await prefs.setString(_themeKey, value.themeKey);
  }
}
