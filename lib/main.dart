import 'package:flutter/material.dart';
import 'package:retailpos/controllers/security/recovery_controller.dart';
import 'package:provider/provider.dart';

import 'controllers/security/user_controller.dart';
import 'controllers/settings/notification_services.dart';
import 'controllers/settings/app_branding_controller.dart';
import 'controllers/settings/system_settings_controller.dart';
import 'controllers/settings/theme_controller.dart';
import 'controllers/settings/ui_preferences_controller.dart';
import 'controllers/settings/theme_controller.dart';
import 'controllers/settings/ui_preferences_controller.dart';
import 'controllers/settings/app_branding_controller.dart';
import 'controllers/settings/system_settings_controller.dart';
import 'controllers/settings/theme_controller.dart';
import 'controllers/settings/ui_preferences_controller.dart';
import 'controllers/settings/app_branding_controller.dart';
import 'controllers/security/user_controller.dart';
import 'controllers/security/recovery_controller.dart';
import 'controllers/inventory/bom_controller.dart';
import 'core/config/app_config.dart';
import 'core/config/app_brand.dart';
import 'core/config/date_time_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'package:flutter/services.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/whatsapp_dashboard_screen.dart';
import 'screens/settings/help_screen.dart';
import 'screens/inventory/salescreen.dart';
import 'screens/inventory/item_master_screen.dart';
import 'screens/inventory/purchase_order_screen.dart';
import 'screens/inventory/goods_receiving_screen.dart';
import 'screens/inventory/damage_item_screen.dart';
import 'screens/reports/sales_report_screen.dart';
import 'screens/reports/brand_analysis_screen.dart';
import 'screens/reports/source_analysis_screen.dart';
import 'screens/reports/commission_report_screen.dart';
import 'screens/reports/payment_analysis_screen.dart';
import 'screens/reports/cash_ledger_screen.dart';
import 'screens/reports/stock_balance_screen.dart';
import 'screens/reports/supplier_payments_report_screen.dart';
import 'screens/reports/closing_report_screen.dart';

