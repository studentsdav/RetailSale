import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/inventory/product_template_model.dart';

class ProductTemplateController extends ChangeNotifier {
  bool loading = false;
  List<ProductTemplate> templates = [];

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get('/api/inventory/product-templates');
      templates = (res['data'] as List)
          .map((e) => ProductTemplate.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error loading product templates: $e');
    }

    loading = false;
    notifyListeners();
  }

  Future<ProductTemplate?> createTemplate({
    required String name,
    required String itemGroup,
    required String subCategory,
    required String brand,
    required String hsnSacCode,
    required String taxType,
    required double taxPercent,
    required bool discountApplicable,
    required bool schemeApplicable,
    required String unit,
    required List<Map<String, dynamic>> variants,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final payload = {
        'name': name,
        'item_group': itemGroup,
        'sub_category': subCategory,
        'brand': brand,
        'hsn_sac_code': hsnSacCode,
        'tax_type': taxType,
        'tax_percent': taxPercent,
        'discount_applicable': discountApplicable,
        'scheme_applicable': schemeApplicable,
        'unit': unit,
        'variants': variants,
      };

      final res = await ApiClient.post('/api/inventory/product-templates', payload);
      final template = ProductTemplate.fromJson(res['data']['template']);
      await load();
      return template;
    } catch (e) {
      debugPrint('Error creating product template: $e');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
