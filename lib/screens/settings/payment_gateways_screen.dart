import 'package:flutter/material.dart';
import '../../controllers/sales/sales_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';
import '../../widgets/virtual_payment_simulator_dialog.dart';

class PaymentGatewaysScreen extends StatefulWidget {
  const PaymentGatewaysScreen({super.key});

  @override
  State<PaymentGatewaysScreen> createState() => _PaymentGatewaysScreenState();
}

class _PaymentGatewaysScreenState extends State<PaymentGatewaysScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  bool _saving = false;
  final SalesController _salesCtrl = SalesController();

  // 1. General & Settlement
  String _settlementMode = 'DIRECT';
  List<Map<String, dynamic>> _dbPaymentMethods = [];
  bool _loadingMethods = false;

  bool _enablePaymentGateway = false;

  // 2. India (UPI, Razorpay, PineLabs / Ezetap POS)
  bool _upiEnabled = true;
  final _upiIdCtrl = TextEditingController();
  final _upiPayeeNameCtrl = TextEditingController();
  bool _printUpiQr = true;

  bool _razorpayEnabled = false;
  String _razorpayEnv = 'test';
  final _razorpayKeyIdCtrl = TextEditingController();
  final _razorpaySecretCtrl = TextEditingController();

  bool _indiaPosEnabled = false;
  String _indiaPosProvider = 'pinelabs'; // 'pinelabs' | 'ezetap' | 'mosambee'
  final _indiaPosIpCtrl = TextEditingController();
  final _indiaPosIdCtrl = TextEditingController();
  bool _indiaPosAutoPush = true;

  // 3. USA / Americas (Stripe & Square)
  bool _stripeEnabled = false;
  String _stripeEnv = 'test';
  final _stripePubCtrl = TextEditingController();
  final _stripeSecretCtrl = TextEditingController();

  bool _squareEnabled = false;
  String _squareEnv = 'sandbox';
  final _squareAppIdCtrl = TextEditingController();
  final _squareLocationIdCtrl = TextEditingController();
  final _squareTokenCtrl = TextEditingController();

  // 4. Europe & Global (PayPal)
  bool _paypalEnabled = false;
  String _paypalEnv = 'sandbox';
  final _paypalClientIdCtrl = TextEditingController();
  final _paypalSecretCtrl = TextEditingController();

  // 5. Africa (M-Pesa)
  bool _mpesaEnabled = false;
  String _mpesaEnv = 'sandbox';
  String _mpesaType = 'till';
  final _mpesaShortcodeCtrl = TextEditingController();
  final _mpesaConsumerKeyCtrl = TextEditingController();
  final _mpesaConsumerSecretCtrl = TextEditingController();
  final _mpesaPasskeyCtrl = TextEditingController();

  // Test STK Push
  final _testPhoneCtrl = TextEditingController();
  final _testAmountCtrl = TextEditingController(text: '1.00');
  bool _testingPush = false;
  String? _testResultLog;

  static const Color primaryBlue = Color(0xFF0B5CAD);
  static const Color safaricomGreen = Color(0xFF00A859);
  static const Color stripePurple = Color(0xFF635BFF);
  static const Color razorpayBlue = Color(0xFF0C2340);
  static const Color darkBlue = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upiIdCtrl.dispose();
    _upiPayeeNameCtrl.dispose();
    _razorpayKeyIdCtrl.dispose();
    _razorpaySecretCtrl.dispose();
    _indiaPosIpCtrl.dispose();
    _indiaPosIdCtrl.dispose();
    _stripePubCtrl.dispose();
    _stripeSecretCtrl.dispose();
    _squareAppIdCtrl.dispose();
    _squareLocationIdCtrl.dispose();
    _squareTokenCtrl.dispose();
    _paypalClientIdCtrl.dispose();
    _paypalSecretCtrl.dispose();
    _mpesaShortcodeCtrl.dispose();
    _mpesaConsumerKeyCtrl.dispose();
    _mpesaConsumerSecretCtrl.dispose();
    _mpesaPasskeyCtrl.dispose();
    _testPhoneCtrl.dispose();
    _testAmountCtrl.dispose();
    super.dispose();
  }

  // Detect which country/region currently has active gateways
  String get _currentActiveRegion {
    if (_upiEnabled || _razorpayEnabled || _indiaPosEnabled) return 'INDIA';
    if (_stripeEnabled || _squareEnabled) return 'AMERICAS';
    if (_paypalEnabled) return 'EUROPE';
    if (_mpesaEnabled) return 'AFRICA';
    return 'NONE';
  }

  String _getRegionLabel(String region) {
    switch (region) {
      case 'INDIA':
        return '🇮🇳 India (UPI, Razorpay, PineLabs)';
      case 'AMERICAS':
        return '🇺🇸 Americas (Stripe & Square)';
      case 'EUROPE':
        return '🇪🇺 Europe & UK (PayPal)';
      case 'AFRICA':
        return '🌍 Africa (Safaricom M-Pesa)';
      default:
        return 'Standard POS (Cash / Card / Bank)';
    }
  }

  // Enforce single active country policy
  Future<bool> _checkAndSwitchRegion(String targetRegion) async {
    final current = _currentActiveRegion;
    if (current == 'NONE' || current == targetRegion) {
      return true;
    }

    final currentLabel = _getRegionLabel(current);
    final targetLabel = _getRegionLabel(targetRegion);

    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: primaryBlue, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Switch Operational Region?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your store currently has active payment gateways in:\n$currentLabel',
              style: const TextStyle(fontWeight: FontWeight.w600, color: darkBlue, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Only ONE country/region\'s live payment gateways can be active at a time to prevent multi-currency and settlement conflicts.\n\nActivating $targetLabel will deactivate $currentLabel gateways.',
                style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Switch to $targetRegion'),
          ),
        ],
      ),
    );

    if (shouldSwitch == true) {
      setState(() {
        // Disable other regions
        if (targetRegion != 'INDIA') {
          _upiEnabled = false;
          _razorpayEnabled = false;
          _indiaPosEnabled = false;
        }
        if (targetRegion != 'AMERICAS') {
          _stripeEnabled = false;
          _squareEnabled = false;
        }
        if (targetRegion != 'EUROPE') {
          _paypalEnabled = false;
        }
        if (targetRegion != 'AFRICA') {
          _mpesaEnabled = false;
        }
      });
      return true;
    }
    return false;
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadConfig(),
      _loadPaymentMethods(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _loadingMethods = true);
    try {
      final list = await _salesCtrl.listPaymentMethods();
      if (mounted) {
        setState(() {
          _dbPaymentMethods = list.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    } finally {
      if (mounted) setState(() => _loadingMethods = false);
    }
  }

  Future<void> _loadConfig() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.paymentGatewaysConfig);
      if (res['success'] == true && res['data'] != null) {
        final d = res['data'];
        setState(() {
          _enablePaymentGateway = d['enable_payment_gateway'] == true;
          _settlementMode = d['settlement_mode'] ?? 'DIRECT';

          // UPI
          final upi = d['upi'] ?? {};
          _upiEnabled = upi['enabled'] ?? true;
          _upiIdCtrl.text = upi['upi_id'] ?? '';
          _upiPayeeNameCtrl.text = upi['payee_name'] ?? '';
          _printUpiQr = upi['print_upi_qr'] ?? true;

          // Razorpay
          final rz = d['razorpay'] ?? {};
          _razorpayEnabled = rz['enabled'] ?? false;
          _razorpayEnv = rz['env'] ?? 'test';
          _razorpayKeyIdCtrl.text = rz['key_id'] ?? '';
          _razorpaySecretCtrl.text = rz['key_secret'] ?? '';

          // India Connected Smart POS Card Machine (PineLabs / Ezetap / Mosambee)
          final inPos = d['india_pos'] ?? {};
          _indiaPosEnabled = inPos['enabled'] ?? false;
          _indiaPosProvider = inPos['provider'] ?? 'pinelabs';
          _indiaPosIpCtrl.text = inPos['device_ip'] ?? '';
          _indiaPosIdCtrl.text = inPos['pos_id'] ?? '';
          _indiaPosAutoPush = inPos['auto_push'] ?? true;

          // Stripe
          final st = d['stripe'] ?? {};
          _stripeEnabled = st['enabled'] ?? false;
          _stripeEnv = st['env'] ?? 'test';
          _stripePubCtrl.text = st['publishable_key'] ?? '';
          _stripeSecretCtrl.text = st['secret_key'] ?? '';

          // Square
          final sq = d['square'] ?? {};
          _squareEnabled = sq['enabled'] ?? false;
          _squareEnv = sq['env'] ?? 'sandbox';
          _squareAppIdCtrl.text = sq['app_id'] ?? '';
          _squareLocationIdCtrl.text = sq['location_id'] ?? '';
          _squareTokenCtrl.text = sq['access_token'] ?? '';

          // PayPal
          final pp = d['paypal'] ?? {};
          _paypalEnabled = pp['enabled'] ?? false;
          _paypalEnv = pp['env'] ?? 'sandbox';
          _paypalClientIdCtrl.text = pp['client_id'] ?? '';
          _paypalSecretCtrl.text = pp['client_secret'] ?? '';

          // M-Pesa
          final mp = d['mpesa'] ?? {};
          _mpesaEnabled = mp['enabled'] ?? false;
          _mpesaEnv = mp['env'] ?? 'sandbox';
          _mpesaType = mp['type'] ?? 'till';
          _mpesaShortcodeCtrl.text = mp['shortcode'] ?? '';
          _mpesaConsumerKeyCtrl.text = mp['consumer_key'] ?? '';
          _mpesaConsumerSecretCtrl.text = mp['consumer_secret'] ?? '';
          _mpesaPasskeyCtrl.text = mp['passkey'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading gateways config: $e');
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'enable_payment_gateway': _enablePaymentGateway,
        'settlement_mode': _settlementMode,
        'upi': {
          'enabled': _upiEnabled,
          'upi_id': _upiIdCtrl.text.trim(),
          'payee_name': _upiPayeeNameCtrl.text.trim(),
          'print_upi_qr': _printUpiQr,
        },
        'razorpay': {
          'enabled': _razorpayEnabled,
          'env': _razorpayEnv,
          'key_id': _razorpayKeyIdCtrl.text.trim(),
          'key_secret': _razorpaySecretCtrl.text.trim(),
        },
        'india_pos': {
          'enabled': _indiaPosEnabled,
          'provider': _indiaPosProvider,
          'device_ip': _indiaPosIpCtrl.text.trim(),
          'pos_id': _indiaPosIdCtrl.text.trim(),
          'auto_push': _indiaPosAutoPush,
        },
        'stripe': {
          'enabled': _stripeEnabled,
          'env': _stripeEnv,
          'publishable_key': _stripePubCtrl.text.trim(),
          'secret_key': _stripeSecretCtrl.text.trim(),
        },
        'square': {
          'enabled': _squareEnabled,
          'env': _squareEnv,
          'app_id': _squareAppIdCtrl.text.trim(),
          'location_id': _squareLocationIdCtrl.text.trim(),
          'access_token': _squareTokenCtrl.text.trim(),
        },
        'paypal': {
          'enabled': _paypalEnabled,
          'env': _paypalEnv,
          'client_id': _paypalClientIdCtrl.text.trim(),
          'client_secret': _paypalSecretCtrl.text.trim(),
        },
        'mpesa': {
          'enabled': _mpesaEnabled,
          'env': _mpesaEnv,
          'type': _mpesaType,
          'shortcode': _mpesaShortcodeCtrl.text.trim(),
          'consumer_key': _mpesaConsumerKeyCtrl.text.trim(),
          'consumer_secret': _mpesaConsumerSecretCtrl.text.trim(),
          'passkey': _mpesaPasskeyCtrl.text.trim(),
        },
      };

      final res = await ApiClient.post(ApiEndpoints.paymentGatewaysConfig, payload);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment & Settlement Settings saved successfully!'),
              backgroundColor: primaryBlue,
            ),
          );
          await _loadConfig();
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

  Future<void> _togglePaymentMethodActive(int id, String name, bool val) async {
    if (name.toUpperCase() == 'CASH') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primary Cash payment method cannot be disabled.'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      await _salesCtrl.updatePaymentMethod(id, name: name, isActive: val);
      setState(() {
        final idx = _dbPaymentMethods.indexWhere((m) => m['id'] == id);
        if (idx != -1) {
          _dbPaymentMethods[idx]['is_active'] = val;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name payment mode ${val ? 'enabled' : 'disabled'} successfully.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddEditPaymentMethodDialog({Map<String, dynamic>? method}) async {
    final isEdit = method != null;
    final nameCtrl = TextEditingController(text: isEdit ? method['name'] : '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Payment Method' : 'Add New Payment Method', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify a descriptive payment method label (e.g. SWIGGY, ZOMATO, GPAY, PHONEPE, PINELABS, AMEX, CHEQUE, M-PESA).',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Payment Method Name',
                hintText: 'e.g. PHONEPE, GPAY, SWIGGY, PINELABS',
                prefixIcon: Icon(Icons.payment_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                if (isEdit) {
                  await _salesCtrl.updatePaymentMethod(method['id'], name: name, isActive: method['is_active'] == true);
                } else {
                  await _salesCtrl.createPaymentMethod(name);
                }
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Payment method updated successfully.' : 'Payment method added successfully.'),
                    backgroundColor: primaryBlue,
                  ),
                );
                _loadPaymentMethods();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Method'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePaymentMethod(int id, String name) async {
    if (name.toUpperCase() == 'CASH') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash payment method cannot be deleted.'), backgroundColor: Colors.red),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text('Are you sure you want to delete payment method "$name"?\nNote: If this method has already been used in recorded sales, it will be kept to preserve accounting integrity.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _salesCtrl.deletePaymentMethod(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment method deleted successfully.')),
      );
      _loadPaymentMethods();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _triggerTestMpesaPush() async {
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
            const SnackBar(content: Text('STK Push Sent! Check phone for PIN prompt.'), backgroundColor: safaricomGreen),
          );
        } else {
          setState(() {
            _testResultLog = 'FAILED: ${res['message']}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'STK push failed'), backgroundColor: Colors.red),
          );
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

  IconData _getPaymentIcon(String name) {
    final n = name.trim().toUpperCase();
    if (n == 'CASH') return Icons.payments_rounded;
    if (n == 'CARD' || n.contains('VISA') || n.contains('MASTER') || n.contains('AMEX') || n.contains('PINELABS')) return Icons.credit_card_rounded;
    if (n == 'UPI' || n.contains('GPAY') || n.contains('PHONEPE') || n.contains('PAYTM') || n.contains('QR')) return Icons.qr_code_rounded;
    if (n == 'BANK' || n.contains('TRANSFER') || n.contains('NEFT') || n.contains('RTGS') || n.contains('IMPS')) return Icons.account_balance_rounded;
    if (n == 'CREDIT' || n.contains('UDHAR') || n.contains('DUE')) return Icons.account_balance_wallet_rounded;
    if (n == 'MPESA' || n.contains('PESA') || n.contains('MOBILE')) return Icons.phone_android_rounded;
    if (n == 'STRIPE' || n == 'SQUARE' || n == 'PAYPAL') return Icons.lock_outline_rounded;
    return Icons.payment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final activeReg = _currentActiveRegion;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment & Settlement Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                Icon(
                  activeReg != 'NONE' ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 13,
                  color: activeReg != 'NONE' ? Colors.green.shade600 : Colors.amber.shade800,
                ),
                const SizedBox(width: 5),
                Text(
                  activeReg != 'NONE'
                      ? 'Active Operational Region: ${_getRegionLabel(activeReg)}'
                      : 'Active Operational Region: Standard (No regional gateways active)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: activeReg != 'NONE' ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF0FDF4),
                foregroundColor: const Color(0xFF166534),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () {
                VirtualPaymentSimulatorDialog.show(
                  context,
                  amount: 1500.00,
                  initialMethod: _tabController.index == 1 ? 'UPI' : (_tabController.index == 2 ? 'CARD' : (_tabController.index == 4 ? 'MPESA' : 'UPI')),
                  upiId: _upiIdCtrl.text,
                  upiPayeeName: _upiPayeeNameCtrl.text,
                  mpesaPhone: _testPhoneCtrl.text.isNotEmpty ? _testPhoneCtrl.text : '254712345678',
                  posDeviceName: _indiaPosProvider == 'ezetap' ? 'Ezetap Smart POS' : (_indiaPosProvider == 'mosambee' ? 'Mosambee POS' : 'PineLabs Android POS'),
                );
              },
              icon: const Icon(Icons.developer_board, size: 18, color: Color(0xFF16A34A)),
              label: const Text('🧪 Virtual POS Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _saving ? null : _saveConfig,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: '💳 Payment Methods & Settlement'),
            Tab(icon: Icon(Icons.qr_code_2_rounded, size: 18), text: '🇮🇳 India (UPI, Razorpay, PineLabs)'),
            Tab(icon: Icon(Icons.credit_card_rounded, size: 18), text: '🇺🇸 Americas (Stripe & Square)'),
            Tab(icon: Icon(Icons.euro_rounded, size: 18), text: '🇪🇺 Europe & UK (PayPal)'),
            Tab(icon: Icon(Icons.phone_android_rounded, size: 18), text: '🌍 Africa (M-Pesa)'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSettlementTab(),
                _buildIndiaTab(),
                _buildAmericasTab(),
                _buildEuropeTab(),
                _buildAfricaTab(),
              ],
            ),
    );
  }

  Widget _buildSettlementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Payment Gateway & Virtual POS Simulator',
            subtitle: 'Enable or disable payment gateways and the POS sandbox simulator on checkout',
            icon: Icons.developer_board,
            iconColor: Colors.teal,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.teal,
              title: const Text('Enable Payment Gateway & POS Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('When enabled, payment gateways and the Virtual POS Simulator (UPI / Smart Card / M-Pesa test charges) will be displayed on the checkout dialog. When disabled, the simulator is completely hidden.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              value: _enablePaymentGateway,
              onChanged: (v) => setState(() => _enablePaymentGateway = v),
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'POS Checkout & Bill Settlement Rules',
            subtitle: 'Choose how retail sales bills and restaurant table checks are settled at POS terminals',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: primaryBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Default Settlement Workflow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'DIRECT',
                  groupValue: _settlementMode,
                  activeColor: primaryBlue,
                  title: const Text('⚡ Direct Settlement (Instant Pay & Print)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Best for Supermarkets, Retail Counters, Quick Service, and Takeaway. Invoice is marked Paid & Final Bill printed immediately.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  onChanged: (v) => setState(() => _settlementMode = v!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'PRINT_FIRST',
                  groupValue: _settlementMode,
                  activeColor: primaryBlue,
                  title: const Text('🖨️ Bill Print First, Settle Later (Dine-In Restaurant / Running Tabs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Waiter prints a Pre-Bill check / Proforma invoice with QR / Till number. The table remains occupied until payment is verified and settled.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  onChanged: (v) => setState(() => _settlementMode = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildCard(
            title: 'Active POS Payment Methods',
            subtitle: 'Manage and customize payment modes accepted during checkouts. (Only CASH is strictly primary and cannot be disabled; all others can be toggled on/off)',
            icon: Icons.checklist_rounded,
            iconColor: primaryBlue,
            action: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _showAddEditPaymentMethodDialog(),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Add Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            child: _loadingMethods
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _dbPaymentMethods.isEmpty
                    ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No payment methods found. Click "+ Add Method" to add one.')),
                  )
                    : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _dbPaymentMethods.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final method = _dbPaymentMethods[index];
                      final id = method['id'];
                      final name = (method['name'] ?? '').toString();
                      final isSystem = method['is_system'] == true;
                      final isActive = method['is_active'] == true;
                      final isCash = name.toUpperCase() == 'CASH';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isActive ? primaryBlue.withOpacity(0.1) : Colors.grey.shade200,
                          foregroundColor: isActive ? primaryBlue : Colors.grey.shade500,
                          child: Icon(_getPaymentIcon(name), size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isActive ? darkBlue : Colors.grey.shade600,
                              ),
                            ),
                            if (isSystem) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isCash ? 'Primary' : 'System',
                                  style: const TextStyle(color: Colors.blue, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          isCash ? 'Cash is primary currency mode and always enabled' : 'ID: $id | Visible at POS settlement dialog',
                          style: TextStyle(fontSize: 11.5, color: isCash ? Colors.indigo : Colors.black45),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: isCash ? 'Cash cannot be disabled' : (isActive ? 'Disable Method' : 'Enable Method'),
                              child: Switch.adaptive(
                                activeColor: primaryBlue,
                                value: isCash ? true : isActive,
                                onChanged: isCash
                                    ? null
                                    : (val) => _togglePaymentMethodActive(id, name, val),
                              ),
                            ),
                            if (!isCash) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Rename Method',
                                onPressed: () => _showAddEditPaymentMethodDialog(method: method),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Delete Method',
                                onPressed: () => _deletePaymentMethod(id, name),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndiaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. UPI Dynamic QR
          _buildCard(
            title: '1. Dynamic UPI QR (PhonePe / Google Pay / Paytm / BHIM)',
            subtitle: 'Generate live dynamic UPI QR codes with bill amount auto-filled on POS screen and printed invoices',
            icon: Icons.qr_code_2_rounded,
            iconColor: Colors.deepOrange,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.deepOrange,
                  title: const Text('Enable UPI Dynamic QR at Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _upiEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('INDIA');
                      if (!canProceed) return;
                    }
                    setState(() => _upiEnabled = v);
                  },
                ),
                if (_upiEnabled) ...[
                  const Divider(),
                  _buildTextField(
                    controller: _upiIdCtrl,
                    label: 'UPI VPA / Merchant UPI ID',
                    hint: 'e.g. storename@okaxis, merchant@icici',
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _upiPayeeNameCtrl,
                    label: 'Payee Merchant Legal Name',
                    hint: 'e.g. Famalth Retail Store',
                    icon: Icons.store_rounded,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.deepOrange,
                    title: const Text('Print Dynamic UPI QR on Invoice Slip', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Prints custom QR with bill amount embedded for instant customer scanning', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    value: _printUpiQr,
                    onChanged: (v) => setState(() => _printUpiQr = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Razorpay Smart Gateway
          _buildCard(
            title: '2. Razorpay Payment Gateway & Links',
            subtitle: 'Accept Credit/Debit cards, NetBanking, and Razorpay Smart POS links',
            icon: Icons.bolt_rounded,
            iconColor: razorpayBlue,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: razorpayBlue,
                  title: const Text('Enable Razorpay Gateway', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _razorpayEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('INDIA');
                      if (!canProceed) return;
                    }
                    setState(() => _razorpayEnabled = v);
                  },
                ),
                if (_razorpayEnabled) ...[
                  const Divider(),
                  _buildEnvSelector(
                    value: _razorpayEnv,
                    onChanged: (v) => setState(() => _razorpayEnv = v),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _razorpayKeyIdCtrl,
                    label: 'Key ID (rzp_test_... / rzp_live_...)',
                    hint: 'rzp_test_xxxxxxxxxx',
                    icon: Icons.key_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _razorpaySecretCtrl,
                    label: 'Key Secret',
                    hint: 'Enter secret key',
                    isSecret: true,
                    icon: Icons.lock_outline_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Connected Smart POS Card Machines (PineLabs / Ezetap / Mosambee / Plutus)
          _buildCard(
            title: '3. Connected Smart POS Card Machines (PineLabs / Ezetap / Mosambee)',
            subtitle: 'Auto-push bill amount directly to physical card swipe/tap machine (Cashier does not need to type amount manually on machine)',
            icon: Icons.point_of_sale_rounded,
            iconColor: Colors.teal.shade700,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.teal.shade700,
                  title: const Text('Enable Connected POS Card Machine', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _indiaPosEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('INDIA');
                      if (!canProceed) return;
                    }
                    setState(() => _indiaPosEnabled = v);
                  },
                ),
                if (_indiaPosEnabled) ...[
                  const Divider(),
                  DropdownButtonFormField<String>(
                    value: _indiaPosProvider,
                    decoration: const InputDecoration(
                      labelText: 'Select POS Terminal Hardware Provider',
                      prefixIcon: Icon(Icons.developer_board_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pinelabs', child: Text('PineLabs Plutus Smart Terminal (LAN / Wi-Fi / Cloud)')),
                      DropdownMenuItem(value: 'ezetap', child: Text('Ezetap / Razorpay POS Smart Terminal')),
                      DropdownMenuItem(value: 'mosambee', child: Text('Mosambee / Mswipe Smart POS Terminal')),
                    ],
                    onChanged: (v) => setState(() => _indiaPosProvider = v ?? 'pinelabs'),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _indiaPosIpCtrl,
                    label: 'Terminal Local IP Address or COM Port (e.g. 192.168.1.150 or COM3)',
                    hint: '192.168.1.150',
                    icon: Icons.settings_ethernet_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _indiaPosIdCtrl,
                    label: 'POS Machine Terminal ID / Store Identifier',
                    hint: 'e.g. PLUTUS_COUNTER_01',
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.teal.shade700,
                    title: const Text('Auto-push Bill Amount on Checkout', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sends exact payable bill amount to card machine automatically when CARD payment is chosen', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    value: _indiaPosAutoPush,
                    onChanged: (v) => setState(() => _indiaPosAutoPush = v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmericasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. Stripe Terminal
          _buildCard(
            title: '1. Stripe Terminal & Readers (USA, Canada, Americas)',
            subtitle: 'Card readers (BBPOS WisePOS E, Verifone), Apple Pay, Google Pay, and online invoice links',
            icon: Icons.credit_card_rounded,
            iconColor: stripePurple,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: stripePurple,
                  title: const Text('Enable Stripe Terminal & Processing', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _stripeEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('AMERICAS');
                      if (!canProceed) return;
                    }
                    setState(() => _stripeEnabled = v);
                  },
                ),
                if (_stripeEnabled) ...[
                  const Divider(),
                  _buildEnvSelector(
                    value: _stripeEnv,
                    onChanged: (v) => setState(() => _stripeEnv = v),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _stripePubCtrl,
                    label: 'Publishable Key (pk_test_... / pk_live_...)',
                    hint: 'pk_test_51xxxxxxxxxxxx',
                    icon: Icons.vpn_key_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _stripeSecretCtrl,
                    label: 'Secret Key (sk_test_... / sk_live_...)',
                    hint: 'sk_test_51xxxxxxxxxxxx',
                    isSecret: true,
                    icon: Icons.lock_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Square POS Terminal
          _buildCard(
            title: '2. Square POS Terminal Integration',
            subtitle: 'Square Terminal hardware swipe, tap & chip reader integration with auto-amount push',
            icon: Icons.crop_square_rounded,
            iconColor: darkBlue,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: darkBlue,
                  title: const Text('Enable Square POS Integration', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _squareEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('AMERICAS');
                      if (!canProceed) return;
                    }
                    setState(() => _squareEnabled = v);
                  },
                ),
                if (_squareEnabled) ...[
                  const Divider(),
                  _buildEnvSelector(
                    value: _squareEnv,
                    onChanged: (v) => setState(() => _squareEnv = v),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _squareAppIdCtrl,
                    label: 'Square Application ID (sq0idp-...)',
                    hint: 'sq0idp-xxxxxxxxxxxx',
                    icon: Icons.apps_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _squareLocationIdCtrl,
                    label: 'Square Location ID',
                    hint: 'e.g. LXXXXXXXXXXXX',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _squareTokenCtrl,
                    label: 'Square Access Token',
                    hint: 'EAAAE...',
                    isSecret: true,
                    icon: Icons.shield_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEuropeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCard(
            title: 'PayPal & European Digital Gateways (EU / UK / Global)',
            subtitle: 'Accept EUR, GBP, and multi-currency PayPal checkout and digital wallets',
            icon: Icons.euro_rounded,
            iconColor: primaryBlue,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: primaryBlue,
                  title: const Text('Enable PayPal Gateway', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _paypalEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('EUROPE');
                      if (!canProceed) return;
                    }
                    setState(() => _paypalEnabled = v);
                  },
                ),
                if (_paypalEnabled) ...[
                  const Divider(),
                  _buildEnvSelector(
                    value: _paypalEnv,
                    onChanged: (v) => setState(() => _paypalEnv = v),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _paypalClientIdCtrl,
                    label: 'PayPal Client ID',
                    hint: 'Enter PayPal Client ID',
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _paypalSecretCtrl,
                    label: 'PayPal Client Secret',
                    hint: 'Enter PayPal Client Secret',
                    isSecret: true,
                    icon: Icons.key_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfricaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCard(
            title: 'Safaricom M-Pesa Daraja 2.0 (Kenya & East Africa)',
            subtitle: 'STK Push (Lipa Na M-Pesa Online), Till Numbers (Buy Goods), and Paybill with instant customer mobile PIN prompt',
            icon: Icons.phone_android_rounded,
            iconColor: safaricomGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: safaricomGreen,
                  title: const Text('Enable Safaricom M-Pesa', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _mpesaEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final canProceed = await _checkAndSwitchRegion('AFRICA');
                      if (!canProceed) return;
                    }
                    setState(() => _mpesaEnabled = v);
                  },
                ),
                if (_mpesaEnabled) ...[
                  const Divider(),
                  _buildEnvSelector(
                    value: _mpesaEnv,
                    onChanged: (v) => setState(() => _mpesaEnv = v),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Business Mode: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Till Number (Buy Goods)'),
                        selected: _mpesaType == 'till',
                        selectedColor: safaricomGreen.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _mpesaType == 'till' ? safaricomGreen : Colors.black87,
                          fontWeight: _mpesaType == 'till' ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _mpesaType = 'till');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Paybill Number'),
                        selected: _mpesaType == 'paybill',
                        selectedColor: safaricomGreen.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _mpesaType == 'paybill' ? safaricomGreen : Colors.black87,
                          fontWeight: _mpesaType == 'paybill' ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _mpesaType = 'paybill');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _mpesaShortcodeCtrl,
                    label: _mpesaType == 'till' ? 'Till Number / Store Number' : 'Paybill Business Shortcode',
                    hint: _mpesaType == 'till' ? 'e.g. 174379' : 'e.g. 400200',
                    icon: Icons.store_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _mpesaConsumerKeyCtrl,
                    label: 'Daraja Consumer Key',
                    hint: 'Enter Daraja Consumer Key',
                    icon: Icons.vpn_key_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _mpesaConsumerSecretCtrl,
                    label: 'Daraja Consumer Secret',
                    hint: 'Enter Daraja Consumer Secret',
                    isSecret: true,
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _mpesaPasskeyCtrl,
                    label: 'Lipa Na M-Pesa Online Passkey',
                    hint: 'Enter Passkey (for STK Push prompt on customer phone)',
                    isSecret: true,
                    icon: Icons.shield_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Diagnostic Tool
          _buildCard(
            title: 'Live Safaricom STK Push Diagnostics',
            subtitle: 'Send a live test STK prompt to a customer mobile phone to verify API keys',
            icon: Icons.wifi_tethering_rounded,
            iconColor: safaricomGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _testPhoneCtrl,
                        label: 'Test Safaricom Phone Number',
                        hint: 'e.g. 254712345678',
                        icon: Icons.phone_iphone_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        controller: _testAmountCtrl,
                        label: 'Amount (KES)',
                        hint: '1.00',
                        icon: Icons.money_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: safaricomGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _testingPush ? null : _triggerTestMpesaPush,
                      icon: _testingPush
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_testingPush ? 'Sending...' : 'Send STK Test'),
                    ),
                  ],
                ),
                if (_testResultLog != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _testResultLog!,
                      style: const TextStyle(color: Colors.lightGreenAccent, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isSecret = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isSecret,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildEnvSelector({required String value, required ValueChanged<String> onChanged}) {
    return Row(
      children: [
        const Text('Environment Mode: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('🧪 Sandbox / Test Mode'),
          selected: value == 'test' || value == 'sandbox',
          selectedColor: Colors.amber.shade100,
          labelStyle: TextStyle(
            color: (value == 'test' || value == 'sandbox') ? Colors.amber.shade900 : Colors.black87,
            fontWeight: (value == 'test' || value == 'sandbox') ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (val) {
            if (val) onChanged(value.contains('sandbox') ? 'sandbox' : 'test');
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('🚀 Live / Production'),
          selected: value == 'live' || value == 'production',
          selectedColor: Colors.green.shade100,
          labelStyle: TextStyle(
            color: (value == 'live' || value == 'production') ? Colors.green.shade900 : Colors.black87,
            fontWeight: (value == 'live' || value == 'production') ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (val) {
            if (val) onChanged(value.contains('sandbox') ? 'production' : 'live');
          },
        ),
      ],
    );
  }
}
