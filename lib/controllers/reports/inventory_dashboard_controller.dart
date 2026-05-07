import '../../core/api/api_client.dart';

class InventoryDashboardController {
  Future<Map<String, dynamic>> load() async {
    final res = await ApiClient.get('/api/reports/inventory-dashboard');
    return res['data'];
  }
}
