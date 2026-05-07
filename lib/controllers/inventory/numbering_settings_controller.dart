import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/numbering_setting_model.dart';

class NumberingSettingsController extends ChangeNotifier {
  bool loading = false;
  List<NumberingSetting> list = [];

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(ApiEndpoints.numberingSettings);

    list =
        (res['data'] as List).map((e) => NumberingSetting.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  Future<void> save(List<NumberingSetting> settings) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(
      ApiEndpoints.numberingSettings,
      settings.map((e) => e.toJson()).toList(), // ✅ List is allowed now
    );

    loading = false;
    notifyListeners();
  }

  NumberingSetting? getByModule(String module) {
    try {
      final matches = getByModuleList(module);
      return matches.isEmpty ? null : matches.first;
    } catch (_) {
      return null;
    }
  }

  List<NumberingSetting> getByModuleList(String module) {
    final matches = list.where((e) => e.module == module).toList();
    matches.sort((a, b) => b.startDate.compareTo(a.startDate));
    return matches;
  }

  Future<String> getNextPoNo(DateTime date) async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.numberingSettings}/next?module=PO&date=${date.toIso8601String()}',
      );
      return res['data']['number'];
    } catch (e) {
      showErrorSnackbar(
        'Numbering is not configured for this date. Please add a start date on or before ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}.',
      );
      return "0";
    }
  }

  Future<String> getNextSalesNo(DateTime date) async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.numberingSettings}/next?module=SALES&date=${date.toIso8601String()}',
      );
      return res['data']['number'];
    } catch (e) {
      showErrorSnackbar(
        'Numbering is not configured for this date. Please add a start date on or before ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}.',
      );
      return "0";
    }
  }
}
