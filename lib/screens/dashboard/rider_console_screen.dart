import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/token_storage.dart';
import '../../controllers/dashboard/dashboard_controller.dart' as UserProfiledata;
import '../../models/security/app_user_model.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/notification_services.dart';

class RiderConsoleScreen extends StatefulWidget {
  const RiderConsoleScreen({super.key});

  @override
  State<RiderConsoleScreen> createState() => _RiderConsoleScreenState();
}

class _RiderConsoleScreenState extends State<RiderConsoleScreen> {
  UserProfile? _currentUser;
  bool _isLoading = false;

  // --- Rider Tab State ---
  int? _selectedRiderId;
  List<dynamic> _assignedOrders = [];
  List<dynamic> _riderHistoryOrders = [];
  List<dynamic> _retailerRiders = [];
  int _riderSubTabIndex = 0; // 0 for Tasks, 1 for History, 2 for Profile/Status

  // Authentication & Session State
  Map<String, dynamic>? _loggedInRider;
  bool _showRegisterForm = false;
  String _billFormat = 'A4'; // loaded from system settings

  Timer? _notificationTimer;
  final Set<int> _shownNotificationIds = {};

  final TextEditingController _loginPhoneCtrl = TextEditingController();
  final TextEditingController _loginPasswordCtrl = TextEditingController();

  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _loginPhoneCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    setState(() => _isLoading = true);
    _currentUser = await UserProfiledata.load();
    setState(() => _isLoading = false);
    // Load system settings to get bill_format (only if we have an admin/user token)
    final token = await TokenStorage.read();
    if (token != null) {
      try {
        final sysRes = await ApiClient.get('/api/inventory/settings');
        if (sysRes['data'] != null) {
          setState(() {
            _billFormat = sysRes['data']['bill_format']?.toString() ?? 'A4';
          });
        }
      } catch (e) {
        debugPrint('Error loading system settings: $e');
      }
    }
    await _loadRiderSession();
  }

  Future<void> _loadRiderSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final riderJson = prefs.getString('delivery_logged_in_rider');
      if (riderJson != null) {
        setState(() {
          _loggedInRider = jsonDecode(riderJson);
          _selectedRiderId = _loggedInRider!['id'];
        });
        await _fetchRiderTasks();
        _startRiderNotificationTimer();
      }
    } catch (e) {
      debugPrint('Error loading rider session: $e');
    }
  }

  void _startRiderNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) return;
      final riderId = _loggedInRider?['id'];
      if (riderId == null) return;
      try {
        final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
        final res = await ApiClient.get('/api/delivery/rider/notifications?rider_id=$riderId&outlet_id=$outletCode');
        final data = (res['data'] as List? ?? []);
        for (final n in data) {
          final id = n['id'] as int? ?? 0;
          if (id > 0 && n['is_read'] == false && !_shownNotificationIds.contains(id)) {
            _shownNotificationIds.add(id);
            NotificationService.show(id, n['title']?.toString() ?? 'Notification', n['message']?.toString() ?? '');
          }
        }
      } catch (_) {}
    });
  }

  void _logoutRider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('delivery_logged_in_rider');
    } catch (e) {
      debugPrint('Error removing rider data on logout: $e');
    }
    setState(() {
      _loggedInRider = null;
      _selectedRiderId = null;
      _assignedOrders.clear();
      _riderHistoryOrders.clear();
      _loginPhoneCtrl.clear();
      _loginPasswordCtrl.clear();
      _regNameCtrl.clear();
      _regPhoneCtrl.clear();
      _regPasswordCtrl.clear();
    });
  }

  Future<void> _loginRider() async {
    if (_loginPhoneCtrl.text.isEmpty || _loginPasswordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Phone and Password.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'outlet_id': outletCode,
        'phone': _loginPhoneCtrl.text.trim(),
        'password': _loginPasswordCtrl.text.trim(),
      };
      final res = await ApiClient.post('/api/delivery/rider/login', body);
      if (res['success'] == true) {
        final riderData = res['data'];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('delivery_logged_in_rider', jsonEncode(riderData));
        } catch (e) {
          debugPrint('Error saving logged-in rider data: $e');
        }
        setState(() {
          _loggedInRider = riderData;
          _selectedRiderId = _loggedInRider!['id'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in successfully! Welcome, ${_loggedInRider!["name"]}')),
        );
        await _fetchRiderTasks();
        _startRiderNotificationTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Login failed.')),
        );
      }
    } catch (e) {
      debugPrint('Error logging in rider: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerRider() async {
    if (_regNameCtrl.text.isEmpty ||
        _regPhoneCtrl.text.isEmpty ||
        _regPasswordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Name, Phone, and Password.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'outlet_id': outletCode,
        'name': _regNameCtrl.text.trim(),
        'phone': _regPhoneCtrl.text.trim(),
        'password': _regPasswordCtrl.text.trim(),
      };
      final res = await ApiClient.post('/api/delivery/rider/register', body);
      if (res['success'] == true) {
        final riderData = res['data'];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('delivery_logged_in_rider', jsonEncode(riderData));
        } catch (e) {
          debugPrint('Error saving registered rider data: $e');
        }
        setState(() {
          _loggedInRider = riderData;
          _selectedRiderId = _loggedInRider!['id'];
          _showRegisterForm = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registered successfully! Welcome, ${_loggedInRider!['name']}')),
        );
        await _fetchRiderTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Registration failed.')),
        );
      }
    } catch (e) {
      debugPrint('Error registering rider: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fetch all riders (for rider profile dropdown)
  Future<void> _fetchRiders() async {
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.get('/api/delivery/retailer/riders?outlet_id=$outletCode');
      if (res['success'] == true) {
        setState(() {
          _retailerRiders = res['data'] ?? [];
          if (_retailerRiders.isNotEmpty && _selectedRiderId == null) {
            _selectedRiderId = _retailerRiders.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching riders list: $e');
    }
  }

  // Fetch tasks assigned to the selected rider
  Future<void> _fetchRiderTasks() async {
    if (_selectedRiderId == null) return;
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.get('/api/delivery/retailer/orders?outlet_id=$outletCode');
      if (res['success'] == true) {
        final allOrders = res['data'] as List;
        setState(() {
          _assignedOrders = allOrders.where((order) {
            final partnerId = order['assigned_partner_id']?.toString();
            final selectedId = _selectedRiderId?.toString();
            return partnerId != null && partnerId == selectedId &&
                (order['status'] == 'ASSIGNED' || order['status'] == 'OUT_FOR_DELIVERY');
          }).toList();
          _riderHistoryOrders = allOrders.where((order) {
            final partnerId = order['assigned_partner_id']?.toString();
            final selectedId = _selectedRiderId?.toString();
            return partnerId != null && partnerId == selectedId &&
                order['status'] == 'DELIVERED';
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching rider tasks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update order delivery status (rider)
  Future<void> _updateDeliveryStatus(int orderId, String status, {String? paymentMode}) async {
    setState(() => _isLoading = true);
    try {
      final body = {
        'status': status,
        if (paymentMode != null) 'payment_mode': paymentMode
      };
      final res = await ApiClient.put('/api/delivery/rider/orders/$orderId/status', body);
      if (res['success'] == true) {
        await _fetchRiderTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as ${status == 'OUT_FOR_DELIVERY' ? 'Out for Delivery' : 'Delivered'}.')),
        );
      }
    } catch (e) {
      debugPrint('Error updating delivery status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Handover / Update return status
  Future<void> _handoverReturn(int orderId, {String? status}) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = (status != null ? {'status': status} : <String, dynamic>{})..['outlet_id'] = outletCode;
      final res = await ApiClient.put('/api/delivery/rider/orders/$orderId/handover-return', body);
      if (res['success'] == true) {
        await _fetchRiderTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'RETURN_PICKED_UP_FROM_STORE'
                    ? 'Store pickup confirmed. Out for delivery/collection.'
                    : status == 'RETURN_COLLECTED'
                        ? 'Doorstep handover completed successfully.'
                        : 'Return items handed over to store.'
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating return: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Native PDF Printing
  SaleOrder _mapRecordToSaleOrder(dynamic record) {
    double parseNum(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0.0;

    final rawItems = record['received_items'] as List? ?? record['items'] as List? ?? [];
    List<SaleItem> saleItems = [];
    double calculatedSubTotal = 0.0;
    double calculatedTotalQty = 0.0;
    
    for (var it in rawItems) {
      final qty = parseNum(it['qty'] ?? 1.0);
      final rate = parseNum(it['rate'] ?? 0.0);
      final lineTaxPercent = parseNum(it['tax_percent'] ?? 0.0);
      
      final total = qty * rate;
      final taxAmt = parseNum(it['tax_amount'] ?? (total * lineTaxPercent / 100.0));
      final taxableAmt = parseNum(it['taxable_amount'] ?? (total - taxAmt));
      final lineTotal = parseNum(it['line_total'] ?? total);

      calculatedSubTotal += total;
      calculatedTotalQty += qty;

      saleItems.add(SaleItem(
        itemId: int.tryParse(it['item_id']?.toString() ?? '') ?? 0,
        itemCode: it['item_code']?.toString() ?? '',
        itemName: it['item_name']?.toString() ?? '',
        barcode: it['barcode']?.toString() ?? '',
        unit: it['unit']?.toString() ?? 'Pcs',
        qty: qty,
        rate: rate,
        taxPercent: lineTaxPercent,
        taxAmount: taxAmt,
        taxableAmount: taxableAmt,
        lineTotal: lineTotal,
      ));
    }

    List<BillingCharge> billingCharges = [];
    final rawCharges = record['charges'] as List?;
    if (rawCharges != null) {
      for (var ch in rawCharges) {
        billingCharges.add(BillingCharge.fromJson(Map<String, dynamic>.from(ch)));
      }
    }
    
    final delivery = parseNum(record['delivery_charge'] ?? record['charge_total'] ?? 0.0);
    final hasDeliveryCharge = billingCharges.any((c) => c.code == 'DELIVERY' || c.name.toUpperCase() == 'DELIVERY');
    if (delivery > 0 && !hasDeliveryCharge) {
      billingCharges.add(BillingCharge(
        name: 'DELIVERY',
        code: 'DELIVERY',
        amount: delivery,
        taxable: false,
        autoApply: false,
        isEnabled: true,
        taxType: 'GST',
        taxPercent: 0.0,
      ));
    }

    final netAmt = parseNum(record['net_amount'] ?? 0.0);
    final taxAmt = parseNum(record['tax_amount'] ?? record['total_tax'] ?? 0.0);

    final String saleNo = record['sale_no']?.toString() ?? record['bill_no']?.toString() ?? record['id']?.toString() ?? '';
    final bool hasBillNo = (record['sale_no']?.toString() ?? record['bill_no']?.toString() ?? '').trim().isNotEmpty;

    final int? orderId = record['id'] == null ? null : int.tryParse(record['id'].toString());

    return SaleOrder(
      saleNo: saleNo,
      hasBillNo: hasBillNo,
      orderId: orderId,
      saleDate: DateTime.tryParse(record['sale_date']?.toString() ?? record['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: record['status']?.toString() ?? 'COMPLETED',
      orderType: 'B2C',
      billingCountry: 'India',
      billingTaxMode: 'CGST_SGST',
      billFormat: _billFormat,
      customerName: record['customer_name']?.toString(),
      customerPhone: record['customer_phone']?.toString(),
      customerAddress: record['customer_address']?.toString(),
      customerGstin: record['gstin']?.toString() ?? record['customer_gstin']?.toString(),
      paymentMode: record['payment_mode']?.toString() ?? 'CASH',
      amountPaid: record['payment_status'] == 'PAID' ? netAmt : 0.0,
      changeAmount: 0.0,
      balanceDue: record['payment_status'] == 'PAID' ? 0.0 : netAmt,
      subTotal: parseNum(record['sub_total'] ?? calculatedSubTotal),
      totalQty: calculatedTotalQty,
      taxPercent: 0.0,
      schemeDiscount: 0.0,
      manualDiscountValue: 0.0,
      manualDiscountAmount: 0.0,
      taxableAmount: parseNum(record['sub_total'] ?? calculatedSubTotal) - taxAmt,
      cgstAmount: taxAmt / 2,
      sgstAmount: taxAmt / 2,
      igstAmount: 0.0,
      totalTax: taxAmt,
      taxBreakup: [],
      charges: billingCharges,
      chargeTotal: delivery,
      chargeTaxTotal: 0.0,
      totalDiscount: 0.0,
      roundOffAmount: 0.0,
      netAmount: netAmt,
      items: saleItems,
    );
  }

  Future<void> _printReceiptNative(dynamic record, bool isOnlineOrder) async {
    setState(() => _isLoading = true);
    try {
      final propertyCtrl = PropertyInfoController();
      await propertyCtrl.load();

      final order = _mapRecordToSaleOrder(record);

      await PosInvoicePrinter.printSaleInvoice(
        order: order,
        property: propertyCtrl.data,
        cashierName: 'System',
        termsAndConditions: 'Goods once sold will not be taken back. Subject to local jurisdiction.',
        thankYouMessage: 'Thank you for shopping with us. Please visit again.',
        authorizedSignatureLabel: 'Authorized Signature',
      );
    } catch (e) {
      debugPrint('Error printing receipt: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Confirm payment mode for delivery order (Rider)
  void _showDeliveryPaymentModeDialog(int orderId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delivery Payment'),
          content: const Text('How did the customer pay for this delivery?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateDeliveryStatus(orderId, 'DELIVERED', paymentMode: 'CARD');
              },
              child: const Text('Paid via Card'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateDeliveryStatus(orderId, 'DELIVERED', paymentMode: 'UPI');
              },
              child: const Text('Paid via UPI'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _updateDeliveryStatus(orderId, 'DELIVERED', paymentMode: 'CASH');
              },
              child: const Text('Paid Cash'),
            ),
          ],
        );
      },
    );
  }

  // Update rider status (Available/Offline)
  Future<void> _updateRiderStatus(int riderId, String status) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.put('/api/delivery/rider/status', {
        'id': riderId,
        'status': status
      });
      if (res['success'] == true) {
        if (_loggedInRider != null) {
          setState(() {
            _loggedInRider!['status'] = status;
          });
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('delivery_logged_in_rider', jsonEncode(_loggedInRider));
          } catch (e) {
            debugPrint('Error saving updated status in session: $e');
          }
        }
        await _fetchRiders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rider status updated to $status.')),
        );
      }
    } catch (e) {
      debugPrint('Error updating rider status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildRiderPerformanceMetrics(ThemeData theme) {
    int totalDelivered = _riderHistoryOrders.length;
    double totalOrderValue = 0.0;
    double totalCashCollected = 0.0;
    double totalCommissionPaid = 0.0;
    double totalCommissionUnpaid = 0.0;

    for (var order in _riderHistoryOrders) {
      final netAmt = double.tryParse(order['net_amount']?.toString() ?? '0') ?? 0.0;
      totalOrderValue += netAmt;

      final payMode = order['payment_mode'] ?? 'CASH';
      if (payMode == 'CASH') {
        totalCashCollected += netAmt;
      }

      final commAmt = double.tryParse(order['commission_amount']?.toString() ?? '20') ?? 20.0;
      final commStatus = order['commission_status'] ?? 'UNPAID';
      if (commStatus == 'PAID') {
        totalCommissionPaid += commAmt;
      } else {
        totalCommissionUnpaid += commAmt;
      }
    }

    return Card(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rider Earnings & Stats', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - 24) / (constraints.maxWidth > 600 ? 5 : 2);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatItem('Delivered', '$totalDelivered orders', Colors.teal, itemWidth),
                    _buildStatItem('Order Value', 'Rs. ${totalOrderValue.toStringAsFixed(2)}', Colors.blue, itemWidth),
                    _buildStatItem('Cash Collected', 'Rs. ${totalCashCollected.toStringAsFixed(2)}', Colors.indigo, itemWidth),
                    _buildStatItem('Comm. Unpaid', 'Rs. ${totalCommissionUnpaid.toStringAsFixed(2)}', Colors.red, itemWidth),
                    _buildStatItem('Comm. Paid', 'Rs. ${totalCommissionPaid.toStringAsFixed(2)}', Colors.green, itemWidth),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(dynamic order, ThemeData theme) {
    final returnStatus = order['return_status'];
    final isReturn = returnStatus != null &&
        returnStatus != 'RETURNED' &&
        returnStatus != 'EXCHANGED' &&
        returnStatus != 'REJECTED';
    final itemsList = isReturn
        ? (order['returned_items'] as List? ?? order['items'] as List? ?? [])
        : (order['received_items'] as List? ?? order['items'] as List? ?? []);
    final netAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
    final isPrepaid = order['is_prepaid'] == true || order['is_prepaid'] == 1;
    final isCredit = order['payment_mode'] == 'CREDIT';
    final isCod = !isPrepaid && !isCredit;
    final status = order['status'];
    final saleNo = order['sale_no'] ?? '--';

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bill No: $saleNo',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isReturn
                            ? Colors.orange
                            : (status == 'ASSIGNED' ? Colors.orange : Colors.teal))
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isReturn
                        ? (returnStatus == 'RETURN_ACCEPTED'
                            ? 'RETURN APPROVED'
                            : (returnStatus == 'RETURN_PICKED_UP_FROM_STORE'
                                ? 'RETURN IN TRANSIT'
                                : (returnStatus == 'RETURN_COLLECTED'
                                    ? 'COLLECTED'
                                    : 'HANDED OVER')))
                        : (status ?? 'ASSIGNED'),
                    style: TextStyle(
                      color: isReturn
                          ? Colors.orange.shade900
                          : (status == 'ASSIGNED' ? Colors.orange.shade900 : Colors.teal.shade900),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('Customer: ${order['customer_name']}', style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone_android_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('Phone: ${order['customer_phone']}', style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Address: ${order['customer_address']}',
                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isReturn
                        ? Colors.orange
                        : (isCod ? Colors.red : Colors.green))
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (isReturn
                            ? Colors.orange
                            : (isCod ? Colors.red : Colors.green))
                        .withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isReturn
                        ? Icons.assignment_return_outlined
                        : (isCod ? Icons.money_off_outlined : Icons.monetization_on_outlined),
                    color: isReturn
                        ? Colors.orange.shade900
                        : (isCod ? Colors.red.shade900 : Colors.green.shade900),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isReturn
                          ? (returnStatus == 'RETURN_ACCEPTED'
                              ? (order['return_type'] == 'EXCHANGE'
                                  ? 'STEP 1: Pick up the new replacement item from the store.'
                                  : 'STEP 1: Go to the customer to collect the returned item.')
                              : (returnStatus == 'RETURN_PICKED_UP_FROM_STORE'
                                  ? (order['return_type'] == 'EXCHANGE'
                                      ? 'STEP 2: Hand over replacement item at customer door in exchange for old item.'
                                      : 'STEP 2: Collect the returned item from the customer doorstep.')
                                  : (returnStatus == 'RETURN_COLLECTED'
                                      ? 'STEP 3: Return to store and hand over the old item to supplier.'
                                      : 'STEP 4: Handed over. Awaiting final supplier confirmation.')))
                          : isCredit
                              ? 'Collect Amount: Rs. 0.00 (CREDIT - DO NOT COLLECT)'
                              : 'Collect Amount: Rs. ${netAmt.toStringAsFixed(2)} (${isCod ? "CASH ON DELIVERY" : "PREPAID - DO NOT COLLECT"})',
                      style: TextStyle(
                        color: isReturn
                            ? Colors.orange.shade900
                            : isCredit
                                ? Colors.purple.shade900
                                : (isCod ? Colors.red.shade900 : Colors.green.shade900),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order['modification_reason'] != null && order['modification_reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Correction Reason: ${order['modification_reason']}',
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (order['original_net_amount'] != null) ...[
                      const SizedBox(height: 4),
                      (() {
                        final origAmt = double.tryParse(order['original_net_amount'].toString()) ?? 0.0;
                        final diff = netAmt - origAmt;
                        if (diff.abs() > 0.01) {
                          final isRefund = diff < 0;
                          
                          String detailText = '';
                          if (isCod) {
                            if (isRefund) {
                              detailText = 'Original Total: Rs. ${origAmt.toStringAsFixed(2)} (Amount reduced by Rs. ${diff.abs().toStringAsFixed(2)})';
                            } else {
                              detailText = 'Original Total: Rs. ${origAmt.toStringAsFixed(2)} (Rs. ${diff.abs().toStringAsFixed(2)} Extra charged)';
                            }
                          } else {
                            // Prepaid order
                            if (isRefund) {
                              final isRefunded = order['refund_status']?.toString() == 'REFUNDED';
                              detailText = 'Original Total: Rs. ${origAmt.toStringAsFixed(2)} (Rs. ${diff.abs().toStringAsFixed(2)} ${isRefunded ? "Refunded" : "Refund pending"})';
                            } else {
                              detailText = 'Original Total: Rs. ${origAmt.toStringAsFixed(2)} (Rs. ${diff.abs().toStringAsFixed(2)} Extra charged)';
                            }
                          }

                          return Text(
                            detailText,
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          );
                        }
                        return const SizedBox.shrink();
                      })(),
                    ],
                  ],
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  isReturn ? 'RETURN ITEMS LIST' : 'ITEMS LIST',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...itemsList.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '•  ${item['item_name']} x ${item['qty']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _printReceiptNative(order, true),
                  icon: const Icon(Icons.print_outlined),
                  tooltip: 'Print Invoice',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isReturn) ...[
                      if (returnStatus == 'RETURN_ACCEPTED') ...[
                        FilledButton.icon(
                          onPressed: () => _handoverReturn(order['id'], status: 'RETURN_PICKED_UP_FROM_STORE'),
                          icon: const Icon(Icons.storefront_outlined),
                          label: Text(order['return_type'] == 'EXCHANGE'
                              ? 'Confirm Pickup from Store'
                              : 'Confirm Out for Collection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      ] else if (returnStatus == 'RETURN_PICKED_UP_FROM_STORE') ...[
                        FilledButton.icon(
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Doorstep Handover'),
                                content: Text(order['return_type'] == 'EXCHANGE'
                                    ? 'Is the customer\'s returned item in good condition? Hand over the new replacement item only if the old one is returned in acceptable condition.'
                                    : 'Confirm collection of the returned item.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Confirm Complete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              _handoverReturn(order['id'], status: 'RETURN_COLLECTED');
                            }
                          },
                          icon: const Icon(Icons.front_hand_outlined),
                          label: Text(order['return_type'] == 'EXCHANGE'
                              ? 'Confirm Doorstep Exchange'
                              : 'Confirm Doorstep Collection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      ] else if (returnStatus == 'RETURN_COLLECTED') ...[
                        FilledButton.icon(
                          onPressed: () => _handoverReturn(order['id'], status: 'RETURN_HANDED_OVER'),
                          icon: const Icon(Icons.handshake_outlined),
                          label: const Text('Confirm Handover to Store'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            'Awaiting Supplier Final Settle',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        )
                      ]
                    ] else ...[
                      if (status == 'ASSIGNED') ...[
                        FilledButton.icon(
                          onPressed: () => _updateDeliveryStatus(order['id'], 'OUT_FOR_DELIVERY'),
                          icon: const Icon(Icons.directions_bike),
                          label: const Text('Confirm Pickup (On the way)'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      ] else if (status == 'OUT_FOR_DELIVERY') ...[
                        FilledButton.icon(
                          onPressed: () {
                            final isCredit = order['payment_mode'] == 'CREDIT';
                            if (isCod && !isCredit) {
                              _showDeliveryPaymentModeDialog(order['id']);
                            } else {
                              _updateDeliveryStatus(order['id'], 'DELIVERED');
                            }
                          },
                          icon: const Icon(Icons.done_all),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          label: Text(isCredit
                              ? 'Confirm Delivery (CREDIT)'
                              : (isCod ? 'Collect Payment & Mark Delivered' : 'Confirm Delivery')),
                        )
                      ]
                    ]
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOrderCard(dynamic order, ThemeData theme) {
    final netAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
    final isCredit = order['payment_mode'] == 'CREDIT';
    final isCod = order['payment_mode'] == 'CASH';
    final commAmt = double.tryParse(order['commission_amount']?.toString() ?? '20') ?? 20.0;
    final commStatus = order['commission_status'] ?? 'UNPAID';
    final dateStr = order['delivered_at'] != null 
        ? DateFormat('dd-MMM-yyyy, hh:mm a').format(DateTime.parse(order['delivered_at'].toString()))
        : '--';

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade50,
              radius: 20,
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order['id']} • Rs. ${netAmt.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Delivered: $dateStr',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    'Payment: ${isCredit ? "Credit Payment (Not Collected)" : (isCod ? "CoD (Cash Collected)" : "Prepaid (Online)")}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Comm: Rs. ${commAmt.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: commStatus == 'PAID' ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: commStatus == 'PAID' ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: Text(
                    commStatus,
                    style: TextStyle(
                      color: commStatus == 'PAID' ? Colors.green.shade800 : Colors.red.shade800,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildAssignedTasksView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Assigned Deliveries',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _assignedOrders.isEmpty
                ? const Center(child: Text('No active deliveries assigned to you.', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _fetchRiderTasks,
                    child: ListView.builder(
                      itemCount: _assignedOrders.length,
                      itemBuilder: (context, index) => _buildActiveOrderCard(_assignedOrders[index], theme),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedHistoryView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed Delivery History',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade900),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _riderHistoryOrders.isEmpty
                ? const Center(child: Text('No completed deliveries yet.', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _fetchRiderTasks,
                    child: ListView.builder(
                      itemCount: _riderHistoryOrders.length,
                      itemBuilder: (context, index) => _buildHistoryOrderCard(_riderHistoryOrders[index], theme),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderProfileView(ThemeData theme) {
    if (_loggedInRider == null) {
      return const Center(child: Text('Please log in first.'));
    }

    final String status = _loggedInRider!['status'] ?? 'AVAILABLE';
    final bool isOffline = status == 'OFFLINE';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Delivery Partner Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _logoutRider,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${_loggedInRider!['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Phone: ${_loggedInRider!['phone']}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOffline ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isOffline ? Colors.red.shade300 : Colors.green.shade300),
                        ),
                        child: Text(
                          isOffline ? 'OFFLINE' : 'ONLINE (AVAILABLE)',
                          style: TextStyle(
                            color: isOffline ? Colors.red.shade800 : Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final newStatus = isOffline ? 'AVAILABLE' : 'OFFLINE';
                        _updateRiderStatus(_selectedRiderId!, newStatus);
                      },
                      icon: const Icon(Icons.power_settings_new),
                      label: Text(isOffline ? 'Go Online (Available)' : 'Go Offline'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _buildRiderPerformanceMetrics(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Rider Portal',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Manage and track deliveries',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Assigned Tasks'),
            selected: _riderSubTabIndex == 0,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _riderSubTabIndex = 0;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Completed History'),
            selected: _riderSubTabIndex == 1,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _riderSubTabIndex = 1;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Rider Profile & Status'),
            selected: _riderSubTabIndex == 2,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _riderSubTabIndex = 2;
              });
            },
          ),
          Visibility(
            visible: !Platform.isAndroid && !Platform.isIOS,
            child: const Divider(),
          ),
          Visibility(
            visible: !Platform.isAndroid && !Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Exit to Dashboard'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderAuthView(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 6,
            shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.directions_bike,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showRegisterForm ? 'Join Wholesale Delivery Network' : 'Delivery Partner Login',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showRegisterForm
                        ? 'Register as a B2B delivery partner to handle Wholesaler-to-Retailer shipments.'
                        : 'Sign in to access your assigned bulk shipments and log earnings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_showRegisterForm) ...[
                    TextField(
                      controller: _regNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _regPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _regPasswordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _loginPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Registered Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _loginPasswordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _showRegisterForm ? _registerRider : _loginRider,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _showRegisterForm ? 'Register Partner' : 'Sign In',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showRegisterForm = !_showRegisterForm;
                      });
                    },
                    child: Text(
                      _showRegisterForm
                          ? 'Already a partner? Sign In'
                          : 'Interested in delivering? Register Here',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Delivery Portal'),
      ),
      drawer: _loggedInRider != null ? _buildDeliveryDrawer(context) : null,
      body: _isLoading && _assignedOrders.isEmpty && _riderHistoryOrders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : (_loggedInRider == null
              ? _buildRiderAuthView(theme)
              : IndexedStack(
                  index: _riderSubTabIndex,
                  children: [
                    _buildAssignedTasksView(theme),
                    _buildCompletedHistoryView(theme),
                    _buildRiderProfileView(theme),
                  ],
                )),
      bottomNavigationBar: _loggedInRider != null
          ? BottomNavigationBar(
              currentIndex: _riderSubTabIndex,
              onTap: (index) {
                setState(() {
                  _riderSubTabIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Badge(
                    label: Text(_assignedOrders.length.toString()),
                    isLabelVisible: _assignedOrders.isNotEmpty,
                    child: const Icon(Icons.directions_bike),
                  ),
                  label: 'Deliveries',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    label: Text(_riderHistoryOrders.length.toString()),
                    isLabelVisible: _riderHistoryOrders.isNotEmpty,
                    child: const Icon(Icons.history),
                  ),
                  label: 'Completed',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile & Earnings',
                ),
              ],
            )
          : null,
    );
  }
}
