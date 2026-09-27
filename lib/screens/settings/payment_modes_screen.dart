import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/settings/system_settings_controller.dart';

class PaymentModesScreen extends StatefulWidget {
  const PaymentModesScreen({super.key});

  @override
  State<PaymentModesScreen> createState() => _PaymentModesScreenState();
}

class _PaymentModesScreenState extends State<PaymentModesScreen> {
  final _modeNameCtrl = TextEditingController();
  final _modeIdCtrl = TextEditingController();
  bool _loading = false;

  static const Color primaryColor = Color(0xFF0B5CAD);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    await context.read<SystemSettingsController>().load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePaymentModes(List<Map<String, dynamic>> updatedModes) async {
    final settingsCtrl = context.read<SystemSettingsController>();
    final currentSettings = settingsCtrl.settings;
    if (currentSettings == null) return;

    currentSettings.paymentModes = updatedModes;
    final success = await settingsCtrl.updateSettings(currentSettings);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Modes updated successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update Payment Modes.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? existingMode, int? index]) {
    _modeNameCtrl.text = existingMode?['name'] ?? '';
    _modeIdCtrl.text = existingMode?['id'] ?? '';
    bool enabled = existingMode?['enabled'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            existingMode == null ? 'Add Payment Mode' : 'Edit Payment Mode',
            style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _modeNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode Name (e.g. M-Pesa Till 12345)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (existingMode == null) ...[
                  TextField(
                    controller: _modeIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code / Identifier (e.g. MPESA_TILL)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SwitchListTile(
                  title: const Text('Enabled for Sales & Checkout'),
                  value: enabled,
                  onChanged: (val) => setDlgState(() => enabled = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () async {
                final name = _modeNameCtrl.text.trim();
                final id = _modeIdCtrl.text.trim().toUpperCase().replaceAll(' ', '_');
                if (name.isEmpty || id.isEmpty) return;

                final settingsCtrl = context.read<SystemSettingsController>();
                final modes = List<Map<String, dynamic>>.from(settingsCtrl.settings?.paymentModes ?? []);

                if (index != null && index >= 0 && index < modes.length) {
                  modes[index] = {'id': modes[index]['id'], 'name': name, 'enabled': enabled};
                } else {
                  modes.add({'id': id, 'name': name, 'enabled': enabled});
                }

                Navigator.pop(ctx);
                await _savePaymentModes(modes);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = context.watch<SystemSettingsController>();
    final modes = settingsCtrl.settings?.paymentModes ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Options Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure Admin Payment Options (Kenya / East Africa & Global)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable, disable, rename or create payment methods like M-Pesa Till, M-Pesa Paybill, Cash, Card, or Bank Transfer.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: modes.isEmpty
                        ? const Center(child: Text('No payment modes configured.'))
                        : ListView.separated(
                            itemCount: modes.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final mode = modes[index];
                              final String name = mode['name'] ?? mode['id'] ?? '';
                              final String id = mode['id'] ?? '';
                              final bool enabled = mode['enabled'] ?? true;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: enabled ? Colors.green.shade50 : Colors.red.shade50,
                                  child: Icon(
                                    id.contains('MPESA')
                                        ? Icons.phone_android
                                        : id.contains('CARD')
                                            ? Icons.credit_card
                                            : id.contains('BANK')
                                                ? Icons.account_balance
                                                : Icons.payments,
                                    color: enabled ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Code: $id'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: enabled,
                                      onChanged: (val) {
                                        final updatedModes = List<Map<String, dynamic>>.from(modes);
                                        updatedModes[index] = {...mode, 'enabled': val};
                                        _savePaymentModes(updatedModes);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showAddEditDialog(mode, index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        final updatedModes = List<Map<String, dynamic>>.from(modes);
                                        updatedModes.removeAt(index);
                                        _savePaymentModes(updatedModes);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Payment Option', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
