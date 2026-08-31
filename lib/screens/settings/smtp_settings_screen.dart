import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class SmtpSettingsScreen extends StatefulWidget {
  const SmtpSettingsScreen({super.key});

  @override
  State<SmtpSettingsScreen> createState() => _SmtpSettingsScreenState();
}

class _SmtpSettingsScreenState extends State<SmtpSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _hostCtrl = TextEditingController(text: 'smtp.gmail.com');
  final _portCtrl = TextEditingController(text: '587');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _senderNameCtrl = TextEditingController(text: 'My Restaurant POS');

  bool _obscurePass = true;
  bool _isLoading = false;
  String _securityType = 'STARTTLS (587)';

  // Feature Toggles
  bool _enablePoEmail = true;
  bool _enableInvoiceEmail = true;
  bool _enableDailyReportEmail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _senderNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final ctrl = context.read<RestaurantController>();
      await ctrl.loadEmailConfig();
      final cfg = ctrl.emailConfig;
      if (cfg != null && cfg.isNotEmpty) {
        _hostCtrl.text = cfg['smtp_host'] ?? 'smtp.gmail.com';
        _portCtrl.text = (cfg['smtp_port'] ?? 587).toString();
        _userCtrl.text = cfg['smtp_user'] ?? '';
        _passCtrl.text = cfg['smtp_pass'] ?? '';
        _senderNameCtrl.text = cfg['sender_name'] ?? 'My Restaurant POS';
        _securityType = cfg['security_type'] ?? 'STARTTLS (587)';
        _enablePoEmail = cfg['enable_po_email'] ?? true;
        _enableInvoiceEmail = cfg['enable_invoice_email'] ?? true;
        _enableDailyReportEmail = cfg['enable_daily_report_email'] ?? false;
      }
    } catch (e) {
      debugPrint('Error loading SMTP config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyPreset(String host, String port, String sec) {
    setState(() {
      _hostCtrl.text = host;
      _portCtrl.text = port;
      _securityType = sec;
    });
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final payload = {
        'smtp_host': _hostCtrl.text.trim(),
        'smtp_port': int.tryParse(_portCtrl.text.trim()) ?? 587,
        'smtp_user': _userCtrl.text.trim(),
        'smtp_pass': _passCtrl.text.trim(),
        'sender_name': _senderNameCtrl.text.trim(),
        'security_type': _securityType,
        'enable_po_email': _enablePoEmail,
        'enable_invoice_email': _enableInvoiceEmail,
        'enable_daily_report_email': _enableDailyReportEmail,
      };

      final ctrl = context.read<RestaurantController>();
      final success = await ctrl.saveEmailConfig(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'SMTP Email Settings saved successfully!' : 'Error saving SMTP parameters'),
            backgroundColor: success ? Colors.teal : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save SMTP config: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTestEmailDialog() async {
    final testEmailCtrl = TextEditingController(text: _userCtrl.text);
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.send_rounded, color: Color(0xFFFF7A1A)),
                  SizedBox(width: 8),
                  Text('Send Test Email'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter a recipient email address to verify your SMTP server credentials.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: testEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Email Address',
                      hintText: 'e.g. test@example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    foregroundColor: Colors.white,
                  ),
                  icon: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: const Text('Send Test Mail'),
                  onPressed: isSending
                      ? null
                      : () async {
                          if (testEmailCtrl.text.trim().isEmpty) return;
                          setDialogState(() => isSending = true);
                          try {
                            final res = await ApiClient.post('${ApiEndpoints.emailConfigurations}/test', {
                              'to_email': testEmailCtrl.text.trim(),
                              'smtp_host': _hostCtrl.text.trim(),
                              'smtp_port': int.tryParse(_portCtrl.text.trim()) ?? 587,
                              'smtp_user': _userCtrl.text.trim(),
                              'smtp_pass': _passCtrl.text.trim(),
                              'sender_name': _senderNameCtrl.text.trim(),
                              'security_type': _securityType,
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Test email sent successfully! Please check recipient inbox.'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Test email failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.email_outlined, size: 22),
            SizedBox(width: 8),
            Text('SMTP Email Configuration'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner (Styled like WhatsApp Setup)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SMTP Outbound Mail Server',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Configure your email server credentials to automatically dispatch Purchase Orders, Invoices, and Reports.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Preset Buttons
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick SMTP Provider Presets',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _presetChip('Gmail', 'smtp.gmail.com', '587', 'STARTTLS (587)', Icons.mail),
                                _presetChip('Outlook / O365', 'smtp.office365.com', '587', 'STARTTLS (587)', Icons.email),
                                _presetChip('Yahoo Mail', 'smtp.mail.yahoo.com', '587', 'STARTTLS (587)', Icons.mark_email_unread),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Server Credentials Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.dns, color: Color(0xFFFF7A1A), size: 20),
                                SizedBox(width: 8),
                                Text('Server Connection Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _hostCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'SMTP Host / Server',
                                      hintText: 'smtp.gmail.com',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.computer),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter SMTP Host' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _portCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Port',
                                      hintText: '587',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.numbers),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _userCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'SMTP Username / Email',
                                      hintText: 'yourname@domain.com',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter SMTP Username' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _passCtrl,
                                    obscureText: _obscurePass,
                                    decoration: InputDecoration(
                                      labelText: 'App Password',
                                      hintText: '••••••••••••',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.lock),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter Password' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _senderNameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Sender Display Name',
                                      hintText: 'e.g. My Restaurant POS',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.badge),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _securityType,
                                    decoration: const InputDecoration(
                                      labelText: 'Security Protocol',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.security),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'STARTTLS (587)', child: Text('STARTTLS / TLS (587)')),
                                      DropdownMenuItem(value: 'SSL (465)', child: Text('SSL (465)')),
                                      DropdownMenuItem(value: 'None (25)', child: Text('None (25)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _securityType = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Feature Toggles Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.toggle_on_outlined, color: Colors.teal, size: 22),
                                SizedBox(width: 8),
                                Text('Automated Email Dispatch Triggers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 24),

                            SwitchListTile(
                              value: _enablePoEmail,
                              title: const Text('Email Purchase Orders to Vendors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: const Text('Allows emailing Purchase Orders (PO) directly to Vendor email from PO management screen.', style: TextStyle(fontSize: 11.5)),
                              activeColor: const Color(0xFFFF7A1A),
                              onChanged: (val) => setState(() => _enablePoEmail = val),
                            ),
                            const Divider(height: 1),

                            SwitchListTile(
                              value: _enableInvoiceEmail,
                              title: const Text('Email Customer Sales Invoices & Receipts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: const Text('Send digital PDF receipt directly to customer email after checkout.', style: TextStyle(fontSize: 11.5)),
                              activeColor: const Color(0xFFFF7A1A),
                              onChanged: (val) => setState(() => _enableInvoiceEmail = val),
                            ),
                            const Divider(height: 1),

                            SwitchListTile(
                              value: _enableDailyReportEmail,
                              title: const Text('Email Daily Sales & Inventory Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: const Text('Dispatch end-of-day summary report to owner/manager email address.', style: TextStyle(fontSize: 11.5)),
                              activeColor: const Color(0xFFFF7A1A),
                              onChanged: (val) => setState(() => _enableDailyReportEmail = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF7A1A)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFFF7A1A)),
                          label: const Text('Test Connection', style: TextStyle(color: Color(0xFFFF7A1A), fontWeight: FontWeight.bold)),
                          onPressed: _showTestEmailDialog,
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A1A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _saveConfig,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _presetChip(String name, String host, String port, String sec, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.teal.shade700),
      label: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: Colors.teal.shade50,
      onPressed: () => _applyPreset(host, port, sec),
    );
  }
}
