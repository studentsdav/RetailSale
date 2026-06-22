import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/stock_location_model.dart';

class RequestController extends ChangeNotifier {
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

  Future<String> getNextRequestNo() async {
    try {
      final now = DateTime.now();
      final res = await ApiClient.get(
        '/api/inventory/requests/next-no?date=${now.toIso8601String()}',
      );
      return res['data'];
    } catch (_) {
      showErrorSnackbar(
        'Request numbering is not configured. Please set Request No in Document Sequence Settings.',
      );
      return '0';
    }
  }

  Future<double> getAvailableStock(String itemCode) async {
    final res = await ApiClient.get('/api/inventory/issue/stock/$itemCode');

    return double.parse(res['qty'].toString());
  }

  Future<void> createRequest(Map<String, dynamic> payload) async {
    await ApiClient.post('/api/inventory/requests', payload);
  }

  Future<List<dynamic>> list() async {
    final res = await ApiClient.get('/api/inventory/requests');
    return res['data'];
  }

  Future<dynamic> getById(int id) async {
    final res = await ApiClient.get('/api/inventory/requests/$id');
    return res['data'];
  }

  Future<void> approve(int id) async {
    await ApiClient.put('/api/inventory/requests/$id/approve', {});
  }

  Future<void> reject(int id, String reason) async {
    await ApiClient.put('/api/inventory/requests/$id/reject', {
      'rejection_reason': reason,
    });
  }

  Future<void> cancel(int id) async {
    await ApiClient.put('/api/inventory/requests/$id/cancel', {});
  }
}
