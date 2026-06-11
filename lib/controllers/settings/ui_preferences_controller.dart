import 'package:flutter/material.dart';

import '../../core/settings/local_preferences.dart';

class UiPreferencesController extends ChangeNotifier {
  bool _touchMode = false;
  String _defaultStartupScreen = 'INVENTORY_DASHBOARD';
  String _textfieldSize = 'normal';
  String _textfieldBorderStyle = 'rounded';
  String _cardColorStyle = 'soft';
  String _cardBorderStyle = 'rounded';
  String _buttonBorderStyle = 'rounded';
  String _fontSizeAdjustment = 'normal';

  bool get touchMode => _touchMode;
  String get defaultStartupScreen => _defaultStartupScreen;
  String get textfieldSize => _textfieldSize;
  String get textfieldBorderStyle => _textfieldBorderStyle;
  String get cardColorStyle => _cardColorStyle;
  String get cardBorderStyle => _cardBorderStyle;
  String get buttonBorderStyle => _buttonBorderStyle;
  String get fontSizeAdjustment => _fontSizeAdjustment;

  Future<void> load() async {
    _touchMode = await LocalPreferences.getTouchMode();
    _defaultStartupScreen = await LocalPreferences.getDefaultStartupScreen();
    _textfieldSize = await LocalPreferences.getTextfieldSize();
    _textfieldBorderStyle = await LocalPreferences.getTextfieldBorderStyle();
    _cardColorStyle = await LocalPreferences.getCardColorStyle();
    _cardBorderStyle = await LocalPreferences.getCardBorderStyle();
    _buttonBorderStyle = await LocalPreferences.getButtonBorderStyle();
    _fontSizeAdjustment = await LocalPreferences.getFontSizeAdjustment();
    notifyListeners();
  }

  Future<void> updateTouchMode(bool value) async {
    if (_touchMode == value) return;
    _touchMode = value;
    await LocalPreferences.setTouchMode(value);
    notifyListeners();
  }

  Future<void> updateDefaultStartupScreen(String value) async {
    if (_defaultStartupScreen == value) return;
    _defaultStartupScreen = value;
    await LocalPreferences.setDefaultStartupScreen(value);
    notifyListeners();
  }

  Future<void> updateTextfieldSize(String value) async {
    if (_textfieldSize == value) return;
    _textfieldSize = value;
    await LocalPreferences.setTextfieldSize(value);
    notifyListeners();
  }

  Future<void> updateTextfieldBorderStyle(String value) async {
    if (_textfieldBorderStyle == value) return;
    _textfieldBorderStyle = value;
    await LocalPreferences.setTextfieldBorderStyle(value);
    notifyListeners();
  }

  Future<void> updateCardColorStyle(String value) async {
    if (_cardColorStyle == value) return;
    _cardColorStyle = value;
    await LocalPreferences.setCardColorStyle(value);
    notifyListeners();
  }

  Future<void> updateCardBorderStyle(String value) async {
    if (_cardBorderStyle == value) return;
    _cardBorderStyle = value;
    await LocalPreferences.setCardBorderStyle(value);
    notifyListeners();
  }

  Future<void> updateButtonBorderStyle(String value) async {
    if (_buttonBorderStyle == value) return;
    _buttonBorderStyle = value;
    await LocalPreferences.setButtonBorderStyle(value);
    notifyListeners();
  }

  Future<void> updateFontSizeAdjustment(String value) async {
    if (_fontSizeAdjustment == value) return;
    _fontSizeAdjustment = value;
    await LocalPreferences.setFontSizeAdjustment(value);
    notifyListeners();
  }
}
