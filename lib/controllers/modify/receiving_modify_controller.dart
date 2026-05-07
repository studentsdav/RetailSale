import 'package:flutter/widgets.dart';

import '../../core/api/api_client.dart';

class ReceivingModifyController extends ChangeNotifier {
  List<dynamic> grns = [];
  Map<String, dynamic> grnDetails = {};
  List items = [];

  Future<void> loadGRNByDate(String date) async {
    final res = await ApiClient.get(
      "/api/receiving/by-date?date=$date",
    );

    grns = res['data'];

    notifyListeners();
  }

  Future<void> loadGRNDetails(int id) async {
    final res = await ApiClient.get(
      "/api/receiving/$id",
    );

    grnDetails = res['data'];
    items = res['data']['items'];

    notifyListeners();
  }

  Future<void> modifyGRN({
    required int id,
    required int supplierId,
    required List items,
  }) async {
    final body = {"supplier_id": supplierId, "items": items};

    final res = await ApiClient.put(
      "/api/receiving/$id",
      body,
    );

    if (!res['success']) {
      throw Exception(res['message']);
    }
  }
}
