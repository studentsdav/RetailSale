import 'package:flutter/material.dart';
import 'package:inventory/screens/recovery/backup_service.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../controllers/settings/app_branding_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/settings/theme_controller.dart';
import '../../controllers/settings/ui_preferences_controller.dart';
import '../../core/api/api_client.dart';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Data & Security', [
            _switchTile(
              'Enable Cloud Backup',
              'Automatically sync your store data to Cloud',
              s.isCloudEnabled,
              (bool newValue) async {
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
                        backgroundColor:
                            newValue ? Colors.green : Colors.orange,
                      ),
                    );
                  } else {
                    setState(() => s.isCloudEnabled = !newValue);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Failed to update setting. Check internet.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
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
                      style: TextStyle(color: Color(0xFF64748B), height: 1.4),
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
          _section('Appearance', [
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
          ]),
          _section('Branding', [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey('branding-company-${_branding.companyName}'),
                initialValue: _branding.companyName,
                decoration: const InputDecoration(labelText: 'Company Name'),
                onChanged: (value) =>
                    _branding = _branding.copyWith(companyName: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey('branding-product-${_branding.productName}'),
                initialValue: _branding.productName,
                decoration: const InputDecoration(labelText: 'Product Name'),
                onChanged: (value) =>
                    _branding = _branding.copyWith(productName: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey('branding-powered-${_branding.poweredByLabel}'),
                initialValue: _branding.poweredByLabel,
                decoration:
                    const InputDecoration(labelText: 'Powered By Label'),
                onChanged: (value) =>
                    _branding = _branding.copyWith(poweredByLabel: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey('branding-email-${_branding.supportEmail}'),
                initialValue: _branding.supportEmail,
                decoration: const InputDecoration(labelText: 'Support Email'),
                onChanged: (value) =>
                    _branding = _branding.copyWith(supportEmail: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey('branding-phone-${_branding.supportPhone}'),
                initialValue: _branding.supportPhone,
                decoration: const InputDecoration(labelText: 'Support Phone'),
                onChanged: (value) =>
                    _branding = _branding.copyWith(supportPhone: value),
              ),
            ),
            TextFormField(
              key: ValueKey('branding-web-${_branding.supportWebsite}'),
              initialValue: _branding.supportWebsite,
              decoration: const InputDecoration(labelText: 'Support Website'),
              onChanged: (value) =>
                  _branding = _branding.copyWith(supportWebsite: value),
            ),
          ]),
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
                decoration: const InputDecoration(labelText: 'Print Mode'),
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
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loadingPrinters ? null : _loadPrinters,
                  icon: const Icon(Icons.refresh),
                  label: Text(_loadingPrinters ? 'Loading...' : 'Refresh'),
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
                decoration:
                    const InputDecoration(labelText: 'Default Tax Mode'),
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
              decoration: const InputDecoration(labelText: 'Bill Format'),
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
                        setState(() => s.defaultCharges.removeAt(index));
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
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              onPressed: () async {
                await LocalPreferences.setShowNotifications(_showNotifications);
                await ctrl.save(s);
                await brandingCtrl.save(
                  _branding.copyWith(themeKey: themeCtrl.themeKey),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved successfully')),
                );
              },
            ),
          ),
        ],
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
}