final GlobalKey<ScaffoldMessengerState> globalSnackbarKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await AppConfig.init();

  // ── Trusted Clock ──────────────────────────────────────────────────────
  // Anchor the app's clock to PostgreSQL server time so that sales/reports
  // always use the correct date, even if the system clock drifted (e.g.
  // PC woke from sleep with wrong BIOS date like year 2002 or May 2025).
  await DateTimeService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SystemSettingsController()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => UiPreferencesController()..load()),
        ChangeNotifierProvider(create: (_) => AppBrandingController()..loadLocal()),
        ChangeNotifierProvider(create: (_) => UserController()),
        ChangeNotifierProvider(create: (_) => RecoveryController()),
        ChangeNotifierProvider(create: (_) => BOMController()),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  final Widget? homeWidget;
  const MyApp({super.key, this.homeWidget});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final uiPrefs = context.watch<UiPreferencesController>();
    final brandingCtrl = context.watch<AppBrandingController>();
    final baseTheme = AppTheme.getTheme(themeCtrl.themeKey);
    final scheme = baseTheme.colorScheme;

    EdgeInsets textFieldPadding;
    double minInputHeight;
    switch (uiPrefs.textfieldSize) {
      case 'extra_compact':
        textFieldPadding = const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        );
        minInputHeight = 36;
        break;
      case 'compact':
        textFieldPadding = const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        );
        minInputHeight = 42;
        break;
      case 'comfortable':
        textFieldPadding = const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        );
        minInputHeight = 56;
        break;
      case 'normal':
      default:
        textFieldPadding = const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        );
        minInputHeight = 48;
        break;
    }

    Color resolvedCardColor;
    switch (uiPrefs.cardColorStyle) {
      case 'white':
        resolvedCardColor = scheme.surface;
        break;
      case 'tint':
        resolvedCardColor = scheme.surfaceContainer;
        break;
      case 'soft':
      default:
        resolvedCardColor = scheme.surfaceContainerLow;
        break;
    }

    final borderStyle = uiPrefs.textfieldBorderStyle;
    InputBorder border;
    InputBorder enabledBorder;
    InputBorder focusedBorder;
    InputBorder errorBorder;

    if (borderStyle == 'none') {
      border = InputBorder.none;
      enabledBorder = InputBorder.none;
      focusedBorder = InputBorder.none;
      errorBorder = InputBorder.none;
    } else if (borderStyle == 'underlined') {
      border = UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.outlineVariant),
      );
      enabledBorder = UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.outlineVariant),
      );
      focusedBorder = UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.primary, width: 2.0),
      );
      errorBorder = UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      );
    } else {
      final double fieldRadius = borderStyle == 'rectangular' ? 0.0 : 10.0;
      border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      );
      enabledBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      );
      focusedBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: scheme.primary, width: 2.0),
      );
      errorBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      );
    }

    final dynamicInputDecorationTheme = baseTheme.inputDecorationTheme.copyWith(
      contentPadding: textFieldPadding,
      constraints: BoxConstraints(minHeight: minInputHeight),
      border: border,
      enabledBorder: enabledBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
    );

    double cardRadius;
    switch (uiPrefs.cardBorderStyle) {
      case 'flat':
        cardRadius = 0.0;
        break;
      case 'less_rounded':
        cardRadius = 8.0;
        break;
      case 'rounded':
      default:
        cardRadius = 16.0;
        break;
    }

    double buttonRadius;
    switch (uiPrefs.buttonBorderStyle) {
      case 'flat':
        buttonRadius = 0.0;
        break;
      case 'less_rounded':
        buttonRadius = 6.0;
        break;
      case 'rounded':
      default:
        buttonRadius = 12.0;
        break;
    }

    double fontSizeScale;
    switch (uiPrefs.fontSizeAdjustment) {
      case 'small':
        fontSizeScale = 0.85;
        break;
      case 'large':
        fontSizeScale = 1.15;
        break;
      case 'extra_large':
        fontSizeScale = 1.3;
        break;
      case 'normal':
      default:
        fontSizeScale = 1.0;
        break;
    }

    TextTheme scaleTextTheme(TextTheme base, double factor) {
      if (factor == 1.0) return base;
      
      TextStyle? scaleStyle(TextStyle? style, double defaultSize) {
        if (style == null) return null;
        final double currentSize = style.fontSize ?? defaultSize;
        return style.copyWith(fontSize: currentSize * factor);
      }

      return TextTheme(
        displayLarge: scaleStyle(base.displayLarge, 57),
        displayMedium: scaleStyle(base.displayMedium, 45),
        displaySmall: scaleStyle(base.displaySmall, 36),
        headlineLarge: scaleStyle(base.headlineLarge, 32),
        headlineMedium: scaleStyle(base.headlineMedium, 28),
        headlineSmall: scaleStyle(base.headlineSmall, 24),
        titleLarge: scaleStyle(base.titleLarge, 22),
        titleMedium: scaleStyle(base.titleMedium, 16),
        titleSmall: scaleStyle(base.titleSmall, 14),
        bodyLarge: scaleStyle(base.bodyLarge, 16),
        bodyMedium: scaleStyle(base.bodyMedium, 14),
        bodySmall: scaleStyle(base.bodySmall, 12),
        labelLarge: scaleStyle(base.labelLarge, 14),
        labelMedium: scaleStyle(base.labelMedium, 12),
        labelSmall: scaleStyle(base.labelSmall, 11),
      );
    }

    final scaledTextTheme = scaleTextTheme(baseTheme.textTheme, fontSizeScale);

    final customCardTheme = CardThemeData(
      color: resolvedCardColor,
      elevation: baseTheme.cardTheme.elevation,
      shadowColor: baseTheme.cardTheme.shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: baseTheme.cardTheme.shape is RoundedRectangleBorder
            ? (baseTheme.cardTheme.shape as RoundedRectangleBorder).side
            : BorderSide.none,
      ),
    );

    final customFilledButtonStyle = (baseTheme.filledButtonTheme.style ?? FilledButton.styleFrom()).copyWith(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
      minimumSize: uiPrefs.touchMode
          ? WidgetStateProperty.all(const Size(0, 52))
          : null,
    );

    final customOutlinedButtonStyle = (baseTheme.outlinedButtonTheme.style ?? OutlinedButton.styleFrom()).copyWith(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
      minimumSize: uiPrefs.touchMode
          ? WidgetStateProperty.all(const Size(0, 52))
          : null,
    );

    final theme = baseTheme.copyWith(
      textTheme: scaledTextTheme,
      inputDecorationTheme: dynamicInputDecorationTheme,
      cardTheme: customCardTheme,
      filledButtonTheme: FilledButtonThemeData(style: customFilledButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: customOutlinedButtonStyle),
      visualDensity: uiPrefs.touchMode ? VisualDensity.comfortable : baseTheme.visualDensity,
      materialTapTargetSize: uiPrefs.touchMode ? MaterialTapTargetSize.padded : baseTheme.materialTapTargetSize,
    );

    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      scaffoldMessengerKey: globalSnackbarKey,
      debugShowCheckedModeBanner: false,
      title: brandingCtrl.branding.productName,
      theme: theme,
      builder: (context, child) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const SaleScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const ItemMasterScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyW, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const WhatsAppDashboardScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyH, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyP, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const PurchaseOrderScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyG, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const GoodsReceivingScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyD, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const DamageItemScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyR, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const SalesReportScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const ClosingReportScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyY, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const SupplierPaymentsReportScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyF, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const CashLedgerScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyA, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const BrandAnalysisScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyS, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const SourceAnalysisScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyP, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const PaymentAnalysisScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const StockBalanceScreen()));
            },
            const SingleActivator(LogicalKeyboardKey.keyO, alt: true): () {
              globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const CommissionReportScreen()));
            },
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: AppLifecycleObserver(
        child: homeWidget ?? const SplashScreen(),
      ),
    );
  }
}
/// Mixin that auto-resync DateTimeService when app resumes from background/sleep.
/// Usage: wrap MaterialApp home with this widget:
///   home: AppLifecycleObserver(child: SplashScreen())
class AppLifecycleObserver extends StatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync clock when app comes back from background / PC wakes from sleep.
      DateTimeService.instance.resync();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
