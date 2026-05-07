import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

class ReceivingController extends ChangeNotifier {
  bool loading = false;

  Future<void> createReceiving({
    required String grnNo,
    required String manualNo,
    required int? poNo,
    required int supplierId,
    required DateTime receiptDate,
    required String supplierBillNo,
    required String? status,
    required List items,
  }) async {
    loading = true;
    notifyListeners();

    final body = {
      "grn_no": grnNo,
      "manual_no": manualNo,
      "po_no": poNo,
      "supplier_id": supplierId,
      "receipt_date": receiptDate.toIso8601String(),
      "supplier_bill_no": supplierBillNo,
      "status": status,
      "items": items,
    };

    final res = await ApiClient.post(
      "/api/receiving/",
      body,
    );

    loading = false;
    notifyListeners();

    if (!res['success']) {
      throw Exception(
        res['message'] ?? res['error'] ?? 'Failed to save receiving',
      );
    }
  }
}
