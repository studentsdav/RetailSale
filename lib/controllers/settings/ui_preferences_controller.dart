import 'package:flutter/material.dart';

import '../../core/settings/local_preferences.dart';

class UiPreferencesController extends ChangeNotifier {
  bool _touchMode = false;
  String _defaultStartupScreen = 'INVENTORY_DASHBOARD';
  String _textfieldSize = 'normal';
  String _cardColorStyle = 'soft';

  bool get touchMode => _touchMode;
  String get defaultStartupScreen => _defaultStartupScreen;
  String get textfieldSize => _textfieldSize;
  String get cardColorStyle => _cardColorStyle;

  Future<void> load() async {
    _touchMode = await LocalPreferences.getTouchMode();
    _defaultStartupScreen = await LocalPreferences.getDefaultStartupScreen();
    _textfieldSize = await LocalPreferences.getTextfieldSize();
    _cardColorStyle = await LocalPreferences.getCardColorStyle();
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

  Future<void> updateCardColorStyle(String value) async {
    if (_cardColorStyle == value) return;
    _cardColorStyle = value;
    await LocalPreferences.setCardColorStyle(value);
    notifyListeners();
  }
}
