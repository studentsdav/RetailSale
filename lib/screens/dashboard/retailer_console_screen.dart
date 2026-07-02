import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../controllers/dashboard/dashboard_controller.dart' as UserProfiledata;
import '../../models/security/app_user_model.dart';
import '../inventory/salescreen.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/notification_services.dart';


class RetailerConsoleScreen extends StatefulWidget {
  const RetailerConsoleScreen({super.key});

  @override
  State<RetailerConsoleScreen> createState() => _RetailerConsoleScreenState();
}

class _RetailerConsoleScreenState extends State<RetailerConsoleScreen> {
  UserProfile? _currentUser;
  bool _isLoading = false;

  // --- Retailer Tab State ---
  List<dynamic> _retailerOrders = [];
  List<dynamic> _retailerRiders = [];
  int _retailerSubTabIndex = 0; // 0: Orders, 1: Returns, 2: Riders, 3: B2B Rates
  String _statusFilter = 'ALL'; // 'ALL', 'PENDING', 'CANCELLED', 'DELIVERED'
  int _ordersSubTab = 0; // 0: Dashboard, 1: Orders List

  // --- B2B Rates State ---
  List<dynamic> _b2bItems = [];
  String _b2bSearchQuery = '';
  bool _b2bLoading = false;

  // --- Rider Registration State ---
  final TextEditingController _riderNameCtrl = TextEditingController();
  final TextEditingController _riderPhoneCtrl = TextEditingController();
  final TextEditingController _riderPasswordCtrl = TextEditingController();
  final TextEditingController _riderConfirmPasswordCtrl = TextEditingController();
  bool _riderPasswordVisible = false;

  // --- Return Settings State ---
  int _defaultReturnWindowDays = 7;
  bool _returnSettingsLoading = false;
  bool _isExchangeAvailable = true;
  bool _isRefundAvailable = true;
  List<dynamic> _customCharges = [];
  List<Map<String, TextEditingController>> _customChargesControllers = [];
  List<dynamic> _coupons = [];
  List<Map<String, TextEditingController>> _couponsControllers = [];
  double _minDeliveryOrderValue = 0.0;
  double _deliveryCharge = 0.0;
  double _deliveryGstPercent = 18.0;
  double _platformFee = 10.0;
  double _platformGstPercent = 18.0;
  double _otherCharges = 0.0;
  double _otherChargesGstPercent = 18.0;
  String _commissionType = 'FLAT';
  double _commissionValue = 20.0;
  String _billFormat = 'A4'; // loaded from system settings

  final TextEditingController _minDeliveryOrderValueCtrl = TextEditingController();
  final TextEditingController _deliveryChargeCtrl = TextEditingController();
  final TextEditingController _deliveryGstPercentCtrl = TextEditingController();
  final TextEditingController _platformFeeCtrl = TextEditingController();
  final TextEditingController _platformGstPercentCtrl = TextEditingController();
  final TextEditingController _otherChargesCtrl = TextEditingController();
  final TextEditingController _otherChargesGstPercentCtrl = TextEditingController();
  final TextEditingController _commissionValueCtrl = TextEditingController();

  // Filters State (Supplier Console Requirements)
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _todayOnly = true;

