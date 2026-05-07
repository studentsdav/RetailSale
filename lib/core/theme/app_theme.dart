import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const famalthClassic = 'famalth_classic';
  static const famalthOcean = 'famalth_ocean';
  static const famalthForest = 'famalth_forest';

  static const availableThemes = <String, String>{
    famalthClassic: 'Famalth Classic',
    famalthOcean: 'Famalth Ocean',
    famalthForest: 'Famalth Forest',
  };

  static ThemeData getTheme(String key) {
    switch (key) {
      case famalthOcean:
        return _buildTheme(
          seed: const Color(0xFF0F4C81),
          secondary: const Color(0xFF2A9D8F),
          scaffold: const Color(0xFFF2F7FB),
        );
      case famalthForest:
        return _buildTheme(
          seed: const Color(0xFF1F6E43),
          secondary: const Color(0xFFC98F2D),
          scaffold: const Color(0xFFF3F7F2),
        );
      case famalthClassic:
      default:
        return _buildTheme(
          seed: const Color(0xFF0B5CAD),
          secondary: const Color(0xFF0F766E),
          scaffold: const Color(0xFFF4F7FB),
        );
    }
  }

  static ThemeData _buildTheme({
    required Color seed,
    required Color secondary,
    required Color scaffold,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      secondary: secondary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: seed.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
