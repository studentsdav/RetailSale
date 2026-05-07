import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

class IssueModifyController extends ChangeNotifier {
  List issues = [];
  Map<String, dynamic> issueDetails = {};
  List items = [];

  Future<void> loadIssueByDate(String date) async {
    final res = await ApiClient.get(
      "/api/inventory/issue/by-date?date=$date",
    );

    issues = res['data'];

    notifyListeners();
  }

  Future<void> loadIssueDetails(int id) async {
    final res = await ApiClient.get(
      "/api/inventory/issue/$id",
    );

    issueDetails = res['data'];
    items = List.from(res['data']['items']);

    notifyListeners();
  }

  Future<void> modifyIssue({
    required int id,
    required String department,
    required List items,
  }) async {
    final body = {"department": department, "items": items};

    final res = await ApiClient.put(
      "/api/inventory/issue/$id",
      body,
    );

    if (!res['success']) {
      throw Exception(res['message']);
    }
  }
}
