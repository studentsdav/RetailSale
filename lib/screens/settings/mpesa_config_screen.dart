import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class MpesaConfigScreen extends StatefulWidget {
  const MpesaConfigScreen({super.key});

  @override
  State<MpesaConfigScreen> createState() => _MpesaConfigScreenState();
}

class _MpesaConfigScreenState extends State<MpesaConfigScreen> {
  bool _loading = false;
  bool _saving = false;
  bool _testingPush = false;

  bool _enabled = true;
  String _env = 'sandbox';
  String _type = 'till'; // 'till' or 'paybill'

  final _shortcodeCtrl = TextEditingController();
  final _consumerKeyCtrl = TextEditingController();
  final _consumerSecretCtrl = TextEditingController();
  final _passkeyCtrl = TextEditingController();

  // Test STK Push fields
  final _testPhoneCtrl = TextEditingController();
  final _testAmountCtrl = TextEditingController(text: '1.00');
  String? _testResultLog;

  static const Color primaryGreen = Color(0xFF00A859); // Safaricom Green
  static const Color darkBlue = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _shortcodeCtrl.dispose();
    _consumerKeyCtrl.dispose();
    _consumerSecretCtrl.dispose();
    _passkeyCtrl.dispose();
    _testPhoneCtrl.dispose();
    _testAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.mpesaConfig);
      if (res['success'] == true && res['data'] != null) {
        final d = res['data'];
        setState(() {
          _enabled = d['enabled'] ?? true;
          _env = d['env'] ?? 'sandbox';
          _type = d['type'] ?? 'till';
          _shortcodeCtrl.text = d['shortcode'] ?? '';
          _consumerKeyCtrl.text = d['consumer_key'] ?? '';
          _consumerSecretCtrl.text = d['consumer_secret'] ?? '';
          _passkeyCtrl.text = d['passkey'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading M-Pesa config: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    final shortcode = _shortcodeCtrl.text.trim();
    final consumerKey = _consumerKeyCtrl.text.trim();
    final consumerSecret = _consumerSecretCtrl.text.trim();
    final passkey = _passkeyCtrl.text.trim();

    if (shortcode.isEmpty || consumerKey.isEmpty || consumerSecret.isEmpty || passkey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all M-Pesa Daraja credential fields')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'enabled': _enabled,
        'env': _env,
        'type': _type,
        'shortcode': shortcode,
        'consumer_key': consumerKey,
        'consumer_secret': consumerSecret,
        'passkey': passkey,
      };

      final res = await ApiClient.post(ApiEndpoints.mpesaConfig, payload);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('M-Pesa Daraja Configuration saved successfully!'),
              backgroundColor: primaryGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to save configuration'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving config: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _triggerTestPush() async {
    final phone = _testPhoneCtrl.text.trim();
    final amount = double.tryParse(_testAmountCtrl.text.trim()) ?? 0.0;

    if (phone.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Safaricom phone number and amount')),
      );
      return;
    }

    setState(() {
      _testingPush = true;
      _testResultLog = 'Initiating Safaricom STK Push to $phone for ${CurrencyService.format(amount)}...';
    });

    try {
      final res = await ApiClient.post(ApiEndpoints.mpesaStkPush, {
        'phone': phone,
        'amount': amount,
        'bill_no': 'TEST-001',
        'reference': 'TEST_STK',
      });

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _testResultLog = 'SUCCESS: ${res['message']}\nCheckoutRequestID: ${res['checkout_request_id']}\nPlease check phone for M-Pesa PIN prompt.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('STK Push Sent! Check phone for PIN prompt.'), backgroundColor: primaryGreen),
          );
        } else {
          setState(() {
            _testResultLog = 'FAILED: ${res['message']}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResultLog = 'ERROR: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _testingPush = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safaricom M-Pesa Daraja API Integration'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfig,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Card(
                        color: Colors.green.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: primaryGreen,
                                radius: 24,
                                child: const Icon(Icons.phone_android, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Lipa na M-Pesa (Online STK Push & C2B)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Directly prompt customer Safaricom phones for M-Pesa PIN at checkout. Supports Paybill and Buy Goods (Till Number).',
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Settings Form Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('API Credentials & Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
                              const Divider(height: 24),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enable M-Pesa Express (STK Push) at POS', style: TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Shows M-Pesa Quick Pay on Checkout and Order Desk'),
                                value: _enabled,
                                activeColor: primaryGreen,
                                onChanged: (val) => setState(() => _enabled = val),
                              ),
                              const SizedBox(height: 12),

                              // Environment selector
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Sandbox / Test Mode'),
                                      subtitle: const Text('developer.safaricom.co.ke testing'),
                                      value: 'sandbox',
                                      groupValue: _env,
                                      activeColor: primaryGreen,
                                      onChanged: (val) => setState(() => _env = val!),
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Live / Production'),
                                      subtitle: const Text('Live merchant business account'),
                                      value: 'production',
                                      groupValue: _env,
                                      activeColor: primaryGreen,
                                      onChanged: (val) => setState(() => _env = val!),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Type selector (Till vs Paybill)
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Buy Goods (Till No)'),
                                      value: 'till',
                                      groupValue: _type,
                                      activeColor: primaryGreen,
                                      onChanged: (val) => setState(() => _type = val!),
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Paybill Number'),
                                      value: 'paybill',
                                      groupValue: _type,
                                      activeColor: primaryGreen,
                                      onChanged: (val) => setState(() => _type = val!),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _shortcodeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: _type == 'till' ? 'Business Till Number *' : 'Business Paybill Shortcode *',
                                  hintText: _type == 'till' ? 'e.g. 174379 or Store Till Number' : 'e.g. 600999',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.store),
                                ),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _consumerKeyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Daraja Consumer Key *',
                                  hintText: 'Obtained from Safaricom Daraja Developer Portal',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.key),
                                ),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _consumerSecretCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Daraja Consumer Secret *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _passkeyCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Lipa Na M-Pesa Online Passkey *',
                                  hintText: 'Daraja Passkey for STK Push encryption',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.vpn_key),
                                ),
                              ),
                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _saving ? null : _saveConfig,
                                  icon: _saving
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.save),
                                  label: const Text('Save M-Pesa Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Test STK Push Section
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.send_to_mobile, color: primaryGreen),
                                  SizedBox(width: 8),
                                  Text('Test Live M-Pesa STK Push Prompt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Send a test push to your phone to verify Safaricom credentials and prompt responsiveness.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const Divider(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _testPhoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Customer Phone (e.g. 0712345678 / 2547...)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.phone),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: _testAmountCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Amount (KES)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                    onPressed: _testingPush ? null : _triggerTestPush,
                                    icon: _testingPush
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.bolt),
                                    label: const Text('Send Push', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),

                              if (_testResultLog != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _testResultLog!.startsWith('SUCCESS') ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    _testResultLog!,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: _testResultLog!.startsWith('SUCCESS') ? Colors.green.shade900 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
