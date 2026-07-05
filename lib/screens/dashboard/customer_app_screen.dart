import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_brand.dart';
import '../../core/auth/token_storage.dart';
import '../../controllers/dashboard/dashboard_controller.dart'
    as UserProfiledata;
import '../../models/security/app_user_model.dart';
import 'retailer_console_screen.dart';
import 'rider_console_screen.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/notification_services.dart';

class CustomerAppScreen extends StatefulWidget {
  const CustomerAppScreen({super.key});

  @override
  State<CustomerAppScreen> createState() => _CustomerAppScreenState();
}

class _CustomerAppScreenState extends State<CustomerAppScreen> {
  UserProfile? _currentUser;
  bool _isLoading = false;

  // --- Customer Tab State ---
  List<dynamic> _catalogItems = [];
  List<dynamic> get _groupedCatalogItems {
    final List<dynamic> representatives = [];
    final Set<int> templateIdsAdded = {};

    for (var item in _catalogItems) {
      final int? templateId = item['product_template_id'];
      if (templateId == null) {
        representatives.add(item);
      } else {
        if (!templateIdsAdded.contains(templateId)) {
          representatives.add(item);
          templateIdsAdded.add(templateId);
        }
      }
    }
    return representatives;
  }

  double _getGroupedCartQty(int? templateId, int itemId) {
    if (templateId != null) {
      double sum = 0.0;
      _cart.forEach((key, value) {
        if (value['item'] != null && value['item']['product_template_id'] == templateId) {
          sum += double.tryParse(value['qty'].toString()) ?? 0.0;
        }
      });
      return sum;
    }
    return _cart.containsKey(itemId) ? double.tryParse(_cart[itemId]!['qty'].toString()) ?? 0.0 : 0.0;
  }
  final Map<int, Map<String, dynamic>> _cart =
      {}; // item_id -> { 'item': Map, 'qty': double }
  final TextEditingController _custNameCtrl = TextEditingController();
  final TextEditingController _custPhoneCtrl = TextEditingController();
  final TextEditingController _custAddressCtrl = TextEditingController();
  String _paymentMode = 'UNPAID'; // UNPAID (CoD) or PAID (Prepaid)
  String _chosenPaymentMethod = 'CASH'; // CASH, CARD, UPI
  double _minDeliveryOrderValue = 0.0;
  double _deliveryCharge = 0.0;
  double _deliveryGstPercent = 18.0;
  double _platformFee = 10.0;
  double _platformGstPercent = 18.0;
  double _otherCharges = 0.0;
  double _otherChargesGstPercent = 18.0;
  List<dynamic> _customCharges = [];
  List<dynamic> _coupons = [];
  final TextEditingController _couponCodeCtrl = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  int? _activeOrderId;
  bool _isExchangeAvailable = true;
  bool _isRefundAvailable = true;
  bool _enablePaymentGateway = false;
  String _paymentGatewayProvider = 'SANDBOX';
  String _paymentGatewayApiKey = '';
  String _merchantUpiId = '';
  List<dynamic> _subscriptions = [];
  bool _isSubscriptionsLoading = false;
  int _historySubTabIndex = 0; // 0 for Orders, 1 for Subscriptions
  Map<String, dynamic>? _activeOrder;
  Timer? _trackingTimer;
  Timer? _notificationTimer;
  final Set<int> _shownNotificationIds = {};

  // Search, Category, and Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  String _searchQuery = '';
  String _selectedCategory = '';
  List<String> _categories = [];
  final ScrollController _scrollController = ScrollController();
  bool _isMoreLoading = false;

  // Customer Auth & History State
  Map<String, dynamic>? _loggedInCustomer;
  bool _showRegisterForm = false;
  int _customerSubTabIndex = 0; // 0 for Shop, 1 for Cart, 2 for Purchases
  List<dynamic> _historyOrders = [];
  List<dynamic> _historySales = [];

