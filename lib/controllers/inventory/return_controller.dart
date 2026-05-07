import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/issued_item_model.dart';
import '../../models/inventory/return_item_model.dart';

class ReturnController extends ChangeNotifier {
  bool loading = false;

  List<Map<String, dynamic>> indents = [];
  List<IssuedItem> issuedItems = [];
  List<ReturnItem> returnItems = [];

  // ---------------- INDENTS ----------------
  Future<void> loadIndents(String date) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.returns}/indents?date=$date',
    );

    indents = List<Map<String, dynamic>>.from(res['data']);

    loading = false;
    notifyListeners();
  }

  // ---------------- ISSUED ITEMS ----------------
  Future<void> loadIssuedItems(int issueId) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.returns}/issued-items/$issueId',
    );

    issuedItems =
        (res['data'] as List).map((e) => IssuedItem.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  // ---------------- SAVE RETURN ----------------
  Future<void> saveReturn(
      {required int issueId,
      required String returnDate,
      required items}) async {
    await ApiClient.post(
      ApiEndpoints.returns,
      {
        'issue_id': issueId,
        'return_date': returnDate,
        'items': items,
      },
    );
  }

  // ---------------- UPDATE / DELETE ----------------
  Future<void> updateReturnItem(int id, Map payload) async {
    await ApiClient.put(
      '${ApiEndpoints.returns}/item/$id',
      payload,
    );
  }

  Future<void> deleteReturnItem(int id) async {
    await ApiClient.delete(
      '${ApiEndpoints.returns}/item/$id',
    );
  }

  Future<void> cancelReturn(int id) async {
    await ApiClient.put(
      '${ApiEndpoints.returns}/$id/cancel',
      {},
    );
  }

  Future<double> getReturnedQty(int issueItemId) async {
    final res =
        await ApiClient.get('/api/inventory/returns/returned-sum/$issueItemId');

    final value = res['data']?['returned_qty'];

    if (value == null) return 0.0;

    return (value as num).toDouble();
  }
}
