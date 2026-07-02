import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/inventory/attribute_model.dart';

class AttributeController extends ChangeNotifier {
  bool loading = false;
  List<Attribute> attributes = [];

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get('/api/inventory/attributes');
      attributes = (res['data'] as List)
          .map((e) => Attribute.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error loading attributes: $e');
    }

    loading = false;
    notifyListeners();
  }

  Future<Attribute?> createAttribute(String name) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post('/api/inventory/attributes', {'name': name});
      final attr = Attribute.fromJson(res['data']);
      await load();
      return attr;
    } catch (e) {
      debugPrint('Error creating attribute: $e');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<AttributeValue?> createAttributeValue(int attributeId, String value) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        '/api/inventory/attributes/$attributeId/values',
        {'value': value},
      );
      final val = AttributeValue.fromJson(res['data']);
      await load();
      return val;
    } catch (e) {
      debugPrint('Error creating attribute value: $e');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
