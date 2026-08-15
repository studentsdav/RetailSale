import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class KotRoutingService {
  /// Always saves ONE single unified KOT in the database.
  /// Runtime station printer routing is performed at print-time.
  static Future<Map<String, dynamic>> routeAndSendKot({
    required Map<String, dynamic> mainKotPayload,
    required List<dynamic> items,
    required List<dynamic> kitchenStations,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.restaurantKots, mainKotPayload);
      return res;
    } catch (e) {
      debugPrint('Error sending KOT: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
