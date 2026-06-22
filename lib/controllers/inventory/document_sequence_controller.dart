import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/document_sequence_model.dart';

class DocumentSequenceController extends ChangeNotifier {
  bool loading = false;
  List<DocumentSequence> list = [];

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(ApiEndpoints.documentSequence);

    list =
        (res['data'] as List).map((e) => DocumentSequence.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  Future<void> save(List<DocumentSequence> settings) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(
      ApiEndpoints.documentSequence,
      settings.map((e) => e.toJson()).toList(), // ✅ List is allowed now
    );

    loading = false;
    notifyListeners();
  }

  DocumentSequence? getByModule(String module) {
    try {
      final matches = getByModuleList(module);
      return matches.isEmpty ? null : matches.first;
    } catch (_) {
      return null;
    }
  }

  List<DocumentSequence> getByModuleList(String module) {
    final matches = list.where((e) => e.module == module).toList();
    matches.sort((a, b) => b.startDate.compareTo(a.startDate));
    return matches;
  }

  Future<String> getNextPoNo(DateTime date) async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.documentSequence}/next?module=PO&date=${date.toIso8601String()}',
      );
      return res['data']['number'];
    } catch (e) {
      showErrorSnackbar(
        'Document sequence is not configured for this date. Please add a start date on or before ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}.',
      );
      return "0";
    }
  }

  Future<String> getNextSalesNo(DateTime date) async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.documentSequence}/next?module=SALES&date=${date.toIso8601String()}',
      );
      return res['data']['number'];
    } catch (e) {
      showErrorSnackbar(
        'Document sequence is not configured for this date. Please add a start date on or before ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}.',
      );
      return "0";
    }
  }
}
