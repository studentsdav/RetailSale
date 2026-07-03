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
  }

  Future<void> _loadLocalPreferences() async {
    final showNotifications = await LocalPreferences.getShowNotifications();
    if (!mounted) return;
    setState(() => _showNotifications = showNotifications);
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
          vertical: 18,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  const SizedBox(height: 20),
                  buildSaveBar(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Operations'),
              Tab(text: 'Appearance'),
              Tab(text: 'Billing & Print'),
              Tab(text: 'Branding'),
              Tab(text: 'Keyboard Shortcuts'),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return TabBarView(
              children: [
                buildTabBody([
                  if (AppConfig.isLocalServer)
                    _section('Data & Security', [
                      _switchTile(
                        'Enable Cloud Backup',
                        'Automatically sync your store data to Cloud',
                        s.isCloudEnabled,
                        (bool newValue) async {
                          setState(() => s.isCloudEnabled = newValue);

                          final success =
                              await BackupService.toggleCloudSync(newValue);
                          ctrl.save(s);

                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(newValue
                                      ? 'Cloud backup enabled successfully!'
                                      : 'Cloud backup paused.'),
                                  backgroundColor:
                                      newValue ? Colors.green : Colors.orange,
                                ),
                              );
                            } else {
                              setState(() => s.isCloudEnabled = !newValue);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Failed to update setting. Check internet.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FilledButton.icon(
                          onPressed: _isCreatingEncBackup
                              ? null
                              : () async {
                                  setState(() => _isCreatingEncBackup = true);
                                  try {
                                    final savedPath = await BackupService
                                        .createAndSaveLocalEncBackup();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '.enc backup saved to $savedPath',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to create backup: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(
                                          () => _isCreatingEncBackup = false);
                                    }
                                  }
                                },
                          icon: _isCreatingEncBackup
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.enhanced_encryption_outlined),
                          label: Text(_isCreatingEncBackup
                              ? 'Creating .enc backup...'
                              : 'Create .enc Backup to Downloads'),
                        ),
                      ),
                    ]),
                  _section('Inventory Settings', [
                    _switchTile(
                      'Enable Auto Reorder Alert',
                      'Notify when stock falls below reorder level',
                      s.autoReorder,
                      (v) => setState(() => s.autoReorder = v),
                    ),
                    _switchTile(
                      'Allow Negative Stock',
                      'Allow issue even if stock is insufficient',
                      s.allowNegativeStock,
                      (v) => setState(() => s.allowNegativeStock = v),
                    ),
                    _switchTile(
                      'Show Item Images in Sales',
                      'Display item photos on the sales screen when available',
                      s.enableItemImagesInSales,
                      (v) => setState(() => s.enableItemImagesInSales = v),
                    ),
                  ]),
                  _section('Subscription Delivery', [
                    _switchTile(
                      'Enable App for Subscription Delivery',
                      'When ON: daily subscription home-delivery orders are auto-accepted and appear directly in retailer console. When OFF: orders appear as draft bills on the sale screen for manual confirmation.',
                      s.enableAppSubscription,
                      (v) => setState(() => s.enableAppSubscription = v),
                    ),
                  ]),
                  _section('Approval Rules', [
                    _switchTile(
                      'Damage Approval Required',
                      'Manager approval required for damage entry',
                      s.damageApprovalRequired,
                      (v) => setState(() => s.damageApprovalRequired = v),
                    ),
                  ]),
                  _section('Audit & Compliance', [
                    _switchTile(
                      'Enable Audit Log',
                      'Track all stock changes and edits',
                      s.enableAuditLog,
                      (v) => setState(() => s.enableAuditLog = v),
                    ),
                    _switchTile(
                      'Show Notifications',
                      'Show notification icon and desktop alerts in dashboard',
                      _showNotifications,
                      (v) => setState(() => _showNotifications = v),
                    ),
                  ]),
                  if (_isAdmin)
                    _section('Danger Zone', [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7F7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin only',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Keeps master data and system settings, but removes stock, sales, purchase, finance, and report records.',
                              style: TextStyle(
                                  color: Color(0xFF64748B), height: 1.4),
                            ),
                            const SizedBox(height: 14),
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
                              onPressed: _showClearTransactionDataDialog,
                              icon: const Icon(Icons.delete_forever, size: 18),
                              label: const Text('Clear All Transaction Data'),
                            ),
                          ],
                        ),
                      ),
                    ]),
                ], constraints),
                buildTabBody([
                  _section('Appearance', [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Card(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.dashboard_customize_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Microsoft Fluent Enterprise Preset',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Instantly apply a clean, compact, professional layout with rectangular borders, optimized for enterprise-grade productivity.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              FilledButton(
                                onPressed: () async {
                                  await themeCtrl
                                      .updateTheme(AppTheme.microsoftFluent);
                                  await uiPrefsCtrl.updateTouchMode(false);
                                  await uiPrefsCtrl
                                      .updateTextfieldSize('compact');
                                  await uiPrefsCtrl.updateTextfieldBorderStyle(
                                      'rectangular');
                                  await uiPrefsCtrl
                                      .updateCardColorStyle('white');
                                  await uiPrefsCtrl
                                      .updateCardBorderStyle('flat');
                                  await uiPrefsCtrl
                                      .updateButtonBorderStyle('flat');

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Microsoft Fluent Enterprise theme applied!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Apply Preset'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _switchTile(
                      'Touch Screen Mode',
                      'Larger tap targets and softer spacing for touch devices',
                      uiPrefsCtrl.touchMode,
                      (v) => uiPrefsCtrl.updateTouchMode(v),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.defaultStartupScreen,
                        decoration: const InputDecoration(
                          labelText: 'Default Startup Screen',
                          helperText:
                              'Choose which screen should open first after login',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'INVENTORY_DASHBOARD',
                            child: Text('Warehouse Dashboard'),
                          ),
                          DropdownMenuItem(
                            value: 'RETAIL_SALES',
                            child: Text('Retail Dashboard'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateDefaultStartupScreen(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: themeCtrl.themeKey,
                        decoration: const InputDecoration(
                          labelText: 'Application Theme',
                          helperText: 'Choose a Famalth enterprise theme',
                        ),
                        items: AppTheme.availableThemes.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            themeCtrl.updateTheme(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.textfieldSize,
                        decoration: const InputDecoration(
                          labelText: 'Global Textfield Size',
                          helperText:
                              'Apply extra compact, compact, normal, or comfortable height',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'extra_compact',
                            child: Text('Extra Compact'),
                          ),
                          DropdownMenuItem(
                            value: 'compact',
                            child: Text('Compact'),
                          ),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(
                            value: 'comfortable',
                            child: Text('Comfortable'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateTextfieldSize(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.textfieldBorderStyle,
                        decoration: const InputDecoration(
                          labelText: 'Global Textfield Border Style',
                          helperText:
                              'Choose the visual style for all input text fields',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'rounded',
                            child: Text('Rounded Borders'),
                          ),
                          DropdownMenuItem(
                            value: 'rectangular',
                            child: Text('Rectangular Borders'),
                          ),
                          DropdownMenuItem(
                            value: 'underlined',
                            child: Text('Underlined Only'),
                          ),
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('No Borders (Borderless)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateTextfieldBorderStyle(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.cardColorStyle,
                        decoration: const InputDecoration(
                          labelText: 'Global Card Color',
                          helperText: 'Control card tint across all screens',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'soft',
                            child: Text('Soft Surface'),
                          ),
                          DropdownMenuItem(
                            value: 'white',
                            child: Text('Plain White'),
                          ),
                          DropdownMenuItem(
                            value: 'tint',
                            child: Text('Theme Tint'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateCardColorStyle(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.cardBorderStyle,
                        decoration: const InputDecoration(
                          labelText: 'Global Card Shape',
                          helperText:
                              'Choose the corner roundness for all cards',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'rounded',
                            child: Text('Rounded (Default)'),
                          ),
                          DropdownMenuItem(
                            value: 'less_rounded',
                            child: Text('Less Rounded'),
                          ),
                          DropdownMenuItem(
                            value: 'flat',
                            child: Text('Flat (Sharp Corners)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateCardBorderStyle(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.buttonBorderStyle,
                        decoration: const InputDecoration(
                          labelText: 'Global Button Shape',
                          helperText: 'Choose the corner roundness for buttons',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'rounded',
                            child: Text('Rounded (Default)'),
                          ),
                          DropdownMenuItem(
                            value: 'less_rounded',
                            child: Text('Less Rounded'),
                          ),
                          DropdownMenuItem(
                            value: 'flat',
                            child: Text('Flat (Sharp Corners)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateButtonBorderStyle(value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: uiPrefsCtrl.fontSizeAdjustment,
                        decoration: const InputDecoration(
                          labelText: 'Global Font Size Scale',
                          helperText: 'Adjust text size across all views',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'small',
                            child: Text('Small'),
                          ),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normal (Default)'),
                          ),
                          DropdownMenuItem(
                            value: 'large',
                            child: Text('Large'),
                          ),
                          DropdownMenuItem(
                            value: 'extra_large',
                            child: Text('Extra Large'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            uiPrefsCtrl.updateFontSizeAdjustment(value);
                          }
                        },
                      ),
                    ),
                  ]),
                ], constraints),
                buildTabBody([
                  _section('Printing', [
                    _switchTile(
                      'Auto Print on Save',
                      'Automatically print after save',
                      s.autoPrintOnSave,
                      (v) => setState(() => s.autoPrintOnSave = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: s.printMode,
                        decoration:
                            const InputDecoration(labelText: 'Print Mode'),
                        items: _printModes
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(
                                  mode == 'PRINT_DIALOG'
                                      ? 'Open Print Dialog'
                                      : mode == 'ASK_BEFORE_PRINT'
                                          ? 'Ask Yes / No Before Print'
                                          : 'Direct Print to Selected Printer',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => s.printMode = value);
                          }
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPrinterValue,
                            decoration: const InputDecoration(
                              labelText: 'Default Printer',
                            ),
                            items: _printers
                                .map(
                                  (printer) => DropdownMenuItem(
                                    value: printer.url,
                                    child: Text(
                                      printer.name +
                                          (printer.isDefault
                                              ? ' (System Default)'
                                              : ''),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              final printer =
                                  _printers.cast<Printer?>().firstWhere(
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
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _loadingPrinters ? null : _loadPrinters,
                          icon: const Icon(Icons.refresh),
                          label:
                              Text(_loadingPrinters ? 'Loading...' : 'Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.printMode == 'DIRECT_DEFAULT'
                          ? 'Direct print sends the bill to the selected printer without opening printer selection.'
                          : s.printMode == 'ASK_BEFORE_PRINT'
                              ? 'Sales will ask Yes / No before printing. If Yes, the normal print dialog opens.'
                              : 'Every print opens the print dialog and user can choose printer.',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ]),
                  _section('Global Billing', [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        initialValue: s.billingCountry,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          helperText:
                              'Used to preselect billing tax mode and invoice defaults',
                        ),
                        onChanged: (value) => s.billingCountry =
                            value.trim().isEmpty ? 'India' : value.trim(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: s.billingTaxMode,
                        decoration: const InputDecoration(
                            labelText: 'Default Tax Mode'),
                        items: _taxModes
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode.replaceAll('_', ' ')),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => s.billingTaxMode = value);
                          }
                        },
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: s.billFormat,
                      decoration:
                          const InputDecoration(labelText: 'Bill Format'),
                      items: _billFormats
                          .map(
                            (format) => DropdownMenuItem(
                              value: format,
                              child: Text(_billFormatLabel(format)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => s.billFormat = value);
                        }
                      },
                    ),
                  ]),
                  _section('Default Charges', [
                    ...List.generate(
                      s.defaultCharges.length,
                      (index) => _chargeTile(
                        s.defaultCharges[index],
                        onChanged: (updated) {
                          setState(() => s.defaultCharges[index] = updated);
                        },
                        onDelete: s.defaultCharges.length <= 1
                            ? null
                            : () {
                                setState(
                                    () => s.defaultCharges.removeAt(index));
                              },
                      ),
                    ),
                    Align(
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
                        icon: const Icon(Icons.add),
                        label: const Text('Add Charge Rule'),
                      ),
                    ),
                  ]),
                ], constraints),
                buildTabBody([
                  _section('Branding', [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey(
                            'branding-company-${_branding.companyName}'),
                        initialValue: _branding.companyName,
                        decoration:
                            const InputDecoration(labelText: 'Company Name'),
                        onChanged: (value) =>
                            _branding = _branding.copyWith(companyName: value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey(
                            'branding-product-${_branding.productName}'),
                        initialValue: _branding.productName,
                        decoration:
                            const InputDecoration(labelText: 'Product Name'),
                        onChanged: (value) =>
                            _branding = _branding.copyWith(productName: value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey(
                            'branding-powered-${_branding.poweredByLabel}'),
                        initialValue: _branding.poweredByLabel,
                        decoration: const InputDecoration(
                            labelText: 'Powered By Label'),
                        onChanged: (value) => _branding =
                            _branding.copyWith(poweredByLabel: value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey(
                            'branding-email-${_branding.supportEmail}'),
                        initialValue: _branding.supportEmail,
                        decoration:
                            const InputDecoration(labelText: 'Support Email'),
                        onChanged: (value) =>
                            _branding = _branding.copyWith(supportEmail: value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey(
                            'branding-phone-${_branding.supportPhone}'),
                        initialValue: _branding.supportPhone,
                        decoration:
                            const InputDecoration(labelText: 'Support Phone'),
                        onChanged: (value) =>
                            _branding = _branding.copyWith(supportPhone: value),
                      ),
                    ),
                    TextFormField(
                      key: ValueKey('branding-web-${_branding.supportWebsite}'),
                      initialValue: _branding.supportWebsite,
                      decoration:
                          const InputDecoration(labelText: 'Support Website'),
                      onChanged: (value) =>
                          _branding = _branding.copyWith(supportWebsite: value),
                    ),
                  ]),
                ], constraints),
                buildTabBody([
                  _buildKeyboardShortcutsSection(Theme.of(context)),
                ], constraints),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Text(subtitle),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: charge.calculationType == 'PERCENT'
                          ? 'Percent'
                          : 'Amount',
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
                    onChanged: (value) => onChanged(
                        charge.copyWith(autoApply: value, isEnabled: value)),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Taxable'),
                    value: charge.taxable,
                    onChanged: (value) =>
                        onChanged(charge.copyWith(taxable: value)),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: charge.isEnabled,
                    onChanged: (value) =>
                        onChanged(charge.copyWith(isEnabled: value)),
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
                          amount: value == 'PERCENT'
                              ? charge.amount
                              : charge.calculationValue,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: charge.taxType,
                    decoration:
                        const InputDecoration(labelText: 'Charge Tax Type'),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
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
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                actionDescription,
                style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    return _section('Keyboard Shortcuts Guide', [
      const Text(
        'Use hotkeys to quickly navigate through screens and control operations without using a mouse.',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      ),
      const SizedBox(height: 16),
      const Text(
        'Global Navigation Shortcuts (Anywhere)',
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
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
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
      ),
      const Divider(),
      shortcutRow('Enter / F1',
          'Focus & search product in barcode scanner input field'),
      shortcutRow('F2', 'Trigger Checkout Payment dialog directly'),
      shortcutRow('Delete',
          'Remove the currently selected/highlighted cart line item (or last item if none selected)'),
      shortcutRow(
          'Escape', 'Close checkout popup / Clear barcode scanner input'),
    ]);
  }
}
