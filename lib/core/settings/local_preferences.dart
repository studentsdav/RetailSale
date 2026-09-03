import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  static const _virtualKeyboardDisabledKey = 'virtual_keyboard_disabled';
  static const _timeZoneKey = 'app_time_zone';

  static Future<String> getTimeZone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_timeZoneKey) ?? 'Asia/Kolkata';
  }

  static Future<void> setTimeZone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeZoneKey, value);
  }

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

  static Future<bool> getVirtualKeyboardDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_virtualKeyboardDisabledKey) ?? false;
  }

  static Future<void> setVirtualKeyboardDisabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_virtualKeyboardDisabledKey, value);
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
  static const _billCopiesCountKey = 'bill_copies_count';

  static Future<int?> getBillCopiesCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_billCopiesCountKey);
  }

  static Future<void> setBillCopiesCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_billCopiesCountKey, count);
  }

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

  // --- LYNX ASSIST AI SETTINGS & LOCAL CHAT HISTORY ---
  static const _lynxAiApiKeyKey = 'lynx_ai_api_key';
  static const _lynxAiProviderKey = 'lynx_ai_provider';
  static const _lynxAiModelNameKey = 'lynx_ai_model_name';
  static const _lynxAiBaseUrlKey = 'lynx_ai_base_url';
  static const _lynxChatHistoryKey = 'lynx_chat_history';

  static Future<String> getLynxAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lynxAiApiKeyKey) ?? '';
  }

  static Future<void> setLynxAiApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lynxAiApiKeyKey, value);
  }

  static Future<String> getLynxAiProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lynxAiProviderKey) ?? 'gemini';
  }

  static Future<void> setLynxAiProvider(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lynxAiProviderKey, value);
  }

  static Future<String> getLynxAiModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lynxAiModelNameKey) ?? 'gemini-1.5-flash';
  }

  static Future<void> setLynxAiModelName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lynxAiModelNameKey, value);
  }

  static Future<String> getLynxAiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lynxAiBaseUrlKey) ?? 'https://generativelanguage.googleapis.com';
  }

  static Future<void> setLynxAiBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lynxAiBaseUrlKey, value);
  }

  static String _historyKeyForOutlet(int outletId) {
    return outletId > 0 ? '${_lynxChatHistoryKey}_$outletId' : _lynxChatHistoryKey;
  }

  static Future<List<Map<String, dynamic>>> getLynxChatHistory([int outletId = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _historyKeyForOutlet(outletId);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setLynxChatHistory(List<Map<String, dynamic>> messages, [int outletId = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _historyKeyForOutlet(outletId);
    await prefs.setString(key, jsonEncode(messages));
  }

  static Future<void> clearLynxChatHistory([int outletId = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _historyKeyForOutlet(outletId);
    await prefs.remove(key);
  }

  static const _lynxThemeModeKey = 'lynx_theme_mode';

  static Future<String> getLynxThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lynxThemeModeKey) ?? 'dark';
  }

  static Future<void> setLynxThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lynxThemeModeKey, value);
  }

  static const _lynxMaxRowsKey = 'lynx_max_rows';
  static const _machineIdKey = 'pos_machine_id';

  /// Auto-detect physical hardware / OS Device Hostname
  static String getSystemHardwareId() {
    if (kIsWeb) return 'WEB_DEVICE';
    try {
      final host = Platform.localHostname.trim().toUpperCase();
      if (host.isNotEmpty && host != 'LOCALHOST') return host;
    } catch (_) {}
    try {
      final comp = (Platform.environment['COMPUTERNAME'] ??
              Platform.environment['HOSTNAME'] ??
              '')
          .trim()
          .toUpperCase();
      if (comp.isNotEmpty) return comp;
    } catch (_) {}
    return 'DEVICE_01';
  }

  static Future<String> getMachineId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_machineIdKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim().toUpperCase();
    }
    final hwId = getSystemHardwareId();
    await prefs.setString(_machineIdKey, hwId);
    return hwId;
  }

  static Future<void> setMachineId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_machineIdKey, value.trim().toUpperCase());
  }

  static Future<int> getLynxMaxRows() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getInt(_lynxMaxRowsKey) ?? 100;
    if (rows > 1000) return 1000;
    if (rows < 1) return 1;
    return rows;
  }

  static Future<void> setLynxMaxRows(int value) async {
    final prefs = await SharedPreferences.getInstance();
    int clamped = value;
    if (clamped > 1000) clamped = 1000;
    if (clamped < 1) clamped = 1;
    await prefs.setInt(_lynxMaxRowsKey, clamped);
  }

  static const _devicePrinterMappingsKey = 'device_printer_mappings_cache';

  static Future<Map<String, dynamic>> getDevicePrinterMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_devicePrinterMappingsKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  static Future<void> setDevicePrinterMappings(Map<String, dynamic> mappings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_devicePrinterMappingsKey, jsonEncode(mappings));
  }

  static const _enableTokenSystemKey = 'enable_token_system_key';
  static const _tokenCopiesCountKey = 'token_copies_count_key';

  static Future<bool?> getEnableTokenSystem() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableTokenSystemKey);
  }

  static Future<void> setEnableTokenSystem(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableTokenSystemKey, value);
  }

  static Future<int?> getTokenCopiesCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tokenCopiesCountKey);
  }

  static Future<void> setTokenCopiesCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tokenCopiesCountKey, value);
  }

  static const _enableKotPrintKey = 'enable_kot_print_key';
  static const _kotPrintModeKey = 'kot_print_mode_key';
  static const _outletMaxDiscountKey = 'outlet_max_discount_percent';

  static Future<bool?> getEnableKotPrint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableKotPrintKey);
  }

  static Future<void> setEnableKotPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableKotPrintKey, value);
  }

  static Future<String?> getKotPrintMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kotPrintModeKey);
  }

  static Future<void> setKotPrintMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kotPrintModeKey, value);
  }

  static Future<double> getMaxDiscountPercent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_outletMaxDiscountKey) ?? 100.0;
  }

  static Future<void> setMaxDiscountPercent(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_outletMaxDiscountKey, value);
  }
}
