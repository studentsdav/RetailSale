import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/settings/system_settings_model.dart';

class SystemSettingsController extends ChangeNotifier {
  bool loading = false;
  SystemSettings? settings;

  /// LOAD SETTINGS
  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(ApiEndpoints.settings);
    settings = SystemSettings.fromJson(res['data']);

    loading = false;
    notifyListeners();
  }

  /// SAVE SETTINGS
  Future<void> save(SystemSettings payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(
      ApiEndpoints.settings,
      payload.toJson(),
    );

    settings = payload;
    loading = false;
    notifyListeners();
  }
}
