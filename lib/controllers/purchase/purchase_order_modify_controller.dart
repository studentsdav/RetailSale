import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class PurchaseOrderModifyController extends ChangeNotifier {
  bool loading = false;

  List<Map<String, dynamic>> purchaseOrders = [];

  List items = [];

  Map poDetails = {};

  // ---------------- PO LIST ----------------

  Future<void> loadPOByDate(String date) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
        '${ApiEndpoints.purchaseOrders}/by-date?date=$date');

    purchaseOrders = List<Map<String, dynamic>>.from(res['data']);

    loading = false;
    notifyListeners();
  }

  // ---------------- PO DETAILS ----------------

  Future<void> loadPODetails(int id) async {
    loading = true;
    notifyListeners();

    final res =
        await ApiClient.get('${ApiEndpoints.purchaseOrders}/$id/details');

    poDetails = res['data'];

    items = List.from(poDetails['items']);

    loading = false;
    notifyListeners();
  }

  // ---------------- SAVE MODIFY ----------------

  Future<void> modifyPO(
      {required int poId, required int supplierId, required List items}) async {
    await ApiClient.put('${ApiEndpoints.purchaseOrders}/$poId/modify',
        {"supplier_id": supplierId, "items": items});
  }

  Future<void> cancelPO(int poId) async {
    await ApiClient.post('${ApiEndpoints.purchaseOrders}/$poId/cancel', {});
  }
}
