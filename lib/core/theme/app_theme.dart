import 'package:flutter/material.dart';

class AppCustomColors extends ThemeExtension<AppCustomColors> {
  final Color success;
  final Color warning;
  final Color info;
  final Color customBackground;

  const AppCustomColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.customBackground,
  });

  @override
  ThemeExtension<AppCustomColors> copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? customBackground,
  }) {
    return AppCustomColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      customBackground: customBackground ?? this.customBackground,
    );
  }

  @override
  ThemeExtension<AppCustomColors> lerp(
    covariant ThemeExtension<AppCustomColors>? other,
    double t,
  ) {
    if (other is! AppCustomColors) return this;
    return AppCustomColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      customBackground:
          Color.lerp(customBackground, other.customBackground, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static const famalthClassic = 'famalth_classic';
  static const famalthBlack = 'famalth_black';
  static const famalthOcean = 'famalth_ocean';
  static const famalthForest = 'famalth_forest';
  static const microsoftFluent = 'microsoft_fluent';

  static const availableThemes = <String, String>{
    famalthClassic: 'Famalth Classic',
    famalthOcean: 'Famalth Ocean',
    famalthForest: 'Famalth Forest',
    microsoftFluent: 'Microsoft Fluent (Enterprise)',
  };

  static List<Color> getHeroGradientColors(String key) {
    switch (key) {
      case famalthOcean:
        return const [
          Color(0xFF0F4C81),
          Color(0xFF1B4965),
          Color(0xFF2A9D8F),
        ];
      case famalthForest:
        return const [
          Color(0xFF1F6E43),
          Color(0xFF145233),
          Color(0xFF2D6A4F),
        ];
      case microsoftFluent:
        return const [
          Color(0xFF0078D4),
          Color(0xFF106EBE),
          Color(0xFF005A9E),
        ];
      case famalthClassic:
      case 'famalth_lynx':
      default:
        return const [
          Color(0xFF0B5CAD), // Corporate Blue
          Color(0xFF0F4C81), // Deep Royal Blue
          Color(0xFF1D4ED8), // Vibrant Accent Blue
        ];
    }
  }

  static ThemeData getTheme(String key, {bool isDark = false}) {
    final Brightness brightness = (key == famalthBlack || isDark)
        ? Brightness.dark
        : Brightness.light;

    switch (key) {
      case famalthBlack:
        return _buildTheme(
          seed: const Color(0xFF38BDF8), // Midnight Sky Primary
          secondary: const Color(0xFF818CF8),
          brightness: Brightness.dark,
        );
      case microsoftFluent:
        return _buildTheme(
          seed: const Color(0xFF0078D4), // Microsoft Communication Blue
          secondary: const Color(0xFF605E5C), // Fluent Charcoal/Gray
          brightness: brightness,
          radius: 4.0, // Fluent-style small rounded corners
        );
      case famalthOcean:
        return _buildTheme(
          seed: const Color(0xFF0F4C81),
          secondary: const Color(0xFF2A9D8F),
          brightness: brightness,
        );
      case famalthForest:
        return _buildTheme(
          seed: const Color(0xFF1F6E43),
          secondary: const Color(0xFFC98F2D),
          brightness: brightness,
        );
      case famalthClassic:
      case 'famalth_lynx':
      default:
        return _buildTheme(
          seed: const Color(0xFF0B5CAD),
          secondary: const Color(0xFF0F766E),
          brightness: brightness,
        );
    }
  }

  static ThemeData _buildTheme({
    required Color seed,
    required Color secondary,
    required Brightness brightness,
    double radius = 10.0,
  }) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      secondary: secondary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        AppCustomColors(
          success: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
          warning: isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00),
          info: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),
          customBackground:
              isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
        ),
      ],
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, letterSpacing: 0.1),
        bodyMedium: TextStyle(fontSize: 14, letterSpacing: 0.2),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: isDark ? 0 : 1,
        shadowColor: scheme.shadow.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: isDark
              ? BorderSide(color: scheme.outlineVariant, width: 1)
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStateProperty.all(scheme.surfaceContainerHighest),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius + 2)),
        backgroundColor: scheme.surfaceContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        backgroundColor: scheme.inverseSurface,
        actionTextColor: scheme.inversePrimary,
      ),
    );
  }
}
