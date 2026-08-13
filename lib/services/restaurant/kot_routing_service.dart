import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class KotRoutingService {
  /// Splits KOT items by station location (e.g., Kitchen vs Bar)
  /// and sends separate KOT tickets to their respective station printers.
  static Future<Map<String, dynamic>> routeAndSendKot({
    required Map<String, dynamic> mainKotPayload,
    required List<dynamic> items,
    required List<dynamic> kitchenStations,
  }) async {
    final Map<String, List<dynamic>> locationGroups = {};

    for (final item in items) {
      final String loc = (item['location'] ?? item['station_name'] ?? item['kitchen_location'] ?? 'Kitchen')
          .toString()
          .trim();
      final String key = loc.isEmpty ? 'Kitchen' : loc;
      locationGroups.putIfAbsent(key, () => []).add(item);
    }

    // If only 1 station location or empty, send as single unified KOT
    if (locationGroups.keys.length <= 1) {
      try {
        final res = await ApiClient.post(ApiEndpoints.restaurantKots, mainKotPayload);
        return res;
      } catch (e) {
        debugPrint('Error sending unified KOT: $e');
        return {'success': false, 'error': e.toString()};
      }
    }

    // Multiple station locations detected -> Split into station-specific KOT tickets
    final List<Map<String, dynamic>> createdKots = [];
    bool overallSuccess = true;

    for (final locationName in locationGroups.keys) {
      final List<dynamic> stationItems = locationGroups[locationName]!;
      
      // Find mapped station printer
      final stationMatch = kitchenStations.firstWhere(
        (s) => (s['station_name'] ?? '').toString().toLowerCase() == locationName.toLowerCase(),
        orElse: () => null,
      );

      final Map<String, dynamic> splitPayload = Map<String, dynamic>.from(mainKotPayload);
      splitPayload['items'] = stationItems;
      splitPayload['target_location'] = locationName;
      if (stationMatch != null && stationMatch['printer_id'] != null) {
        splitPayload['printer_id'] = stationMatch['printer_id'];
      }

      try {
        final res = await ApiClient.post(ApiEndpoints.restaurantKots, splitPayload);
        if (res['success'] == true) {
          createdKots.add(res['data'] ?? {});
        } else {
          overallSuccess = false;
        }
      } catch (e) {
        overallSuccess = false;
        debugPrint('Error routing KOT for station "$locationName": $e');
      }
    }

    return {
      'success': overallSuccess,
      'split_routed': true,
      'total_stations': locationGroups.keys.length,
      'created_kots': createdKots,
    };
  }
}
