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

  // Provider Mode: 'SMTP', 'GMAIL_OAUTH', 'RESEND'
  String _providerType = 'SMTP';

  final _hostCtrl = TextEditingController(text: 'smtp.gmail.com');
  final _portCtrl = TextEditingController(text: '587');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _senderNameCtrl = TextEditingController(text: 'My Restaurant POS');

  // OAuth2 Controllers
  final _gmailClientIdCtrl = TextEditingController();
  final _gmailClientSecretCtrl = TextEditingController();
  final _gmailRefreshTokenCtrl = TextEditingController();

  // Resend API Controller
  final _resendApiKeyCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureClientId = true;
  bool _obscureClientSecret = true;
  bool _obscureRefreshToken = true;
  bool _obscureResendKey = true;
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
    _gmailClientIdCtrl.dispose();
    _gmailClientSecretCtrl.dispose();
    _gmailRefreshTokenCtrl.dispose();
    _resendApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final ctrl = context.read<RestaurantController>();
      await ctrl.loadEmailConfig();
      final cfg = ctrl.emailConfig;
      if (cfg != null && cfg.isNotEmpty) {
        _providerType = cfg['provider_type'] ?? 'SMTP';
        _hostCtrl.text = cfg['smtp_host'] ?? 'smtp.gmail.com';
        _portCtrl.text = (cfg['smtp_port'] ?? 587).toString();
        _userCtrl.text = cfg['smtp_user'] ?? '';
        _passCtrl.text = cfg['smtp_pass'] ?? '';
        _senderNameCtrl.text = cfg['sender_name'] ?? cfg['from_name'] ?? 'My Restaurant POS';
        _securityType = cfg['security_type'] ?? cfg['encryption_type'] ?? 'STARTTLS (587)';
        _gmailClientIdCtrl.text = cfg['gmail_client_id'] ?? '';
        _gmailClientSecretCtrl.text = cfg['gmail_client_secret'] ?? '';
        _gmailRefreshTokenCtrl.text = cfg['gmail_refresh_token'] ?? '';
        _resendApiKeyCtrl.text = cfg['resend_api_key'] ?? '';
        _enablePoEmail = cfg['enable_po_email'] ?? true;
        _enableInvoiceEmail = cfg['enable_invoice_email'] ?? true;
        _enableDailyReportEmail = cfg['enable_daily_report_email'] ?? false;
      }
    } catch (e) {
      debugPrint('Error loading Email config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySmtpPreset(String host, String port, String sec) {
    setState(() {
      _providerType = 'SMTP';
      _hostCtrl.text = host;
      _portCtrl.text = port;
      _securityType = sec;
    });
  }

  void _applyGmailOAuthPreset() {
    setState(() {
      _providerType = 'GMAIL_OAUTH';
      _hostCtrl.text = 'smtp.gmail.com';
      _portCtrl.text = '587';
      _securityType = 'STARTTLS (587)';
    });
  }

  void _applyResendPreset() {
    setState(() {
      _providerType = 'RESEND';
    });
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final payload = {
        'provider_type': _providerType,
        'smtp_host': _hostCtrl.text.trim(),
        'smtp_port': int.tryParse(_portCtrl.text.trim()) ?? 587,
        'smtp_user': _userCtrl.text.trim(),
        'smtp_pass': _passCtrl.text.trim(),
        'sender_name': _senderNameCtrl.text.trim(),
        'from_name': _senderNameCtrl.text.trim(),
        'from_email': _userCtrl.text.trim(),
        'security_type': _securityType,
        'gmail_client_id': _gmailClientIdCtrl.text.trim(),
        'gmail_client_secret': _gmailClientSecretCtrl.text.trim(),
        'gmail_refresh_token': _gmailRefreshTokenCtrl.text.trim(),
        'resend_api_key': _resendApiKeyCtrl.text.trim(),
        'enable_po_email': _enablePoEmail,
        'enable_invoice_email': _enableInvoiceEmail,
        'enable_daily_report_email': _enableDailyReportEmail,
      };

      final ctrl = context.read<RestaurantController>();
      final success = await ctrl.saveEmailConfig(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Email Settings saved successfully!' : 'Error saving email parameters'),
            backgroundColor: success ? Colors.teal : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save email config: $e'), backgroundColor: Colors.red),
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
                    'Enter a recipient email address to verify your email configuration.',
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
                              'provider_type': _providerType,
                              'smtp_host': _hostCtrl.text.trim(),
                              'smtp_port': int.tryParse(_portCtrl.text.trim()) ?? 587,
                              'smtp_user': _userCtrl.text.trim(),
                              'smtp_pass': _passCtrl.text.trim(),
                              'sender_name': _senderNameCtrl.text.trim(),
                              'security_type': _securityType,
                              'gmail_client_id': _gmailClientIdCtrl.text.trim(),
                              'gmail_client_secret': _gmailClientSecretCtrl.text.trim(),
                              'gmail_refresh_token': _gmailRefreshTokenCtrl.text.trim(),
                              'resend_api_key': _resendApiKeyCtrl.text.trim(),
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
            Text('Email & Dispatch Configuration'),
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
                    // Header Banner
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
                                  'Outbound Mail Server & API Setup',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Configure your email credentials via Gmail OAuth2, Resend API, or Standard SMTP to send Purchase Orders, Invoices, and Verification OTPs.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Presets Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Provider Presets',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _presetChip('Gmail (OAuth2)', Icons.vpn_key, Colors.deepPurple, _applyGmailOAuthPreset),
                                _presetChip('Resend HTTP API', Icons.flash_on, Colors.blue.shade800, _applyResendPreset),
                                _presetChip('Gmail (App Pass)', Icons.mail, Colors.teal.shade700, () => _applySmtpPreset('smtp.gmail.com', '587', 'STARTTLS (587)')),
                                _presetChip('Outlook / O365', Icons.email, Colors.indigo, () => _applySmtpPreset('smtp.office365.com', '587', 'STARTTLS (587)')),
                                _presetChip('Zoho Mail', Icons.business, Colors.orange.shade800, () => _applySmtpPreset('smtp.zoho.in', '587', 'STARTTLS (587)')),
                                _presetChip('Yahoo Mail', Icons.mark_email_unread, Colors.purple, () => _applySmtpPreset('smtp.mail.yahoo.com', '587', 'STARTTLS (587)')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Provider Mode Choice Selector
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.settings_suggest, color: Color(0xFFFF7A1A), size: 20),
                                SizedBox(width: 8),
                                Text('Authentication Protocol Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'SMTP',
                                  label: Text('Standard SMTP'),
                                  icon: Icon(Icons.dns),
                                ),
                                ButtonSegment<String>(
                                  value: 'GMAIL_OAUTH',
                                  label: Text('Gmail OAuth2'),
                                  icon: Icon(Icons.vpn_key),
                                ),
                                ButtonSegment<String>(
                                  value: 'RESEND',
                                  label: Text('Resend API'),
                                  icon: Icon(Icons.flash_on),
                                ),
                              ],
                              selected: {_providerType},
                              onSelectionChanged: (Set<String> newSelection) {
                                setState(() {
                                  _providerType = newSelection.first;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Form Body Based on Selected Provider Type
                    if (_providerType == 'GMAIL_OAUTH') ...[
                      _buildGmailOAuthCard(),
                    ] else if (_providerType == 'RESEND') ...[
                      _buildResendCard(),
                    ] else ...[
                      _buildSmtpCard(),
                    ],

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

  // ================= GMAIL OAUTH CARD =================
  Widget _buildGmailOAuthCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.vpn_key, color: Colors.deepPurple, size: 22),
                SizedBox(width: 8),
                Text('Google Gmail OAuth2 Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Uses official Google API tokens to bypass cloud port blocking and password restrictions.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _userCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Sender Gmail Address',
                      hintText: 'yourname@gmail.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter Gmail Address' : null,
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _gmailClientIdCtrl,
              obscureText: _obscureClientId,
              decoration: InputDecoration(
                labelText: 'Google OAuth Client ID',
                hintText: '123456789-xyz.apps.googleusercontent.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureClientId ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureClientId = !_obscureClientId),
                ),
              ),
              validator: (v) => _providerType == 'GMAIL_OAUTH' && (v == null || v.trim().isEmpty) ? 'Enter Client ID' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _gmailClientSecretCtrl,
              obscureText: _obscureClientSecret,
              decoration: InputDecoration(
                labelText: 'Google OAuth Client Secret',
                hintText: 'GOCSPX-your_client_secret',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.security),
                suffixIcon: IconButton(
                  icon: Icon(_obscureClientSecret ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureClientSecret = !_obscureClientSecret),
                ),
              ),
              validator: (v) => _providerType == 'GMAIL_OAUTH' && (v == null || v.trim().isEmpty) ? 'Enter Client Secret' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _gmailRefreshTokenCtrl,
              obscureText: _obscureRefreshToken,
              decoration: InputDecoration(
                labelText: 'Google OAuth Refresh Token',
                hintText: '1//04_your_refresh_token_from_playground',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.refresh_rounded, color: Colors.deepPurple.shade400),
                suffixIcon: IconButton(
                  icon: Icon(_obscureRefreshToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureRefreshToken = !_obscureRefreshToken),
                ),
              ),
              validator: (v) => _providerType == 'GMAIL_OAUTH' && (v == null || v.trim().isEmpty) ? 'Enter Refresh Token' : null,
            ),
          ],
        ),
      ),
    );
  }

  // ================= RESEND CARD =================
  Widget _buildResendCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.blue.shade800, size: 22),
                const SizedBox(width: 8),
                const Text('Resend HTTP API Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Sends instant emails over HTTPS Port 443. Ideal for cloud deployments.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _resendApiKeyCtrl,
              obscureText: _obscureResendKey,
              decoration: InputDecoration(
                labelText: 'Resend API Key',
                hintText: 're_123456789_your_api_key',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureResendKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureResendKey = !_obscureResendKey),
                ),
              ),
              validator: (v) => _providerType == 'RESEND' && (v == null || v.trim().isEmpty) ? 'Enter Resend API Key' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _userCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Verified From Address',
                      hintText: 'noreply@yourdomain.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) => _providerType == 'RESEND' && (v == null || v.trim().isEmpty) ? 'Enter Sender Email' : null,
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= SMTP CARD =================
  Widget _buildSmtpCard() {
    return Card(
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
                    validator: (v) => _providerType == 'SMTP' && (v == null || v.trim().isEmpty) ? 'Enter SMTP Host' : null,
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
                    validator: (v) => _providerType == 'SMTP' && (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    validator: (v) => _providerType == 'SMTP' && (v == null || v.trim().isEmpty) ? 'Enter SMTP Username' : null,
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
                    validator: (v) => _providerType == 'SMTP' && (v == null || v.trim().isEmpty) ? 'Enter Password' : null,
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
    );
  }

  Widget _presetChip(String name, IconData icon, Color color, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.3)),
      onPressed: onTap,
    );
  }
}
