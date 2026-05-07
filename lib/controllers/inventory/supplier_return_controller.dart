import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../models/inventory/supplier_return_model.dart';

class SupplierReturnController extends ChangeNotifier {
  bool loading = false;

  List<Map<String, dynamic>> grns = [];
  List<SupplierReturnSourceItem> receivedItems = [];
  List<SupplierReturnRecord> returns = [];
  List<SupplierReturnRefund> refunds = [];

  Future<void> loadGrns(String date) async {
    loading = true;
    notifyListeners();

    final res =
        await ApiClient.get('/api/inventory/supplier-returns/grns?date=$date');
    grns = List<Map<String, dynamic>>.from(res['data'] ?? []);

    loading = false;
    notifyListeners();
  }

  Future<void> loadReceivedItems(int grnId) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
        '/api/inventory/supplier-returns/received-items/$grnId');
    receivedItems = (res['data'] as List)
        .map((e) => SupplierReturnSourceItem.fromJson(e))
        .toList();

    loading = false;
    notifyListeners();
  }

  Future<double> getReturnedQty(int receiptItemId) async {
    final res = await ApiClient.get(
      '/api/inventory/supplier-returns/returned-sum/$receiptItemId',
    );

    return double.tryParse(
          (res['data']?['returned_qty'] ?? 0).toString(),
        ) ??
        0;
  }

  Future<void> saveReturn({
    required int grnId,
    required int supplierId,
    required DateTime returnDate,
    required List<SupplierReturnEntryItem> items,
    String? notes,
  }) async {
    final res = await ApiClient.post(
      '/api/inventory/supplier-returns',
      {
        'grn_id': grnId,
        'supplier_id': supplierId,
        'return_date': DateFormat('yyyy-MM-dd').format(returnDate),
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );

    if (res['success'] != true) {
      throw Exception(
          res['message'] ?? res['error'] ?? 'Failed to save return');
    }
  }

  Future<void> loadReturns({
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
  }) async {
    loading = true;
    notifyListeners();

    final query = StringBuffer('/api/inventory/supplier-returns');
    final params = <String>[];
    if (fromDate != null) {
      params.add('from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}');
    }
    if (toDate != null) {
      params.add('to_date=${DateFormat('yyyy-MM-dd').format(toDate)}');
    }
    if (status != null && status.isNotEmpty) {
      params.add('status=$status');
    }
    if (params.isNotEmpty) {
      query.write('?${params.join('&')}');
    }

    final res = await ApiClient.get(query.toString());
    returns = (res['data'] as List)
        .map((e) => SupplierReturnRecord.fromJson(e))
        .toList();

    loading = false;
    notifyListeners();
  }

  Future<void> loadRefunds(int returnId) async {
    final res = await ApiClient.get(
        '/api/inventory/supplier-returns/$returnId/refunds');
    refunds = (res['data'] as List)
        .map((e) => SupplierReturnRefund.fromJson(e))
        .toList();
    notifyListeners();
  }

  Future<void> receiveRefund({
    required int returnId,
    required double amount,
    required DateTime refundDate,
    required String paymentMode,
    String? referenceNo,
    String? notes,
  }) async {
    final res = await ApiClient.post(
      '/api/inventory/supplier-returns/$returnId/refunds',
      {
        'amount': amount,
        'refund_date': DateFormat('yyyy-MM-dd').format(refundDate),
        'payment_mode': paymentMode,
        'reference_no': referenceNo,
        'notes': notes,
      },
    );

    if (res['success'] != true) {
      throw Exception(
        res['message'] ?? res['error'] ?? 'Failed to receive refund',
      );
    }
  }
}