  final TextEditingController _loginPhoneCtrl = TextEditingController();
  final TextEditingController _loginPasswordCtrl = TextEditingController();
  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regPasswordCtrl = TextEditingController();
  final TextEditingController _regAddressCtrl = TextEditingController();
  final TextEditingController _custGstinCtrl = TextEditingController();
  String _gstin = '';
  String _billFormat = 'A4'; // loaded from system settings

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadUserAndData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _custAddressCtrl.dispose();
    _loginPhoneCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regAddressCtrl.dispose();
    _custGstinCtrl.dispose();
    _couponCodeCtrl.dispose();
    _stopTrackingOrder();
    _notificationTimer?.cancel();
    super.dispose();
  }

  double _getItemPrice(Map<String, dynamic> item) {
    final b2bRate = double.tryParse(item['b2b_rate']?.toString() ?? '') ?? 0.0;
    if (_gstin.isNotEmpty && b2bRate > 0) {
      return b2bRate;
    }
    return double.tryParse(item['retail_sale_price']?.toString() ?? '') ??
        double.tryParse(item['rate']?.toString() ?? '') ??
        0.0;
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _currentPage < _totalPages) {
        _loadNextPage();
      }
    }
  }

  Future<void> _loadUserAndData() async {
    setState(() => _isLoading = true);
    _currentUser = await UserProfiledata.load();

    try {
      final prefs = await SharedPreferences.getInstance();
      final customerDataStr = prefs.getString('delivery_logged_in_customer');
      if (customerDataStr != null) {
        final Map<String, dynamic> customerData = jsonDecode(customerDataStr);
        _loggedInCustomer = customerData;
        _custNameCtrl.text = customerData['name'] ?? '';
        _custPhoneCtrl.text = customerData['phone'] ?? '';
        _custAddressCtrl.text = customerData['address'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading saved customer: $e');
    }

    setState(() => _isLoading = false);
    _fetchDeliverySettings();
    _fetchCatalog();
    if (_activeOrderId != null) {
      _startTrackingOrder();
    }
    if (_loggedInCustomer != null) {
      _fetchHistory();
      _startCustomerNotificationTimer();
    }
  }

  void _startCustomerNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) return;
      final phone = _loggedInCustomer?['phone'];
      if (phone == null) return;
      try {
        final outletCode = _loggedInCustomer?['outlet_id'] ??
            _currentUser?.outletCode ??
            (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
        final res = await ApiClient.get(
            '/api/delivery/customer/notifications?customer_phone=${Uri.encodeComponent(phone)}&outlet_id=$outletCode');
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

  // ================= API CALLS =================

  Future<void> _fetchDeliverySettings() async {
    try {
      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      if (outletCode.isEmpty) return;
      final res = await ApiClient.get(
          '/api/delivery/retailer/return-settings?outlet_id=$outletCode');
      if (res['success'] == true) {
        setState(() {
          final data = res['data'] ?? {};
          _minDeliveryOrderValue = double.tryParse(
                  data['min_delivery_order_value']?.toString() ?? '0.0') ??
              0.0;
          _deliveryCharge =
              double.tryParse(data['delivery_charge']?.toString() ?? '0.0') ??
                  0.0;
          _deliveryGstPercent = double.tryParse(
                  data['delivery_gst_percent']?.toString() ?? '18.0') ??
              18.0;
          _platformFee =
              double.tryParse(data['platform_fee']?.toString() ?? '10.0') ??
                  10.0;
          _platformGstPercent = double.tryParse(
                  data['platform_gst_percent']?.toString() ?? '18.0') ??
              18.0;
          _otherCharges =
              double.tryParse(data['other_charges']?.toString() ?? '0.0') ??
                  0.0;
          _otherChargesGstPercent = double.tryParse(
                  data['other_charges_gst_percent']?.toString() ?? '18.0') ??
              18.0;
          _customCharges = List<dynamic>.from(data['custom_charges'] ?? []);
          _coupons = List<dynamic>.from(data['coupons'] ?? []);
          if (_appliedCoupon != null) {
            final exists = _coupons.any((c) =>
                c['code']?.toString().toUpperCase() ==
                    _appliedCoupon!['code']?.toString().toUpperCase() &&
                c['is_active'] != false);
            if (!exists) {
              _appliedCoupon = null;
              _couponCodeCtrl.clear();
            }
          }
          _isExchangeAvailable = data['is_exchange_available'] ?? true;
          _isRefundAvailable = data['is_refund_available'] ?? true;
          _enablePaymentGateway = data['enable_payment_gateway'] ?? false;
          _paymentGatewayProvider = data['payment_gateway_provider'] ?? 'SANDBOX';
          _paymentGatewayApiKey = data['payment_gateway_api_key'] ?? '';
          _merchantUpiId = data['merchant_upi_id'] ?? '';
        });
      }
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
        } catch (_) {
          // Safe to ignore if not authorized as admin
        }
      }
    } catch (e) {
      debugPrint('Error fetching delivery settings: $e');
    }
  }

  Future<void> _fetchCatalog() async {
    try {
      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      if (outletCode.isEmpty) return;
      _currentPage = 1;
      final query =
          'outlet_id=$outletCode&page=1&search=${Uri.encodeComponent(_searchQuery)}&category=${Uri.encodeComponent(_selectedCategory)}&limit=10&gstin=${Uri.encodeComponent(_gstin)}';
      final res = await ApiClient.get('/api/delivery/catalog?$query');
      if (res['success'] == true) {
        setState(() {
          _catalogItems = res['data'] ?? [];
          _categories = List<String>.from(res['categories'] ?? []);
          if (res['pagination'] != null) {
            _totalPages = res['pagination']['totalPages'] ?? 1;
            _currentPage = res['pagination']['currentPage'] ?? 1;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching catalog: $e');
    }
  }

  Future<void> _loadNextPage() async {
    final outletCode = _loggedInCustomer?['outlet_id'] ??
        _currentUser?.outletCode ??
        (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
    if (outletCode.isEmpty) return;
    setState(() {
      _isMoreLoading = true;
    });
    try {
      final nextPage = _currentPage + 1;
      final query =
          'outlet_id=$outletCode&page=$nextPage&search=${Uri.encodeComponent(_searchQuery)}&category=${Uri.encodeComponent(_selectedCategory)}&limit=10&gstin=${Uri.encodeComponent(_gstin)}';
      final res = await ApiClient.get('/api/delivery/catalog?$query');
      if (res['success'] == true) {
        setState(() {
          final newItems = res['data'] ?? [];
          _catalogItems.addAll(newItems);
          if (res['pagination'] != null) {
            _totalPages = res['pagination']['totalPages'] ?? 1;
            _currentPage = res['pagination']['currentPage'] ?? 1;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading next page: $e');
    } finally {
      setState(() {
        _isMoreLoading = false;
      });
    }
  }

  Future<void> _registerCustomer() async {
    if (_regNameCtrl.text.isEmpty ||
        _regPhoneCtrl.text.isEmpty ||
        _regPasswordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in Name, Phone, and Password.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'outlet_id': outletCode,
        'name': _regNameCtrl.text.trim(),
        'phone': _regPhoneCtrl.text.trim(),
        'password': _regPasswordCtrl.text.trim(),
        'address': _regAddressCtrl.text.trim(),
      };
      final res = await ApiClient.post('/api/delivery/customer/register', body);
      if (res['success'] == true) {
        final customerData = res['data'];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'delivery_logged_in_customer', jsonEncode(customerData));
        } catch (e) {
          debugPrint('Error saving registered customer data: $e');
        }
        setState(() {
          _loggedInCustomer = customerData;
          _custNameCtrl.text = _loggedInCustomer!['name'] ?? '';
          _custPhoneCtrl.text = _loggedInCustomer!['phone'] ?? '';
          _custAddressCtrl.text = _loggedInCustomer!['address'] ?? '';
          _showRegisterForm = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Registered successfully! Welcome, ${_loggedInCustomer!['name']}')),
        );
        _fetchHistory();
        _startCustomerNotificationTimer();
      }
    } catch (e) {
      debugPrint('Error registering customer: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginCustomer() async {
    if (_loginPhoneCtrl.text.isEmpty || _loginPasswordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Phone and Password.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final outletCode = _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'outlet_id': outletCode,
        'phone': _loginPhoneCtrl.text.trim(),
        'password': _loginPasswordCtrl.text.trim(),
      };
      final res = await ApiClient.post('/api/delivery/customer/login', body);
      if (res['success'] == true) {
        final customerData = res['data'];
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'delivery_logged_in_customer', jsonEncode(customerData));
        } catch (e) {
          debugPrint('Error saving logged-in customer data: $e');
        }
        setState(() {
          _loggedInCustomer = customerData;
          _custNameCtrl.text = _loggedInCustomer!['name'] ?? '';
          _custPhoneCtrl.text = _loggedInCustomer!['phone'] ?? '';
          _custAddressCtrl.text = _loggedInCustomer!['address'] ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Logged in successfully! Welcome, ${_loggedInCustomer!['name']}')),
        );
        _fetchHistory();
        _startCustomerNotificationTimer();
      }
    } catch (e) {
      debugPrint('Error logging in customer: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logoutCustomer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('delivery_logged_in_customer');
    } catch (e) {
      debugPrint('Error removing customer data on logout: $e');
    }
    setState(() {
      _loggedInCustomer = null;
      _historyOrders.clear();
      _historySales.clear();
      _custNameCtrl.clear();
      _custPhoneCtrl.clear();
      _custAddressCtrl.clear();
      _loginPhoneCtrl.clear();
      _loginPasswordCtrl.clear();
      _regNameCtrl.clear();
      _regPhoneCtrl.clear();
      _regPasswordCtrl.clear();
      _regAddressCtrl.clear();
      _customerSubTabIndex = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out successfully.')),
    );
  }

  void _setSubTabIndex(int index) {
    setState(() {
      _customerSubTabIndex = index;
    });
    if (index == 2) {
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    if (_loggedInCustomer == null) return;
    try {
      final phone = _loggedInCustomer!['phone'];
      final res =
          await ApiClient.get('/api/delivery/customer/history?phone=$phone');
      if (res['success'] == true) {
        setState(() {
          _historyOrders = res['data']['onlineOrders'] ?? [];
          _historySales = res['data']['inStoreSales'] ?? [];
        });
      }
      _fetchSubscriptions();
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
  }

  Future<void> _fetchSubscriptions() async {
    if (_loggedInCustomer == null) return;
    setState(() => _isSubscriptionsLoading = true);
    try {
      final phone = _loggedInCustomer!['phone'];
      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.get(
          '/api/sales/subscriptions/customer?customer_phone=$phone&outlet_id=$outletCode');
      if (res['success'] == true) {
        setState(() {
          _subscriptions = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscriptions: $e');
    } finally {
      setState(() => _isSubscriptionsLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _showDirectUpiQrDialog(double amount) async {
    final upiUrl = 'upi://pay?pa=$_merchantUpiId&pn=${Uri.encodeComponent(AppBrand.companyName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=DeliveryOrder';
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiUrl)}';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'UPI Direct QR Payment',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan and pay using any UPI App (GPay/PhonePe/Paytm)',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 24),
                    Text(
                      'Amount to Pay',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${amount.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Beautiful QR frame
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.network(
                        qrUrl,
                        width: 200,
                        height: 200,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade50,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off_outlined, color: Colors.red, size: 36),
                                SizedBox(height: 8),
                                Text(
                                  'QR load failed',
                                  style: TextStyle(fontSize: 11, color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'UPI ID: $_merchantUpiId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please scan the QR, complete the payment on your device, and click "I Have Paid" below.',
                              style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              // Show circular loading indicator
                              showDialog(
                                context: dialogCtx,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Verifying payment...'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              // Simulate verifying delay
                              await Future.delayed(const Duration(seconds: 2));

                              // Pop the loading spinner
                              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                              final txnId = 'upi_qr_${DateTime.now().millisecondsSinceEpoch}';
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop({
                                  'success': true,
                                  'provider': 'DIRECT_UPI_QR',
                                  'txn_id': txnId,
                                  'status': 'PAID',
                                  'amount': amount,
                                  'payment_method': 'UPI',
                                  'upi_details': 'Direct Scan QR',
                                  'paid_at': DateTime.now().toIso8601String(),
                                });
                              }
                            },
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('I Have Paid'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showPaymentGatewayDialog(double amount) async {
    String testStatus = 'SUCCESS'; // 'SUCCESS' or 'FAILURE'
    String paymentMethod = 'CARD'; // 'CARD', 'UPI'
    
    final TextEditingController cardNoCtrl = TextEditingController(text: '4111 2222 3333 4444');
    final TextEditingController cardExpiryCtrl = TextEditingController(text: '12/28');
    final TextEditingController cardCvvCtrl = TextEditingController(text: '123');
    final TextEditingController upiCtrl = TextEditingController(text: 'customer@okaxis');

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Secure Checkout',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _paymentGatewayProvider,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'SECURE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Amount to Pay',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${amount.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Payment Method',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Card'),
                            selected: paymentMethod == 'CARD',
                            onSelected: (selected) {
                              if (selected) setModalState(() => paymentMethod = 'CARD');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('UPI ID'),
                            selected: paymentMethod == 'UPI',
                            onSelected: (selected) {
                              if (selected) setModalState(() => paymentMethod = 'UPI');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (paymentMethod == 'CARD') ...[
                      TextField(
                        controller: cardNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          prefixIcon: Icon(Icons.credit_card_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cardExpiryCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Expiry (MM/YY)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: cardCvvCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: upiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          prefixIcon: Icon(Icons.qr_code_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bug_report_outlined, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Text(
                                'TEST SANDBOX MODE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('Simulate Status: ', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: testStatus,
                                underline: const SizedBox(),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                items: const [
                                  DropdownMenuItem(value: 'SUCCESS', child: Text('SUCCESS (Approve)')),
                                  DropdownMenuItem(value: 'FAILURE', child: Text('FAILURE (Decline)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => testStatus = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              // Show circular loading indicator
                              showDialog(
                                context: dialogCtx,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Processing transaction...'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              // Simulate processing delay
                              await Future.delayed(const Duration(seconds: 2));

                              // Pop the loading spinner
                              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                              if (testStatus == 'SUCCESS') {
                                final txnId = 'pay_${_paymentGatewayProvider.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
                                final cardNo = cardNoCtrl.text.trim();
                                final maskedCard = cardNo.length >= 4 
                                    ? 'Card **** ${cardNo.substring(cardNo.length - 4)}' 
                                    : 'Card';
                                final maskedUpi = upiCtrl.text.trim();
                                if (dialogCtx.mounted) {
                                  Navigator.of(dialogCtx).pop({
                                    'success': true,
                                    'provider': _paymentGatewayProvider,
                                    'txn_id': txnId,
                                    'status': 'PAID',
                                    'amount': amount,
                                    'payment_method': paymentMethod,
                                    'card_details': paymentMethod == 'CARD' ? maskedCard : null,
                                    'upi_details': paymentMethod == 'UPI' ? maskedUpi : null,
                                    'paid_at': DateTime.now().toIso8601String(),
                                  });
                                }
                              } else {
                                if (dialogCtx.mounted) {
                                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Payment Declined. Please try a different card or UPI ID.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  Navigator.of(dialogCtx).pop(null);
                                }
                              }
                            },
                            child: const Text('Pay Now'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to cart first.')),
      );
      return;
    }
    if (_custNameCtrl.text.isEmpty ||
        _custPhoneCtrl.text.isEmpty ||
        _custAddressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out customer details.')),
      );
      return;
    }

    bool hasExcessQty = false;
    _cart.forEach((itemId, value) {
      if (value['qty'] > 5.0) {
        hasExcessQty = true;
      }
    });
    if (hasExcessQty && _gstin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Maximum order quantity for any item is 5 without a GSTIN.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      double subTotal = 0;
      double tax = 0;
      double subscriptionDiscount = 0.0;
      double subscriptionTaxDiscount = 0.0;
      final List<Map<String, dynamic>> itemsList = [];

      _cart.forEach((itemId, value) {
        final item = value['item'];
        final qty = value['qty'];
        final rate = _getItemPrice(item);
        final itemTotal = rate * qty;
        subTotal += itemTotal;

        final itemTaxPercent =
            double.tryParse(item['tax_percent']?.toString() ?? '0') ?? 0.0;
        final itemTaxAmount = itemTotal * itemTaxPercent / 100.0;
        tax += itemTaxAmount;

        final sub = _subscriptions.firstWhere(
          (s) => s['item_id'] == itemId && (s['active_subscription'] == true || s['status'] == 'ACTIVE'),
          orElse: () => null,
        );
        if (sub != null) {
          final double remainingQty = double.tryParse(sub['today_remaining_qty']?.toString() ?? '0') ?? 0.0;
          final double coveredQty = qty < remainingQty ? qty : remainingQty;
          subscriptionDiscount += rate * coveredQty;
          subscriptionTaxDiscount += (rate * coveredQty) * itemTaxPercent / 100.0;
        }

        itemsList.add({
          'item_id': itemId,
          'item_code': item['item_code'],
          'item_name': item['item_name'],
          'unit': item['unit'] ?? '',
          'qty': qty,
          'rate': rate,
          'amount': itemTotal,
          'tax_percent': itemTaxPercent,
          'taxable_amount': itemTotal,
          'tax_amount': itemTaxAmount,
        });
      });

      double delivery =
          (subTotal < _minDeliveryOrderValue) ? _deliveryCharge : 0.00;
      double deliveryGst = (delivery * _deliveryGstPercent) / 100.0;

      final List<Map<String, dynamic>> chargesList = [];
      if (delivery > 0) {
        chargesList.add({
          'name': 'Delivery Charge',
          'code': 'DELIVERY_CHARGE',
          'amount': delivery,
          'taxable': _deliveryGstPercent > 0,
          'tax_percent': _deliveryGstPercent,
          'tax_amount': deliveryGst,
          'taxable_amount': delivery
        });
      }

      double customChargesTotal = 0.0;
      double customChargesGstTotal = 0.0;
      for (final charge in _customCharges) {
        final double amt =
            double.tryParse(charge['charge']?.toString() ?? '0.0') ?? 0.0;
        final double gstRate =
            double.tryParse(charge['gst_percentage']?.toString() ?? '0.0') ??
                0.0;
        final double gstAmt = (amt * gstRate) / 100.0;
        customChargesTotal += amt;
        customChargesGstTotal += gstAmt;
        if (amt > 0) {
          chargesList.add({
            'name': charge['name'] ?? 'Charge',
            'code': 'CUSTOM_CHARGE',
            'amount': amt,
            'taxable': gstRate > 0,
            'tax_percent': gstRate,
            'tax_amount': gstAmt,
            'taxable_amount': amt
          });
        }
      }

      double couponDiscount = _calculateCouponDiscount(subTotal);
      if (couponDiscount > 0 && _appliedCoupon != null) {
        chargesList.add({
          'name': 'Coupon Discount (${_appliedCoupon!['code']})',
          'code': 'COUPON_DISCOUNT',
          'amount': -couponDiscount,
          'taxable': false,
          'tax_percent': 0.0,
          'tax_amount': 0.0,
          'taxable_amount': 0.0
        });
      }

      if (subscriptionDiscount > 0) {
        chargesList.add({
          'name': 'Subscription Discount',
          'code': 'SUBSCRIPTION_DISCOUNT',
          'amount': -subscriptionDiscount,
          'taxable': false,
          'tax_percent': 0.0,
          'tax_amount': -subscriptionTaxDiscount,
          'taxable_amount': -subscriptionDiscount
        });
      }

      double totalCharges = delivery + customChargesTotal;
      double totalChargesTax = deliveryGst + customChargesGstTotal;
      double finalTax = (tax - subscriptionTaxDiscount) + totalChargesTax;
      if (finalTax < 0) finalTax = 0.0;
      double netAmount = subTotal + finalTax + totalCharges - couponDiscount - subscriptionDiscount;
      if (netAmount < 0) netAmount = 0.0;

      Map<String, dynamic>? gatewayDetails;
      if (_paymentMode == 'PAID' && _enablePaymentGateway) {
        setState(() => _isLoading = false);
        gatewayDetails = await _showPaymentGatewayDialog(netAmount);
        if (gatewayDetails == null) {
          // Cancelled or failed payment
          return;
        }
        setState(() => _isLoading = true);
      } else if (_paymentMode == 'PAID' && !_enablePaymentGateway && _merchantUpiId.isNotEmpty) {
        setState(() => _isLoading = false);
        gatewayDetails = await _showDirectUpiQrDialog(netAmount);
        if (gatewayDetails == null) {
          // Cancelled or failed payment
          return;
        }
        setState(() => _isLoading = true);
      }

      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final body = {
        'outlet_id': outletCode,
        'customer_name': _custNameCtrl.text.trim(),
        'customer_phone': _custPhoneCtrl.text.trim(),
        'customer_address': _custAddressCtrl.text.trim(),
        'items': itemsList,
        'sub_total': subTotal,
        'tax_amount': finalTax,
        'delivery_charge': totalCharges,
        'net_amount': netAmount,
        'payment_status': gatewayDetails != null ? 'PAID' : _paymentMode,
        'payment_mode': gatewayDetails != null ? gatewayDetails['payment_method'] : _chosenPaymentMethod,
        'gstin': _gstin.isEmpty ? null : _gstin,
        'charges': chargesList,
        'coupon_code': _appliedCoupon != null ? _appliedCoupon!['code'] : null,
        'payment_gateway_details': gatewayDetails,
      };

      final res = await ApiClient.post('/api/delivery/orders', body);
      if (res['success'] == true) {
        final order = res['data'];
        setState(() {
          _activeOrderId = order['id'];
          _cart.clear();
          _appliedCoupon = null;
          _couponCodeCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order #${order['id']} placed successfully!')),
        );
        _startTrackingOrder();
        _fetchHistory();
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startTrackingOrder() {
    _trackingTimer?.cancel();
    _fetchActiveOrderTracking();
    _trackingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchActiveOrderTracking();
    });
  }

  void _stopTrackingOrder() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  Future<void> _fetchActiveOrderTracking() async {
    if (_activeOrderId == null) return;
    try {
      final res =
          await ApiClient.get('/api/delivery/orders/$_activeOrderId/track');
      if (res['success'] == true) {
        setState(() {
          _activeOrder = res['data'];
        });
        if (_activeOrder?['status'] == 'DELIVERED' ||
            _activeOrder?['status'] == 'CANCELLED') {
          _stopTrackingOrder();
          _fetchHistory();
        }
      }
    } catch (e) {
      debugPrint('Error tracking order: $e');
    }
  }

  Future<void> _cancelOrderAsCustomer(dynamic orderId) async {
    String selectedReason = 'Changed my mind';
    final TextEditingController otherReasonCtrl = TextEditingController();
    bool isOther = false;

    final String? reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Cancel Order Reason'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please select a reason for cancelling this order:',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Select Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Changed my mind',
                    'Incorrect items ordered',
                    'Delivery taking too long',
                    'Found a better price',
                    'Other'
                  ]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
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
                final String finalReason =
                    isOther ? otherReasonCtrl.text.trim() : selectedReason;
                if (isOther && finalReason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please write a cancellation reason.')),
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
      }),
    );

    if (reason == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.post(
          '/api/delivery/orders/$orderId/cancel', {'reason': reason});
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
        if (_activeOrderId == orderId) {
          setState(() {
            _activeOrderId = null;
            _activeOrder = null;
          });
          _stopTrackingOrder();
        }
        _fetchHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to cancel order.')),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFeedbackDialog(dynamic orderId) async {
    double selectedRating = 5;
    final TextEditingController commentCtrl = TextEditingController();

    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Order Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate your order experience:',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    return IconButton(
                      icon: Icon(
                        starVal <= selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          selectedRating = starVal.toDouble();
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comments (Optional)',
                    hintText: 'Share your feedback with us...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Feedback is shared with the retailer for internal improvement purposes only.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        );
      }),
    );

    if (success != true) return;

    setState(() => _isLoading = true);
    try {
      final res =
          await ApiClient.post('/api/delivery/orders/$orderId/feedback', {
        'rating': selectedRating,
        'comment': commentCtrl.text.trim(),
      });
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Feedback submitted successfully. Thank you!')),
        );
        _fetchHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['message'] ?? 'Failed to submit feedback.')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateOrderSavings(dynamic order) {
    double savings = 0.0;
    final charges = order['charges'] as List?;
    if (charges != null) {
      for (var charge in charges) {
        if (charge is Map && charge['code'] == 'COUPON_DISCOUNT') {
          final amt =
              double.tryParse(charge['amount']?.toString() ?? '0') ?? 0.0;
          savings += amt.abs();
        }
      }
    }
    return savings;
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
    if (order['return_item_name'] != null &&
        order['return_item_name'].toString().isNotEmpty) {
      return '[${order['return_item_name']}]';
    }
    return '';
  }

  Future<void> _requestReturnDialog(dynamic orderId) async {
    final order = _historyOrders.firstWhere((o) => o['id'] == orderId,
        orElse: () => null);
    if (order == null) return;
    final itemsList = order['items'] as List? ?? [];
    if (itemsList.isEmpty) return;

    final Set<Map<String, dynamic>> selectedItemsSet = {};
    String returnType = _isRefundAvailable ? 'REFUND' : 'EXCHANGE';

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request Return / Exchange'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Items to Return:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...itemsList.map((it) {
                  final itemMap = it as Map<String, dynamic>;
                  final isChecked = selectedItemsSet
                      .any((x) => x['item_id'] == itemMap['item_id']);
                  final q =
                      double.tryParse(itemMap['qty']?.toString() ?? '1') ?? 1.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      border: Border.all(color: Colors.teal.shade200, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          activeColor: Colors.teal.shade700,
                          title: Text(
                            '${itemMap['item_name']} x ${q.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                              'Rate: Rs. ${itemMap['rate']} • Total: Rs. ${itemMap['amount']}'),
                          value: isChecked,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedItemsSet.add(itemMap);
                              } else {
                                selectedItemsSet.removeWhere(
                                    (x) => x['item_id'] == itemMap['item_id']);
                              }
                            });
                          },
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 16.0, bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _isRefundAvailable && _isExchangeAvailable
                                  ? 'Eligible for Refund & Exchange'
                                  : _isRefundAvailable
                                      ? 'Eligible for Refund'
                                      : 'Eligible for Exchange',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_isRefundAvailable || _isExchangeAvailable) ...[
                  const Divider(),
                  const Text('Choose Return Type:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isRefundAvailable)
                    RadioListTile<String>(
                      title: const Text('Refund'),
                      value: 'REFUND',
                      groupValue: returnType,
                      onChanged: (val) {
                        setDialogState(() {
                          returnType = val!;
                        });
                      },
                    ),
                  if (_isExchangeAvailable)
                    RadioListTile<String>(
                      title: const Text('Exchange'),
                      value: 'EXCHANGE',
                      groupValue: returnType,
                      onChanged: (val) {
                        setDialogState(() {
                          returnType = val!;
                        });
                      },
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedItemsSet.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || selectedItemsSet.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Confirm ${returnType == 'REFUND' ? 'Refund' : 'Exchange'} Request'),
        content: Text(
            'Are you sure you want to request a ${returnType.toLowerCase()} for the selected items? This request cannot be cancelled once submitted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Go Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary),
            child: const Text('Yes, Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.post('/api/delivery/orders/$orderId/return', {
        'return_type': returnType,
        'outlet_id': order['outlet_id'],
        'returned_items': selectedItemsSet
            .map((x) => {
                  'item_id': x['item_id'],
                  'item_code': x['item_code'],
                  'item_name': x['item_name'],
                  'qty': x['qty'],
                  'rate': x['rate'],
                  'amount': x['amount']
                })
            .toList(),
      });
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Return request submitted successfully.')),
        );
        _fetchHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(res['message'] ?? 'Failed to submit return request.')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting return: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

    final String status = record['status']?.toString() ?? 'COMPLETED';
    final String? returnType = record['return_type']?.toString();
    final String paymentMode = record['payment_mode']?.toString() ?? '';
    final String notes = record['notes']?.toString() ?? '';
    final exchangeAgainstBillNo = RegExp(r'against bill #(\S+)', caseSensitive: false)
        .firstMatch(notes)
        ?.group(1);
    final bool hasBillNo = (record['bill_no']?.toString() ?? record['sale_no']?.toString() ?? '').trim().isNotEmpty;
    final bool isExchange = returnType == 'EXCHANGE' ||
        paymentMode.toUpperCase() == 'EXCHANGE' ||
        notes.toLowerCase().contains('exchange order for return');
    final String saleNo = (record['sale_no']?.toString() ?? record['bill_no']?.toString() ?? '').trim().isNotEmpty
        ? (record['sale_no']?.toString() ?? record['bill_no']?.toString() ?? '').trim()
        : (record['id']?.toString() ?? '');

    double refundAmt = 0.0;
    final refund = record['refund_details'];
    if (refund != null) {
      final paid = double.tryParse(refund['amount_paid']?.toString() ?? '0.0') ?? 0.0;
      final pending = double.tryParse(refund['amount_pending']?.toString() ?? '0.0') ?? 0.0;
      refundAmt = paid > 0 ? paid : pending;
    }
    final gatewayDetails = record['payment_gateway_details'];
    if (gatewayDetails != null) {
      try {
        final dynamic details = gatewayDetails is String ? jsonDecode(gatewayDetails) : gatewayDetails;
        if (details != null && details['refund_amount'] != null) {
          refundAmt = double.tryParse(details['refund_amount'].toString()) ?? refundAmt;
        }
      } catch (_) {}
    }

    final String? returnStatus = record['return_status']?.toString();
    final String refundPaymentMode = isExchange
        ? 'EXCHANGE'
        : (record['refund_payment_mode']?.toString() ?? record['payment_mode']?.toString() ?? 'CASH');
    final DateTime? refundPaidAt = DateTime.tryParse(
      record['refund_paid_at']?.toString() ?? record['updated_at']?.toString() ?? '',
    );
    final String? mappedReturnType = isExchange ? 'EXCHANGE' : returnType;

    List<dynamic> returnedItemsList = [];
    if (record['returned_items'] != null && (record['returned_items'] as List).isNotEmpty) {
      returnedItemsList = List<dynamic>.from(record['returned_items']);
    } else if (record['return_item_id'] != null) {
      returnedItemsList = [
        {
          'item_id': record['return_item_id'],
          'item_name': record['return_item_name'] ?? '',
        }
      ];
    }

    return SaleOrder(
      saleNo: saleNo,
      returnStatus: returnStatus,
      returnType: mappedReturnType,
      refundAmount: refundAmt,
      refundPaidAt: refundPaidAt,
      refundPaymentMode: refundPaymentMode,
      exchangeAgainstBillNo: exchangeAgainstBillNo,
      hasBillNo: hasBillNo,
      returnedItems: returnedItemsList,
      saleDate: DateTime.tryParse(record['sale_date']?.toString() ?? record['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: status,
      orderType: 'B2C',
      billingCountry: 'India',
      billingTaxMode: 'CGST_SGST',
      billFormat: _billFormat,
      customerName: record['customer_name']?.toString(),
      customerPhone: record['customer_phone']?.toString(),
      customerAddress: record['customer_address']?.toString(),
      customerGstin: record['gstin']?.toString() ?? record['customer_gstin']?.toString(),
      paymentMode: isExchange ? 'EXCHANGE' : (paymentMode.isNotEmpty ? paymentMode : 'CASH'),
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

  void _showThermalReceipt(dynamic record, bool isOnlineOrder) {
    _printReceiptNative(record, isOnlineOrder);
  }

  double _calculateCouponDiscount(double subTotal) {
    if (_appliedCoupon == null) return 0.0;
    final minPurchase =
        double.tryParse(_appliedCoupon!['min_purchase']?.toString() ?? '0.0') ??
            0.0;
    if (subTotal < minPurchase) {
      return 0.0;
    }
    final discountType = _appliedCoupon!['discount_type'] ?? 'FLAT';
    final discountVal = double.tryParse(
            _appliedCoupon!['discount_value']?.toString() ?? '0.0') ??
        0.0;
    if (discountType == 'FLAT') {
      return discountVal > subTotal ? subTotal : discountVal;
    } else if (discountType == 'PERCENTAGE') {
      final discount = (subTotal * discountVal) / 100.0;
      final maxDisc = double.tryParse(
              _appliedCoupon!['max_discount']?.toString() ?? '0.0') ??
          0.0;
      if (maxDisc > 0 && discount > maxDisc) {
        return maxDisc;
      }
      return discount;
    }
    return 0.0;
  }

  Widget _buildCouponSection(ThemeData theme) {
    if (_cart.isEmpty) return const SizedBox.shrink();

    double subTotal = 0;
    _cart.forEach((itemId, value) {
      final item = value['item'];
      final qty = value['qty'];
      final price = _getItemPrice(item);
      subTotal += price * qty;
    });

    // Filter to only non-exhausted coupons visible to customer
    final availableCoupons = _coupons.where((c) {
      if (c['is_active'] == false) return false;
      final maxUses = int.tryParse(c['max_uses']?.toString() ?? '0') ?? 0;
      final usedCount = int.tryParse(c['used_count']?.toString() ?? '0') ?? 0;
      // Hide if exhausted (max_uses > 0 and used_count >= max_uses)
      if (maxUses > 0 && usedCount >= maxUses) return false;
      // Hide if no code
      if ((c['code'] ?? '').toString().trim().isEmpty) return false;
      return true;
    }).toList();

    // If a coupon is already applied, show the applied banner
    if (_appliedCoupon != null) {
      final disc = _calculateCouponDiscount(subTotal);
      final minPurchase = double.tryParse(
              _appliedCoupon!['min_purchase']?.toString() ?? '0.0') ??
          0.0;
      final isStillValid = subTotal >= minPurchase;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade300, width: 1.4),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _appliedCoupon!['code'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Applied ✓',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (isStillValid)
                      Text(
                        'You save Rs. ${disc.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 12),
                      )
                    else
                      Text(
                        'Add Rs. ${(minPurchase - subTotal).toStringAsFixed(2)} more to unlock this offer',
                        style:
                            const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _appliedCoupon = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.red, size: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No coupons available — hide section entirely
    if (availableCoupons.isEmpty) return const SizedBox.shrink();

    // Show pre-filled coupon cards (Swiggy/Zomato style)
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined,
                  size: 16, color: Colors.deepPurple),
              const SizedBox(width: 6),
              Text(
                'Available Offers',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...availableCoupons.map((coupon) {
            final code = coupon['code'].toString();
            final discountType = coupon['discount_type'] ?? 'FLAT';
            final discountVal =
                double.tryParse(coupon['discount_value']?.toString() ?? '0') ??
                    0.0;
            final minPurchase =
                double.tryParse(coupon['min_purchase']?.toString() ?? '0') ??
                    0.0;
            final maxDiscount =
                double.tryParse(coupon['max_discount']?.toString() ?? '0') ??
                    0.0;
            final maxUses =
                int.tryParse(coupon['max_uses']?.toString() ?? '0') ?? 0;
            final usedCount =
                int.tryParse(coupon['used_count']?.toString() ?? '0') ?? 0;
            final remaining = maxUses > 0 ? maxUses - usedCount : null;
            final meetsMinPurchase = subTotal >= minPurchase;

            // Build human-readable offer description
            String offerText;
            if (discountType == 'FLAT') {
              offerText = 'Rs. ${discountVal.toStringAsFixed(0)} OFF';
            } else {
              offerText = '${discountVal.toStringAsFixed(0)}% OFF';
              if (maxDiscount > 0) {
                offerText += ' (max Rs. ${maxDiscount.toStringAsFixed(0)})';
              }
            }

            String conditionText = '';
            if (minPurchase > 0) {
              conditionText =
                  'on orders above Rs. ${minPurchase.toStringAsFixed(0)}';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GestureDetector(
                onTap: () {
                  if (!meetsMinPurchase) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Add Rs. ${(minPurchase - subTotal).toStringAsFixed(2)} more to use this coupon.',
                        ),
                        backgroundColor: Colors.orange.shade700,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _appliedCoupon = coupon;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Coupon $code applied!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: meetsMinPurchase
                        ? Colors.deepPurple.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: meetsMinPurchase
                          ? Colors.deepPurple.shade200
                          : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Coupon Code Badge
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: meetsMinPurchase
                                  ? Colors.deepPurple
                                  : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          if (remaining != null && remaining <= 20)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '$remaining left',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: remaining <= 5
                                      ? Colors.red
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Offer Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offerText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: meetsMinPurchase
                                    ? Colors.deepPurple.shade800
                                    : Colors.grey.shade600,
                              ),
                            ),
                            if (conditionText.isNotEmpty)
                              Text(
                                conditionText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            if (!meetsMinPurchase && minPurchase > 0)
                              Text(
                                'Add Rs. ${(minPurchase - subTotal).toStringAsFixed(0)} more',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Apply button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: meetsMinPurchase
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'APPLY',
                          style: TextStyle(
                            color: meetsMinPurchase
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCartSummary(ThemeData theme) {
    double subTotal = 0;
    double tax = 0;
    double subscriptionDiscount = 0.0;
    double subscriptionTaxDiscount = 0.0;

    _cart.forEach((itemId, value) {
      final item = value['item'];
      final qty = value['qty'];
      final price = _getItemPrice(item);
      subTotal += price * qty;

      final itemTaxPercent =
          double.tryParse(item['tax_percent']?.toString() ?? '0') ?? 0.0;
      final itemTax = (price * qty) * itemTaxPercent / 100.0;
      tax += itemTax;

      final sub = _subscriptions.firstWhere(
        (s) => s['item_id'] == itemId && (s['active_subscription'] == true || s['status'] == 'ACTIVE'),
        orElse: () => null,
      );
      if (sub != null) {
        final double remainingQty = double.tryParse(sub['today_remaining_qty']?.toString() ?? '0') ?? 0.0;
        final double coveredQty = qty < remainingQty ? qty : remainingQty;
        subscriptionDiscount += price * coveredQty;
        subscriptionTaxDiscount += (price * coveredQty) * itemTaxPercent / 100.0;
      }
    });

    double delivery = _cart.isEmpty
        ? 0.00
        : ((subTotal < _minDeliveryOrderValue) ? _deliveryCharge : 0.00);
    double deliveryGst =
        _cart.isEmpty ? 0.00 : ((delivery * _deliveryGstPercent) / 100.0);

    double customChargesTotal = 0.0;
    double customChargesGstTotal = 0.0;
    final List<Map<String, dynamic>> computedCustomCharges = [];

    if (_cart.isNotEmpty) {
      for (final charge in _customCharges) {
        final double amt =
            double.tryParse(charge['charge']?.toString() ?? '0.0') ?? 0.0;
        final double gstRate =
            double.tryParse(charge['gst_percentage']?.toString() ?? '0.0') ??
                0.0;
        final double gstAmt = (amt * gstRate) / 100.0;
        customChargesTotal += amt;
        customChargesGstTotal += gstAmt;
        computedCustomCharges.add({
          'name': charge['name'] ?? 'Charge',
          'amount': amt,
          'gst_amount': gstAmt,
        });
      }
    }

    double couponDiscount = _calculateCouponDiscount(subTotal);

    double totalCharges = delivery + customChargesTotal;
    double totalChargesGst = deliveryGst + customChargesGstTotal;
    double finalTax = (tax - subscriptionTaxDiscount) + totalChargesGst;
    if (finalTax < 0) finalTax = 0.0;
    double netTotal = subTotal + finalTax + totalCharges - couponDiscount - subscriptionDiscount;
    if (netTotal < 0) netTotal = 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sub-total'),
            Text('Rs. ${subTotal.toStringAsFixed(2)}'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('GST / Taxes (Items)'),
            Text('Rs. ${tax.toStringAsFixed(2)}'),
          ],
        ),
        if (delivery > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Charge'),
              Text('Rs. ${delivery.toStringAsFixed(2)}'),
            ],
          ),
          if (deliveryGst > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('  • Delivery GST'),
                Text('Rs. ${deliveryGst.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
        ],
        for (final cc in computedCustomCharges) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(cc['name']),
              Text('Rs. ${cc['amount'].toStringAsFixed(2)}'),
            ],
          ),
          if (cc['gst_amount'] > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('  • ${cc['name']} GST'),
                Text('Rs. ${cc['gst_amount'].toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
        ],
        if (couponDiscount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Coupon Discount (${_appliedCoupon!['code']})',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              Text('-Rs. ${couponDiscount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        if (subscriptionDiscount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subscription Discount',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              Text('-Rs. ${subscriptionDiscount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        if (subscriptionTaxDiscount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subscription Tax Adjustment',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              Text('-Rs. ${subscriptionTaxDiscount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Net Total',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Rs. ${netTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerTrackingView(ThemeData theme) {
    if (_activeOrder == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _activeOrder!['status'] ?? 'PENDING';
    final riderName = _activeOrder!['partner']?['name'] ?? 'Not assigned yet';
    final riderPhone = _activeOrder!['partner']?['phone'] ?? '--';

    int activeStep = 0;
    if (status == 'ACCEPTED') activeStep = 1;
    if (status == 'ASSIGNED') activeStep = 2;
    if (status == 'OUT_FOR_DELIVERY') activeStep = 3;
    if (status == 'DELIVERED') activeStep = 4;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Track Order #${_activeOrder!['id']}',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _activeOrderId = null;
                            _activeOrder = null;
                          });
                          _stopTrackingOrder();
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('Customer Name: ${_activeOrder!['customer_name']}'),
                  Text(
                      'Delivery Address: ${_activeOrder!['customer_address']}'),
                  Text(
                      'Net Amount: Rs. ${double.tryParse(_activeOrder!['net_amount']?.toString() ?? '0')?.toStringAsFixed(2)}'),
                  Text('Payment Status: ${_activeOrder!['payment_status']}'),
                  const SizedBox(height: 20),
                  const Text('Live Delivery Progress',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildStepper(activeStep, theme),
                  const SizedBox(height: 24),
                  if (status == 'ASSIGNED' || status == 'OUT_FOR_DELIVERY') ...[
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned Rider: $riderName',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text('Phone: $riderPhone'),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                  if (status == 'DELIVERED') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Your order was delivered successfully!',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          )
                        ],
                      ),
                    ),
                  ],
                  if (status == 'PENDING' || status == 'ACCEPTED') ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        label: const Text('Cancel Order',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () =>
                            _cancelOrderAsCustomer(_activeOrder!['id']),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(int currentStep, ThemeData theme) {
    final steps = [
      {'title': 'Placed', 'subtitle': 'Order submitted'},
      {'title': 'Accepted', 'subtitle': 'Creating invoice'},
      {'title': 'Rider Assigned', 'subtitle': 'Rider is on the way'},
      {'title': 'Out for Delivery', 'subtitle': 'Order is on the way'},
      {'title': 'Delivered', 'subtitle': 'Enjoy your order!'},
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isDone = index <= currentStep;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      isDone ? theme.colorScheme.primary : Colors.grey.shade300,
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text((index + 1).toString(),
                          style: const TextStyle(fontSize: 12)),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: index < currentStep
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  steps[index]['title']!,
                  style: TextStyle(
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                    color: isDone ? Colors.black : Colors.grey,
                  ),
                ),
                Text(
                  steps[index]['subtitle']!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            )
          ],
        );
      }),
    );
  }

  Widget _buildCustomerAuthView(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 6,
            shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showRegisterForm
                        ? 'Create Customer Account'
                        : 'Customer Login Portal',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showRegisterForm
                        ? 'Register to track purchases, print invoices and get home delivery.'
                        : 'Sign in to access your previous orders and print invoices.',
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _regAddressCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Default Delivery Address',
                        prefixIcon: const Icon(Icons.map_outlined),
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
                        labelText: 'Registered Mobile Number',
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
                    onPressed:
                        _showRegisterForm ? _registerCustomer : _loginCustomer,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _showRegisterForm ? 'Sign Up' : 'Sign In',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showRegisterForm = !_showRegisterForm;
                      });
                    },
                    child: Text(
                      _showRegisterForm
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Sign Up",
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildDeliveryDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomer = _loggedInCustomer != null;
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Customer Portal',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  hasCustomer
                      ? 'Logged in as: ${_loggedInCustomer!['name'] ?? _loggedInCustomer!['phone']}'
                      : 'Guest Mode',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Shop Catalog'),
            selected: _customerSubTabIndex == 0,
            onTap: () {
              Navigator.of(context).pop();
              _setSubTabIndex(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('My Cart'),
            selected: _customerSubTabIndex == 1,
            onTap: () {
              Navigator.of(context).pop();
              _setSubTabIndex(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(
                hasCustomer ? 'My Purchases & Tracking' : 'Login / Register'),
            selected: _customerSubTabIndex == 2,
            onTap: () {
              Navigator.of(context).pop();
              _setSubTabIndex(2);
            },
          ),
          if (hasCustomer) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout / Switch Account'),
              onTap: () {
                Navigator.of(context).pop();
                _logoutCustomer();
              },
            ),
          ],
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

  Widget _buildProductCatalogSection(ThemeData theme, bool isMobile) {
    final int crossAxisCount = isMobile ? 1 : 2;
    final double childAspectRatio = isMobile ? 2.2 : 1.25;

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Retailer Shop Products',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Shop',
                onPressed: () {
                  setState(() {
                    _currentPage = 1;
                  });
                  _fetchCatalog();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _custGstinCtrl,
            decoration: InputDecoration(
              labelText: 'GSTIN (Optional - Enter for B2B rates & bulk orders)',
              prefixIcon: const Icon(Icons.business_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) {
              setState(() {
                _gstin = val.trim();
                if (_gstin.isEmpty) {
                  _cart.forEach((key, value) {
                    if (value['qty'] > 5.0) {
                      value['qty'] = 5.0;
                    }
                  });
                }
                _currentPage = 1;
              });
              _fetchCatalog();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                    _fetchCatalog();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      _selectedCategory.isEmpty ? null : _selectedCategory,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  hint: const Text('Categories'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All'),
                    ),
                    ..._categories.map((cat) => DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val ?? '';
                      _currentPage = 1;
                    });
                    _fetchCatalog();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _groupedCatalogItems.isEmpty
                ? const Center(child: Text('No saleable products found.'))
                : Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          controller: _scrollController,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: childAspectRatio,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _groupedCatalogItems.length,
                          itemBuilder: (context, index) {
                            final item = _groupedCatalogItems[index];
                            final price = _getItemPrice(item);

                            final int itemId = item['id'];
                            final int? templateId = item['product_template_id'];
                            final bool hasVariants = templateId != null;

                            final bool isStockable = item['stockable'] == true;
                            final double currentStock = double.tryParse(
                                    item['current_stock']?.toString() ?? '0') ??
                                0.0;
                            final bool isOutOfStock =
                                isStockable && currentStock <= 0;

                            bool isTemplateOutOfStock = false;
                            if (hasVariants) {
                              final siblings = _catalogItems.where((e) => e['product_template_id'] == templateId).toList();
                              isTemplateOutOfStock = siblings.every((sib) {
                                final bool sibStockable = sib['stockable'] == true;
                                final double sibStock = double.tryParse(sib['current_stock']?.toString() ?? '0') ?? 0.0;
                                return sibStockable && sibStock <= 0;
                              });
                            }

                            final bool isDisplayOutOfStock = hasVariants ? isTemplateOutOfStock : isOutOfStock;

                            final bool isInCart = _cart.containsKey(itemId);
                            final double cartQty =
                                isInCart ? _cart[itemId]!['qty'] : 0.0;

                            final double displayCartQty = hasVariants ? _getGroupedCartQty(templateId, itemId) : cartQty;
                            final bool isDisplayInCart = displayCartQty > 0;

                            final String brand = (item['brand'] ?? '').toString().trim();
                            final String baseName = hasVariants 
                                ? (item['item_name'] ?? 'Product').toString().split(' - ').first 
                                : (item['item_name'] ?? 'Product');
                            final String displayName = brand.isNotEmpty ? '$brand - $baseName' : baseName;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: hasVariants ? () => _showCustomerVariantSelector(item) : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDisplayOutOfStock
                                                  ? Colors.red.shade50
                                                  : Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isDisplayOutOfStock
                                                  ? 'Out of Stock'
                                                  : (hasVariants ? 'In Stock (Options Available)' : 'In Stock (${currentStock.toInt()} left)'),
                                              style: TextStyle(
                                                color: isDisplayOutOfStock
                                                    ? Colors.red.shade700
                                                    : Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            hasVariants ? 'Rs. ${price.toStringAsFixed(2)}+' : 'Rs. ${price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (isDisplayOutOfStock)
                                            const IconButton(
                                              onPressed: null,
                                              icon: Icon(Icons.add_shopping_cart,
                                                  size: 20),
                                            )
                                          else if (hasVariants)
                                            if (!isDisplayInCart)
                                              IconButton(
                                                onPressed: () => _showCustomerVariantSelector(item),
                                                style: IconButton.styleFrom(
                                                  backgroundColor: theme
                                                      .colorScheme.primaryContainer,
                                                  foregroundColor: theme.colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                                icon: const Icon(
                                                    Icons.add_shopping_cart,
                                                    size: 20),
                                              )
                                            else
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.remove_circle,
                                                        color: Colors.redAccent,
                                                        size: 22),
                                                    onPressed: () => _showCustomerVariantSelector(item),
                                                  ),
                                                  Text(
                                                    displayCartQty.toStringAsFixed(0),
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.add_circle,
                                                        color: theme.colorScheme.primary,
                                                        size: 22),
                                                    onPressed: () => _showCustomerVariantSelector(item),
                                                  ),
                                                ],
                                              )
                                          else if (!isDisplayInCart)
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _cart[itemId] = {
                                                    'item': item,
                                                    'qty': 1.0,
                                                  };
                                                });
                                              },
                                              style: IconButton.styleFrom(
                                                backgroundColor: theme
                                                    .colorScheme.primaryContainer,
                                                foregroundColor: theme.colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                              icon: const Icon(
                                                  Icons.add_shopping_cart,
                                                  size: 20),
                                            )
                                          else
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.remove_circle,
                                                      color: Colors.redAccent,
                                                      size: 22),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (displayCartQty > 1) {
                                                        _cart[itemId]!['qty'] -=
                                                            1.0;
                                                      } else {
                                                        _cart.remove(itemId);
                                                      }
                                                    });
                                                  },
                                                ),
                                                Text(
                                                  displayCartQty.toStringAsFixed(0),
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.add_circle,
                                                      color: ((_gstin.isEmpty &&
                                                                  displayCartQty >= 5) ||
                                                              (isStockable &&
                                                                  displayCartQty >=
                                                                      currentStock))
                                                          ? Colors.grey
                                                          : theme.colorScheme
                                                              .primary,
                                                      size: 22),
                                                  onPressed: ((_gstin.isEmpty &&
                                                              displayCartQty >= 5) ||
                                                          (isStockable &&
                                                              displayCartQty >=
                                                                  currentStock))
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            _cart[itemId]![
                                                                'qty'] += 1.0;
                                                          });
                                                        },
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_isMoreLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartAndCheckoutSection(ThemeData theme, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        border: isMobile
            ? null
            : Border(left: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shopping Cart',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('Your cart is empty.')),
              )
            else
              Column(
                children: _cart.entries.map((entry) {
                  final item = entry.value['item'];
                  final qty = entry.value['qty'];
                  final price = _getItemPrice(item);

                  final int itemId = entry.key;
                  final bool isStockable = item['stockable'] == true;
                  final double currentStock = double.tryParse(
                          item['current_stock']?.toString() ?? '0') ??
                      0.0;

                  final sub = _subscriptions.firstWhere(
                    (s) => s['item_id'] == itemId && (s['active_subscription'] == true || s['status'] == 'ACTIVE'),
                    orElse: () => null,
                  );
                  final double remainingQty = sub != null ? (double.tryParse(sub['today_remaining_qty']?.toString() ?? '0') ?? 0.0) : 0.0;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['item_name'] ?? 'Product'),
                        if (sub != null && remainingQty > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Subscription Covered: max ${remainingQty.toStringAsFixed(0)} daily at Rs. 0',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                        'Rs. ${price.toStringAsFixed(2)} x ${qty.toStringAsFixed(0)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              if (qty > 1) {
                                _cart[entry.key]!['qty'] -= 1.0;
                              } else {
                                _cart.remove(entry.key);
                              }
                            });
                          },
                        ),
                        Text(
                          qty.toStringAsFixed(0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: ((_gstin.isEmpty && qty >= 5) ||
                                  (isStockable && qty >= currentStock))
                              ? null
                              : () {
                                  setState(() {
                                    _cart[entry.key]!['qty'] += 1.0;
                                  });
                                },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const Divider(),
            _buildCartSummary(theme),
            _buildCouponSection(theme),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Delivery Details',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _custNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _custPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _custAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _custGstinCtrl,
              decoration: const InputDecoration(
                labelText: 'GSTIN (Optional for B2B)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              onChanged: (val) {
                setState(() {
                  _gstin = val.trim();
                  if (_gstin.isEmpty) {
                    _cart.forEach((key, value) {
                      if (value['qty'] > 5.0) {
                        value['qty'] = 5.0;
                      }
                    });
                  }
                  _currentPage = 1;
                });
                _fetchCatalog();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Payment Mode:   ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ChoiceChip(
                  label: const Text('CASH'),
                  selected: _chosenPaymentMethod == 'CASH',
                  onSelected: (selected) {
                    if (selected) setState(() => _chosenPaymentMethod = 'CASH');
                  },
                ),

                if (_enablePaymentGateway) ...[
                  ChoiceChip(
                    label: const Text('CARD'),
                    selected: _chosenPaymentMethod == 'CARD',
                    onSelected: (selected) {
                      if (selected) setState(() => _chosenPaymentMethod = 'CARD');
                    },
                  ),
                ],
                ChoiceChip(
                  label: const Text('UPI'),
                  selected: _chosenPaymentMethod == 'UPI',
                  onSelected: (selected) {
                    if (selected) setState(() => _chosenPaymentMethod = 'UPI');
                  },
                ),
                if (_enablePaymentGateway) ...[
                  ChoiceChip(
                    label: const Text('CREDIT'),
                    selected: _chosenPaymentMethod == 'CREDIT',
                    onSelected: (selected) {
                      if (selected) setState(() => _chosenPaymentMethod = 'CREDIT');
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Payment Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ChoiceChip(
                  label: const Text('Pay on Delivery'),
                  selected: _paymentMode == 'UNPAID',
                  onSelected: (selected) {
                    if (selected) setState(() => _paymentMode = 'UNPAID');
                  },
                ),
                if (_enablePaymentGateway || _merchantUpiId.isNotEmpty)
                  ChoiceChip(
                    label: const Text('Paid Online'),
                    selected: _paymentMode == 'PAID',
                    onSelected: (selected) {
                      if (selected) setState(() => _paymentMode = 'PAID');
                    },
                  ),
              ],
            ),
            if (_enablePaymentGateway)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '🔒 Payment gateway active via $_paymentGatewayProvider. Orders marked as Paid Online will proceed to secure payment.',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            else if (_merchantUpiId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '📱 Direct UPI QR active. Orders marked as Paid Online will show a QR Code for instant UPI payment.',
                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _placeOrder,
                child: const Text('Place Delivery Order',
                    style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReturnStatusBanner(dynamic order, double netAmt) {
    Color color = Colors.grey;
    IconData icon = Icons.info_outline;
    String text = '';

    final returnStatus = order['return_status'];
    final returnedItems = _formatReturnedItems(order);
    final refund = order['refund_details'];

    if (returnStatus == 'RETURNED' && refund != null) {
      color = Colors.blue;
      icon = Icons.keyboard_return_outlined;
      final paidAmt =
          double.tryParse(refund['amount_paid']?.toString() ?? '0.0') ?? 0.0;
      final pendingAmt =
          double.tryParse(refund['amount_pending']?.toString() ?? '0.0') ?? 0.0;
      final mode = refund['payment_mode'] ?? 'N/A';
      final status = refund['status'] ?? 'PENDING';
      final remarks = refund['notes'] ?? '';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refunded - $returnedItems',
                    style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text('• Mode: $mode',
                      style:
                          TextStyle(color: Colors.blue.shade800, fontSize: 12)),
                  Text('• Refund Status: $status',
                      style:
                          TextStyle(color: Colors.blue.shade800, fontSize: 12)),
                  Text(
                      '• Refunded Amount: Rs. ${paidAmt.toStringAsFixed(2)} (Pending: Rs. ${pendingAmt.toStringAsFixed(2)})',
                      style:
                          TextStyle(color: Colors.blue.shade800, fontSize: 12)),
                  if (remarks.isNotEmpty)
                    Text('• Remark: $remarks',
                        style: TextStyle(
                            color: Colors.blue.shade800, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (returnStatus == 'PENDING') {
      color = Colors.orange;
      icon = Icons.pending_actions_outlined;
      text = 'Return Pending (${order['return_type']}) - $returnedItems';
    } else if (returnStatus == 'RETURN_ACCEPTED') {
      color = Colors.orange;
      icon = Icons.check_circle_outline;
      text = order['return_type'] == 'EXCHANGE'
          ? 'Exchange Approved: Rider picking up new item from store.'
          : 'Return Approved: Rider on the way to collect item.';
    } else if (returnStatus == 'RETURN_PICKED_UP_FROM_STORE') {
      color = Colors.orange;
      icon = Icons.directions_bike;
      text = order['return_type'] == 'EXCHANGE'
          ? 'Exchange Approved: Rider out for delivery of replacement item.'
          : 'Return Approved: Rider out for collection of return item.';
    } else if (returnStatus == 'RETURN_COLLECTED') {
      if (order['return_type'] == 'EXCHANGE') {
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Exchange Completed. Replacement Delivered.';
      } else {
        color = Colors.orange;
        icon = Icons.done;
        text = 'Return Collected. Rider returning to store with item.';
      }
    } else if (returnStatus == 'RETURN_HANDED_OVER') {
      if (order['return_type'] == 'EXCHANGE') {
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Exchange Completed. Replacement Delivered.';
      } else {
        color = Colors.orange;
        icon = Icons.airport_shuttle_outlined;
        text = 'Return Handed Over to Store. Awaiting supplier confirmation.';
      }
    } else if (returnStatus == 'RETURNED') {
      color = Colors.blue;
      icon = Icons.keyboard_return_outlined;
      final isPaid = order['payment_status'] == 'PAID';
      text = isPaid
          ? 'Refunded (Rs. ${netAmt.toStringAsFixed(2)}) - $returnedItems'
          : 'Return Accepted - $returnedItems';
    } else if (returnStatus == 'EXCHANGED') {
      color = Colors.purple;
      icon = Icons.swap_horiz_outlined;
      text = 'Exchanged - $returnedItems';
    } else if (returnStatus == 'REDELIVERED') {
      color = Colors.teal;
      icon = Icons.delivery_dining_outlined;
      text = 'Redelivered - $returnedItems';
    } else if (returnStatus == 'REJECTED') {
      color = Colors.red;
      icon = Icons.gpp_bad_outlined;
      final remark = order['return_rejection_reason'] ?? '';
      text = 'Return Request Rejected - $returnedItems${remark.toString().isNotEmpty ? "\nReason: $remark" : ""}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color == Colors.orange
                    ? Colors.orange.shade900
                    : color == Colors.blue
                        ? Colors.blue.shade900
                        : color == Colors.purple
                            ? Colors.purple.shade900
                            : color == Colors.teal
                                ? Colors.teal.shade900
                                : color == Colors.red
                                    ? Colors.red.shade900
                                    : Colors.grey.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView(ThemeData theme) {
    return RefreshIndicator(
        onRefresh: () async {
          await _fetchHistory();
          await _fetchSubscriptions();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Purchase Orders')),
                      selected: _historySubTabIndex == 0,
                      onSelected: (val) {
                        if (val) setState(() => _historySubTabIndex = 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Daily Subscriptions')),
                      selected: _historySubTabIndex == 1,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _historySubTabIndex = 1);
                          _fetchSubscriptions();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _historySubTabIndex == 0
                  ? (_historyOrders.isEmpty && _historySales.isEmpty
                      ? const Center(
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                      'No purchase history found for this account.',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            _buildCustomerDashboard(theme),
                            if (_historyOrders.isNotEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Online Delivery Orders',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary),
                                ),
                              ),
                              ..._historyOrders.map((order) {
                                final netAmt = double.tryParse(
                                        order['net_amount']?.toString() ??
                                            '0') ??
                                    0.0;
                                final String status =
                                    order['status'] ?? 'PENDING';
                                final String returnStatus =
                                    order['return_status']?.toString().toUpperCase() ?? '';
                                final String refundStatus =
                                    order['refund_status']?.toString().toUpperCase() ?? '';
                                final String returnType =
                                    order['return_type']?.toString().toUpperCase() ?? '';
                                final bool isExchange = returnType == 'EXCHANGE' ||
                                    returnStatus == 'EXCHANGED' ||
                                    refundStatus == 'EXCHANGED';
                                final bool isRefunded = refundStatus == 'REFUNDED' ||
                                    returnStatus == 'RETURNED' ||
                                    returnType == 'REFUND';
                                final bool isRefundPending = refundStatus == 'PENDING';
                                final itemsList = order['items'] as List? ?? [];
                                final dateStr = order['created_at'] != null
                                    ? DateFormat('dd-MMM-yyyy, hh:mm a').format(
                                        DateTime.parse(
                                            order['created_at'].toString()))
                                    : '--';

                                Color statusColor = Colors.orange;
                                IconData statusIcon = Icons.local_shipping_outlined;
                                String displayStatus = status;
                                if (isExchange) {
                                  statusColor = Colors.purple;
                                  statusIcon = Icons.swap_horiz_outlined;
                                  displayStatus = 'EXCHANGED';
                                } else if (isRefunded) {
                                  statusColor = Colors.blue;
                                  statusIcon = Icons.currency_rupee;
                                  displayStatus = 'REFUNDED';
                                } else if (isRefundPending) {
                                  statusColor = Colors.amber.shade800;
                                  statusIcon = Icons.pending_actions_outlined;
                                  displayStatus = 'REFUND PENDING';
                                } else if (status == 'ACCEPTED') {
                                  statusColor = Colors.blue;
                                  statusIcon = Icons.check_circle_outline_rounded;
                                } else if (status == 'ASSIGNED') {
                                  statusColor = Colors.indigo;
                                  statusIcon = Icons.local_shipping_outlined;
                                } else if (status == 'OUT_FOR_DELIVERY') {
                                  statusColor = Colors.teal;
                                  statusIcon = Icons.delivery_dining_outlined;
                                } else if (status == 'DELIVERED') {
                                  statusColor = Colors.green;
                                  statusIcon = Icons.check_circle_outline_rounded;
                                } else if (status == 'CANCELLED') {
                                  statusColor = Colors.red;
                                  statusIcon = Icons.cancel_outlined;
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  statusColor.withOpacity(0.12),
                                              radius: 20,
                                              child: Icon(
                                                statusIcon,
                                                color: statusColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Order #${order['id']}',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: statusColor
                                                              .withOpacity(
                                                                  0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Text(
                                                          displayStatus,
                                                          style: TextStyle(
                                                            color: statusColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.print_outlined,
                                                  size: 20),
                                              tooltip: 'Print Invoice',
                                              onPressed: () =>
                                                  _showThermalReceipt(
                                                      order, true),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        if (order['received_items'] != null && (order['received_items'] as List).isNotEmpty) ...[
                                           Row(
                                             children: [
                                               Icon(Icons.shopping_bag_outlined,
                                                   size: 14,
                                                   color: Colors.grey.shade600),
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
                                           ...itemsList.map<Widget>((it) {
                                             final amt = double.tryParse(it['amount']?.toString() ?? '0') ?? 0.0;
                                             final q = double.tryParse(it['qty']?.toString() ?? '1') ?? 1.0;
                                             return Padding(
                                               padding: const EdgeInsets.symmetric(vertical: 4.0),
                                               child: Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       '•  ${it['item_name']} x ${q.toStringAsFixed(0)}',
                                                       style: TextStyle(
                                                           fontSize: 13,
                                                           color: Colors.grey.shade600,
                                                           decoration: TextDecoration.lineThrough),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   const SizedBox(width: 16),
                                                   Text(
                                                     'Rs. ${amt.toStringAsFixed(2)}',
                                                     style: TextStyle(
                                                         fontSize: 13,
                                                         color: Colors.grey.shade500,
                                                         decoration: TextDecoration.lineThrough),
                                                   ),
                                                 ],
                                               ),
                                             );
                                           }),
                                           const Divider(height: 24),
                                           Row(
                                             children: [
                                               Icon(Icons.check_circle_outline,
                                                   size: 14,
                                                   color: Colors.green.shade700),
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
                                           ...(order['received_items'] as List).map<Widget>((it) {
                                             final amt = double.tryParse(it['amount']?.toString() ?? '0') ?? 0.0;
                                             final q = double.tryParse(it['qty']?.toString() ?? '1') ?? 1.0;
                                             return Padding(
                                               padding: const EdgeInsets.symmetric(vertical: 4.0),
                                               child: Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       '•  ${it['item_name']} x ${q.toStringAsFixed(0)}',
                                                       style: TextStyle(
                                                           fontSize: 13,
                                                           fontWeight: FontWeight.w500,
                                                           color: Colors.grey.shade800),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   const SizedBox(width: 16),
                                                   Text(
                                                     'Rs. ${amt.toStringAsFixed(2)}',
                                                     style: TextStyle(
                                                         fontSize: 13,
                                                         fontWeight: FontWeight.bold,
                                                         color: Colors.grey.shade800),
                                                   ),
                                                 ],
                                               ),
                                             );
                                           }),
                                         ] else ...[
                                           ...itemsList.map<Widget>((it) {
                                             final amt = double.tryParse(
                                                     it['amount']?.toString() ??
                                                         '0') ??
                                                 0.0;
                                             final q = double.tryParse(
                                                     it['qty']?.toString() ??
                                                         '1') ??
                                                 1.0;
                                             return Padding(
                                               padding: const EdgeInsets.symmetric(
                                                   vertical: 4.0),
                                               child: Row(
                                                 mainAxisAlignment:
                                                     MainAxisAlignment
                                                         .spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Text(
                                                       '•  ${it['item_name']} x ${q.toStringAsFixed(0)}',
                                                       style: TextStyle(
                                                           fontSize: 13,
                                                           color: Colors
                                                               .grey.shade800),
                                                       overflow:
                                                           TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                   const SizedBox(width: 16),
                                                   Text(
                                                     'Rs. ${amt.toStringAsFixed(2)}',
                                                     style: TextStyle(
                                                         fontSize: 13,
                                                         fontWeight:
                                                             FontWeight.w500,
                                                         color:
                                                             Colors.grey.shade800),
                                                   ),
                                                 ],
                                               ),
                                             );
                                           }),
                                         ],
                                        const Divider(height: 20),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total Amount:',
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13),
                                            ),
                                            Text(
                                              'Rs. ${netAmt.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                          ],
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
                                         if (order['original_net_amount'] != null) ...[
                                            (() {
                                              final origAmt = double.tryParse(order['original_net_amount'].toString()) ?? 0.0;
                                              final diff = netAmt - origAmt;
                                              if (diff.abs() > 0.01) {
                                                final isRefund = diff < 0;
                                                final isPrepaid = order['is_prepaid'] == true || order['is_prepaid'] == 1;
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
                                                  ? (refundMethod == 'GATEWAY'
                                                      ? 'Refund processed via Online Gateway. Credited to source account in 48 hours to 3 business days.\nProcessed at $refundPaidAtStr:'
                                                      : 'Refund Paid via $refundMethod at $refundPaidAtStr:')
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
                                        if (status == 'PENDING' ||
                                            status == 'ACCEPTED' ||
                                            status == 'ASSIGNED' ||
                                            status == 'OUT_FOR_DELIVERY') ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                        (status == 'PENDING' ||
                                                                status ==
                                                                    'ACCEPTED')
                                                            ? Icons.info_outline
                                                            : Icons
                                                                .delivery_dining_outlined,
                                                        color: (status ==
                                                                    'PENDING' ||
                                                                status ==
                                                                    'ACCEPTED')
                                                            ? Colors
                                                                .orange.shade700
                                                            : Colors
                                                                .blue.shade700,
                                                        size: 16),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        (status == 'PENDING' ||
                                                                status ==
                                                                    'ACCEPTED')
                                                            ? 'Order placed. Processing...'
                                                            : 'Order shipped / out for delivery',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            color: (status ==
                                                                        'PENDING' ||
                                                                    status ==
                                                                        'ACCEPTED')
                                                                ? Colors
                                                                    .orange.shade700
                                                                : Colors
                                                                    .blue.shade700,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Wrap(
                                                spacing: 8,
                                                children: [
                                                  if (status == 'PENDING' ||
                                                      status == 'ACCEPTED')
                                                    OutlinedButton.icon(
                                                      onPressed: () =>
                                                          _cancelOrderAsCustomer(
                                                              order['id']),
                                                      icon: const Icon(
                                                          Icons.cancel_outlined,
                                                          color: Colors.red,
                                                          size: 16),
                                                      label: const Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                              color: Colors.red,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        side: const BorderSide(
                                                            color: Colors.red),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 0),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8)),
                                                      ),
                                                    ),
                                                  ElevatedButton.icon(
                                                    onPressed: () {
                                                      setState(() {
                                                        _activeOrderId =
                                                            order['id'];
                                                        _activeOrder = order;
                                                      });
                                                      _startTrackingOrder();
                                                    },
                                                    icon: const Icon(
                                                        Icons
                                                            .location_on_outlined,
                                                        size: 16),
                                                    label: const Text('Track'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: theme
                                                          .colorScheme.primary,
                                                      foregroundColor: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 0),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ] else if (status == 'CANCELLED') ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(Icons.cancel_outlined,
                                                  color: Colors.red.shade700,
                                                  size: 16),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Cancelled: ${order['cancellation_reason'] ?? 'No reason provided'}',
                                                  style: TextStyle(
                                                      color:
                                                          Colors.red.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          if (order['return_status'] !=
                                              null) ...[
                                            const SizedBox(height: 12),
                                            _buildReturnStatusBanner(
                                                order, netAmt),
                                          ] else ...[
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child:
                                                      order['return_eligible'] !=
                                                              false
                                                          ? Row(
                                                              children: [
                                                                const Icon(
                                                                    Icons
                                                                        .assignment_return_outlined,
                                                                    color: Colors
                                                                        .green,
                                                                    size: 16),
                                                                const SizedBox(
                                                                    width: 6),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Return window open (${order['return_days_remaining'] != null ? double.parse(order['return_days_remaining'].toString()).toStringAsFixed(0) : 7}d remaining)',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .green
                                                                            .shade700,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w500,
                                                                        fontSize:
                                                                            13),
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          : Row(
                                                              children: [
                                                                const Icon(
                                                                    Icons
                                                                        .lock_clock_outlined,
                                                                    color: Colors
                                                                        .red,
                                                                    size: 16),
                                                                const SizedBox(
                                                                    width: 6),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Return Window Closed (${order['return_window_days'] ?? 7}d)',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .red
                                                                            .shade600,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w500,
                                                                        fontSize:
                                                                            13),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                ),
                                                if (order['return_eligible'] !=
                                                        false &&
                                                    (_isRefundAvailable ||
                                                        _isExchangeAvailable))
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        _requestReturnDialog(
                                                            order['id']),
                                                    icon: const Icon(
                                                        Icons
                                                            .assignment_return_outlined,
                                                        size: 16),
                                                    label: const Text(
                                                        'Return / Exchange'),
                                                    style:
                                                        FilledButton.styleFrom(
                                                      backgroundColor: theme
                                                          .colorScheme
                                                          .secondary,
                                                      foregroundColor: theme
                                                          .colorScheme
                                                          .onSecondary,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                          if (order['feedback'] != null) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade50
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color:
                                                        Colors.amber.shade200),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.star,
                                                              color:
                                                                  Colors.amber,
                                                              size: 16),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'Your Feedback: ${order['feedback']['rating']}/5',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13),
                                                          ),
                                                        ],
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey.shade200,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: const Text(
                                                          'Internal Purpose Only',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color:
                                                                  Colors.grey,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (order['feedback']
                                                              ['comment'] !=
                                                          null &&
                                                      order['feedback']
                                                              ['comment']
                                                          .toString()
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '"${order['feedback']['comment']}"',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          color: Colors
                                                              .grey.shade700),
                                                    ),
                                                  ],
                                                  if (order['feedback']
                                                          ['reply'] !=
                                                      null) ...[
                                                    const Divider(height: 16),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.reply,
                                                            color: Colors.blue,
                                                            size: 14),
                                                        const SizedBox(
                                                            width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'Retailer Reply: "${order['feedback']['reply']}"',
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .blue),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ] else ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Awaiting reply from retailer...',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey.shade500,
                                                          fontStyle:
                                                              FontStyle.italic),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 8),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _submitFeedbackDialog(
                                                      order['id']),
                                              icon: const Icon(
                                                  Icons.rate_review_outlined,
                                                  size: 16),
                                              label:
                                                  const Text('Submit Feedback'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    theme.colorScheme.primary,
                                                side: BorderSide(
                                                    color: theme
                                                        .colorScheme.primary),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                            if (_historySales.isNotEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'In-Store POS Purchases',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900),
                                ),
                              ),
                              ..._historySales.map((sale) {
                                final netAmt = double.tryParse(
                                        sale['net_amount']?.toString() ??
                                            '0') ??
                                    0.0;
                                final dateStr = sale['sale_date'] != null
                                    ? DateFormat('dd-MMM-yyyy, hh:mm a').format(
                                        DateTime.parse(
                                            sale['sale_date'].toString()))
                                    : '--';
                                final itemsList = sale['items'] as List? ?? [];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  Colors.blue.shade50,
                                              radius: 20,
                                              child: Icon(
                                                  Icons.storefront_outlined,
                                                  color: Colors.blue.shade700,
                                                  size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        sale['sale_no'] ??
                                                            'Invoice',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .blue.shade50,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Text(
                                                          sale['payment_mode'] ??
                                                              'PAID',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .blue.shade700,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.print_outlined,
                                                  size: 20),
                                              tooltip: 'Print Invoice',
                                              onPressed: () =>
                                                  _showThermalReceipt(
                                                      sale, false),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Row(
                                          children: [
                                            Icon(Icons.shopping_bag_outlined,
                                                size: 14,
                                                color: Colors.grey.shade600),
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
                                        ...itemsList.map<Widget>((it) {
                                          final amt = double.tryParse(
                                                  it['amount']?.toString() ??
                                                      '0') ??
                                              0.0;
                                          final q = double.tryParse(
                                                  it['qty']?.toString() ??
                                                      '1') ??
                                              1.0;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '•  ${it['item_name']} x ${q.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey.shade800),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  'Rs. ${amt.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Colors.grey.shade800),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ))
                  : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildSubscriptionsView(theme),
                      ],
                    ),
            ),
          ],
        ));
  }

  Widget _buildCustomerDashboard(ThemeData theme) {
    double totalSpent = 0.0;
    double totalSavings = 0.0;
    int deliveredCount = 0;
    int cancelledCount = 0;
    int returnedCount = 0;
    int refundCount = 0;
    int exchangeCount = 0;

    for (var order in _historyOrders) {
      final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
      final netAmt =
          double.tryParse(order['net_amount']?.toString() ?? '0') ?? 0.0;
      final retStatus = order['return_status'];
      final retType = order['return_type']?.toString().toUpperCase();

      if (status == 'DELIVERED') {
        deliveredCount++;
        totalSpent += netAmt;
        totalSavings += _calculateOrderSavings(order);
      } else if (status == 'CANCELLED') {
        cancelledCount++;
      }

      if (retStatus != null) {
        returnedCount++;
        if (retType == 'REFUND') {
          refundCount++;
        } else if (retType == 'EXCHANGE') {
          exchangeCount++;
        }
      }
    }

    for (var sale in _historySales) {
      final netAmt =
          double.tryParse(sale['net_amount']?.toString() ?? '0') ?? 0.0;
      totalSpent += netAmt;
      final discount =
          double.tryParse(sale['discount_amount']?.toString() ?? '0') ?? 0.0;
      totalSavings += discount;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.4),
            theme.colorScheme.surface
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Purchase Summary',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary),
              ),
              Icon(Icons.analytics_outlined,
                  color: theme.colorScheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Spend',
                  'Rs. ${totalSpent.toStringAsFixed(2)}',
                  Colors.indigo.shade800,
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Total Savings',
                  'Rs. ${totalSavings.toStringAsFixed(2)}',
                  Colors.green.shade800,
                  Icons.savings_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCountBadge('Delivered', deliveredCount, Colors.green,
                    Icons.check_circle_outline),
                const SizedBox(width: 8),
                _buildCountBadge('Cancelled', cancelledCount, Colors.red,
                    Icons.cancel_outlined),
                const SizedBox(width: 8),
                _buildCountBadge('Returned', returnedCount, Colors.orange,
                    Icons.keyboard_return_outlined),
                const SizedBox(width: 8),
                _buildCountBadge('Refunded', refundCount, Colors.blue,
                    Icons.monetization_on_outlined),
                const SizedBox(width: 8),
                _buildCountBadge('Exchanged', exchangeCount, Colors.purple,
                    Icons.swap_horiz_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      color: color, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
          Text(
            '$count',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Milk & Daily Subscriptions',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
              FilledButton.icon(
                onPressed: _showSubscribeDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Subscribe'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_isSubscriptionsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_subscriptions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No subscriptions yet. Tap "Subscribe" to start one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ..._subscriptions.map((sub) {
            final String unit = sub['item']?['unit']?.toString() ?? 'Ltr';
            final double consumed = double.tryParse(
                    sub['advance_consumed_qty']?.toString() ?? '0.0') ??
                0.0;
            final double original = double.tryParse(
                    sub['advance_original_qty']?.toString() ?? '0.0') ??
                0.0;
            final double remaining = double.tryParse(
                    sub['advance_remaining_qty']?.toString() ?? '0.0') ??
                0.0;
            final double totalPaid = double.tryParse(
                    sub['advance_original_amount']?.toString() ?? '0.0') ??
                0.0;
            final double consumedAmount = double.tryParse(
                    sub['advance_consumed_amount']?.toString() ?? '0.0') ??
                0.0;
            final double progress =
                original > 0 ? (consumed / original).clamp(0.0, 1.0) : 0.0;
            final status = sub['status']?.toString() ?? 'ACTIVE';
            final isActive = sub['active_subscription'] == true;

            final startDateVal = sub['start_date'] != null
                ? DateFormat('dd-MMM-yyyy')
                    .format(DateTime.parse(sub['start_date'].toString()))
                : '--';
            final endDateVal = sub['end_date'] != null
                ? DateFormat('dd-MMM-yyyy')
                    .format(DateTime.parse(sub['end_date'].toString()))
                : '--';

            // Determine badge color by status
            Color badgeColor;
            Color badgeBg;
            if (isActive) {
              badgeColor = Colors.green.shade700;
              badgeBg = Colors.green.shade50;
            } else if (status == 'EXPIRED') {
              badgeColor = Colors.orange.shade700;
              badgeBg = Colors.orange.shade50;
            } else {
              badgeColor = Colors.grey.shade700;
              badgeBg = Colors.grey.shade100;
            }

            final canRenew = !isActive || remaining < (original * 0.2 + 0.001);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: isActive ? theme.colorScheme.primary.withOpacity(0.3) : Colors.grey.shade200),
              ),
              elevation: isActive ? 2 : 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: item name + status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sub['item_name'] ?? 'Milk Service',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Duration row
                    Row(
                      children: [
                        const Icon(Icons.date_range, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('$startDateVal → $endDateVal',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Rate + daily qty
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daily Limit: ${sub['daily_allowed_qty']} $unit',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                        Text('Rate: Rs. ${sub['advance_rate'] ?? '0.0'}/unit',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                    const Divider(height: 20),
                    // Financial summary grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _subStat('Total Paid', 'Rs. ${totalPaid.toStringAsFixed(2)}',
                                  Icons.payments_outlined, Colors.blue.shade700, theme),
                              const SizedBox(width: 8),
                              _subStat('Consumed Amt', 'Rs. ${consumedAmount.toStringAsFixed(2)}',
                                  Icons.shopping_bag_outlined, Colors.orange.shade700, theme),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _subStat('Total Qty', '${original.toStringAsFixed(1)} $unit',
                                  Icons.inventory_2_outlined, Colors.teal.shade700, theme),
                              const SizedBox(width: 8),
                              _subStat('Remaining', '${remaining.toStringAsFixed(1)} $unit',
                                  Icons.water_drop_outlined,
                                  remaining < 2 ? Colors.red.shade600 : Colors.green.shade700,
                                  theme),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Consumption',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${consumed.toStringAsFixed(1)} / ${original.toStringAsFixed(1)} $unit',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.85 ? Colors.orange : theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showSubscriptionTransactions(sub),
                          icon: const Icon(Icons.receipt_long_outlined, size: 15),
                          label: const Text('Transactions'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                            foregroundColor: Colors.teal.shade700,
                            side: BorderSide(color: Colors.teal.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (canRenew)
                          FilledButton.icon(
                            onPressed: () => _showRenewSubscriptionDialog(sub),
                            icon: const Icon(Icons.autorenew, size: 15),
                            label: const Text('Renew'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12),
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _subStat(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubscriptionTransactions(dynamic subMap) async {
    final sub = Map<String, dynamic>.from(subMap);
    final subId = sub['id'];
    if (subId == null) return;
    final phone = _loggedInCustomer?['phone'] ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading transactions...'),
          ]),
        ),
      ),
    );

    try {
      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.get(
          '/api/sales/subscriptions/$subId/ledger?customer_phone=${Uri.encodeComponent(phone)}&outlet_id=$outletCode');
      if (!mounted) return;
      Navigator.of(context).pop();
      if (res['success'] == true) {
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        final entries = (data['consumptions'] as List? ?? []);
        final summary = Map<String, dynamic>.from(data['financial_summary'] ?? {});
        _showTransactionLedgerDialog(sub, entries, summary);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to load transactions.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showTransactionLedgerDialog(Map<String, dynamic> sub, List<dynamic> entries, Map<String, dynamic> summary) {
    final theme = Theme.of(context);
    final String unit = sub['item']?['unit']?.toString() ?? 'Ltr';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transactions — ${sub['item_name'] ?? 'Subscription'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // Summary strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: theme.colorScheme.primary.withOpacity(0.06),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ledgerStat('Total Paid', 'Rs. ${(double.tryParse(summary['prepaid_value']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}', Colors.blue.shade700),
                    _ledgerStat('Consumed', '${(double.tryParse(summary['consumed_qty']?.toString() ?? '0') ?? 0.0).toStringAsFixed(1)} $unit', Colors.orange.shade700),
                    _ledgerStat('Remaining', '${(double.tryParse(sub['advance_remaining_qty']?.toString() ?? sub['today_remaining_qty']?.toString() ?? '0') ?? 0.0).toStringAsFixed(1)} $unit', Colors.green.shade700),
                  ],
                ),
              ),
              // Entries list
              Flexible(
                child: entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No delivery transactions found.', style: TextStyle(color: Colors.grey))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          final date = e['txn_date'] != null
                              ? DateFormat('dd-MMM-yy').format(DateTime.parse(e['txn_date'].toString()))
                              : '--';
                          final qty = double.tryParse(e['covered_qty']?.toString() ?? '0') ?? 0.0;
                          final amt = double.tryParse(e['covered_amount']?.toString() ?? '0') ?? 0.0;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                              child: Icon(Icons.water_drop, size: 14, color: theme.colorScheme.primary),
                            ),
                            title: Text(date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(e['item_name']?.toString() ?? 'Delivery', style: const TextStyle(fontSize: 11)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                  Text('${qty.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('Rs. ${amt.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ledgerStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Future<void> _showRenewSubscriptionDialog(dynamic subMap) async {
    final sub = Map<String, dynamic>.from(subMap);
    final String unit = sub['item']?['unit']?.toString() ?? 'Ltr';
    final rate = double.tryParse(sub['advance_rate']?.toString() ?? '0') ?? 0.0;
    final dailyQty = double.tryParse(sub['daily_allowed_qty']?.toString() ?? '1') ?? 1.0;
    int durationDays = 30;
    String paymentMode = 'UPI';
    DateTime startDate = DateTime.now();

    // Suggest start from subscription end date if it's in the future
    try {
      final endDate = sub['end_date'] != null ? DateTime.parse(sub['end_date'].toString()) : DateTime.now();
      if (endDate.isAfter(DateTime.now())) startDate = endDate.add(const Duration(days: 1));
    } catch (_) {}

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final totalQty = dailyQty * durationDays;
        final totalCost = totalQty * rate;
        final endDate = startDate.add(Duration(days: durationDays));
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.autorenew, color: Colors.green),
            SizedBox(width: 8),
            Text('Renew Subscription'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: ${sub['item_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Daily: ${dailyQty.toStringAsFixed(1)} $unit  |  Rate: Rs. ${rate.toStringAsFixed(2)}/unit',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Divider(height: 20),
                const Text('Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: durationDays,
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 Days')),
                        DropdownMenuItem(value: 30, child: Text('30 Days (Monthly)')),
                        DropdownMenuItem(value: 60, child: Text('60 Days')),
                      ],
                      onChanged: (v) { if (v != null) setSt(() => durationDays = v); },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(DateFormat('dd-MMM-yyyy').format(startDate)),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (p != null) setSt(() => startDate = p);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: ['UPI', 'CASH', 'CARD'].map((m) => ChoiceChip(
                  label: Text(m),
                  selected: paymentMode == m,
                  onSelected: (_) => setSt(() => paymentMode = m),
                )).toList()),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Qty: ${totalQty.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('End Date: ${DateFormat('dd-MMM-yyyy').format(endDate)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Total Advance: Rs. ${totalCost.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop({
                'item_id': sub['item_id'],
                'daily_allowed_qty': dailyQty,
                'duration_days': durationDays,
                'start_date': startDate.toIso8601String().split('T')[0],
                'advance_rate': rate,
                'payment_mode': paymentMode,
              }),
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              child: const Text('Renew'),
            ),
          ],
        );
      }),
    );

    if (result == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final phone = _loggedInCustomer!['phone'];
      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final res = await ApiClient.post('/api/sales/subscriptions', {
        ...result,
        'customer_phone': phone,
        'outlet_id': outletCode,
      });
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription renewed successfully! ✅'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchSubscriptions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message']?.toString() ?? 'Failed to renew.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSubscribeDialog() async {
    if (_loggedInCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please log in first to subscribe to milk services.')),
      );
      return;
    }

    if (_catalogItems.isEmpty) {
      await _fetchCatalog();
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SubscribeDialog(
        catalogItems: List<Map<String, dynamic>>.from(_catalogItems),
        customerName: _loggedInCustomer?['name']?.toString() ?? '',
        customerPhone: _loggedInCustomer?['phone']?.toString() ?? '',
        customerAddress: _loggedInCustomer?['address']?.toString() ?? '',
      ),
    );

    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      final outletCode = _loggedInCustomer?['outlet_id'] ??
          _currentUser?.outletCode ??
          (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
      final payload = {
        ...result,
        'outlet_id': outletCode,
      };
      final res = await ApiClient.post('/api/sales/subscriptions', payload);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 Subscribed to services successfully!')),
        );
        _fetchSubscriptions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(res['message'] ?? 'Failed to subscribe to service.')),
        );
      }
    } catch (e) {
      debugPrint('Error subscribing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    // ── LOGIN GATE ──────────────────────────────────────────────
    // Block all sections until customer has logged in / registered
    if (_loggedInCustomer == null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Customer Shopping App'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo / Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 44,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _showRegisterForm ? 'Create Account' : 'Welcome Back',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _showRegisterForm
                              ? 'Register to shop, track orders & get delivery'
                              : 'Sign in to access your orders & shopping cart',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Register Fields ──
                        if (_showRegisterForm) ...[
                          TextField(
                            controller: _regNameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _regPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Mobile Number',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _regPasswordCtrl,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _regAddressCtrl,
                            maxLines: 2,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Default Delivery Address',
                              prefixIcon: const Icon(Icons.map_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ]
                        // ── Login Fields ──
                        else ...[
                          TextField(
                            controller: _loginPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Registered Mobile Number',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _loginPasswordCtrl,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _loginCustomer(),
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

                        // ── Primary action button ──
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading
                                ? null
                                : (_showRegisterForm
                                    ? _registerCustomer
                                    : _loginCustomer),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(_showRegisterForm
                                    ? Icons.how_to_reg
                                    : Icons.login),
                            label: Text(
                              _showRegisterForm ? 'Create Account' : 'Sign In',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // ── Toggle login/register ──
                        TextButton(
                          onPressed: () => setState(() {
                            _showRegisterForm = !_showRegisterForm;
                          }),
                          child: Text(
                            _showRegisterForm
                                ? 'Already have an account? Sign In'
                                : "Don't have an account? Sign Up",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // ── END LOGIN GATE ──────────────────────────────────────────

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentUser?.propertyName.isNotEmpty == true
              ? _currentUser!.propertyName
              : 'Customer Shopping App',
        ),
        actions: [
          // Logged-in customer chip
          if (_loggedInCustomer != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _setSubTabIndex(2),
                  icon: const Icon(Icons.account_circle, size: 18),
                  label: Text(
                    _loggedInCustomer!['name']?.toString().split(' ').first ??
                        'Account',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: _buildDeliveryDrawer(context),
      body: _isLoading && _catalogItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : (_activeOrderId != null
              ? _buildCustomerTrackingView(theme)
              : (isMobile
                  ? IndexedStack(
                      index: _customerSubTabIndex,
                      children: [
                        _buildProductCatalogSection(theme, true),
                        _buildCartAndCheckoutSection(theme, true),
                        _buildHistoryView(theme),
                      ],
                    )
                  : IndexedStack(
                      index: _customerSubTabIndex,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildProductCatalogSection(theme, false),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildCartAndCheckoutSection(theme, false),
                            ),
                          ],
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Card(
                              margin: const EdgeInsets.all(16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: _buildCartAndCheckoutSection(theme, true),
                            ),
                          ),
                        ),
                        _buildHistoryView(theme),
                      ],
                    ))),
      bottomNavigationBar: (_activeOrderId == null)
          ? BottomNavigationBar(
              currentIndex: _customerSubTabIndex,
              onTap: _setSubTabIndex,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.storefront),
                  label: 'Shop',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    label: Text(_cart.length.toString()),
                    isLabelVisible: _cart.isNotEmpty,
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: 'Cart',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long),
                  label: 'My Orders',
                ),
              ],
            )
          : null,
      floatingActionButton:
          (isMobile && _customerSubTabIndex == 0 && _cart.isNotEmpty)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    _setSubTabIndex(1);
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('View Cart (${_cart.length})'),
                )
              : null,
    );
  }

  void _showCustomerVariantSelector(Map<String, dynamic> templateRep) {
    final int? templateId = templateRep['product_template_id'];
    if (templateId == null) return;

    final siblings = _catalogItems.where((e) => e['product_template_id'] == templateId).toList();
    if (siblings.isEmpty) return;

    // Collect all unique attribute names
    final List<String> attributeNames = siblings
        .expand((v) {
          final vals = v['attribute_values'] as List? ?? [];
          return vals.map((av) => (av['attribute'] != null ? av['attribute']['name']?.toString() : null) ?? '');
        })
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    // Collect all unique choice values for each attribute name
    final Map<String, List<String>> attributeChoices = {};
    for (var name in attributeNames) {
      final choices = siblings
          .expand((v) => v['attribute_values'] as List? ?? [])
          .where((av) => (av['attribute'] != null ? av['attribute']['name']?.toString() : null) == name)
          .map((av) => av['value']?.toString() ?? '')
          .toSet()
          .toList();
      attributeChoices[name] = choices;
    }

    // Default select first available combination if possible
    final Map<String, String> selectedOptions = {};
    if (siblings.isNotEmpty) {
      for (var name in attributeNames) {
        final vals = siblings.first['attribute_values'] as List? ?? [];
        final matches = vals.where((av) => (av['attribute'] != null ? av['attribute']['name']?.toString() : null) == name);
        if (matches.isNotEmpty) {
          selectedOptions[name] = matches.first['value']?.toString() ?? '';
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Map<String, dynamic>? matchingItem;
            bool selectionComplete = selectedOptions.length == attributeNames.length;
            if (selectionComplete) {
              for (var sibling in siblings) {
                bool isMatch = true;
                final vals = sibling['attribute_values'] as List? ?? [];
                for (var entry in selectedOptions.entries) {
                  final hasMatch = vals.any(
                    (av) => (av['attribute'] != null ? av['attribute']['name']?.toString() : null) == entry.key && av['value'] == entry.value,
                  );
                  if (!hasMatch) {
                    isMatch = false;
                    break;
                  }
                }
                if (isMatch) {
                  matchingItem = sibling;
                  break;
                }
              }
            }

            final price = matchingItem != null
                ? (double.tryParse(matchingItem['retail_sale_price']?.toString() ?? '') ?? 
                   double.tryParse(matchingItem['rate']?.toString() ?? '') ?? 0.0)
                : 0.0;
            
            final bool isStockable = matchingItem?['stockable'] == true;
            final double currentStock = double.tryParse(
                    matchingItem?['current_stock']?.toString() ?? '0') ??
                0.0;
            final bool isOutOfStock = isStockable && currentStock <= 0;

            final int? matchingItemId = matchingItem?['id'];
            final double cartQty = (matchingItemId != null && _cart.containsKey(matchingItemId))
                ? _cart[matchingItemId]!['qty']
                : 0.0;

            final String brand = (templateRep['brand'] ?? '').toString().trim();
            final templateName = (templateRep['item_name'] ?? 'Product').toString().split(' - ').first;
            final fullTitle = brand.isNotEmpty ? '$brand - $templateName' : templateName;

            return AlertDialog(
              title: Text(fullTitle),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...attributeNames.map((attrName) {
                      final choices = attributeChoices[attrName] ?? [];
                      final selectedVal = selectedOptions[attrName];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attrName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: choices.map((choice) {
                              final isSelected = selectedVal == choice;
                              return ChoiceChip(
                                label: Text(choice),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() {
                                      selectedOptions[attrName] = choice;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (matchingItem != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOutOfStock ? 'Out of Stock' : 'In Stock (${currentStock.toInt()} left)',
                                style: TextStyle(
                                  color: isOutOfStock ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (cartQty > 0)
                                Text(
                                  'In Cart: ${cartQty.toInt()}',
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                            ],
                          ),
                          Text(
                            'Rs. ${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'This combination is unavailable.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                if (matchingItem != null && !isOutOfStock)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cartQty > 0)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 24),
                          onPressed: () {
                            setDialogState(() {
                              setState(() {
                                if (cartQty > 1) {
                                  _cart[matchingItemId]!['qty'] -= 1.0;
                                } else {
                                  _cart.remove(matchingItemId);
                                }
                              });
                            });
                          },
                        ),
                      if (cartQty > 0)
                        Text(
                          cartQty.toStringAsFixed(0),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle,
                          color: ((_gstin.isEmpty && cartQty >= 5) || (isStockable && cartQty >= currentStock))
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        onPressed: ((_gstin.isEmpty && cartQty >= 5) || (isStockable && cartQty >= currentStock))
                            ? null
                            : () {
                                setDialogState(() {
                                  setState(() {
                                    if (cartQty > 0) {
                                      _cart[matchingItemId]!['qty'] += 1.0;
                                    } else {
                                      _cart[matchingItemId!] = {
                                        'item': matchingItem,
                                        'qty': 1.0,
                                      };
                                    }
                                  });
                                });
                              },
                      ),
                    ],
                  )
                else
                  const FilledButton(
                    onPressed: null,
                    child: Text('Out of Stock'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SubscribeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> catalogItems;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  const _SubscribeDialog({
    required this.catalogItems,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  @override
  State<_SubscribeDialog> createState() => _SubscribeDialogState();
}

class _SubscribeDialogState extends State<_SubscribeDialog> {
  int? _selectedItemId;
  double _dailyAllowedQty = 1.0;
  int _durationDays = 30;
  DateTime _startDate = DateTime.now();
  String _paymentMode = 'UPI';
  String _deliveryType = 'HOME';

  Map<String, dynamic>? get _selectedItem {
    if (_selectedItemId == null) return null;
    for (final item in widget.catalogItems) {
      final itemId = int.tryParse(item['id']?.toString() ?? '');
      if (itemId == _selectedItemId) return item;
    }
    return null;
  }

  double _rateFor(Map<String, dynamic>? item) {
    if (item == null) return 0.0;
    return double.tryParse(
          (item['retail_sale_price'] ?? item['rate'] ?? '0').toString(),
        ) ??
        0.0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.catalogItems.isNotEmpty) {
      _selectedItemId = int.tryParse(widget.catalogItems.first['id']?.toString() ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem;
    final rate = _rateFor(selectedItem);
    final totalQty = _dailyAllowedQty * _durationDays;
    final totalCost = totalQty * rate;
    final endDate = _startDate.add(Duration(days: _durationDays));
    final unitLabel = selectedItem?['unit']?.toString() ?? 'Ltr';
    final validItems = widget.catalogItems
        .where((item) => int.tryParse(item['id']?.toString() ?? '') != null)
        .toList();

    return AlertDialog(
      title: const Text('Subscribe to Milk/Daily Services'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Service/Product:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            widget.catalogItems.isEmpty
                ? const Text('Loading catalog...')
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedItemId,
                        items: validItems.map((item) {
                          final itemId = int.parse(item['id'].toString());
                          return DropdownMenuItem<int>(
                            value: itemId,
                            child: Text(
                              '${item['item_name']} (Rs. ${item['retail_sale_price'] ?? item['rate']}/unit)',
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedItemId = val);
                        },
                      ),
                    ),
                  ),
            Text(
              'Daily Quantity ($unitLabel):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: _dailyAllowedQty > 0.5
                      ? () => setState(() => _dailyAllowedQty -= 0.5)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  _dailyAllowedQty.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () => setState(() => _dailyAllowedQty += 0.5),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Duration:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _durationDays,
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 Days (Short Term)')),
                    DropdownMenuItem(value: 30, child: Text('30 Days (Monthly)')),
                    DropdownMenuItem(value: 60, child: Text('60 Days (2 Months)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _durationDays = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Start Date:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: Text(DateFormat('dd-MMM-yyyy').format(_startDate)),
                )
              ],
            ),
            const SizedBox(height: 12),
            const Text('Payment Mode:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _paymentMode,
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / Net Banking')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash Advance')),
                    DropdownMenuItem(value: 'CARD', child: Text('Credit/Debit Card')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMode = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Delivery Type:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _deliveryType,
                  items: const [
                    DropdownMenuItem(value: 'HOME', child: Text('Home Delivery')),
                    DropdownMenuItem(value: 'PICKUP', child: Text('Store Pickup')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _deliveryType = val);
                  },
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('End Date:', style: TextStyle(color: Colors.grey)),
                Text(DateFormat('dd-MMM-yyyy').format(endDate),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Qty:', style: TextStyle(color: Colors.grey)),
                Text(
                  '${totalQty.toStringAsFixed(1)} ${unitLabel}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Cost:', style: TextStyle(color: Colors.grey)),
                Text(
                  'Rs. ${totalCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selectedItem == null
              ? null
              : () => Navigator.pop(context, {
                    'item_id': selectedItem['id'],
                    'item_name': selectedItem['item_name'],
                    'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
                    'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                    'daily_allowed_qty': _dailyAllowedQty,
                    'total_payment_amount': totalCost,
                    'payment_mode': _paymentMode,
                    'delivery_type': _deliveryType,
                    'customer_name': widget.customerName,
                    'customer_phone': widget.customerPhone,
                    'customer_address': widget.customerAddress,
                  }),
          child: const Text('Subscribe Now'),
        ),
      ],
    );
  }
}