  Timer? _refreshTimer;
  Timer? _notificationTimer;
  int? _maxOrderIdSeen;
  final Set<int> _shownNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
    _startRefreshTimer();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationTimer?.cancel();
    _riderNameCtrl.dispose();
    _riderPhoneCtrl.dispose();
    _riderPasswordCtrl.dispose();
    _riderConfirmPasswordCtrl.dispose();
    _searchCtrl.dispose();
    _minDeliveryOrderValueCtrl.dispose();
    _deliveryChargeCtrl.dispose();
    _deliveryGstPercentCtrl.dispose();
    _platformFeeCtrl.dispose();
    _platformGstPercentCtrl.dispose();
    _otherChargesCtrl.dispose();
    _otherChargesGstPercentCtrl.dispose();
    _commissionValueCtrl.dispose();
    for (final ctrlMap in _customChargesControllers) {
      ctrlMap['name']?.dispose();
      ctrlMap['charge']?.dispose();
      ctrlMap['gst_percentage']?.dispose();
    }
    for (final ctrlMap in _couponsControllers) {
      ctrlMap['code']?.dispose();
      ctrlMap['discount_value']?.dispose();
      ctrlMap['min_purchase']?.dispose();
      ctrlMap['max_discount']?.dispose();
      ctrlMap['max_uses']?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    setState(() => _isLoading = true);
    _currentUser = await UserProfiledata.load();
    setState(() => _isLoading = false);
    _fetchRetailerData();
    _fetchB2bItems();
    _fetchReturnSettings();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _fetchRetailerData(isBackground: true);
      }
    });
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) return;
      try {
        final res = await ApiClient.get('/api/notifications');
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

  void _showNewOrderNotification(dynamic order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'NEW ORDER RECEIVED!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Order #${order['id']} from ${order['customer_name']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.amber,
          onPressed: () {},
        ),
      ),
    );
  }

  // Fetch retailer dashboard orders & riders with filters
  Future<void> _fetchRetailerData({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }
    try {
      final String fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final String toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final query = 'search=${Uri.encodeComponent(_searchCtrl.text.trim())}&fromDate=$fromDateStr&toDate=$toDateStr&today=$_todayOnly&includePendingReturns=true&outlet_id=$outletCode';
      
      final ordersRes = await ApiClient.get('/api/delivery/retailer/orders?$query');
      final ridersRes = await ApiClient.get('/api/delivery/retailer/riders?outlet_id=$outletCode');
      
      final List<dynamic> newOrders = ordersRes['data'] ?? [];

      if (_maxOrderIdSeen != null) {
        final List<dynamic> freshlyReceived = [];
        for (var order in newOrders) {
          final int oId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
          if (oId > _maxOrderIdSeen!) {
            freshlyReceived.add(order);
          }
        }
        if (freshlyReceived.isNotEmpty) {
          for (var newOrder in freshlyReceived) {
            _showNewOrderNotification(newOrder);
          }
        }
      }

      int currentMax = _maxOrderIdSeen ?? 0;
      for (var order in newOrders) {
        final int oId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
        if (oId > currentMax) {
          currentMax = oId;
        }
      }
      _maxOrderIdSeen = currentMax;

      setState(() {
        _retailerOrders = newOrders;
        _retailerRiders = ridersRes['data'] ?? [];
      });
    } catch (e) {
      debugPrint('Error fetching retailer data: $e');
    } finally {
      if (!isBackground) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchB2bItems() async {
    final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
    if (outletCode.isEmpty) return;
    setState(() => _b2bLoading = true);
    try {
      final query = 'page=1&search=${Uri.encodeComponent(_b2bSearchQuery)}&limit=50&outlet_id=$outletCode';
      final res = await ApiClient.get('/api/delivery/catalog?$query');
      if (res['success'] == true) {
        setState(() {
          _b2bItems = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching B2B items: $e');
    } finally {
      setState(() => _b2bLoading = false);
    }
  }

  Future<void> _updateB2bRate(String itemCode, double rate) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.put(
          '/api/delivery/retailer/items/$itemCode/b2b-rate', {
            'b2b_rate': rate,
            'outlet_id': outletCode,
          });
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('B2B rate updated to Rs. ${rate.toStringAsFixed(2)}')),
        );
        _fetchB2bItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to update B2B rate.')),
        );
      }
    } catch (e) {
      debugPrint('Error updating B2B rate: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showB2bRateDialog(Map<String, dynamic> item) {
    final stdRate = double.tryParse(item['retail_sale_price']?.toString() ?? '') ??
        double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
    final currentB2b = double.tryParse(item['b2b_rate']?.toString() ?? '') ?? 0.0;
    final ctrl = TextEditingController(
        text: currentB2b > 0 ? currentB2b.toStringAsFixed(2) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set B2B Rate – ${item['item_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Standard Rate: Rs. ${stdRate.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'B2B Price (Rs.)',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim()) ?? 0.0;
              Navigator.pop(ctx);
              _updateB2bRate(item['item_code'], val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Register delivery rider
  Future<void> _addRider() async {
    if (_riderNameCtrl.text.isEmpty || _riderPhoneCtrl.text.isEmpty || _riderPasswordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out name, phone number, and password.')),
      );
      return;
    }
    if (_riderPasswordCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 4 characters.')),
      );
      return;
    }
    if (_riderPasswordCtrl.text != _riderConfirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'name': _riderNameCtrl.text.trim(),
        'phone': _riderPhoneCtrl.text.trim(),
        'password': _riderPasswordCtrl.text.trim(),
        'outlet_id': outletCode,
      };
      final res = await ApiClient.post('/api/delivery/retailer/riders', body);
      if (res['success'] == true) {
        _riderNameCtrl.clear();
        _riderPhoneCtrl.clear();
        _riderPasswordCtrl.clear();
        _riderConfirmPasswordCtrl.clear();
        if (mounted) Navigator.pop(context);
        _fetchRetailerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rider registered successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to register rider.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error registering rider: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Cancel customer order
  Future<void> _cancelOrder(dynamic order) async {
    final int orderId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
    final bool isPrepaid = order['payment_status']?.toString() == 'PAID';
    String selectedReason = 'Customer requested cancellation';
    final TextEditingController otherReasonCtrl = TextEditingController();
    bool isOther = false;

    final String? reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Cancel Order Reason'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please select a reason for cancelling this order:', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: const InputDecoration(
                      labelText: 'Select Reason',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Customer requested cancellation',
                      'Out of stock / Item unavailable',
                      'Store closing / Out of business hours',
                      'Delivery rider unavailable',
                      'Incorrect pricing/details',
                      'Other'
                    ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedReason = val!;
                        isOther = val == 'Other';
                      });
                    },
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherReasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Write cancellation reason',
                        hintText: 'Please specify...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () {
                  final String finalReason = isOther ? otherReasonCtrl.text.trim() : selectedReason;
                  if (isOther && finalReason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please write a cancellation reason.')),
                    );
                    return;
                  }
                  Navigator.pop(context, finalReason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel Order'),
              ),
            ],
          );
        }
      ),
    );

    if (reason == null) return;

    // For prepaid orders, ask if refund should be processed now or later
    bool? refundNow;
    if (isPrepaid) {
      final netAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
      refundNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.currency_rupee, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Refund to Customer?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is a prepaid order. The customer paid Rs. ${netAmt.toStringAsFixed(2)} online.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Do you want to refund the customer now?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.schedule, size: 16),
              label: const Text('Later (Keep Pending)'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Yes, Refund Now'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            ),
          ],
        ),
      );
    }

    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = <String, dynamic>{
        'outlet_id': outletCode,
        'reason': reason,
      };
      if (isPrepaid && refundNow != null) {
        body['refund_now'] = refundNow;
      }
      final res = await ApiClient.post('/api/delivery/retailer/orders/$orderId/cancel', body);
      if (res['success'] == true) {
        await _fetchRetailerData();
        final msg = isPrepaid && refundNow == true
            ? 'Order cancelled and refund recorded in ledger.'
            : isPrepaid && refundNow == false
                ? 'Order cancelled. Refund is pending — check the Refund Pending tab.'
                : (res['message'] ?? 'Order cancelled successfully.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel order: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _replyToFeedbackDialog(int orderId) async {
    final TextEditingController replyCtrl = TextEditingController();

    final String? replyText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Customer Feedback'),
        content: TextField(
          controller: replyCtrl,
          decoration: const InputDecoration(
            labelText: 'Write reply (Internal Purpose Only)',
            hintText: 'Type your reply here...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = replyCtrl.text.trim();
              if (val.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please write a reply.')),
                );
                return;
              }
              Navigator.pop(context, val);
            },
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );

    if (replyText == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.post('/api/delivery/retailer/orders/$orderId/feedback/reply', {
        'reply': replyText,
      });
      if (res['success'] == true) {
        await _fetchRetailerData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply submitted successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to submit reply.')),
        );
      }
    } catch (e) {
      debugPrint('Error replying to feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit reply: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatReturnedItems(dynamic order) {
    final returnedItems = order['returned_items'] as List?;
    if (returnedItems != null && returnedItems.isNotEmpty) {
      final List<String> itemsFormatted = [];
      for (var it in returnedItems) {
        final q = double.tryParse(it['qty']?.toString() ?? '1') ?? 1.0;
        itemsFormatted.add('${it['item_name']} x${q.toStringAsFixed(0)}');
      }
      return '[${itemsFormatted.join(", ")}]';
    }
    if (order['return_item_name'] != null && order['return_item_name'].toString().isNotEmpty) {
      return '[${order['return_item_name']}]';
    }
    return '';
  }

  Future<void> _handleReturnRequest(dynamic orderId, String action) async {
    // Find the order to determine return_type for rider picking
    final order = _retailerOrders.firstWhere(
        (o) => o['id'].toString() == orderId.toString(),
        orElse: () => null);
    final returnType = order?['return_type'] ?? '';
    final bool needsRider =
        action == 'ACCEPT' && (returnType == 'EXCHANGE' || returnType == 'REDELIVERY' || returnType == 'REFUND');

    // If EXCHANGE, REDELIVERY or REFUND, pick a rider first
    int? selectedRiderId;
    String? remark;
    if (needsRider && _retailerRiders.isNotEmpty) {
      selectedRiderId = await showDialog<int>(
        context: context,
        builder: (ctx) {
          int? picked;
          return StatefulBuilder(
            builder: (ctx, setSt) => AlertDialog(
              title: Text(returnType == 'REFUND'
                  ? 'Assign Rider for Return Pickup'
                  : 'Assign Delivery Rider'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    returnType == 'EXCHANGE'
                        ? 'Select a rider to deliver the replacement item:'
                        : returnType == 'REFUND'
                            ? 'Select a rider to pickup from customer and handover to supplier:'
                            : 'Select a rider for re-delivery:',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ..._retailerRiders.map((r) => RadioListTile<int>(
                        title: Text(r['name'] ?? ''),
                        subtitle: Text(r['phone'] ?? ''),
                        value: r['id'] as int,
                        groupValue: picked,
                        onChanged: (v) => setSt(() => picked = v),
                      )),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (picked == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please select a rider first.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, picked);
                  },
                  child: Text(returnType == 'REFUND'
                      ? 'Assign & Accept Pickup'
                      : 'Assign & Accept'),
                ),
              ],
            ),
          );
        },
      );
      if (selectedRiderId == null) {
        return; // User cancelled or did not assign a rider, do not save/accept request
      }
    } else if (needsRider && _retailerRiders.isEmpty) {
      // No riders available — show warning and block continuing
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Riders Available'),
          content: const Text(
              'No delivery riders registered. You must add at least one rider first to accept return/refund requests.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Do not proceed, exit
    } else {
      // Prompt for rejection remark when action is REJECT
      if (action == 'REJECT') {
        final TextEditingController remarkCtrl = TextEditingController();
        remark = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reject Return/Refund Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please write the reason for rejecting this return request:', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: remarkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Remark',
                    hintText: 'e.g., Items returned were damaged, or return window has closed...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final val = remarkCtrl.text.trim();
                  if (val.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please specify a rejection reason.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, val);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reject Request'),
              ),
            ],
          ),
        );
        if (remark == null) return; // Exit if user cancelled or did not provide a remark
      } else {
        // Confirm for ACCEPT action when rider is not required
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Accept Return Request'),
            content: Text(returnType == 'REFUND'
                ? 'Accept this refund request? Stock will be restored automatically.'
                : 'Accept this return request?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = <String, dynamic>{
        'action': action,
        'outlet_id': outletCode,
      };
      if (selectedRiderId != null) body['rider_id'] = selectedRiderId;
      if (remark != null) body['remark'] = remark;
      final res = await ApiClient.post(
          '/api/delivery/retailer/orders/$orderId/accept-return', body);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(action == 'ACCEPT'
                    ? (selectedRiderId != null
                        ? 'Accepted & rider assigned for ${returnType == 'EXCHANGE' ? 'replacement delivery' : returnType == 'REFUND' ? 'return pickup' : 're-delivery'}!'
                        : returnType == 'REFUND'
                            ? 'Refund accepted. Stock restored.'
                            : 'Return request accepted.')
                    : 'Return request rejected.')),
          );
        }
        _fetchRetailerData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to update return request.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling return request: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMarkRefundPaid(dynamic orderId, double refundAmount) async {
    final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
    String selectedMethod = 'CASH';
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Mark Refund as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refund Amount: Rs. ${refundAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
              ),
              const SizedBox(height: 16),
              const Text('Refund Method:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['CASH', 'UPI', 'BANK'].map((method) {
                  return ChoiceChip(
                    label: Text(method),
                    selected: selectedMethod == method,
                    onSelected: (_) => setSt(() => selectedMethod = method),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Refunded via PhonePe',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Refund Paid'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.post(
        '/api/delivery/retailer/orders/$orderId/mark-refund-paid?outlet_id=$outletCode',
        {
          'refund_method': selectedMethod,
          if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
        },
      );
      notesCtrl.dispose();
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Refund marked as paid successfully!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
        await _fetchRetailerData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message']?.toString() ?? 'Failed to update refund status')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error marking refund paid: $e');
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

    return SaleOrder(
      saleNo: record['sale_no']?.toString() ?? record['id']?.toString() ?? '',
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

  // Handle final receive of return order
  Future<void> _handleFinalReceiveReturn(dynamic orderId) async {
    final order = _retailerOrders.firstWhere(
        (o) => o['id'].toString() == orderId.toString(),
        orElse: () => null);
    if (order == null) return;

    final bool isExchange = order['return_type'] == 'EXCHANGE';
    final bool isPaidOrder = order['payment_status'] == 'PAID';

    bool addToStock = true;
    String refundAction = isExchange
        ? 'EXCHANGE'
        : (isPaidOrder ? 'REFUND' : 'ACCEPT_NO_REFUND'); // 'REFUND', 'ACCEPT_NO_REFUND', 'REJECT', or 'EXCHANGE'
    String? refundPaymentMode;
    double calculatedRefundAmt = 0.0;
    final returnedItemsList = order['returned_items'] as List? ?? [];
    if (returnedItemsList.isNotEmpty) {
      for (var it in returnedItemsList) {
        final amt = double.tryParse(it['amount']?.toString() ?? '0') ?? 0.0;
        calculatedRefundAmt += amt;
      }
    } else if (order['return_item_id'] != null) {
      final matched = (order['items'] as List?)?.firstWhere(
          (x) => x['item_id'] == order['return_item_id'],
          orElse: () => null);
      if (matched != null) {
        final netAmt = double.tryParse(matched['net_amount']?.toString() ?? '') ?? 
                       (double.tryParse(matched['amount']?.toString() ?? '') ?? 0.0);
        calculatedRefundAmt = netAmt;
      }
    } else {
      calculatedRefundAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
    }

    final double maxRefundAmount = calculatedRefundAmt;
    double refundAmount = maxRefundAmount;
    String refundAmountType = 'FULL'; // 'FULL', 'HALF', 'CUSTOM'
    String remark = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: Text(isExchange ? 'Finalize Exchange Settle' : 'Final Receive Return'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add returned items back to stock?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Yes'),
                            value: true,
                            groupValue: addToStock,
                            onChanged: (val) {
                              if (val != null) setSt(() => addToStock = val);
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('No'),
                            value: false,
                            groupValue: addToStock,
                            onChanged: (val) {
                              if (val != null) setSt(() => addToStock = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!isExchange) ...[
                      const Divider(),
                      const Text(
                        'Select Settlement Action',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (isPaidOrder)
                        RadioListTile<String>(
                          title: const Text('Refund (Credit Note)'),
                          subtitle: const Text('Generates POS Credit Note and pending refund'),
                          value: 'REFUND',
                          groupValue: refundAction,
                          onChanged: (val) {
                            if (val != null) setSt(() => refundAction = val);
                          },
                        )
                      else
                        RadioListTile<String>(
                          title: const Text('Accept Return (No Refund)'),
                          subtitle: const Text('No payment was collected, accept return only'),
                          value: 'ACCEPT_NO_REFUND',
                          groupValue: refundAction,
                          onChanged: (val) {
                            if (val != null) setSt(() => refundAction = val);
                          },
                        ),
                      RadioListTile<String>(
                        title: const Text('Reject Return Request'),
                        subtitle: const Text('Reject return, restore sales ledger'),
                        value: 'REJECT',
                        groupValue: refundAction,
                        onChanged: (val) {
                          if (val != null) setSt(() => refundAction = val);
                        },
                      ),
                      if (refundAction == 'REFUND') ...[
                        const Divider(),
                        const Text(
                          'Refund Payment Mode',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Keep Pending (Credit Note Only)'),
                              value: refundPaymentMode,
                              items: const [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Keep Pending (Credit Note Only)'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'CASH',
                                  child: Text('CASH'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'UPI',
                                  child: Text('UPI'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'CARD',
                                  child: Text('CARD'),
                                ),
                              ],
                              onChanged: (val) {
                                setSt(() => refundPaymentMode = val);
                              },
                            ),
                          ),
                        ),
                        const Divider(),
                        const Text(
                          'Refund Amount Option',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('Full (Rs. ${maxRefundAmount.toStringAsFixed(2)})'),
                              selected: refundAmountType == 'FULL',
                              onSelected: (selected) {
                                if (selected) {
                                  setSt(() {
                                    refundAmountType = 'FULL';
                                    refundAmount = maxRefundAmount;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text('Half (Rs. ${(maxRefundAmount / 2).toStringAsFixed(2)})'),
                              selected: refundAmountType == 'HALF',
                              onSelected: (selected) {
                                if (selected) {
                                  setSt(() {
                                    refundAmountType = 'HALF';
                                    refundAmount = maxRefundAmount / 2;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Custom'),
                              selected: refundAmountType == 'CUSTOM',
                              onSelected: (selected) {
                                if (selected) {
                                  setSt(() {
                                    refundAmountType = 'CUSTOM';
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey(refundAmount),
                          enabled: refundAmountType == 'CUSTOM',
                          initialValue: refundAmount.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Enter refund amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixText: 'Rs. ',
                            suffixText: refundAmountType != 'CUSTOM' ? '(Selected Option)' : null,
                          ),
                          onChanged: (val) {
                            refundAmount = double.tryParse(val) ?? 0.0;
                          },
                        ),
                      ],
                    ],
                    const Divider(),
                    const Text(
                      'Remark / Note',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Enter remark (e.g. item condition)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        remark = val;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!isExchange && refundAction == 'REFUND' && refundAmount < 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Refund amount cannot be negative.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, {
                      'add_to_stock': addToStock,
                      'refund_action': refundAction,
                      'refund_payment_mode': refundPaymentMode,
                      'refund_amount': refundAmount,
                      'action': refundAction,
                      'remark': remark.trim(),
                    });
                  },
                  child: Text(isExchange ? 'Confirm Exchange' : 'Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = Map<String, dynamic>.from(result)..['outlet_id'] = outletCode;
      final res = await ApiClient.post(
        '/api/delivery/retailer/orders/$orderId/final-receive-return',
        body,
      );
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Return processed successfully!')),
          );
        }
        _fetchRetailerData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to process final receive.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in final receive: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Open / Edit order in POS Sales Billing screen

  Future<void> _editOrderInPOS(dynamic order) async {
    // Editing invoices is only supported on the Windows Desktop Application
    if (Platform.isAndroid || Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.desktop_windows, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invoice editing can only be done on your Windows Desktop Application.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blueGrey.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    int? saleId = order['sale_id'];
    if (saleId == null) {
      setState(() => _isLoading = true);
      try {
        final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
        final body = { 'rider_id': null, 'outlet_id': outletCode, 'for_edit': true };
        final res = await ApiClient.post('/api/delivery/retailer/orders/${order['id']}/accept', body);
        if (res['success'] == true) {
          saleId = res['data']['sale_id'];
          await _fetchRetailerData();
        }
      } catch (e) {
        debugPrint('Error generating sale for edit: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }

    if (saleId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SaleScreen(editSaleId: saleId)),
      ).then((_) {
        _fetchRetailerData();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open sale editor. Please ensure billing configuration is active.')),
      );
    }
  }

  // Accept customer order
  Future<void> _acceptOrder(int orderId, dynamic riderId) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'rider_id': riderId == 'AUTO' ? null : riderId,
        'outlet_id': outletCode,
      };
      final res = await ApiClient.post('/api/delivery/retailer/orders/$orderId/accept', body);
      if (res['success'] == true) {
        final data = res['data'];
        await _fetchRetailerData();
        
        if (mounted) {
          _showReceiptDialog(data);
        }
      }
    } catch (e) {
      debugPrint('Error accepting order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Pay rider commission
  Future<void> _payCommission(int riderId, String paymentMethod) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.post('/api/delivery/retailer/riders/$riderId/pay-commission', {
        'payment_method': paymentMethod,
        'outlet_id': outletCode,
      });
      if (res['success'] == true) {
        await _fetchRetailerData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Commission paid successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error paying commission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pay commission: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show dialog to pay rider commission with selected payment mode
  void _showPayCommissionDialog(int riderId) {
    String selectedMethod = 'CASH';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Pay Rider Commission'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select payment mode:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / Online')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedMethod = val;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _payCommission(riderId, selectedMethod);
                  },
                  child: const Text('Pay'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteRiderConfirm(dynamic rider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rider'),
        content: Text('Are you sure you want to delete rider "${rider['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRider(rider['id']);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRider(int riderId) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.delete('/api/delivery/retailer/riders/$riderId?outlet_id=$outletCode');
      if (res['success'] == true) {
        final msg = res['message'] ?? 'Rider deleted successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        _fetchRetailerData();
      }
    } catch (e) {
      debugPrint('Error deleting rider: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show dialog to accept order and assign a rider (auto or manual)
  void _showAssignRiderDialog(int orderId) {
    dynamic selectedRiderVal = 'AUTO';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Accept & Assign Order #$orderId'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose how you want to assign this order:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<dynamic>(
                    value: selectedRiderVal,
                    items: [
                      const DropdownMenuItem<dynamic>(
                        value: 'AUTO',
                        child: Text('Auto-Assign (Default)'),
                      ),
                      ..._retailerRiders.map((dynamic rider) {
                        return DropdownMenuItem<dynamic>(
                          value: rider['id'],
                          child: Text(rider['name']),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRiderVal = val;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Rider',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _acceptOrder(orderId, selectedRiderVal);
                  },
                  child: const Text('Accept & Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show dialog to reassign rider for an already accepted/assigned order
  void _showReassignRiderDialog(int orderId, dynamic currentRiderId) {
    dynamic selectedRiderVal = currentRiderId ?? 'NONE';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Reassign Rider for Order #$orderId'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select a new rider or option for this order:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<dynamic>(
                    value: selectedRiderVal,
                    items: [
                      const DropdownMenuItem<dynamic>(
                        value: 'AUTO',
                        child: Text('Auto-Assign'),
                      ),
                      const DropdownMenuItem<dynamic>(
                        value: 'NONE',
                        child: Text('Unassign / None'),
                      ),
                      ..._retailerRiders.map((dynamic rider) {
                        return DropdownMenuItem<dynamic>(
                          value: rider['id'],
                          child: Text(rider['name']),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRiderVal = val;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Rider',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reassignRider(orderId, selectedRiderVal);
                  },
                  child: const Text('Reassign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // API Call to reassign rider
  Future<void> _reassignRider(int orderId, dynamic riderId) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'rider_id': riderId,
        'outlet_id': outletCode,
      };
      final res = await ApiClient.post('/api/delivery/retailer/orders/$orderId/reassign', body);
      if (res['success'] == true) {
        await _fetchRetailerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Rider reassigned successfully.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to reassign rider.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error reassigning rider: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _getRiderUnpaidCommission(int riderId) {
    double total = 0.0;
    for (var order in _retailerOrders) {
      if (order['assigned_partner_id'] == riderId &&
          order['status'] == 'DELIVERED' &&
          order['commission_status'] == 'UNPAID') {
        final commAmt = double.tryParse(order['commission_amount']?.toString() ?? '20') ?? 20.0;
        total += commAmt;
      }
    }
    return total;
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search customer name/phone/ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetchRetailerData();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onSubmitted: (val) => _fetchRetailerData(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _fetchRetailerData,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text("Only Today's Orders"),
                    value: _todayOnly,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setState(() {
                        _todayOnly = val ?? true;
                      });
                      _fetchRetailerData();
                    },
                  ),
                ),
              ],
            ),
            if (!_todayOnly) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('From: ${DateFormat('dd-MMM-yyyy').format(_fromDate)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _fromDate = picked;
                          });
                          _fetchRetailerData();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('To: ${DateFormat('dd-MMM-yyyy').format(_toDate)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _toDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _toDate = picked;
                          });
                          _fetchRetailerData();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView(ThemeData theme) {
    double totalEarnings = 0.0;
    int deliveredCount = 0;
    int cancelledCount = 0;
    int activeCount = 0;
    int assignedCount = 0;
    double cashPayments = 0.0;
    double onlinePayments = 0.0;
    int cashCount = 0;
    int onlineCount = 0;

    for (var order in _retailerOrders) {
      final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
      final netAmt = double.tryParse(order['net_amount']?.toString() ?? '0.0') ?? 0.0;
      final payMode = order['payment_mode']?.toString().toUpperCase() ?? 'CASH';

      if (status == 'DELIVERED') {
        totalEarnings += netAmt;
        deliveredCount++;
      } else if (status == 'CANCELLED') {
        cancelledCount++;
      } else {
        activeCount++;
        if (status == 'ASSIGNED' || status == 'OUT_FOR_DELIVERY') {
          assignedCount++;
        }
      }

      if (status != 'CANCELLED') {
        if (payMode == 'CASH') {
          cashPayments += netAmt;
          cashCount++;
        } else {
          onlinePayments += netAmt;
          onlineCount++;
        }
      }
    }

    int availableRiders = 0;
    int busyRiders = 0;
    final List<dynamic> availableRidersList = [];
    final List<dynamic> busyRidersList = [];

    for (var rider in _retailerRiders) {
      final status = rider['status']?.toString().toUpperCase() ?? 'AVAILABLE';
      if (status == 'AVAILABLE') {
        availableRiders++;
        availableRidersList.add(rider);
      } else {
        busyRiders++;
        busyRidersList.add(rider);
      }
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    final isMobile = MediaQuery.of(context).size.width < 768;

    final card1 = _buildKpiCard(
      title: 'Total Earnings',
      value: '₹${totalEarnings.toStringAsFixed(2)}',
      subtitle: '$deliveredCount delivered orders',
      icon: Icons.currency_rupee,
      color: Colors.green,
      theme: theme,
    );
    final card2 = _buildKpiCard(
      title: 'Active Orders',
      value: '$activeCount Pending',
      subtitle: '$assignedCount assigned to riders',
      icon: Icons.local_shipping_outlined,
      color: Colors.blue,
      theme: theme,
    );
    final card3 = _buildKpiCard(
      title: 'Cancelled Orders',
      value: '$cancelledCount Cancelled',
      subtitle: '${_retailerOrders.length} total orders',
      icon: Icons.cancel_outlined,
      color: Colors.red,
      theme: theme,
    );
    final card4 = _buildKpiCard(
      title: 'Active Riders',
      value: '$availableRiders Available',
      subtitle: '$busyRiders riders busy',
      icon: Icons.motorcycle_outlined,
      color: Colors.orange,
      theme: theme,
    );

    Widget kpiGrid;
    if (isMobile) {
      kpiGrid = Column(
        children: [
          Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: card3),
              const SizedBox(width: 12),
              Expanded(child: card4),
            ],
          ),
        ],
      );
    } else {
      kpiGrid = Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 12),
          Expanded(child: card2),
          const SizedBox(width: 12),
          Expanded(child: card3),
          const SizedBox(width: 12),
          Expanded(child: card4),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiGrid,
          const SizedBox(height: 24),

          // SECONDARY DETAILS
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildPaymentsBreakdownCard(theme, cashPayments, onlinePayments, cashCount, onlineCount),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: _buildRidersStatusCard(theme, availableRidersList, busyRidersList),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildPaymentsBreakdownCard(theme, cashPayments, onlinePayments, cashCount, onlineCount),
                    const SizedBox(height: 20),
                    _buildRidersStatusCard(theme, availableRidersList, busyRidersList),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 18,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsBreakdownCard(
    ThemeData theme,
    double cashAmount,
    double onlineAmount,
    int cashCount,
    int onlineCount,
  ) {
    final double totalAmount = cashAmount + onlineAmount;
    final double cashPercent = totalAmount > 0 ? (cashAmount / totalAmount) : 0.0;
    final double onlinePercent = totalAmount > 0 ? (onlineAmount / totalAmount) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Summary',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Total Transaction Volume',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cash on Delivery ($cashCount sales)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('₹${cashAmount.toStringAsFixed(2)} (${(cashPercent * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cashPercent,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Online Payments ($onlineCount sales)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('₹${onlineAmount.toStringAsFixed(2)} (${(onlinePercent * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: onlinePercent,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidersStatusCard(
    ThemeData theme,
    List<dynamic> availableRiders,
    List<dynamic> busyRiders,
  ) {
    final allRiders = [...availableRiders, ...busyRiders];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.motorcycle, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Rider Directory & Status',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${allRiders.length} Registered',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allRiders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No delivery partners registered.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allRiders.length > 5 ? 5 : allRiders.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final rider = allRiders[index];
                final String name = rider['name'] ?? 'Rider';
                final String phone = rider['phone'] ?? 'N/A';
                final String status = rider['status']?.toString().toUpperCase() ?? 'AVAILABLE';
                final isAvailable = status == 'AVAILABLE';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                      child: Icon(
                        isAvailable ? Icons.check_circle_outline : Icons.pending_outlined,
                        size: 16,
                        color: isAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Phone: $phone', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRetailerOrdersSection(ThemeData theme) {
    final filteredOrders = _retailerOrders.where((order) {
      final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
      if (_statusFilter == 'ALL') return true;
      if (_statusFilter == 'PENDING') {
        return status == 'PENDING' || status == 'ACCEPTED' || status == 'ASSIGNED' || status == 'OUT_FOR_DELIVERY';
      }
      if (_statusFilter == 'DELIVERED') {
        return status == 'DELIVERED';
      }
      if (_statusFilter == 'CANCELLED') {
        return status == 'CANCELLED';
      }
      if (_statusFilter == 'REFUND_PENDING') {
        return order['refund_status']?.toString() == 'PENDING';
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Incoming Customer Orders',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _fetchRetailerData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSubTabButton(
                              label: 'Dashboard',
                              isSelected: _ordersSubTab == 0,
                              onTap: () => setState(() => _ordersSubTab = 0),
                              icon: Icons.dashboard_outlined,
                              theme: theme,
                            ),
                          ),
                          Expanded(
                            child: _buildSubTabButton(
                              label: 'Orders List',
                              isSelected: _ordersSubTab == 1,
                              onTap: () => setState(() => _ordersSubTab = 1),
                              icon: Icons.list_alt_outlined,
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Incoming Customer Orders', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        children: [
                          _buildSubTabButton(
                            label: 'Dashboard',
                            isSelected: _ordersSubTab == 0,
                            onTap: () => setState(() => _ordersSubTab = 0),
                            icon: Icons.dashboard_outlined,
                            theme: theme,
                          ),
                          _buildSubTabButton(
                            label: 'Orders List',
                            isSelected: _ordersSubTab == 1,
                            onTap: () => setState(() => _ordersSubTab = 1),
                            icon: Icons.list_alt_outlined,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchRetailerData,
                    )
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildFilterBar(theme),
          const SizedBox(height: 16),
          if (_ordersSubTab == 0)
            Expanded(
              child: _buildDashboardView(theme),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${_retailerOrders.length})'),
                    selected: _statusFilter == 'ALL',
                    onSelected: (selected) {
                      if (selected) setState(() => _statusFilter = 'ALL');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Pending (${_retailerOrders.where((o) => ['PENDING', 'ACCEPTED', 'ASSIGNED', 'OUT_FOR_DELIVERY'].contains(o['status']?.toString().toUpperCase())).length})'),
                    selected: _statusFilter == 'PENDING',
                    onSelected: (selected) {
                      if (selected) setState(() => _statusFilter = 'PENDING');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Delivered (${_retailerOrders.where((o) => o['status']?.toString().toUpperCase() == 'DELIVERED').length})'),
                    selected: _statusFilter == 'DELIVERED',
                    onSelected: (selected) {
                      if (selected) setState(() => _statusFilter = 'DELIVERED');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Cancelled (${_retailerOrders.where((o) => o['status']?.toString().toUpperCase() == 'CANCELLED').length})'),
                    selected: _statusFilter == 'CANCELLED',
                    onSelected: (selected) {
                      if (selected) setState(() => _statusFilter = 'CANCELLED');
                    },
                  ),
                  const SizedBox(width: 8),
                  (() {
                    final pendingRefundCount = _retailerOrders.where((o) => o['refund_status']?.toString() == 'PENDING').length;
                    return Badge(
                      isLabelVisible: pendingRefundCount > 0,
                      label: Text('$pendingRefundCount'),
                      backgroundColor: Colors.red.shade600,
                      child: ChoiceChip(
                        label: const Text('Refund Pending'),
                        selected: _statusFilter == 'REFUND_PENDING',
                        selectedColor: Colors.green.shade100,
                        onSelected: (selected) {
                          if (selected) setState(() => _statusFilter = 'REFUND_PENDING');
                        },
                        avatar: Icon(Icons.currency_rupee, size: 14,
                          color: _statusFilter == 'REFUND_PENDING' ? Colors.green.shade800 : Colors.grey.shade600),
                      ),
                    );
                  })(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredOrders.isEmpty
                  ? const Center(child: Text('No matching orders found.'))
                  : ListView.builder(
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                      final itemsList = order['items'] as List? ?? [];
                      final netAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
                      final isPrepaid = order['is_prepaid'] == true || order['is_prepaid'] == 1;
                      final isCredit = order['payment_mode'] == 'CREDIT';
                      final isCod = !isPrepaid && !isCredit;
                      final status = order['status'] ?? 'PENDING';
                      final riderName = order['partner']?['name'] ?? 'Unassigned';

                      // Helper variables for return banner details
                      final returnStatus = order['return_status'];
                      Color returnBannerColor = Colors.grey;
                      IconData returnBannerIcon = Icons.info_outline;
                      String returnBannerText = '';
                      if (returnStatus != null) {
                        final returnedItems = _formatReturnedItems(order);
                        if (returnStatus == 'PENDING') {
                          returnBannerColor = Colors.orange;
                          returnBannerIcon = Icons.pending_actions_outlined;
                          returnBannerText = 'Return Requested: ${order['return_type']} - $returnedItems';
                        } else if (returnStatus == 'RETURN_ACCEPTED') {
                          returnBannerColor = Colors.amber.shade800;
                          returnBannerIcon = Icons.check_circle_outline;
                          returnBannerText = order['return_type'] == 'EXCHANGE'
                              ? 'Exchange Approved: Rider picking up new item from store.'
                              : 'Return Approved: Rider on the way to collect item.';
                        } else if (returnStatus == 'RETURN_PICKED_UP_FROM_STORE') {
                          returnBannerColor = Colors.orange;
                          returnBannerIcon = Icons.directions_bike;
                          returnBannerText = order['return_type'] == 'EXCHANGE'
                              ? 'Exchange Approved: Rider out for delivery of replacement item.'
                              : 'Return Approved: Rider out for collection of return item.';
                        } else if (returnStatus == 'RETURN_COLLECTED') {
                          returnBannerColor = order['return_type'] == 'EXCHANGE' ? Colors.green : Colors.orange;
                          returnBannerIcon = order['return_type'] == 'EXCHANGE' ? Icons.check_circle : Icons.done;
                          returnBannerText = order['return_type'] == 'EXCHANGE'
                              ? 'Exchange Completed. Replacement Delivered.'
                              : 'Return Collected. Rider returning to store with item.';
                        } else if (returnStatus == 'RETURN_HANDED_OVER') {
                          returnBannerColor = order['return_type'] == 'EXCHANGE' ? Colors.green : Colors.indigo;
                          returnBannerIcon = order['return_type'] == 'EXCHANGE' ? Icons.check_circle : Icons.airport_shuttle_outlined;
                          returnBannerText = order['return_type'] == 'EXCHANGE'
                              ? 'Exchange Completed. Replacement Delivered.'
                              : 'Return Handed Over to Store. Awaiting final receive.';
                        } else if (returnStatus == 'RETURNED') {
                          returnBannerColor = Colors.blue;
                          returnBannerIcon = Icons.keyboard_return_outlined;
                          returnBannerText = 'Returned & Refunded - $returnedItems';
                        } else if (returnStatus == 'EXCHANGED') {
                          returnBannerColor = Colors.purple;
                          returnBannerIcon = Icons.assignment_return_outlined;
                          returnBannerText = 'Returned & Exchanged - $returnedItems';
                        } else if (returnStatus == 'REDELIVERED') {
                          returnBannerColor = Colors.teal;
                          returnBannerIcon = Icons.assignment_return_outlined;
                          returnBannerText = 'Returned & Redelivered - $returnedItems';
                        } else {
                          returnBannerColor = Colors.red;
                          returnBannerIcon = Icons.close;
                          returnBannerText = 'Return Request Rejected - $returnedItems';
                        }
                      }

                      Color statusColor = Colors.orange;
                      if (status == 'ACCEPTED') statusColor = Colors.blue;
                      if (status == 'ASSIGNED') statusColor = Colors.indigo;
                      if (status == 'OUT_FOR_DELIVERY') statusColor = Colors.teal;
                      if (status == 'DELIVERED') statusColor = Colors.green;
                      if (status == 'CANCELLED') statusColor = Colors.red;

                      return Card(
                        elevation: 0.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          collapsedShape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isCredit
                                ? Colors.purple.shade50
                                : (isCod ? Colors.red.shade50 : Colors.green.shade50),
                            foregroundColor: isCredit
                                ? Colors.purple.shade700
                                : (isCod ? Colors.red.shade700 : Colors.green.shade700),
                            radius: 20,
                            child: Icon(
                                isCredit
                                    ? Icons.credit_card
                                    : (isCod ? Icons.money_off_outlined : Icons.monetization_on_outlined),
                                size: 20),
                          ),
                          title: Text(
                            '${order['customer_name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            'Order #${order['id']} • Rs. ${netAmt.toStringAsFixed(2)} • ${isCredit ? "Credit" : (isCod ? "CoD" : "Prepaid")}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Phone: ${order['customer_phone']}',
                                        style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                                      ),
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
                                          style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.delivery_dining_outlined, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Assigned Rider: $riderName',
                                        style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  if (status == 'CANCELLED') ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.cancel, color: Colors.red.shade700, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Cancellation Reason: ${order['cancellation_reason'] ?? "No reason provided"}',
                                              style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (order['feedback'] != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Customer Feedback: ${order['feedback']['rating']}/5',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Internal Purpose Only',
                                                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (order['feedback']['comment'] != null && order['feedback']['comment'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '"${order['feedback']['comment']}"',
                                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                                            ),
                                          ],
                                          if (order['feedback']['reply'] != null) ...[
                                            const Divider(height: 16),
                                            Row(
                                              children: [
                                                const Icon(Icons.reply, color: Colors.blue, size: 14),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Your Reply: "${order['feedback']['reply']}"',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 8),
                                            OutlinedButton.icon(
                                              onPressed: () => _replyToFeedbackDialog(order['id']),
                                              icon: const Icon(Icons.reply, size: 14),
                                              label: const Text('Reply to Feedback'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.blue.shade700,
                                                side: BorderSide(color: Colors.blue.shade300),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (order['return_status'] != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: returnBannerColor.withOpacity(0.08),
                                        border: Border.all(
                                          color: returnBannerColor.withOpacity(0.3),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            returnBannerIcon,
                                            color: returnBannerColor == Colors.orange
                                                ? Colors.orange.shade800
                                                : (returnBannerColor == Colors.blue
                                                    ? Colors.blue.shade800
                                                    : (returnBannerColor == Colors.purple
                                                        ? Colors.purple.shade800
                                                        : (returnBannerColor == Colors.teal
                                                            ? Colors.teal.shade800
                                                            : (returnBannerColor == Colors.red
                                                                ? Colors.red.shade800
                                                                : returnBannerColor)))),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              returnBannerText,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: returnBannerColor == Colors.orange
                                                    ? Colors.orange.shade900
                                                    : (returnBannerColor == Colors.blue
                                                        ? Colors.blue.shade900
                                                        : (returnBannerColor == Colors.purple
                                                            ? Colors.purple.shade900
                                                            : (returnBannerColor == Colors.teal
                                                                ? Colors.teal.shade900
                                                                : (returnBannerColor == Colors.red
                                                                    ? Colors.red.shade900
                                                                    : returnBannerColor)))),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const Divider(height: 24),
                                  if (order['received_items'] != null && (order['received_items'] as List).isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'ORDERED ITEMS',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.grey,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...itemsList.map<Widget>((item) {
                                      final rate = double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
                                      final qty = double.tryParse(item['qty']?.toString() ?? '') ?? 0.0;
                                      final total = rate * qty;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '•  ${item['item_name']} x ${qty.toStringAsFixed(0)}',
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, decoration: TextDecoration.lineThrough),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              'Rs. ${total.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                          'RECEIVED ITEMS (MODIFIED)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...(order['received_items'] as List).map<Widget>((item) {
                                      final rate = double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
                                      final qty = double.tryParse(item['qty']?.toString() ?? '') ?? 0.0;
                                      final total = rate * qty;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '•  ${item['item_name']} x ${qty.toStringAsFixed(0)}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              'Rs. ${total.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'ITEMS',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.grey,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...itemsList.map<Widget>((item) {
                                      final total = (double.tryParse(item['rate']?.toString() ?? '') ?? 0.0) *
                                          (double.tryParse(item['qty']?.toString() ?? '') ?? 0.0);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '•  ${item['item_name']} x ${item['qty']}',
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              'Rs. ${total.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
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
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Correction Reason: ${order['modification_reason']}',
                                              style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (order['refund_status']?.toString() == 'PENDING' && !isCod) ...[
                                    (() {
                                      final origAmt = double.tryParse(order['original_net_amount']?.toString() ?? '') ?? 0.0;
                                      final curAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
                                      final refundDue = origAmt > 0 ? origAmt - curAmt : 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.green.shade300, width: 1.5),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.currency_rupee, size: 18, color: Colors.green.shade800),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'REFUND PENDING',
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800, letterSpacing: 0.5),
                                                    ),
                                                    if (refundDue > 0)
                                                      Text(
                                                        'Rs. ${refundDue.toStringAsFixed(2)} to be refunded to customer',
                                                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              FilledButton(
                                                onPressed: () => _handleMarkRefundPaid(order['id'], refundDue),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.green.shade700,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  minimumSize: Size.zero,
                                                ),
                                                child: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    })(),
                                  ],
                                  if (order['original_net_amount'] != null) ...[
                                    (() {
                                      final origAmt = double.tryParse(order['original_net_amount'].toString()) ?? 0.0;
                                      final diff = netAmt - origAmt;
                                      if (diff.abs() > 0.01) {
                                        final isRefund = diff < 0;
                                        final isRefunded = order['refund_status']?.toString() == 'REFUNDED';
                                        
                                        String label = '';
                                        Color boxColor;
                                        Color textColor;
                                        Color borderColor;

                                        if (isPrepaid) {
                                          if (isRefund) {
                                            if (isRefunded) {
                                              final refundPaidAtRaw = order['refund_paid_at'] ?? order['updated_at'];
                                              final refundPaidAtStr = refundPaidAtRaw != null
                                                  ? DateFormat('dd-MMM-yyyy, hh:mm a').format(DateTime.parse(refundPaidAtRaw.toString()).toLocal())
                                                  : '';
                                              final refundMethod = order['refund_payment_mode'] ?? order['payment_mode'] ?? 'UPI';
                                              label = 'Refund Paid via $refundMethod at $refundPaidAtStr:';
                                              boxColor = Colors.blue.shade50;
                                              borderColor = Colors.blue.shade200;
                                              textColor = Colors.blue.shade800;
                                            } else {
                                              label = 'Amount to Refund:';
                                              boxColor = Colors.green.shade50;
                                              borderColor = Colors.green.shade200;
                                              textColor = Colors.green.shade800;
                                            }
                                          } else {
                                            label = 'Extra Amount Charged:';
                                            boxColor = Colors.red.shade50;
                                            borderColor = Colors.red.shade200;
                                            textColor = Colors.red.shade800;
                                          }
                                        } else {
                                          // COD Order
                                          if (isRefund) {
                                            label = 'Amount Reduced:';
                                            boxColor = Colors.green.shade50;
                                            borderColor = Colors.green.shade200;
                                            textColor = Colors.green.shade800;
                                          } else {
                                            label = 'Extra Amount to Pay:';
                                            boxColor = Colors.red.shade50;
                                            borderColor = Colors.red.shade200;
                                            textColor = Colors.red.shade800;
                                          }
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.only(top: 12.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: boxColor,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: borderColor),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    label,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: textColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'Rs. ${diff.abs().toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: textColor,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    })(),
                                  ],
                                  if (status == 'CANCELLED' && (order['is_prepaid'] == true || order['is_prepaid'] == 1) && order['refund_status'] != null) ...[
                                    (() {
                                      final isRefunded = order['refund_status']?.toString() == 'REFUNDED';
                                      final refundPaidAtRaw = order['refund_paid_at'] ?? order['updated_at'];
                                      final refundPaidAtStr = refundPaidAtRaw != null
                                          ? DateFormat('dd-MMM-yyyy, hh:mm a').format(DateTime.parse(refundPaidAtRaw.toString()).toLocal())
                                          : '';
                                      final refundMethod = order['refund_payment_mode'] ?? order['payment_mode'] ?? 'UPI';
                                      
                                      final label = isRefunded
                                          ? 'Refund Paid via $refundMethod at $refundPaidAtStr:'
                                          : 'Refund Pending:';

                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isRefunded ? Colors.blue.shade50 : Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isRefunded ? Colors.blue.shade200 : Colors.amber.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isRefunded ? Colors.blue.shade800 : Colors.amber.shade900,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'Rs. ${netAmt.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isRefunded ? Colors.blue.shade800 : Colors.amber.shade900,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    })(),
                                  ],
                                  const Divider(),
                                  // Status label
                                  Text(
                                    status == 'PENDING'
                                        ? 'Pending Action'
                                        : (status == 'ACCEPTED'
                                            ? 'Auto-Assignment: Rider Unavailable'
                                            : (status == 'ASSIGNED'
                                                ? 'Assigned to $riderName'
                                                : (status == 'OUT_FOR_DELIVERY'
                                                    ? 'Out for Delivery via $riderName'
                                                    : (status == 'DELIVERED'
                                                        ? 'Delivered'
                                                        : 'Cancelled')))),
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Action buttons wrapped so they never overflow
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      if (order['refund_status']?.toString() == 'PENDING' && !isCod) ...[
                                        (() {
                                          final origAmt = double.tryParse(order['original_net_amount']?.toString() ?? '') ?? 0.0;
                                          final curAmt = double.tryParse(order['net_amount']?.toString() ?? '') ?? 0.0;
                                          final refundDue = origAmt > 0 ? origAmt - curAmt : 0.0;
                                          return FilledButton.icon(
                                            onPressed: () => _handleMarkRefundPaid(order['id'], refundDue),
                                            icon: const Icon(Icons.currency_rupee, size: 16),
                                            label: Text(refundDue > 0
                                                ? 'Mark Refund Paid (Rs. ${refundDue.toStringAsFixed(2)})'
                                                : 'Mark Refund Paid'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                            ),
                                          );
                                        })(),
                                      ] else if (order['return_status'] == 'PENDING') ...[
                                        OutlinedButton.icon(
                                          onPressed: () => _handleReturnRequest(order['id'], 'REJECT'),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Reject Return'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red.shade700,
                                            side: BorderSide(color: Colors.red.shade300),
                                          ),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () => _handleReturnRequest(order['id'], 'ACCEPT'),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: Text(order['return_type'] == 'REFUND' ? 'Accept & Refund' : 'Accept & Exchange'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ] else if (order['return_status'] == 'RETURN_HANDED_OVER' || order['return_status'] == 'RETURN_ACCEPTED') ...[
                                        OutlinedButton.icon(
                                          onPressed: () => _showReceiptDialog(order),
                                          icon: const Icon(Icons.receipt_long, size: 16),
                                          label: const Text('Receipt'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.teal.shade700,
                                            side: BorderSide(color: Colors.teal.shade300),
                                          ),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () => _handleFinalReceiveReturn(order['id']),
                                          icon: const Icon(Icons.check_circle_outline, size: 16),
                                          label: const Text('Final Receive'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ] else ...[
                                        if (status != 'DELIVERED' && status != 'CANCELLED')
                                          OutlinedButton.icon(
                                            onPressed: () => _cancelOrder(order),
                                            icon: const Icon(Icons.cancel, size: 16),
                                            label: const Text('Cancel'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red.shade700,
                                              side: BorderSide(color: Colors.red.shade300),
                                            ),
                                          ),
                                        if (status != 'CANCELLED') ...[
                                          OutlinedButton.icon(
                                            onPressed: () => _showReceiptDialog(order),
                                            icon: const Icon(Icons.receipt_long, size: 16),
                                            label: const Text('Receipt'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.teal.shade700,
                                              side: BorderSide(color: Colors.teal.shade300),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => _editOrderInPOS(order),
                                            icon: const Icon(Icons.edit, size: 16),
                                            label: const Text('Edit Invoice'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.blue.shade700,
                                              side: BorderSide(color: Colors.blue.shade300),
                                            ),
                                          ),
                                        ],
                                        if (status == 'PENDING')
                                          FilledButton.icon(
                                            onPressed: () => _showAssignRiderDialog(order['id']),
                                            icon: const Icon(Icons.check, size: 16),
                                            label: const Text('Accept & Assign'),
                                          ),
                                        if (status == 'ACCEPTED' || status == 'ASSIGNED')
                                          OutlinedButton.icon(
                                            onPressed: () => _showReassignRiderDialog(order['id'], order['assigned_partner_id']),
                                            icon: const Icon(Icons.person_outline, size: 16),
                                            label: const Text('Reassign Rider'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.orange.shade800,
                                              side: BorderSide(color: Colors.orange.shade300),
                                            ),
                                          ),
                                        if (status == 'ACCEPTED')
                                          TextButton(
                                            onPressed: _fetchRetailerData,
                                            child: const Text('Retry Auto-Assign'),
                                          ),
                                      ],
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildRetailerRidersSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Riders', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: () => _showAddRiderDialog(),
              )
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _retailerRiders.isEmpty
                ? const Center(child: Text('No riders registered yet.'))
                : ListView.builder(
                    itemCount: _retailerRiders.length,
                    itemBuilder: (context, index) {
                      final rider = _retailerRiders[index];
                      final status = rider['status'] ?? 'OFFLINE';

                      Color riderColor = Colors.green;
                      if (status == 'BUSY') riderColor = Colors.orange;
                      if (status == 'OFFLINE') riderColor = Colors.grey;

                      final unpaidCommission = _getRiderUnpaidCommission(rider['id']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: riderColor.withOpacity(0.15),
                          child: Icon(Icons.delivery_dining, color: riderColor),
                        ),
                        title: Text(rider['name'] ?? 'Rider'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Phone: ${rider['phone']}'),
                            Text(
                              'Unpaid Comm: Rs. ${unpaidCommission.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: unpaidCommission > 0 ? FontWeight.bold : FontWeight.normal,
                                color: unpaidCommission > 0 ? Colors.red.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unpaidCommission > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: TextButton(
                                  onPressed: () => _showPayCommissionDialog(rider['id']),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Pay Comm'),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: riderColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(color: riderColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDeleteRiderConfirm(rider),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  void _showAddRiderDialog() {
    _riderNameCtrl.clear();
    _riderPhoneCtrl.clear();
    _riderPasswordCtrl.clear();
    _riderConfirmPasswordCtrl.clear();
    _riderPasswordVisible = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.motorcycle, color: Colors.deepOrange),
              SizedBox(width: 8),
              Expanded(
                child: Text('Register Delivery Rider'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rider details for delivery assignment',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _riderNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _riderPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _riderPasswordCtrl,
                  obscureText: !_riderPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'App Password *',
                    helperText: 'Must be at least 4 characters',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_riderPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setDlgState(() => _riderPasswordVisible = !_riderPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _riderConfirmPasswordCtrl,
                  obscureText: !_riderPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_riderPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setDlgState(() => _riderPasswordVisible = !_riderPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _addRider,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDialog(Map<String, dynamic> data) {
    final orderId = data['order_id'] ?? data['id'] ?? '--';
    final order = _retailerOrders.firstWhere((o) => o['id'] == orderId, orElse: () => null) ?? data;
    _printReceiptNative(order, true);
  }

  Widget _buildReceiptSummaryRow(Map<String, dynamic> order) {
    final subTotal = double.tryParse(order['sub_total']?.toString() ?? '0') ?? 0.0;
    final tax = double.tryParse(order['tax_amount']?.toString() ?? '0') ?? 0.0;
    final delivery = double.tryParse(order['delivery_charge']?.toString() ?? '0') ?? 0.0;
    final netTotal = double.tryParse(order['net_amount']?.toString() ?? '0') ?? 0.0;
    final isPrepaid = order['payment_status'] == 'PAID';
    final isCredit = order['payment_mode'] == 'CREDIT';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SUB TOTAL', style: TextStyle(fontFamily: 'Courier')),
            Text('Rs. ${subTotal.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier')),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('GST (18%)', style: TextStyle(fontFamily: 'Courier')),
            Text('Rs. ${tax.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier')),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('DELIVERY', style: TextStyle(fontFamily: 'Courier')),
            Text('Rs. ${delivery.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier')),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('NET TOTAL', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
            Text('Rs. ${netTotal.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PAYMENT STATUS', style: TextStyle(fontFamily: 'Courier')),
            Text(
              isCredit 
                  ? 'CREDIT (DUE)' 
                  : (isPrepaid ? 'PREPAID (PAID)' : 'CASH ON DELIVERY'), 
              style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRetailerReturnsSection(ThemeData theme) {
    final returnOrders = _retailerOrders
        .where((o) => o['return_status'] != null)
        .toList();
    final pendingCount = returnOrders.where((o) => o['return_status'] == 'PENDING').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Return / Refund Requests',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$pendingCount Pending',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ],
              ),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchRetailerData),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: returnOrders.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_return_outlined,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No return requests found.',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: returnOrders.length,
                    itemBuilder: (context, index) {
                      final order = returnOrders[index];
                      final returnStatus = order['return_status'] ?? '';
                      final returnType = order['return_type'] ?? '';
                      final netAmt = double.tryParse(
                              order['net_amount']?.toString() ?? '0') ??
                          0.0;
                      final isPending = returnStatus == 'PENDING';

                      Color statusColor = Colors.orange;
                      if (returnStatus == 'RETURNED') statusColor = Colors.green;
                      if (returnStatus == 'EXCHANGED') statusColor = Colors.purple;
                      if (returnStatus == 'RETURN_ACCEPTED') statusColor = Colors.amber.shade800;
                      if (returnStatus == 'RETURN_HANDED_OVER') statusColor = Colors.indigo;
                      if (returnStatus == 'REDELIVERED') statusColor = Colors.teal;
                      if (returnStatus == 'REJECTED') statusColor = Colors.red;

                      final returnedItemsList = order['returned_items'] as List? ?? [];

                      return Card(
                        elevation: isPending ? 1 : 0.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isPending ? Colors.orange.shade300 : Colors.grey.shade200,
                            width: isPending ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: statusColor.withOpacity(0.12),
                                          radius: 20,
                                          child: Icon(
                                            returnStatus == 'PENDING'
                                                ? Icons.pending_actions_outlined
                                                : Icons.assignment_return_outlined,
                                            color: statusColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${order['customer_name']}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              Text(
                                                'Order #${order['id']} • Rs. ${netAmt.toStringAsFixed(2)} • ${order['customer_phone']}',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$returnType • $returnStatus',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (returnedItemsList.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Returned Items:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor.withOpacity(0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...returnedItemsList.map((it) {
                                        final itMap = it as Map<String, dynamic>;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '•  ${itMap['item_name']} x ${itMap['qty']}',
                                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                'Rs. ${itMap['amount'] ?? ''}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                              if (isPending) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _handleReturnRequest(order['id'], 'REJECT'),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(color: Colors.red.shade300),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _handleReturnRequest(order['id'], 'ACCEPT'),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: Text(returnType == 'REFUND'
                                          ? 'Accept & Refund'
                                          : returnType == 'EXCHANGE'
                                              ? 'Accept & Exchange'
                                              : 'Accept & Redeliver'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (returnStatus == 'RETURN_HANDED_OVER' || returnStatus == 'RETURN_ACCEPTED') ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showReceiptDialog(order),
                                      icon: const Icon(Icons.receipt_long, size: 16),
                                      label: const Text('Receipt'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.teal.shade700,
                                        side: BorderSide(color: Colors.teal.shade300),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _handleFinalReceiveReturn(order['id']),
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: const Text('Final Receive'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
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

  Widget _buildB2bRatesSection(ThemeData theme) {
    final filteredItems = _b2bSearchQuery.isEmpty
        ? _b2bItems
        : _b2bItems
            .where((i) => (i['item_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_b2bSearchQuery.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('B2B Pricing Setup',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.refresh), onPressed: _fetchB2bItems),
            ],
          ),
          const SizedBox(height: 4),
          Text('Set separate wholesale rates visible only to B2B customers (with GSTIN).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) {
              setState(() => _b2bSearchQuery = val);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _b2bLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item =
                              filteredItems[index] as Map<String, dynamic>;
                          final stdRate = double.tryParse(
                                  item['retail_sale_price']?.toString() ?? '') ??
                              double.tryParse(
                                      item['rate']?.toString() ?? '') ??
                              0.0;
                          final b2bRate = double.tryParse(
                                  item['b2b_rate']?.toString() ?? '') ??
                              0.0;
                          final hasB2bRate = b2bRate > 0;

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: hasB2bRate
                                    ? Colors.indigo.shade50
                                    : Colors.grey.shade100,
                                foregroundColor: hasB2bRate
                                    ? Colors.indigo
                                    : Colors.grey,
                                child: const Icon(Icons.inventory_2_outlined,
                                    size: 20),
                              ),
                              title: Text(
                                item['item_name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('Retail: Rs. ${stdRate.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                  if (hasB2bRate)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.indigo.shade200),
                                      ),
                                      child: Text(
                                        'B2B: Rs. ${b2bRate.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo.shade700),
                                      ),
                                    )
                                  else
                                    Text('B2B: Not set',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                            fontStyle: FontStyle.italic)),
                                ],
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () => _showB2bRateDialog(item),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                                child: Text(hasB2bRate ? 'Edit Rate' : 'Set Rate',
                                    style: const TextStyle(fontSize: 13)),
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

  // ---- Return Settings ----

  void _populateSettingsData(dynamic data) {
    _defaultReturnWindowDays =
        int.tryParse(data['default_return_window_days']?.toString() ?? '7') ?? 7;
    _minDeliveryOrderValue =
        double.tryParse(data['min_delivery_order_value']?.toString() ?? '0.0') ?? 0.0;
    _deliveryCharge =
        double.tryParse(data['delivery_charge']?.toString() ?? '0.0') ?? 0.0;
    _deliveryGstPercent =
        double.tryParse(data['delivery_gst_percent']?.toString() ?? '18.0') ?? 18.0;
    _platformFee =
        double.tryParse(data['platform_fee']?.toString() ?? '10.0') ?? 10.0;
    _platformGstPercent =
        double.tryParse(data['platform_gst_percent']?.toString() ?? '18.0') ?? 18.0;
    _otherCharges =
        double.tryParse(data['other_charges']?.toString() ?? '0.0') ?? 0.0;
    _otherChargesGstPercent =
        double.tryParse(data['other_charges_gst_percent']?.toString() ?? '18.0') ?? 18.0;
    _commissionType =
        data['commission_type']?.toString() ?? 'FLAT';
    _commissionValue =
        double.tryParse(data['commission_value']?.toString() ?? '20.0') ?? 20.0;
    _isExchangeAvailable = data['is_exchange_available'] ?? true;
    _isRefundAvailable = data['is_refund_available'] ?? true;

    _minDeliveryOrderValueCtrl.text = _minDeliveryOrderValue.toStringAsFixed(2);
    _deliveryChargeCtrl.text = _deliveryCharge.toStringAsFixed(2);
    _deliveryGstPercentCtrl.text = _deliveryGstPercent.toStringAsFixed(1);
    _platformFeeCtrl.text = _platformFee.toStringAsFixed(2);
    _platformGstPercentCtrl.text = _platformGstPercent.toStringAsFixed(1);
    _otherChargesCtrl.text = _otherCharges.toStringAsFixed(2);
    _otherChargesGstPercentCtrl.text = _otherChargesGstPercent.toStringAsFixed(1);
    _commissionValueCtrl.text = _commissionValue.toStringAsFixed(2);

    _customCharges = List<dynamic>.from(data['custom_charges'] ?? []);
    for (final ctrlMap in _customChargesControllers) {
      ctrlMap['name']?.dispose();
      ctrlMap['charge']?.dispose();
      ctrlMap['gst_percentage']?.dispose();
    }
    _customChargesControllers = _customCharges.map<Map<String, TextEditingController>>((charge) {
      return {
        'name': TextEditingController(text: charge['name']?.toString() ?? ''),
        'charge': TextEditingController(text: (double.tryParse(charge['charge']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)),
        'gst_percentage': TextEditingController(text: (double.tryParse(charge['gst_percentage']?.toString() ?? '18.0') ?? 18.0).toStringAsFixed(1)),
      };
    }).toList();

    _coupons = List<dynamic>.from(data['coupons'] ?? []);
    for (final ctrlMap in _couponsControllers) {
      ctrlMap['code']?.dispose();
      ctrlMap['discount_value']?.dispose();
      ctrlMap['min_purchase']?.dispose();
      ctrlMap['max_discount']?.dispose();
      ctrlMap['max_uses']?.dispose();
    }
    _couponsControllers = _coupons.map<Map<String, TextEditingController>>((coupon) {
      return {
        'code': TextEditingController(text: coupon['code']?.toString() ?? ''),
        'discount_value': TextEditingController(text: (double.tryParse(coupon['discount_value']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)),
        'min_purchase': TextEditingController(text: (double.tryParse(coupon['min_purchase']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)),
        'max_discount': TextEditingController(text: (double.tryParse(coupon['max_discount']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)),
        'max_uses': TextEditingController(text: (int.tryParse(coupon['max_uses']?.toString() ?? '100') ?? 100).toString()),
      };
    }).toList();
  }

  Future<void> _fetchReturnSettings() async {
    final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
    setState(() => _returnSettingsLoading = true);
    try {
      // Load delivery/return settings
      final res = await ApiClient.get('/api/delivery/retailer/return-settings?outlet_id=$outletCode');
      if (res['success'] == true) {
        setState(() {
          _populateSettingsData(res['data'] ?? {});
        });
      }
      // Load system settings to get bill_format
      final sysRes = await ApiClient.get('/api/inventory/settings');
      if (sysRes['data'] != null) {
        setState(() {
          _billFormat = sysRes['data']['bill_format']?.toString() ?? 'A4';
        });
      }
    } catch (e) {
      debugPrint('Error fetching return settings: $e');
    } finally {
      setState(() => _returnSettingsLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final days = _defaultReturnWindowDays;
      final minVal = double.tryParse(_minDeliveryOrderValueCtrl.text) ?? 0.0;
      final charge = double.tryParse(_deliveryChargeCtrl.text) ?? 0.0;
      final delGst = double.tryParse(_deliveryGstPercentCtrl.text) ?? 18.0;
      final platFee = double.tryParse(_platformFeeCtrl.text) ?? 10.0;
      final platGst = double.tryParse(_platformGstPercentCtrl.text) ?? 18.0;
      final othCharge = double.tryParse(_otherChargesCtrl.text) ?? 0.0;
      final othGst = double.tryParse(_otherChargesGstPercentCtrl.text) ?? 18.0;
      final commVal = double.tryParse(_commissionValueCtrl.text) ?? 20.0;
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');

      final res = await ApiClient.put('/api/delivery/retailer/return-settings', {
        'default_return_window_days': days,
        'min_delivery_order_value': minVal,
        'delivery_charge': charge,
        'delivery_gst_percent': delGst,
        'platform_fee': platFee,
        'platform_gst_percent': platGst,
        'other_charges': othCharge,
        'other_charges_gst_percent': othGst,
        'commission_type': _commissionType,
        'commission_value': commVal,
        'custom_charges': _customCharges,
        'coupons': _coupons,
        'is_exchange_available': _isExchangeAvailable,
        'is_refund_available': _isRefundAvailable,
        'outlet_id': outletCode,
      });
      if (res['success'] == true) {
        setState(() {
          _populateSettingsData(res['data'] ?? {});
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery & Return Settings saved successfully.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveItemReturnWindow(String itemCode, int days) async {
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.put(
          '/api/delivery/retailer/items/$itemCode/return-window',
          {
            'return_window_days': days,
            'outlet_id': outletCode,
          });
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Return window updated to $days day(s) for this item.')),
          );
        }
        _fetchB2bItems(); // refresh to show updated window
      }
    } catch (e) {
      debugPrint('Error saving item return window: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemReturnWindowDialog(Map<String, dynamic> item) {
    final current = int.tryParse(item['return_window_days']?.toString() ?? '') ??
        _defaultReturnWindowDays;
    int selected = current;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Return Window – ${item['item_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How many days after delivery can customers return this item?',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: selected > 0
                        ? () => setSt(() => selected--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.deepOrange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$selected day${selected == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: selected < 365
                        ? () => setSt(() => selected++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (selected == 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '0 days = No returns allowed for this item.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveItemReturnWindow(item['item_code'], selected);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormRow(String label, Widget field) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = MediaQuery.of(context).size.width < 650;
        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                field,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              field,
            ],
          ),
        );
      },
    );
  }

  Widget _buildReturnSettingsSection(ThemeData theme) {
    return _returnSettingsLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery & Return Settings',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Configure rider commissions, delivery charge rules, and return policies.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Return Window
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        color: Colors.deepOrange),
                                    const SizedBox(width: 8),
                                    Text('Return Window (Global)',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Applies to all items unless overridden per-item below.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: _defaultReturnWindowDays > 0
                                          ? () => setState(
                                              () => _defaultReturnWindowDays--)
                                          : null,
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            '$_defaultReturnWindowDays',
                                            style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepOrange),
                                          ),
                                          const Text('days',
                                              style: TextStyle(
                                                  color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: _defaultReturnWindowDays < 365
                                          ? () => setState(
                                              () => _defaultReturnWindowDays++)
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: [0, 1, 3, 7, 14, 30].map((d) {
                                    return ChoiceChip(
                                      label: Text('$d d'),
                                      selected: _defaultReturnWindowDays == d,
                                      onSelected: (_) =>
                                          setState(() => _defaultReturnWindowDays = d),
                                    );
                                  }).toList(),
                                ),
                                const Divider(height: 24),
                                SwitchListTile(
                                  title: const Text('Exchange Available'),
                                  subtitle: const Text('Allow customers to request exchange for returned items'),
                                  value: _isExchangeAvailable,
                                  activeColor: Colors.deepOrange,
                                  onChanged: (val) {
                                    setState(() {
                                      _isExchangeAvailable = val;
                                    });
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text('Refund Available'),
                                  subtitle: const Text('Allow customers to request refund for returned items'),
                                  value: _isRefundAvailable,
                                  activeColor: Colors.deepOrange,
                                  onChanged: (val) {
                                    setState(() {
                                      _isRefundAvailable = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Card 2: Delivery charges
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.delivery_dining_outlined,
                                        color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text('Delivery Rules',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Set minimum order value for free delivery and the charges applied below it.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                _buildFormRow('Min Order for Free Delivery', SizedBox(
                                  width: 250,
                                  child: TextField(
                                    controller: _minDeliveryOrderValueCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      prefixText: 'Rs. ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                )),
                                _buildFormRow('Delivery Charge', SizedBox(
                                  width: 250,
                                  child: TextField(
                                    controller: _deliveryChargeCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      prefixText: 'Rs. ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                )),
                                _buildFormRow('Delivery GST %', SizedBox(
                                  width: 250,
                                  child: TextField(
                                    controller: _deliveryGstPercentCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      suffixText: ' %',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),

                        // Card 3: Custom Charges
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_outlined, color: Colors.purple),
                                    const SizedBox(width: 8),
                                    Text('Custom Additional Charges', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Configure extra charges like packing fee, service charges, or handling fees with their respective GST rates.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                if (_customCharges.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text('No custom charges added yet. Click "+ Add Charge" to add one.', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                                  )
                                else
                                  Column(
                                    children: [
                                      for (int i = 0; i < _customCharges.length; i++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isMobile = MediaQuery.of(context).size.width < 650;
                                              if (isMobile) {
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      TextField(
                                                        decoration: const InputDecoration(
                                                          labelText: 'Charge Name',
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        controller: _customChargesControllers[i]['name'],
                                                        onChanged: (val) {
                                                          _customCharges[i]['name'] = val;
                                                        },
                                                      ),
                                                      const SizedBox(height: 12),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            flex: 3,
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'Charge',
                                                                prefixText: 'Rs. ',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              controller: _customChargesControllers[i]['charge'],
                                                              onChanged: (val) {
                                                                _customCharges[i]['charge'] = double.tryParse(val) ?? 0.0;
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            flex: 2,
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'GST %',
                                                                suffixText: ' %',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              controller: _customChargesControllers[i]['gst_percentage'],
                                                              onChanged: (val) {
                                                                _customCharges[i]['gst_percentage'] = double.tryParse(val) ?? 0.0;
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                            tooltip: 'Remove Charge',
                                                            onPressed: () {
                                                              setState(() {
                                                                _customCharges.removeAt(i);
                                                                _customChargesControllers.removeAt(i);
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              return Row(
                                                children: [
                                                  SizedBox(
                                                    width: 180,
                                                    child: TextField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Charge Name',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      controller: _customChargesControllers[i]['name'],
                                                      onChanged: (val) {
                                                        _customCharges[i]['name'] = val;
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 130,
                                                    child: TextField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Charge',
                                                        prefixText: 'Rs. ',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      controller: _customChargesControllers[i]['charge'],
                                                      onChanged: (val) {
                                                        _customCharges[i]['charge'] = double.tryParse(val) ?? 0.0;
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 110,
                                                    child: TextField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'GST %',
                                                        suffixText: ' %',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      controller: _customChargesControllers[i]['gst_percentage'],
                                                      onChanged: (val) {
                                                        _customCharges[i]['gst_percentage'] = double.tryParse(val) ?? 0.0;
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                    tooltip: 'Remove Charge',
                                                    onPressed: () {
                                                      setState(() {
                                                        _customCharges.removeAt(i);
                                                        _customChargesControllers.removeAt(i);
                                                      });
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Charge'),
                                  onPressed: () {
                                    setState(() {
                                      _customCharges.add({
                                        'name': '',
                                        'charge': 0.0,
                                        'gst_percentage': 18.0,
                                      });
                                      _customChargesControllers.add({
                                        'name': TextEditingController(text: ''),
                                        'charge': TextEditingController(text: '0.00'),
                                        'gst_percentage': TextEditingController(text: '18.0'),
                                      });
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Card 4: Coupons & Discount Offers
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_offer_outlined, color: Colors.teal),
                                    const SizedBox(width: 8),
                                    Text('Coupons & Offers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Manage discount codes that customers can apply in their cart. Set min purchase values, max discount limits, and max usage counts.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                if (_coupons.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text('No coupon codes added yet. Click "+ Add Coupon" to create one.', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                                  )
                                else
                                  Column(
                                    children: [
                                      for (int i = 0; i < _coupons.length; i++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isMobile = MediaQuery.of(context).size.width < 650;
                                              if (isMobile) {
                                                return Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Row 1: Code and Delete
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'Coupon Code',
                                                                hintText: 'e.g. SAVE100',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              controller: _couponsControllers[i]['code'],
                                                              onChanged: (val) {
                                                                _coupons[i]['code'] = val.toUpperCase();
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                            tooltip: 'Remove Coupon',
                                                            onPressed: () {
                                                              setState(() {
                                                                _coupons.removeAt(i);
                                                                _couponsControllers.removeAt(i);
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                      // Row 2: Type and Value
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            flex: 3,
                                                            child: DropdownButtonFormField<String>(
                                                              isExpanded: true,
                                                              value: _coupons[i]['discount_type'] ?? 'FLAT',
                                                              decoration: const InputDecoration(
                                                                labelText: 'Type',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              items: const [
                                                                DropdownMenuItem(value: 'FLAT', child: Text('Flat Rs. Off')),
                                                                DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage % Off')),
                                                              ],
                                                              onChanged: (val) {
                                                                if (val != null) {
                                                                  setState(() {
                                                                    _coupons[i]['discount_type'] = val;
                                                                  });
                                                                }
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            flex: 2,
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'Value',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              controller: _couponsControllers[i]['discount_value'],
                                                              onChanged: (val) {
                                                                _coupons[i]['discount_value'] = double.tryParse(val) ?? 0.0;
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                      // Row 3: Min Purchase and Max Discount
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'Min Purchase',
                                                                prefixText: 'Rs. ',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              controller: _couponsControllers[i]['min_purchase'],
                                                              onChanged: (val) {
                                                                _coupons[i]['min_purchase'] = double.tryParse(val) ?? 0.0;
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'Max Discount',
                                                                prefixText: 'Rs. ',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              controller: _couponsControllers[i]['max_discount'],
                                                              enabled: _coupons[i]['discount_type'] == 'PERCENTAGE',
                                                              onChanged: (val) {
                                                                _coupons[i]['max_discount'] = double.tryParse(val) ?? 0.0;
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                      // Row 4: Max Uses and Used Info
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextField(
                                                              decoration: const InputDecoration(
                                                                labelText: 'Max Uses',
                                                                isDense: true,
                                                                border: OutlineInputBorder(),
                                                              ),
                                                              keyboardType: TextInputType.number,
                                                              controller: _couponsControllers[i]['max_uses'],
                                                              onChanged: (val) {
                                                                _coupons[i]['max_uses'] = int.tryParse(val) ?? 100;
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 16),
                                                          Text(
                                                            'Used: ${_coupons[i]['used_count'] ?? 0} / ${_coupons[i]['max_uses'] ?? "∞"}',
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          const Text('Active Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                                          Switch(
                                                            value: _coupons[i]['is_active'] ?? true,
                                                            onChanged: (val) {
                                                              setState(() {
                                                                _coupons[i]['is_active'] = val;
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              return Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 150,
                                                          child: TextField(
                                                            decoration: const InputDecoration(
                                                              labelText: 'Coupon Code',
                                                              hintText: 'e.g. SAVE100',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            controller: _couponsControllers[i]['code'],
                                                            onChanged: (val) {
                                                              _coupons[i]['code'] = val.toUpperCase();
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        SizedBox(
                                                          width: 150,
                                                          child: DropdownButtonFormField<String>(
                                                            value: _coupons[i]['discount_type'] ?? 'FLAT',
                                                            decoration: const InputDecoration(
                                                              labelText: 'Type',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            items: const [
                                                              DropdownMenuItem(value: 'FLAT', child: Text('Flat Rs. Off')),
                                                              DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage % Off')),
                                                            ],
                                                            onChanged: (val) {
                                                              if (val != null) {
                                                                setState(() {
                                                                  _coupons[i]['discount_type'] = val;
                                                                });
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        SizedBox(
                                                          width: 110,
                                                          child: TextField(
                                                            decoration: const InputDecoration(
                                                              labelText: 'Value',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            controller: _couponsControllers[i]['discount_value'],
                                                            onChanged: (val) {
                                                              _coupons[i]['discount_value'] = double.tryParse(val) ?? 0.0;
                                                            },
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                          tooltip: 'Remove Coupon',
                                                          onPressed: () {
                                                            setState(() {
                                                              _coupons.removeAt(i);
                                                              _couponsControllers.removeAt(i);
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 140,
                                                          child: TextField(
                                                            decoration: const InputDecoration(
                                                              labelText: 'Min Purchase',
                                                              prefixText: 'Rs. ',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            controller: _couponsControllers[i]['min_purchase'],
                                                            onChanged: (val) {
                                                              _coupons[i]['min_purchase'] = double.tryParse(val) ?? 0.0;
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        SizedBox(
                                                          width: 140,
                                                          child: TextField(
                                                            decoration: const InputDecoration(
                                                              labelText: 'Max Discount',
                                                              prefixText: 'Rs. ',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            controller: _couponsControllers[i]['max_discount'],
                                                            enabled: _coupons[i]['discount_type'] == 'PERCENTAGE',
                                                            onChanged: (val) {
                                                              _coupons[i]['max_discount'] = double.tryParse(val) ?? 0.0;
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        SizedBox(
                                                          width: 110,
                                                          child: TextField(
                                                            decoration: const InputDecoration(
                                                              labelText: 'Max Uses',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            keyboardType: TextInputType.number,
                                                            controller: _couponsControllers[i]['max_uses'],
                                                            onChanged: (val) {
                                                              _coupons[i]['max_uses'] = int.tryParse(val) ?? 100;
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Text(
                                                          'Used: ${_coupons[i]['used_count'] ?? 0} / ${_coupons[i]['max_uses'] ?? "∞"}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        const Text('Active: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                                        Switch(
                                                          value: _coupons[i]['is_active'] ?? true,
                                                          onChanged: (val) {
                                                            setState(() {
                                                              _coupons[i]['is_active'] = val;
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Coupon'),
                                  onPressed: () {
                                    setState(() {
                                      _coupons.add({
                                        'code': '',
                                        'discount_type': 'FLAT',
                                        'discount_value': 0.0,
                                        'min_purchase': 0.0,
                                        'max_discount': 0.0,
                                        'max_uses': 100,
                                        'used_count': 0,
                                        'is_active': true,
                                      });
                                      _couponsControllers.add({
                                        'code': TextEditingController(text: ''),
                                        'discount_value': TextEditingController(text: '0.00'),
                                        'min_purchase': TextEditingController(text: '0.00'),
                                        'max_discount': TextEditingController(text: '0.00'),
                                        'max_uses': TextEditingController(text: '100'),
                                      });
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Card 5: Rider Commission
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.percent_outlined,
                                        color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text('Rider Commission Formula',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Decide how much to pay the rider per order.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                _buildFormRow(
                                  'Commission Type',
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Flat Fee'),
                                        selected: _commissionType == 'FLAT',
                                        onSelected: (selected) {
                                          if (selected) setState(() => _commissionType = 'FLAT');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('Percentage'),
                                        selected: _commissionType == 'PERCENTAGE',
                                        onSelected: (selected) {
                                          if (selected) setState(() => _commissionType = 'PERCENTAGE');
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                _buildFormRow(
                                  _commissionType == 'PERCENTAGE' ? 'Commission %' : 'Commission Flat (Rs.)',
                                  SizedBox(
                                    width: 250,
                                    child: TextField(
                                      controller: _commissionValueCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        prefixText: _commissionType == 'PERCENTAGE' ? null : 'Rs. ',
                                        suffixText: _commissionType == 'PERCENTAGE' ? '%' : null,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Save Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 250,
                            height: 44,
                            child: FilledButton.icon(
                              onPressed: _saveSettings,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save All Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Overrides Title
                        Row(
                          children: [
                            Text('Per-Item Return Overrides',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _fetchB2bItems),
                          ],
                        ),
                        const Text(
                          'Override the return window for specific items (e.g. milk = 1 day).',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),

                        // ListView of items
                        _b2bLoading
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ))
                            : _b2bItems.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Text('No items found. Refresh to load.'),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _b2bItems.length,
                                    itemBuilder: (context, i) {
                                      final item =
                                          _b2bItems[i] as Map<String, dynamic>;
                                      final window = int.tryParse(
                                              item['return_window_days']?.toString() ??
                                                  '') ??
                                          _defaultReturnWindowDays;
                                      final isOverridden =
                                          item['return_window_days'] != null &&
                                              window != _defaultReturnWindowDays;

                                      return Card(
                                        elevation: 0.5,
                                        margin: const EdgeInsets.only(bottom: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isOverridden
                                                ? Colors.deepOrange.shade50
                                                : Colors.grey.shade100,
                                            foregroundColor: isOverridden
                                                ? Colors.deepOrange
                                                : Colors.grey,
                                            child: Text(
                                              '$window',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                          ),
                                          title: Text(
                                            item['item_name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            isOverridden
                                                ? '$window day${window == 1 ? '' : 's'} (custom)'
                                                : '$window day${window == 1 ? '' : 's'} (default)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isOverridden
                                                    ? Colors.deepOrange
                                                    : Colors.grey),
                                          ),
                                          trailing: FilledButton.tonal(
                                            onPressed: () =>
                                                _showItemReturnWindowDialog(item),
                                            style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12)),
                                            child: const Text('Set Days'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        const SizedBox(height: 40),
                      ],
                    ),
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
                  'Retailer Console',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Manage customer orders & riders',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Manage Orders'),
            selected: _retailerSubTabIndex == 0,
            onTap: () {
              Navigator.of(context).pop();
              setState(() => _retailerSubTabIndex = 0);
            },
          ),
          ListTile(
            leading: Badge(
              isLabelVisible: _retailerOrders
                  .where((o) => o['return_status'] == 'PENDING')
                  .isNotEmpty,
              label: Text(_retailerOrders
                  .where((o) => o['return_status'] == 'PENDING')
                  .length
                  .toString()),
              child: const Icon(Icons.assignment_return_outlined),
            ),
            title: const Text('Returns / Refunds'),
            selected: _retailerSubTabIndex == 1,
            onTap: () {
              Navigator.of(context).pop();
              setState(() => _retailerSubTabIndex = 1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.motorcycle),
            title: const Text('Registered Riders'),
            selected: _retailerSubTabIndex == 2,
            onTap: () {
              Navigator.of(context).pop();
              setState(() => _retailerSubTabIndex = 2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('Register New Rider'),
            onTap: () {
              Navigator.of(context).pop();
              _showAddRiderDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.business_center_outlined),
            title: const Text('B2B Pricing'),
            selected: _retailerSubTabIndex == 3,
            onTap: () {
              Navigator.of(context).pop();
              setState(() => _retailerSubTabIndex = 3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Return Settings'),
            selected: _retailerSubTabIndex == 4,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _retailerSubTabIndex = 4;
                _fetchReturnSettings();
                if (_b2bItems.isEmpty) _fetchB2bItems();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ── RETAILER SESSION GATE ────────────────────────────────────
    // The retailer must be logged in to the Windows software first.
    // We reuse the same JWT session — no separate login is required.
    if (!_isLoading && _currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Retailer Console'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 44,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Login Required',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The Retailer Console uses your existing software credentials.\n\nPlease log in to the inventory software first, then return here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.login),
                          label: const Text(
                            'Go to Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // ── END RETAILER SESSION GATE ────────────────────────────────

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Retailer Console'),
            if (_currentUser != null)
              Text(
                _currentUser!.propertyName.isNotEmpty ? _currentUser!.propertyName : _currentUser!.username,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
      drawer: _buildDeliveryDrawer(context),
      body: _isLoading && _retailerOrders.isEmpty && _retailerRiders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _retailerSubTabIndex,
              children: [
                _buildRetailerOrdersSection(theme),
                _buildRetailerReturnsSection(theme),
                _buildRetailerRidersSection(theme),
                _buildB2bRatesSection(theme),
                _buildReturnSettingsSection(theme),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _retailerSubTabIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _retailerSubTabIndex = index;
            if (index == 3 && _b2bItems.isEmpty) {
              _fetchB2bItems();
            }
            if (index == 4) {
              _fetchReturnSettings();
              if (_b2bItems.isEmpty) _fetchB2bItems();
            }
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_retailerOrders
                  .where((o) => o['return_status'] == null || o['return_status'] == '')
                  .length
                  .toString()),
              isLabelVisible: _retailerOrders
                  .where((o) => o['return_status'] == null || o['return_status'] == '')
                  .isNotEmpty,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_retailerOrders
                  .where((o) => o['return_status'] == 'PENDING')
                  .length
                  .toString()),
              isLabelVisible: _retailerOrders
                  .where((o) => o['return_status'] == 'PENDING')
                  .isNotEmpty,
              child: const Icon(Icons.assignment_return_outlined),
            ),
            label: 'Returns',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_retailerRiders.length.toString()),
              isLabelVisible: _retailerRiders.isNotEmpty,
              child: const Icon(Icons.motorcycle),
            ),
            label: 'Riders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            label: 'B2B Rates',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
