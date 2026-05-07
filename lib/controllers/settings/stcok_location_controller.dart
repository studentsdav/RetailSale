import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/stock_location_model.dart' show StockLocationdata;

class StockLocationController extends ChangeNotifier {
  bool loading = false;
  List<StockLocationdata> list = [];

  Future<void> load({String q = ''}) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.stockLocations}?q=$q',
    );

    list = (res['data'] as List)
        .map((e) => StockLocationdata.fromJson(e))
        .toList();

    loading = false;

    notifyListeners();
  }

  Future<void> create(StockLocationdata payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(
      ApiEndpoints.stockLocations,
      payload.toJson(),
    );

    await load();
  }

  Future<String> getNextCode() async {
    final res = await ApiClient.get('/api/inventory/locations/next-code');
    return res['data'];
  }

  Future<void> update(int id, StockLocationdata payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.put(
      '${ApiEndpoints.stockLocations}/$id',
      payload.toJson(),
    );

    await load();
  }

  Future<void> delete(int id) async {
    loading = true;
    notifyListeners();

    await ApiClient.delete(
      '${ApiEndpoints.stockLocations}/$id',
    );

    await load();
  }
}
