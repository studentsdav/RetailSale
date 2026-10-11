import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/currency/currency_service.dart';

class VirtualPaymentResult {
  final String method; // 'UPI', 'CARD', 'MPESA', 'STRIPE', 'SQUARE', 'RAZORPAY', 'PAYPAL'
  final double amount;
  final String referenceId;
  final String? authCode;
  final String? rrn;
  final String? cardBrand;
  final String? last4;
  final String? phone;
  final String status; // 'SUCCESS' | 'DECLINED'
  final String message;
  final DateTime timestamp;

  VirtualPaymentResult({
    required this.method,
    required this.amount,
    required this.referenceId,
    this.authCode,
    this.rrn,
    this.cardBrand,
    this.last4,
    this.phone,
    required this.status,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class VirtualPaymentSimulatorDialog extends StatefulWidget {
  final double amount;
  final String initialMethod; // 'UPI', 'CARD', 'MPESA', 'ALL'
  final String? billNo;
  final String? upiId;
  final String? upiPayeeName;
  final String? mpesaPhone;
  final String? posDeviceName; // 'PineLabs Android POS', 'Square Terminal', etc.

  const VirtualPaymentSimulatorDialog({
    super.key,
    required this.amount,
    this.initialMethod = 'UPI',
    this.billNo,
    this.upiId,
    this.upiPayeeName,
    this.mpesaPhone,
    this.posDeviceName,
  });

  static Future<VirtualPaymentResult?> show(
    BuildContext context, {
    required double amount,
    String initialMethod = 'UPI',
    String? billNo,
    String? upiId,
    String? upiPayeeName,
    String? mpesaPhone,
    String? posDeviceName,
  }) {
    return showDialog<VirtualPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VirtualPaymentSimulatorDialog(
        amount: amount,
        initialMethod: initialMethod,
        billNo: billNo,
        upiId: upiId,
        upiPayeeName: upiPayeeName,
        mpesaPhone: mpesaPhone,
        posDeviceName: posDeviceName,
      ),
    );
  }

  @override
  State<VirtualPaymentSimulatorDialog> createState() => _VirtualPaymentSimulatorDialogState();
}

class _VirtualPaymentSimulatorDialogState extends State<VirtualPaymentSimulatorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _amount;
  late String _billNo;
  final TextEditingController _amountCtrl = TextEditingController();

  // India UPI state
  late String _upiId;
  late String _upiPayeeName;
  bool _upiScanning = false;
  bool _upiSuccess = false;
  String? _upiUtr;

  // Smart POS Card Machine state
  String _posProvider = 'PineLabs Smart POS';
  String _cardState = 'READY'; // 'READY', 'INSERTING', 'PIN_REQUIRED', 'PROCESSING', 'APPROVED', 'DECLINED'
  String _cardBrand = 'VISA';
  final String _cardLast4 = '4242';
  String _enteredPin = '';
  String? _posRrn;
  String? _posAuthCode;

  // Africa M-Pesa STK Push state
  late String _mpesaPhone;
  String _mpesaState = 'READY'; // 'READY', 'PUSHING', 'PHONE_PROMPT', 'PROCESSING', 'APPROVED', 'DECLINED'
  String _mpesaEnteredPin = '';
  String? _mpesaReceipt;

  // Real-time Logs
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _amount = widget.amount > 0 ? widget.amount : 100.0;
    _billNo = widget.billNo ?? 'BILL-${Random().nextInt(899999) + 100000}';
    _upiId = widget.upiId?.isNotEmpty == true ? widget.upiId! : 'merchant@upi';
    _upiPayeeName = widget.upiPayeeName?.isNotEmpty == true ? widget.upiPayeeName! : 'Retail POS Store';
    _mpesaPhone = widget.mpesaPhone?.isNotEmpty == true ? widget.mpesaPhone! : '254712345678';
    _posProvider = widget.posDeviceName ?? 'PineLabs Smart POS v3.2';

    _amountCtrl.text = _amount.toStringAsFixed(2);

    int initialIndex = 0;
    final m = widget.initialMethod.toUpperCase();
    if (m == 'CARD' || m == 'STRIPE' || m == 'SQUARE') {
      initialIndex = 1;
    } else if (m == 'MPESA') {
      initialIndex = 2;
    }

    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _log('⚡ Virtual POS Simulator Initialized in Sandbox Test Mode.');
    _log('📋 Bill No: $_billNo | Amount to Settle: ${CurrencyService.format(_amount)}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _log(String message) {
    final timeStr = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    setState(() {
      _logs.insert(0, '[$timeStr] $message');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  String _generateUpiQrString() {
    return 'upi://pay?pa=$_upiId&pn=${Uri.encodeComponent(_upiPayeeName)}&am=${_amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("POS Bill $_billNo")}';
  }

  // -------------------------------------------------------------
  // UPI SIMULATION LOGIC
  // -------------------------------------------------------------
  Future<void> _simulateUpiSuccess() async {
    setState(() {
      _upiScanning = true;
    });
    _log('📱 Customer opened PhonePe / Google Pay app and scanned dynamic QR code.');
    _log('🔄 Customer authorized bank PIN for ${CurrencyService.format(_amount)}...');

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final utr = 'UPI${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
    setState(() {
      _upiScanning = false;
      _upiSuccess = true;
      _upiUtr = utr;
    });

    _log('✅ Bank Payment Confirmed! NPCI / Bank UTR: $utr');
    _log('🎉 Instant settlement callback broadcasted to POS checkout system.');
  }

  void _simulateUpiDecline() {
    setState(() {
      _upiScanning = false;
      _upiSuccess = false;
      _upiUtr = null;
    });
    _log('❌ UPI Transaction Cancelled / Declined by Customer or Bank timeout.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI Payment declined by user/bank simulator.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // -------------------------------------------------------------
  // CARD MACHINE (PINE LABS / EZETAP / SQUARE) SIMULATION LOGIC
  // -------------------------------------------------------------
  Future<void> _simulateCardInsertOrTap({bool isTap = false}) async {
    setState(() {
      _cardState = 'INSERTING';
      _enteredPin = '';
    });
    _log('💳 ${isTap ? "Contactless NFC Card Tapped" : "EMV Chip Card Inserted"}: $_cardBrand **** $_cardLast4');
    _log('📟 Terminal LCD: "READING CARD DATA..."');

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (isTap && _amount <= 5000) {
      _processCardAuthorization();
    } else {
      setState(() {
        _cardState = 'PIN_REQUIRED';
      });
      _log('🔐 Terminal LCD: "PLEASE ENTER 4-DIGIT PIN ON PAD"');
    }
  }

  Future<void> _processCardAuthorization() async {
    setState(() {
      _cardState = 'PROCESSING';
    });
    _log('🌐 Connecting to Payment Gateway Host & Bank Switch...');

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final rrn = 'RRN${(Random().nextInt(89999999) + 10000000)}';
    final auth = 'AUTH${(Random().nextInt(899999) + 100000)}';

    setState(() {
      _cardState = 'APPROVED';
      _posRrn = rrn;
      _posAuthCode = auth;
    });

    _log('✅ TERMINAL RESPONSE: 00 - APPROVED');
    _log('🧾 Auth Code: $auth | RRN: $rrn | Card: $_cardBrand **** $_cardLast4');
    _log('🖨️ Thermal Charge Slip Ready. Returning confirmation to POS.');
  }

  void _simulateCardDecline() {
    setState(() {
      _cardState = 'DECLINED';
      _posRrn = null;
      _posAuthCode = null;
    });
    _log('❌ TERMINAL RESPONSE: 05 - DO NOT HONOR / INSUFFICIENT FUNDS');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Card Declined (Simulated 05: Do Not Honor).'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // -------------------------------------------------------------
  // AFRICA M-PESA STK PUSH SIMULATION LOGIC
  // -------------------------------------------------------------
  Future<void> _simulateMpesaPush() async {
    setState(() {
      _mpesaState = 'PUSHING';
      _mpesaEnteredPin = '';
    });
    _log('📲 Sending Safaricom Daraja STK Push prompt to $_mpesaPhone...');

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _mpesaState = 'PHONE_PROMPT';
    });
    _log('📱 Customer Mobile Screen: SIM Toolkit Modal displayed on handset.');
    _log('💬 Prompt: "Do you want to pay ${CurrencyService.format(_amount)} to $_upiPayeeName? Enter M-Pesa PIN:"');
  }

  Future<void> _simulateMpesaConfirmPin() async {
    setState(() {
      _mpesaState = 'PROCESSING';
    });
    _log('🔄 Customer entered 4-digit PIN. Transmitting to Safaricom core switch...');

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final receipt = 'Q${List.generate(9, (index) => chars[Random().nextInt(chars.length)]).join()}';

    setState(() {
      _mpesaState = 'APPROVED';
      _mpesaReceipt = receipt;
    });

    _log('✅ Safaricom Webhook Callback: ResultCode: 0 (The service request is processed successfully)');
    _log('📩 M-Pesa Receipt Number: $receipt | Phone: $_mpesaPhone | Amount: ${CurrencyService.format(_amount)}');
    _log('🎉 Instant STK callback received. POS invoice ready for automatic settlement.');
  }

  void _simulateMpesaCancel() {
    setState(() {
      _mpesaState = 'DECLINED';
      _mpesaReceipt = null;
    });
    _log('❌ Safaricom Webhook Callback: ResultCode: 1032 (Request cancelled by user).');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('M-Pesa STK Push cancelled by customer phone simulator.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // -------------------------------------------------------------
  // FINALIZE AND RETURN TO POS
  // -------------------------------------------------------------
  void _completeAndReturn(String method, {required String ref, String? rrn, String? auth, String? brand, String? last4, String? phone}) {
    final result = VirtualPaymentResult(
      method: method,
      amount: _amount,
      referenceId: ref,
      rrn: rrn,
      authCode: auth,
      cardBrand: brand,
      last4: last4,
      phone: phone,
      status: 'SUCCESS',
      message: 'Payment simulated successfully in Sandbox mode.',
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 900,
        height: 720,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            // Top Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.developer_board, color: Color(0xFF2563EB), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Virtual Payment Terminal & Sandbox Simulator',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Text(
                              'SANDBOX TEST MODE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Test Dynamic UPI QR, Smart POS Card Machine, and Mobile Money STK Push without real hardware or bank charges.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close, color: Color(0xFF475569)),
                  tooltip: 'Close Simulator',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Amount & Bill Meta Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Bill: $_billNo',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                  const Spacer(),
                  const Text('Simulate Charge: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  SizedBox(
                    width: 130,
                    height: 34,
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2563EB)),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        prefixText: '${CurrencyService.symbol} ',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          setState(() {
                            _amount = parsed;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Navigation Tabs (All 3 Methods)
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF2563EB),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF475569),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_2, size: 18), text: '1. Dynamic UPI QR Pay'),
                  Tab(icon: Icon(Icons.credit_card, size: 18), text: '2. Smart POS Card Terminal'),
                  Tab(icon: Icon(Icons.phone_android, size: 18), text: '3. Mobile Money (M-Pesa)'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main Interactive Simulator Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Active Simulator Interactive Device UI
                  Expanded(
                    flex: 11,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUpiSimulator(),
                        _buildCardPosSimulator(),
                        _buildMpesaSimulator(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right side: Terminal Live Telemetry & Log Console (Clean Light Theme)
                  Expanded(
                    flex: 7,
                    child: _buildTelemetryAndLogs(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // 1. DYNAMIC UPI QR SIMULATOR VIEW (LIGHT THEME)
  // =============================================================
  Widget _buildUpiSimulator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/UPI-Logo-vector.svg/1200px-UPI-Logo-vector.svg.png',
                      height: 20,
                      errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, color: Colors.deepOrange, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text('Dynamic Customer-Facing UPI QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Text('AUTO-GENERATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Visual QR Frame
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _generateUpiQrString(),
                    version: QrVersions.auto,
                    size: 150.0,
                    gapless: true,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scan with any UPI App',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade800),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Google Pay', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      const Text(' • ', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      Text('PhonePe', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
                      const Text(' • ', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      Text('Paytm', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.cyan.shade800)),
                      const Text(' • ', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      Text('BHIM', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payee Details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payee: $_upiPayeeName ($_upiId)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        Text('Amount Due: ${CurrencyService.format(_amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Interactive Simulator Controls
            if (_upiSuccess) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: 6),
                        Text('Payment Received via UPI!', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534), fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('NPCI UTR: $_upiUtr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => _completeAndReturn(
                        'UPI',
                        ref: _upiUtr!,
                        rrn: _upiUtr,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Apply to POS Bill & Settle', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _upiScanning ? null : _simulateUpiSuccess,
                    icon: _upiScanning
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.flash_on, size: 18),
                    label: Text(_upiScanning ? 'Scanning...' : '⚡ Simulate Customer Scan & Pay', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _simulateUpiDecline,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Simulate Decline'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =============================================================
  // 2. SMART POS CARD MACHINE SIMULATOR (CLEAN LIGHT THEME)
  // =============================================================
  Widget _buildCardPosSimulator() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Provider selector
            Row(
              children: [
                const Icon(Icons.point_of_sale, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(_posProvider, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                const Spacer(),
                DropdownButton<String>(
                  value: _cardBrand,
                  isDense: true,
                  items: ['VISA', 'MASTERCARD', 'RUPAY', 'AMEX']
                      .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _cardBrand = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Virtual POS Terminal Hardware (Light Platinum/Silver Bezel)
            Container(
              width: 320,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  // Terminal LCD Screen (Clean Light Emerald Canvas)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_posProvider.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Color(0xFF065F46), fontWeight: FontWeight.w800)),
                            const Icon(Icons.wifi, size: 13, color: Color(0xFF059669)),
                          ],
                        ),
                        const Divider(color: Color(0xFFA7F3D0), height: 8),
                        const Text(
                          'SALE AMOUNT',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF047857), letterSpacing: 1, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          CurrencyService.format(_amount),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: Color(0xFF064E3B), fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCardStatusText(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: _cardState == 'APPROVED' ? const Color(0xFF15803D) : (_cardState == 'DECLINED' ? const Color(0xFFDC2626) : const Color(0xFFB45309)),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_cardState == 'PIN_REQUIRED') ...[
                          const SizedBox(height: 4),
                          Text(
                            'PIN: ${_enteredPin.isEmpty ? "----" : ("• " * _enteredPin.length).trim()}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Color(0xFF064E3B), letterSpacing: 2, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Contactless Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.contactless, size: 22, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text('NFC TAP & CHIP READER', style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Virtual POS Keypad (Clean Light Buttons)
                  if (_cardState == 'PIN_REQUIRED') ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (int i = 1; i <= 9; i++) _buildKeypadBtn(i.toString()),
                        _buildKeypadBtn('C', color: const Color(0xFFF59E0B), textColor: Colors.white, onTap: () {
                          setState(() => _enteredPin = '');
                        }),
                        _buildKeypadBtn('0'),
                        _buildKeypadBtn('OK', color: const Color(0xFF16A34A), textColor: Colors.white, onTap: () {
                          if (_enteredPin.length >= 4) {
                            _processCardAuthorization();
                          }
                        }),
                      ],
                    ),
                  ] else ...[
                    // Standard action buttons on machine
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => _simulateCardInsertOrTap(isTap: true),
                            icon: const Icon(Icons.contactless, size: 16),
                            label: const Text('Tap Card (NFC)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF475569),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => _simulateCardInsertOrTap(isTap: false),
                            icon: const Icon(Icons.credit_card, size: 16),
                            label: const Text('Insert Chip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card Approved Success or Decline Result Bar
            if (_cardState == 'APPROVED') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    Text('Auth Code: $_posAuthCode | RRN: $_posRrn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534))),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => _completeAndReturn(
                        'CARD',
                        ref: _posRrn!,
                        rrn: _posRrn,
                        auth: _posAuthCode,
                        brand: _cardBrand,
                        last4: _cardLast4,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Apply Card Charge & Settle', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: _simulateCardDecline,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Simulate Card Decline', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadBtn(String text, {Color? color, Color? textColor, VoidCallback? onTap}) {
    return SizedBox(
      width: 44,
      height: 34,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white,
          foregroundColor: textColor ?? const Color(0xFF1E293B),
          elevation: 1,
          padding: EdgeInsets.zero,
          side: color == null ? const BorderSide(color: Color(0xFFCBD5E1)) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onTap ??
            () {
              if (_enteredPin.length < 4) {
                setState(() {
                  _enteredPin += text;
                  if (_enteredPin.length == 4) {
                    _processCardAuthorization();
                  }
                });
              }
            },
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getCardStatusText() {
    switch (_cardState) {
      case 'READY':
        return 'READY: PLEASE TAP / INSERT';
      case 'INSERTING':
        return 'READING CARD...';
      case 'PIN_REQUIRED':
        return 'ENTER 4-DIGIT PIN';
      case 'PROCESSING':
        return 'AUTHORIZING WITH BANK...';
      case 'APPROVED':
        return '00 - APPROVED';
      case 'DECLINED':
        return '05 - DECLINED';
      default:
        return 'IDLE';
    }
  }

  // =============================================================
  // 3. AFRICA M-PESA STK PUSH SIMULATOR VIEW (LIGHT THEME)
  // =============================================================
  Widget _buildMpesaSimulator() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF00A859), borderRadius: BorderRadius.circular(4)),
                  child: const Text('M-PESA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                ),
                const SizedBox(width: 8),
                const Text('Safaricom Daraja STK Push Simulator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 10),

            // Virtual Customer Smartphone Mockup (Light Silver Bezel - No Black Screen!)
            Container(
              width: 310,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 2.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  // Phone Status Bar (Dark Readable Text on Light Header)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('09:41', style: TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text('Safaricom 4G', style: TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.signal_cellular_alt, size: 12, color: Color(0xFF334155)),
                          SizedBox(width: 4),
                          Icon(Icons.battery_full, size: 12, color: Color(0xFF334155)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Active SIM Toolkit Modal on Phone (Pure White Card on Light Bezel)
                  if (_mpesaState == 'PHONE_PROMPT' || _mpesaState == 'PROCESSING' || _mpesaState == 'APPROVED') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(color: Color(0xFF00A859), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              const Text('SAFARICOM M-PESA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF00A859))),
                            ],
                          ),
                          const Divider(height: 12, color: Color(0xFFE2E8F0)),
                          Text(
                            'Do you want to pay ${CurrencyService.format(_amount)} to $_upiPayeeName (Till 7482)?',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 8),
                          const Text('Enter M-Pesa PIN:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _mpesaEnteredPin.isEmpty ? '••••' : ('• ' * _mpesaEnteredPin.length).trim(),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF0F172A)),
                                ),
                                if (_mpesaState == 'PROCESSING')
                                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A859))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_mpesaState == 'APPROVED') ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF86EFAC))),
                              child: Text('Receipt: $_mpesaReceipt Confirmed!', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF475569),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onPressed: _simulateMpesaCancel,
                                    child: const Text('Cancel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00A859),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onPressed: _simulateMpesaConfirmPin,
                                    child: const Text('Send PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Idle Phone Screen with Trigger Button
                    Container(
                      height: 130,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app, size: 30, color: Color(0xFF00A859)),
                          const SizedBox(height: 6),
                          Text('Ready to Receive Push on $_mpesaPhone', style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Controls
            if (_mpesaState == 'APPROVED') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () => _completeAndReturn(
                  'MPESA',
                  ref: _mpesaReceipt!,
                  phone: _mpesaPhone,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Apply M-Pesa Receipt & Settle Bill', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _mpesaState == 'PUSHING' ? null : _simulateMpesaPush,
                icon: _mpesaState == 'PUSHING'
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_to_mobile, size: 18),
                label: Text(_mpesaState == 'PUSHING' ? 'Pushing Prompt...' : '📱 Initiate M-Pesa STK Push', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =============================================================
  // 4. TELEMETRY & REAL-TIME LOGS CONSOLE (CLEAN LIGHT THEME)
  // =============================================================
  Widget _buildTelemetryAndLogs() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Live Machine Telemetry & Logs',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _logs.clear();
                    _log('Console cleared.');
                  });
                },
                icon: const Icon(Icons.delete_sweep, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Clear Logs',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                Color logColor = const Color(0xFF334155);
                if (log.contains('✅') || log.contains('Confirmed') || log.contains('APPROVED')) {
                  logColor = const Color(0xFF15803D);
                } else if (log.contains('❌') || log.contains('DECLINED') || log.contains('Cancelled')) {
                  logColor = const Color(0xFFDC2626);
                } else if (log.contains('⚡') || log.contains('📱') || log.contains('💳')) {
                  logColor = const Color(0xFF2563EB);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: logColor,
                      fontWeight: log.contains('✅') || log.contains('❌') ? FontWeight.bold : FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
