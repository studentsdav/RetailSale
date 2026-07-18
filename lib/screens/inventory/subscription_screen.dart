import 'dart:typed_data';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/ui_preferences_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/sale_customer_model.dart';

class SubscriptionScreen extends StatefulWidget {
  final SaleCustomer? initialCustomer;
  final bool renewMode;

  const SubscriptionScreen({
    super.key,
    this.initialCustomer,
    this.renewMode = false,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SalesController _ctrl = SalesController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerAddress = TextEditingController();
  final _customerGstin = TextEditingController();
  final _dailyQty = TextEditingController(text: '2');
  final _totalPayment = TextEditingController(text: '0');
  final _search = TextEditingController();

  DateTime _startDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ).add(const Duration(days: 29));
  Item? _selectedItem;
  SaleCustomer? _selectedCustomer;
  bool _loading = true;
  String _statusFilter = '';
  Map<String, dynamic>? _paymentDraft;
  Map<String, dynamic>? _lastSavedSubscription;
  _SchemeDraft _schemeDraft = const _SchemeDraft();
  double _lastAutoPaymentAmount = 0;
  List<Map<String, dynamic>> _subscriptions = const [];
  String _deliveryType = 'PICKUP';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _customerAddress.dispose();
    _customerGstin.dispose();
    _dailyQty.dispose();
    _totalPayment.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Yield execution to allow build phase to finish
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final settingsCtrl = context.read<SystemSettingsController>();
      if (settingsCtrl.settings == null) {
        await settingsCtrl.load();
      }
    } catch (_) {}
    await _ctrl.loadInitialData();
    _applyInitialCustomer();
    await _reloadSubscriptions();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _applyInitialCustomer() {
    final customer = widget.initialCustomer;
    if (customer == null) return;
    _selectedCustomer = customer;
    _customerName.text = customer.customerName;
    _customerPhone.text = customer.customerPhone;
    _customerAddress.text = customer.customerAddress;
    _customerGstin.text = customer.customerGstin;
    if (widget.renewMode) {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 29));
    }
  }

  Future<void> _confirmDeleteSubscription(Map<String, dynamic> subscription) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: const Text('Are you sure you want to delete this subscription? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _ctrl.deleteSubscription(subscription['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription deleted successfully')),
        );
        _reloadSubscriptions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _reloadSubscriptions({bool reset = false}) async {
    final backendStatus = (_statusFilter == 'ACTIVE' ||
            _statusFilter == 'SETTLED' ||
            _statusFilter == 'CANCELLED')
        ? _statusFilter
        : '';
    final rows = await _ctrl.listSubscriptions(
      search: _search.text,
      status: backendStatus,
    );
    if (!mounted) return;
    setState(() => _subscriptions = rows);
  }

  void _setCustomer(SaleCustomer? customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerName.text = customer?.customerName ?? '';
      _customerPhone.text = customer?.customerPhone ?? '';
      _customerAddress.text = customer?.customerAddress ?? '';
      _customerGstin.text = customer?.customerGstin ?? '';
    });
  }

  DateTime? _parseDateOnly(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  void _applyDefaultBonusQtyFromDaily({bool onlyWhenEmpty = true}) {
    final qty = double.tryParse(_dailyQty.text.trim()) ?? 0;
    if (qty <= 0) return;
    if (_schemeDraft.type != 'BONUS_QTY') return;
    if (onlyWhenEmpty && _schemeDraft.bonusQty > 0) return;
    _applySchemeDraft(
      _schemeDraft.copyWith(
        bonusQty: qty,
        value: qty,
      ),
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _inclusiveDaysBetween(DateTime start, DateTime end) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    final raw = e.difference(s).inDays + 1;
    return raw < 1 ? 1 : raw;
  }

  double _asDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  bool _canRenewSubscription(Map<String, dynamic> subscription) {
    final endDate = _parseDateOnly(subscription['end_date']);
    if (endDate == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final renewWindowStart = endDate.subtract(const Duration(days: 7));
    return !todayOnly.isBefore(renewWindowStart);
  }

  bool _sameCustomerScope(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aPhone = (a['customer_phone'] ?? '').toString().trim();
    final bPhone = (b['customer_phone'] ?? '').toString().trim();
    if (aPhone.isNotEmpty && bPhone.isNotEmpty) return aPhone == bPhone;

    final aGstin = (a['customer_gstin'] ?? '').toString().trim().toUpperCase();
    final bGstin = (b['customer_gstin'] ?? '').toString().trim().toUpperCase();
    if (aGstin.isNotEmpty && bGstin.isNotEmpty) return aGstin == bGstin;

    final aName = (a['customer_name'] ?? '').toString().trim().toUpperCase();
    final bName = (b['customer_name'] ?? '').toString().trim().toUpperCase();
    return aName.isNotEmpty && aName == bName;
  }

  List<Map<String, dynamic>> _subscriptionChainFor(
    Map<String, dynamic> subscription,
  ) {
    final baseItemId =
        int.tryParse(subscription['item_id']?.toString() ?? '') ?? 0;
    if (baseItemId <= 0) return [subscription];
    final rows = _subscriptions.where((row) {
      final rowItemId = int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
      return rowItemId == baseItemId && _sameCustomerScope(subscription, row);
    }).toList();
    rows.sort((a, b) {
      final aStart = _parseDateOnly(a['start_date']) ?? DateTime(1900);
      final bStart = _parseDateOnly(b['start_date']) ?? DateTime(1900);
      return aStart.compareTo(bStart);
    });
    return rows.isEmpty ? [subscription] : rows;
  }

  Map<String, dynamic> _currentCycleSubscriptionForLedger(
    Map<String, dynamic> subscription,
  ) {
    final chain = _subscriptionChainFor(subscription);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeToday = chain.where((row) {
      final start = _parseDateOnly(row['start_date']);
      final end = _parseDateOnly(row['end_date']);
      if (start == null || end == null) return false;
      return !today.isBefore(start) && !today.isAfter(end);
    }).toList();
    if (activeToday.isNotEmpty) return activeToday.last;
    final started = chain.where((row) {
      final start = _parseDateOnly(row['start_date']);
      return start != null && !start.isAfter(today);
    }).toList();
    if (started.isNotEmpty) return started.last;
    return chain.last;
  }

  List<Map<String, dynamic>> _previousCyclesFor(
    Map<String, dynamic> currentCycle,
  ) {
    final chain = _subscriptionChainFor(currentCycle);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = chain.where((row) {
      final end = _parseDateOnly(row['end_date']);
      if (end == null) return false;
      return end.isBefore(today);
    }).toList();
    rows.sort((a, b) {
      final aEnd = _parseDateOnly(a['end_date']) ?? DateTime(1900);
      final bEnd = _parseDateOnly(b['end_date']) ?? DateTime(1900);
      return bEnd.compareTo(aEnd);
    });
    return rows;
  }

  List<Map<String, dynamic>> _upcomingCyclesFor(
    Map<String, dynamic> currentCycle,
  ) {
    final chain = _subscriptionChainFor(currentCycle);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = chain.where((row) {
      final rowStart = _parseDateOnly(row['start_date']);
      if (rowStart == null) return false;
      return rowStart.isAfter(today);
    }).toList();
    upcoming.sort((a, b) {
      final aStart = _parseDateOnly(a['start_date']) ?? DateTime(1900);
      final bStart = _parseDateOnly(b['start_date']) ?? DateTime(1900);
      return aStart.compareTo(bStart);
    });
    return upcoming;
  }

  bool _hasFutureRenewal(Map<String, dynamic> subscription) {
    final baseEnd = _parseDateOnly(subscription['end_date']);
    if (baseEnd == null) return false;
    final expectedStart = baseEnd.add(const Duration(days: 1));
    final chain = _subscriptionChainFor(subscription);
    return chain.any((row) {
      final rowId = int.tryParse(row['id']?.toString() ?? '') ?? 0;
      final baseId = int.tryParse(subscription['id']?.toString() ?? '') ?? 0;
      if (rowId == baseId) return false;
      final rowStart = _parseDateOnly(row['start_date']);
      if (rowStart == null) return false;
      return !rowStart.isBefore(expectedStart);
    });
  }

  bool _isUpcomingRenewal(Map<String, dynamic> subscription) {
    final endDate = _parseDateOnly(subscription['end_date']);
    if (endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysToEnd = endDate.difference(today).inDays;
    final isActive = subscription['active_subscription'] == true ||
        (subscription['status']?.toString().toUpperCase() == 'ACTIVE');
    if (!isActive) return false;
    if (_hasFutureRenewal(subscription)) return false;
    return daysToEnd >= 0 && daysToEnd <= 7;
  }

  bool _isAlreadyRenewed(Map<String, dynamic> subscription) {
    return _hasFutureRenewal(subscription);
  }

  List<Map<String, dynamic>> get _filteredSubscriptions {
    final query = _search.text.trim().toLowerCase();
    bool matchSearch(Map<String, dynamic> row) {
      if (query.isEmpty) return true;
      final hay = [
        row['customer_name'],
        row['customer_phone'],
        row['customer_gstin'],
        row['item_name'],
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }

    bool matchFilter(Map<String, dynamic> row) {
      switch (_statusFilter) {
        case 'UPCOMING_RENEWAL':
          return _isUpcomingRenewal(row);
        case 'RENEWED':
          return _isAlreadyRenewed(row);
        case 'ACTIVE':
        case 'SETTLED':
        case 'CANCELLED':
          return (row['status']?.toString().toUpperCase() ?? '') ==
              _statusFilter;
        case '':
        default:
          return true;
      }
    }

    return _subscriptions
        .where((row) => matchSearch(row) && matchFilter(row))
        .toList();
  }

  Color _statusBgColor(Map<String, dynamic> subscription) {
    if (_isUpcomingRenewal(subscription)) return const Color(0xFFFFF3CD);
    if (_isAlreadyRenewed(subscription)) return const Color(0xFFE8F5E9);
    final status = (subscription['status'] ?? '').toString().toUpperCase();
    switch (status) {
      case 'ACTIVE':
        return const Color(0xFFE3F2FD);
      case 'SETTLED':
        return const Color(0xFFE8F5E9);
      case 'CANCELLED':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFEDEFF3);
    }
  }

  Color _statusTextColor(Map<String, dynamic> subscription) {
    if (_isUpcomingRenewal(subscription)) return const Color(0xFF8A6D3B);
    if (_isAlreadyRenewed(subscription)) return const Color(0xFF1B5E20);
    final status = (subscription['status'] ?? '').toString().toUpperCase();
    switch (status) {
      case 'ACTIVE':
        return const Color(0xFF0D47A1);
      case 'SETTLED':
        return const Color(0xFF1B5E20);
      case 'CANCELLED':
        return const Color(0xFFB71C1C);
      default:
        return const Color(0xFF37474F);
    }
  }

  String _statusLabel(Map<String, dynamic> subscription) {
    if (_isUpcomingRenewal(subscription)) return 'Upcoming Renewal';
    if (_isAlreadyRenewed(subscription)) return 'Renewed';
    return (subscription['status'] ?? 'Unknown').toString();
  }

  Future<void> _showCyclePicker(
    Map<String, dynamic> currentCycle, {
    required bool showPrevious,
  }) async {
    final rows = showPrevious
        ? _previousCyclesFor(currentCycle)
        : _upcomingCyclesFor(currentCycle);
    if (rows.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(showPrevious ? 'Previous Cycles' : 'Upcoming Cycles'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              children: rows.map((row) {
                final amount = double.tryParse(
                        row['total_payment_amount']?.toString() ?? '0') ??
                    0;
                return ListTile(
                  dense: true,
                  title: Text('${row['start_date']} to ${row['end_date']}'),
                  subtitle: Text(
                    'Amount Rs. ${amount.toStringAsFixed(2)} | Status ${row['status'] ?? ''}',
                  ),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await _showLedger(row, stickToSelectedCycle: true);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _renewalHistoryForSubscription(
    Map<String, dynamic> subscription,
  ) {
    final baseId = int.tryParse(subscription['id']?.toString() ?? '') ?? 0;
    final baseItemId =
        int.tryParse(subscription['item_id']?.toString() ?? '') ?? 0;
    final baseEndDate = _parseDateOnly(subscription['end_date']);
    if (baseId <= 0 || baseItemId <= 0 || baseEndDate == null) return const [];

    final renewStart = baseEndDate.add(const Duration(days: 1));
    final rows = _subscriptions.where((row) {
      final rowId = int.tryParse(row['id']?.toString() ?? '') ?? 0;
      final rowItemId = int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
      final rowStart = _parseDateOnly(row['start_date']);
      if (rowId <= 0 || rowId == baseId) return false;
      if (rowItemId != baseItemId) return false;
      if (!_sameCustomerScope(subscription, row)) return false;
      if (rowStart == null) return false;
      return !rowStart.isBefore(renewStart);
    }).toList();

    rows.sort((a, b) {
      final aStart = _parseDateOnly(a['start_date']) ?? DateTime(1900);
      final bStart = _parseDateOnly(b['start_date']) ?? DateTime(1900);
      return aStart.compareTo(bStart);
    });
    return rows;
  }

  List<Map<String, dynamic>> _renewSchemesFromSubscription(
    Map<String, dynamic> subscription,
  ) {
    final selected = (subscription['selected_schemes'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    if (selected.isNotEmpty) {
      return selected
          .map((scheme) => {
                'scheme_type':
                    (scheme['scheme_type'] ?? scheme['type'] ?? 'CUSTOM')
                        .toString()
                        .trim(),
                'scheme_name':
                    (scheme['scheme_name'] ?? scheme['label'] ?? 'Scheme')
                        .toString()
                        .trim(),
                'scheme_value':
                    _asDouble(scheme['scheme_value'] ?? scheme['value']),
                'bonus_qty':
                    _asDouble(scheme['bonus_qty'] ?? scheme['bonusQty']),
                'discount_amount': _asDouble(
                  scheme['discount_amount'] ?? scheme['discountAmount'],
                ),
                'discount_mode':
                    (scheme['discount_mode'] ?? scheme['discountMode'] ?? '')
                        .toString()
                        .trim(),
                'notes': (scheme['notes'] ?? '').toString(),
              })
          .toList();
    }
    final bonusQty = _asDouble(subscription['bonus_qty']);
    if (bonusQty > 0) {
      return [
        {
          'scheme_type': 'BONUS_QTY',
          'scheme_name': 'Bonus Quantity',
          'scheme_value': bonusQty,
          'bonus_qty': bonusQty,
          'discount_amount': 0,
          'notes': 'Auto copied from previous subscription',
        }
      ];
    }
    return const [];
  }

  Future<void> _renewSubscription(Map<String, dynamic> subscription) async {
    final endDate = _parseDateOnly(subscription['end_date']);
    if (endDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid end date in subscription.')),
      );
      return;
    }
    final itemId = int.tryParse(subscription['item_id']?.toString() ?? '') ?? 0;
    if (itemId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item is missing for renewal.')),
      );
      return;
    }

    final nextStart = endDate.add(const Duration(days: 1));
    final nextEnd = nextStart.add(const Duration(days: 29));
    final dailyQty = _asDouble(subscription['daily_allowed_qty']);
    final item = _ctrl.items.cast<Item?>().firstWhere(
          (entry) => entry?.id == itemId,
          orElse: () => null,
        );
    final currentRate = item == null
        ? 0
        : (item.retailSalePrice > 0 ? item.retailSalePrice : item.rate);
    final renewalSchemes = _renewSchemesFromSubscription(subscription);
    final renewDiscount = renewalSchemes.fold<double>(0, (sum, row) {
      final schemeType =
          (row['scheme_type'] ?? '').toString().trim().toUpperCase();
      if (schemeType != 'PRICE_DISCOUNT') return sum;
      return sum + (_asDouble(row['discount_amount']));
    });
    final effectiveRenewEnd = nextEnd;
    const payableRenewalDays = 30;
    final taxableAmount = ((currentRate * dailyQty * payableRenewalDays) -
            renewDiscount)
        .clamp(0, double.infinity)
        .toDouble();
    final taxPercent = item?.taxPercent ?? 0;
    final taxAmount = (taxableAmount * taxPercent / 100)
        .clamp(0, double.infinity)
        .toDouble();
    final totalPayment = (taxableAmount + taxAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final paymentDraft = await _showPaymentDialog(expectedAmount: totalPayment);
    if (paymentDraft == null) return;

    final paymentLines = (paymentDraft['lines'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final paymentNotes = paymentDraft['notes']?.toString().trim() ?? '';
    final paidAmount = paymentLines.fold<double>(
      0,
      (sum, entry) =>
          sum + (double.tryParse(entry['amount']?.toString() ?? '0') ?? 0),
    );
    final firstMode = paymentLines.isNotEmpty
        ? (paymentLines.first['method']?.toString() ?? 'SUBSCRIPTION')
        : 'SUBSCRIPTION';

    final payload = <String, dynamic>{
      'customer_name': (subscription['customer_name'] ?? '').toString().trim(),
      'customer_phone':
          (subscription['customer_phone'] ?? '').toString().trim(),
      'customer_address':
          (subscription['customer_address'] ?? '').toString().trim(),
      'customer_gstin':
          (subscription['customer_gstin'] ?? '').toString().trim(),
      'item_id': itemId,
      'start_date': nextStart.toIso8601String(),
      'end_date': effectiveRenewEnd.toIso8601String(),
      'daily_allowed_qty': _asDouble(subscription['daily_allowed_qty']),
      'total_payment_amount': totalPayment,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'tax_percent': taxPercent,
      'item_rate': currentRate,
      'payment_mode': firstMode,
      'bonus_qty': 0,
      'selected_schemes': renewalSchemes,
      'delivery_type': (subscription['delivery_type'] ?? 'PICKUP').toString(),
    };

    final saved = await _ctrl.createSubscription(payload);
    await _reloadSubscriptions();
    if (!mounted) return;

    final receiptData = <String, dynamic>{
      ...saved,
      'payment_lines': paymentLines,
      'payment_notes': paymentNotes,
      'paid_amount': paidAmount,
      'remaining_amount': (totalPayment - paidAmount).clamp(0, double.infinity),
      'receipt_date': DateTime.now().toIso8601String(),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Renewed: ${DateFormat('dd-MMM-yyyy').format(nextStart)} to ${DateFormat('dd-MMM-yyyy').format(nextEnd)}',
        ),
      ),
    );
    await _showReceiptActions(receiptData);
  }

  int get _subscriptionDays {
    return _inclusiveDaysBetween(_startDate, _endDate);
  }

  int get _payableSubscriptionDays {
    final payable = _hasBonusExtension ? (_subscriptionDays - 1) : _subscriptionDays;
    return payable < 0 ? 0 : payable;
  }

  double get _itemRate {
    final item = _selectedItem;
    if (item == null) return 0;
    if (item.retailSalePrice > 0) return item.retailSalePrice;
    return item.rate;
  }

  double get _dailyQtyValue => double.tryParse(_dailyQty.text.trim()) ?? 0;

  double get _baseSubscriptionAmount =>
      _itemRate * _dailyQtyValue * _payableSubscriptionDays;

  bool get _hasBonusExtension {
    // Keep this independent from computed totals to avoid recursive getter loops.
    return _schemeDraft.type == 'BONUS_QTY' && _schemeDraft.bonusQty > 0;
  }

  int get _bonusExtensionDays => 0;

  DateTime get _effectiveEndDate =>
      _endDate.add(Duration(days: _bonusExtensionDays));

  double get _taxPercentValue => _selectedItem?.taxPercent ?? 0;

  double get _taxableSubscriptionAmount {
    final base = _baseSubscriptionAmount;
    final discount = _calculatedSchemeDiscountAmount(_schemeDraft);
    return (base - discount).clamp(0, double.infinity).toDouble();
  }

  double get _taxAmountValue =>
      (_taxableSubscriptionAmount * _taxPercentValue / 100)
          .clamp(0, double.infinity)
          .toDouble();

  double get _grandTotalSubscriptionAmount =>
      (_taxableSubscriptionAmount + _taxAmountValue)
          .clamp(0, double.infinity)
          .toDouble();

  double _calculatedSchemeDiscountAmount(_SchemeDraft draft) {
    final base = _baseSubscriptionAmount;
    if (base <= 0) return 0;
    switch (draft.type) {
      case 'BONUS_QTY':
        return 0;
      case 'PRICE_DISCOUNT':
        if (draft.discountMode == 'PERCENT') {
          final percent = draft.value.clamp(0, 100);
          return (base * percent / 100).clamp(0, base).toDouble();
        }
        return draft.discountAmount.clamp(0, base).toDouble();
      default:
        return 0;
    }
  }

  void _applySchemeDraft(_SchemeDraft next) {
    final normalized = next.normalized(
        baseAmount: _baseSubscriptionAmount, unitRate: _itemRate);
    setState(() {
      _schemeDraft = normalized;
      _syncSuggestedPaymentAmount();
    });
  }

  void _syncSuggestedPaymentAmount({bool force = false}) {
    final suggested = _grandTotalSubscriptionAmount;
    final current = double.tryParse(_totalPayment.text.trim()) ?? 0;
    final isCurrentAuto = (current - _lastAutoPaymentAmount).abs() < 0.01;
    if (force || _totalPayment.text.trim().isEmpty || isCurrentAuto) {
      _totalPayment.text = suggested.toStringAsFixed(2);
    }
    _lastAutoPaymentAmount = suggested;
  }

  List<Map<String, dynamic>> _selectedSchemesPayload() {
    final normalized = _schemeDraft.normalized(
        baseAmount: _baseSubscriptionAmount, unitRate: _itemRate);
    if (normalized.type == 'BONUS_QTY' && normalized.bonusQty <= 0)
      return const [];
    if (normalized.type == 'PRICE_DISCOUNT' && normalized.discountAmount <= 0)
      return const [];
    return [normalized.toJson()];
  }

  Future<Map<String, dynamic>?> _showPaymentDialog({
    double? expectedAmount,
  }) async {
    final targetAmount =
        expectedAmount ?? (double.tryParse(_totalPayment.text.trim()) ?? 0);
    final notesCtrl = TextEditingController();
    final lines = <_SubscriptionPaymentLine>[
      _SubscriptionPaymentLine(method: 'CASH', amount: targetAmount),
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Payment'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose one or more payment modes. Use Split/Multiple when payment is shared.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...lines.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: entry.value.method,
                              decoration:
                                  const InputDecoration(labelText: 'Mode'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'CASH', child: Text('Cash')),
                                DropdownMenuItem(
                                    value: 'CARD', child: Text('Card')),
                                DropdownMenuItem(
                                    value: 'UPI', child: Text('UPI')),
                                DropdownMenuItem(
                                    value: 'BANK', child: Text('Bank')),
                                DropdownMenuItem(
                                    value: 'SPLIT',
                                    child: Text('Split/Multiple')),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  lines[entry.key].method = value ?? 'CASH';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue:
                                  entry.value.amount.toStringAsFixed(2),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration:
                                  const InputDecoration(labelText: 'Amount'),
                              onChanged: (value) {
                                setDialogState(() {
                                  lines[entry.key].amount =
                                      double.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: lines.length == 1
                                ? null
                                : () {
                                    setDialogState(
                                        () => lines.removeAt(entry.key));
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          lines.add(_SubscriptionPaymentLine(
                              method: 'CASH', amount: 0));
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Payment Mode'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Expected total: ${targetAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final cleaned = lines
                    .where((line) => line.amount > 0)
                    .map((line) =>
                        {'method': line.method, 'amount': line.amount})
                    .toList();
                Navigator.pop(dialogContext, {
                  'notes': notesCtrl.text.trim(),
                  'lines': cleaned,
                });
              },
              child: const Text('Use Payment'),
            ),
          ],
        ),
      ),
    );

    notesCtrl.dispose();
    return result;
  }

  Future<void> _saveSubscription() async {
    final item = _selectedItem;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item.')),
      );
      return;
    }
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a customer from the master list.')),
      );
      return;
    }

    _paymentDraft ??= await _showPaymentDialog();
    if (_paymentDraft == null) return;

    final paymentLines = (_paymentDraft?['lines'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final paymentNotes = _paymentDraft?['notes']?.toString().trim() ?? '';
    final totalPaid = paymentLines.fold<double>(
      0,
      (sum, entry) =>
          sum + (double.tryParse(entry['amount']?.toString() ?? '0') ?? 0),
    );
    final totalAmount = _grandTotalSubscriptionAmount;
    _totalPayment.text = totalAmount.toStringAsFixed(2);

    final selectedSchemes = _selectedSchemesPayload();
    final bonusQty = selectedSchemes.isNotEmpty
        ? (double.tryParse(
                selectedSchemes.first['bonus_qty']?.toString() ?? '0') ??
            0)
        : 0;
    final firstMode = paymentLines.isNotEmpty
        ? (paymentLines.first['method']?.toString() ?? 'SUBSCRIPTION')
        : 'SUBSCRIPTION';

    final payload = <String, dynamic>{
      'customer_name': _selectedCustomer!.customerName.trim(),
      'customer_phone': _selectedCustomer!.customerPhone.trim(),
      'customer_address': _selectedCustomer!.customerAddress.trim(),
      'customer_gstin': _selectedCustomer!.customerGstin.trim(),
      'item_id': item.id,
      'start_date': _startDate.toIso8601String(),
      'end_date': _endDate.toIso8601String(),
      'daily_allowed_qty': double.tryParse(_dailyQty.text.trim()) ?? 0,
      'total_payment_amount': totalAmount,
      'taxable_amount': _taxableSubscriptionAmount,
      'tax_amount': _taxAmountValue,
      'tax_percent': _taxPercentValue,
      'item_rate': _itemRate,
      'bonus_qty': bonusQty,
      'selected_schemes': selectedSchemes,
      'payment_mode': firstMode,
      'delivery_type': _deliveryType,
    };

    final saved = await _ctrl.createSubscription(payload);
    await _reloadSubscriptions();
    if (!mounted) return;

    final receiptData = <String, dynamic>{
      ...saved,
      'payment_lines': paymentLines,
      'payment_notes': paymentNotes,
      'paid_amount': totalPaid,
      'remaining_amount': (totalAmount - totalPaid).clamp(0, double.infinity),
      'receipt_date': DateTime.now().toIso8601String(),
    };
    _lastSavedSubscription = receiptData;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Subscription created for ${saved['customer_name'] ?? _customerName.text}')),
    );

    await _showReceiptActions(receiptData);
    _resetForm();
  }

  void _resetForm() {
    _customerName.clear();
    _customerPhone.clear();
    _customerAddress.clear();
    _customerGstin.clear();
    _selectedCustomer = null;
    _dailyQty.text = '2';
    _totalPayment.text = '0';
    _paymentDraft = null;
    _lastAutoPaymentAmount = 0;
    setState(() {
      _selectedItem = null;
      _schemeDraft = const _SchemeDraft();
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 29));
    });
  }

  Future<void> _showReceiptActions(Map<String, dynamic> receiptData) async {
    final paidAmount = double.tryParse(
          (receiptData['paid_amount'] ??
                  receiptData['amount_paid'] ??
                  receiptData['total_payment_amount'] ??
                  0)
              .toString(),
        ) ??
        0;
    final outstandingAmount = double.tryParse(
          (receiptData['remaining_amount'] ??
                  receiptData['balance_due'] ??
                  receiptData['outstanding_amount'] ??
                  0)
              .toString(),
        ) ??
        0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Receipt Ready'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${receiptData['customer_name'] ?? ''}'),
              Text('Item: ${receiptData['item_name'] ?? ''}'),
              Text(
                  'Period: ${receiptData['start_date']} to ${receiptData['end_date']}'),
              Text('Paid: Rs. ${paidAmount.toStringAsFixed(2)}'),
              Text('Outstanding: Rs. ${outstandingAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 10),
              const Text(
                'You can preview the slip on screen or send it directly to the printer.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _previewReceipt(receiptData);
            },
            child: const Text('Preview'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Printing.layoutPdf(
                  onLayout: (_) => _buildReceiptPdf(receiptData));
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewReceipt(Map<String, dynamic> receiptData) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Receipt Preview'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${receiptData['customer_name'] ?? ''}'),
                Text('Phone: ${receiptData['customer_phone'] ?? ''}'),
                Text('Item: ${receiptData['item_name'] ?? ''}'),
                Text('Daily Qty: ${receiptData['daily_allowed_qty'] ?? ''}'),
                Text(
                    'Total: Rs. ${(double.tryParse(receiptData['total_payment_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                const Text('Payment Lines',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...((receiptData['payment_lines'] as List? ?? const [])
                    .map((entry) {
                  final row = Map<String, dynamic>.from(entry);
                  return Text(
                    '${row['method'] ?? ''} - Rs. ${(row['amount'] ?? 0).toString()}',
                  );
                })),
                if ((receiptData['payment_notes'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Notes: ${receiptData['payment_notes']}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Printing.layoutPdf(
                  onLayout: (_) => _buildReceiptPdf(receiptData));
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildReceiptPdf(Map<String, dynamic> subscription) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final schemes = (subscription['selected_schemes'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final paymentLines = (subscription['payment_lines'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final paidAmount =
        double.tryParse(subscription['paid_amount']?.toString() ?? '0') ?? 0;
    final totalAmount = double.tryParse(
            subscription['total_payment_amount']?.toString() ?? '0') ??
        0;
    final outstandingAmount =
        double.tryParse(subscription['remaining_amount']?.toString() ?? '0') ??
            0;
    final receiptDate = DateTime.tryParse(
          subscription['receipt_date']?.toString() ?? '',
        ) ??
        DateTime.now();
    final startDate = _parseDateOnly(subscription['start_date']);
    final endDate = _parseDateOnly(subscription['end_date']);
    final periodDays = (startDate != null && endDate != null)
        ? (endDate.difference(startDate).inDays + 1)
        : 31;
    final bonusQtyForReceipt =
        double.tryParse(subscription['bonus_qty']?.toString() ?? '0') ?? 0;
    final payableDays = periodDays > 0
        ? (bonusQtyForReceipt > 0 ? periodDays - 1 : periodDays)
        : 0;
    final dailyQty =
        double.tryParse(subscription['daily_allowed_qty']?.toString() ?? '0') ??
            0;
    final declaredRate =
        double.tryParse(subscription['item_rate']?.toString() ?? '0') ?? 0;
    final effectiveRate = declaredRate > 0
        ? declaredRate
        : (payableDays > 0 && dailyQty > 0
            ? (totalAmount / (payableDays * dailyQty))
            : 0);
    final baseAmount = (effectiveRate * dailyQty * payableDays)
        .clamp(0, double.infinity)
        .toDouble();
    final mono = pw.Font.courier();

    pw.Widget divider() => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 5),
          width: double.infinity,
          height: 1,
          color: PdfColors.black,
        );

    pw.Widget kvLine(
      String label,
      String value, {
      bool bold = false,
      double fontSize = 9,
    }) {
      final style = pw.TextStyle(
        font: mono,
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text(label, style: style)),
            pw.SizedBox(width: 6),
            pw.Text(value, style: style, textAlign: pw.TextAlign.right),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm,
          220 * PdfPageFormat.mm,
          marginLeft: 3 * PdfPageFormat.mm,
          marginRight: 3 * PdfPageFormat.mm,
          marginTop: 3 * PdfPageFormat.mm,
          marginBottom: 3 * PdfPageFormat.mm,
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'SUBSCRIPTION RECEIPT',
              style: pw.TextStyle(
                font: mono,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              DateFormat('dd-MMM-yyyy hh:mm a').format(receiptDate),
              style: pw.TextStyle(font: mono, fontSize: 8),
            ),
          ),
          divider(),
          pw.Text(
            'Customer: ${subscription['customer_name'] ?? ''}',
            style: pw.TextStyle(font: mono, fontSize: 9),
          ),
          pw.Text(
            'Phone   : ${subscription['customer_phone'] ?? ''}',
            style: pw.TextStyle(font: mono, fontSize: 9),
          ),
          pw.Text(
            'Item    : ${subscription['item_name'] ?? ''}',
            style: pw.TextStyle(font: mono, fontSize: 9),
          ),
          pw.Text(
            'Period  : ${subscription['start_date']} to ${subscription['end_date']}',
            style: pw.TextStyle(font: mono, fontSize: 9),
          ),
          pw.Text(
            'DailyQty: ${subscription['daily_allowed_qty'] ?? ''}',
            style: pw.TextStyle(font: mono, fontSize: 9),
          ),
          divider(),
          kvLine(
            'TOTAL',
            currency.format(totalAmount),
            bold: true,
            fontSize: 11,
          ),
          kvLine(
            'PAID',
            currency.format(paidAmount),
            bold: true,
            fontSize: 11,
          ),
          kvLine(
            'OUTSTANDING',
            currency.format(outstandingAmount),
            bold: true,
            fontSize: 10,
          ),
          divider(),
          pw.Text('Payment Breakdown',
              style: pw.TextStyle(
                font: mono,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              )),
          pw.SizedBox(height: 2),
          if (paymentLines.isEmpty)
            pw.Text(
              'No payment line',
              style: pw.TextStyle(font: mono, fontSize: 9),
            )
          else
            ...paymentLines.map((row) {
              final amount =
                  double.tryParse(row['amount']?.toString() ?? '0') ?? 0;
              return kvLine(
                (row['method'] ?? '').toString().toUpperCase(),
                currency.format(amount),
              );
            }),
          if ((subscription['payment_notes'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Note: ${subscription['payment_notes']}',
              style: pw.TextStyle(font: mono, fontSize: 8),
            ),
          ],
          divider(),
          pw.Text('Scheme Applied',
              style: pw.TextStyle(
                font: mono,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              )),
          pw.SizedBox(height: 2),
          if (schemes.isEmpty)
            pw.Text('No scheme', style: pw.TextStyle(font: mono, fontSize: 9))
          else
            ...schemes.map((scheme) {
              final schemeName = (scheme['scheme_name'] ?? '').toString();
              final bonusQty =
                  double.tryParse(scheme['bonus_qty']?.toString() ?? '0') ?? 0;
              final discountAmount = double.tryParse(
                      scheme['discount_amount']?.toString() ?? '0') ??
                  0;
              final schemeValue =
                  double.tryParse(scheme['scheme_value']?.toString() ?? '0') ??
                      0;
              final schemeType =
                  (scheme['scheme_type'] ?? '').toString().trim().toUpperCase();
              final expectedOff = schemeType == 'BONUS_QTY'
                  ? (bonusQty * effectiveRate)
                      .clamp(0, double.infinity)
                      .toDouble()
                  : schemeType == 'PRICE_DISCOUNT' &&
                          (scheme['discount_mode'] ?? '')
                                  .toString()
                                  .toUpperCase() ==
                              'PERCENT'
                      ? (baseAmount * schemeValue / 100)
                          .clamp(0, double.infinity)
                          .toDouble()
                      : discountAmount;
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    schemeName.isEmpty ? 'Scheme' : schemeName,
                    style: pw.TextStyle(
                      font: mono,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  kvLine(
                    'Type',
                    schemeType.isEmpty ? '-' : schemeType,
                  ),
                  if (schemeType == 'BONUS_QTY')
                    kvLine(
                      'Formula',
                      '${_itemRate.toStringAsFixed(2)} x ${bonusQty.toStringAsFixed(bonusQty % 1 == 0 ? 0 : 2)}',
                    )
                  else if (schemeType == 'PRICE_DISCOUNT')
                    kvLine(
                      'Formula',
                      (scheme['discount_mode'] ?? '')
                                  .toString()
                                  .toUpperCase() ==
                              'PERCENT'
                          ? '${schemeValue.toStringAsFixed(2)}% of base'
                          : 'Flat discount amount',
                    ),
                  kvLine(
                    'Expected Off',
                    currency.format(expectedOff),
                  ),
                  kvLine(
                    'Applied Off',
                    currency.format(discountAmount),
                  ),
                  pw.SizedBox(height: 3),
                ],
              );
            }),
          divider(),
          pw.Text(
            'Terms & Conditions',
            style: pw.TextStyle(
              font: mono,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
          ),
          pw.Text(
            '1) Scheme benefit shown as expected off.',
            style: pw.TextStyle(font: mono, fontSize: 7),
          ),
          pw.Text(
            '2) If item rate changes in future bills, payable amount will be adjusted as per current rate.',
            style: pw.TextStyle(font: mono, fontSize: 7),
          ),
          pw.Text(
            '3) Subscription usage follows daily quantity limit and billing period.',
            style: pw.TextStyle(font: mono, fontSize: 7),
          ),
          divider(),
          pw.Center(
            child: pw.Text(
              'Thank you for your business',
              style: pw.TextStyle(font: mono, fontSize: 8),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _showLedger(
    Map<String, dynamic> subscription, {
    bool stickToSelectedCycle = false,
  }) async {
    final selectedForLedger = stickToSelectedCycle
        ? subscription
        : _currentCycleSubscriptionForLedger(subscription);
    if (!stickToSelectedCycle &&
        (selectedForLedger['id']?.toString() ?? '') !=
            (subscription['id']?.toString() ?? '')) {
      await _showLedger(selectedForLedger, stickToSelectedCycle: true);
      return;
    }
    subscription = selectedForLedger;
    final id = int.tryParse(subscription['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final details = await _ctrl.getSubscriptionLedger(id);
    if (!mounted) return;

    final consumptions = (details['consumptions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final settlements = (details['settlements'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final financialSummary =
        Map<String, dynamic>.from(details['financial_summary'] ?? const {});
    final itemAdvanceSummary =
        Map<String, dynamic>.from(details['advance_summary'] ?? const {});
    final cashAdvanceSummary =
        Map<String, dynamic>.from(details['cash_advance_summary'] ?? const {});
    final previousCycles = _previousCyclesFor(subscription);
    final upcomingCycles = _upcomingCyclesFor(subscription);
    final prepaidValue =
        double.tryParse(financialSummary['prepaid_value']?.toString() ?? '0') ??
            0;
    final actualValue =
        double.tryParse(financialSummary['actual_value']?.toString() ?? '0') ??
            0;
    final schemeDiscountValue = double.tryParse(
            financialSummary['discount_amount']?.toString() ?? '0') ??
        0;
    final pendingSchemeDiscountValue = double.tryParse(
            financialSummary['discount_pending_amount']?.toString() ?? '0') ??
        0;
    final grossCoveredValue = double.tryParse(
            financialSummary['gross_covered_value']?.toString() ?? '') ??
        (actualValue + schemeDiscountValue)
            .clamp(0, double.infinity)
            .toDouble();
    final outstandingValue = double.tryParse(
            financialSummary['outstanding_amount']?.toString() ?? '0') ??
        0;
    final creditedValue = double.tryParse(
            financialSummary['credited_amount']?.toString() ?? '0') ??
        0;
    final totalConsumedQty = consumptions.fold<double>(
      0,
      (sum, row) =>
          sum + (double.tryParse(row['cart_qty']?.toString() ?? '0') ?? 0),
    );
    final totalCoveredQty = consumptions.fold<double>(
      0,
      (sum, row) =>
          sum + (double.tryParse(row['covered_qty']?.toString() ?? '0') ?? 0),
    );
    final totalExcessQty = consumptions.fold<double>(
      0,
      (sum, row) =>
          sum + (double.tryParse(row['excess_qty']?.toString() ?? '0') ?? 0),
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 720
        ? screenWidth * 0.94
        : (screenWidth * 0.88).clamp(640.0, 900.0);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Subscription Ledger - ${subscription['customer_name'] ?? subscription['customer_phone'] ?? ''}'),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: ${subscription['item_name'] ?? ''}'),
                Text(
                    'Period: ${subscription['start_date']} to ${subscription['end_date']}'),
                const Text('Financial Summary',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ledgerInfoChip(
                        'Prepaid: Rs. ${prepaidValue.toStringAsFixed(2)}'),
                    _ledgerInfoChip(
                        'Gross Covered: Rs. ${grossCoveredValue.toStringAsFixed(2)}'),
                    _ledgerInfoChip(
                        'Scheme Discount Applied: Rs. ${schemeDiscountValue.toStringAsFixed(2)}'),
                    _ledgerInfoChip(
                        'Net Actual: Rs. ${actualValue.toStringAsFixed(2)}'),
                    _ledgerInfoChip(
                        'Outstanding: Rs. ${outstandingValue.toStringAsFixed(2)}'),
                    _ledgerInfoChip(
                        'Credit: Rs. ${creditedValue.toStringAsFixed(2)}'),
                    if (pendingSchemeDiscountValue > 0)
                      _ledgerInfoChip(
                        'Scheme Discount Pending: Rs. ${pendingSchemeDiscountValue.toStringAsFixed(2)}',
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Formula: Gross Covered - Scheme Discount = Net Actual',
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ledgerInfoChip(
                      'Qty ${totalConsumedQty.toStringAsFixed(totalConsumedQty % 1 == 0 ? 0 : 2)}',
                    ),
                    _ledgerInfoChip(
                      'Covered ${totalCoveredQty.toStringAsFixed(totalCoveredQty % 1 == 0 ? 0 : 2)}',
                    ),
                    _ledgerInfoChip(
                      'Excess ${totalExcessQty.toStringAsFixed(totalExcessQty % 1 == 0 ? 0 : 2)}',
                    ),
                  ],
                ),
                if (itemAdvanceSummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Item Advance',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Original Qty: ${itemAdvanceSummary['original_qty'] ?? 0} | '
                    'Consumed Qty: ${itemAdvanceSummary['consumed_qty'] ?? 0} | '
                    'Left Qty: ${itemAdvanceSummary['available_qty'] ?? 0}',
                  ),
                  Text(
                    'Rate: ${itemAdvanceSummary['rate'] ?? 0} | '
                    'Original Amount: ${itemAdvanceSummary['original_amount'] ?? 0} | '
                    'Left Amount: ${itemAdvanceSummary['available_amount'] ?? 0}',
                  ),
                ],
                if (cashAdvanceSummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Cash Prepayment',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Paid: Rs. ${cashAdvanceSummary['original_amount'] ?? 0} | '
                    'Used: Rs. ${cashAdvanceSummary['consumed_amount'] ?? 0} | '
                    'Left: Rs. ${cashAdvanceSummary['available_amount'] ?? 0}',
                  ),
                ],
                if (itemAdvanceSummary.isEmpty &&
                    cashAdvanceSummary.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'No advance/prepayment is configured for this subscription. Outstanding comes from excess billed quantity.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Consumption',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (consumptions.isEmpty)
                  const Text('No transactions found.')
                else
                  ...consumptions.map((row) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${row['txn_date']} | ${row['item_name'] ?? ''}'),
                      subtitle: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ledgerInfoChip('Qty ${row['cart_qty']}'),
                          _ledgerInfoChip('Covered ${row['covered_qty']}'),
                          _ledgerInfoChip('Excess ${row['excess_qty']}'),
                          _ledgerInfoChip('Rate ${row['rate']}'),
                          _ledgerInfoChip('Bill ${row['sale_no'] ?? '-'}'),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 28),
                const Text('Settlements',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (settlements.isEmpty)
                  const Text('No settlement records.')
                else
                  ...settlements.map((row) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${row['settlement_no'] ?? ''} | ${row['settlement_date'] ?? ''}'),
                      subtitle: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ledgerInfoChip(
                              'Actual ${row['gross_excess_amount']}'),
                          _ledgerInfoChip('Bonus ${row['bonus_amount']}'),
                          _ledgerInfoChip(
                              'Discount ${row['scheme_discount_amount']}'),
                          _ledgerInfoChip('Due ${row['total_due']}'),
                          _ledgerInfoChip('Paid ${row['amount_paid'] ?? 0}'),
                          _ledgerInfoChip(
                              'Outstanding ${row['balance_due'] ?? 0}'),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          if (!stickToSelectedCycle)
            TextButton(
              onPressed: (previousCycles.isEmpty && upcomingCycles.isEmpty)
                  ? null
                  : () async {
                      await _showCycleDirectionPicker(subscription);
                    },
              child: const Text('Cycles'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (subscription['active_subscription'] == true)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _settleSubscription(subscription, details);
              },
              child: const Text('Settle'),
            )
          else
            const FilledButton.tonal(
              onPressed: null,
              child: Text('Settled'),
            ),
        ],
      ),
    );
  }

  Future<void> _settleSubscription(
    Map<String, dynamic> subscription,
    Map<String, dynamic> details,
  ) async {
    final id = int.tryParse(subscription['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final financial =
        Map<String, dynamic>.from(details['financial_summary'] ?? const {});
    final itemAdvanceSummary =
        Map<String, dynamic>.from(details['advance_summary'] ?? const {});
    final cashAdvanceSummary =
        Map<String, dynamic>.from(details['cash_advance_summary'] ?? const {});
    final grossOutstanding = double.tryParse(
            financial['gross_outstanding_amount']?.toString() ??
                financial['outstanding_amount']?.toString() ??
                '0') ??
        0;
    final outstanding =
        double.tryParse(financial['outstanding_amount']?.toString() ?? '0') ??
            0;
    final cashAdvanceAvailable = double.tryParse(
            cashAdvanceSummary['available_amount']?.toString() ?? '0') ??
        0;
    final cashAdvanceUsed = cashAdvanceAvailable > 0
        ? (grossOutstanding > cashAdvanceAvailable
            ? cashAdvanceAvailable
            : grossOutstanding)
        : 0;
    final netOutstanding = outstanding;
    final credited =
        double.tryParse(financial['credited_amount']?.toString() ?? '0') ?? 0;
    final isRefundFlow =
        outstanding <= 0 && (cashAdvanceAvailable > 0 || credited > 0);
    final refundPreview = isRefundFlow
        ? (cashAdvanceAvailable > 0 ? cashAdvanceAvailable : credited)
        : 0.0;
    final amountCtrl = TextEditingController(
      text: isRefundFlow
          ? (cashAdvanceAvailable > 0
              ? cashAdvanceAvailable.toStringAsFixed(2)
              : credited.toStringAsFixed(2))
          : (netOutstanding > 0 ? netOutstanding.toStringAsFixed(2) : '0.00'),
    );
    String paymentMode = 'CASH';
    final settled = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Settle Subscription'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review the settlement summary and choose how much was received or refunded now.',
                  ),
                  const SizedBox(height: 16),
                  _summaryRow('Prepaid', financial['prepaid_value']),
                  _summaryRow('Actual', financial['actual_value']),
                  if (itemAdvanceSummary.isNotEmpty)
                    _summaryQtyRow(
                        'Item Qty Left', itemAdvanceSummary['available_qty']),
                  _summaryRow('Cash Advance Left',
                      cashAdvanceSummary['available_amount'] ?? credited),
                  if (cashAdvanceUsed > 0)
                    _summaryRow('Advance Applied', cashAdvanceUsed),
                  _summaryRow('Gross Due', grossOutstanding),
                  _summaryRow('Net Due', netOutstanding),
                  if (isRefundFlow)
                    _summaryRow('Refund From Advance', refundPreview),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'CARD', child: Text('Card')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                    ],
                    onChanged: (value) {
                      paymentMode = value ?? 'CASH';
                      if (netOutstanding > 0 &&
                          (double.tryParse(amountCtrl.text.trim()) ?? 0) <= 0) {
                        amountCtrl.text = netOutstanding.toStringAsFixed(2);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isRefundFlow
                          ? 'Amount Refunded Now'
                          : 'Amount Received Now',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRefundFlow
                        ? 'If refund is less than available customer credit, remaining credit stays as advance for future purchases.'
                        : 'Amount received must clear the full net due. Extra received amount is saved as customer advance.',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (isRefundFlow && enteredAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter refund amount before settling.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'payment_mode': paymentMode,
                  'amount_paid': enteredAmount,
                });
              },
              child: const Text('Settle Now'),
            ),
          ],
        );
      },
    );
    amountCtrl.dispose();
    if (settled == null) return;

    try {
      final result = await _ctrl.generateFinalSettlement(
        id,
        notes: settled['notes']?.toString(),
        settlementDate: DateTime.now(),
        paymentMode: settled['payment_mode']?.toString(),
        amountPaid: double.tryParse(settled['amount_paid']?.toString() ?? '0'),
      );
      await _reloadSubscriptions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settlement created: ${result['settlement']?['settlement_no'] ?? ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showCycleDirectionPicker(
      Map<String, dynamic> currentCycle) async {
    final hasPrevious = _previousCyclesFor(currentCycle).isNotEmpty;
    final hasUpcoming = _upcomingCyclesFor(currentCycle).isNotEmpty;
    if (!hasPrevious && !hasUpcoming) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Cycle Type'),
        content:
            const Text('Choose which subscription cycles you want to view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: hasPrevious
                ? () async {
                    Navigator.pop(dialogContext);
                    await _showCyclePicker(currentCycle, showPrevious: true);
                  }
                : null,
            child: const Text('Previous'),
          ),
          FilledButton.tonal(
            onPressed: hasUpcoming
                ? () async {
                    Navigator.pop(dialogContext);
                    await _showCyclePicker(currentCycle, showPrevious: false);
                  }
                : null,
            child: const Text('Upcoming'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _summaryQtyRow(String label, dynamic value) {
    final qty = double.tryParse(value?.toString() ?? '0') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _ledgerInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard({
    required Map<String, dynamic> subscription,
    required NumberFormat currency,
    required String cust,
    required String itemName,
    required double due,
    required String totalDays,
    required String consumedDays,
    required String missedDays,
    required String daysLeft,
    required List<Map<String, dynamic>> schemes,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusBgColor(subscription),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(subscription),
                          style: TextStyle(
                            color: _statusTextColor(subscription),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showLedger(subscription),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(
                          '$cust - $itemName',
                          style: const TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ledgerInfoChip(
                  '${subscription['start_date']} to ${subscription['end_date']}',
                ),
                _ledgerInfoChip('Daily ${subscription['daily_allowed_qty']}'),
                _ledgerInfoChip(currency.format(due)),
                _ledgerInfoChip('Total $totalDays'),
                _ledgerInfoChip('Consumed $consumedDays'),
                _ledgerInfoChip('Skipped $missedDays'),
                _ledgerInfoChip('Left $daysLeft'),
              ],
            ),
            if (schemes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  schemes
                      .map((scheme) => scheme['scheme_name']?.toString() ?? '')
                      .where((value) => value.isNotEmpty)
                      .join(' | '),
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () => _showLedger(subscription),
                  child: const Text('Ledger'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () => _showReceiptActions(subscription),
                  child: const Text('Preview'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: _canRenewSubscription(subscription) &&
                          !_hasFutureRenewal(subscription)
                      ? () => _renewSubscription(subscription)
                      : null,
                  child: const Text('Renew'),
                ),
                if (subscription['active_subscription'] == true)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      final id =
                          int.tryParse(subscription['id']?.toString() ?? '') ??
                              0;
                      if (id <= 0) return;
                      final details = await _ctrl.getSubscriptionLedger(id);
                      if (!mounted) return;
                      await _settleSubscription(subscription, details);
                    },
                    child: const Text('Settle'),
                  ),
                if (consumedDays == '0' && (double.tryParse(subscription['consumed_qty']?.toString() ?? '0') ?? 0) == 0)
                  IconButton(
                    onPressed: () async {
                      final id = int.tryParse(subscription['id']?.toString() ?? '') ?? 0;
                      if (id <= 0) return;
                      
                      final details = await _ctrl.getSubscriptionLedger(id);
                      final financial = Map<String, dynamic>.from(details['financial_summary'] ?? const {});
                      final outstanding = double.tryParse(financial['outstanding_amount']?.toString() ?? '0') ?? 0;
                      
                      if (!mounted) return;
                      
                      if (outstanding > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please settle all balance before deleting.')),
                        );
                        return;
                      }
                      
                      await _confirmDeleteSubscription(subscription);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Subscription',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showHomeDelivery = context.read<SystemSettingsController>().settings?.enableAppSubscription == true;
    if (!showHomeDelivery && _deliveryType == 'HOME') {
      _deliveryType = 'PICKUP';
    }
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final activeCount = _subscriptions
        .where((row) => row['active_subscription'] == true)
        .length;
    final upcomingRenewalCount =
        _subscriptions.where((row) => _isUpcomingRenewal(row)).length;
    final renewedCount =
        _subscriptions.where((row) => _isAlreadyRenewed(row)).length;
    final visibleSubscriptions = _filteredSubscriptions;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_outlined, size: 22),
            SizedBox(width: 10),
            Text(
              'Subscription Billing',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reloadSubscriptions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final uiPrefs = context.watch<UiPreferencesController>();
                final isWide = constraints.maxWidth >= 1200;
                final isMedium = constraints.maxWidth >= 760;
                const horizontalGap = 12.0;
                final outerHorizontalPadding =
                    constraints.maxWidth >= 1200 ? 56.0 : 24.0;
                const maxContentWidth = 1160.0;
                final canvasWidth = (constraints.maxWidth -
                        (outerHorizontalPadding * 2))
                    .clamp(0, maxContentWidth)
                    .toDouble();
                final formFieldWidth = isWide
                    ? (canvasWidth - (horizontalGap * 3)) / 4
                    : isMedium
                        ? (canvasWidth - horizontalGap) / 2
                        : canvasWidth;
                final compactFieldWidth = isWide
                    ? (canvasWidth - (horizontalGap * 4)) / 5
                    : isMedium
                        ? (canvasWidth - horizontalGap) / 2
                        : canvasWidth;
                final itemFieldWidth = isWide
                    ? (compactFieldWidth * 2) + horizontalGap
                    : canvasWidth;
                final searchFieldWidth = canvasWidth;
                final isExtraCompactFields =
                    uiPrefs.textfieldSize == 'extra_compact';
                final isCompactFields = uiPrefs.textfieldSize == 'compact';
                final isComfortableFields =
                    uiPrefs.textfieldSize == 'comfortable';
                final fieldPadding = isExtraCompactFields
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                    : isCompactFields
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                    : isComfortableFields
                        ? const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          );
                final minFieldHeight = isExtraCompactFields
                    ? 36.0
                    : isCompactFields
                    ? 40.0
                    : isComfortableFields
                        ? 56.0
                        : 46.0;

                return Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.white,
                        isDense: isCompactFields || isExtraCompactFields,
                        constraints: BoxConstraints(minHeight: minFieldHeight),
                        contentPadding: fieldPadding,
                        labelStyle: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                        ),
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                    child: RefreshIndicator(
                      onRefresh: _bootstrap,
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: outerHorizontalPadding,
                          vertical: 18,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: maxContentWidth),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0F172A),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Enterprise Subscription Workspace',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    _enterpriseStatChip(
                                      'Active',
                                      '$activeCount',
                                      const Color(0xFF22C55E),
                                    ),
                                    _enterpriseStatChip(
                                      'Upcoming',
                                      '$upcomingRenewalCount',
                                      const Color(0xFFF59E0B),
                                    ),
                                    _enterpriseStatChip(
                                      'Renewed',
                                      '$renewedCount',
                                      const Color(0xFF38BDF8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: maxContentWidth),
                              child: Card(
                            elevation: 0,
                            color: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    icon: Icons.add_card_outlined,
                                    title: 'Create Subscription',
                                    subtitle:
                                        'Configure customer, item plan, scheme and payment in one workspace.',
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(
                                      height: 1, color: Color(0xFFE2E8F0)),
                                  const SizedBox(height: 14),
                                  DropdownSearch<SaleCustomer>(
                                    selectedItem: _selectedCustomer,
                                    items: (filter, _) async {
                                      if (filter.trim().isEmpty)
                                        return _ctrl.customers;
                                      return _ctrl.customers.where((customer) {
                                        final q = filter.trim().toLowerCase();
                                        return customer.customerName
                                                .toLowerCase()
                                                .contains(q) ||
                                            customer.customerPhone
                                                .toLowerCase()
                                                .contains(q) ||
                                            customer.customerGstin
                                                .toLowerCase()
                                                .contains(q);
                                      }).toList();
                                    },
                                    itemAsString: (customer) =>
                                        customer.displayLabel,
                                    compareFn: (a, b) => a.id == b.id,
                                    popupProps: const PopupProps.menu(
                                        showSearchBox: true),
                                    decoratorProps:
                                        const DropDownDecoratorProps(
                                      decoration: InputDecoration(
                                        labelText: 'Select Customer',
                                        hintText:
                                            'Pick from the customer master',
                                      ),
                                    ),
                                    onChanged: _setCustomer,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: formFieldWidth,
                                        child: TextField(
                                          controller: _customerName,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                              labelText: 'Customer Name'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: formFieldWidth,
                                        child: TextField(
                                          controller: _customerPhone,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                              labelText: 'Customer Phone'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: formFieldWidth,
                                        child: TextField(
                                          controller: _customerGstin,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                              labelText: 'GSTIN'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: formFieldWidth,
                                        child: TextField(
                                          controller: _customerAddress,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                              labelText: 'Address'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: itemFieldWidth,
                                        child: DropdownSearch<Item>(
                                          selectedItem: _selectedItem,
                                          items: (filter, _) async {
                                            if (filter.trim().isEmpty) {
                                              return _ctrl.items;
                                            }
                                            final q = filter.trim().toLowerCase();
                                            return _ctrl.items.where((item) {
                                              return item.itemName
                                                      .toLowerCase()
                                                      .contains(q) ||
                                                  item.itemCode
                                                      .toLowerCase()
                                                      .contains(q);
                                            }).toList();
                                          },
                                          itemAsString: (item) =>
                                              '${item.itemCode} - ${item.itemName}',
                                          compareFn: (a, b) => a.id == b.id,
                                          popupProps: const PopupProps.menu(
                                            showSearchBox: true,
                                          ),
                                          decoratorProps:
                                              const DropDownDecoratorProps(
                                            decoration: InputDecoration(
                                              labelText: 'Item',
                                              hintText:
                                                  'Search by item code or name',
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() => _selectedItem = value);
                                            _applyDefaultBonusQtyFromDaily();
                                            _syncSuggestedPaymentAmount(
                                              force: true,
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: compactFieldWidth,
                                        child: TextField(
                                          controller: _dailyQty,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                              labelText: 'Daily Qty'),
                                          onChanged: (_) {
                                            _applyDefaultBonusQtyFromDaily(
                                                onlyWhenEmpty: false);
                                            _syncSuggestedPaymentAmount(
                                                force: true);
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: compactFieldWidth,
                                        child: TextField(
                                          controller: _totalPayment,
                                          readOnly: true,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Total Payment',
                                            helperText: 'Tax included',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: compactFieldWidth,
                                        child: TextFormField(
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                              labelText: 'Start Date'),
                                          controller: TextEditingController(
                                            text: DateFormat('dd-MMM-yyyy')
                                                .format(_startDate),
                                          ),
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _startDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() =>
                                                  _startDate = _dateOnly(picked));
                                              _syncSuggestedPaymentAmount(
                                                  force: true);
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: compactFieldWidth,
                                        child: TextFormField(
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                              labelText: 'End Date'),
                                          controller: TextEditingController(
                                            text: DateFormat('dd-MMM-yyyy')
                                                .format(_endDate),
                                          ),
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _endDate,
                                              firstDate: _startDate,
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() =>
                                                  _endDate = _dateOnly(picked));
                                              _syncSuggestedPaymentAmount(
                                                  force: true);
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: compactFieldWidth,
                                        child: DropdownButtonFormField<String>(
                                          value: _deliveryType,
                                          decoration: const InputDecoration(
                                            labelText: 'Delivery Type',
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                              value: 'PICKUP',
                                              child: Text('Store Pickup'),
                                            ),
                                            if (showHomeDelivery)
                                              const DropdownMenuItem(
                                                value: 'HOME',
                                                child: Text('Home Delivery'),
                                              ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _deliveryType = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Taxable: Rs. ${_taxableSubscriptionAmount.toStringAsFixed(2)} | Tax (${_taxPercentValue.toStringAsFixed(2)}%): Rs. ${_taxAmountValue.toStringAsFixed(2)} | Total: Rs. ${_grandTotalSubscriptionAmount.toStringAsFixed(2)} | Days: ${_subscriptionDays} | End: ${DateFormat('dd-MMM-yyyy').format(_endDate)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Scheme (Single)',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SchemeDraftEditor(
                                      draft: _schemeDraft,
                                      baseAmount: _baseSubscriptionAmount,
                                      unitRate: _itemRate,
                                      onChanged: _applySchemeDraft,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      spacing: 10,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                          ),
                                          onPressed: () async {
                                            final draft =
                                                await _showPaymentDialog();
                                            if (draft == null) return;
                                            setState(
                                                () => _paymentDraft = draft);
                                          },
                                          icon: const Icon(
                                              Icons.payments_outlined),
                                          label: Text(
                                            _paymentDraft == null
                                                ? 'Pay'
                                                : 'Edit Payment',
                                          ),
                                        ),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 18, vertical: 12),
                                          ),
                                          onPressed: _saveSubscription,
                                          icon: const Icon(Icons.receipt_long),
                                          label: const Text(
                                              'Save & Print Receipt'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            )),
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: maxContentWidth),
                              child: Card(
                            elevation: 0,
                            color: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _sectionHeader(
                                          icon: Icons.subscriptions_outlined,
                                          title: 'Subscriptions',
                                          subtitle:
                                              'Track active cycles, renewals and settlements.',
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          '$activeCount Active',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        ActionChip(
                                          avatar: const Icon(Icons.event_repeat,
                                              size: 18),
                                          label: Text(
                                              'Upcoming (7 days): $upcomingRenewalCount'),
                                          onPressed: () {
                                            setState(() => _statusFilter =
                                                'UPCOMING_RENEWAL');
                                          },
                                        ),
                                        ActionChip(
                                          avatar: const Icon(
                                              Icons.check_circle_outline,
                                              size: 18),
                                          label: Text(
                                              'Already Renewed: $renewedCount'),
                                          onPressed: () {
                                            setState(() =>
                                                _statusFilter = 'RENEWED');
                                          },
                                        ),
                                        if (_statusFilter.isNotEmpty)
                                          ActionChip(
                                            avatar:
                                                const Icon(Icons.clear, size: 18),
                                            label: const Text('Clear Filter'),
                                            onPressed: () {
                                              setState(() => _statusFilter = '');
                                              _reloadSubscriptions();
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: searchFieldWidth,
                                        child: TextField(
                                          controller: _search,
                                          decoration: const InputDecoration(
                                            labelText: 'Search',
                                            prefixIcon: Icon(Icons.search),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      SizedBox(
                                        width: searchFieldWidth,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _statusFilter.isEmpty
                                              ? null
                                              : _statusFilter,
                                          decoration: const InputDecoration(
                                              labelText: 'Status'),
                                          items: const [
                                            DropdownMenuItem(
                                                value: '', child: Text('All')),
                                            DropdownMenuItem(
                                                value: 'ACTIVE',
                                                child: Text('Active')),
                                            DropdownMenuItem(
                                              value: 'UPCOMING_RENEWAL',
                                              child: Text('Upcoming Renewal'),
                                            ),
                                            DropdownMenuItem(
                                                value: 'RENEWED',
                                                child: Text('Already Renewed')),
                                            DropdownMenuItem(
                                                value: 'SETTLED',
                                                child: Text('Settled')),
                                            DropdownMenuItem(
                                                value: 'CANCELLED',
                                                child: Text('Cancelled')),
                                          ],
                                          onChanged: (value) {
                                            setState(() =>
                                                _statusFilter = value ?? '');
                                            _reloadSubscriptions();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (visibleSubscriptions.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 24),
                                      child: Center(
                                          child:
                                              Text('No subscriptions found.')),
                                    )
                                  else
                                    ...visibleSubscriptions.map((subscription) {
                                      final itemName = subscription['item_name']
                                              ?.toString() ??
                                          '';
                                      final cust = subscription['customer_name']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true
                                          ? subscription['customer_name']
                                              .toString()
                                          : subscription['customer_phone']
                                                  ?.toString() ??
                                              '';
                                      final schemes = (subscription[
                                                      'selected_schemes']
                                                  as List? ??
                                              const [])
                                          .map((entry) =>
                                              Map<String, dynamic>.from(entry))
                                          .toList();
                                      final due = double.tryParse(subscription[
                                                      'total_payment_amount']
                                                  ?.toString() ??
                                              '0') ??
                                          0;
                                      final totalDays =
                                          subscription['total_days']
                                                  ?.toString() ??
                                              '';
                                      final consumedDays =
                                          subscription['consumed_days']
                                                  ?.toString() ??
                                              '';
                                      final missedDays =
                                          subscription['missed_days']
                                                  ?.toString() ??
                                              '';
                                      final daysLeft = subscription['days_left']
                                              ?.toString() ??
                                          '';
                                      return _buildSubscriptionCard(
                                        subscription: subscription,
                                        currency: currency,
                                        cust: cust,
                                        itemName: itemName,
                                        due: due,
                                        totalDays: totalDays,
                                        consumedDays: consumedDays,
                                        missedDays: missedDays,
                                        daysLeft: daysLeft,
                                        schemes: schemes,
                                      );
                                    }),
                                ],
                              ),
                            ),
                            )),
                            ),
                        ],
                      ),
                    ));
              },
            ),
    );
  }

  Widget _enterpriseStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeDraft {
  final String type;
  final String label;
  final String discountMode;
  final double value;
  final double bonusQty;
  final double discountAmount;
  final String notes;

  const _SchemeDraft({
    this.type = 'BONUS_QTY',
    this.label = 'Bonus Quantity',
    this.discountMode = 'PERCENT',
    this.value = 0,
    this.bonusQty = 0,
    this.discountAmount = 0,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'scheme_type': type,
        'scheme_name': label,
        'scheme_value': value,
        'bonus_qty': bonusQty,
        'discount_amount': discountAmount,
        'discount_mode': discountMode,
        'notes': notes,
      };

  _SchemeDraft copyWith({
    String? type,
    String? label,
    String? discountMode,
    double? value,
    double? bonusQty,
    double? discountAmount,
    String? notes,
  }) {
    return _SchemeDraft(
      type: type ?? this.type,
      label: label ?? this.label,
      discountMode: discountMode ?? this.discountMode,
      value: value ?? this.value,
      bonusQty: bonusQty ?? this.bonusQty,
      discountAmount: discountAmount ?? this.discountAmount,
      notes: notes ?? this.notes,
    );
  }

  static String _labelForType(String type) {
    switch (type) {
      case 'BONUS_QTY':
        return 'Bonus Quantity';
      case 'PRICE_DISCOUNT':
        return 'Price Discount';
      default:
        return 'Custom Scheme';
    }
  }

  _SchemeDraft normalized({
    required double baseAmount,
    required double unitRate,
  }) {
    final normalizedType =
        type == 'PRICE_DISCOUNT' ? 'PRICE_DISCOUNT' : 'BONUS_QTY';
    final normalizedLabel = _labelForType(normalizedType);
    final normalizedMode = discountMode == 'AMOUNT' ? 'AMOUNT' : 'PERCENT';
    double normalizedValue = value;
    double normalizedBonusQty = bonusQty;
    double normalizedDiscountAmount = discountAmount;

    if (normalizedType == 'BONUS_QTY') {
      normalizedBonusQty =
          normalizedBonusQty.clamp(0, double.infinity).toDouble();
      normalizedValue = normalizedBonusQty;
      normalizedDiscountAmount =
          (normalizedBonusQty * unitRate).clamp(0, baseAmount).toDouble();
    } else {
      if (normalizedMode == 'PERCENT') {
        normalizedValue = normalizedValue.clamp(0, 100).toDouble();
        normalizedDiscountAmount = (baseAmount * normalizedValue / 100)
            .clamp(0, baseAmount)
            .toDouble();
      } else {
        normalizedDiscountAmount =
            normalizedDiscountAmount.clamp(0, baseAmount).toDouble();
        normalizedValue = normalizedDiscountAmount;
      }
      normalizedBonusQty = 0;
    }

    return copyWith(
      type: normalizedType,
      label: normalizedLabel,
      discountMode: normalizedMode,
      value: normalizedValue,
      bonusQty: normalizedBonusQty,
      discountAmount: normalizedDiscountAmount,
    );
  }
}

class _SubscriptionPaymentLine {
  String method;
  double amount;

  _SubscriptionPaymentLine({
    required this.method,
    required this.amount,
  });
}

class _SchemeDraftEditor extends StatelessWidget {
  final _SchemeDraft draft;
  final double baseAmount;
  final double unitRate;
  final ValueChanged<_SchemeDraft> onChanged;

  const _SchemeDraftEditor({
    required this.draft,
    required this.baseAmount,
    required this.unitRate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.type,
                    decoration: const InputDecoration(labelText: 'Scheme Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'BONUS_QTY', child: Text('Bonus Qty')),
                      DropdownMenuItem(
                          value: 'PRICE_DISCOUNT', child: Text('Discount')),
                    ],
                    onChanged: (value) {
                      onChanged(
                        draft.copyWith(
                          type: value ?? 'BONUS_QTY',
                          label: value == 'PRICE_DISCOUNT'
                              ? 'Price Discount'
                              : 'Bonus Quantity',
                          bonusQty: value == 'BONUS_QTY' ? draft.bonusQty : 0,
                          value: value == 'PRICE_DISCOUNT'
                              ? draft.value
                              : draft.bonusQty,
                          discountAmount: value == 'PRICE_DISCOUNT'
                              ? draft.discountAmount
                              : 0,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.type == 'BONUS_QTY'
                        ? 'Bonus Quantity'
                        : (draft.discountMode == 'PERCENT'
                            ? 'Price Discount (%)'
                            : 'Price Discount (Amount)'),
                    decoration: const InputDecoration(labelText: 'Label'),
                    enabled: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (draft.type == 'BONUS_QTY')
              Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 190,
                        child: TextFormField(
                          key: ValueKey(
                            'bonus-qty-${draft.bonusQty.toStringAsFixed(2)}',
                          ),
                          initialValue: draft.bonusQty.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Bonus Qty'),
                          onChanged: (value) => onChanged(
                            draft.copyWith(
                              bonusQty: double.tryParse(value) ?? 0,
                              value: double.tryParse(value) ?? 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 230,
                        child: TextFormField(
                          key: ValueKey(
                            'bonus-eq-${draft.bonusQty.toStringAsFixed(2)}-${unitRate.toStringAsFixed(2)}',
                          ),
                          initialValue: (draft.bonusQty * unitRate)
                              .clamp(0, baseAmount)
                              .toStringAsFixed(2),
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Equivalent Discount Amount',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Applied as free quantity according to subscription rule',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: draft.discountMode,
                    decoration:
                        const InputDecoration(labelText: 'Discount Mode'),
                    items: const [
                      DropdownMenuItem(
                          value: 'PERCENT', child: Text('Percentage')),
                      DropdownMenuItem(value: 'AMOUNT', child: Text('Amount')),
                    ],
                    onChanged: (value) => onChanged(
                      draft.copyWith(discountMode: value ?? 'PERCENT'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: draft.discountMode == 'PERCENT'
                              ? draft.value.toStringAsFixed(2)
                              : draft.discountAmount.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: draft.discountMode == 'PERCENT'
                                ? 'Discount %'
                                : 'Discount Amount',
                          ),
                          onChanged: (value) {
                            final parsed = double.tryParse(value) ?? 0;
                            if (draft.discountMode == 'PERCENT') {
                              onChanged(
                                draft.copyWith(
                                  value: parsed,
                                  discountAmount: (baseAmount * parsed / 100)
                                      .clamp(0, baseAmount),
                                ),
                              );
                            } else {
                              onChanged(
                                draft.copyWith(
                                  discountAmount: parsed,
                                  value: parsed,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: draft.discountMode == 'PERCENT'
                              ? (baseAmount * draft.value / 100)
                                  .clamp(0, baseAmount)
                                  .toStringAsFixed(2)
                              : draft.discountAmount
                                  .clamp(0, baseAmount)
                                  .toStringAsFixed(2),
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Calculated Discount Amount',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              onChanged: (value) => onChanged(draft.copyWith(notes: value)),
            ),
          ],
        ),
      ),
    );
  }
}

