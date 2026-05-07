import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/supplier_model.dart';

class SupplierController extends ChangeNotifier {
  bool loading = false;
  List<Supplier> list = [];

  Future<void> load({String q = ''}) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.suppliers}?q=$q',
    );

    list = (res['data'] as List).map((e) => Supplier.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  Future<void> create(Supplier payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(ApiEndpoints.suppliers, payload.toJson());
    await load();
  }

  Future<void> update(int id, Supplier payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.put(
      '${ApiEndpoints.suppliers}/$id',
      payload.toJson(),
    );

    await load();
  }

  Future<void> delete(int id) async {
    loading = true;
    notifyListeners();
    await ApiClient.delete('${ApiEndpoints.suppliers}/$id');
    await load();
  }

  Future<String> getNextCode() async {
    final res = await ApiClient.get('${ApiEndpoints.suppliers}/next-code');
    return res['data'];
  }
}
