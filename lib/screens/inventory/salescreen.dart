import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:retailpos/screens/inventory/goods_receiving_screen.dart';
import 'package:retailpos/screens/modify/sales_reprint_modify_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/settings/ui_preferences_controller.dart';
import '../../core/billing/pos_billing_engine.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../models/inventory/billing_charge_model.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/sale_customer_model.dart';
import '../../models/inventory/sale_item_model.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/sale_scheme_model.dart';
import '../../models/inventory/tax_breakdown_model.dart';
import 'customer_list_screen.dart';
import '../reports/sales_report_screen.dart';
import '../settings/settings_screen.dart';
import 'item_master_screen.dart';
import 'subscription_screen.dart';

class SaleScreen extends StatefulWidget {
  final int? editSaleId;

  const SaleScreen({super.key, this.editSaleId});
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final ctrl = SalesController();
  final propertyCtrl = PropertyInfoController();
  final settingsCtrl = SystemSettingsController();

  final _saleNo = TextEditingController();
  final _saleDateCtrl = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerAddress = TextEditingController();
  final _customerGstin = TextEditingController();
  final _paymentRef = TextEditingController();
  final _amountPaid = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _barcode = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final _entryQty = TextEditingController(text: '1');
  final _manualDiscountValue = TextEditingController(text: '0');
  final _voucherCode = TextEditingController();

  final _schemeName = TextEditingController();
  final _schemeDiscountValue = TextEditingController(text: '0');
  final _schemeMinQty = TextEditingController(text: '0');
  final _schemeMinAmount = TextEditingController(text: '0');
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _schemeSelectionScrollController = ScrollController();
  final ScrollController _schemeStripScrollController = ScrollController();

  DateTime _saleDate = DateTime.now();
  String _paymentMode = 'CASH';
  String _manualDiscountType = 'AMOUNT';
  String _schemeUsageMode = 'APPLY_NOW';
  String _voucherUsageMode = 'APPLY_NOW';
  String _entryMode = 'SCAN';
  String _orderType = 'B2C';
  String _taxMode = 'CGST_SGST';
  String _billingCountry = 'India';
  String _billFormat = 'A4';
  String _selectedCatalogCategory = 'ALL';
  String _lastProcessedScanValue = '';
  DateTime _lastProcessedScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _skipNextSubmitAfterAutoScan = false;
  bool _isAutoScanProcessing = false;
  SaleCustomer? _selectedCustomer;
  Item? _selectedManualItem;
  SaleScheme? _selectedScheme;
  SaleScheme? _selectedItemScheme;
  String? _selectedIgstState;
  String? _selectedIgstStateCode;
  _VoucherDefinition? _appliedVoucher;
  TimeOfDay? _schemeStartTime;
  TimeOfDay? _schemeEndTime;
  bool _loadingItemSchemeStatus = false;
  bool _loadingItemAdvanceStatus = false;
  int _itemSchemeStatusRequestId = 0;
  Map<String, dynamic>? _itemSchemeProgress;
  final Map<int, Map<String, dynamic>> _itemSchemeProgressByScheme = {};
  final Set<int> _suppressedSchemeCustomerIds = <int>{};
  Map<String, dynamic>? _itemAdvanceSummary;
  final Map<int, Map<String, dynamic>> _itemAdvanceSummaries = {};
  final Map<int, double> _itemAdvanceAppliedQtyByItem = {};
  final Map<int, double> _itemAdvanceAppliedAmountByItem = {};
  List<Map<String, dynamic>> _customerItemAdvances = const [];
  List<Map<String, dynamic>> _customerSubscriptions = const [];
  bool _selectedCustomerSchemeSuppressed = false;
  final List<SaleScheme> _selectedSchemes = [];

  final List<SaleItem> _items = [];
  List<BillingCharge> _charges = const [];
  List<_VoucherDefinition> _voucherCatalog = const [];
  List<_PaymentLine> _paymentEntries = const [];
  List<Map<String, dynamic>> _previousCreditBills = const [];
  List<Map<String, dynamic>> _availableAdvanceEntries = const [];
  double _previousOutstandingAmount = 0;
  double _availableAdvanceAmount = 0;
  int _availableLoyaltyPoints = 0;
  double _loyaltyRedemptionValue = 1;
  int _loyaltyMaxRedeemPerBill = 0;
  bool _loyaltyProgramActive = false;
  int _redeemPointsInput = 0;
  double _pendingPreviousAdjustment = 0;
  double _pendingAdvanceApplied = 0;
  double _pendingAdvanceCreated = 0;
  String _cashierName = 'System';
  int _customerOutstandingRequestId = 0;
  int? _activeDraftId;
  int? _editingSaleId;
  bool _affectStockOnEdit = true;
  bool _schemeManuallyRemoved = false;
  bool get _showItemImages =>
      settingsCtrl.settings?.enableItemImagesInSales ?? false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await ctrl.loadInitialData();
      await propertyCtrl.load();
      await settingsCtrl.load();
      await _loadCashierName();
      _saleNo.text = await ctrl.getNextSaleNo();
      _saleDateCtrl.text = DateFormat('dd-MMM-yyyy HH:mm').format(_saleDate);
      _applyBillingDefaults();
      if (widget.editSaleId != null) {
        _editingSaleId = widget.editSaleId;
        await _loadExistingSaleForEdit(widget.editSaleId!);
      } else {
        _saleNo.text = await ctrl.getNextSaleNo();
        _saleDateCtrl.text = DateFormat('dd-MMM-yyyy HH:mm').format(_saleDate);
      }

