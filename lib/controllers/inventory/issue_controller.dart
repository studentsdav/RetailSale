import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/stock_location_model.dart';

class IssueController extends ChangeNotifier {
  bool loading = false;

  List<Item> items = [];
  List<StockLocationdata> departments = [];

  Future<void> loadInitialData() async {
    loading = true;
    notifyListeners();

    final itemRes = await ApiClient.get('/api/inventory/items');
    items = (itemRes['data'] as List).map((e) => Item.fromJson(e)).toList();

    final deptRes = await ApiClient.get('/api/inventory/issue/departments');
    departments = (deptRes['data'] as List)
        .map((e) => StockLocationdata.fromJson(e))
        .toList();

    loading = false;
    notifyListeners();
  }

  Future<void> getdepartment() async {
    final deptRes = await ApiClient.get('/api/inventory/issue/departments');
    departments = (deptRes['data'] as List)
        .map((e) => StockLocationdata.fromJson(e))
        .toList();
    notifyListeners();
  }

  Future<double> getAvailableStock(String itemCode) async {
    final res = await ApiClient.get('/api/inventory/issue/stock/$itemCode');

    return double.parse(res['qty'].toString());
  }

  Future<void> createIssue(Map<String, dynamic> payload) async {
    await ApiClient.post('/api/inventory/issue', payload);
  }
}
