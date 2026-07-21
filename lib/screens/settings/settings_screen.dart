import 'package:flutter/material.dart';
import 'package:retailpos/screens/recovery/backup_service.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../controllers/settings/app_branding_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/settings/theme_controller.dart';
import '../../controllers/settings/ui_preferences_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../models/settings/app_branding_model.dart';
import '../../controllers/sales/sales_controller.dart';
import 'commission_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _taxModes = [
    'CGST_SGST',
    'IGST',
    'VAT',
    'CESS',
    'CUSTOM',
    'NONE',
  ];
  static const _billFormats = [
    'A4',
    'THERMAL_58',
    'THERMAL_72',
    'THERMAL_76',
    'THERMAL_80',
  ];
  static const _taxTypes = ['GST', 'VAT', 'CESS', 'OTHER'];
  static const _printModes = [
    'PRINT_DIALOG',
    'ASK_BEFORE_PRINT',
    'DIRECT_DEFAULT',
  ];
  List<Printer> _printers = const [];
  bool _loadingPrinters = false;
  bool _showNotifications = true;
  bool _didLoadBranding = false;
  bool _isCreatingEncBackup = false;
  AppBrandingModel _branding = AppBrandingModel.defaults();
  List<Map<String, dynamic>> _settingsSaleSources = [];
  List<Map<String, dynamic>> _settingsPaymentMethods = [];
  bool _loadingSettingsData = false;

  bool get _isAdmin => PermissionService.user?.role == 'ADMIN';

  String _billFormatLabel(String format) {
    switch (format) {
      case 'THERMAL_58':
        return '58mm Thermal';
      case 'THERMAL_72':
        return '72mm Thermal';
      case 'THERMAL_76':
        return '76mm Thermal';
      case 'THERMAL_80':
        return '80mm Thermal';
      default:
        return 'A4 Invoice';
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SystemSettingsController>().load());
    Future.microtask(
        () => context.read<AppBrandingController>().loadFromServer());
    Future.microtask(_loadPrinters);
    Future.microtask(_loadLocalPreferences);
    Future.microtask(_loadSettingsData);
  }

  Future<void> _loadLocalPreferences() async {
    final showNotifications = await LocalPreferences.getShowNotifications();
    if (!mounted) return;
    setState(() => _showNotifications = showNotifications);
  }

  Future<void> _openFavoritesManager() async {
    final favorites = (await LocalPreferences.getFavoriteDrawerItems()).toSet();
    final allFeatures = [
      {'label': 'Purchase Order', 'category': 'Operations'},
      {'label': 'Item Request', 'category': 'Operations'},
      {'label': 'Receive from Vendor', 'category': 'Operations'},
      {'label': 'Retail Sales', 'category': 'Operations'},
      {'label': 'Stock Dispatch', 'category': 'Operations'},
      {'label': 'Stock Transfer', 'category': 'Operations'},
      {'label': 'Stock Adjustment', 'category': 'Operations'},
      {'label': 'Master Items', 'category': 'Masters'},
      {'label': 'Departments', 'category': 'Masters'},
      {'label': 'Vendors / Suppliers', 'category': 'Masters'},
      {'label': 'Customers / Debtors', 'category': 'Masters'},
      {'label': 'Stock View', 'category': 'Stock View'},
      {'label': 'Reports', 'category': 'Reports'},
      {'label': 'System Settings', 'category': 'System'},
    ];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFFFB800)),
                  SizedBox(width: 8),
                  Text('Navigation Favorites', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 420,
                height: 440,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check the features you want pinned directly to the top FAVORITES section in your sidebar drawer:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: allFeatures.map((item) {
                          final label = item['label']!;
                          final category = item['category']!;
                          final isFav = favorites.contains(label);

                          return CheckboxListTile(
                            dense: true,
                            value: isFav,
                            activeColor: const Color(0xFFFFB800),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(category, style: const TextStyle(fontSize: 11)),
                            onChanged: (val) async {
                              setDialogState(() {
                                if (isFav) {
                                  favorites.remove(label);
                                } else {
                                  favorites.add(label);
                                }
                              });
                              await LocalPreferences.setFavoriteDrawerItems(favorites.toList());
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Save & Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    try {
      final printers = await Printing.listPrinters();
      if (!mounted) return;
      setState(() => _printers = printers);
    } catch (_) {
      if (!mounted) return;
      setState(() => _printers = const []);
    } finally {
      if (mounted) {
        setState(() => _loadingPrinters = false);
      }
    }
  }

  Future<void> _showClearTransactionDataDialog() async {
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_forever,
                            color: Colors.red, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Clear Transaction Data',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This permanently removes stock, sales, purchase, finance, and report records for the current database. Master data, settings, and schema version are preserved.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Type DELETE ALL DATA to continue',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: confirmController,
                          decoration: const InputDecoration(
                            hintText: 'DELETE ALL DATA',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Delete Now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final confirmText = confirmController.text.trim();
    if (confirmText.toUpperCase() != 'DELETE ALL DATA') {
      showErrorSnackbar('Please type DELETE ALL DATA to continue');
      return;
    }

    try {
      await ApiClient.post('/api/inventory/settings/clear-transaction-data', {
        'confirm_text': confirmText,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction data deleted successfully')),
      );
    } catch (_) {}
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SystemSettingsController>();
    final themeCtrl = context.watch<ThemeController>();
    final uiPrefsCtrl = context.watch<UiPreferencesController>();
    final brandingCtrl = context.watch<AppBrandingController>();

    if (!_didLoadBranding && !brandingCtrl.loading) {
      _didLoadBranding = true;
      _branding = brandingCtrl.branding;
    }

    if (ctrl.loading || ctrl.settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final s = ctrl.settings!;
    final selectedPrinterValue = _printers.any(
      (printer) => printer.url == s.defaultPrinterUrl,
    )
        ? s.defaultPrinterUrl
        : null;

    Future<void> saveAllSettings() async {
      await LocalPreferences.setShowNotifications(_showNotifications);
      await ctrl.save(s);
      await brandingCtrl.save(
        _branding.copyWith(themeKey: themeCtrl.themeKey),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }

    Widget buildSaveBar() {
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
          onPressed: saveAllSettings,
        ),
      );
    }

    Widget buildTabBody(List<Widget> sections, BoxConstraints constraints) {
      final horizontalPadding = constraints.maxWidth >= 1200 ? 40.0 : 20.0;
      return ListView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  const SizedBox(height: 24),
                  buildSaveBar(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF121214)
            : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Operations'),
              Tab(text: 'Security & Gateways'),
              Tab(text: 'Appearance'),
              Tab(text: 'Billing & Print'),
              Tab(text: 'Branding'),
              Tab(text: 'Keyboard Shortcuts'),
              Tab(text: 'Sale & Payment'),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return TabBarView(
              children: [
                // 1. OPERATIONS TAB
                buildTabBody([
                  _customSection(
                    'Inventory Settings',
                    'Configure behaviors and triggers for product inventory management.',
                    [
                      _settingRow(
                        title: 'Enable Auto Reorder Alert',
                        description: 'Notify when stock falls below specified reorder thresholds',
                        control: Switch.adaptive(
                          value: s.autoReorder,
                          onChanged: (v) => setState(() => s.autoReorder = v),
                        ),
                      ),
                      _settingRow(
                        title: 'Allow Negative Stock',
                        description: 'Allow issue/sale transactions even if current stock is zero or insufficient',
                        control: Switch.adaptive(
                          value: s.allowNegativeStock,
                          onChanged: (v) => setState(() => s.allowNegativeStock = v),
                        ),
                      ),
                      _settingRow(
                        title: 'Show Item Images in Sales',
                        description: 'Display item photographs directly on the POS sale screen',
                        isLast: true,
                        control: Switch.adaptive(
                          value: s.enableItemImagesInSales,
                          onChanged: (v) => setState(() => s.enableItemImagesInSales = v),
                        ),
                      ),
                    ],
                  ),
                  _customSection(
                    'Subscription Delivery',
                    'Manage automated workflows for daily recurring orders.',
                    [
                      _settingRow(
                        title: 'Enable Home Delivery Subscription (From App or Store)',
                        description: 'Enable home delivery subscriptions when subscribing from the Customer App or from the Store',
                        isLast: !s.enableAppSubscription,
                        control: Switch.adaptive(
                          value: s.enableAppSubscription,
                          onChanged: (v) => setState(() {
                            s.enableAppSubscription = v;
                            if (!v) {
                              s.subDeliveryChargeEnabled = false;
                            }
                          }),
                        ),
                      ),
                      if (s.enableAppSubscription) ...[
                        _settingRow(
                          title: 'Apply Delivery Charges for Subscription',
                          description: 'Enable additional home delivery charges on subscription orders',
                          isLast: !s.subDeliveryChargeEnabled,
                          control: Switch.adaptive(
                            value: s.subDeliveryChargeEnabled,
                            onChanged: (v) => setState(() => s.subDeliveryChargeEnabled = v),
                          ),
                        ),
                        if (s.subDeliveryChargeEnabled) ...[
                          _settingRow(
                            title: 'Delivery Charges Name',
                            description: 'Label shown on receipts and reports (e.g. Home Delivery Charges)',
                            control: SizedBox(
                              width: 280,
                              child: TextFormField(
                                initialValue: s.subDeliveryChargeName,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                onChanged: (v) => s.subDeliveryChargeName = v.trim(),
                              ),
                            ),
                          ),
                          _settingRow(
                            title: 'Delivery Charge Type',
                            description: 'Charge structure: Flat fee per day or percentage of daily subtotal',
                            control: SizedBox(
                              width: 280,
                              child: DropdownButtonFormField<String>(
                                value: s.subDeliveryChargeType,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                items: const [
                                  DropdownMenuItem(value: 'FLAT', child: Text('Flat Rate per Day')),
                                  DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage of Subtotal')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => s.subDeliveryChargeType = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          _settingRow(
                            title: 'Delivery Charge Value',
                            description: 'Daily charge amount (in Rs. or % depending on type)',
                            control: SizedBox(
                              width: 280,
                              child: TextFormField(
                                initialValue: s.subDeliveryChargeAmount.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                onChanged: (v) => s.subDeliveryChargeAmount = double.tryParse(v.trim()) ?? 0.0,
                              ),
                            ),
                          ),
                          _settingRow(
                            title: 'GST on Delivery Charges (%)',
                            description: 'Tax rate applicable specifically to subscription delivery charges',
                            control: SizedBox(
                              width: 280,
                              child: TextFormField(
                                initialValue: s.subDeliveryChargeGstPercent.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                onChanged: (v) => s.subDeliveryChargeGstPercent = double.tryParse(v.trim()) ?? 0.0,
                              ),
                            ),
                          ),
                          _settingRow(
                            title: 'Free Delivery Threshold Amount',
                            description: 'Subscriptions with daily value (subtotal + tax per day) above this threshold will have free delivery (0 to disable)',
                            isLast: true,
                            control: SizedBox(
                              width: 280,
                              child: TextFormField(
                                initialValue: s.subDeliveryFreeAbove.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                onChanged: (v) => s.subDeliveryFreeAbove = double.tryParse(v.trim()) ?? 0.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  _customSection(
                    'Approval Rules',
                    'Set authorization constraints for warehouse managers.',
                    [
                      _settingRow(
                        title: 'Damage Approval Required',
                        description: 'Require manager approval/authorization before writing off damaged items',
                        isLast: true,
                        control: Switch.adaptive(
                          value: s.damageApprovalRequired,
                          onChanged: (v) => setState(() => s.damageApprovalRequired = v),
                        ),
                      ),
                    ],
                  ),
                  _customSection(
                    'Audit & Compliance',
                    'Maintain system logs and dashboard communication.',
                    [
                      _settingRow(
                        title: 'Enable Audit Log',
                        description: 'Log all warehouse stock updates, edits, and deletions for security review',
                        control: Switch.adaptive(
                          value: s.enableAuditLog,
                          onChanged: (v) => setState(() => s.enableAuditLog = v),
                        ),
                      ),
                      _settingRow(
                        title: 'Show Notifications',
                        description: 'Show app alerts and desktop warnings in the administrator console',
                        control: Switch.adaptive(
                          value: _showNotifications,
                          onChanged: (v) => setState(() => _showNotifications = v),
                        ),
                      ),
                      _settingRow(
                        title: 'Customize Navigation Favorites',
                        description: 'Select features to pin directly to the FAVORITES section in your sidebar drawer',
                        isLast: true,
                        control: ElevatedButton.icon(
                          onPressed: _openFavoritesManager,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB800).withOpacity(0.15),
                            foregroundColor: const Color(0xFFD97706),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
                          label: const Text('Manage Favorites', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ], constraints),

                // 2. SECURITY & GATEWAYS TAB
                buildTabBody([
                  if (AppConfig.isLocalServer)
                    _customSection(
                      'Data & Security',
                      'Manage your cloud configuration and manual offline backups.',
                      [
                        _settingRow(
                          title: 'Enable Cloud Backup',
                          description: 'Automatically sync your store data to the Cloud',
                          control: Switch.adaptive(
                            value: s.isCloudEnabled,
                            onChanged: (bool newValue) async {
                              setState(() => s.isCloudEnabled = newValue);
                              final success = await BackupService.toggleCloudSync(newValue);
                              ctrl.save(s);
                              if (mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(newValue
                                          ? 'Cloud backup enabled successfully!'
                                          : 'Cloud backup paused.'),
                                      backgroundColor: newValue ? Colors.green : Colors.orange,
                                    ),
                                  );
                                } else {
                                  setState(() => s.isCloudEnabled = !newValue);
                                  showErrorSnackbar('Failed to update setting. Check internet.');
                                }
                              }
                            },
                          ),
                        ),
                        _settingRow(
                          title: 'Create Manual Backup',
                          description: 'Encrypt your local database and save to Downloads folder.',
                          isLast: true,
                          control: FilledButton.icon(
                            onPressed: _isCreatingEncBackup
                                ? null
                                : () async {
                                    setState(() => _isCreatingEncBackup = true);
                                    try {
                                      final savedPath = await BackupService.createAndSaveLocalEncBackup();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('.enc backup saved to $savedPath'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      showErrorSnackbar('Failed to create backup: $e');
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isCreatingEncBackup = false);
                                      }
                                    }
                                  },
                            icon: _isCreatingEncBackup
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.enhanced_encryption_outlined, size: 18),
                            label: Text(_isCreatingEncBackup ? 'Backing up...' : 'Create .enc Backup'),
                          ),
                        ),
                      ],
                    ),
                  _customSection(
                    'Payment Gateway & UPI (Beta)',
                    'Configure digital checkout APIs and direct merchant QR billing.',
                    [
                      _settingRow(
                        title: 'Enable Payment Gateway',
                        description: 'Require online payments for customer app delivery orders',
                        isLast: !s.enablePaymentGateway && s.merchantUpiId.isEmpty,
                        control: Switch.adaptive(
                          value: s.enablePaymentGateway,
                          onChanged: (v) => setState(() {
                            s.enablePaymentGateway = v;
                            if (!v) {
                              s.paymentGatewayProvider = 'SANDBOX';
                            }
                          }),
                        ),
                      ),
                      if (s.enablePaymentGateway) ...[
                        _settingRow(
                          title: 'Payment Gateway Provider',
                          description: 'Choose your secure processing merchant partner',
                          control: SizedBox(
                            width: 280,
                            child: DropdownButtonFormField<String>(
                              value: s.paymentGatewayProvider,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              items: ['SANDBOX', 'RAZORPAY', 'STRIPE', 'PAYTM']
                                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => s.paymentGatewayProvider = val);
                                }
                              },
                            ),
                          ),
                        ),
                        _settingRow(
                          title: 'API Key / Merchant ID',
                          description: 'Public identifier supplied by the gateway developer console',
                          control: SizedBox(
                            width: 280,
                            child: TextFormField(
                              initialValue: s.paymentGatewayApiKey,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onChanged: (val) => s.paymentGatewayApiKey = val.trim(),
                            ),
                          ),
                        ),
                        _settingRow(
                          title: 'API Secret / Salt Key',
                          description: 'Private credential used to sign checkout requests securely',
                          isLast: s.merchantUpiId.isEmpty,
                          control: SizedBox(
                            width: 280,
                            child: TextFormField(
                              initialValue: s.paymentGatewaySecretKey,
                              obscureText: true,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onChanged: (val) => s.paymentGatewaySecretKey = val.trim(),
                            ),
                          ),
                        ),
                      ],
                      _settingRow(
                        title: 'Direct Merchant UPI ID',
                        description: 'e.g. storename@okaxis. Enables direct UPI QR generation if payment gateway is off.',
                        isLast: true,
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            initialValue: s.merchantUpiId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            onChanged: (val) => s.merchantUpiId = val.trim(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isAdmin)
                    _customSection(
                      'Danger Zone',
                      'High-risk administrative operations.',
                      [
                        _settingRow(
                          title: 'Clear All Transaction Data',
                          description: 'Wipes transaction logs, sales, GRNs, and ledger items. Master catalogs are preserved.',
                          isLast: true,
                          control: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _showClearTransactionDataDialog,
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Clear Transaction Data'),
                          ),
                        ),
                      ],
                    ),
                ], constraints),

                // 2. APPEARANCE TAB
                buildTabBody([
                  _customSection(
                    'Design System Presets',
                    'Quickly format layout shapes to match enterprise guidelines.',
                    [
                      _settingRow(
                        title: 'Microsoft Fluent Preset',
                        description: 'Instantly apply compact, flat-edged buttons and rectangular inputs for a sleek workspace layout.',
                        isLast: true,
                        control: FilledButton(
                          onPressed: () async {
                            await themeCtrl.updateTheme(AppTheme.microsoftFluent);
                            await uiPrefsCtrl.updateTouchMode(false);
                            await uiPrefsCtrl.updateTextfieldSize('compact');
                            await uiPrefsCtrl.updateTextfieldBorderStyle('rectangular');
                            await uiPrefsCtrl.updateCardColorStyle('white');
                            await uiPrefsCtrl.updateCardBorderStyle('flat');
                            await uiPrefsCtrl.updateButtonBorderStyle('flat');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Microsoft Fluent Preset theme applied!')),
                              );
                            }
                          },
                          child: const Text('Apply Preset'),
                        ),
                      ),
                    ],
                  ),
                  _customSection(
                    'Interface Customization',
                    'Configure spacing, sizing parameters, shapes, and color configurations.',
                    [
                      _settingRow(
                        title: 'Touch Screen Mode',
                        description: 'Increases size of tap targets and adjusts list spacing for touchscreen users',
                        control: Switch.adaptive(
                          value: uiPrefsCtrl.touchMode,
                          onChanged: (v) => uiPrefsCtrl.updateTouchMode(v),
                        ),
                      ),
                      _settingRow(
                        title: 'Default Startup Screen',
                        description: 'Determine which dashboard loads first upon log-in',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.defaultStartupScreen,
                            items: const [
                              DropdownMenuItem(value: 'INVENTORY_DASHBOARD', child: Text('Warehouse Dashboard')),
                              DropdownMenuItem(value: 'RETAIL_SALES', child: Text('Retail Dashboard')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateDefaultStartupScreen(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Application Palette Theme',
                        description: 'Change the overall theme color scheme of the console',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: themeCtrl.themeKey,
                            items: AppTheme.availableThemes.entries
                                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                themeCtrl.updateTheme(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Textfield Spacing Density',
                        description: 'Select heights for forms, search fields, and transaction rows',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.textfieldSize,
                            items: const [
                              DropdownMenuItem(value: 'extra_compact', child: Text('Extra Compact')),
                              DropdownMenuItem(value: 'compact', child: Text('Compact')),
                              DropdownMenuItem(value: 'normal', child: Text('Normal (Default)')),
                              DropdownMenuItem(value: 'comfortable', child: Text('Comfortable')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateTextfieldSize(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Textfield Border Styling',
                        description: 'Modify input text field corner visual properties',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.textfieldBorderStyle,
                            items: const [
                              DropdownMenuItem(value: 'rounded', child: Text('Rounded Borders')),
                              DropdownMenuItem(value: 'rectangular', child: Text('Rectangular Borders')),
                              DropdownMenuItem(value: 'underlined', child: Text('Underlined Only')),
                              DropdownMenuItem(value: 'none', child: Text('No Borders (Borderless)')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateTextfieldBorderStyle(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Global Card Background Color',
                        description: 'Fine-tune color tint and card panel backgrounds',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.cardColorStyle,
                            items: const [
                              DropdownMenuItem(value: 'soft', child: Text('Soft Surface')),
                              DropdownMenuItem(value: 'white', child: Text('Plain White')),
                              DropdownMenuItem(value: 'tint', child: Text('Theme Tint')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateCardColorStyle(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Global Card Shape',
                        description: 'Select corner radius attributes for details cards and containers',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.cardBorderStyle,
                            items: const [
                              DropdownMenuItem(value: 'rounded', child: Text('Rounded Corners')),
                              DropdownMenuItem(value: 'less_rounded', child: Text('Less Rounded')),
                              DropdownMenuItem(value: 'flat', child: Text('Flat (Sharp Corners)')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateCardBorderStyle(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Global Button Shape',
                        description: 'Modify corner roundness configurations for interactive button surfaces',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.buttonBorderStyle,
                            items: const [
                              DropdownMenuItem(value: 'rounded', child: Text('Rounded Corners')),
                              DropdownMenuItem(value: 'less_rounded', child: Text('Less Rounded')),
                              DropdownMenuItem(value: 'flat', child: Text('Flat (Sharp Corners)')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateButtonBorderStyle(value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Global Text Size Scale',
                        description: 'Change core app system font scale attributes',
                        isLast: true,
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: uiPrefsCtrl.fontSizeAdjustment,
                            items: const [
                              DropdownMenuItem(value: 'small', child: Text('Small')),
                              DropdownMenuItem(value: 'normal', child: Text('Normal (Default)')),
                              DropdownMenuItem(value: 'large', child: Text('Large')),
                              DropdownMenuItem(value: 'extra_large', child: Text('Extra Large')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                uiPrefsCtrl.updateFontSizeAdjustment(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ], constraints),

                // 3. BILLING & PRINT TAB
                buildTabBody([
                  _customSection(
                    'Printing Config',
                    'Receipt printing triggers, defaults, and printer outputs.',
                    [
                      _settingRow(
                        title: 'Auto Print on Save',
                        description: 'Directly send receipt print task immediately upon document save',
                        control: Switch.adaptive(
                          value: s.autoPrintOnSave,
                          onChanged: (v) => setState(() => s.autoPrintOnSave = v),
                        ),
                      ),
                      _settingRow(
                        title: 'Invoicing Print Mode',
                        description: 'Select printing dialog workflow trigger style',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: s.printMode,
                            items: _printModes
                                .map((mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(
                                        mode == 'PRINT_DIALOG'
                                            ? 'Open Print Dialog'
                                            : mode == 'ASK_BEFORE_PRINT'
                                                ? 'Ask Yes / No'
                                                : 'Direct Print (Selected Printer)',
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => s.printMode = value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Default Printer Device',
                        description: 'Target printer for system defaults or silent printing',
                        isLast: true,
                        control: SizedBox(
                          width: 280,
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: selectedPrinterValue,
                                  items: _printers
                                      .map((printer) => DropdownMenuItem(
                                            value: printer.url,
                                            child: Text(
                                              printer.name + (printer.isDefault ? ' (System Default)' : ''),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    final printer = _printers.cast<Printer?>().firstWhere(
                                          (entry) => entry?.url == value,
                                          orElse: () => null,
                                        );
                                    setState(() {
                                      s.defaultPrinterUrl = value ?? '';
                                      s.defaultPrinterName = printer?.name ?? '';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _loadingPrinters ? null : _loadPrinters,
                                icon: _loadingPrinters
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _customSection(
                    'Global Invoicing Details',
                    'Configure standard tax regimes, invoice formats, and country rules.',
                    [
                      _settingRow(
                        title: 'Billing Country',
                        description: 'Preselect default tax configurations and regional specifications',
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            initialValue: s.billingCountry,
                            onChanged: (value) => s.billingCountry = value.trim().isEmpty ? 'India' : value.trim(),
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Default Billing Tax Mode',
                        description: 'Configure active regional tax compliance formats',
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: s.billingTaxMode,
                            items: _taxModes
                                .map((mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode.replaceAll('_', ' ')),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => s.billingTaxMode = value);
                              }
                            },
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Default Invoice Output Format',
                        description: 'Select invoice document paper dimensions',
                        isLast: true,
                        control: SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: s.billFormat,
                            items: _billFormats
                                .map((format) => DropdownMenuItem(
                                      value: format,
                                      child: Text(_billFormatLabel(format)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => s.billFormat = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  _customSection(
                    'Default Billing Charges',
                    'Configure auto-applied packaging, delivery, or custom surcharges.',
                    [
                      ...List.generate(
                        s.defaultCharges.length,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: _chargeTile(
                            s.defaultCharges[index],
                            onChanged: (updated) {
                              setState(() => s.defaultCharges[index] = updated);
                            },
                            onDelete: s.defaultCharges.length <= 1
                                ? null
                                : () {
                                    setState(() => s.defaultCharges.removeAt(index));
                                  },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, bottom: 16.0, top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                s.defaultCharges.add(
                                  const BillingCharge(
                                    name: 'Custom',
                                    code: 'CUSTOM',
                                    amount: 0,
                                    calculationValue: 0,
                                    taxable: false,
                                    autoApply: false,
                                    isEnabled: false,
                                    taxType: 'GST',
                                    taxPercent: 0,
                                  ),
                                );
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Charge Rule'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ], constraints),

                // 4. BRANDING TAB
                buildTabBody([
                  _customSection(
                    'Store Branding & Support Metadata',
                    'Customize invoice labels, support emails, contact phone lines, and websites.',
                    [
                      _settingRow(
                        title: 'Company / Organization Name',
                        description: 'Primary legal business name printed at the top of bills',
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            key: ValueKey('branding-company-${_branding.companyName}'),
                            initialValue: _branding.companyName,
                            onChanged: (value) => _branding = _branding.copyWith(companyName: value),
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Product / System Name',
                        description: 'Primary label for title bars and login screens',
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            key: ValueKey('branding-product-${_branding.productName}'),
                            initialValue: _branding.productName,
                            onChanged: (value) => _branding = _branding.copyWith(productName: value),
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Powered By Tagline',
                        description: 'Footer attribution copyright label printed on reports',
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            key: ValueKey('branding-powered-${_branding.poweredByLabel}'),
                            initialValue: _branding.poweredByLabel,
                            onChanged: (value) => _branding = _branding.copyWith(poweredByLabel: value),
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Support Desk Email',
                        description: 'Target contact email address for customer tickets',
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            key: ValueKey('branding-email-${_branding.supportEmail}'),
                            initialValue: _branding.supportEmail,
                            onChanged: (value) => _branding = _branding.copyWith(supportEmail: value),
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Support Desk Phone',
                        description: 'Contact helpline phone number shown on support panels',
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            key: ValueKey('branding-phone-${_branding.supportPhone}'),
                            initialValue: _branding.supportPhone,
                            onChanged: (value) => _branding = _branding.copyWith(supportPhone: value),
                          ),
                        ),
                      ),
                      _settingRow(
                        title: 'Support Website URL',
                        description: 'Reference business website domain linked in footer',
                        isLast: true,
                        control: SizedBox(
                          width: 280,
                          child: TextFormField(
                            key: ValueKey('branding-web-${_branding.supportWebsite}'),
                            initialValue: _branding.supportWebsite,
                            onChanged: (value) => _branding = _branding.copyWith(supportWebsite: value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ], constraints),

                // 5. KEYBOARD SHORTCUTS TAB
                buildTabBody([
                  _customSection(
                    'Keyboard Shortcuts Guide',
                    'Use hotkeys to quickly navigate screens without using a mouse.',
                    [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildKeyboardShortcutsSection(Theme.of(context)),
                      ),
                    ],
                  ),
                ], constraints),

                // 6. SALE & PAYMENT TAB
                buildTabBody([
                  _customSection(
                    'Sale Channels & Payment Options',
                    'Manage customized sale channels and payment options used during checkouts.',
                    [
                      if (_loadingSettingsData)
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _saleSourcesSettingsSection(),
                        const Divider(),
                        _paymentMethodsSettingsSection(),
                      ]
                    ],
                  ),
                ], constraints),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadSettingsData() async {
    setState(() => _loadingSettingsData = true);
    try {
      final salesCtrl = SalesController();
      final sources = await salesCtrl.listSaleSources();
      final methods = await salesCtrl.listPaymentMethods();
      setState(() {
        _settingsSaleSources = sources;
        _settingsPaymentMethods = methods;
      });
    } catch (_) {}
    setState(() => _loadingSettingsData = false);
  }

  Future<void> _toggleSourceActive(int id, String name, bool val) async {
    try {
      final salesCtrl = SalesController();
      await salesCtrl.updateSaleSource(id, name: name, isActive: val);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale source status updated')),
      );
      _loadSettingsData();
    } catch (e) {
      showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteSource(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale Source'),
        content: const Text('Are you sure you want to delete this sale source? This will fail if it has already been used in sales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final salesCtrl = SalesController();
      await salesCtrl.deleteSaleSource(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale source deleted successfully')),
      );
      _loadSettingsData();
    } catch (e) {
      showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showAddEditSourceDialog({Map<String, dynamic>? source}) async {
    final isEdit = source != null;
    final nameCtrl = TextEditingController(text: isEdit ? source['name'] : '');
    final commissionCtrl = TextEditingController(text: isEdit ? (source['commission_rate'] ?? 0.0).toString() : '0.0');
    final gstCtrl = TextEditingController(text: isEdit ? (source['gst_rate_on_commission'] ?? 0.0).toString() : '0.0');
    final tdsCtrl = TextEditingController(text: isEdit ? (source['tds_rate'] ?? 0.0).toString() : '0.0');
    final tcsCtrl = TextEditingController(text: isEdit ? (source['tcs_rate'] ?? 0.0).toString() : '0.0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Sale Source' : 'Add Sale Source'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Source Name', hintText: 'e.g. Flipkart, Amazon, Meesho'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commissionCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Commission Rate (%)', hintText: '0.00'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gstCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'GST on Commission (%)', hintText: '0.00'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tdsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'TDS Rate (%)', hintText: '0.00'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tcsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'TCS Rate (%)', hintText: '0.00'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final commission = double.tryParse(commissionCtrl.text.trim()) ?? 0.0;
              final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
              final tds = double.tryParse(tdsCtrl.text.trim()) ?? 0.0;
              final tcs = double.tryParse(tcsCtrl.text.trim()) ?? 0.0;

              try {
                final salesCtrl = SalesController();
                if (isEdit) {
                  await salesCtrl.updateSaleSource(
                    source['id'],
                    name: name,
                    isActive: source['is_active'] == true,
                    commissionRate: commission,
                    gstRateOnCommission: gst,
                    tdsRate: tds,
                    tcsRate: tcs,
                  );
                } else {
                  await salesCtrl.createSaleSource(
                    name,
                    commissionRate: commission,
                    gstRateOnCommission: gst,
                    tdsRate: tds,
                    tcsRate: tcs,
                  );
                }
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Sale source updated' : 'Sale source added')),
                );
                _loadSettingsData();
              } catch (e) {
                showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePaymentMethodActive(int id, String name, bool val) async {
    try {
      final salesCtrl = SalesController();
      await salesCtrl.updatePaymentMethod(id, name: name, isActive: val);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment method status updated')),
      );
      _loadSettingsData();
    } catch (e) {
      showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePaymentMethod(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: const Text('Are you sure you want to delete this payment method? This will fail if it has already been used in sales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final salesCtrl = SalesController();
      await salesCtrl.deletePaymentMethod(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment method deleted successfully')),
      );
      _loadSettingsData();
    } catch (e) {
      showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showAddEditPaymentMethodDialog({Map<String, dynamic>? method}) async {
    final isEdit = method != null;
    final nameCtrl = TextEditingController(text: isEdit ? method['name'] : '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Payment Method' : 'Add Payment Method'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Payment Method Name', hintText: 'e.g. PHONEPE, GPAY, PAYTM'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                final salesCtrl = SalesController();
                if (isEdit) {
                  await salesCtrl.updatePaymentMethod(method['id'], name: name, isActive: method['is_active'] == true);
                } else {
                  await salesCtrl.createPaymentMethod(name);
                }
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Payment method updated' : 'Payment method added')),
                );
                _loadSettingsData();
              } catch (e) {
                showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _saleSourcesSettingsSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sale Sources / Channels',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CommissionRulesScreen()),
                      );
                    },
                    icon: const Icon(Icons.rule_folder_rounded, size: 18),
                    label: const Text('Configure Commission Rules'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _showAddEditSourceDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Source'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _settingsSaleSources.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No custom sale sources added yet.')),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _settingsSaleSources.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final src = _settingsSaleSources[index];
                  final isSystem = src['is_system'] == true;
                  final isActive = src['is_active'] == true;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(src['name'].toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSystem)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'System',
                              style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: isActive,
                          onChanged: isSystem
                              ? null
                              : (val) => _toggleSourceActive(src['id'], src['name'], val),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: isSystem
                              ? null
                              : () => _showAddEditSourceDialog(source: src),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: isSystem
                              ? null
                              : () => _deleteSource(src['id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _paymentMethodsSettingsSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Methods',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showAddEditPaymentMethodDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Method'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _settingsPaymentMethods.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No custom payment methods added yet.')),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _settingsPaymentMethods.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final method = _settingsPaymentMethods[index];
                  final isSystem = method['is_system'] == true;
                  final isActive = method['is_active'] == true;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(method['name'].toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSystem)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'System',
                              style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: isActive,
                          onChanged: isSystem
                              ? null
                              : (val) => _togglePaymentMethodActive(method['id'], method['name'], val),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: isSystem
                              ? null
                              : () => _showAddEditPaymentMethodDialog(method: method),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: isSystem
                              ? null
                              : () => _deletePaymentMethod(method['id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  // ---------------- UPGRADED LAYOUT BUILDERS ----------------

  Widget _customSection(String title, String? description, List<Widget> rows) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: rows,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _settingRow({
    required String title,
    required String description,
    required Widget control,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              control,
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
          ),
      ],
    );
  }

  Widget _chargeTile(
    BillingCharge charge, {
    required ValueChanged<BillingCharge> onChanged,
    VoidCallback? onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: charge.name,
                    decoration: const InputDecoration(labelText: 'Charge Name'),
                    onChanged: (value) => onChanged(
                      charge.copyWith(
                        name: value,
                        code: value.toUpperCase().replaceAll(' ', '_'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    initialValue: charge.calculationValue.toStringAsFixed(
                      charge.calculationValue % 1 == 0 ? 0 : 2,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: charge.calculationType == 'PERCENT' ? 'Percent' : 'Amount',
                    ),
                    onChanged: (value) => onChanged(
                      charge.copyWith(
                        amount: charge.calculationType == 'PERCENT'
                            ? charge.amount
                            : (double.tryParse(value.trim()) ?? 0),
                        calculationValue: double.tryParse(value.trim()) ?? 0,
                      ),
                    ),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto Apply'),
                    value: charge.autoApply,
                    onChanged: (value) => onChanged(charge.copyWith(autoApply: value, isEnabled: value)),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Taxable'),
                    value: charge.taxable,
                    onChanged: (value) => onChanged(charge.copyWith(taxable: value)),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: charge.isEnabled,
                    onChanged: (value) => onChanged(charge.copyWith(isEnabled: value)),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: charge.calculationType,
                    decoration: const InputDecoration(labelText: 'Charge Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'AMOUNT',
                        child: Text('Fixed Amount'),
                      ),
                      DropdownMenuItem(
                        value: 'PERCENT',
                        child: Text('Percentage'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged(
                        charge.copyWith(
                          calculationType: value,
                          amount: value == 'PERCENT' ? charge.amount : charge.calculationValue,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: charge.taxType,
                    decoration: const InputDecoration(labelText: 'Charge Tax Type'),
                    items: _taxTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: charge.taxable
                        ? (value) {
                            if (value != null) {
                              onChanged(charge.copyWith(taxType: value));
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    initialValue: charge.taxPercent.toStringAsFixed(
                      charge.taxPercent % 1 == 0 ? 0 : 2,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: charge.taxable,
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    onChanged: (value) => onChanged(
                      charge.copyWith(
                        taxPercent: double.tryParse(value.trim()) ?? 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardShortcutsSection(ThemeData theme) {
    Widget shortcutRow(String keyCombination, String actionDescription) {
      final isDark = theme.brightness == Brightness.dark;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2024) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 1.5),
                    blurRadius: 1,
                  )
                ],
              ),
              child: Text(
                keyCombination,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                actionDescription,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white60 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Use hotkeys to quickly navigate through screens and control operations without using a mouse.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text(
          'Global Navigation Shortcuts (Anywhere)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
        ),
        const Divider(),
        shortcutRow('Alt + S', 'Open Settings Panel'),
        shortcutRow('Alt + B', 'Open Retail POS Billing Console'),
        shortcutRow('Alt + I', 'Open Item Master'),
        shortcutRow('Alt + W', 'Open WhatsApp Integration Dashboard'),
        shortcutRow('Alt + H', 'Open Help & Support Panel'),
        shortcutRow('Alt + P', 'Open Purchase Order Console'),
        shortcutRow('Alt + G', 'Open Goods Receiving (GRN) Screen'),
        shortcutRow('Alt + R', 'Open Sales Report Console'),
        shortcutRow('Alt + C', 'Open Daily Closing Report Console'),
        shortcutRow('Alt + Y', 'Open Supplier Payments Report'),
        shortcutRow('Alt + F', 'Open Finance / Cash Ledger Console'),
        shortcutRow('Alt + A', 'Open Brand Analysis Report'),
        shortcutRow('Alt + K', 'Open Store Analysis / Stock Balance'),
        shortcutRow('Alt + D', 'Open Damage Item Console'),
        const SizedBox(height: 20),
        const Text(
          'POS Billing / Cart Shortcuts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
        ),
        const Divider(),
        shortcutRow('Enter / F1', 'Focus & search product in barcode scanner input field'),
        shortcutRow('F2', 'Trigger Checkout Payment dialog directly'),
        shortcutRow('Delete', 'Remove the currently selected/highlighted cart line item (or last item if none selected)'),
        shortcutRow('Escape', 'Close checkout popup / Clear barcode scanner input'),
      ],
    );
  }
}
