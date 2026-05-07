import 'package:flutter/material.dart';

import '../../core/settings/local_preferences.dart';

class ThemeController extends ChangeNotifier {
  String _themeKey = 'famalth_classic';

  String get themeKey => _themeKey;

  Future<void> load() async {
    _themeKey = await LocalPreferences.getThemeKey();
    notifyListeners();
  }

  Future<void> updateTheme(String value) async {
    if (_themeKey == value) return;
    _themeKey = value;
    await LocalPreferences.setThemeKey(value);
    notifyListeners();
  }
}
