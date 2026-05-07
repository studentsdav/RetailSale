import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/common/property_info_model.dart';

class PropertyInfoController extends ChangeNotifier {
  bool loading = false;
  PropertyInfo? data;

  Future<void> load() async {
    try {
      loading = true;
      notifyListeners();

      final res = await ApiClient.get(ApiEndpoints.propertyInfo);
      data = PropertyInfo.fromJson(res['data']);

      loading = false;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> save(PropertyInfo payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(
      ApiEndpoints.propertyInfo,
      payload.toJson(),
    );

    loading = false;
    notifyListeners();
  }
}