      if (mounted) setState(() {});
    } catch (error) {
      _saleDateCtrl.text = DateFormat('dd-MMM-yyyy HH:mm').format(_saleDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _loadCashierName() async {
    final user = await TokenStorage.getUser();
    final resolved =
        (user?['name'] ?? user?['username'] ?? 'System').toString().trim();
    _cashierName = resolved.isEmpty ? 'System' : resolved;
  }

  Future<void> _loadExistingSaleForEdit(int saleId) async {
    final details = await ctrl.getSaleDetails(saleId);
    final order = SaleOrder.fromJson(details);
    final charges = (details['charges'] as List? ?? const [])
        .map((e) => BillingCharge.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    setState(() {
      _saleNo.text = order.saleNo;
      _saleDate = order.saleDate;
      _saleDateCtrl.text = DateFormat('dd-MMM-yyyy HH:mm').format(_saleDate);
      _orderType = order.orderType;
      _billingCountry = order.billingCountry;
      _taxMode = order.billingTaxMode;
      _billFormat = settingsCtrl.settings?.billFormat ?? order.billFormat;
      _paymentMode = order.paymentMode;
      _paymentRef.text = order.paymentReference ?? '';
      _amountPaid.text = order.amountPaid.toStringAsFixed(2);
      _paymentEntries = _decodePaymentEntries(
        order.paymentReference,
        fallbackMode: order.paymentMode,
        fallbackPaid: order.amountPaid,
        fallbackBalance: order.balanceDue,
      );
      _customerName.text = order.customerName ?? '';
      _customerPhone.text = order.customerPhone ?? '';
      _customerAddress.text = order.customerAddress ?? '';
      _customerGstin.text = order.customerGstin ?? '';
      _notes.text = order.notes ?? '';
      _manualDiscountType = order.manualDiscountType ?? 'AMOUNT';
      _manualDiscountValue.text = order.manualDiscountValue.toStringAsFixed(2);
      _items
        ..clear()
        ..addAll(order.items);
      _charges = charges.isEmpty ? _charges : charges;
      _selectedSchemes
        ..clear()
        ..addAll(order.selectedSchemes.where(
          (scheme) =>
              _availableSchemes.any((available) => available.id == scheme.id),
        ));
      _selectedScheme = _selectedSchemes.cast<SaleScheme?>().firstWhere(
                (scheme) => scheme?.schemeScope.toUpperCase() != 'ITEM',
                orElse: () => null,
              ) ??
          _availableSchemes.cast<SaleScheme?>().firstWhere(
                (scheme) => scheme?.id == order.schemeId,
                orElse: () => null,
              );
      _selectedItemScheme = _selectedSchemes.cast<SaleScheme?>().firstWhere(
            (scheme) => scheme?.schemeScope.toUpperCase() == 'ITEM',
            orElse: () => null,
          );
      _schemeUsageMode = 'APPLY_NOW';
      _schemeManuallyRemoved = false;
      _appliedVoucher = null;
      _voucherUsageMode = 'APPLY_NOW';
      _voucherCode.clear();
      _redeemPointsInput = order.loyaltyPointsRedeemed;
      _affectStockOnEdit = true;
    });
    if (_customerName.text.trim().isNotEmpty ||
        _customerPhone.text.trim().isNotEmpty) {
      await _loadCustomerOutstanding();
    }
  }

  Future<void> _loadVoucherCatalog() async {
    final vouchers = await ctrl.listVouchers();
    _voucherCatalog = vouchers.map(_VoucherDefinition.fromJson).toList();
  }

  void _applyBillingDefaults() {
    final settings = settingsCtrl.settings;
    if (settings == null) return;
    _billingCountry = settings.billingCountry;
    _taxMode = settings.billingTaxMode;
    _billFormat = settings.billFormat;
    _charges = settings.defaultCharges
        .map(
          (charge) => charge.copyWith(
            isEnabled: charge.autoApply || charge.isEnabled,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _saleNo.dispose();
    _saleDateCtrl.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _customerAddress.dispose();
    _customerGstin.dispose();
    _paymentRef.dispose();
    _amountPaid.dispose();
    _notes.dispose();
    _barcode.dispose();
    _barcodeFocusNode.dispose();
    _entryQty.dispose();
    _manualDiscountValue.dispose();
    _voucherCode.dispose();
    _schemeName.dispose();
    _schemeDiscountValue.dispose();
    _schemeMinQty.dispose();
    _schemeMinAmount.dispose();
    _categoryScrollController.dispose();
    _schemeSelectionScrollController.dispose();
    _schemeStripScrollController.dispose();
    settingsCtrl.dispose();
    super.dispose();
  }

  double get _subTotal => _items.fold(0, (sum, item) => sum + item.amount);
  double get _totalQty => _items.fold(0, (sum, item) => sum + item.qty);
  double get _schemeBaseAmount => _items
      .where((item) => item.schemeApplicable)
      .fold<double>(0, (sum, item) => sum + item.amount);

  double get _schemeFreeSavingsAmount {
    double savings = 0;
    for (final freeLine in _items.where((item) => item.isSchemeFree)) {
      double sourceRate = 0;
      for (final paidLine in _items) {
        if (paidLine.itemId == freeLine.itemId &&
            !paidLine.isSchemeFree &&
            !paidLine.isAdvanceFree) {
          sourceRate = paidLine.rate;
          break;
        }
      }
      savings += freeLine.qty * sourceRate;
    }
    return savings;
  }

  double get _totalSchemeSavingsAmount =>
      _schemeDiscountAmount + _schemeFreeSavingsAmount;

  static const double _retailRoundingTolerance = 0.05;
  static const double _cashRoundStep = 0.5;
  static const Map<String, String> _billFormatLabels = {
    'A4': 'A4 Invoice',
    'THERMAL_58': '58mm Thermal',
    'THERMAL_72': '72mm Thermal',
    'THERMAL_76': '76mm Thermal',
    'THERMAL_80': '80mm Thermal',
  };
  double _roundCurrency(double value) => double.parse(value.toStringAsFixed(2));
  double _roundToStep(double value, double step) {
    if (step <= 0) return _roundCurrency(value);
    return _roundCurrency((value / step).roundToDouble() * step);
  }

  bool get _isCashRoundApplicable {
    if (_paymentEntries.isEmpty) {
      return _paymentMode.toUpperCase() == 'CASH';
    }
    final active = _paymentEntries
        .where((entry) => (entry.amount) > _retailRoundingTolerance)
        .toList();
    if (active.isEmpty) return _paymentMode.toUpperCase() == 'CASH';
    return active.every((entry) => entry.method.toUpperCase() == 'CASH');
  }

  double _normalizeRetailAmount(double value) {
    return _roundCurrency(value);
  }

  double _positiveDelta(double value) =>
      value > _retailRoundingTolerance ? _roundCurrency(value) : 0;
  double _displayRetailTotal(double value) => _normalizeRetailAmount(value);
  double _displayLineTotal(SaleItem item) {
    return _displayRetailTotal(item.lineTotal);
  }

  double get _discountBaseAmount => _items
      .where((item) => item.discountApplicable)
      .fold<double>(0, (sum, item) => sum + item.amount);

  double get _schemeDiscountAmount {
    if (_schemeUsageMode != 'APPLY_NOW' ||
        _selectedScheme == null ||
        !_isSchemeEligible(_selectedScheme!)) return 0;
    return _discountAmount(
      baseAmount: _schemeBaseAmount,
      discountType: _selectedScheme!.discountType,
      discountValue: _selectedScheme!.discountValue,
    );
  }

  double get _manualDiscountAmount => _discountAmount(
        baseAmount: _discountBaseAmount,
        discountType: _manualDiscountType,
        discountValue: double.tryParse(_manualDiscountValue.text.trim()) ?? 0,
      );
  double get _voucherDiscountAmount {
    return 0;
  }

  int get _maxRedeemAllowedForBill {
    if (_loyaltyMaxRedeemPerBill <= 0) {
      return _availableLoyaltyPoints;
    }
    return math.min(_availableLoyaltyPoints, _loyaltyMaxRedeemPerBill);
  }

  double get _loyaltyDiscountAmount =>
      (_redeemPointsInput * _loyaltyRedemptionValue);

  double get _amountPaidValue => _currentPaymentState.collectedAmount;

  double get _effectiveAmountPaid {
    return _currentPaymentState.collectedAmount;
  }

  double get _refundAmount => _currentPaymentState.refundAmount;

  double get _balanceDueAmount => _currentPaymentState.balanceDue;

  _PaymentSummary get _currentPaymentState {
    final state = _summarizePayments(_resolvedPaymentEntries, _payableInvoiceTotal - _pendingAdvanceApplied);
    return _PaymentSummary(
      primaryMode: state.primaryMode,
      collectedAmount: state.collectedAmount,
      rawCollectedAmount: state.rawCollectedAmount,
      cashAmount: state.cashAmount,
      creditAmount: state.creditAmount,
      refundAmount: state.refundAmount,
      balanceDue: state.balanceDue,
      hasInvalidRefund: state.hasInvalidRefund,
      previousAdjustmentAmount: _pendingPreviousAdjustment,
      advanceAppliedAmount: _pendingAdvanceApplied,
      advanceCreatedAmount: _pendingAdvanceCreated,
      refundEnabled: state.refundEnabled,
    );
  }

  List<_PaymentLine> get _resolvedPaymentEntries {
    final normalized = _normalizePaymentEntries(
      _paymentEntries,
      invoiceTotal: _payableInvoiceTotal - _pendingAdvanceApplied,
      fallbackMode: _paymentMode,
      fallbackPaid: double.tryParse(_amountPaid.text.trim()),
    );
    return normalized.entries;
  }

  List<_PaymentLine> _paymentDialogSeedEntries() {
    final payableAfterAdvance = _payableInvoiceTotal;
    
    // Default to CASH ON DELIVERY for unpaid delivery CASH (CoD) orders
    if (_orderType == 'DELIVERY' && _paymentMode != 'CREDIT') {
      final paidVal = double.tryParse(_amountPaid.text.trim()) ?? 0.0;
      if (paidVal <= 0.009) {
        return <_PaymentLine>[
          _PaymentLine(method: 'CASH ON DELIVERY', amount: 0),
        ];
      }
    }

    final normalized = _resolvedPaymentEntries
        .map(
            (entry) => _PaymentLine(method: entry.method, amount: entry.amount))
        .toList();

    if (normalized.isEmpty) {
      return <_PaymentLine>[
        _PaymentLine(method: 'CASH', amount: payableAfterAdvance),
      ];
    }

    final positiveEntries =
        normalized.where((entry) => entry.amount > 0.009).toList();
    final positiveNonCreditEntries =
        positiveEntries.where((entry) => entry.method != 'CREDIT').toList();
    final hasSingleEditablePayment = positiveNonCreditEntries.length == 1 &&
        normalized.every((entry) =>
            entry.amount <= 0.009 ||
            entry.method == positiveNonCreditEntries.first.method ||
            entry.method == 'CREDIT');

    if (hasSingleEditablePayment) {
      final preservedMethod = positiveNonCreditEntries.first.method;
      return <_PaymentLine>[
        _PaymentLine(method: preservedMethod, amount: payableAfterAdvance),
      ];
    }

    return normalized;
  }

  String? get _voucherFooterMessage {
    final voucher = _appliedVoucher;
    if (voucher == null || _voucherUsageMode != 'NEXT_PURCHASE') return null;
    final discountText = voucher.discountType == 'PERCENT'
        ? '${voucher.discountValue.toStringAsFixed(voucher.discountValue % 1 == 0 ? 0 : 2)}% discount'
        : 'Rs. ${voucher.discountValue.toStringAsFixed(2)} discount';
    final minPurchase = voucher.minimumPurchaseAmount > 0
        ? ' on purchase above Rs. ${voucher.minimumPurchaseAmount.toStringAsFixed(2)}'
        : '';
    final validTo = voucher.validTo.trim().isEmpty
        ? ''
        : ' before ${voucher.validTo.trim()}';
    return 'Next purchase use voucher ${voucher.code} and get $discountText$minPurchase$validTo.';
  }

  String _formatSchemeBenefitText(SaleScheme scheme) {
    if (scheme.freeQty > 0) {
      return 'get ${scheme.freeQty.toStringAsFixed(scheme.freeQty % 1 == 0 ? 0 : 2)} qty free';
    }
    if (scheme.discountType.toUpperCase() == 'PERCENT') {
      return 'get ${scheme.discountValue.toStringAsFixed(scheme.discountValue % 1 == 0 ? 0 : 2)}% discount';
    }
    return 'get Rs. ${scheme.discountValue.toStringAsFixed(2)} discount';
  }

  String _formatSchemeConditionText(SaleScheme scheme) {
    final parts = <String>[];
    if (scheme.minQty > 0) {
      parts.add(
        'qty >= ${scheme.minQty.toStringAsFixed(scheme.minQty % 1 == 0 ? 0 : 2)}',
      );
    }
    if (scheme.minAmount > 0) {
      parts.add('purchase >= Rs. ${scheme.minAmount.toStringAsFixed(2)}');
    }
    if (scheme.requiredDailyQty > 0) {
      parts.add(
        'daily qty >= ${scheme.requiredDailyQty.toStringAsFixed(scheme.requiredDailyQty % 1 == 0 ? 0 : 2)}',
      );
    }
    return parts.isEmpty ? 'eligible purchase' : parts.join(', ');
  }

  String? get _schemeFooterMessage {
    if (_schemeUsageMode != 'NEXT_PURCHASE') return null;
    final nextPurchaseSchemes = _selectedSchemes
        .where((scheme) => scheme.applyTiming.toUpperCase() == 'NEXT_PURCHASE')
        .toList();
    if (nextPurchaseSchemes.isEmpty) return null;

    final messages = nextPurchaseSchemes.map((scheme) {
      final validDays =
          scheme.nextPurchaseValidDays > 0 ? scheme.nextPurchaseValidDays : 7;
      return '${scheme.schemeName}: ${_formatSchemeBenefitText(scheme)} on ${_formatSchemeConditionText(scheme)} (valid $validDays days).';
    }).toList();

    return 'Next purchase offer - ${messages.join(' ')}';
  }

  InvoiceComputation get _invoice => PosBillingEngine.compute(
        items: _items,
        taxMode: _taxMode,
        schemeDiscountAmount: _schemeDiscountAmount,
        manualDiscountAmount: _manualDiscountAmount +
            _voucherDiscountAmount +
            _loyaltyDiscountAmount,
        charges: _charges,
      );
  double get _payableInvoiceTotal {
    double rawTotal = math.max(_invoice.netAmount, 0);
    return _isCashRoundApplicable
        ? _roundToStep(rawTotal, _cashRoundStep)
        : _roundCurrency(rawTotal);
  }

  double get _billRoundOffAmount {
    final rawTotal = _roundCurrency(math.max(_invoice.netAmount, 0));
    return _roundCurrency(_payableInvoiceTotal - rawTotal);
  }

  double get _subscriptionItemAdvanceDiscount {
    return _itemAdvanceAppliedAmount;
  }

  double get _itemAdvanceAppliedAmount {
    if (_itemAdvanceAppliedAmountByItem.isEmpty) return 0;
    return _normalizeRetailAmount(
      _itemAdvanceAppliedAmountByItem.values.fold<double>(
        0,
        (sum, value) => sum + value,
      ),
    );
  }

  String get _billFormatLabel => _billFormatLabels[_billFormat] ?? 'A4 Invoice';

  bool get _isThermalBillFormat => _billFormat.startsWith('THERMAL_');

  List<SaleScheme> get _availableSchemes {
    final unique = <int, SaleScheme>{};
    for (final scheme in ctrl.schemes) {
      unique.putIfAbsent(scheme.id, () => scheme);
    }
    return unique.values.toList();
  }

  bool _isSchemeChipSelected(SaleScheme scheme) =>
      _selectedSchemes.any((item) => item.id == scheme.id);

  List<SaleScheme> get _selectedItemSchemes => _selectedSchemes
      .where(
        (scheme) =>
            scheme.schemeScope.toUpperCase() == 'ITEM' &&
            scheme.schemeType.toUpperCase() == 'CYCLE_ITEM_FREE',
      )
      .toList();

  int _selectedSchemeIndex(int schemeId) =>
      _selectedSchemes.indexWhere((item) => item.id == schemeId);

  SaleScheme? _lastSelectedSchemeByScope(String scope) {
    for (var i = _selectedSchemes.length - 1; i >= 0; i--) {
      final scheme = _selectedSchemes[i];
      if (scheme.schemeScope.toUpperCase() == scope.toUpperCase()) {
        return scheme;
      }
    }
    return null;
  }

  void _removeSelectedSchemeById(int schemeId) {
    _selectedSchemes.removeWhere((scheme) => scheme.id == schemeId);
  }

  void _syncSelectedSchemePointers() {
    if (_selectedScheme != null && !_isSchemeChipSelected(_selectedScheme!)) {
      _selectedScheme = _lastSelectedSchemeByScope('ORDER');
    }
    if (_selectedItemScheme != null &&
        !_isSchemeChipSelected(_selectedItemScheme!)) {
      _selectedItemScheme = _lastSelectedSchemeByScope('ITEM');
    }
    if (_selectedScheme == null && _selectedItemScheme == null) {
      _schemeUsageMode = 'APPLY_NOW';
    }
  }

  void _pruneSelectedSchemesToAvailable() {
    final availableIds = _availableSchemes.map((scheme) => scheme.id).toSet();
    _selectedSchemes.removeWhere((scheme) => !availableIds.contains(scheme.id));
    if (_selectedScheme != null &&
        !availableIds.contains(_selectedScheme!.id)) {
      _selectedScheme = _lastSelectedSchemeByScope('ORDER');
    }
    if (_selectedItemScheme != null &&
        !availableIds.contains(_selectedItemScheme!.id)) {
      _selectedItemScheme = _lastSelectedSchemeByScope('ITEM');
    }
  }

  bool get _hasCustomerContext =>
      _selectedCustomer != null ||
      (_customerName.text.trim().isNotEmpty &&
          _customerPhone.text.trim().isNotEmpty);

  List<SaleScheme> get _eligibleSchemes => !_hasCustomerContext
      ? const <SaleScheme>[]
      : _availableSchemes.where(_isSchemeEligible).toList();

  String get _schemeFeedbackMessage {
    final scheme = _selectedScheme ??
        _selectedItemScheme ??
        (_selectedSchemes.isNotEmpty ? _selectedSchemes.last : null);
    if (!_hasCustomerContext) {
      return 'Select a customer to enable scheme selection.';
    }
    if (scheme == null) {
      return _eligibleSchemes.isNotEmpty
          ? 'Eligible scheme available: ${_eligibleSchemes.first.schemeName}'
          : 'No scheme selected. Select a scheme or create one.';
    }
    final repeatText =
        scheme.repeatMode.toUpperCase() == 'ONCE' ? 'One-time' : 'Repeat';
    final timingText = scheme.applyTiming.toUpperCase() == 'NEXT_PURCHASE'
        ? 'Next purchase'
        : 'Current bill';
    if (_schemeUsageMode == 'NEXT_PURCHASE') {
      return '$repeatText scheme reserved for next purchase: ${scheme.schemeName}';
    }
    if (_isSchemeEligible(scheme)) {
      return 'Scheme applied: ${scheme.schemeName} ($repeatText, $timingText)';
    }
    switch (scheme.schemeType) {
      case 'TIME':
        return 'Scheme not active now. Allowed time: ${scheme.startTime ?? '--:--'} to ${scheme.endTime ?? '--:--'}';
      case 'QTY':
        return 'Scheme pending. Minimum qty ${scheme.minQty.toStringAsFixed(0)} required.';
      case 'VALUE':
        return 'Scheme pending. Minimum bill ${scheme.minAmount.toStringAsFixed(2)} required.';
      default:
        return 'Scheme selected but not eligible yet.';
    }
  }

  Color get _schemeFeedbackColor {
    final scheme = _selectedScheme ??
        _selectedItemScheme ??
        (_selectedSchemes.isNotEmpty ? _selectedSchemes.last : null);
    if (scheme != null && _isSchemeEligible(scheme)) {
      return const Color(0xFFE8F7EE);
    }
    if (_eligibleSchemes.isNotEmpty) return const Color(0xFFFFF4DB);
    return const Color(0xFFF0F4FA);
  }

  double _discountAmount({
    required double baseAmount,
    required String discountType,
    required double discountValue,
  }) {
    if (discountValue <= 0 || baseAmount <= 0) return 0;
    if (discountType == 'PERCENT') return (baseAmount * discountValue) / 100;
    return discountValue > baseAmount ? baseAmount : discountValue;
  }

  bool _isSchemeEligible(SaleScheme scheme) {
    if (!scheme.isActive || _items.isEmpty || _schemeBaseAmount <= 0)
      return false;
    if (scheme.schemeType == 'TIME') {
      if (scheme.startTime == null || scheme.endTime == null) return false;
      final now = TimeOfDay.fromDateTime(DateTime.now());
      final current = now.hour * 60 + now.minute;
      final start = _minutesFromHm(scheme.startTime!);
      final end = _minutesFromHm(scheme.endTime!);
      return current >= start && current <= end;
    }
    if (scheme.schemeType == 'QTY') {
      final eligibleQty = _items
          .where((item) => item.schemeApplicable)
          .fold<double>(0, (sum, item) => sum + item.qty);
      return eligibleQty >= scheme.minQty;
    }
    if (scheme.schemeType == 'VALUE')
      return _schemeBaseAmount >= scheme.minAmount;
    return false;
  }

  void _clearManualDiscount() {
    setState(() {
      _manualDiscountType = 'AMOUNT';
      _manualDiscountValue.text = '0';
      _syncAmountPaidWithInvoice();
    });
  }

  void _clearAllCharges() {
    setState(() {
      _charges = _charges
          .map(
            (charge) => charge.copyWith(
              isEnabled: false,
              amount: 0,
              calculationValue: 0,
            ),
          )
          .toList();
      _syncAmountPaidWithInvoice();
    });
  }

  Widget _tintedActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    String? tooltip,
  }) {
    final button = Container(
      decoration: BoxDecoration(
        color: onPressed == null
            ? backgroundColor.withValues(alpha: 0.35)
            : backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: foregroundColor),
        visualDensity: VisualDensity.compact,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _customerIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: foregroundColor),
      ),
    );
  }

  int _minutesFromHm(String hm) {
    final parts = hm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _schemeDefaultUsageMode(SaleScheme scheme) {
    if (scheme.applyTiming.toUpperCase() == 'NEXT_PURCHASE') {
      // For first reservation bill -> NEXT_PURCHASE.
      // For linked future bills -> APPLY_NOW so next purchase can consume.
      return scheme.customerLinked ? 'APPLY_NOW' : 'NEXT_PURCHASE';
    }
    return 'APPLY_NOW';
  }

  bool _schemeAlreadyGrantedThisCycle(SaleScheme scheme) {
    if (_itemSchemeProgress == null) return false;
    final progress = Map<String, dynamic>.from(
      _itemSchemeProgress?['progress'] ?? const <String, dynamic>{},
    );
    return progress['already_granted_today'] == true &&
        (_selectedCustomer?.schemeId == scheme.id ||
            _selectedItemScheme?.id == scheme.id);
  }

  Future<void> _deactivateSchemeForCurrentCustomer(SaleScheme scheme) async {
    if (!_hasCustomerContext) return;
    try {
      final rows = await ctrl.listSchemeCustomers(scheme.id);
      final phone = _customerPhone.text.trim();
      final gstin = _customerGstin.text.trim().toUpperCase();
      final name = _customerName.text.trim().toUpperCase();

      bool matches(Map<String, dynamic> row) {
        final rowPhone = (row['customer_phone'] ?? '').toString().trim();
        final rowGstin =
            (row['customer_gstin'] ?? '').toString().trim().toUpperCase();
        final rowName =
            (row['customer_name'] ?? '').toString().trim().toUpperCase();
        if (phone.isNotEmpty && rowPhone.isNotEmpty) return rowPhone == phone;
        if (gstin.isNotEmpty && rowGstin.isNotEmpty) return rowGstin == gstin;
        if (name.isNotEmpty && rowName.isNotEmpty) return rowName == name;
        return false;
      }

      final activeRows = rows.where((row) {
        final isActive = row['is_active'] == true;
        return isActive && matches(row);
      }).toList();
      for (final row in activeRows) {
        final customerId = int.tryParse(row['id']?.toString() ?? '') ?? 0;
        if (customerId <= 0) continue;
        await ctrl.updateSchemeCustomer(
          schemeId: scheme.id,
          customerId: customerId,
          isActive: false,
        );
      }
      await ctrl.refreshSchemes(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // Keep billing smooth even if unlink API fails.
    }
  }

  void _refreshSelectedScheme() {
    _pruneSelectedSchemesToAvailable();
    if (!_hasCustomerContext) {
      _selectedSchemes.clear();
      _selectedScheme = null;
      _selectedItemScheme = null;
      _schemeUsageMode = 'APPLY_NOW';
      _itemSchemeProgress = null;
      _itemSchemeProgressByScheme.clear();
      _schemeManuallyRemoved = false;
      _selectedCustomerSchemeSuppressed = false;
      return;
    }
    if (_schemeManuallyRemoved) {
      return;
    }
    SaleScheme? preferred;
    if (!_schemeManuallyRemoved && _selectedCustomer?.schemeId != null) {
      preferred = _availableSchemes.cast<SaleScheme?>().firstWhere(
            (scheme) => scheme?.id == _selectedCustomer!.schemeId,
            orElse: () => null,
          );
    }
    preferred ??= _availableSchemes.cast<SaleScheme?>().firstWhere(
          (scheme) => scheme?.customerLinked == true,
          orElse: () => null,
        );
    if (preferred != null &&
        (preferred.autoSelectOnCustomer ||
            preferred.customerLinked ||
            preferred.repeatMode.toUpperCase() == 'REPEAT' ||
            preferred.applyTiming.toUpperCase() == 'NEXT_PURCHASE')) {
      if (_selectedCustomerSchemeSuppressed && preferred.customerLinked) {
        _removeSelectedSchemeById(preferred.id);
        if (preferred.schemeScope.toUpperCase() == 'ITEM') {
          _selectedItemScheme = null;
        } else {
          _selectedScheme = null;
        }
        return;
      }
      if (preferred.repeatMode.toUpperCase() == 'ONCE' &&
          (_selectedCustomerSchemeSuppressed ||
              _schemeAlreadyGrantedThisCycle(preferred))) {
        _removeSelectedSchemeById(preferred.id);
        _selectedItemScheme = null;
        return;
      }
      if (!_isSchemeChipSelected(preferred)) {
        _selectedSchemes.add(preferred);
      }
      for (final linked in _availableSchemes.where(
        (scheme) => scheme.customerLinked == true,
      )) {
        if (_selectedCustomerSchemeSuppressed) {
          _removeSelectedSchemeById(linked.id);
          continue;
        }
        if (linked.repeatMode.toUpperCase() == 'ONCE' &&
            (_selectedCustomerSchemeSuppressed ||
                _schemeAlreadyGrantedThisCycle(linked))) {
          _removeSelectedSchemeById(linked.id);
          continue;
        }
        if (!_isSchemeChipSelected(linked)) {
          _selectedSchemes.add(linked);
        }
      }
      if (preferred.schemeScope.toUpperCase() == 'ITEM') {
        _selectedItemScheme = preferred;
      } else {
        _selectedScheme = preferred;
      }
      _schemeUsageMode = _schemeDefaultUsageMode(preferred);
      return;
    }
    if (_selectedItemScheme != null) {
      final refreshedSelection =
          _availableSchemes.cast<SaleScheme?>().firstWhere(
                (scheme) => scheme?.id == _selectedItemScheme!.id,
                orElse: () => null,
              );
      if (refreshedSelection != null) {
        if (refreshedSelection.repeatMode.toUpperCase() == 'ONCE' &&
            (_selectedCustomerSchemeSuppressed ||
                _schemeAlreadyGrantedThisCycle(refreshedSelection))) {
          _removeSelectedSchemeById(refreshedSelection.id);
          _selectedItemScheme = null;
          return;
        }
        if (!_isSchemeChipSelected(refreshedSelection)) {
          _selectedSchemes.add(refreshedSelection);
        }
        if (refreshedSelection.schemeScope.toUpperCase() == 'ITEM') {
          _selectedItemScheme = refreshedSelection;
        } else {
          _selectedScheme = refreshedSelection;
        }
        _schemeUsageMode = _schemeDefaultUsageMode(refreshedSelection);
        return;
      }
    }
    _selectedItemScheme = null;
  }

  void _setSelectedScheme(SaleScheme? scheme, {bool manual = false}) {
    SaleScheme? removedScheme;
    setState(() {
      final previous = _selectedScheme;
      if (previous != null) {
        _removeSelectedSchemeById(previous.id);
        removedScheme = previous;
      }
      _selectedScheme = scheme;
      if (scheme == null) {
        _schemeUsageMode = 'APPLY_NOW';
      } else if (_schemeUsageMode == 'APPLY_NOW' ||
          _schemeUsageMode == 'NEXT_PURCHASE') {
        _schemeUsageMode = _schemeDefaultUsageMode(scheme);
        if (!_isSchemeChipSelected(scheme)) {
          _selectedSchemes.add(scheme);
        }
      }
      if (manual) {
        _schemeManuallyRemoved = scheme == null;
        if (scheme == null) {
          _selectedCustomerSchemeSuppressed = true;
          if (_selectedCustomer != null) {
            _suppressedSchemeCustomerIds.add(_selectedCustomer!.id);
          }
        } else {
          _selectedCustomerSchemeSuppressed = false;
          if (_selectedCustomer != null) {
            _suppressedSchemeCustomerIds.remove(_selectedCustomer!.id);
          }
        }
      }
    });
    if (manual && scheme == null && removedScheme != null) {
      _deactivateSchemeForCurrentCustomer(removedScheme!);
    }
    _refreshItemSchemeStatus();
    setState(() {
      _rebuildItemSchemeFreeLines();
    });
    _syncAmountPaidWithInvoice();
  }

  void _setSelectedItemScheme(SaleScheme? scheme, {bool manual = false}) {
    SaleScheme? removedScheme;
    setState(() {
      final previous = _selectedItemScheme;
      if (previous != null) {
        _removeSelectedSchemeById(previous.id);
        removedScheme = previous;
      }
      _selectedItemScheme = scheme;
      if (scheme == null) {
        _schemeUsageMode = 'APPLY_NOW';
      } else if (_schemeUsageMode == 'APPLY_NOW' ||
          _schemeUsageMode == 'NEXT_PURCHASE') {
        _schemeUsageMode = _schemeDefaultUsageMode(scheme);
        if (!_isSchemeChipSelected(scheme)) {
          _selectedSchemes.add(scheme);
        }
      }
      if (manual) {
        _schemeManuallyRemoved = scheme == null;
        if (scheme == null) {
          _selectedCustomerSchemeSuppressed = true;
          if (_selectedCustomer != null) {
            _suppressedSchemeCustomerIds.add(_selectedCustomer!.id);
          }
        } else {
          _selectedCustomerSchemeSuppressed = false;
          if (_selectedCustomer != null) {
            _suppressedSchemeCustomerIds.remove(_selectedCustomer!.id);
          }
        }
      }
      _itemSchemeProgress = null;
      if (scheme == null) {
        _itemSchemeProgressByScheme.clear();
      }
    });
    if (manual && scheme == null && removedScheme != null) {
      _deactivateSchemeForCurrentCustomer(removedScheme!);
    }
    _refreshItemSchemeStatus();
    setState(() {
      _rebuildItemSchemeFreeLines();
    });
    _syncAmountPaidWithInvoice();
  }

  void _toggleSelectedSchemeChip(SaleScheme scheme) {
    bool shouldUnlink = false;
    setState(() {
      final isRemoving = _isSchemeChipSelected(scheme);
      if (isRemoving) {
        _removeSelectedSchemeById(scheme.id);
        _schemeManuallyRemoved = true;
        _selectedCustomerSchemeSuppressed = true;
        shouldUnlink = true;
        if (_selectedCustomer != null) {
          _suppressedSchemeCustomerIds.add(_selectedCustomer!.id);
        }
        if (_selectedScheme?.id == scheme.id) {
          _selectedScheme = _lastSelectedSchemeByScope('ORDER');
        }
        if (_selectedItemScheme?.id == scheme.id) {
          _selectedItemScheme = _lastSelectedSchemeByScope('ITEM');
        }
        if (_selectedScheme == null && _selectedItemScheme == null) {
          _schemeUsageMode = 'APPLY_NOW';
        }
      } else {
        if (!_isSchemeChipSelected(scheme)) {
          _selectedSchemes.add(scheme);
        }
        if (scheme.schemeScope.toUpperCase() == 'ITEM') {
          _selectedItemScheme = scheme;
        } else {
          _selectedScheme = scheme;
        }
        _schemeManuallyRemoved = false;
        _selectedCustomerSchemeSuppressed = false;
        if (_selectedCustomer != null) {
          _suppressedSchemeCustomerIds.remove(_selectedCustomer!.id);
        }
      }
    });
    if (shouldUnlink) {
      _deactivateSchemeForCurrentCustomer(scheme);
    }
    _refreshSelectedScheme();
    _refreshItemSchemeStatus();
    setState(() {
      _rebuildItemSchemeFreeLines();
    });
    _syncAmountPaidWithInvoice();
  }

  Future<void> _selectSchemeWithUsage(
    SaleScheme? scheme, {
    bool preserveExistingSelections = false,
  }) async {
    if (scheme == null) {
      _setSelectedScheme(null, manual: true);
      return;
    }
    final selectedUsage = scheme.applyTiming.toUpperCase() == 'NEXT_PURCHASE'
        ? 'NEXT_PURCHASE'
        : 'APPLY_NOW';
    if (selectedUsage == 'APPLY_NOW' &&
        _schemeAlreadyGrantedThisCycle(scheme)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This scheme has already been used for today.'),
          ),
        );
      }
      return;
    }
    if (preserveExistingSelections) {
      setState(() => _schemeUsageMode = selectedUsage);
      if (!_isSchemeChipSelected(scheme)) {
        _toggleSelectedSchemeChip(scheme);
      } else {
        _refreshSelectedScheme();
        _refreshItemSchemeStatus();
        setState(() {
          _rebuildItemSchemeFreeLines();
        });
        _syncAmountPaidWithInvoice();
      }
      return;
    }
    if (scheme.schemeScope.toUpperCase() == 'ITEM') {
      setState(() => _schemeUsageMode = selectedUsage);
      _setSelectedItemScheme(scheme);
    } else {
      setState(() {
        _schemeUsageMode = selectedUsage;
        _selectedScheme = scheme;
        _schemeManuallyRemoved = false;
        if (!_isSchemeChipSelected(scheme)) {
          _selectedSchemes.add(scheme);
        }
      });
      _syncAmountPaidWithInvoice();
    }
  }

  _NormalizedPaymentEntries _normalizePaymentEntries(
    List<_PaymentLine> rawEntries, {
    required double invoiceTotal,
    String? fallbackMode,
    double? fallbackPaid,
  }) {
    final mode = (fallbackMode ?? _paymentMode).trim().toUpperCase();
    final paid = fallbackPaid ?? (double.tryParse(_amountPaid.text.trim()) ?? 0.0);
    final isCodOrder = _orderType == 'DELIVERY' && mode != 'CREDIT' && paid <= 0.009;

    var seedEntries = rawEntries.isEmpty
        ? (invoiceTotal <= 0.009
            ? <_PaymentLine>[]
            : [
                _PaymentLine(
                  method: mode,
                  amount: mode == 'CREDIT'
                      ? 0
                      : paid,
                ),
              ])
        : rawEntries;

    if (isCodOrder) {
      final hasOtherPayments = seedEntries.any((e) =>
          e.method != 'CASH' &&
          e.method != 'CASH ON DELIVERY' &&
          e.amount > 0.009);
      if (!hasOtherPayments) {
        seedEntries = [
          const _PaymentLine(method: 'CASH ON DELIVERY', amount: 0),
        ];
      }
    }

    final buckets = <String, double>{};
    for (final entry in seedEntries) {
      final method = entry.method.trim().toUpperCase();
      double amount = _roundCurrency(entry.amount < 0 ? 0 : entry.amount);
      if (amount <= 0.009 && method != 'CREDIT' && method != 'CASH ON DELIVERY') continue;
      buckets.update(method, (value) => value + amount, ifAbsent: () => amount);
    }

    final hasCod = buckets.containsKey('CASH ON DELIVERY');

    final nonCreditTotal = _roundCurrency(buckets.entries
        .where((entry) => entry.key != 'CREDIT' && entry.key != 'CASH ON DELIVERY')
        .fold<double>(0, (sum, entry) => sum + entry.value));
    final payableInvoiceTotal = _normalizeRetailAmount(invoiceTotal);
    double expectedCredit =
        _positiveDelta(payableInvoiceTotal - nonCreditTotal);
    double finalCredit = expectedCredit;
    if (finalCredit > 0.009) {
      if (hasCod) {
        buckets['CASH ON DELIVERY'] = 0;
      } else {
        buckets['CREDIT'] = _roundCurrency(finalCredit);
      }
    } else {
      buckets.remove('CREDIT');
    }

    final entries = buckets.entries
        .map((entry) => _PaymentLine(method: entry.key, amount: entry.value))
        .toList()
      ..sort((a, b) => _paymentMethodOrder(a.method)
          .compareTo(_paymentMethodOrder(b.method)));
    return _NormalizedPaymentEntries(
      entries: entries,
      summary: _summarizePayments(entries, payableInvoiceTotal),
    );
  }

  _PaymentSummary _summarizePayments(List<_PaymentLine> entries, [double? invoiceTotalOverride]) {
    double cash = 0;
    double nonCredit = 0;
    double credit = 0;
    final hasCod = entries.any((entry) => entry.method == 'CASH ON DELIVERY');
    for (final entry in entries) {
      final method = entry.method.trim().toUpperCase();
      if (method == 'CASH') cash += entry.amount;
      if (method == 'CREDIT') {
        credit += entry.amount;
      } else if (method != 'CASH ON DELIVERY') {
        nonCredit += entry.amount;
      }
    }

    final invoiceTotal = invoiceTotalOverride ?? _payableInvoiceTotal;
    double overpay = _positiveDelta(nonCredit - invoiceTotal);
    double refund = cash >= overpay ? overpay : 0;
    final invalidRefund = overpay > cash;
    final collectedApplied = nonCredit - refund;
    double balanceDue = _positiveDelta(invoiceTotal - collectedApplied);
    final primaryMode = entries
        .firstWhere(
          (entry) => entry.method != 'CREDIT' && entry.method != 'CASH ON DELIVERY',
          orElse: () => entries.isNotEmpty
              ? entries.first
              : const _PaymentLine(method: 'CASH', amount: 0),
        )
        .method;

    return _PaymentSummary(
      primaryMode: hasCod
          ? 'CASH'
          : (balanceDue > 0 && collectedApplied <= 0 ? 'CREDIT' : primaryMode),
      collectedAmount: collectedApplied,
      rawCollectedAmount: nonCredit,
      cashAmount: cash,
      creditAmount: hasCod ? 0 : (credit > balanceDue ? credit : balanceDue),
      refundAmount: refund,
      balanceDue: balanceDue,
      hasInvalidRefund: invalidRefund,
      previousAdjustmentAmount: 0,
      advanceAppliedAmount: 0,
      advanceCreatedAmount: 0,
      refundEnabled: refund > 0,
    );
  }

  int _paymentMethodOrder(String method) {
    switch (method) {
      case 'CASH':
        return 0;
      case 'CARD':
        return 1;
      case 'UPI':
        return 2;
      case 'BANK':
        return 3;
      case 'CREDIT':
        return 4;
      default:
        return 5;
    }
  }

  String _encodePaymentReference(List<_PaymentLine> entries) {
    final payload = entries
        .map((entry) => {'method': entry.method, 'amount': entry.amount})
        .toList();
    return 'POSPAY:${jsonEncode(payload)}';
  }

  List<_PaymentLine> _decodePaymentEntries(
    String? rawReference, {
    required String fallbackMode,
    required double fallbackPaid,
    required double fallbackBalance,
  }) {
    final raw = (rawReference ?? '').trim();
    if (raw.startsWith('POSPAY:')) {
      try {
        final decoded = jsonDecode(raw.substring(7));
        if (decoded is List) {
          return decoded
              .map(
                (entry) => _PaymentLine(
                  method: (entry['method'] ?? 'CASH').toString(),
                  amount:
                      double.tryParse((entry['amount'] ?? 0).toString()) ?? 0,
                ),
              )
              .toList();
        }
      } catch (_) {}
    }
    final fallback = <_PaymentLine>[
      _PaymentLine(method: fallbackMode, amount: fallbackPaid),
    ];
    if (fallbackBalance > 0) {
      fallback.add(_PaymentLine(method: 'CREDIT', amount: fallbackBalance));
    }
    return fallback;
  }

  String _paymentSummaryText(List<_PaymentLine> entries) {
    if (entries.isEmpty) return 'No payment selected';
    final summary = entries
        .where((entry) => entry.amount > 0)
        .map(
          (entry) =>
              '${entry.method[0]}${entry.method.substring(1).toLowerCase()} ${entry.amount.toStringAsFixed(2)}',
        )
        .join('  |  ');
    return summary.isEmpty ? 'No payment selected' : summary;
  }

  Item? _findItem(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return null;
    for (final item in ctrl.items) {
      if (!item.isSaleable) continue;
      if (item.barcode.toLowerCase() == value ||
          item.itemCode.toLowerCase() == value ||
          item.itemName.toLowerCase() == value) {
        return item;
      }
    }
    for (final item in ctrl.items) {
      if (!item.isSaleable) continue;
      if (item.barcode.toLowerCase().contains(value) ||
          item.itemCode.toLowerCase().contains(value) ||
          item.itemName.toLowerCase().contains(value)) {
        return item;
      }
    }
    return null;
  }

  Item? _findItemExactForScan(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return null;
    for (final item in ctrl.items) {
      if (!item.isSaleable) continue;
      if (item.barcode.toLowerCase() == value ||
          item.itemCode.toLowerCase() == value) {
        return item;
      }
    }
    // Handle scanner bursts where the same barcode is appended repeatedly:
    // keep matching against suffix chunks so the last scanned code still works.
    for (final item in ctrl.items) {
      if (!item.isSaleable) continue;
      final barcode = item.barcode.toLowerCase().trim();
      final itemCode = item.itemCode.toLowerCase().trim();
      if (barcode.isNotEmpty && value.endsWith(barcode)) return item;
      if (itemCode.isNotEmpty && value.endsWith(itemCode)) return item;
    }
    return null;
  }

  List<Item> _suggestedItems(String query) {
    final value = query.trim().toLowerCase();
    final saleableItems = ctrl.items.where((item) => item.isSaleable).toList();
    if (value.isEmpty) return saleableItems.take(10).toList();
    return saleableItems
        .where((item) {
          return item.itemCode.toLowerCase().contains(value) ||
              item.itemName.toLowerCase().contains(value) ||
              item.barcode.toLowerCase().contains(value);
        })
        .take(10)
        .toList();
  }

  double _entryQtyValue() {
    final qty = double.tryParse(_entryQty.text.trim()) ?? 1;
    return qty <= 0 ? 1 : qty;
  }

  double _defaultRateForItemId(int itemId) {
    final item = ctrl.items.cast<Item?>().firstWhere(
          (it) => it?.id == itemId,
          orElse: () => null,
        );
    if (item == null) return 0;
    return item.retailSalePrice > 0 ? item.retailSalePrice : item.rate;
  }

  void _syncCartRatesWithLatestCatalog() {
    for (var i = 0; i < _items.length; i++) {
      final line = _items[i];
      if (line.isAdvanceFree || line.isSchemeFree) continue;
      final latestRate = _defaultRateForItemId(line.itemId);
      if ((line.rate - latestRate).abs() < 0.0001) continue;
      _items[i] = line.copyWith(rate: latestRate, referenceRate: latestRate);
    }
  }

  double _totalCartQtyForItemId(int itemId) {
    return _items
        .where((line) => line.itemId == itemId)
        .fold<double>(0, (sum, line) => sum + line.qty);
  }

  SaleItem _buildBaseSaleItem({
    required Item item,
    required double qty,
    SaleItem? seed,
  }) {
    final defaultRate =
        item.retailSalePrice > 0 ? item.retailSalePrice : item.rate;
    return SaleItem(
      itemId: item.id,
      itemCode: seed?.itemCode ?? item.itemCode,
      itemName: seed?.itemName ?? item.itemName,
      hsnSacCode: seed?.hsnSacCode ?? item.hsnSacCode,
      barcode: seed?.barcode ?? item.barcode,
      unit: seed?.unit ?? item.unit,
      qty: qty,
      originalQty: qty,
      rate: seed?.rate ?? defaultRate,
      taxType: seed?.taxType ?? item.taxType,
      taxPercent: seed?.taxPercent ?? item.taxPercent,
      discountApplicable: seed?.discountApplicable ?? item.discountApplicable,
      schemeApplicable: seed?.schemeApplicable ?? item.schemeApplicable,
    );
  }

  List<BillingCharge> get _activeCharges =>
      _charges.where((charge) => charge.isEnabled).toList();

  void _focusBarcodeField() {
    if (!mounted) return;
    void requestIfNeeded() {
      if (!mounted) return;
      if (!_barcodeFocusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_barcodeFocusNode);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestIfNeeded();
      Future.delayed(const Duration(milliseconds: 60), requestIfNeeded);
      Future.delayed(const Duration(milliseconds: 180), requestIfNeeded);
      Future.delayed(const Duration(milliseconds: 360), requestIfNeeded);
    });
  }

  Future<void> _handleQuickEntry() async {
    if (_skipNextSubmitAfterAutoScan) {
      _skipNextSubmitAfterAutoScan = false;
      return;
    }
    final item = _entryMode == 'MANUAL'
        ? (_selectedManualItem ?? _findItem(_barcode.text))
        : _findItem(_barcode.text);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No product found. Scan barcode or search item again.'),
        ),
      );
      setState(() {
        _barcode.clear();
        _selectedManualItem = null;
      });
      _focusBarcodeField();
      return;
    }
    if (_hasCustomerContext) {
      await _ensureItemAdvanceSummary(item);
    }
    _addOrUpdateItem(item, qty: _entryQtyValue());
    setState(() {
      _barcode.clear();
      _selectedManualItem = null;
      _entryQty.text = '1';
    });
    _focusBarcodeField();
  }

  Future<void> _tryAutoAddScannedItem(String rawValue) async {
    if (_entryMode != 'SCAN') return;
    if (_isAutoScanProcessing) return;
    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final now = DateTime.now();
    final isDuplicateBurst = normalized == _lastProcessedScanValue &&
        now.difference(_lastProcessedScanAt).inMilliseconds < 900;
    if (isDuplicateBurst) return;

    final item = _findItemExactForScan(rawValue);
    if (item == null) {
      // If scanner keeps flooding a long unresolved value, reset field.
      if (normalized.length > 40 && mounted) {
        setState(() => _barcode.clear());
      }
      return;
    }
    _isAutoScanProcessing = true;
    try {
      if (mounted) {
        setState(() {
          _barcode.clear();
          _selectedManualItem = null;
          _entryQty.text = '1';
        });
        _focusBarcodeField();
      }
      if (_hasCustomerContext) {
        await _ensureItemAdvanceSummary(item);
      }
      _addOrUpdateItem(item, qty: 1);
      _focusBarcodeField();
      _lastProcessedScanValue = normalized;
      _lastProcessedScanAt = now;
      _skipNextSubmitAfterAutoScan = true;
    } finally {
      _isAutoScanProcessing = false;
    }
  }

  Future<void> _ensureItemAdvanceSummary(Item item) async {
    if (!_hasCustomerContext) return;
    final cached = _itemAdvanceSummaries[item.id];
    if (cached != null) return;
    try {
      final advanceRes = await ctrl.getItemAdvanceSummary(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        itemId: item.id,
        asOfDate: _saleDate,
      );
      if (!mounted) return;
      _itemAdvanceSummaries[item.id] = Map<String, dynamic>.from(advanceRes);
    } catch (_) {
      // Ignore missing advance data; the item just behaves like a normal sale line.
    }
  }

  void _addOrUpdateItem(Item item, {required double qty}) {
    if (qty <= 0) return;
    final existingLines =
        _items.where((line) => line.itemId == item.id).toList();
    final existingTotalQty =
        existingLines.fold<double>(0, (sum, line) => sum + line.qty);
    SaleItem? seed;
    for (final line in existingLines) {
      if (!line.isAdvanceFree && !line.isSchemeFree) {
        seed = line;
        break;
      }
    }
    final nextQty = existingTotalQty + qty;
    setState(() {
      _paymentEntries = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _items.removeWhere((line) => line.itemId == item.id);
      if (nextQty > 0) {
        _items.insert(
            0, _buildBaseSaleItem(item: item, qty: nextQty, seed: seed));
      }
      _syncSelectedSchemePointers();
      _rebuildItemAdvanceFreeLines();
      _rebuildItemSchemeFreeLines();
      _syncAmountPaidWithInvoice();
    });
  }

  void _updateLineQty(int index, double qty) {
    final line = _items[index];
    final isFreeLine = line.isAdvanceFree || line.isSchemeFree;

    // For split rows (paid + free), qty edits on the paid row should preserve
    // already-generated free quantity and only change payable quantity.
    if (!isFreeLine) {
      final freeQtyForItem = _items
          .where(
            (row) =>
                row.itemId == line.itemId &&
                (row.isAdvanceFree || row.isSchemeFree),
          )
          .fold<double>(0, (sum, row) => sum + row.qty);
      final paidQty = qty <= 0 ? 0 : qty;
      final totalQty = paidQty + freeQtyForItem;

      if (totalQty <= 0) {
        _removeCartItemGroupById(line.itemId);
        return;
      }

      setState(() {
        _paymentEntries = const [];
        _pendingPreviousAdjustment = 0;
        _pendingAdvanceApplied = 0;
        _pendingAdvanceCreated = 0;
        _items.removeWhere((row) => row.itemId == line.itemId);
        _items.insert(
          0,
          line.copyWith(
            qty: totalQty,
            originalQty: totalQty,
            isAdvanceFree: false,
            isSchemeFree: false,
            appliedSchemeId: null,
          ),
        );
        _syncSelectedSchemePointers();
        _rebuildItemAdvanceFreeLines();
        _rebuildItemSchemeFreeLines();
        _syncAmountPaidWithInvoice();
      });
      return;
    }

    if (qty <= 0) {
      setState(() {
        _paymentEntries = const [];
        _pendingPreviousAdjustment = 0;
        _pendingAdvanceApplied = 0;
        _pendingAdvanceCreated = 0;
        _items.removeAt(index);
        _syncSelectedSchemePointers();
        _rebuildItemAdvanceFreeLines();
        _rebuildItemSchemeFreeLines();
        _syncAmountPaidWithInvoice();
      });
      return;
    }
    setState(() {
      _paymentEntries = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _items[index] = _items[index].copyWith(qty: qty, originalQty: qty);
      _syncSelectedSchemePointers();
      _rebuildItemAdvanceFreeLines();
      _rebuildItemSchemeFreeLines();
      _syncAmountPaidWithInvoice();
    });
  }

  void _removeCartItemGroupById(int itemId) {
    setState(() {
      _paymentEntries = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _items.removeWhere((line) => line.itemId == itemId);
      _syncSelectedSchemePointers();
      _rebuildItemAdvanceFreeLines();
      _rebuildItemSchemeFreeLines();
      _syncAmountPaidWithInvoice();
    });
  }

  void _syncAmountPaidWithInvoice() {
    final isCod = _orderType == 'DELIVERY' &&
        (_paymentMode == 'CASH ON DELIVERY' ||
            (_paymentMode != 'CREDIT' && (double.tryParse(_amountPaid.text.trim()) ?? 0.0) <= 0.009));
    if (isCod) {
      _amountPaid.text = '0';
      return;
    }

    if (_paymentEntries.isNotEmpty) return;
    if (_paymentMode == 'CREDIT') {
      _amountPaid.text = '0';
      return;
    }
    final total = _payableInvoiceTotal;
    _amountPaid.text = total.toStringAsFixed(2);
  }

  Future<void> _editQtyDialog(int index) async {
    final controller = TextEditingController(
      text:
          _items[index].qty.toStringAsFixed(_items[index].qty % 1 == 0 ? 0 : 2),
    );
    final qty = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: controller,
          autofocus: !context.watch<UiPreferencesController>().touchMode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            helperText: 'Example: 1, 5, 12.5 or 100',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (qty != null) _updateLineQty(index, qty);
  }

  Future<void> _editTaxDialog(int index) async {
    final item = _items[index];
    String tempTaxType = item.taxType.isEmpty ? 'GST' : item.taxType;
    final percentController = TextEditingController(
      text: item.taxPercent.toStringAsFixed(item.taxPercent % 1 == 0 ? 0 : 2),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Tax'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempTaxType,
                  decoration: const InputDecoration(labelText: 'Tax Type'),
                  items: const [
                    DropdownMenuItem(value: 'GST', child: Text('GST')),
                    DropdownMenuItem(value: 'IGST', child: Text('IGST')),
                    DropdownMenuItem(value: 'VAT', child: Text('VAT')),
                    DropdownMenuItem(value: 'NONE', child: Text('No Tax')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => tempTaxType = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: percentController,
                  autofocus: !context.watch<UiPreferencesController>().touchMode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tax Percentage',
                    helperText: 'Example: 0, 5, 12, 18',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final newPercent = double.tryParse(percentController.text.trim()) ?? item.taxPercent;
                  setState(() {
                    _items[index] = item.copyWith(
                      taxType: tempTaxType,
                      taxPercent: newPercent,
                    );
                    _syncAmountPaidWithInvoice();
                  });
                  Navigator.pop(dialogContext);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
    percentController.dispose();
  }

  Future<void> _applyCustomer(SaleCustomer customer) async {
    final isSameCustomer = _selectedCustomer?.id == customer.id;
    final preserveManualSchemeRemoval = isSameCustomer;
    setState(() {
      _selectedCustomer = customer;
      _customerPhone.text = customer.customerPhone;
      _customerName.text = customer.customerName;
      _customerAddress.text = customer.customerAddress;
      _customerGstin.text = customer.customerGstin;
      _schemeManuallyRemoved =
          preserveManualSchemeRemoval ? _schemeManuallyRemoved : false;
      _selectedCustomerSchemeSuppressed =
          _suppressedSchemeCustomerIds.contains(customer.id);
      if (!isSameCustomer) {
        _selectedSchemes.clear();
        _selectedScheme = null;
        _selectedItemScheme = null;
        _schemeUsageMode = 'APPLY_NOW';
        _itemSchemeProgress = null;
        _itemSchemeProgressByScheme.clear();
      }
      _itemAdvanceSummaries.clear();
      _customerItemAdvances = const [];
      _customerSubscriptions = const [];
      _redeemPointsInput = 0;
    });
    await ctrl.refreshSchemes(
      customerName: _customerName.text.trim(),
      customerPhone: _customerPhone.text.trim(),
      customerGstin: _customerGstin.text.trim(),
    );
    if (!mounted) return;
    _loadCustomerOutstanding();
    _refreshSelectedItemAdvanceStatus();
    await _refreshSelectedCustomerSchemeStatus();
    setState(() {
      _pruneSelectedSchemesToAvailable();
      _refreshSelectedScheme();
    });
    _refreshItemSchemeStatus();
  }

  Future<void> _refreshItemSchemeStatus() async {
    final requestId = ++_itemSchemeStatusRequestId;
    if (!_hasCustomerContext) {
      if (mounted) {
        setState(() {
          _itemSchemeProgress = null;
          _itemSchemeProgressByScheme.clear();
          _itemAdvanceSummary = null;
        });
      }
      return;
    }

    final itemSchemes = _selectedItemSchemes;
    if (itemSchemes.isEmpty) {
      if (mounted) {
        setState(() {
          _itemSchemeProgress = null;
          _itemSchemeProgressByScheme.clear();
          _itemAdvanceSummary = null;
        });
      }
      return;
    }

    setState(() {
      _loadingItemSchemeStatus = true;
      _itemSchemeProgress = null;
    });
    try {
      final progressByScheme = <int, Map<String, dynamic>>{};
      final advanceByItem = <int, Map<String, dynamic>>{};
      for (final scheme in itemSchemes) {
        final itemId = scheme.itemId;
        if (itemId == null || itemId <= 0) continue;
        final hasAdvanceFreeForItem =
            _items.any((it) => it.itemId == itemId && it.isAdvanceFree);
        if (hasAdvanceFreeForItem) continue;

        final progressRes = await ctrl.getSchemeProgress(
          schemeId: scheme.id,
          customerName: _customerName.text.trim(),
          customerPhone: _customerPhone.text.trim(),
          customerGstin: _customerGstin.text.trim(),
          date: _saleDate,
        );
        progressByScheme[scheme.id] = Map<String, dynamic>.from(progressRes);

        if (!advanceByItem.containsKey(itemId)) {
          final advanceRes = await ctrl.getItemAdvanceSummary(
            customerName: _customerName.text.trim(),
            customerPhone: _customerPhone.text.trim(),
            customerGstin: _customerGstin.text.trim(),
            itemId: itemId,
            asOfDate: _saleDate,
          );
          advanceByItem[itemId] = Map<String, dynamic>.from(advanceRes);
        }
      }
      if (!mounted || requestId != _itemSchemeStatusRequestId) return;
      setState(() {
        _itemSchemeProgressByScheme
          ..clear()
          ..addAll(progressByScheme);
        final currentSchemeId = _selectedItemScheme?.id;
        _itemSchemeProgress = currentSchemeId == null
            ? null
            : _itemSchemeProgressByScheme[currentSchemeId];
        if (_selectedManualItem != null) {
          _itemAdvanceSummary = advanceByItem[_selectedManualItem!.id];
        } else {
          _itemAdvanceSummary = null;
        }
        _rebuildItemAdvanceFreeLines();
        // Apply/refresh item-wise scheme free-qty lines so the discount is visible on the bill.
        _rebuildItemSchemeFreeLines();
        _syncAmountPaidWithInvoice();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _itemSchemeProgress = null;
        _itemSchemeProgressByScheme.clear();
        _itemAdvanceSummary = null;
      });
    } finally {
      if (mounted) setState(() => _loadingItemSchemeStatus = false);
    }
  }

  Future<void> _refreshSelectedItemAdvanceStatus() async {
    if (!_hasCustomerContext || _selectedManualItem == null) {
      if (mounted) {
        setState(() => _loadingItemAdvanceStatus = false);
      }
      return;
    }

    final item = _selectedManualItem!;
    setState(() => _loadingItemAdvanceStatus = true);
    try {
      final advanceRes = await ctrl.getItemAdvanceSummary(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        itemId: item.id,
        asOfDate: _saleDate,
      );
      if (!mounted) return;
      setState(() {
        _itemAdvanceSummaries[item.id] = Map<String, dynamic>.from(advanceRes);
        _rebuildItemAdvanceFreeLines();
        _syncAmountPaidWithInvoice();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _itemAdvanceSummaries.remove(item.id);
      });
    } finally {
      if (mounted) setState(() => _loadingItemAdvanceStatus = false);
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  double _availableAdvanceQtyForItem(int itemId) {
    double subscriptionQty = 0;
    bool hasSubscriptionRow = false;
    for (final row in _customerSubscriptions) {
      final rowItemId = int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
      if (rowItemId != itemId) continue;
      hasSubscriptionRow = true;
      final remainingToday = _num(row['today_remaining_qty']);
      if (remainingToday > 0) {
        subscriptionQty += remainingToday;
      }
    }
    if (hasSubscriptionRow) {
      // Subscription flow is day-capped. If today's remaining qty is 0, do not
      // fall back to lifetime/item-advance balance for the same item.
      return subscriptionQty;
    }

    final summary = _itemAdvanceSummaries[itemId];
    if (summary != null) {
      final summaryQty = _num(
        summary['remaining_qty_total'] ??
            summary['remaining_qty'] ??
            summary['available_qty'],
      );
      if (summaryQty > 0) return summaryQty;
    }

    final rows = _customerItemAdvances
        .where((row) =>
            (int.tryParse(row['item_id']?.toString() ?? '') ?? 0) == itemId)
        .toList();
    if (rows.isEmpty) return 0;

    return rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          _num(
            row['remaining_qty_total'] ??
                row['remaining_qty'] ??
                row['available_qty'],
          ),
    );
  }

  void _rebuildItemAdvanceFreeLines() {
    _itemAdvanceAppliedQtyByItem.clear();
    _itemAdvanceAppliedAmountByItem.clear();

    if (!_hasCustomerContext) {
      _items.removeWhere((line) => line.isAdvanceFree);
      return;
    }
    if (_customerItemAdvances.isEmpty && _customerSubscriptions.isEmpty) {
      // Keep already-split free lines if backend summary is still loading.
      // This prevents valid subscription free rows from disappearing on save/use payment.
      return;
    }

    final sourceItems =
        List<SaleItem>.from(_items.where((line) => !line.isAdvanceFree));
    final sourceItemIds = sourceItems.map((line) => line.itemId).toSet();
    final existingAdvanceFreeOnly = _items
        .where((line) =>
            line.isAdvanceFree && !sourceItemIds.contains(line.itemId))
        .toList(growable: false);
    if (sourceItems.isEmpty) {
      final hasAnyAdvanceCoverage = _customerSubscriptions.isNotEmpty ||
          _itemAdvanceSummaries.values.any((summary) {
            final remainingQty = _num(
              summary['remaining_qty_total'] ??
                  summary['remaining_qty'] ??
                  summary['available_qty'],
            );
            return remainingQty > 0;
          }) ||
          _customerItemAdvances.any((row) {
            final remainingQty = _num(
              row['remaining_qty_total'] ??
                  row['remaining_qty'] ??
                  row['available_qty'],
            );
            return remainingQty > 0;
          });
      if (!hasAnyAdvanceCoverage) {
        _items.removeWhere((line) => line.isAdvanceFree);
        return;
      }
      for (final line in _items.where((line) => line.isAdvanceFree)) {
        final qty = line.qty;
        if (qty <= 0) continue;
        _itemAdvanceAppliedQtyByItem[line.itemId] =
            (_itemAdvanceAppliedQtyByItem[line.itemId] ?? 0) + qty;
        _itemAdvanceAppliedAmountByItem[line.itemId] =
            (_itemAdvanceAppliedAmountByItem[line.itemId] ?? 0) +
                (qty *
                    (line.rate > 0
                        ? line.rate
                        : _defaultRateForItemId(line.itemId)));
      }
      // Cart already contains only free rows. Do not clear them on rebuild.
      return;
    }
    final rebuiltItems = <SaleItem>[];
    final remainingByItem = <int, double>{};

    for (final source in sourceItems) {
      if (source.isSchemeFree) {
        rebuiltItems.add(source);
        continue;
      }

      final itemId = source.itemId;
      final availableAdvance = _availableAdvanceQtyForItem(itemId);
      final alreadyConsumed = remainingByItem[itemId] ?? 0;
      double remainingFree = math.max(availableAdvance - alreadyConsumed, 0);
      final currentQty =
          source.originalQty > 0 ? source.originalQty : source.qty;

      if (remainingFree <= 0 || currentQty <= 0) {
        rebuiltItems.add(source);
        continue;
      }

      final freeQty = math.min(currentQty, remainingFree);
      final paidQty = currentQty - freeQty;

      if (paidQty > 0) {
        rebuiltItems
            .add(source.copyWith(qty: paidQty, originalQty: currentQty));
      }

      if (freeQty > 0) {
        rebuiltItems.add(
          SaleItem(
            itemId: source.itemId,
            itemCode: source.itemCode,
            itemName: source.itemName,
            hsnSacCode: source.hsnSacCode,
            barcode: source.barcode,
            unit: source.unit,
            qty: freeQty,
            originalQty: currentQty,
            rate: 0,
            referenceRate: source.rate,
            taxType: source.taxType,
            taxPercent: source.taxPercent,
            discountApplicable: false,
            schemeApplicable: false,
            isAdvanceFree: true,
          ),
        );
        _itemAdvanceAppliedQtyByItem[itemId] =
            (_itemAdvanceAppliedQtyByItem[itemId] ?? 0) + freeQty;
        _itemAdvanceAppliedAmountByItem[itemId] =
            (_itemAdvanceAppliedAmountByItem[itemId] ?? 0) +
                (freeQty * source.rate);
        remainingByItem[itemId] = alreadyConsumed + freeQty;
      }
    }

    if (existingAdvanceFreeOnly.isNotEmpty) {
      for (final freeLine in existingAdvanceFreeOnly) {
        final qty = freeLine.qty;
        if (qty <= 0) continue;
        _itemAdvanceAppliedQtyByItem[freeLine.itemId] =
            (_itemAdvanceAppliedQtyByItem[freeLine.itemId] ?? 0) + qty;
        final baseRate = freeLine.rate > 0
            ? freeLine.rate
            : _defaultRateForItemId(freeLine.itemId);
        _itemAdvanceAppliedAmountByItem[freeLine.itemId] =
            (_itemAdvanceAppliedAmountByItem[freeLine.itemId] ?? 0) +
                (qty * baseRate);
        rebuiltItems.add(freeLine);
      }
    }

    _items
      ..clear()
      ..addAll(rebuiltItems);
  }

  // Item-wise scheme: convert up to `free_qty` from the scheme item into a rate=0 line
  // (so payable decreases, not extra qty added).
  //
  // This relies on `_itemSchemeProgress` (enrollment + progress) already loaded.
  void _rebuildItemSchemeFreeLines() {
    final schemes = _selectedItemSchemes;
    if (schemes.isEmpty) return;
    if (_schemeUsageMode != 'APPLY_NOW') return;

    final selectedSchemeIds = schemes.map((scheme) => scheme.id).toSet();
    final schemeItemIds = schemes
        .map((scheme) => scheme.itemId ?? 0)
        .where((itemId) => itemId > 0)
        .toSet();

    // Normalize each scheme item back to one paid/base line before reapplying
    // free split, so repeated rebuilds do not reduce qty line-by-line.
    for (final itemId in schemeItemIds) {
      final schemeScopedLines = _items
          .where(
            (it) =>
                it.itemId == itemId &&
                !it.isAdvanceFree &&
                (!it.isSchemeFree ||
                    selectedSchemeIds.contains(it.appliedSchemeId)),
          )
          .toList();
      if (schemeScopedLines.isEmpty) continue;

      final restoredQty = schemeScopedLines.fold<double>(
        0,
        (sum, it) => sum + it.qty,
      );
      if (restoredQty <= 0) continue;

      final seed = schemeScopedLines.cast<SaleItem?>().firstWhere(
                (it) => it != null && !it.isSchemeFree,
                orElse: () => null,
              ) ??
          schemeScopedLines.first;
      final resolvedRate =
          seed.rate > 0 ? seed.rate : _defaultRateForItemId(itemId);

      _items.removeWhere(
        (it) =>
            it.itemId == itemId &&
            !it.isAdvanceFree &&
            (!it.isSchemeFree ||
                selectedSchemeIds.contains(it.appliedSchemeId)),
      );
      _items.insert(
        0,
        seed.copyWith(
          qty: restoredQty,
          originalQty: restoredQty,
          rate: resolvedRate,
          isSchemeFree: false,
          appliedSchemeId: null,
        ),
      );
    }

    final appliedForItem = <int>{};
    for (final scheme in schemes) {
      final itemId = scheme.itemId;
      if (itemId == null || itemId <= 0) continue;
      if (appliedForItem.contains(itemId)) continue;

      final data = _itemSchemeProgressByScheme[scheme.id] ??
          (scheme.id == _selectedItemScheme?.id ? _itemSchemeProgress : null);
      final enrolled = data != null && data['enrolled'] == true;
      if (!enrolled) continue;

      final progress = Map<String, dynamic>.from(
        data['progress'] ?? const <String, dynamic>{},
      );
      if (progress['already_granted_today'] == true) continue;

      final minQty =
          scheme.minQty > 0 ? scheme.minQty : _num(progress['min_qty']);
      final freeQty =
          scheme.freeQty > 0 ? scheme.freeQty : _num(progress['free_qty']);
      final requiredQty = scheme.requiredDailyQty > 0
          ? scheme.requiredDailyQty
          : _num(progress['required_daily_qty']);
      if (freeQty <= 0) continue;

      final billQty = _items
          .where((it) =>
              it.itemId == itemId && !it.isSchemeFree && !it.isAdvanceFree)
          .fold<double>(0, (sum, it) => sum + it.qty);
      if (billQty <= 0) continue;

      final totalBefore = _num(progress['total_qty']);
      final totalIncludingCurrent = totalBefore + billQty;
      if (minQty > 0 && totalIncludingCurrent + 1e-9 < minQty) continue;
      if (requiredQty <= 0 || billQty < requiredQty) continue;

      if (progress['require_no_gaps'] == true) {
        final missing = (progress['missing_days'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final todayKey = DateFormat('yyyy-MM-dd').format(_saleDate);
        final effectiveMissing = billQty > 0
            ? missing.where((d) => d != todayKey).toList()
            : missing;
        if (effectiveMissing.isNotEmpty) continue;
      }

      double remainingFree = freeQty.clamp(0, billQty);
      for (int i = 0; i < _items.length && remainingFree > 0; i++) {
        final it = _items[i];
        if (it.itemId != itemId || it.isSchemeFree || it.isAdvanceFree) {
          continue;
        }
        if (it.qty <= 0) continue;

        final take = remainingFree < it.qty ? remainingFree : it.qty;
        if (take <= 0) continue;

        final freeLine = SaleItem(
          itemId: it.itemId,
          itemCode: it.itemCode,
          itemName: it.itemName,
          hsnSacCode: it.hsnSacCode,
          barcode: it.barcode,
          unit: it.unit,
          qty: take,
          originalQty: it.originalQty > 0 ? it.originalQty : it.qty,
          rate: 0,
          referenceRate: it.rate,
          taxType: it.taxType,
          taxPercent: it.taxPercent,
          discountApplicable: false,
          schemeApplicable: false,
          isSchemeFree: true,
          appliedSchemeId: scheme.id,
        );

        if (take >= it.qty - 1e-9) {
          _items[i] = freeLine;
        } else {
          _items[i] = it.copyWith(
            qty: it.qty - take,
            originalQty: it.originalQty > 0 ? it.originalQty : it.qty,
          );
          _items.insert(i + 1, freeLine);
          i++;
        }

        remainingFree -= take;
      }
      appliedForItem.add(itemId);
    }
  }

  Future<void> _openSalesReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesReportScreen()),
    );
  }

  Future<void> _openCustomerListScreen() async {
    final selectedCustomer = await Navigator.push<SaleCustomer>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerListScreen()),
    );
    await ctrl.refreshCustomers();
    if (!mounted || selectedCustomer == null) return;
    _applyCustomer(selectedCustomer);
  }

  Future<void> _showCustomerPickerDialog() async {
    await ctrl.refreshCustomers();
    SaleCustomer? selected = _selectedCustomer;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Customer'),
        content: SizedBox(
          width: 420,
          child: DropdownSearch<SaleCustomer>(
            selectedItem: selected,
            items: (filter, _) async => filter.isEmpty
                ? ctrl.customers
                : await ctrl.searchCustomers(filter),
            itemAsString: (customer) => customer.displayLabel,
            compareFn: (first, second) => first.id == second.id,
            popupProps: const PopupProps.menu(showSearchBox: true),
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: 'Search Existing Customer',
                hintText: 'Search by name or mobile',
              ),
            ),
            onChanged: (customer) => selected = customer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              if (selected != null) {
                _applyCustomer(selected!);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Use Customer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomerDialog({bool clearSelection = true}) async {
    final nameCtrl = TextEditingController(text: _customerName.text);
    final phoneCtrl = TextEditingController(text: _customerPhone.text);
    final addressCtrl = TextEditingController(text: _customerAddress.text);
    final gstCtrl = TextEditingController(text: _customerGstin.text);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clearSelection ? 'Add Customer' : 'Edit Customer Details'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact No'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstCtrl,
                decoration: const InputDecoration(labelText: 'GST No'),
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
            onPressed: () async {
              final customerName = nameCtrl.text.trim();
              final customerPhone = phoneCtrl.text.trim();
              final customerAddress = addressCtrl.text.trim();
              final customerGstin = gstCtrl.text.trim();

              if (customerName.isEmpty && customerPhone.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter customer name or contact no.'),
                  ),
                );
                return;
              }

              try {
                Map<String, dynamic>? savedCustomer;
                if (!clearSelection && _selectedCustomer != null) {
                  await ctrl.updateCustomer(
                    _selectedCustomer!.id,
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerAddress: customerAddress,
                    customerGstin: customerGstin,
                  );
                  savedCustomer = {
                    'id': _selectedCustomer!.id,
                    'customer_name': customerName,
                    'customer_phone': customerPhone,
                    'customer_address': customerAddress,
                    'customer_gstin': customerGstin,
                    'scheme_id': _selectedCustomer!.schemeId,
                    'scheme_name': _selectedCustomer!.schemeName,
                  };
                } else {
                  savedCustomer = await ctrl.createCustomer(
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerAddress: customerAddress,
                    customerGstin: customerGstin,
                  );
                }

                if (!mounted) return;
                final persisted = SaleCustomer.fromJson(savedCustomer);
                await _applyCustomer(persisted);
                _schemeManuallyRemoved = false;
                _refreshSelectedScheme();
                if (context.mounted) {
                  Navigator.pop(context);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer saved to database successfully.'),
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditExistingCustomerDialog(SaleCustomer customer) async {
    final nameCtrl = TextEditingController(text: customer.customerName);
    final phoneCtrl = TextEditingController(text: customer.customerPhone);
    final addressCtrl = TextEditingController(text: customer.customerAddress);
    final gstCtrl = TextEditingController(text: customer.customerGstin);
    var hasExistingBills = false;

    try {
      final searchKey = customer.customerPhone.trim().isNotEmpty
          ? customer.customerPhone.trim()
          : customer.customerName.trim();
      if (searchKey.isNotEmpty) {
        final summary = await ctrl.getCustomerCreditSummary(searchKey);
        hasExistingBills = (summary['bills'] as List? ?? const []).isNotEmpty;
      }
    } catch (_) {
      hasExistingBills = false;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                readOnly: hasExistingBills,
                decoration: InputDecoration(
                  labelText: 'Contact No',
                  helperText: hasExistingBills
                      ? 'Phone number is locked because this customer already has bills.'
                      : 'Phone number can be updated because there are no bills yet.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstCtrl,
                decoration: const InputDecoration(labelText: 'GST No'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ctrl.updateCustomer(
                customer.id,
                customerName: nameCtrl.text.trim(),
                customerPhone: phoneCtrl.text.trim(),
                customerAddress: addressCtrl.text.trim(),
                customerGstin: gstCtrl.text.trim(),
              );
              if (!mounted) return;
              if (_selectedCustomer?.id == customer.id) {
                _applyCustomer(
                  SaleCustomer(
                    id: customer.id,
                    customerName: nameCtrl.text.trim(),
                    customerPhone: phoneCtrl.text.trim(),
                    customerAddress: addressCtrl.text.trim(),
                    customerGstin: gstCtrl.text.trim(),
                    schemeId: customer.schemeId,
                    schemeName: customer.schemeName,
                  ),
                );
              }
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCustomerListExcel(List<SaleCustomer> customers) async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Customers'];
    final headers = ['Name', 'Number', 'Address', 'GSTIN'];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = exc.TextCellValue(headers[i]);
    }

    for (var row = 0; row < customers.length; row++) {
      final customer = customers[row];
      final values = [
        customer.customerName.trim().isEmpty
            ? 'Walk-in Customer'
            : customer.customerName.trim(),
        customer.customerPhone,
        customer.customerAddress,
        customer.customerGstin,
      ];
      for (var col = 0; col < values.length; col++) {
        sheet
            .cell(
              exc.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: row + 1,
              ),
            )
            .value = exc.TextCellValue(values[col]);
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/customer_list_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> _exportCustomerListPdf(List<SaleCustomer> customers) async {
    final pdf = pw.Document();
    final rows = customers
        .map(
          (customer) => [
            customer.customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : customer.customerName.trim(),
            customer.customerPhone,
            customer.customerAddress,
            customer.customerGstin,
          ],
        )
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Customer List',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const ['Name', 'Number', 'Address', 'GSTIN'],
            data: rows,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _showManageCustomersDialog() async {
    await ctrl.refreshCustomers();
    if (!mounted) return;

    final searchCtrl = TextEditingController();
    var customers = List<SaleCustomer>.from(ctrl.customers);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> reloadCustomers([String search = '']) async {
            await ctrl.refreshCustomers(search: search);
            if (!dialogContext.mounted) return;
            setDialogState(() {
              customers = List<SaleCustomer>.from(ctrl.customers);
            });
          }

          return AlertDialog(
            title: const Text('Customer List'),
            content: SizedBox(
              width: 900,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 420,
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Search customer',
                            hintText: 'Name, phone, address, GSTIN',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => reloadCustomers(value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: 'Export customer list to Excel',
                        child: OutlinedButton.icon(
                          onPressed: customers.isEmpty
                              ? null
                              : () => _exportCustomerListExcel(customers),
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Excel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Export customer list to PDF',
                        child: OutlinedButton.icon(
                          onPressed: customers.isEmpty
                              ? null
                              : () => _exportCustomerListPdf(customers),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: customers.isEmpty
                        ? const Center(child: Text('No customers found'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Number')),
                                DataColumn(label: Text('Address')),
                                DataColumn(label: Text('GSTIN')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: customers.map((customer) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(
                                      customer.customerName.trim().isEmpty
                                          ? 'Walk-in Customer'
                                          : customer.customerName.trim(),
                                    )),
                                    DataCell(Text(customer.customerPhone)),
                                    DataCell(Text(customer.customerAddress)),
                                    DataCell(Text(customer.customerGstin)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Use Customer',
                                            onPressed: () {
                                              Navigator.pop(dialogContext);
                                              _applyCustomer(customer);
                                            },
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit Customer',
                                            onPressed: () async {
                                              await _showEditExistingCustomerDialog(
                                                customer,
                                              );
                                              await reloadCustomers(
                                                searchCtrl.text,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete Customer',
                                            onPressed: () async {
                                              await ctrl.deleteCustomer(
                                                customer.id,
                                              );
                                              if (!mounted) return;
                                              if (_selectedCustomer?.id ==
                                                  customer.id) {
                                                _setGuestCustomer();
                                              }
                                              await reloadCustomers(
                                                searchCtrl.text,
                                              );
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Customer removed successfully',
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _setGuestCustomer() {
    _customerOutstandingRequestId++;
    setState(() {
      _selectedCustomer = null;
      _customerName.clear();
      _customerPhone.clear();
      _customerAddress.clear();
      _customerGstin.clear();
      _paymentRef.clear();
      _amountPaid.text = '0';
      _paymentEntries = const [];
      _previousCreditBills = const [];
      _availableAdvanceEntries = const [];
      _previousOutstandingAmount = 0;
      _availableAdvanceAmount = 0;
      _availableLoyaltyPoints = 0;
      _redeemPointsInput = 0;
      _loyaltyProgramActive = false;
      _loyaltyRedemptionValue = 1;
      _loyaltyMaxRedeemPerBill = 0;
      _customerItemAdvances = const [];
      _customerSubscriptions = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _schemeManuallyRemoved = false;
      _selectedSchemes.clear();
      _selectedScheme = null;
      _selectedItemScheme = null;
      _schemeUsageMode = 'APPLY_NOW';
      _itemSchemeProgress = null;
      _itemSchemeProgressByScheme.clear();
      _refreshSelectedScheme();
    });
    _syncAmountPaidWithInvoice();
  }

  Future<void> _loadCustomerOutstanding() async {
    final requestId = ++_customerOutstandingRequestId;
    final search = _customerPhone.text.trim().isNotEmpty
        ? _customerPhone.text.trim()
        : _customerName.text.trim();
    if (search.isEmpty) {
      if (!mounted) return;
      setState(() {
        _previousCreditBills = const [];
        _availableAdvanceEntries = const [];
        _customerItemAdvances = const [];
        _customerSubscriptions = const [];
        _previousOutstandingAmount = 0;
        _availableAdvanceAmount = 0;
        _availableLoyaltyPoints = 0;
        _redeemPointsInput = 0;
        _loyaltyProgramActive = false;
        _loyaltyRedemptionValue = 1;
        _loyaltyMaxRedeemPerBill = 0;
        _selectedSchemes.clear();
        _selectedScheme = null;
        _selectedItemScheme = null;
        _schemeUsageMode = 'APPLY_NOW';
        _itemSchemeProgress = null;
        _itemSchemeProgressByScheme.clear();
      });
      return;
    }
    try {
      final summary = await ctrl.getCustomerCreditSummary(search);
      final latestSearch = _customerPhone.text.trim().isNotEmpty
          ? _customerPhone.text.trim()
          : _customerName.text.trim();
      if (!mounted || requestId != _customerOutstandingRequestId) return;
      if (latestSearch != search || latestSearch.isEmpty) return;
      setState(() {
        _previousCreditBills = (summary['bills'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _availableAdvanceEntries = (summary['advances'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _previousOutstandingAmount =
            double.tryParse((summary['total_outstanding'] ?? 0).toString()) ??
                0;
        _availableAdvanceAmount =
            double.tryParse((summary['total_advance'] ?? 0).toString()) ?? 0;
      });

      final subscriptions = await ctrl.listCustomerSubscriptions(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        date: _saleDate,
      );
      if (!mounted || requestId != _customerOutstandingRequestId) return;

      final advances = await ctrl.listItemAdvances(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
      );
      if (!mounted || requestId != _customerOutstandingRequestId) return;
      final advanceSummaryByItem = <int, Map<String, dynamic>>{};
      for (final row in advances) {
        final itemId = int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
        if (itemId <= 0) continue;
        final current = advanceSummaryByItem[itemId];
        final originalQty = _num(row['original_qty']);
        final availableQty = _num(
          row['remaining_qty_total'] ??
              row['remaining_qty'] ??
              row['available_qty'],
        );
        if (current == null) {
          advanceSummaryByItem[itemId] = {
            'item_id': itemId,
            'item_name': row['item_name'],
            'item_code': row['item_code'],
            'original_qty': originalQty,
            'consumed_qty': originalQty - availableQty,
            'remaining_qty': availableQty,
          };
        } else {
          current['original_qty'] = _num(current['original_qty']) + originalQty;
          current['consumed_qty'] =
              _num(current['consumed_qty']) + (originalQty - availableQty);
          current['remaining_qty'] =
              _num(current['remaining_qty']) + availableQty;
        }
      }
      setState(() {
        _customerSubscriptions = subscriptions;
        _customerItemAdvances = advances;
        _itemAdvanceSummaries
          ..clear()
          ..addAll(advanceSummaryByItem);
        _rebuildItemAdvanceFreeLines();
      });
      await _loadCustomerLoyaltySummary(requestId: requestId);
    } catch (_) {}
  }

  Future<void> _loadCustomerLoyaltySummary({required int requestId}) async {
    try {
      final summary = await ctrl.getCustomerLoyaltySummary(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
      );
      if (!mounted || requestId != _customerOutstandingRequestId) return;
      setState(() {
        _availableLoyaltyPoints =
            int.tryParse((summary['available_points'] ?? 0).toString()) ?? 0;
        _loyaltyRedemptionValue =
            double.tryParse((summary['redemption_value'] ?? 1).toString()) ?? 1;
        _loyaltyMaxRedeemPerBill =
            int.tryParse((summary['max_redeem_per_bill'] ?? 0).toString()) ?? 0;
        _loyaltyProgramActive = summary['active_now'] == true;
        if (_redeemPointsInput > _availableLoyaltyPoints) {
          _redeemPointsInput = _availableLoyaltyPoints;
        }
      });
    } catch (_) {}
  }

  Future<void> _openRedeemPointsDialog() async {
    if (!_hasCustomerContext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select customer before redeeming points.')),
      );
      return;
    }
    if (!_loyaltyProgramActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loyalty program is not active now.')),
      );
      return;
    }
    final maxAllowed = _maxRedeemAllowedForBill;
    if (maxAllowed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No redeemable loyalty points available.')),
      );
      return;
    }

    final ctrlInput = TextEditingController(
      text: (_redeemPointsInput > 0 ? _redeemPointsInput : 0).toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Points: $_availableLoyaltyPoints'),
            Text('Max redeem this bill: $maxAllowed'),
            Text(
                'Value per point: Rs. ${_loyaltyRedemptionValue.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            TextField(
              controller: ctrlInput,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Points to redeem',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              final points = int.tryParse(ctrlInput.text.trim()) ?? 0;
              Navigator.pop(context, points);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    ctrlInput.dispose();
    if (result == null) return;

    if (result < 0 || result > maxAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Redeem points must be between 0 and $maxAllowed.'),
        ),
      );
      return;
    }

    setState(() {
      _redeemPointsInput = result;
      _paymentEntries = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _syncAmountPaidWithInvoice();
    });
  }

  Widget _buildCustomerItemAdvanceSummary() {
    if (!_hasCustomerContext) return const SizedBox.shrink();
    final selectedItemId = _selectedManualItem?.id ??
        (_items.length == 1 ? _items.first.itemId : 0);
    if (selectedItemId <= 0) return const SizedBox.shrink();

    final subRowsForItem = _customerSubscriptions.where((row) {
      final rowItemId = int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
      return rowItemId == selectedItemId;
    }).toList();
    final hasSubscriptionForSelected = subRowsForItem.isNotEmpty;

    final sourceRows = hasSubscriptionForSelected
        ? subRowsForItem
        : _customerItemAdvances.where((row) {
            final rowItemId =
                int.tryParse(row['item_id']?.toString() ?? '') ?? 0;
            return rowItemId == selectedItemId;
          }).toList();
    if (sourceRows.isEmpty) return const SizedBox.shrink();

    final itemName = (sourceRows.first['item_name'] ??
            sourceRows.first['item_code'] ??
            _selectedManualItem?.itemName ??
            'Item')
        .toString();
    final remainingQty = sourceRows.fold<double>(
      0,
      (sum, row) =>
          sum +
          _num(
            hasSubscriptionForSelected
                ? row['today_remaining_qty']
                : (row['remaining_qty_total'] ??
                    row['remaining_qty'] ??
                    row['available_qty']),
          ),
    );
    final liveLeft =
        (remainingQty - _currentAdvanceFreeQtyForItem(selectedItemId))
            .clamp(0, double.infinity);
    if (liveLeft <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(
            label: Text(
              '$itemName: ${liveLeft.toStringAsFixed(liveLeft % 1 == 0 ? 0 : 2)} qty left',
            ),
            backgroundColor: const Color(0xFFE8F5E9),
          ),
        ],
      ),
    );
  }

  double _currentAdvanceQtyForItem(int itemId) {
    return _items
        .where((line) =>
            line.itemId == itemId && !line.isSchemeFree && !line.isAdvanceFree)
        .fold<double>(0, (sum, line) => sum + line.qty);
  }

  double _currentAdvanceFreeQtyForItem(int itemId) {
    return _items
        .where((line) => line.itemId == itemId && line.isAdvanceFree)
        .fold<double>(0, (sum, line) => sum + line.qty);
  }

  Future<void> _showDiscountDialog() async {
    final valueCtrl = TextEditingController(text: _manualDiscountValue.text);
    String discountType = _manualDiscountType;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Apply Discount'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  items: const [
                    DropdownMenuItem(
                        value: 'AMOUNT', child: Text('Fixed Amount')),
                    DropdownMenuItem(
                        value: 'PERCENT', child: Text('Percentage')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => discountType = value ?? 'AMOUNT'),
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _manualDiscountType = discountType;
                  _manualDiscountValue.text = valueCtrl.text.trim().isEmpty
                      ? '0'
                      : valueCtrl.text.trim();
                  _syncAmountPaidWithInvoice();
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaxModeDialog() async {
    String selectedMode = _taxMode;
    String? tempIgstState = _selectedIgstState;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Select Tax Mode'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedMode,
                    decoration: const InputDecoration(labelText: 'Tax Mode'),
                    items: const [
                      DropdownMenuItem(value: 'CGST_SGST', child: Text('CGST + SGST')),
                      DropdownMenuItem(value: 'IGST', child: Text('IGST')),
                      DropdownMenuItem(value: 'VAT', child: Text('VAT')),
                      DropdownMenuItem(value: 'CESS', child: Text('CESS')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('Custom Tax')),
                      DropdownMenuItem(value: 'NONE', child: Text('No Tax')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedMode = value;
                        });
                      }
                    },
                  ),
                  if (selectedMode == 'IGST') ...[
                    const SizedBox(height: 16),
                    DropdownSearch<String>(
                      selectedItem: tempIgstState,
                      items: (filter, _) async {
                        if (filter.isEmpty) return _stateCodes.keys.toList();
                        return _stateCodes.keys
                            .where((state) => state.toLowerCase().contains(filter.toLowerCase()))
                            .toList();
                      },
                      itemAsString: (state) {
                        final code = _stateCodes[state];
                        return '${_titleCase(state)} ($code)';
                      },
                      compareFn: (first, second) => first == second,
                      popupProps: const PopupProps.menu(showSearchBox: true),
                      decoratorProps: const DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Select State (Place of Supply)',
                          helperText: 'Required for IGST billing',
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          tempIgstState = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _taxMode = selectedMode;
                    if (selectedMode == 'IGST') {
                      _selectedIgstState = tempIgstState;
                      _selectedIgstStateCode = tempIgstState != null ? _stateCodes[tempIgstState!] : null;
                    } else {
                      _selectedIgstState = null;
                      _selectedIgstStateCode = null;
                    }
                    _syncAmountPaidWithInvoice();
                  });
                  Navigator.pop(dialogContext);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isVoucherValid(_VoucherDefinition voucher, {bool showReason = true}) {
    final now = DateTime.now();
    final from = DateTime.tryParse(voucher.validFrom);
    final to = DateTime.tryParse(voucher.validTo);
    if (from != null && now.isBefore(from)) {
      if (showReason) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voucher ${voucher.code} is not active yet.')),
        );
      }
      return false;
    }
    if (to != null && now.isAfter(to.add(const Duration(days: 1)))) {
      if (showReason) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voucher ${voucher.code} has expired.')),
        );
      }
      return false;
    }
    if (_subTotal < voucher.minimumPurchaseAmount) {
      if (showReason) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Voucher ${voucher.code} requires minimum purchase of ${voucher.minimumPurchaseAmount.toStringAsFixed(2)}.',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _applyVoucherCode([String? rawCode]) async {
    final code = (rawCode ?? _voucherCode.text).trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _appliedVoucher = null);
      return;
    }

    try {
      final data = await ctrl.validateVoucher({
        'code': code,
        'order_amount': _subTotal,
        'header': {
          'customer_name': _customerName.text.trim(),
          'customer_phone': _customerPhone.text.trim(),
          'customer_gstin': _customerGstin.text.trim(),
        },
      });
      final match = _VoucherDefinition.fromJson(data);
      if (!_isVoucherValid(match)) {
        setState(() => _appliedVoucher = null);
        return;
      }
      setState(() {
        _appliedVoucher = match;
        _voucherCode.text = match.code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voucher ${match.code} applied successfully.')),
      );
    } catch (error) {
      setState(() => _appliedVoucher = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showCreateVoucherDialog() async {
    final codeCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '0');
    final minPurchaseCtrl = TextEditingController(text: '2000');
    final fromCtrl = TextEditingController(text: '2026-01-01');
    final toCtrl = TextEditingController(text: '2026-12-31');
    String discountType = 'AMOUNT';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Voucher'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Voucher Code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Voucher Label'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  items: const [
                    DropdownMenuItem(value: 'AMOUNT', child: Text('Amount')),
                    DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => discountType = value ?? 'AMOUNT');
                  },
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Discount Value'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minPurchaseCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Purchase Amount',
                    hintText: 'Example 2000 or 3000',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Valid From'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Valid To'),
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
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                try {
                  final created = await ctrl.createVoucher({
                    'code': code,
                    'label': labelCtrl.text.trim().isEmpty
                        ? code
                        : labelCtrl.text.trim(),
                    'discount_type': discountType,
                    'discount_value':
                        double.tryParse(valueCtrl.text.trim()) ?? 0,
                    'valid_from': fromCtrl.text.trim(),
                    'valid_to': toCtrl.text.trim(),
                    'minimum_purchase_amount':
                        double.tryParse(minPurchaseCtrl.text.trim()) ?? 0,
                  });
                  await _loadVoucherCatalog();
                  final voucher = _VoucherDefinition.fromJson(created);
                  setState(() {
                    _voucherCode.text = voucher.code;
                    _appliedVoucher = null;
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showEditVoucherDialog(_VoucherDefinition voucher) async {
    final labelCtrl = TextEditingController(text: voucher.label);
    final valueCtrl =
        TextEditingController(text: voucher.discountValue.toStringAsFixed(2));
    final minPurchaseCtrl = TextEditingController(
      text: voucher.minimumPurchaseAmount.toStringAsFixed(2),
    );
    final fromCtrl = TextEditingController(text: voucher.validFrom);
    final toCtrl = TextEditingController(text: voucher.validTo);
    String discountType = voucher.discountType;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit Voucher ${voucher.code}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Voucher Label'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  items: const [
                    DropdownMenuItem(value: 'AMOUNT', child: Text('Amount')),
                    DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => discountType = value ?? 'AMOUNT');
                  },
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Discount Value'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minPurchaseCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Purchase Amount',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Valid From'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Valid To'),
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
              onPressed: () async {
                try {
                  await ctrl.updateVoucher(voucher.code, {
                    'label': labelCtrl.text.trim().isEmpty
                        ? voucher.code
                        : labelCtrl.text.trim(),
                    'discount_type': discountType,
                    'discount_value':
                        double.tryParse(valueCtrl.text.trim()) ?? 0,
                    'valid_from': fromCtrl.text.trim(),
                    'valid_to': toCtrl.text.trim(),
                    'minimum_purchase_amount':
                        double.tryParse(minPurchaseCtrl.text.trim()) ?? 0,
                  });
                  await _loadVoucherCatalog();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Voucher ${voucher.code} updated.'),
                    ),
                  );
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    return updated ?? false;
  }

  Future<void> _showManageVouchersDialog() async {
    await _loadVoucherCatalog();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, refreshDialog) {
            return AlertDialog(
              title: const Text('Manage Vouchers'),
              content: SizedBox(
                width: 720,
                child: _voucherCatalog.isEmpty
                    ? const Text('No vouchers created yet.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _voucherCatalog.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final voucher = _voucherCatalog[index];
                          return ListTile(
                            title: Text('${voucher.code} • ${voucher.label}'),
                            subtitle: Text(
                              '${voucher.discountType == 'PERCENT' ? '${voucher.discountValue.toStringAsFixed(0)}%' : 'Rs. ${voucher.discountValue.toStringAsFixed(2)}'} • Min Rs. ${voucher.minimumPurchaseAmount.toStringAsFixed(2)} • ${voucher.validFrom} to ${voucher.validTo}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    final changed =
                                        await _showEditVoucherDialog(voucher);
                                    if (changed) {
                                      await _loadVoucherCatalog();
                                      refreshDialog(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      await ctrl.deleteVoucher(voucher.code);
                                      await _loadVoucherCatalog();
                                      refreshDialog(() {});
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Voucher ${voucher.code} deleted.',
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error.toString().replaceFirst(
                                                'Exception: ', ''),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _searchCustomerMatches(String value) async {
    final query = value.trim();
    if (query.length < 3) return;
    final matches = await ctrl.searchCustomers(query);
    if (!mounted || matches.isEmpty) return;
    final exactPhone = matches.where((c) => c.customerPhone == query).toList();
    final exactName = matches
        .where((c) => c.customerName.toLowerCase() == query.toLowerCase())
        .toList();
    if (exactPhone.isNotEmpty) {
      _applyCustomer(exactPhone.first);
      return;
    }
    if (exactName.isNotEmpty) _applyCustomer(exactName.first);
  }

  bool _validateSchemeCustomerRequirement() {
    if (_selectedSchemes.isEmpty) return true;
    if (_customerName.text.trim().isEmpty ||
        _customerPhone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Customer name and mobile are required for scheme sales.'),
        ),
      );
      return false;
    }
    return true;
  }

  bool _hasCreditSelected(List<_PaymentLine> entries) =>
      entries.any((entry) => entry.method == 'CREDIT' && entry.amount > 0.009);

  Future<void> _openPaymentSheet({required bool printAfterSave}) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before checkout.')),
      );
      return;
    }
    if (!_validateSchemeCustomerRequirement()) return;

    final result = await _showPaymentDialog();
    if (result == null) return;
    setState(() {
      _paymentEntries = result.entries;
      _paymentMode = result.summary.primaryMode;
      _amountPaid.text = result.summary.collectedAmount.toStringAsFixed(2);
      _pendingPreviousAdjustment = result.summary.previousAdjustmentAmount;
      _pendingAdvanceApplied = result.summary.advanceAppliedAmount;
      _pendingAdvanceCreated = result.summary.advanceCreatedAmount;
    });
    await _persistSale(status: 'COMPLETED', printAfterSave: printAfterSave);
  }

  Future<_NormalizedPaymentEntries?> _showPaymentDialog() async {
    final previousOutstanding = _previousOutstandingAmount;
    final availableAdvance = _availableAdvanceAmount;
    final seed = _paymentDialogSeedEntries();

    return showDialog<_NormalizedPaymentEntries>(
      context: context,
      builder: (context) {
        final lines = seed
            .map((entry) => _EditablePaymentLine(
                method: entry.method,
                amountCtrl: TextEditingController(
                    text: entry.amount > 0
                        ? entry.amount.toStringAsFixed(2)
                        : '')))
            .toList();
        bool refundEnabled = false;
        bool adjustPreviousCredit = previousOutstanding > 0;
        bool adjustAdvance = availableAdvance > 0 && _subscriptionItemAdvanceDiscount == 0;

        double readLineAmount(_EditablePaymentLine line) =>
            double.tryParse(line.amountCtrl.text.trim()) ?? 0;

        void setLineAmount(
          _EditablePaymentLine line,
          double value,
        ) {
          final nextText = value <= 0 ? '' : value.toStringAsFixed(2);
          if (line.amountCtrl.text == nextText) return;
          line.amountCtrl.value = TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          );
        }

        void autoBalanceCash({bool force = false}) {
          final payableAfterAdvance = adjustAdvance
              ? (_payableInvoiceTotal - math.min(availableAdvance, _payableInvoiceTotal))
              : _payableInvoiceTotal;
          final cashLines =
              lines.where((line) => line.method == 'CASH').toList();
          if (cashLines.isEmpty) return;
          final nonCashNonCredit = lines
              .where((line) => line.method != 'CASH' && line.method != 'CREDIT' && line.method != 'CASH ON DELIVERY')
              .fold<double>(0, (sum, line) => sum + readLineAmount(line));
          final shouldAutoAdjust = force ||
              cashLines.length > 1 ||
              nonCashNonCredit > _retailRoundingTolerance;
          if (!shouldAutoAdjust) return;
          final primaryCash = cashLines.first;
          for (final extraCash in cashLines.skip(1)) {
            setLineAmount(extraCash, 0);
          }
          final otherNonCredit = lines
              .where((line) =>
                  !identical(line, primaryCash) && line.method != 'CREDIT' && line.method != 'CASH ON DELIVERY')
              .fold<double>(0, (sum, line) => sum + readLineAmount(line));
          final remainingCash = payableAfterAdvance - otherNonCredit;
          setLineAmount(primaryCash, remainingCash > 0 ? remainingCash : 0);
        }

        autoBalanceCash(force: true);

        _NormalizedPaymentEntries preview() {
          final appliedAdvance = adjustAdvance
              ? math.min(availableAdvance, _payableInvoiceTotal)
              : 0.0;
          final payableAfterAdvance = _payableInvoiceTotal - appliedAdvance;
          final raw = lines
              .map(
                (line) => _PaymentLine(
                  method: line.method,
                  amount: line.method == 'CASH ON DELIVERY'
                      ? 0
                      : (double.tryParse(line.amountCtrl.text.trim()) ?? 0),
                ),
              )
              .toList();
          final base = _normalizePaymentEntries(
            raw,
            invoiceTotal: payableAfterAdvance,
            fallbackMode: _paymentMode,
            fallbackPaid: double.tryParse(_amountPaid.text.trim()),
          );
          final rawCash = raw
              .where((entry) => entry.method == 'CASH')
              .fold<double>(0, (sum, entry) => sum + entry.amount);
          final rawNonCredit = raw
              .where((entry) => entry.method != 'CREDIT')
              .fold<double>(0, (sum, entry) => sum + entry.amount);
          double overpay = _positiveDelta(rawNonCredit - payableAfterAdvance);
          double previousAdjust = adjustPreviousCredit
              ? (overpay > previousOutstanding ? previousOutstanding : overpay)
              : 0;
          double refundBase = overpay - previousAdjust;
          double refund =
              refundEnabled ? (refundBase > rawCash ? rawCash : refundBase) : 0;
          double advanceCreated =
              !refundEnabled && _hasCustomerContext && refundBase > 0
                  ? refundBase
                  : 0;
          return _NormalizedPaymentEntries(
            entries: base.entries,
            summary: _PaymentSummary(
              primaryMode: base.summary.primaryMode,
              collectedAmount: base.summary.collectedAmount,
              rawCollectedAmount: base.summary.rawCollectedAmount,
              cashAmount: base.summary.cashAmount,
              creditAmount: base.summary.creditAmount,
              refundAmount: refund < 0 ? 0 : refund,
              balanceDue: base.summary.balanceDue,
              hasInvalidRefund: (_hasCreditSelected(base.entries) &&
                      !_hasCustomerContext) ||
                  (!_hasCustomerContext && refundBase > 0 && !refundEnabled),
              previousAdjustmentAmount: previousAdjust,
              advanceAppliedAmount: appliedAdvance,
              advanceCreatedAmount: advanceCreated,
              refundEnabled: refundEnabled,
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final paymentState = preview();
            return AlertDialog(
              title: const Text('Checkout Payment'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total bill Rs. ${_payableInvoiceTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (_subscriptionItemAdvanceDiscount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Subscription item discount Rs. ${_subscriptionItemAdvanceDiscount.toStringAsFixed(2)} already applied.',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (_hasCustomerContext &&
                          availableAdvance > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Customer advance Rs. ${availableAdvance.toStringAsFixed(2)} is available, but it is not auto-applied in checkout.',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ...List.generate(lines.length, (index) {
                        final line = lines[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: line.method,
                                  items: [
                                    'CASH',
                                    'CARD',
                                    'UPI',
                                    'BANK',
                                    'CREDIT',
                                    if (_orderType == 'DELIVERY') 'CASH ON DELIVERY'
                                  ]
                                      .map(
                                        (method) => DropdownMenuItem(
                                          value: method,
                                          child: Text(method),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      line.method = value ?? 'CASH';
                                      if (line.method == 'CASH ON DELIVERY') {
                                        line.amountCtrl.text = '';
                                      }
                                      autoBalanceCash();
                                    });
                                  },
                                  decoration:
                                      const InputDecoration(labelText: 'Mode'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  enabled: line.method != 'CASH ON DELIVERY',
                                  controller: line.amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  onChanged: (_) => setDialogState(() {
                                    if (line.method != 'CASH' ||
                                        lines
                                                .where((entry) =>
                                                    entry.method == 'CASH')
                                                .length >
                                            1) {
                                      autoBalanceCash();
                                    }
                                  }),
                                  decoration: const InputDecoration(
                                      labelText: 'Amount'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: lines.length == 1
                                    ? null
                                    : () {
                                        final ctrl =
                                            lines.removeAt(index).amountCtrl;
                                        ctrl.dispose();
                                        setDialogState(() {
                                          autoBalanceCash();
                                        });
                                        setState(() {});
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                lines.add(
                                  _EditablePaymentLine(
                                    method: 'UPI',
                                    amountCtrl: TextEditingController(),
                                  ),
                                );
                                autoBalanceCash();
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Payment'),
                          ),
                          const Text(
                            'Cash auto-adjusts when Card/UPI/Bank amounts are added.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_hasCustomerContext &&
                          availableAdvance > 0 &&
                          _subscriptionItemAdvanceDiscount == 0)
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Apply available advance Rs. ${availableAdvance.toStringAsFixed(2)}',
                          ),
                          value: adjustAdvance,
                          onChanged: (value) => setDialogState(() {
                            adjustAdvance = value;
                            autoBalanceCash(force: true);
                          }),
                        ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Adjust previous credit Rs. ${previousOutstanding.toStringAsFixed(2)}',
                        ),
                        value: adjustPreviousCredit && previousOutstanding > 0,
                        onChanged:
                            previousOutstanding <= 0 || !_hasCustomerContext
                                ? null
                                : (value) => setDialogState(
                                      () => adjustPreviousCredit = value,
                                    ),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Refund extra cash now'),
                        subtitle: const Text(
                          'Disabled until cash amount is entered',
                        ),
                        value: refundEnabled,
                        onChanged: lines.any((line) => line.method == 'CASH')
                            ? (value) =>
                                setDialogState(() => refundEnabled = value)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Collected Rs. ${paymentState.summary.collectedAmount.toStringAsFixed(2)}'),
                            Text(
                                'Advance Used Rs. ${paymentState.summary.advanceAppliedAmount.toStringAsFixed(2)}'),
                            Text(
                                'Outstanding Rs. ${paymentState.summary.balanceDue.toStringAsFixed(2)}'),
                            Text(
                                'Previous Adjust Rs. ${paymentState.summary.previousAdjustmentAmount.toStringAsFixed(2)}'),
                            Text(
                                'New Advance Rs. ${paymentState.summary.advanceCreatedAmount.toStringAsFixed(2)}'),
                            if (paymentState.summary.refundAmount > 0)
                              Text(
                                'Refund Rs. ${paymentState.summary.refundAmount.toStringAsFixed(2)} in CASH',
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              Text(
                                'Refund Rs. ${paymentState.summary.refundAmount.toStringAsFixed(2)}',
                              ),
                            Text(_paymentSummaryText(paymentState.entries)),
                          ],
                        ),
                      ),
                      if (paymentState.summary.hasInvalidRefund) ...[
                        const SizedBox(height: 12),
                        Text(
                          _hasCreditSelected(paymentState.entries) &&
                                  !_hasCustomerContext
                              ? 'Customer selection is required for credit payment.'
                              : 'Customer selection is required to keep extra payment as advance.',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (final line in lines) {
                      line.amountCtrl.dispose();
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: paymentState.summary.hasInvalidRefund
                      ? null
                      : () {
                          final result = preview();
                          for (final line in lines) {
                            line.amountCtrl.dispose();
                          }
                          Navigator.pop(context, result);
                          setState(() {});
                        },
                  child: const Text('Use Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmEditStockEffect() async {
    if (_editingSaleId == null) return true;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modify stock effect'),
          content: const Text(
            'Should this modified bill update stock ledger quantity? Choose No if you are only correcting the bill without changing stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.do_not_disturb_alt_outlined),
              label: const Text('No Effect'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Affect Stock'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showModificationReasonDialog() async {
    final controller = TextEditingController();
    String selectedReason = 'Item Out of stock / Insufficient stock';
    final reasons = [
      'Item Out of stock / Insufficient stock',
      'Pricing correction',
      'Quantity correction',
      'Customer requested changes',
      'Other'
    ];
    bool isOther = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reason for Modification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please select or specify the reason for modifying this order:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: const InputDecoration(
                      labelText: 'Select Reason',
                      border: OutlineInputBorder(),
                    ),
                    items: reasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedReason = val;
                          isOther = val == 'Other';
                        });
                      }
                    },
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Specify Custom Reason',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reason = isOther ? controller.text.trim() : selectedReason;
                    if (isOther && reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please specify a reason')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, reason);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    ).then((val) {
      controller.dispose();
      return val;
    });
  }

  Future<void> _persistSale({
    required String status,
    required bool printAfterSave,
  }) async {
    final cartSnapshot =
        _items.where((line) => line.qty > 0).toList(growable: false);
    if (printAfterSave && status != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only completed sales can be printed.')),
      );
      return;
    }
    if (status == 'COMPLETED' && !_validateSchemeCustomerRequirement()) {
      return;
    }
    if (_redeemPointsInput > 0) {
      if (!_hasCustomerContext) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Customer selection is required for redeeming points.'),
          ),
        );
        return;
      }
      if (!_loyaltyProgramActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loyalty program is not active now.'),
          ),
        );
        return;
      }
      if (_redeemPointsInput > _maxRedeemAllowedForBill) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Redeem points cannot exceed $_maxRedeemAllowedForBill for this bill.',
            ),
          ),
        );
        return;
      }
    }

    if (_editingSaleId != null) {
      final chosen = await _confirmEditStockEffect();
      if (chosen == null) {
        return;
      }
      setState(() {
        _affectStockOnEdit = chosen;
      });
    }

    String? modReason;
    if (_editingSaleId != null && status == 'COMPLETED') {
      modReason = await _showModificationReasonDialog();
      if (modReason == null) {
        return;
      }
    }

    // Refresh catalog before save so billing uses latest current item rates.
    try {
      await ctrl.loadInitialData();
      _syncCartRatesWithLatestCatalog();
    } catch (_) {
      // Continue with cached rates if refresh fails.
    }

    // Ensure item-advance (qty) is applied on the bill lines before totals are computed/saved.
    _rebuildItemAdvanceFreeLines();

    // Ensure item-wise scheme (free qty) is applied to the bill lines before totals are computed/saved.
    _rebuildItemSchemeFreeLines();

    final invoice = _invoice;
    final orderItems = <SaleItem>[
      ...(invoice.items.isNotEmpty
          ? invoice.items
          : _items.where((line) => line.qty > 0).toList(growable: false)),
    ];
    if (orderItems.isEmpty && cartSnapshot.isNotEmpty) {
      orderItems.addAll(cartSnapshot);
    }
    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one item before saving sale.')),
      );
      return;
    }
    final isEditing = _editingSaleId != null;
    final isWorkingDraft = _activeDraftId != null;
    final roundedInvoiceTotal = _payableInvoiceTotal;
    final normalizedPayments = _normalizePaymentEntries(
      _paymentEntries,
      invoiceTotal: roundedInvoiceTotal,
      fallbackMode: _paymentMode,
      fallbackPaid: double.tryParse(_amountPaid.text.trim()),
    );
    final paymentSummary = normalizedPayments.summary;
    if (_hasCreditSelected(normalizedPayments.entries) &&
        !_hasCustomerContext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer selection is required for credit payment.'),
        ),
      );
      return;
    }
    final paymentReference =
        _encodePaymentReference(normalizedPayments.entries);
    final noteParts = <String>[];
    if (_notes.text.trim().isNotEmpty) {
      noteParts.add(_notes.text.trim());
    }
    noteParts
        .add('Payment: ${_paymentSummaryText(normalizedPayments.entries)}');
    final retailRoundOff = _billRoundOffAmount;
    if (retailRoundOff.abs() > 0.009) {
      noteParts.add(
        'Retail round off: ${retailRoundOff >= 0 ? '+' : ''}${retailRoundOff.toStringAsFixed(2)}',
      );
    }
    String? resolvedCustomerAddress = _customerAddress.text.trim();
    if (_taxMode == 'IGST' && _selectedIgstState != null) {
      if (resolvedCustomerAddress.isEmpty) {
        resolvedCustomerAddress = 'State: ${_titleCase(_selectedIgstState!)}';
      } else if (!resolvedCustomerAddress.toLowerCase().contains(_selectedIgstState!.toLowerCase())) {
        resolvedCustomerAddress += ', State: ${_titleCase(_selectedIgstState!)}';
      }
    }
    if (resolvedCustomerAddress.isEmpty) resolvedCustomerAddress = null;

    final order = SaleOrder(
      saleNo: _saleNo.text,
      saleDate: _saleDate,
      status: status,
      orderType: _orderType,
      billingCountry: _billingCountry,
      billingTaxMode: _taxMode,
      billFormat: _billFormat,
      customerName:
          _customerName.text.trim().isEmpty ? null : _customerName.text.trim(),
      customerPhone: _customerPhone.text.trim().isEmpty
          ? null
          : _customerPhone.text.trim(),
      customerAddress: resolvedCustomerAddress,
      customerGstin: _customerGstin.text.trim().isEmpty
          ? null
          : _customerGstin.text.trim(),
      paymentMode: paymentSummary.primaryMode,
      paymentReference: paymentReference,
      amountPaid: paymentSummary.collectedAmount,
      changeAmount: paymentSummary.refundAmount,
      balanceDue: paymentSummary.balanceDue,
      subTotal: invoice.subTotal,
      totalQty: invoice.totalQty,
      taxPercent: invoice.taxableAmount <= 0
          ? 0
          : (invoice.totalTax * 100) / invoice.taxableAmount,
      schemeId: _selectedScheme?.id,
      schemeName: _selectedScheme?.schemeName,
      schemeUsageMode: _schemeUsageMode,
      schemeDiscount: invoice.schemeDiscountAmount,
      manualDiscountType:
          invoice.manualDiscountAmount > 0 ? _manualDiscountType : null,
      manualDiscountValue:
          double.tryParse(_manualDiscountValue.text.trim()) ?? 0,
      manualDiscountAmount: invoice.manualDiscountAmount,
      taxableAmount: invoice.taxableAmount,
      cgstAmount: invoice.amountForCode('CGST'),
      sgstAmount: invoice.amountForCode('SGST'),
      igstAmount: invoice.amountForCode('IGST'),
      totalTax: invoice.totalTax,
      taxBreakup: invoice.taxSummary,
      charges: invoice.charges.map((charge) => charge.charge).toList(),
      chargeTotal: invoice.chargeTotal,
      chargeTaxTotal: invoice.chargeTaxTotal,
      totalDiscount: invoice.totalDiscount,
      roundOffAmount: retailRoundOff,
      netAmount: roundedInvoiceTotal,
      voucherCode: null,
      voucherLabel: null,
      voucherFooterMessage: _schemeFooterMessage,
      loyaltyPointsEarned: 0,
      loyaltyPointsRedeemed: _redeemPointsInput,
      loyaltyDiscountAmount: _loyaltyDiscountAmount,
      selectedSchemes: List<SaleScheme>.from(_selectedSchemes),
      itemsPreSplit: true,
      notes: noteParts.isEmpty ? null : noteParts.join(' | '),
      modificationNote:
          isEditing ? (modReason ?? 'Sales bill updated from reprint section') : null,
      affectStock: !isEditing || _affectStockOnEdit,
      items: orderItems,
    );
    Map<String, dynamic>? saveResponse;
    Map<String, dynamic>? modifyResponse;
    if (isWorkingDraft) {
      modifyResponse =
          await ctrl.modifySale(_activeDraftId!, order, modificationNote: '');
    } else {
      if (isEditing) {
        modifyResponse = await ctrl.modifySale(
          _editingSaleId!,
          order,
          modificationNote: modReason ?? 'Sales bill updated from reprint section',
        );
      } else {
        saveResponse = await ctrl.createSale(order);
      }
    }
    final normalizedSaveSaleIds =
        _normalizeSaleIds(saveResponse?['sale_ids']) ?? const <int>[];
    final modifiedSaleId =
        int.tryParse((modifyResponse?['sale_id'] ?? 0).toString()) ?? 0;
    final savedSaleIds = <int>[
      ...normalizedSaveSaleIds,
      if (modifiedSaleId > 0) modifiedSaleId,
      if (normalizedSaveSaleIds.isEmpty)
        ...(() {
          final fallbackSaleId =
              int.tryParse((saveResponse?['sale_id'] ?? 0).toString()) ?? 0;
          return fallbackSaleId > 0 ? [fallbackSaleId] : <int>[];
        })(),
    ];
    if (status == 'COMPLETED' &&
        _pendingPreviousAdjustment > 0 &&
        _previousCreditBills.isNotEmpty &&
        _hasCustomerContext) {
      await ctrl.settlePreviousCredit(
        bills: _previousCreditBills,
        amount: _pendingPreviousAdjustment,
        paymentDate: _saleDate,
        paymentMode: paymentSummary.primaryMode == 'CREDIT'
            ? 'CASH'
            : paymentSummary.primaryMode,
        referenceNo: _saleNo.text,
        note: 'Adjusted while billing ${_saleNo.text}',
      );
      await _loadCustomerOutstanding();
    }
    final savedSaleId = savedSaleIds.isNotEmpty
        ? savedSaleIds.first
        : (isWorkingDraft ? (_activeDraftId ?? 0) : 0);
    if (status == 'COMPLETED' &&
        _pendingAdvanceApplied > 0 &&
        savedSaleId > 0 &&
        _hasCustomerContext) {
      await ctrl.applyCustomerAdvance(
        saleId: savedSaleId,
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        amount: _pendingAdvanceApplied,
        paymentDate: _saleDate,
        paymentMode: 'ADVANCE',
        referenceNo: _saleNo.text,
        note: 'Advance adjusted while billing ${_saleNo.text}',
      );
      await _loadCustomerOutstanding();
    }
    if (status == 'COMPLETED' &&
        _pendingAdvanceCreated > 0 &&
        _hasCustomerContext) {
      await ctrl.createCustomerAdvance(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        amount: _pendingAdvanceCreated,
        advanceDate: _saleDate,
        paymentMode: paymentSummary.primaryMode == 'CREDIT'
            ? 'CASH'
            : paymentSummary.primaryMode,
        referenceNo: _saleNo.text,
        note: 'Advance received while billing ${_saleNo.text}',
        sourceSaleId: savedSaleId > 0 ? savedSaleId : null,
      );
      await _loadCustomerOutstanding();
    }
    final shouldPrint = status == 'COMPLETED' &&
        (printAfterSave || (settingsCtrl.settings?.autoPrintOnSave ?? false));
    if (shouldPrint) {
      final idsToPrint = savedSaleIds.isNotEmpty ? savedSaleIds : [savedSaleId];
      for (final saleId in idsToPrint) {
        if (saleId <= 0) continue;
        SaleOrder printOrder = order;
        final details = await ctrl.getSaleDetails(saleId);
        printOrder = _saleOrderFromDetails(details);
        await _handlePrintAfterSave(printOrder);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWorkingDraft && status == 'DRAFT'
              ? 'Draft updated successfully'
              : isWorkingDraft
                  ? 'Draft completed successfully'
                  : isEditing
                      ? printAfterSave
                          ? 'Bill updated and print opened successfully'
                          : 'Bill updated successfully'
                      : status == 'DRAFT'
                          ? 'Order saved as draft successfully'
                          : printAfterSave
                              ? 'Sale saved and print opened successfully'
                              : 'Sale saved successfully',
        ),
      ),
    );
    if (status == 'COMPLETED') {
      _activeDraftId = null;
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      try {
        _saleNo.text = await ctrl.getNextSaleNo();
      } catch (_) {}
    }
    if (isEditing) {
      Navigator.pop(context, true);
      return;
    }
    await _resetSaleForm();
  }

  List<int>? _normalizeSaleIds(dynamic value) {
    if (value is List) {
      return value
          .map((entry) => int.tryParse(entry.toString()) ?? 0)
          .where((entry) => entry > 0)
          .toList(growable: false);
    }
    if (value == null) return null;
    final parsed = int.tryParse(value.toString()) ?? 0;
    return parsed > 0 ? [parsed] : null;
  }

  Future<void> _resetSaleForm({bool preserveRecurringSchemes = false}) async {
    _customerOutstandingRequestId++;
    final recurringSchemes = preserveRecurringSchemes
        ? _selectedSchemes
            .where((scheme) => scheme.usageType.toLowerCase() != 'single_use')
            .toList()
        : <SaleScheme>[];
    final hasCustomerContext = _customerName.text.trim().isNotEmpty ||
        _customerPhone.text.trim().isNotEmpty ||
        _customerGstin.text.trim().isNotEmpty;
    final preserveCustomer = preserveRecurringSchemes && hasCustomerContext;
    setState(() {
      _activeDraftId = null;
      _editingSaleId = null;
      _saleNo.clear();
      _items.clear();
      if (!preserveCustomer) {
        _selectedCustomer = null;
      }
      _selectedManualItem = null;
      _itemAdvanceSummaries.clear();
      _itemAdvanceAppliedQtyByItem.clear();
      _itemAdvanceAppliedAmountByItem.clear();
      _itemSchemeProgress = null;
      _itemSchemeProgressByScheme.clear();
      _itemAdvanceSummary = null;
      _customerItemAdvances = const [];
      _customerSubscriptions = const [];
      _selectedSchemes
        ..clear()
        ..addAll(recurringSchemes);
      _selectedScheme = _lastSelectedSchemeByScope('ORDER');
      _selectedItemScheme = _lastSelectedSchemeByScope('ITEM');
      _schemeUsageMode = _selectedScheme != null || _selectedItemScheme != null
          ? _schemeDefaultUsageMode(_selectedScheme ?? _selectedItemScheme!)
          : 'APPLY_NOW';
      _schemeManuallyRemoved = false;
      _selectedCustomerSchemeSuppressed = false;
      if (!preserveCustomer) {
        _customerName.clear();
        _customerPhone.clear();
        _customerAddress.clear();
        _customerGstin.clear();
      }
      _barcode.clear();
      _entryQty.text = '1';
      _paymentRef.clear();
      _amountPaid.text = '0';
      _paymentEntries = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _notes.clear();
      _manualDiscountValue.text = '0';
      _voucherCode.clear();
      _appliedVoucher = null;
      _paymentMode = 'CASH';
      _manualDiscountType = 'AMOUNT';
      _voucherUsageMode = 'APPLY_NOW';
      _orderType = 'B2C';
      _taxMode = 'CGST_SGST';
      _selectedIgstState = null;
      _selectedIgstStateCode = null;
      _saleDate = DateTime.now();
      _saleDateCtrl.text = DateFormat('dd-MMM-yyyy HH:mm').format(_saleDate);
      _applyBillingDefaults();
      _availableAdvanceEntries = const [];
      _availableAdvanceAmount = 0;
      _availableLoyaltyPoints = 0;
      _redeemPointsInput = 0;
      _loyaltyProgramActive = false;
      _loyaltyRedemptionValue = 1;
      _loyaltyMaxRedeemPerBill = 0;
      _previousOutstandingAmount = 0;
      _pendingPreviousAdjustment = 0;
    });
    if (preserveCustomer) {
      await ctrl.refreshSchemes(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
      );
      _refreshSelectedScheme();
      _refreshItemSchemeStatus();
      _loadCustomerOutstanding();
    } else {
      await ctrl.refreshSchemes();
      await ctrl.searchCustomers('');
    }
    try {
      _saleNo.text = await ctrl.getNextSaleNo();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
    _focusBarcodeField();
  }

  double _jsonDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  SaleItem _saleItemFromJson(Map<String, dynamic> json) {
    return SaleItem(
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      hsnSacCode: json['hsn_sac_code'] ?? '',
      barcode: json['barcode'] ?? '',
      unit: json['unit'] ?? '',
      qty: _jsonDouble(json['qty']),
      originalQty: _jsonDouble(json['original_qty'] ?? json['qty']),
      rate: _jsonDouble(json['rate']),
      taxType: json['tax_type'] ?? 'GST',
      taxPercent: _jsonDouble(json['tax_percent']),
      discountApplicable: json['discount_applicable'] ?? true,
      schemeApplicable: json['scheme_applicable'] ?? true,
      lineDiscount: _jsonDouble(json['line_discount']),
      taxableAmount: _jsonDouble(json['taxable_amount']),
      taxAmount: _jsonDouble(json['tax_amount']),
      lineTotal: _jsonDouble(json['line_total']),
    );
  }

  Future<void> _loadDraft(Map<String, dynamic> sale) async {
    final draftId = int.tryParse(sale['id']?.toString() ?? '') ?? 0;
    final details = await ctrl.getSaleDetails(draftId);
    final items = (details['items'] as List? ?? const [])
        .map((e) => _saleItemFromJson(Map<String, dynamic>.from(e)))
        .toList();
    final charges = (details['charges'] as List? ?? const [])
        .map((e) => BillingCharge.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    setState(() {
      _activeDraftId = draftId;
      _saleNo.text = details['sale_no']?.toString() ?? '';
      _saleDate = DateTime.tryParse(details['sale_date']?.toString() ?? '') ??
          DateTime.now();
      _saleDateCtrl.text = DateFormat('dd-MMM-yyyy HH:mm').format(_saleDate);
      _orderType = details['order_type']?.toString() ?? 'B2C';
      _billingCountry = details['billing_country']?.toString() ?? 'India';
      _taxMode = details['billing_tax_mode']?.toString() ?? 'CGST_SGST';
      _billFormat = settingsCtrl.settings?.billFormat ?? (details['bill_format']?.toString() ?? 'A4');
      _paymentMode = details['payment_mode']?.toString() ?? 'CASH';
      _paymentRef.text = details['payment_reference']?.toString() ?? '';
      _amountPaid.text = _jsonDouble(details['amount_paid']).toStringAsFixed(2);
      _paymentEntries = _decodePaymentEntries(
        details['payment_reference']?.toString(),
        fallbackMode: _paymentMode,
        fallbackPaid: _jsonDouble(details['amount_paid']),
        fallbackBalance: _jsonDouble(details['balance_due']),
      );
      _customerName.text = details['customer_name']?.toString() ?? '';
      _customerPhone.text = details['customer_phone']?.toString() ?? '';
      _customerAddress.text = details['customer_address']?.toString() ?? '';
      _customerGstin.text = details['customer_gstin']?.toString() ?? '';
      _notes.text = details['notes']?.toString() ?? '';
      _manualDiscountType =
          details['manual_discount_type']?.toString() ?? 'AMOUNT';
      _manualDiscountValue.text =
          _jsonDouble(details['manual_discount_value']).toStringAsFixed(2);
      _items
        ..clear()
        ..addAll(items);
      _charges = charges.isEmpty ? _charges : charges;
      _selectedScheme = _availableSchemes.cast<SaleScheme?>().firstWhere(
            (scheme) => scheme?.id == details['scheme_id'],
            orElse: () => null,
          );
      _schemeManuallyRemoved = false;
      _appliedVoucher = null;
      _voucherUsageMode = 'APPLY_NOW';
      _voucherCode.clear();
    });
  }

  Future<void> _showDraftsDialog() async {
    var drafts = await ctrl.listSales(status: 'DRAFT');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draft / Delivery Orders'),
        content: SizedBox(
          width: 640,
          child: drafts.isEmpty
              ? const Text('No draft orders available.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: drafts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    final saleDate = DateTime.tryParse(
                      draft['sale_date']?.toString() ?? '',
                    );
                    final draftId =
                        int.tryParse(draft['id']?.toString() ?? '') ?? 0;
                    return ListTile(
                      title: Text(draft['sale_no']?.toString() ?? 'Draft'),
                      subtitle: Text(
                        '${draft['customer_name']?.toString().trim().isNotEmpty == true ? draft['customer_name'] : 'Walk-in Customer'} • ${saleDate == null ? '--' : DateFormat('dd-MMM-yyyy hh:mm a').format(saleDate)} • Rs. ${_jsonDouble(draft['net_amount']).toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Print Draft',
                            onPressed: draftId <= 0
                                ? null
                                : () => _printDraftById(draftId),
                            icon: const Icon(Icons.print_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete Draft',
                            onPressed: draftId <= 0
                                ? null
                                : () async {
                                    await ctrl.deleteDraft(draftId);
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    await _showDraftsDialog();
                                  },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _loadDraft(draft);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Draft ${draft['sale_no']} loaded successfully.',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _printDraftById(int draftId) async {
    final details = await ctrl.getSaleDetails(draftId);
    final order = _saleOrderFromDetails(details);
    await _printInvoice(order);
  }

  SaleOrder _saleOrderFromDetails(Map<String, dynamic> details) {
    final items = (details['items'] as List? ?? const [])
        .map((e) => _saleItemFromJson(Map<String, dynamic>.from(e)))
        .toList();
    final charges = (details['charges'] as List? ?? const [])
        .map((e) => BillingCharge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final taxBreakup = (details['tax_breakup'] as List? ?? const [])
        .map((e) => TaxBreakdown.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SaleOrder(
      saleNo: details['sale_no']?.toString() ?? '',
      saleDate: DateTime.tryParse(details['sale_date']?.toString() ?? '') ??
          DateTime.now(),
      status: details['status']?.toString() ?? 'COMPLETED',
      orderType: details['order_type']?.toString() ?? 'B2C',
      billingCountry: details['billing_country']?.toString() ?? 'India',
      billingTaxMode: details['billing_tax_mode']?.toString() ?? 'CGST_SGST',
      billFormat: _billFormat, // Always use current settings format for reprints
      customerName: details['customer_name']?.toString(),
      customerPhone: details['customer_phone']?.toString(),
      customerAddress: details['customer_address']?.toString(),
      customerGstin: details['customer_gstin']?.toString(),
      paymentMode: details['payment_mode']?.toString() ?? 'CASH',
      paymentReference: details['payment_reference']?.toString(),
      amountPaid: _jsonDouble(details['amount_paid']),
      changeAmount: _jsonDouble(details['change_amount']),
      balanceDue: _jsonDouble(details['balance_due']),
      subTotal: _jsonDouble(details['sub_total']),
      totalQty: _jsonDouble(details['total_qty']),
      taxPercent: _jsonDouble(details['tax_percent']),
      schemeId: details['scheme_id'],
      schemeName: details['scheme_name']?.toString(),
      schemeUsageMode: details['scheme_usage_mode']?.toString(),
      schemeDiscount: _jsonDouble(details['scheme_discount']),
      manualDiscountType: details['manual_discount_type']?.toString(),
      manualDiscountValue: _jsonDouble(details['manual_discount_value']),
      manualDiscountAmount: _jsonDouble(details['manual_discount_amount']),
      taxableAmount: _jsonDouble(details['taxable_amount']),
      cgstAmount: _jsonDouble(details['cgst_amount']),
      sgstAmount: _jsonDouble(details['sgst_amount']),
      igstAmount: _jsonDouble(details['igst_amount']),
      totalTax: _jsonDouble(details['total_tax']),
      taxBreakup: taxBreakup,
      charges: charges,
      chargeTotal: _jsonDouble(details['charge_total']),
      chargeTaxTotal: _jsonDouble(details['charge_tax_total']),
      totalDiscount: _jsonDouble(details['total_discount']),
      netAmount: _jsonDouble(details['net_amount']),
      roundOffAmount: _jsonDouble(details['round_off_amount']),
      voucherCode: details['voucher_code']?.toString(),
      voucherLabel: details['voucher_label']?.toString(),
      voucherFooterMessage: null,
      loyaltyPointsEarned:
          int.tryParse((details['loyalty_points_earned'] ?? 0).toString()) ?? 0,
      loyaltyPointsRedeemed:
          int.tryParse((details['loyalty_points_redeemed'] ?? 0).toString()) ??
              0,
      loyaltyDiscountAmount: _jsonDouble(details['loyalty_discount_amount']),
      notes: details['notes']?.toString(),
      itemsPreSplit: details['items_pre_split'] == true,
      items: items,
    );
  }

  Future<void> _showCompletedSalesDialog() async {
    final sales = await ctrl.listSales(status: 'COMPLETED');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Old Bill Reprint'),
        content: SizedBox(
          width: 640,
          child: sales.isEmpty
              ? const Text('No completed bills available.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final saleDate = DateTime.tryParse(
                      sale['sale_date']?.toString() ?? '',
                    );
                    return ListTile(
                      title: Text(sale['sale_no']?.toString() ?? 'Bill'),
                      subtitle: Text(
                        '${sale['customer_name']?.toString().trim().isNotEmpty == true ? sale['customer_name'] : 'Walk-in Customer'} • ${saleDate == null ? '--' : DateFormat('dd-MMM-yyyy hh:mm a').format(saleDate)} • Rs. ${_jsonDouble(sale['net_amount']).toStringAsFixed(2)}',
                      ),
                      trailing: const Icon(Icons.print_outlined),
                      onTap: () async {
                        Navigator.pop(context);
                        final details = await ctrl.getSaleDetails(
                          int.parse(sale['id'].toString()),
                        );
                        await _handlePrintAfterSave(
                          _saleOrderFromDetails(details),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSchemeDialog() async {
    String schemeScope = 'ORDER';
    String schemeType = 'TIME';
    String discountType = 'PERCENT';
    String repeatMode = 'REPEAT';
    String applyTiming = 'CURRENT_BILL';
    bool isActive = true;
    bool autoSelectOnCustomer = true;
    int? selectedItemId;
    bool requireNoGaps = true;
    final requiredDailyQtyCtrl = TextEditingController(text: '1');
    final cycleDaysCtrl = TextEditingController(text: '30');
    final freeQtyCtrl = TextEditingController(text: '1');
    final nextPurchaseDaysCtrl = TextEditingController(text: '7');

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Create Scheme'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _schemeName,
                          decoration:
                              const InputDecoration(labelText: 'Scheme Name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: schemeScope,
                          items: const [
                            DropdownMenuItem(
                              value: 'ORDER',
                              child: Text('Order Discount'),
                            ),
                            DropdownMenuItem(
                              value: 'ITEM',
                              child: Text('Item Wise (Free Qty)'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              schemeScope = value ?? 'ORDER';
                              if (schemeScope == 'ITEM') {
                                schemeType = 'CYCLE_ITEM_FREE';
                                discountType = 'AMOUNT';
                                _schemeDiscountValue.text = '0';
                                _schemeMinAmount.text = '0';
                                _schemeStartTime = null;
                                _schemeEndTime = null;
                              } else {
                                schemeType = 'TIME';
                              }
                            });
                          },
                          decoration:
                              const InputDecoration(labelText: 'Scheme Scope'),
                        ),
                        if (schemeScope == 'ITEM') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedItemId,
                            items: ctrl.items
                                .map(
                                  (it) => DropdownMenuItem<int>(
                                    value: it.id,
                                    child: Text('${it.itemName} - ${it.brand}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => selectedItemId = value),
                            decoration: const InputDecoration(
                              labelText: 'Scheme Item (Milk)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _schemeMinQty,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min Qty In Cycle (Example 30)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: requiredDailyQtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Daily Qty Required',
                              hintText: 'Example 2 or 3',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: freeQtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Free Qty On Cycle End',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: cycleDaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cycle Days (Example 30)',
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                const Text('Require Daily Purchase (No Gaps)'),
                            value: requireNoGaps,
                            onChanged: (value) =>
                                setDialogState(() => requireNoGaps = value),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: schemeType,
                            items: const [
                              DropdownMenuItem(
                                  value: 'TIME', child: Text('Time Based')),
                              DropdownMenuItem(
                                  value: 'QTY', child: Text('Quantity Based')),
                              DropdownMenuItem(
                                  value: 'VALUE', child: Text('Value Based')),
                            ],
                            onChanged: (value) {
                              setDialogState(
                                  () => schemeType = value ?? 'TIME');
                            },
                            decoration:
                                const InputDecoration(labelText: 'Scheme Type'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: discountType,
                            items: const [
                              DropdownMenuItem(
                                  value: 'PERCENT', child: Text('Percentage')),
                              DropdownMenuItem(
                                  value: 'AMOUNT', child: Text('Value Amount')),
                            ],
                            onChanged: (value) {
                              setDialogState(
                                  () => discountType = value ?? 'PERCENT');
                            },
                            decoration: const InputDecoration(
                              labelText: 'Discount Type',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _schemeDiscountValue,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Discount Value',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: repeatMode,
                          items: const [
                            DropdownMenuItem(
                              value: 'REPEAT',
                              child: Text('Repeat every bill'),
                            ),
                            DropdownMenuItem(
                              value: 'ONCE',
                              child: Text('Apply once'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              repeatMode = value ?? 'REPEAT';
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Repeat Mode',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: applyTiming,
                          items: const [
                            DropdownMenuItem(
                              value: 'CURRENT_BILL',
                              child: Text('Current bill'),
                            ),
                            DropdownMenuItem(
                              value: 'NEXT_PURCHASE',
                              child: Text('Next purchase'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              applyTiming = value ?? 'CURRENT_BILL';
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Apply Timing',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto select on customer select'),
                          value: autoSelectOnCustomer,
                          onChanged: (value) => setDialogState(
                              () => autoSelectOnCustomer = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nextPurchaseDaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Next Purchase Valid Days',
                            hintText: 'Example 7',
                          ),
                        ),
                        if (schemeScope != 'ITEM' && schemeType == 'TIME') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (time != null) {
                                      setDialogState(
                                          () => _schemeStartTime = time);
                                    }
                                  },
                                  child: Text(
                                    _schemeStartTime == null
                                        ? 'Start Time'
                                        : _schemeStartTime!.format(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (time != null) {
                                      setDialogState(
                                          () => _schemeEndTime = time);
                                    }
                                  },
                                  child: Text(
                                    _schemeEndTime == null
                                        ? 'End Time'
                                        : _schemeEndTime!.format(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (schemeScope != 'ITEM' && schemeType == 'QTY') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _schemeMinQty,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Minimum Qty'),
                          ),
                        ],
                        if (schemeScope != 'ITEM' && schemeType == 'VALUE') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _schemeMinAmount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Minimum Order Value'),
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          value: isActive,
                          onChanged: (value) {
                            setDialogState(() => isActive = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final scheme = SaleScheme(
                        id: 0,
                        schemeName: _schemeName.text.trim(),
                        schemeType: schemeType,
                        schemeScope: schemeScope,
                        discountType: discountType,
                        discountValue: schemeScope == 'ITEM'
                            ? 0
                            : double.tryParse(_schemeDiscountValue.text) ?? 0,
                        startTime: _schemeStartTime == null
                            ? null
                            : '${_schemeStartTime!.hour.toString().padLeft(2, '0')}:${_schemeStartTime!.minute.toString().padLeft(2, '0')}',
                        endTime: _schemeEndTime == null
                            ? null
                            : '${_schemeEndTime!.hour.toString().padLeft(2, '0')}:${_schemeEndTime!.minute.toString().padLeft(2, '0')}',
                        minQty: double.tryParse(_schemeMinQty.text) ?? 0,
                        minAmount: schemeScope == 'ITEM'
                            ? 0
                            : double.tryParse(_schemeMinAmount.text) ?? 0,
                        itemId: schemeScope == 'ITEM' ? selectedItemId : null,
                        requiredDailyQty: schemeScope == 'ITEM'
                            ? (double.tryParse(
                                    requiredDailyQtyCtrl.text.trim()) ??
                                0)
                            : 0,
                        freeQty: schemeScope == 'ITEM'
                            ? (double.tryParse(freeQtyCtrl.text.trim()) ?? 0)
                            : 0,
                        cycleDays: schemeScope == 'ITEM'
                            ? (int.tryParse(cycleDaysCtrl.text.trim()) ?? 30)
                            : 30,
                        requireNoGaps:
                            schemeScope == 'ITEM' ? requireNoGaps : false,
                        repeatMode: repeatMode,
                        applyTiming: applyTiming,
                        autoSelectOnCustomer: autoSelectOnCustomer,
                        nextPurchaseValidDays:
                            int.tryParse(nextPurchaseDaysCtrl.text.trim()) ?? 7,
                        isActive: isActive,
                      );

                      await ctrl.createScheme(scheme);
                      _schemeName.clear();
                      _schemeDiscountValue.text = '0';
                      _schemeMinQty.text = '0';
                      _schemeMinAmount.text = '0';
                      _schemeStartTime = null;
                      _schemeEndTime = null;
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      setState(_refreshSelectedScheme);
                    },
                    child: const Text('Save Scheme'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      cycleDaysCtrl.dispose();
      freeQtyCtrl.dispose();
      requiredDailyQtyCtrl.dispose();
      nextPurchaseDaysCtrl.dispose();
    }
  }

  Future<void> _refreshSelectedCustomerSchemeStatus() async {
    if (!_hasCustomerContext || _selectedCustomer?.schemeId == null) {
      return;
    }

    final scheme = _availableSchemes.cast<SaleScheme?>().firstWhere(
          (scheme) => scheme?.id == _selectedCustomer!.schemeId,
          orElse: () => null,
        );
    if (scheme == null || scheme.schemeScope.toUpperCase() != 'ITEM') {
      return;
    }

    try {
      final progressRes = await ctrl.getSchemeProgress(
        schemeId: scheme.id,
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        date: _saleDate,
      );
      if (!mounted) return;
      final progress = Map<String, dynamic>.from(progressRes['progress'] ?? {});
      final alreadyGranted = scheme.repeatMode.toUpperCase() == 'ONCE' &&
          progress['already_granted_today'] == true;
      setState(() {
        _itemSchemeProgress = Map<String, dynamic>.from(progressRes);
        if (alreadyGranted) {
          _selectedItemScheme = null;
          _selectedCustomerSchemeSuppressed = true;
        } else {
          _selectedCustomerSchemeSuppressed = false;
          if (_selectedItemScheme?.id == scheme.id) {
            _schemeManuallyRemoved = false;
          }
        }
      });
    } catch (_) {}
  }

  Future<bool> _showEditSchemeDialog(SaleScheme scheme) async {
    final nameCtrl = TextEditingController(text: scheme.schemeName);
    final discountCtrl = TextEditingController(
      text: scheme.discountValue.toStringAsFixed(2),
    );
    final minQtyCtrl = TextEditingController(
      text: scheme.minQty.toStringAsFixed(scheme.minQty % 1 == 0 ? 0 : 2),
    );
    final minAmountCtrl = TextEditingController(
      text: scheme.minAmount.toStringAsFixed(2),
    );
    final requiredDailyQtyCtrl = TextEditingController(
      text: scheme.requiredDailyQty.toStringAsFixed(
        scheme.requiredDailyQty % 1 == 0 ? 0 : 2,
      ),
    );
    final freeQtyCtrl = TextEditingController(
      text: scheme.freeQty.toStringAsFixed(scheme.freeQty % 1 == 0 ? 0 : 2),
    );
    final cycleDaysCtrl =
        TextEditingController(text: scheme.cycleDays.toString());
    bool requireNoGaps = scheme.requireNoGaps;
    bool autoSelectOnCustomer = scheme.autoSelectOnCustomer;
    int? selectedItemId = scheme.itemId;
    String schemeType = scheme.schemeType;
    String discountType = scheme.discountType;
    String repeatMode = scheme.repeatMode;
    String applyTiming = scheme.applyTiming;
    bool isActive = scheme.isActive;
    final nextPurchaseDaysCtrl =
        TextEditingController(text: scheme.nextPurchaseValidDays.toString());
    TimeOfDay? startTime = scheme.startTime == null
        ? null
        : TimeOfDay(
            hour: int.tryParse(scheme.startTime!.split(':').first) ?? 0,
            minute: int.tryParse(scheme.startTime!.split(':').last) ?? 0,
          );
    TimeOfDay? endTime = scheme.endTime == null
        ? null
        : TimeOfDay(
            hour: int.tryParse(scheme.endTime!.split(':').first) ?? 0,
            minute: int.tryParse(scheme.endTime!.split(':').last) ?? 0,
          );

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit Scheme ${scheme.schemeName}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Scheme Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: schemeType,
                    items: const [
                      DropdownMenuItem(
                          value: 'TIME', child: Text('Time Based')),
                      DropdownMenuItem(
                          value: 'QTY', child: Text('Quantity Based')),
                      DropdownMenuItem(
                          value: 'VALUE', child: Text('Value Based')),
                      DropdownMenuItem(
                        value: 'CYCLE_ITEM_FREE',
                        child: Text('Item Cycle Free'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => schemeType = value ?? 'TIME');
                    },
                    decoration: const InputDecoration(labelText: 'Scheme Type'),
                  ),
                  const SizedBox(height: 12),
                  if (schemeType == 'CYCLE_ITEM_FREE') ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedItemId,
                      items: ctrl.items
                          .map(
                            (it) => DropdownMenuItem<int>(
                              value: it.id,
                              child: Text('${it.itemName} - ${it.brand}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedItemId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Scheme Item (Milk)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: requiredDailyQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Daily Qty Required',
                        hintText: 'Example 2 or 3',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min Qty In Cycle (Example 30)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: freeQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Free Qty On Cycle End',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cycleDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cycle Days (Example 30)',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Require Daily Purchase (No Gaps)'),
                      value: requireNoGaps,
                      onChanged: (value) {
                        setDialogState(() => requireNoGaps = value);
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      initialValue: discountType,
                      items: const [
                        DropdownMenuItem(
                            value: 'PERCENT', child: Text('Percent')),
                        DropdownMenuItem(
                            value: 'AMOUNT', child: Text('Amount')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => discountType = value ?? 'PERCENT');
                      },
                      decoration:
                          const InputDecoration(labelText: 'Discount Type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Discount Value'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: repeatMode,
                    items: const [
                      DropdownMenuItem(
                        value: 'REPEAT',
                        child: Text('Repeat every bill'),
                      ),
                      DropdownMenuItem(
                        value: 'ONCE',
                        child: Text('Apply once'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => repeatMode = value ?? 'REPEAT');
                    },
                    decoration: const InputDecoration(labelText: 'Repeat Mode'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: applyTiming,
                    items: const [
                      DropdownMenuItem(
                        value: 'CURRENT_BILL',
                        child: Text('Current bill'),
                      ),
                      DropdownMenuItem(
                        value: 'NEXT_PURCHASE',
                        child: Text('Next purchase'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(
                          () => applyTiming = value ?? 'CURRENT_BILL');
                    },
                    decoration:
                        const InputDecoration(labelText: 'Apply Timing'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto select on customer select'),
                    value: autoSelectOnCustomer,
                    onChanged: (value) {
                      setDialogState(() => autoSelectOnCustomer = value);
                    },
                  ),
                  TextField(
                    controller: nextPurchaseDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Next Purchase Valid Days',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                  ),
                  if (schemeType == 'TIME') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: dialogContext,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => startTime = picked);
                              }
                            },
                            child: Text(
                              startTime == null
                                  ? 'Start Time'
                                  : startTime!.format(dialogContext),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: dialogContext,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => endTime = picked);
                              }
                            },
                            child: Text(
                              endTime == null
                                  ? 'End Time'
                                  : endTime!.format(dialogContext),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (schemeType == 'QTY') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: minQtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Minimum Quantity'),
                    ),
                  ],
                  if (schemeType == 'VALUE') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: minAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Minimum Amount'),
                    ),
                  ],
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
              onPressed: () async {
                final updated = SaleScheme(
                  id: scheme.id,
                  schemeName: nameCtrl.text.trim(),
                  schemeType: schemeType,
                  schemeScope: schemeType == 'CYCLE_ITEM_FREE'
                      ? 'ITEM'
                      : scheme.schemeScope,
                  discountType:
                      schemeType == 'CYCLE_ITEM_FREE' ? 'AMOUNT' : discountType,
                  discountValue: schemeType == 'CYCLE_ITEM_FREE'
                      ? 0
                      : double.tryParse(discountCtrl.text.trim()) ?? 0,
                  startTime: startTime == null
                      ? null
                      : '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
                  endTime: endTime == null
                      ? null
                      : '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
                  minQty: double.tryParse(minQtyCtrl.text.trim()) ?? 0,
                  minAmount: schemeType == 'CYCLE_ITEM_FREE'
                      ? 0
                      : double.tryParse(minAmountCtrl.text.trim()) ?? 0,
                  itemId: schemeType == 'CYCLE_ITEM_FREE'
                      ? selectedItemId
                      : scheme.itemId,
                  requiredDailyQty: schemeType == 'CYCLE_ITEM_FREE'
                      ? (double.tryParse(requiredDailyQtyCtrl.text.trim()) ??
                          scheme.requiredDailyQty)
                      : scheme.requiredDailyQty,
                  freeQty: schemeType == 'CYCLE_ITEM_FREE'
                      ? (double.tryParse(freeQtyCtrl.text.trim()) ?? 0)
                      : scheme.freeQty,
                  cycleDays: schemeType == 'CYCLE_ITEM_FREE'
                      ? (int.tryParse(cycleDaysCtrl.text.trim()) ?? 30)
                      : scheme.cycleDays,
                  requireNoGaps: schemeType == 'CYCLE_ITEM_FREE'
                      ? requireNoGaps
                      : scheme.requireNoGaps,
                  repeatMode: repeatMode,
                  applyTiming: applyTiming,
                  autoSelectOnCustomer: autoSelectOnCustomer,
                  nextPurchaseValidDays:
                      int.tryParse(nextPurchaseDaysCtrl.text.trim()) ??
                          scheme.nextPurchaseValidDays,
                  isActive: isActive,
                );
                try {
                  await ctrl.updateScheme(scheme.id, updated);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                  if (!mounted) return;
                  setState(_refreshSelectedScheme);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scheme ${scheme.schemeName} updated.'),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    discountCtrl.dispose();
    minQtyCtrl.dispose();
    minAmountCtrl.dispose();
    freeQtyCtrl.dispose();
    cycleDaysCtrl.dispose();
    requiredDailyQtyCtrl.dispose();
    nextPurchaseDaysCtrl.dispose();
    return changed ?? false;
  }

  Future<void> _showManageSchemesDialog() async {
    await ctrl.refreshSchemes();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshDialog) => AlertDialog(
          title: const Text('Manage Schemes'),
          content: SizedBox(
            width: 760,
            child: _availableSchemes.isEmpty
                ? const Text('No schemes created yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availableSchemes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final scheme = _availableSchemes[index];
                      final condition = scheme.schemeType == 'TIME'
                          ? '${scheme.startTime ?? '--:--'} to ${scheme.endTime ?? '--:--'}'
                          : scheme.schemeType == 'QTY'
                              ? 'Min Qty ${scheme.minQty.toStringAsFixed(0)}'
                              : 'Min Amount Rs. ${scheme.minAmount.toStringAsFixed(2)}';
                      return ListTile(
                        title: Text(
                            '${scheme.schemeName} • ${scheme.discountType == 'PERCENT' ? '${scheme.discountValue.toStringAsFixed(0)}%' : 'Rs. ${scheme.discountValue.toStringAsFixed(2)}'}'),
                        subtitle: Text(
                          '${scheme.schemeType} • $condition • ${scheme.isActive ? 'Active' : 'Inactive'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () async {
                                final changed =
                                    await _showEditSchemeDialog(scheme);
                                if (changed) {
                                  await ctrl.refreshSchemes();
                                  if (!mounted) return;
                                  setState(_refreshSelectedScheme);
                                  refreshDialog(() {});
                                }
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () async {
                                try {
                                  await ctrl.deleteScheme(scheme.id);
                                  if (!mounted) return;
                                  setState(() {
                                    if (_selectedScheme?.id == scheme.id) {
                                      _selectedScheme = null;
                                      _schemeManuallyRemoved = false;
                                    }
                                    _refreshSelectedScheme();
                                  });
                                  refreshDialog(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Scheme ${scheme.schemeName} deleted.',
                                      ),
                                    ),
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error
                                            .toString()
                                            .replaceFirst('Exception: ', ''),
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoice(SaleOrder order) async {
    await PosInvoicePrinter.printSaleInvoice(
      order: order,
      property: propertyCtrl.data,
      cashierName: _cashierName,
      termsAndConditions:
          'Goods once sold will not be taken back. Subject to local jurisdiction.',
      thankYouMessage: 'Thank you for shopping with us. Please visit again.',
      authorizedSignatureLabel: 'Authorized Signature',
    );
  }

  Future<Printer?> _resolveDefaultPrinter() async {
    final settings = settingsCtrl.settings;
    if (settings == null || settings.defaultPrinterUrl.trim().isEmpty) {
      return null;
    }
    try {
      final printers = await Printing.listPrinters();
      return printers.cast<Printer?>().firstWhere(
            (printer) =>
                printer?.url == settings.defaultPrinterUrl ||
                printer?.name == settings.defaultPrinterName,
            orElse: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handlePrintAfterSave(SaleOrder order) async {
    final settings = settingsCtrl.settings;
    final printMode = settings?.printMode ?? 'PRINT_DIALOG';

    if (printMode == 'ASK_BEFORE_PRINT') {
      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Print Bill'),
          content: const Text('Do you want to print this bill now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (shouldPrint != true) return;
    }

    if (printMode == 'DIRECT_DEFAULT') {
      final printer = await _resolveDefaultPrinter();
      if (printer != null) {
        await PosInvoicePrinter.printSaleInvoice(
          order: order,
          property: propertyCtrl.data,
          printer: printer,
          directPrint: true,
          cashierName: _cashierName,
          termsAndConditions:
              'Goods once sold will not be taken back. Subject to local jurisdiction.',
          thankYouMessage:
              'Thank you for shopping with us. Please visit again.',
          authorizedSignatureLabel: 'Authorized Signature',
        );
        return;
      }
    }

    await _printInvoice(order);
  }

  Future<void> _openItemMaster() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ItemMasterScreen()),
    );
    await ctrl.loadInitialData();
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await settingsCtrl.load();
    _applyBillingDefaults();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final property = propertyCtrl.data;
    return Scaffold(
      backgroundColor: const Color(0xFFF4EEE8),
      // appBar: AppBar(
      //   title: const Text('Retail Sales'),
      //   actions: [
      //     TextButton.icon(
      //       onPressed: () {
      //         Navigator.of(context).push(
      //           MaterialPageRoute(
      //             builder: (_) => const SubscriptionScreen(),
      //           ),
      //         );
      //       },
      //       icon: const Icon(Icons.water_drop_outlined),
      //       label: const Text('Subscriptions'),
      //     ),
      //   ],
      // ),
      body: AnimatedBuilder(
        animation: Listenable.merge([ctrl, settingsCtrl]),
        builder: (_, __) {
          if (ctrl.loading ||
              settingsCtrl.loading ||
              settingsCtrl.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 22,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPosSidebar(
                          property?.propertyName.isNotEmpty == true
                              ? property!.propertyName
                              : 'Retail Sales',
                        ),
                        Expanded(
                          flex: 8,
                          child: _buildCatalogPane(),
                        ),
                        Container(
                          width: 360,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFC),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(26),
                              bottomRight: Radius.circular(26),
                            ),
                          ),
                          child: _buildOrderPane(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPosSidebar(String title) {
    return Container(
      width: 78,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F1EB),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          bottomLeft: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              _gobackHome();
            },
            child: Tooltip(
              message: 'Go back',
              child: Container(
                margin: const EdgeInsets.only(top: 14),
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  title.isEmpty ? 'S' : title[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sidebarButton(
            Icons.shopping_bag_outlined,
            selected: true,
            tooltip: 'Current bill',
          ),
          _sidebarButton(Icons.person_add_alt_1_rounded,
              onTap: _showCustomerDialog, tooltip: 'Add customer'),
          _sidebarButton(Icons.groups_2_outlined,
              onTap: _openCustomerListScreen, tooltip: 'Customer list'),
          _sidebarButton(Icons.drafts_outlined,
              onTap: _showDraftsDialog, tooltip: 'Draft bills'),
          _sidebarButton(Icons.inventory_2_outlined,
              onTap: _openItemMaster, tooltip: 'Item master'),
          _sidebarButton(Icons.add_card_rounded,
              onTap: _createSchemeDialog, tooltip: 'Create schemes'),
          _sidebarButton(Icons.local_offer_outlined,
              onTap: _showManageSchemesDialog, tooltip: 'Manage schemes'),
          _sidebarButton(Icons.storefront,
              onTap: _goback, tooltip: 'Receiving'),
          _sidebarButton(Icons.payment, onTap: getSub, tooltip: 'Subscription'),
          _sidebarButton(
            Icons.receipt_long_outlined,
            onTap: _openBillReprint,
            tooltip: 'Bill Reprint',
          ),
          const Spacer(),
          _sidebarButton(Icons.settings_outlined,
              onTap: _openSettings, tooltip: 'Settings'),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  void getSub() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionScreen(),
      ),
    );
  }

  void _openBillReprint() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SalesReprintModifyScreen(),
      ),
    );
  }

  void _goback() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const GoodsReceivingScreen()));
  }

  void _gobackHome() {
    Navigator.maybePop(context);
  }

  Widget _sidebarButton(
    IconData icon, {
    bool selected = false,
    VoidCallback? onTap,
    String tooltip = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFE8D8) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color:
                  selected ? const Color(0xFFFF7A1A) : const Color(0xFF7C8798),
            ),
          ),
        ),
      ),
    );
  }

  List<String> get _catalogCategories {
    final categories = <String>{'ALL'};
    for (final item in ctrl.items) {
      if (!item.isSaleable) continue;
      final value = item.itemGroup.trim().isNotEmpty
          ? item.itemGroup.trim()
          : item.subCategory.trim().isNotEmpty
              ? item.subCategory.trim()
              : 'General';
      categories.add(value);
    }
    return categories.toList();
  }

  List<Item> get _catalogItems {
    final query = _barcode.text.trim().toLowerCase();
    return ctrl.items.where((item) {
      if (!item.isSaleable) return false;
      final categoryMatch = _selectedCatalogCategory == 'ALL' ||
          item.itemGroup == _selectedCatalogCategory ||
          item.subCategory == _selectedCatalogCategory;
      final queryMatch = query.isEmpty ||
          item.itemName.toLowerCase().contains(query) ||
          item.itemCode.toLowerCase().contains(query) ||
          item.barcode.toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList();
  }

  double _cartQtyForItem(Item item) {
    return _totalCartQtyForItemId(item.id);
  }

  String _itemImageUrl(Item item) {
    final imagePath = item.imagePath.trim();
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    return AppConfig.baseUrl.endsWith('/')
        ? '${AppConfig.baseUrl}${imagePath.startsWith('/') ? imagePath.substring(1) : imagePath}'
        : '${AppConfig.baseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}';
  }

  void _adjustCatalogItemQty(Item item, double delta) {
    final currentQty = _totalCartQtyForItemId(item.id);
    final nextQty = currentQty + delta;
    if (nextQty <= 0) {
      _removeCartItemGroupById(item.id);
      return;
    }
    if (delta > 0) {
      _addOrUpdateItem(item, qty: delta);
      return;
    }

    final existingLines =
        _items.where((line) => line.itemId == item.id).toList();
    SaleItem? seed;
    for (final line in existingLines) {
      if (!line.isAdvanceFree && !line.isSchemeFree) {
        seed = line;
        break;
      }
    }

    setState(() {
      _paymentEntries = const [];
      _pendingPreviousAdjustment = 0;
      _pendingAdvanceApplied = 0;
      _pendingAdvanceCreated = 0;
      _items.removeWhere((line) => line.itemId == item.id);
      _items.insert(
          0, _buildBaseSaleItem(item: item, qty: nextQty, seed: seed));
      _syncSelectedSchemePointers();
      _rebuildItemAdvanceFreeLines();
      _rebuildItemSchemeFreeLines();
      _syncAmountPaidWithInvoice();
    });
  }

  Widget _buildCatalogPane() {
    final products = _catalogItems;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // IconButton(
              //   tooltip: 'Back',
              //   onPressed: () => Navigator.maybePop(context),
              //   icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              // ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Expanded(
                        //   child: Row(
                        //     children: [
                        //       const Text(
                        //         'Items',
                        //         style: TextStyle(
                        //           fontSize: 22,
                        //           fontWeight: FontWeight.w800,
                        //           color: Color(0xFF0F172A),
                        //         ),
                        //       ),
                        //       const SizedBox(height: 4),
                        //       Text(
                        //         '${products.length} products ready for checkout',
                        //         style: const TextStyle(
                        //           color: Color(0xFF64748B),
                        //           fontWeight: FontWeight.w600,
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Number',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Text(
                                '#${_saleNo.text}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${_items.length} items in cart',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  InkWell(
                    onTap: _resetSaleForm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Clear Order',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcode,
                  focusNode: _barcodeFocusNode,
                  autofocus:
                      !context.watch<UiPreferencesController>().touchMode,
                  onChanged: (value) {
                    setState(() {});
                    _tryAutoAddScannedItem(value);
                  },
                  onSubmitted: (_) => _handleQuickEntry(),
                  decoration: InputDecoration(
                    hintText: 'Search for items or scan barcode',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _handleQuickEntry,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _entryQty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _handleQuickEntry(),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _handleQuickEntry,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () {
                    _categoryScrollController.animateTo(
                      (_categoryScrollController.offset - 150).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _catalogCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = _catalogCategories[index];
                      final selected = category == _selectedCatalogCategory;
                      return FilterChip(
                        selected: selected,
                        showCheckmark: false,
                        label: Text(category),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: const Color(0xFFFF7A1A),
                        backgroundColor: const Color(0xFFF8FAFD),
                        side: BorderSide.none,
                        onSelected: (_) {
                          setState(() => _selectedCatalogCategory = category);
                        },
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () {
                    _categoryScrollController.animateTo(
                      (_categoryScrollController.offset + 150).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: _showItemImages ? 1.22 : 1.38,
              ),
              itemBuilder: (context, index) {
                final item = products[index];
                final cartQty = _cartQtyForItem(item);
                final isSelected = cartQty > 0;

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0, // Flat look like the image
                  color: isSelected ? const Color(0xFFFFF8F1) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFE58A20)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _addOrUpdateItem(item, qty: _entryQtyValue()),
                    child: Stack(
                      children: [
                        // --- TEXT CONTENT ---
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title (Dark Blue)
                              Padding(
                                padding: const EdgeInsets.only(
                                    right:
                                        20.0), // Breathing room for long titles
                                child: Text(
                                  item.itemName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(
                                        0xFF223854), // Exact Dark Blue from image
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Item Code (Gray, Italicized)
                              Text(
                                '#${item.itemCode}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF718096),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  fontStyle: FontStyle
                                      .italic, // Matches the image style
                                ),
                              ),

                              // HSN Code (Optional)
                              if (item.hsnSacCode.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'HSN ${item.hsnSacCode.trim()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),

                              if (cartQty > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E7),
                                    border: Border.all(
                                        color: const Color(0xFFE58A20)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'x${cartQty.toStringAsFixed(cartQty % 1 == 0 ? 0 : 2)}',
                                    style: const TextStyle(
                                      color: Color(0xFFE58A20),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],

                              const Spacer(),

                              // Price (Orange) & Cart Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Rs. ${(item.retailSalePrice > 0 ? item.retailSalePrice : item.rate).toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(
                                            0xFFD67D25), // Exact Orange from image
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  // if (!(_showItemImages &&
                                  //     item.imagePath.trim().isNotEmpty))
                                  //   if (cartQty > 0) ...[
                                  //     const SizedBox(width: 8),
                                  //     Container(
                                  //       padding: const EdgeInsets.symmetric(
                                  //           horizontal: 6, vertical: 2),
                                  //       decoration: BoxDecoration(
                                  //         color: const Color(0xFFFFF3E7),
                                  //         border: Border.all(
                                  //             color: const Color(0xFFE58A20)),
                                  //         borderRadius:
                                  //             BorderRadius.circular(6),
                                  //       ),
                                  //       child: Text(
                                  //         'x${cartQty.toStringAsFixed(cartQty % 1 == 0 ? 0 : 2)}',
                                  //         style: const TextStyle(
                                  //           color: Color(0xFFE58A20),
                                  //           fontWeight: FontWeight.bold,
                                  //           fontSize: 11,
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (_showItemImages && item.imagePath.trim().isNotEmpty)
                          Positioned(
                            right: 4,
                            bottom: 12,
                            width: 80,
                            height: 60,
                            child: Image.network(
                              _itemImageUrl(item),
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomRight,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _buildSchemeSelectionBar(),
        ],
      ),
    );
  }

  Widget _buildSchemeSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Select available scheme for this sale',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF33506B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 36,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  onPressed: () {
                    _schemeSelectionScrollController.animateTo(
                      (_schemeSelectionScrollController.offset - 150).clamp(0.0, _schemeSelectionScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _schemeSelectionScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableSchemes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final scheme = _availableSchemes[index];
                      final selected =
                          _hasCustomerContext && _isSchemeChipSelected(scheme);
                      return FilterChip(
                        selected: selected,
                        onSelected: !_hasCustomerContext
                            ? null
                            : (isSelected) {
                                if (isSelected) {
                                  _selectSchemeWithUsage(
                                    scheme,
                                    preserveExistingSelections: true,
                                  );
                                } else {
                                  _toggleSelectedSchemeChip(scheme);
                                }
                              },
                        label: Text(scheme.schemeName),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  onPressed: () {
                    _schemeSelectionScrollController.animateTo(
                      (_schemeSelectionScrollController.offset + 150).clamp(0.0, _schemeSelectionScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddedItemsPane() {
    final computedItems = _invoice.items;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Added Items',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${computedItems.length} lines • Qty ${_invoice.totalQty.toStringAsFixed(_invoice.totalQty % 1 == 0 ? 0 : 2)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _resetSaleForm,
                child: const Text('Clear Order'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: computedItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items added yet.\nScan barcode or tap a product.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: computedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final line = computedItems[index];
                      return Dismissible(
                        key: ValueKey('main-cart-${line.itemId}-$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          _removeCartItemGroupById(line.itemId);
                        },
                        child: _buildCartLineTile(line, index),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniInfoCard('Sub Total', _invoice.subTotal),
              _miniInfoCard('Discount', _invoice.totalDiscount),
              _miniInfoCard('Tax', _invoice.totalTax),
              _miniInfoCard('Total', _invoice.netAmount, highlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPane() {
    final invoice = _invoice;
    final computedItems = invoice.items;
    final paymentState = _currentPaymentState;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: computedItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items in order',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                : ListView.separated(
                    itemCount: computedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final line = computedItems[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6EAF0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          line.itemName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            height: 1.15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    ' (${line.unit})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 8),
                                  ),
                                  // const SizedBox(height: 4),
                                  // Text(
                                  //   'Rs. ${line.rate.toStringAsFixed(2)}',
                                  //   style: const TextStyle(
                                  //     color: Color(0xFF64748B),
                                  //     fontWeight: FontWeight.w600,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                            _qtyStepper(line, index),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 62,
                              child: Text(
                                _displayLineTotal(line).toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          //   const SizedBox(height: 12),
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Customer',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _customerIconAction(
                      tooltip: 'Select Customer',
                      onPressed: _showCustomerPickerDialog,
                      icon: Icons.person_search_outlined,
                      backgroundColor: const Color(0xFFE8F0FE),
                      foregroundColor: const Color(0xFF1D4ED8),
                    ),
                    _customerIconAction(
                      tooltip: 'Add Customer',
                      onPressed: _showCustomerDialog,
                      icon: Icons.person_add_alt_1_rounded,
                      backgroundColor: const Color(0xFFEAF8EE),
                      foregroundColor: const Color(0xFF15803D),
                    ),
                    if (_hasCustomerContext)
                      _customerIconAction(
                        tooltip: 'Remove Customer',
                        onPressed: _setGuestCustomer,
                        icon: Icons.person_remove_alt_1_rounded,
                        backgroundColor: const Color(0xFFFDECEC),
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                  ],
                ),
                if (_customerPhone.text.trim().isNotEmpty)
                  Text(
                    _customerName.text.trim().isEmpty
                        ? 'Walk-in Customer'
                        : _customerName.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (_customerPhone.text.trim().isNotEmpty)
                  Text(_customerPhone.text.trim()),
                if (_previousOutstandingAmount > 0 &&
                    _customerPhone.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Previous Credit Rs. ${_previousOutstandingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_availableAdvanceAmount > 0 &&
                    _customerPhone.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Available Advance Rs. ${_availableAdvanceAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_hasCustomerContext) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Available Points: $_availableLoyaltyPoints',
                          style: TextStyle(
                            color: _loyaltyProgramActive
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openRedeemPointsDialog,
                        icon: const Icon(Icons.redeem),
                        label: const Text('Redeem Points'),
                      ),
                    ],
                  ),
                ],
                if (_redeemPointsInput > 0 && _hasCustomerContext) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Savings by points redeemed: $_redeemPointsInput points (- Rs. ${_loyaltyDiscountAmount.toStringAsFixed(2)})',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                _buildCustomerItemAdvanceSummary(),
                //   const SizedBox(height: 8),
                // Text(
                //   _schemeFeedbackMessage,
                //   style: const TextStyle(
                //     color: Color(0xFF64748B),
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
                // const SizedBox(height: 8),
                // Row(
                //   children: [
                //     OutlinedButton.icon(
                //       onPressed: _showCustomerPickerDialog,
                //       icon: const Icon(Icons.badge_outlined, size: 18),
                //       label: const Text('Select'),
                //     ),
                //     const SizedBox(width: 8),
                //     TextButton(
                //       onPressed: _setGuestCustomer,
                //       child: const Text('Walk-in'),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _surfaceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bill Totals',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tintedActionButton(
                          icon: Icons.percent,
                          onPressed: _showTaxModeDialog,
                          backgroundColor: const Color(0xFFE0F2FE),
                          foregroundColor: const Color(0xFF0369A1),
                          tooltip: 'Select tax mode',
                        ),
                        _tintedActionButton(
                          icon: Icons.add_card_rounded,
                          onPressed: _showDiscountDialog,
                          backgroundColor: const Color(0xFFFFF4DB),
                          foregroundColor: const Color(0xFFB45309),
                          tooltip: 'Add or edit discount',
                        ),
                        _tintedActionButton(
                          icon: Icons.backspace_outlined,
                          onPressed: _manualDiscountAmount > 0.009 ||
                                  (double.tryParse(
                                            _manualDiscountValue.text.trim(),
                                          ) ??
                                          0) >
                                      0.009
                              ? _clearManualDiscount
                              : null,
                          backgroundColor: const Color(0xFFFDECEC),
                          foregroundColor: const Color(0xFFDC2626),
                          tooltip: 'Remove discount only',
                        ),
                        _tintedActionButton(
                          icon: Icons.local_shipping_outlined,
                          onPressed: _addCustomChargeDialog,
                          backgroundColor: const Color(0xFFE8F0FE),
                          foregroundColor: const Color(0xFF1D4ED8),
                          tooltip: 'Add delivery or other charge',
                        ),
                        _tintedActionButton(
                          icon: Icons.delete_sweep_outlined,
                          onPressed: _activeCharges.isNotEmpty
                              ? _clearAllCharges
                              : null,
                          backgroundColor: const Color(0xFFFDECEC),
                          foregroundColor: const Color(0xFFDC2626),
                          tooltip: 'Remove charges only',
                        ),
                      ],
                    ),
                  ],
                ),
                _summaryRow('Sub Total', invoice.subTotal),
                _summaryRow('Discount', invoice.totalDiscount),
                _summaryRow('Charges', invoice.chargeTotal),
                _summaryRow('Tax', invoice.totalTax),
                const Divider(height: 18),
                _summaryRow('Total', _payableInvoiceTotal, emphasized: true),
              ],
            ),
          ),
          // const SizedBox(height: 10),
          // _surfaceCard(
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       const Text(
          //         'Payment',
          //         style: TextStyle(fontWeight: FontWeight.w800),
          //       ),
          //       const SizedBox(height: 8),
          //       Text(_paymentSummaryText(_resolvedPaymentEntries)),
          //       const SizedBox(height: 6),
          //       Text(
          //         'Outstanding Rs. ${paymentState.balanceDue.toStringAsFixed(2)}',
          //       ),
          //       Text(
          //         'Refund Rs. ${paymentState.refundAmount.toStringAsFixed(2)}',
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _persistSale(
                    status: _editingSaleId != null ? 'COMPLETED' : 'DRAFT',
                    printAfterSave: false,
                  ),
                  child: Text(
                    _editingSaleId != null ? 'Update' : 'Save Draft',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openPaymentSheet(printAfterSave: true),
                  child: const Text('Print'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyStepper(SaleItem line, int index) {
    final isFree = line.isSchemeFree || line.isAdvanceFree;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed:
                isFree ? null : () => _updateLineQty(index, line.qty - 1),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
          ),
          InkWell(
            onTap: () {
              _editQtyDialog(index);
            },
            child: Text(
              line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed:
                isFree ? null : () => _updateLineQty(index, line.qty + 1),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPane() {
    final invoice = _invoice;
    final paymentState = _currentPaymentState;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF1),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer & Checkout',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeDraftId != null
                            ? 'Draft ${_saleNo.text}'
                            : 'Bill ${_saleNo.text}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delivery Orders',
                  onPressed: _showDraftsDialog,
                  icon: const Icon(Icons.drafts_outlined),
                ),
                IconButton(
                  tooltip: 'New Bill',
                  onPressed: _resetSaleForm,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCustomerCard(),
            const SizedBox(height: 12),
            _buildBillingConfigCard(),
            const SizedBox(height: 12),
            _buildChargesSummary(),
            const SizedBox(height: 12),
            _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _paymentSummaryText(_resolvedPaymentEntries),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Collected Rs. ${paymentState.collectedAmount.toStringAsFixed(2)}'),
                  if (paymentState.advanceAppliedAmount > 0)
                    Text(
                        'Advance Used Rs. ${paymentState.advanceAppliedAmount.toStringAsFixed(2)}'),
                  Text(
                      'Outstanding Rs. ${paymentState.balanceDue.toStringAsFixed(2)}'),
                  if (paymentState.refundAmount > 0)
                    Text(
                      'Refund Rs. ${paymentState.refundAmount.toStringAsFixed(2)} in CASH',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Text(
                      'Refund Rs. ${paymentState.refundAmount.toStringAsFixed(2)}',
                    ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () => _showPaymentDialog().then((result) {
                      if (result == null || !mounted) return;
                      setState(() {
                        _paymentEntries = result.entries;
                        _paymentMode = result.summary.primaryMode;
                        _amountPaid.text =
                            result.summary.collectedAmount.toStringAsFixed(2);
                      });
                    }),
                    icon: const Icon(Icons.point_of_sale_outlined),
                    label: const Text('Open Payment'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTotalsSummary(invoice),
            if (_editingSaleId != null) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Affect Stock'),
                subtitle: const Text(
                  'Turn off to update bill amounts only without changing stock.',
                ),
                value: _affectStockOnEdit,
                onChanged: (value) {
                  setState(() => _affectStockOnEdit = value);
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _persistSale(
                      status: _editingSaleId != null ? 'COMPLETED' : 'DRAFT',
                      printAfterSave: false,
                    ),
                    icon: const Icon(Icons.save_as_outlined),
                    label: Text(
                      _editingSaleId != null ? 'Update Bill' : 'Save Draft',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openPaymentSheet(printAfterSave: false),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _editingSaleId != null ? 'Update Bill' : 'Save Bill',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openPaymentSheet(printAfterSave: true),
              icon: const Icon(Icons.print_outlined),
              label: Text(
                _editingSaleId != null ? 'Update & Print' : 'Save & Print',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SalesReprintModifyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Reprint / Modify Bill'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutPane() {
    final invoice = _invoice;
    final computedItems = invoice.items;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF1),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. FIXED HEADER ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Order',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeDraftId != null
                            ? 'Draft ${_saleNo.text}'
                            : 'Order ${_saleNo.text}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _showDraftsDialog,
                  icon: const Icon(Icons.drafts_outlined),
                  label: const Text('Delivery Order'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesReprintModifyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Reprint / Modify Bill'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => setState(() {
                    _paymentEntries = const [];
                    _pendingPreviousAdjustment = 0;
                    _pendingAdvanceApplied = 0;
                    _pendingAdvanceCreated = 0;
                    _items.clear();
                    _syncAmountPaidWithInvoice();
                    _refreshSelectedScheme();
                  }),
                  child: const Text('Clear Order'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _resetSaleForm,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('New Bill'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- 2. SCROLLABLE MIDDLE SECTION ---
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: computedItems.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(
                              32.0), // Added padding so it doesn't look cramped
                          child: Center(
                            child: Text(
                              'No items added yet. Tap a product card or scan a barcode.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          // CRITICAL: These two lines allow the ListView to sit safely inside the SingleChildScrollView
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: computedItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final line = computedItems[index];
                            return Dismissible(
                              key: ValueKey('${line.itemId}-$index'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) {
                                _removeCartItemGroupById(line.itemId);
                              },
                              child: _buildCartLineTile(line, index),
                            );
                          },
                        ),
                ),
                const SizedBox(
                  height: 10,
                ),
                _buildCustomerCard(),
                const SizedBox(height: 12),
                _buildBillingConfigCard(),
                const SizedBox(height: 12),

                // Cart Items Container
              ],
            ),

            // --- 3. FIXED FOOTER (Totals & Action Buttons) ---
            const SizedBox(height: 12),
            _buildChargesSummary(),
            const SizedBox(height: 12),
            _buildTotalsSummary(invoice),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _persistSale(
                      status: _editingSaleId != null ? 'COMPLETED' : 'DRAFT',
                      printAfterSave: false,
                    ),
                    icon: const Icon(Icons.save_as_outlined),
                    label: Text(
                      _editingSaleId != null ? 'Update Bill' : 'Save Draft',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _persistSale(status: 'COMPLETED', printAfterSave: true),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(
                      _editingSaleId != null
                          ? 'Update & Print'
                          : 'Save & Print',
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

  Widget _buildCustomerCard() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownSearch<SaleCustomer>(
                  selectedItem: _selectedCustomer,
                  items: (filter, _) async => filter.isEmpty
                      ? ctrl.customers
                      : await ctrl.searchCustomers(filter),
                  itemAsString: (customer) => customer.displayLabel,
                  compareFn: (first, second) => first.id == second.id,
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: 'Search Existing Customer',
                      hintText: 'Search by name or mobile',
                    ),
                  ),
                  onChanged: (customer) {
                    if (customer != null) {
                      _applyCustomer(customer);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Open complete customer list',
                child: OutlinedButton.icon(
                  onPressed: _openCustomerListScreen,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Customer List'),
                ),
              ),
            ],
          ),
          if (_selectedCustomer != null ||
              _customerName.text.trim().isNotEmpty ||
              _customerPhone.text.trim().isNotEmpty ||
              _customerAddress.text.trim().isNotEmpty ||
              _customerGstin.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _customerName.text.trim().isEmpty
                              ? 'Walk-in Customer'
                              : _customerName.text.trim(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Edit selected customer details',
                        child: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => _selectedCustomer != null
                                  ? _showEditExistingCustomerDialog(
                                      _selectedCustomer!,
                                    )
                                  : _showCustomerDialog(clearSelection: false),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              onPressed: _setGuestCustomer,
                              icon: const Icon(
                                Icons.person_remove_alt_1_rounded,
                                size: 18,
                              ),
                              label: const Text('Remove'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_customerPhone.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_customerPhone.text.trim()),
                  ],
                  if (_customerAddress.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_customerAddress.text.trim()),
                  ],
                  if (_customerGstin.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('GST: ${_customerGstin.text.trim()}'),
                  ],
                  if (_availableAdvanceAmount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Available Advance: Rs. ${_availableAdvanceAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Available Points: $_availableLoyaltyPoints',
                          style: TextStyle(
                            color: _loyaltyProgramActive
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openRedeemPointsDialog,
                        icon: const Icon(Icons.redeem),
                        label: const Text('Redeem Points'),
                      ),
                    ],
                  ),
                  if (_redeemPointsInput > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Savings by points redeemed: $_redeemPointsInput points (- Rs. ${_loyaltyDiscountAmount.toStringAsFixed(2)})',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  _buildCustomerItemAdvanceSummary(),
                  if (_previousOutstandingAmount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Outstanding: Rs. ${_previousOutstandingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingConfigCard() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scheme, Discount & Charges',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          DropdownSearch<SaleScheme>(
            selectedItem: _selectedScheme,
            items: (filter, _) async {
              if (!_hasCustomerContext) return const <SaleScheme>[];
              if (filter.isEmpty) return _availableSchemes;
              return _availableSchemes
                  .where((scheme) => scheme.schemeName
                      .toLowerCase()
                      .contains(filter.toLowerCase()))
                  .toList();
            },
            itemAsString: (scheme) => scheme.schemeName,
            compareFn: (first, second) => first.id == second.id,
            popupProps: const PopupProps.menu(showSearchBox: true),
            decoratorProps: const DropDownDecoratorProps(
              decoration: InputDecoration(
                labelText: 'Search Scheme',
                hintText: 'Select customer scheme',
              ),
            ),
            enabled: _hasCustomerContext,
            onChanged: (scheme) => _selectSchemeWithUsage(scheme),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('schemeUsageMode-$_schemeUsageMode'),
            initialValue: _schemeUsageMode,
            decoration: const InputDecoration(labelText: 'Scheme Apply'),
            items: const [
              DropdownMenuItem(
                value: 'APPLY_NOW',
                child: Text('Apply Scheme Now'),
              ),
              DropdownMenuItem(
                value: 'NEXT_PURCHASE',
                child: Text('Use In Next Purchase'),
              ),
            ],
            onChanged: _selectedSchemes.isEmpty
                ? null
                : (value) => setState(
                      () => _schemeUsageMode = value ?? 'APPLY_NOW',
                    ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_selectedSchemes.isNotEmpty)
                Text(
                  'Selected: ${_selectedSchemes.map((scheme) => scheme.schemeName).join(', ')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                )
              else
                const Text(
                  'No scheme selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              const Spacer(),
              Tooltip(
                message: 'Remove the selected scheme for this order',
                child: TextButton.icon(
                  onPressed: _selectedSchemes.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _selectedSchemes.clear();
                            _selectedScheme = null;
                            _selectedItemScheme = null;
                            _schemeManuallyRemoved = true;
                            _schemeUsageMode = 'APPLY_NOW';
                          });
                          _refreshSelectedScheme();
                          _refreshItemSchemeStatus();
                          _syncAmountPaidWithInvoice();
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('Remove Scheme'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('orderType-$_orderType'),
                  initialValue: _orderType,
                  items: const [
                    DropdownMenuItem(value: 'B2C', child: Text('B2C')),
                    DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                  ],
                  onChanged: (value) =>
                      setState(() => _orderType = value ?? 'B2C'),
                  decoration: const InputDecoration(labelText: 'Bill Type'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Bill Note'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('discountType-$_manualDiscountType'),
                  initialValue: _manualDiscountType,
                  items: const [
                    DropdownMenuItem(
                        value: 'AMOUNT', child: Text('Discount Amount')),
                    DropdownMenuItem(
                        value: 'PERCENT', child: Text('Discount %')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _manualDiscountType = value ?? 'AMOUNT';
                      _syncAmountPaidWithInvoice();
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Discount'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _manualDiscountValue,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(_syncAmountPaidWithInvoice),
                  decoration: const InputDecoration(labelText: 'Amount / %'),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _manualDiscountAmount > 0.009 ||
                        (double.tryParse(_manualDiscountValue.text.trim()) ??
                                0) >
                            0.009
                    ? _clearManualDiscount
                    : null,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
          if (_schemeFooterMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD5B0)),
              ),
              child: Text(
                _schemeFooterMessage!,
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _schemeFeedbackColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _schemeFeedbackMessage,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bill Format: $_billFormatLabel',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartLineTile(SaleItem line, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: Color(0xFFFF7A1A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${line.itemCode}  |  ${line.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text(
                        line.discountApplicable
                            ? 'Discount On'
                            : 'Discount Off',
                      ),
                      onPressed: () {
                        setState(() {
                          _items[index] = _items[index].copyWith(
                            discountApplicable:
                                !_items[index].discountApplicable,
                          );
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Edit Qty'),
                      onPressed: () => _editQtyDialog(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Container(
            height: 38,
            width: 118,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: IconButton(
                    onPressed: (line.isSchemeFree || line.isAdvanceFree)
                        ? null
                        : () => _updateLineQty(index, line.qty - 1),
                    icon: const Icon(Icons.remove_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Text(
                  line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Expanded(
                  child: IconButton(
                    onPressed: (line.isSchemeFree || line.isAdvanceFree)
                        ? null
                        : () => _updateLineQty(index, line.qty + 1),
                    icon: const Icon(Icons.add_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesSummary() {
    final activeCharges = _activeCharges;
    if (activeCharges.isEmpty) {
      return _surfaceCard(
        child: Row(
          children: [
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addCustomChargeDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Charge'),
            ),
          ],
        ),
      );
    }

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Additional Charges',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: activeCharges.isNotEmpty ? _clearAllCharges : null,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addCustomChargeDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(activeCharges.length, (index) {
            final charge = activeCharges[index];
            final chargeIndex = _charges.indexOf(charge);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(charge.name),
                      subtitle: Text(_chargeDescriptor(charge)),
                      value: charge.isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _charges[chargeIndex] =
                              charge.copyWith(isEnabled: value);
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: charge.calculationValue.toStringAsFixed(
                        charge.calculationValue % 1 == 0 ? 0 : 2,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            charge.calculationType == 'PERCENT' ? '%' : 'Amt',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _charges[chargeIndex] = charge.copyWith(
                            amount: charge.calculationType == 'PERCENT'
                                ? charge.amount
                                : (double.tryParse(value.trim()) ?? 0),
                            calculationValue:
                                double.tryParse(value.trim()) ?? 0,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalsSummary(InvoiceComputation invoice) {
    return _surfaceCard(
      child: Column(
        children: [
          _summaryRow('Total Qty', invoice.totalQty),
          _summaryRow('Sub Total', invoice.subTotal),
          if (_subscriptionItemAdvanceDiscount > 0)
            _summaryRow(
                'Subscription Item Discount', _subscriptionItemAdvanceDiscount),
          _summaryRow('Scheme Savings', _totalSchemeSavingsAmount),
          _summaryRow('Discount', _manualDiscountAmount),
          if (_loyaltyDiscountAmount > 0)
            _summaryRow('Loyalty Discount', _loyaltyDiscountAmount),
          _summaryRow('Charges', invoice.chargeTotal),
          _summaryRow('Tax', invoice.totalTax),
          const Divider(height: 24),
          _summaryRow('Total', _payableInvoiceTotal, emphasized: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool emphasized = false}) {
    final style = TextStyle(
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      fontSize: emphasized ? 20 : 14,
      color: const Color(0xFF0F172A),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('Rs. ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _buildSchemeStrip() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Select Available Promo to Apply',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF33506B),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '(Limit 1 per order)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _voucherCode,
                  onSubmitted: _applyVoucherCode,
                  decoration: InputDecoration(
                    hintText: 'Voucher code',
                    isDense: true,
                    suffixIcon: IconButton(
                      onPressed: _applyVoucherCode,
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          Row(
            children: [
              Tooltip(
                message: 'Create a new voucher',
                child: OutlinedButton.icon(
                  onPressed: _showCreateVoucherDialog,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Create Voucher'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Open voucher management',
                child: OutlinedButton.icon(
                  onPressed: _showManageVouchersDialog,
                  icon: const Icon(Icons.tune_outlined),
                  label: const Text('Manage Vouchers'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Open scheme management',
                child: OutlinedButton.icon(
                  onPressed: _showManageSchemesDialog,
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('Manage Schemes'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Open complete customer list',
                child: OutlinedButton.icon(
                  onPressed: _openCustomerListScreen,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Customer List'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Open sales report management',
                child: OutlinedButton.icon(
                  onPressed: _openSalesReport,
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('Manage Report'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () {
                    _schemeStripScrollController.animateTo(
                      (_schemeStripScrollController.offset - 150).clamp(0.0, _schemeStripScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _schemeStripScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableSchemes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final scheme = _availableSchemes[index];
                      final selected = _selectedScheme?.id == scheme.id ||
                          _selectedItemScheme?.id == scheme.id;
                      return Tooltip(
                        message: selected
                            ? 'Click again to remove ${scheme.schemeName}'
                            : 'Click to apply ${scheme.schemeName}',
                        child: OutlinedButton(
                          onPressed: () => scheme.schemeScope.toUpperCase() == 'ITEM'
                              ? (selected
                                  ? _setSelectedItemScheme(null, manual: true)
                                  : _selectSchemeWithUsage(scheme))
                              : (selected
                                  ? _setSelectedScheme(null, manual: true)
                                  : _selectSchemeWithUsage(scheme)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                selected ? const Color(0xFFFFF3E7) : Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFFF7A1A)
                                  : const Color(0xFFE2E8F0),
                              width: selected ? 1.6 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: Text(
                            scheme.schemeName,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFFE56A00)
                                  : const Color(0xFF475569),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () {
                    _schemeStripScrollController.animateTo(
                      (_schemeStripScrollController.offset + 150).clamp(0.0, _schemeStripScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ],
            ),
          ),
          if (_appliedVoucher != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD5B0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: Color(0xFFFF7A1A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _voucherUsageMode == 'APPLY_NOW'
                              ? 'Voucher ${_appliedVoucher!.code} will apply now'
                              : 'Voucher ${_appliedVoucher!.code} will print for next purchase',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'APPLY_NOW',
                              label: Text('Apply Now'),
                            ),
                            ButtonSegment<String>(
                              value: 'NEXT_PURCHASE',
                              label: Text('Next Purchase'),
                            ),
                          ],
                          selected: {_voucherUsageMode},
                          onSelectionChanged: (value) {
                            setState(() {
                              _voucherUsageMode = value.first;
                            });
                          },
                        ),
                        if (_voucherUsageMode == 'NEXT_PURCHASE') ...[
                          const SizedBox(height: 8),
                          Text(
                            _voucherFooterMessage ?? '',
                            style: const TextStyle(
                              color: Color(0xFF7C2D12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _appliedVoucher = null;
                        _voucherCode.clear();
                        _voucherUsageMode = 'APPLY_NOW';
                      });
                    },
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _headerCard() {
    return _card(
      title: 'Sale Header',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _compactField(_saleNo, 'Sale No', width: 140, readOnly: true),
              _compactField(_saleDateCtrl, 'Sale Date',
                  width: 180, readOnly: true),
              _compactField(_customerName, 'Customer Name',
                  width: 180,
                  onChanged: (value) => _searchCustomerMatches(value)),
              _compactField(_customerPhone, 'Mobile',
                  width: 150,
                  onChanged: (value) => _searchCustomerMatches(value)),
              SizedBox(
                width: 260,
                child: DropdownSearch<SaleCustomer>(
                  selectedItem: _selectedCustomer,
                  items: (filter, _) async => filter.isEmpty
                      ? ctrl.customers
                      : await ctrl.searchCustomers(filter),
                  itemAsString: (customer) => customer.displayLabel,
                  compareFn: (first, second) => first.id == second.id,
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: 'Search Customer',
                      hintText: 'Mobile or name',
                    ),
                  ),
                  onChanged: (customer) {
                    if (customer != null) _applyCustomer(customer);
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('orderType-$_orderType'),
                  initialValue: _orderType,
                  items: const [
                    DropdownMenuItem(value: 'B2C', child: Text('B2C Sale')),
                    DropdownMenuItem(value: 'B2B', child: Text('B2B Sale')),
                  ],
                  onChanged: (value) {
                    setState(() => _orderType = value ?? 'B2C');
                  },
                  decoration: const InputDecoration(labelText: 'Bill Type'),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('paymentMode-$_paymentMode'),
                  initialValue: _paymentMode,
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                    DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _paymentMode = value ?? 'CASH';
                      if (_paymentMode == 'CREDIT') {
                        _amountPaid.text = '0';
                      }
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Payment'),
                ),
              ),
              _compactField(_amountPaid, 'Amount Paid', width: 130),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: TextEditingController(
                    text: (_paymentMode == 'CREDIT'
                            ? _balanceDueAmount
                            : _refundAmount)
                        .toStringAsFixed(2),
                  ),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText:
                        _paymentMode == 'CREDIT' ? 'Outstanding' : 'Refund',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _compactField(_customerAddress, 'Customer Address', width: 280),
              if (_orderType == 'B2B')
                _compactField(_customerGstin, 'Customer GSTIN', width: 180),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('taxMode-$_taxMode'),
                  initialValue: _taxMode,
                  items: const [
                    DropdownMenuItem(
                        value: 'CGST_SGST', child: Text('CGST + SGST')),
                    DropdownMenuItem(value: 'IGST', child: Text('IGST')),
                    DropdownMenuItem(value: 'VAT', child: Text('VAT')),
                    DropdownMenuItem(value: 'CESS', child: Text('CESS')),
                    DropdownMenuItem(
                        value: 'CUSTOM', child: Text('Custom Tax')),
                    DropdownMenuItem(value: 'NONE', child: Text('No Tax')),
                  ],
                  onChanged: (value) {
                    setState(() => _taxMode = value ?? 'NONE');
                  },
                  decoration: const InputDecoration(labelText: 'Tax Mode'),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: TextEditingController(text: _billingCountry),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: TextEditingController(
                    text: _billFormatLabel,
                  ),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Bill Format'),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedScheme?.id,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Scheme'),
                    ),
                    ..._availableSchemes.map(
                      (scheme) => DropdownMenuItem<int?>(
                        value: scheme.id,
                        child: Text(scheme.schemeName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _setSelectedScheme(
                      value == null
                          ? null
                          : _availableSchemes.cast<SaleScheme?>().firstWhere(
                                (scheme) => scheme?.id == value,
                                orElse: () => null,
                              ),
                      manual: true,
                    );
                  },
                  decoration: const InputDecoration(labelText: 'Offer Scheme'),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('discountType-$_manualDiscountType'),
                  initialValue: _manualDiscountType,
                  items: const [
                    DropdownMenuItem(
                        value: 'AMOUNT', child: Text('Disc Amount')),
                    DropdownMenuItem(value: 'PERCENT', child: Text('Disc %')),
                  ],
                  onChanged: (value) {
                    setState(() => _manualDiscountType = value ?? 'AMOUNT');
                  },
                  decoration:
                      const InputDecoration(labelText: 'Manual Discount'),
                ),
              ),
              _compactField(_manualDiscountValue, 'Discount Value', width: 130),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ),
              FilledButton.icon(
                onPressed: _createSchemeDialog,
                icon: const Icon(Icons.local_offer_outlined),
                label: const Text('Create Scheme'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _schemeFeedbackColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _schemeFeedbackMessage,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_selectedScheme != null)
                  Text(
                    '$_billFormatLabel | Discount ${_schemeDiscountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          if (_selectedItemScheme != null &&
              _selectedItemScheme!.schemeScope.toUpperCase() == 'ITEM')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loadingItemSchemeStatus
                            ? 'Loading item scheme status...'
                            : _itemSchemeProgress == null
                                ? 'Select customer to view item scheme progress.'
                                : _formatItemSchemeStatus(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Add Item Advance (Qty)',
                      onPressed: _hasCustomerContext &&
                              _selectedItemScheme?.schemeScope.toUpperCase() ==
                                  'ITEM' &&
                              (_selectedItemScheme?.itemId ?? 0) > 0
                          ? _showAddItemAdvanceDialog
                          : null,
                      icon: const Icon(Icons.add_card_outlined),
                    ),
                    IconButton(
                      tooltip: 'Enroll Customer (Start Date)',
                      onPressed: _hasCustomerContext &&
                              _selectedItemScheme?.schemeScope.toUpperCase() ==
                                  'ITEM' &&
                              (_selectedItemScheme?.id ?? 0) > 0 &&
                              (_itemSchemeProgress?['enrolled'] != true)
                          ? _showEnrollItemSchemeDialog
                          : null,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddItemAdvanceDialog() async {
    final scheme = _selectedItemScheme;
    if (!_hasCustomerContext ||
        scheme == null ||
        scheme.schemeScope.toUpperCase() != 'ITEM' ||
        scheme.itemId == null ||
        scheme.itemId! <= 0) {
      return;
    }

    final qtyCtrl = TextEditingController(
      text: scheme.minQty.toStringAsFixed(scheme.minQty % 1 == 0 ? 0 : 2),
    );
    final amountCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController(text: 'Item advance');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Item Advance (Qty)'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Advance Qty',
                  helperText: 'Example: 30 qty for 1200 amount',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Advance Amount',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (qty > 0) {
        await ctrl.createItemAdvance(
          customerName: _customerName.text.trim(),
          customerPhone: _customerPhone.text.trim(),
          customerGstin: _customerGstin.text.trim(),
          itemId: scheme.itemId!,
          qty: qty,
          advanceDate: _saleDate,
          rate: amount > 0 ? amount / qty : 0,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
        await _refreshItemSchemeStatus();
      }
    }

    qtyCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _showItemAdvanceLedgerDialog() async {
    final scheme = _selectedItemScheme;
    if (!_hasCustomerContext ||
        scheme == null ||
        scheme.schemeScope.toUpperCase() != 'ITEM' ||
        scheme.itemId == null ||
        scheme.itemId! <= 0) {
      return;
    }

    DateTime? startDate;
    final data = _itemSchemeProgress;
    if (data != null && data['enrollment'] is Map) {
      final enrollment =
          Map<String, dynamic>.from(data['enrollment'] ?? const {});
      startDate =
          DateTime.tryParse((enrollment['start_date'] ?? '').toString());
    }
    final fromDate = startDate ?? _saleDate.subtract(const Duration(days: 30));
    final toDate = _saleDate;

    Map<String, dynamic> ledger = const {};
    try {
      ledger = await ctrl.getItemAdvanceLedger(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        itemId: scheme.itemId!,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load item advance ledger')),
      );
      return;
    }

    if (!mounted) return;

    final advances = (ledger['advances'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final consumptions = (ledger['consumptions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    double num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    final purchasedQty =
        advances.fold<double>(0, (sum, r) => sum + num(r['original_qty']));
    final consumedQty =
        consumptions.fold<double>(0, (sum, r) => sum + num(r['qty']));
    final leftQty = (purchasedQty - consumedQty).clamp(0, double.infinity);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Advance Ledger'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From ${DateFormat('dd-MMM-yyyy').format(fromDate)} to ${DateFormat('dd-MMM-yyyy').format(toDate)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Purchased: ${purchasedQty.toStringAsFixed(purchasedQty % 1 == 0 ? 0 : 2)} | '
                  'Consumed: ${consumedQty.toStringAsFixed(consumedQty % 1 == 0 ? 0 : 2)} | '
                  'Left: ${leftQty.toStringAsFixed(leftQty % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Divider(height: 22),
                const Text('Advance Purchases',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (advances.isEmpty)
                  const Text('No advance purchases in this period.')
                else
                  ...advances.map((r) {
                    final dt =
                        DateTime.tryParse((r['advance_date'] ?? '').toString());
                    final dateText = dt == null
                        ? '--'
                        : DateFormat('dd-MMM-yyyy').format(dt);
                    final qty = num(r['original_qty']);
                    final note = (r['note'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$dateText • Qty ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}${note.isEmpty ? '' : ' • $note'}',
                      ),
                    );
                  }),
                const Divider(height: 22),
                const Text('Consumed In Bills',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (consumptions.isEmpty)
                  const Text('No consumption in this period.')
                else
                  ...consumptions.map((r) {
                    final dt =
                        DateTime.tryParse((r['sale_day'] ?? '').toString());
                    final dateText = dt == null
                        ? '--'
                        : DateFormat('dd-MMM-yyyy').format(dt);
                    final saleNo = (r['sale_no'] ?? '').toString();
                    final qty = num(r['qty']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$dateText • $saleNo • Qty ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemAdvanceDialogForItem(Item item) async {
    final qtyCtrl = TextEditingController(text: '1');
    final amountCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController(text: 'Item advance');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add Item Advance (${item.itemName})'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Advance Qty',
                  helperText: 'Example: 30 qty for 1200 amount',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Advance Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (qty > 0) {
        await ctrl.createItemAdvance(
          customerName: _customerName.text.trim(),
          customerPhone: _customerPhone.text.trim(),
          customerGstin: _customerGstin.text.trim(),
          itemId: item.id,
          qty: qty,
          advanceDate: _saleDate,
          rate: amount > 0 ? amount / qty : 0,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
        await _refreshSelectedItemAdvanceStatus();
      }
    }

    qtyCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _showItemAdvanceLedgerDialogForItem(Item item) async {
    if (!_hasCustomerContext) return;

    final ledger = await ctrl.getItemAdvanceLedger(
      customerName: _customerName.text.trim(),
      customerPhone: _customerPhone.text.trim(),
      customerGstin: _customerGstin.text.trim(),
      itemId: item.id,
      fromDate: _saleDate.subtract(const Duration(days: 30)),
      toDate: _saleDate,
    );

    if (!mounted) return;

    final advances = (ledger['advances'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final consumptions = (ledger['consumptions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    double num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    final purchasedQty =
        advances.fold<double>(0, (sum, r) => sum + num(r['original_qty']));
    final consumedQty =
        consumptions.fold<double>(0, (sum, r) => sum + num(r['qty']));
    final leftQty = (purchasedQty - consumedQty).clamp(0, double.infinity);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Advance Ledger (${item.itemName})'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Customer: ${_customerName.text.trim().isEmpty ? 'Walk-in' : _customerName.text.trim()}'),
                const SizedBox(height: 8),
                Text(
                  'From ${DateFormat('dd-MMM-yyyy').format(_saleDate.subtract(const Duration(days: 30)))} to ${DateFormat('dd-MMM-yyyy').format(_saleDate)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Purchased: ${purchasedQty.toStringAsFixed(purchasedQty % 1 == 0 ? 0 : 2)} | '
                  'Consumed: ${consumedQty.toStringAsFixed(consumedQty % 1 == 0 ? 0 : 2)} | '
                  'Left: ${leftQty.toStringAsFixed(leftQty % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Divider(height: 22),
                const Text('Advance Purchases',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (advances.isEmpty)
                  const Text('No advance purchases in this period.')
                else
                  ...advances.map((r) {
                    final dt =
                        DateTime.tryParse((r['advance_date'] ?? '').toString());
                    final dateText = dt == null
                        ? '--'
                        : DateFormat('dd-MMM-yyyy').format(dt);
                    final qty = num(r['original_qty']);
                    final note = (r['note'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$dateText | Qty ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}${note.isEmpty ? '' : ' | $note'}',
                      ),
                    );
                  }),
                const Divider(height: 22),
                const Text('Consumed In Bills',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (consumptions.isEmpty)
                  const Text('No consumption in this period.')
                else
                  ...consumptions.map((r) {
                    final dt =
                        DateTime.tryParse((r['sale_day'] ?? '').toString());
                    final dateText = dt == null
                        ? '--'
                        : DateFormat('dd-MMM-yyyy').format(dt);
                    final saleNo = (r['sale_no'] ?? '').toString();
                    final qty = num(r['qty']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$dateText | $saleNo | Qty ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnrollItemSchemeDialog() async {
    final scheme = _selectedItemScheme;
    if (!_hasCustomerContext ||
        scheme == null ||
        scheme.schemeScope.toUpperCase() != 'ITEM') {
      return;
    }

    DateTime selectedDate = _saleDate;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Enroll Customer In Scheme'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select cycle start date (custom). Free qty applies on cycle end day only.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('dd-MMM-yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true) {
      await ctrl.createSchemeCustomer(
        schemeId: scheme.id,
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerGstin: _customerGstin.text.trim(),
        startDate: selectedDate,
        isActive: true,
      );
      await _refreshItemSchemeStatus();
    }
  }

  String _formatItemSchemeStatus() {
    final data = _itemSchemeProgress;
    if (data == null || data['enrolled'] != true) {
      return 'Not enrolled in this item scheme.';
    }
    final progress = Map<String, dynamic>.from(data['progress'] ?? const {});
    final advance = _itemAdvanceSummary ?? const {};

    final missingDays = (progress['missing_days'] as List? ?? const []).length;
    final remainingQty = (progress['remaining_qty'] ?? 0).toString();
    final cycleStart = (progress['cycle_start'] ?? '').toString();
    final cycleEnd = (progress['cycle_end'] ?? '').toString();
    final advanceLeft = (advance['remaining_qty'] ?? 0).toString();

    return 'Cycle $cycleStart to $cycleEnd | Left Qty: $remainingQty | Missing Days: $missingDays | Advance Left: $advanceLeft';
  }

  String _formatSelectedItemAdvanceStatus() {
    final item = _selectedManualItem;
    if (item == null) return '';
    final subscription = _customerSubscriptions.firstWhere(
      (row) => (int.tryParse(row['item_id']?.toString() ?? '') ?? 0) == item.id,
      orElse: () => const <String, dynamic>{},
    );
    final advance = _itemAdvanceSummaries[item.id];
    if (advance == null && subscription.isEmpty) {
      return 'No advance loaded for ${item.itemName}.';
    }

    final purchasedQty = _num(
      advance != null
          ? advance['original_qty']
          : subscription['today_remaining_qty'],
    );
    final currentConsumedQty = _currentAdvanceFreeQtyForItem(item.id);
    final consumedQty =
        _num(advance?['consumed_qty'] ?? 0) + currentConsumedQty;
    final remainingQty =
        (_availableAdvanceQtyForItem(item.id) - currentConsumedQty)
            .clamp(0, double.infinity);
    return 'Item ${item.itemName} | Purchased ${purchasedQty.toStringAsFixed(2)} | Consumed ${consumedQty.toStringAsFixed(2)} | Left ${remainingQty.toStringAsFixed(2)}';
  }

  Widget _entryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Scan or Search Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'SCAN',
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Scanning'),
                  ),
                  ButtonSegment(
                    value: 'MANUAL',
                    icon: Icon(Icons.search),
                    label: Text('Manual'),
                  ),
                ],
                selected: {_entryMode},
                onSelectionChanged: (value) {
                  setState(() => _entryMode = value.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcode,
                  focusNode: _barcodeFocusNode,
                  autofocus:
                      !context.watch<UiPreferencesController>().touchMode,
                  onChanged: (value) => _tryAutoAddScannedItem(value),
                  onSubmitted: (_) => _handleQuickEntry(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF6F8FC),
                    prefixIcon: Icon(
                      _entryMode == 'SCAN'
                          ? Icons.qr_code_scanner
                          : Icons.search,
                      size: 28,
                    ),
                    hintText: _entryMode == 'SCAN'
                        ? 'Scan QR / barcode or type item code'
                        : 'Search item by name, code or barcode',
                    helperText: _entryMode == 'SCAN'
                        ? 'Scanner users can scan and press Enter. Manual users can still type here.'
                        : 'Type item name or choose from the item selector below.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _entryQty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _handleQuickEntry(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    filled: true,
                    fillColor: const Color(0xFFF6F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _handleQuickEntry,
                icon: Icon(_entryMode == 'SCAN'
                    ? Icons.add_business_outlined
                    : Icons.add_shopping_cart),
                label: Text(_entryMode == 'SCAN' ? 'Scan Add' : 'Add Item'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownSearch<Item>(
                  selectedItem: _selectedManualItem,
                  items: (filter, _) async {
                    return _suggestedItems(filter);
                  },
                  itemAsString: (item) =>
                      '${item.itemCode} - ${item.itemName} (${item.taxType} ${item.taxPercent.toStringAsFixed(item.taxPercent % 1 == 0 ? 0 : 2)}%)',
                  compareFn: (first, second) => first.id == second.id,
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: 'Item Search',
                      hintText: 'Top 10 matching items',
                    ),
                  ),
                  onChanged: (item) {
                    setState(() => _selectedManualItem = item);
                    if (item != null) {
                      _ensureItemAdvanceSummary(item).then((_) {
                        if (mounted) {
                          setState(_rebuildItemAdvanceFreeLines);
                        }
                      });
                    } else {
                      _itemAdvanceSummaries.removeWhere((_, __) => true);
                      setState(_rebuildItemAdvanceFreeLines);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _handleQuickEntry,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add Selected'),
              ),
            ],
          ),
          if (_hasCustomerContext && _selectedManualItem != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loadingItemAdvanceStatus
                          ? 'Loading item advance status...'
                          : _itemAdvanceSummaries[_selectedManualItem!.id] ==
                                  null
                              ? 'No advance loaded for ${_selectedManualItem!.itemName}.'
                              : _formatSelectedItemAdvanceStatus(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Add Item Advance (Qty)',
                    onPressed: _hasCustomerContext
                        ? () => _showAddItemAdvanceDialogForItem(
                              _selectedManualItem!,
                            )
                        : null,
                    icon: const Icon(Icons.add_card_outlined),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard() {
    final computedItems = _invoice.items;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sale Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No items added yet. Scan or search above to start billing.',
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth < 1080
                          ? 1080.0
                          : constraints.maxWidth;
                      final tableHeight = constraints.hasBoundedHeight &&
                              constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : 260.0;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          height: tableHeight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _itemsHeaderRow(),
                              const Divider(height: 1),
                              Flexible(
                                fit: FlexFit.loose,
                                child: ListView.separated(
                                  itemCount: computedItems.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final line = computedItems[index];
                                    return _itemRow(line, index);
                                  },
                                ),
                              ),
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

  Future<void> _addCustomChargeDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0');
    final taxCtrl = TextEditingController(text: '0');
    bool taxable = false;
    String taxType = 'GST';
    String calculationType = 'AMOUNT';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Custom Charge'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Charge Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: calculationType,
                    items: const [
                      DropdownMenuItem(
                        value: 'AMOUNT',
                        child: Text('Fixed Amount'),
                      ),
                      DropdownMenuItem(
                        value: 'PERCENT',
                        child: Text('Percentage'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(
                        () => calculationType = value ?? 'AMOUNT',
                      );
                    },
                    decoration: const InputDecoration(labelText: 'Charge Type'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          calculationType == 'PERCENT' ? 'Percent' : 'Amount',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Taxable'),
                    value: taxable,
                    onChanged: (value) {
                      setDialogState(() => taxable = value);
                    },
                  ),
                  if (taxable) ...[
                    DropdownButtonFormField<String>(
                      initialValue: taxType,
                      items: const [
                        DropdownMenuItem(value: 'GST', child: Text('GST')),
                        DropdownMenuItem(value: 'VAT', child: Text('VAT')),
                        DropdownMenuItem(value: 'CESS', child: Text('CESS')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => taxType = value ?? 'GST');
                      },
                      decoration: const InputDecoration(labelText: 'Tax Type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: taxCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tax %'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  setState(() {
                    _charges = [
                      ..._charges,
                      BillingCharge(
                        name: name,
                        code: name.toUpperCase().replaceAll(' ', '_'),
                        amount: calculationType == 'PERCENT'
                            ? 0
                            : (double.tryParse(amountCtrl.text.trim()) ?? 0),
                        calculationType: calculationType,
                        calculationValue:
                            double.tryParse(amountCtrl.text.trim()) ?? 0,
                        taxable: taxable,
                        autoApply: true,
                        isEnabled: true,
                        taxType: taxType,
                        taxPercent: double.tryParse(taxCtrl.text.trim()) ?? 0,
                      ),
                    ];
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _chargeDescriptor(BillingCharge charge) {
    final base = charge.calculationType == 'PERCENT'
        ? '${charge.calculationValue.toStringAsFixed(charge.calculationValue % 1 == 0 ? 0 : 2)}%'
        : 'Rs. ${charge.amount.toStringAsFixed(2)}';
    if (!charge.taxable) return base;
    return '$base + ${charge.taxType} ${charge.taxPercent.toStringAsFixed(charge.taxPercent % 1 == 0 ? 0 : 2)}%';
  }

  Widget _chargesCard() {
    final invoice = _invoice;
    return _card(
      title: 'Charges',
      child: Column(
        children: [
          if (_charges.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'No default charges configured. Add a custom charge if needed.'),
            ),
          ...List.generate(_charges.length, (index) {
            final charge = _charges[index];
            final computed = invoice.charges.cast<ComputedCharge?>().firstWhere(
                  (entry) =>
                      entry?.charge.code == charge.code &&
                      entry?.charge.name == charge.name,
                  orElse: () => null,
                );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(charge.name),
                      subtitle: Text(_chargeDescriptor(charge)),
                      value: charge.isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _charges[index] = charge.copyWith(isEnabled: value);
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: charge.calculationValue.toStringAsFixed(
                        charge.calculationValue % 1 == 0 ? 0 : 2,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: charge.calculationType == 'PERCENT'
                            ? 'Percent'
                            : 'Amount',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _charges[index] = charge.copyWith(
                            amount: charge.calculationType == 'PERCENT'
                                ? charge.amount
                                : (double.tryParse(value.trim()) ?? 0),
                            calculationValue:
                                double.tryParse(value.trim()) ?? 0,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Tax ${computed?.taxAmount.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _charges.removeAt(index));
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addCustomChargeDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Charge'),
              ),
              const SizedBox(width: 14),
              Text(
                'Charge total ${invoice.chargeTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsCard() {
    final invoice = _invoice;
    return _card(
      title: 'Bill Summary',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric('Items', _items.length.toDouble(), decimals: 0),
              _metric('Total Qty', invoice.totalQty),
              _metric('Sub Total', invoice.subTotal),
              _metric('Scheme Savings', _totalSchemeSavingsAmount),
              _metric('Manual Discount', invoice.manualDiscountAmount),
              if (_loyaltyDiscountAmount > 0)
                _metric('Loyalty Discount', _loyaltyDiscountAmount),
              _metric('Charge Total', invoice.chargeTotal),
              _metric(
                'Total Savings',
                invoice.totalDiscount + _schemeFreeSavingsAmount,
              ),
              _metric('Taxable Amount', invoice.taxableAmount),
              _metric('Total Tax', invoice.totalTax),
              if (invoice.amountForCode('CGST') > 0)
                _metric('CGST', invoice.amountForCode('CGST')),
              if (invoice.amountForCode('SGST') > 0)
                _metric('SGST', invoice.amountForCode('SGST')),
              if (invoice.amountForCode('IGST') > 0)
                _metric('IGST', invoice.amountForCode('IGST')),
              _metric('Final Amount', _payableInvoiceTotal, highlight: true),
            ],
          ),
          const SizedBox(height: 14),
          if (invoice.taxSummary.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Tax Head',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Taxable',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Tax',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...invoice.taxSummary.map(
                    (tax) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(tax.label)),
                          Expanded(
                            flex: 2,
                            child: Text(tax.taxableAmount.toStringAsFixed(2)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(tax.taxAmount.toStringAsFixed(2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_editingSaleId != null) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Affect Stock'),
              subtitle: const Text(
                'Turn off to update bill amounts only without changing stock.',
              ),
              value: _affectStockOnEdit,
              onChanged: (value) {
                setState(() => _affectStockOnEdit = value);
              },
            ),
          ],
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _persistSale(
                  status: _editingSaleId != null ? 'COMPLETED' : 'DRAFT',
                  printAfterSave: false,
                ),
                icon: const Icon(Icons.save_as_outlined),
                label: Text(
                  _editingSaleId != null ? 'Update Bill' : 'Save Order',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () =>
                    _persistSale(status: 'COMPLETED', printAfterSave: false),
                icon: const Icon(Icons.save),
                label: Text(
                  _editingSaleId != null ? 'Update Bill' : 'Save Sale',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () =>
                    _persistSale(status: 'COMPLETED', printAfterSave: true),
                icon: const Icon(Icons.print_outlined),
                label: Text(
                  _editingSaleId != null
                      ? 'Update & Print'
                      : _isThermalBillFormat
                          ? 'Save & Print $_billFormatLabel'
                          : 'Save & Print A4 Bill',
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _showDraftsDialog,
                icon: const Icon(Icons.drafts_outlined),
                label: const Text('Delivery Order'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesReprintModifyScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Reprint / Modify Bill'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetSaleForm,
                icon: const Icon(Icons.restart_alt),
                label: const Text('New Bill'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _itemsHeaderRow() {
    const labelStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFFF7F8FC),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Code', style: labelStyle)),
          Expanded(flex: 4, child: Text('Item Name', style: labelStyle)),
          Expanded(flex: 2, child: Text('Barcode', style: labelStyle)),
          Expanded(flex: 3, child: Text('Quantity', style: labelStyle)),
          Expanded(flex: 2, child: Text('Rate', style: labelStyle)),
          Expanded(flex: 2, child: Text('Tax Type', style: labelStyle)),
          Expanded(flex: 2, child: Text('Tax %', style: labelStyle)),
          Expanded(flex: 2, child: Text('Tax', style: labelStyle)),
          Expanded(flex: 2, child: Text('Amount', style: labelStyle)),
          Expanded(flex: 2, child: Text('Action', style: labelStyle)),
        ],
      ),
    );
  }

  Widget _itemRow(SaleItem line, int index) {
    final isFree = line.isSchemeFree || line.isAdvanceFree;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              line.itemCode,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isFree ? Colors.green.shade800 : Colors.black87,
                    ),
                    children: [
                      TextSpan(text: line.itemName),
                      if (isFree)
                        const TextSpan(
                          text: ' (free)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(line.unit, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Expanded(
              flex: 2, child: Text(line.barcode.isEmpty ? '-' : line.barcode)),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Decrease quantity',
                  onPressed:
                      isFree ? null : () => _updateLineQty(index, line.qty - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                OutlinedButton(
                  onPressed: isFree ? null : () => _editQtyDialog(index),
                  child: Text(
                    line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase quantity',
                  onPressed:
                      isFree ? null : () => _updateLineQty(index, line.qty + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(line.rate.toStringAsFixed(2))),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: isFree ? null : () => _editTaxDialog(index),
              child: Row(
                children: [
                  Text(
                    line.taxType,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Colors.blue),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: isFree ? null : () => _editTaxDialog(index),
              child: Row(
                children: [
                  Text(
                    line.taxPercent.toStringAsFixed(line.taxPercent % 1 == 0 ? 0 : 2),
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 14, color: Colors.blue),
                ],
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(line.taxAmount.toStringAsFixed(2))),
          Expanded(
            flex: 2,
            child: Text(
              _displayLineTotal(line).toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit quantity',
                  onPressed: isFree ? null : () => _editQtyDialog(index),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: () {
                    _removeCartItemGroupById(line.itemId);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactField(
    TextEditingController controller,
    String label, {
    required double width,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _metric(String label, double value,
      {int decimals = 2, bool highlight = false}) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF17324D) : const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                TextStyle(color: highlight ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(decimals),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfoCard(String label, double value, {bool highlight = false}) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF17324D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white70 : const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs. ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: highlight ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentLine {
  final String method;
  final double amount;

  const _PaymentLine({required this.method, required this.amount});
}

class _EditablePaymentLine {
  String method;
  final TextEditingController amountCtrl;

  _EditablePaymentLine({required this.method, required this.amountCtrl});
}

class _PaymentSummary {
  final String primaryMode;
  final double collectedAmount;
  final double rawCollectedAmount;
  final double cashAmount;
  final double creditAmount;
  final double refundAmount;
  final double balanceDue;
  final bool hasInvalidRefund;
  final double previousAdjustmentAmount;
  final double advanceAppliedAmount;
  final double advanceCreatedAmount;
  final bool refundEnabled;

  const _PaymentSummary({
    required this.primaryMode,
    required this.collectedAmount,
    required this.rawCollectedAmount,
    required this.cashAmount,
    required this.creditAmount,
    required this.refundAmount,
    required this.balanceDue,
    required this.hasInvalidRefund,
    required this.previousAdjustmentAmount,
    required this.advanceAppliedAmount,
    required this.advanceCreatedAmount,
    required this.refundEnabled,
  });
}

class _NormalizedPaymentEntries {
  final List<_PaymentLine> entries;
  final _PaymentSummary summary;

  const _NormalizedPaymentEntries({
    required this.entries,
    required this.summary,
  });
}

class _VoucherDefinition {
  final String code;
  final String label;
  final String discountType;
  final double discountValue;
  final String validFrom;
  final String validTo;
  final double minimumPurchaseAmount;

  const _VoucherDefinition({
    required this.code,
    required this.label,
    required this.discountType,
    required this.discountValue,
    required this.validFrom,
    required this.validTo,
    required this.minimumPurchaseAmount,
  });

  factory _VoucherDefinition.fromJson(Map<String, dynamic> json) {
    return _VoucherDefinition(
      code: (json['code'] ?? '').toString().trim().toUpperCase(),
      label: (json['label'] ?? json['code'] ?? '').toString(),
      discountType: (json['discount_type'] ?? json['discountType'] ?? 'AMOUNT')
          .toString()
          .toUpperCase(),
      discountValue: double.tryParse(
            (json['discount_value'] ?? json['discountValue']).toString(),
          ) ??
          0,
      validFrom: (json['valid_from'] ?? json['validFrom'] ?? '').toString(),
      validTo: (json['valid_to'] ?? json['validTo'] ?? '').toString(),
      minimumPurchaseAmount: double.tryParse(
            (json['minimum_purchase_amount'] ?? json['minimumPurchaseAmount'])
                .toString(),
          ) ??
          0,
    );
  }
}

const Map<String, String> _stateCodes = {
  'andaman and nicobar islands': '35',
  'andhra pradesh': '37',
  'arunachal pradesh': '12',
  'assam': '18',
  'bihar': '10',
  'chandigarh': '04',
  'chhattisgarh': '22',
  'dadra and nagar haveli and daman and diu': '26',
  'delhi': '07',
  'goa': '30',
  'gujarat': '24',
  'haryana': '06',
  'himachal pradesh': '02',
  'jammu and kashmir': '01',
  'jharkhand': '20',
  'karnataka': '29',
  'kerala': '32',
  'ladakh': '38',
  'lakshadweep': '31',
  'madhya pradesh': '23',
  'maharashtra': '27',
  'manipur': '14',
  'meghalaya': '17',
  'mizoram': '15',
  'nagaland': '13',
  'odisha': '21',
  'puducherry': '34',
  'punjab': '03',
  'rajasthan': '08',
  'sikkim': '11',
  'tamil nadu': '33',
  'telangana': '36',
  'tripura': '16',
  'uttar pradesh': '09',
  'uttarakhand': '05',
  'west bengal': '19',
};

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
