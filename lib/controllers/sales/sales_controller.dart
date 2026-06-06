import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/sale_customer_model.dart';
import '../../models/inventory/sale_order_model.dart';
import '../../models/inventory/sale_scheme_model.dart';

class SalesController extends ChangeNotifier {
  bool loading = false;
  List<Item> items = [];
  List<SaleScheme> schemes = [];
  List<SaleCustomer> customers = [];

  Future<void> loadInitialData() async {
    loading = true;
    notifyListeners();

    final itemRes = await ApiClient.get(ApiEndpoints.items);
    items = (itemRes['data'] as List).map((e) => Item.fromJson(e)).toList();

    final schemeRes = await ApiClient.get(ApiEndpoints.salesSchemes);
    schemes =
        (schemeRes['data'] as List).map((e) => SaleScheme.fromJson(e)).toList();
    final customerRes = await ApiClient.get(ApiEndpoints.salesCustomers);
    customers = (customerRes['data'] as List)
        .map((e) => SaleCustomer.fromJson(e))
        .toList();

    loading = false;
    notifyListeners();
  }

  Future<String> getNextSaleNo() async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.sales}/next-sale-no');
      return res['data']['number'];
    } catch (e) {
      throw Exception(
        'Sales numbering is not configured. Please set Sales Bill No in Numbering Settings.',
      );
    }
  }

  Future<void> refreshSchemes({
    String customerName = '',
    String customerPhone = '',
    String customerGstin = '',
  }) async {
    final query = [
      'customer_name=${Uri.encodeComponent(customerName.trim())}',
      'customer_phone=${Uri.encodeComponent(customerPhone.trim())}',
      'customer_gstin=${Uri.encodeComponent(customerGstin.trim())}',
    ].join('&');
    final schemeRes = await ApiClient.get('${ApiEndpoints.salesSchemes}?$query');
    schemes =
        (schemeRes['data'] as List).map((e) => SaleScheme.fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> refreshCustomers({String search = ''}) async {
    final query = search.trim().isEmpty
        ? ApiEndpoints.salesCustomers
        : '${ApiEndpoints.salesCustomers}?search=${Uri.encodeComponent(search.trim())}';
    final res = await ApiClient.get(query);
    customers =
        (res['data'] as List).map((e) => SaleCustomer.fromJson(e)).toList();
    notifyListeners();
  }

  Future<Map<String, dynamic>> createCustomer({
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String customerGstin,
  }) async {
    final res = await ApiClient.post(ApiEndpoints.salesCustomers, {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'customer_gstin': customerGstin,
    });
    await refreshCustomers();
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<List<SaleCustomer>> searchCustomers(String search) async {
    final query = search.trim().isEmpty
        ? ApiEndpoints.salesCustomers
        : '${ApiEndpoints.salesCustomers}?search=${Uri.encodeComponent(search.trim())}';
    final res = await ApiClient.get(query);
    customers =
        (res['data'] as List).map((e) => SaleCustomer.fromJson(e)).toList();
    notifyListeners();
    return customers;
  }

  Future<void> updateCustomer(
    int id, {
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String customerGstin,
  }) async {
    await ApiClient.put('${ApiEndpoints.salesCustomers}/$id', {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'customer_gstin': customerGstin,
    });
    await refreshCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    await ApiClient.delete('${ApiEndpoints.salesCustomers}/$id');
    await refreshCustomers();
  }

  Future<void> createScheme(SaleScheme scheme) async {
    await ApiClient.post(ApiEndpoints.salesSchemes, scheme.toJson());
    await refreshSchemes();
  }

  Future<void> updateScheme(int id, SaleScheme scheme) async {
    await ApiClient.put('${ApiEndpoints.salesSchemes}/$id', scheme.toJson());
    await refreshSchemes();
  }

  Future<void> deleteScheme(int id) async {
    await ApiClient.delete('${ApiEndpoints.salesSchemes}/$id');
    await refreshSchemes();
  }

  Future<List<Map<String, dynamic>>> listSubscriptions({
    String search = '',
    String status = '',
  }) async {
    final params = <String>[];
    if (search.trim().isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (status.trim().isNotEmpty) {
      params.add('status=${Uri.encodeComponent(status.trim())}');
    }
    final query = params.isEmpty
        ? ApiEndpoints.salesSubscriptions
        : '${ApiEndpoints.salesSubscriptions}?${params.join('&')}';
    final res = await ApiClient.get(query);
    return (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listCustomerSubscriptions({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    DateTime? date,
  }) async {
    final params = <String>[
      'customer_name=${Uri.encodeComponent(customerName)}',
      'customer_phone=${Uri.encodeComponent(customerPhone)}',
      'customer_gstin=${Uri.encodeComponent(customerGstin)}',
    ];
    if (date != null) {
      params.add('date=${Uri.encodeComponent(date.toIso8601String())}');
    }
    final res = await ApiClient.get(
      '${ApiEndpoints.salesSubscriptionCustomer}?${params.join('&')}',
    );
    return (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createSubscription(
    Map<String, dynamic> payload,
  ) async {
    final res = await ApiClient.post(ApiEndpoints.salesSubscriptions, payload);
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<void> deleteSubscription(int id) async {
    await ApiClient.delete('${ApiEndpoints.salesSubscriptions}/$id');
  }

  Future<void> cancelSubscription(int id) async {
    await ApiClient.put(
      '${ApiEndpoints.salesSubscriptions}/$id/status',
      {'status': 'CANCELLED'},
    );
  }

  Future<Map<String, dynamic>> getSubscriptionDetails(int id) async {
    final res = await ApiClient.get('${ApiEndpoints.salesSubscriptions}/$id');
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> getSubscriptionLedger(int id) async {
    final res = await ApiClient.get('${ApiEndpoints.salesSubscriptions}/$id/ledger');
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> generateFinalSettlement(
    int id, {
    DateTime? settlementDate,
    String? notes,
    String? paymentMode,
    double? amountPaid,
  }) async {
    final res = await ApiClient.post(
      '${ApiEndpoints.salesSubscriptions}/$id/final-settlement',
      {
        if (settlementDate != null)
          'settlement_date': settlementDate.toIso8601String(),
        if (notes != null) 'notes': notes,
        if (paymentMode != null) 'payment_mode': paymentMode,
        if (amountPaid != null) 'amount_paid': amountPaid,
      },
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> getSchemeProgress({
    required int schemeId,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required DateTime date,
  }) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.salesSchemes}/$schemeId/progress'
      '?customer_name=${Uri.encodeComponent(customerName)}'
      '&customer_phone=${Uri.encodeComponent(customerPhone)}'
      '&customer_gstin=${Uri.encodeComponent(customerGstin)}'
      '&date=${Uri.encodeComponent(date.toIso8601String())}',
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<List<Map<String, dynamic>>> listSchemeCustomers(int schemeId) async {
    final res = await ApiClient.get('${ApiEndpoints.salesSchemes}/$schemeId/customers');
    return (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createSchemeCustomer({
    required int schemeId,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required DateTime startDate,
    bool isActive = true,
  }) async {
    final res = await ApiClient.post(
      '${ApiEndpoints.salesSchemes}/$schemeId/customers',
      {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_gstin': customerGstin,
        'start_date': startDate.toIso8601String(),
        'is_active': isActive,
      },
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<void> updateSchemeCustomer({
    required int schemeId,
    required int customerId,
    DateTime? startDate,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (startDate != null) payload['start_date'] = startDate.toIso8601String();
    if (isActive != null) payload['is_active'] = isActive;
    await ApiClient.put('${ApiEndpoints.salesSchemes}/$schemeId/customers/$customerId', payload);
  }

  Future<Map<String, dynamic>> createItemAdvance({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required int itemId,
    required double qty,
    required DateTime advanceDate,
    double rate = 0,
    String? note,
    int? sourceSaleId,
  }) async {
    final res = await ApiClient.post(
      '${ApiEndpoints.sales}/item-advances',
      {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_gstin': customerGstin,
        'item_id': itemId,
        'original_qty': qty,
        'advance_date': advanceDate.toIso8601String(),
        'rate': rate,
        'note': note,
        'source_sale_id': sourceSaleId,
      },
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> updateItemAdvance({
    required int id,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required int itemId,
    required double qty,
    required DateTime advanceDate,
    required double rate,
    String? note,
  }) async {
    final res = await ApiClient.put(
      '${ApiEndpoints.sales}/item-advances/$id',
      {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_gstin': customerGstin,
        'item_id': itemId,
        'qty': qty,
        'advance_date': advanceDate.toIso8601String(),
        'rate': rate,
        'note': note,
      },
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<void> deleteItemAdvance(int id) async {
    await ApiClient.delete('${ApiEndpoints.sales}/item-advances/$id');
  }

  Future<Map<String, dynamic>> getItemAdvanceSummary({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required int itemId,
    DateTime? asOfDate,
  }) async {
    final dateQuery = asOfDate == null
        ? ''
        : '&date=${Uri.encodeComponent(asOfDate.toIso8601String())}';
    final res = await ApiClient.get(
      '${ApiEndpoints.sales}/item-advances/summary'
      '?customer_name=${Uri.encodeComponent(customerName)}'
      '&customer_phone=${Uri.encodeComponent(customerPhone)}'
      '&customer_gstin=${Uri.encodeComponent(customerGstin)}'
      '&item_id=$itemId'
      '$dateQuery',
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> getItemAdvanceLedger({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required int itemId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.sales}/item-advances/ledger'
      '?customer_name=${Uri.encodeComponent(customerName)}'
      '&customer_phone=${Uri.encodeComponent(customerPhone)}'
      '&customer_gstin=${Uri.encodeComponent(customerGstin)}'
      '&item_id=$itemId'
      '&from_date=${Uri.encodeComponent(fromDate.toIso8601String())}'
      '&to_date=${Uri.encodeComponent(toDate.toIso8601String())}',
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<List<Map<String, dynamic>>> listItemAdvances({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    int? itemId,
  }) async {
    final params = <String>[
      'customer_name=${Uri.encodeComponent(customerName)}',
      'customer_phone=${Uri.encodeComponent(customerPhone)}',
      'customer_gstin=${Uri.encodeComponent(customerGstin)}',
    ];
    if (itemId != null && itemId > 0) {
      params.add('item_id=$itemId');
    }
    final res = await ApiClient.get(
      '${ApiEndpoints.sales}/item-advances?${params.join('&')}',
    );
    return (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createSale(SaleOrder payload) async {
    final res = await ApiClient.post(ApiEndpoints.sales, payload.toJson());
    return Map<String, dynamic>.from(res);
  }



  Future<Map<String, dynamic>> modifySale(
    int id,
    SaleOrder payload, {
    required String modificationNote,
  }) async {
    final res = await ApiClient.put('${ApiEndpoints.sales}/$id', payload.toJson());
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> updateSalePaymentMode({
    required int saleId,
    required String paymentMode,
    List<Map<String, dynamic>> paymentLines = const [],
  }) async {
    final payload = <String, dynamic>{'payment_mode': paymentMode};
    if (paymentLines.isNotEmpty) {
      payload['payment_lines'] = paymentLines;
    }
    final res = await ApiClient.put(
      '${ApiEndpoints.sales}/$saleId/payment-mode',
      payload,
    );
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> listVouchers() async {
    final res = await ApiClient.get(ApiEndpoints.salesVouchers);
    return (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createVoucher(
      Map<String, dynamic> payload) async {
    final res = await ApiClient.post(ApiEndpoints.salesVouchers, payload);
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> updateVoucher(
    String code,
    Map<String, dynamic> payload,
  ) async {
    final res =
        await ApiClient.put('${ApiEndpoints.salesVouchers}/$code', payload);
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<void> deleteVoucher(String code) async {
    await ApiClient.delete('${ApiEndpoints.salesVouchers}/$code');
  }

  Future<Map<String, dynamic>> validateVoucher(
      Map<String, dynamic> payload) async {
    final res =
        await ApiClient.post(ApiEndpoints.salesValidateVoucher, payload);
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> getLoyaltyConfig() async {
    final res = await ApiClient.get(ApiEndpoints.salesLoyaltyConfig);
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> saveLoyaltyConfig(
    Map<String, dynamic> payload,
  ) async {
    final res = await ApiClient.post(ApiEndpoints.salesLoyaltyConfig, payload);
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> getCustomerLoyaltySummary({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
  }) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.salesLoyaltyCustomerSummary}'
      '?customer_name=${Uri.encodeComponent(customerName)}'
      '&customer_phone=${Uri.encodeComponent(customerPhone)}'
      '&customer_gstin=${Uri.encodeComponent(customerGstin)}',
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<List<Map<String, dynamic>>> listSales({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool latestOnly = true,
  }) async {
    final params = <String>[];
    if (status != null && status.trim().isNotEmpty) {
      params.add('status=${Uri.encodeComponent(status.trim())}');
    }
    if (fromDate != null) {
      params.add(
        'from_date=${Uri.encodeComponent(fromDate.toIso8601String())}',
      );
    }
    if (toDate != null) {
      params.add(
        'to_date=${Uri.encodeComponent(toDate.toIso8601String())}',
      );
    }
    if (search != null && search.trim().isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (!latestOnly) {
      params.add('latest_only=false');
    }
    final query = params.isEmpty
        ? ApiEndpoints.sales
   : '${ApiEndpoints.sales}?${params.join('&')}';
    final res = await ApiClient.get(query);
    return (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getSaleDetails(int id) async {
    final res = await ApiClient.get('${ApiEndpoints.sales}/$id');
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<void> deleteDraft(int id) async {
    await ApiClient.delete('${ApiEndpoints.sales}/drafts/$id');
  }

  Future<Map<String, dynamic>> getCustomerCreditSummary(String search) async {
    final query = search.trim();
    if (query.isEmpty) {
      return {
        'total_outstanding': 0.0,
        'total_advance': 0.0,
        'bills': <Map<String, dynamic>>[],
        'advances': <Map<String, dynamic>>[],
      };
    }
    final res = await ApiClient.get(
      '${ApiEndpoints.financeCreditReport}?customer=${Uri.encodeComponent(query)}',
    );
    final customers = (res['data'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (customers.isEmpty) {
      return {
        'total_outstanding': 0.0,
        'total_advance': 0.0,
        'bills': <Map<String, dynamic>>[],
        'advances': <Map<String, dynamic>>[],
      };
    }
    final customer = customers.first;
    return {
      'total_outstanding':
          double.tryParse((customer['total_outstanding'] ?? 0).toString()) ?? 0,
      'total_advance':
          double.tryParse((customer['total_advance'] ?? 0).toString()) ?? 0,
      'bills': (customer['bills'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      'advances': (customer['advances'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    };
  }

  Future<void> createCustomerAdvance({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required double amount,
    required DateTime advanceDate,
    required String paymentMode,
    required String referenceNo,
    required String note,
    int? sourceSaleId,
  }) async {
    await ApiClient.post(ApiEndpoints.financeAdvances, {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_gstin': customerGstin,
      'amount': amount,
      'advance_date': advanceDate.toIso8601String(),
      'payment_mode': paymentMode,
      'reference_no': referenceNo,
      'note': note,
      'source_sale_id': sourceSaleId,
    });
  }

  Future<void> applyCustomerAdvance({
    required int saleId,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required double amount,
    required DateTime paymentDate,
    required String paymentMode,
    required String referenceNo,
    required String note,
  }) async {
    await ApiClient.post(ApiEndpoints.financeApplyAdvance, {
      'sale_id': saleId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_gstin': customerGstin,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_mode': paymentMode,
      'reference_no': referenceNo,
      'note': note,
    });
  }

  Future<void> settlePreviousCredit({
    required List<Map<String, dynamic>> bills,
    required double amount,
    required DateTime paymentDate,
    required String paymentMode,
    String referenceNo = '',
    String note = '',
  }) async {
    var remaining = amount;
    for (final bill in bills) {
      if (remaining <= 0) break;
      final outstanding =
          double.tryParse((bill['outstanding'] ?? 0).toString()) ?? 0;
      final saleId = int.tryParse((bill['sale_id'] ?? 0).toString()) ?? 0;
      if (saleId <= 0 || outstanding <= 0) continue;
      final payAmount = remaining > outstanding ? outstanding : remaining;
      await ApiClient.post(ApiEndpoints.financeRepayments, {
        'sale_id': saleId,
        'payment_date': paymentDate.toIso8601String(),
        'amount': payAmount,
        'payment_mode': paymentMode,
        'reference_no': referenceNo,
        'note': note,
      });
      remaining -= payAmount;
    }
  }
}
