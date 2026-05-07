import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/item_model.dart';

class ItemController extends ChangeNotifier {
  bool loading = false;
  List<Item> list = [];

  Future<void> load({String q = ''}) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.items}?q=$q',
    );

    list = (res['data'] as List).map((e) => Item.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  Future<String> getNextCode() async {
    final res = await ApiClient.get('/api/inventory/items/next-code');
    return res['data'];
  }

  Future<Item> create(Item payload) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.post(ApiEndpoints.items, payload.toJson());
    await load();
    return Item.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<Item> update(int id, Item payload) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.put(
      '${ApiEndpoints.items}/$id',
      payload.toJson(),
    );

    await load();
    return Item.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<void> delete(int id) async {
    loading = true;
    notifyListeners();

    await ApiClient.delete('${ApiEndpoints.items}/$id');
    await load();
  }

  Future<List<Item>> generateBarcodes({
    List<int> itemIds = const [],
    bool forceRegenerate = false,
  }) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.post('${ApiEndpoints.items}/generate-barcodes', {
      'item_ids': itemIds,
      'force_regenerate': forceRegenerate,
    });
    list = (res['data'] as List).map((e) => Item.fromJson(e)).toList();

    loading = false;
    notifyListeners();
    return list;
  }
}
