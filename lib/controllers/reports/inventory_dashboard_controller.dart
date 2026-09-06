import '../../core/api/api_client.dart';

class InventoryDashboardController {
  Future<Map<String, dynamic>> load({String? outletId}) async {
    final query = (outletId != null && outletId.isNotEmpty) ? '?outlet_id=$outletId' : '';
    final res = await ApiClient.get('/api/reports/inventory-dashboard$query');
    return res['data'];
  }
}

