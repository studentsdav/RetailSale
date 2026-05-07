import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/stock_location_model.dart'
    show StockLocationdata;

class RequestModifyController extends ChangeNotifier {
  List requests = [];
  Map requestDetails = {};
  List items = [];
  List<StockLocationdata> departments = [];

  Future<void> loadRequestsByDate(String date) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.requests}/by-date?date=$date',
    );

    requests = res['data'];
  }

  Future<void> loadRequestDetails(int id) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.requests}/$id',
    );

    requestDetails = res['data'];
    items = requestDetails['items'];
  }

  Future<void> getdepartment() async {
    final deptRes = await ApiClient.get('/api/inventory/issue/departments');
    departments = (deptRes['data'] as List)
        .map((e) => StockLocationdata.fromJson(e))
        .toList();
    notifyListeners();
  }

  Future<void> modifyRequest({
    required int requestId,
    required String department,
    required List items,
  }) async {
    await ApiClient.put(
      '${ApiEndpoints.requests}/$requestId/modify',
      {
        "department": department,
        "items": items,
      },
    );
  }

  Future<void> cancelRequest(int requestId) async {
    await ApiClient.put('${ApiEndpoints.requests}/$requestId/cancel', {});
  }
}
