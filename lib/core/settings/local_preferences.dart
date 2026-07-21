import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/settings/app_branding_model.dart';

class LocalPreferences {
  static const _showNotificationsKey = 'show_notifications';
  static const _themeKey = 'app_theme_key';
  static const _brandingKey = 'app_branding';
  static const _touchModeKey = 'touch_mode_enabled';
  static const _defaultStartupScreenKey = 'default_startup_screen';
  static const _textfieldSizeKey = 'ui_textfield_size';
  static const _textfieldBorderStyleKey = 'ui_textfield_border_style';
  static const _cardColorStyleKey = 'ui_card_color_style';
  static const _cardBorderStyleKey = 'ui_card_border_style';
  static const _buttonBorderStyleKey = 'ui_button_border_style';
  static const _fontSizeAdjustmentKey = 'ui_font_size_adjustment';

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

  static Future<String> getTextfieldSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_textfieldSizeKey) ?? 'normal';
  }

  static Future<void> setTextfieldSize(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textfieldSizeKey, value);
  }

  static Future<String> getTextfieldBorderStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_textfieldBorderStyleKey) ?? 'rounded';
  }

  static Future<void> setTextfieldBorderStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textfieldBorderStyleKey, value);
  }

  static Future<String> getCardColorStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cardColorStyleKey) ?? 'soft';
  }

  static Future<void> setCardColorStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cardColorStyleKey, value);
  }

  static Future<String> getCardBorderStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cardBorderStyleKey) ?? 'rounded';
  }

  static Future<void> setCardBorderStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cardBorderStyleKey, value);
  }

  static Future<String> getButtonBorderStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_buttonBorderStyleKey) ?? 'rounded';
  }

  static Future<void> setButtonBorderStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_buttonBorderStyleKey, value);
  }

  static Future<String> getFontSizeAdjustment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontSizeAdjustmentKey) ?? 'normal';
  }

  static Future<void> setFontSizeAdjustment(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeAdjustmentKey, value);
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

  static const _favoriteDrawerItemsKey = 'favorite_drawer_items';

  static Future<List<String>> getFavoriteDrawerItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoriteDrawerItemsKey) ?? [
      'Retail Sales',
      'Purchase Order',
      'Stock View',
      'Stock Issue / Dispatch',
    ];
  }

  static Future<void> setFavoriteDrawerItems(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteDrawerItemsKey, items);
  }
}
