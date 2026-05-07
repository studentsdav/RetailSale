import 'package:flutter/material.dart';

import '../../core/settings/local_preferences.dart';

class UiPreferencesController extends ChangeNotifier {
  bool _touchMode = false;
  String _defaultStartupScreen = 'INVENTORY_DASHBOARD';

  bool get touchMode => _touchMode;
  String get defaultStartupScreen => _defaultStartupScreen;

  Future<void> load() async {
    _touchMode = await LocalPreferences.getTouchMode();
    _defaultStartupScreen = await LocalPreferences.getDefaultStartupScreen();
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
}
