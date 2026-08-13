import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/settings/master_model.dart';
import 'package:flutter/foundation.dart';

class MasterController {
  Future<List<GroupModel>> getGroups() async {
    try {
      final res = await ApiClient.get('/api/inventory/groups');
      if (res['data'] is List) {
        return (res['data'] as List).map((e) => GroupModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
    return [];
  }

  Future<void> createGroup(String name) async {
    await ApiClient.post('/api/inventory/groups', {"group_name": name});
  }

  Future<void> createSubCategory(int groupId, String name) async {
    await ApiClient.post('/api/inventory/subcategories', {
      "group_id": groupId,
      "subcategory_name": name,
    });
  }

  Future<void> createBrand(String name) async {
    await ApiClient.post('/api/inventory/brands', {"brand_name": name});
  }

  Future<List<LocationModel>> getLocations() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.stockLocations);
      if (res['data'] is List) {
        return (res['data'] as List).map((e) => LocationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
    }
    return [];
  }

  Future<void> createLocation(String name) async {
    String code = 'LOC_${name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_')}';
    try {
      final res = await ApiClient.get('/api/inventory/locations/next-code');
      if (res['data'] != null && res['data'].toString().trim().isNotEmpty) {
        code = res['data'].toString().trim();
      }
    } catch (_) {}

    await ApiClient.post(ApiEndpoints.stockLocations, {
      "location_code": code,
      "location_name": name.trim(),
      "description": name.trim(),
      "is_active": true,
    });
  }

  Future<void> deleteLocation(int id) async {
    await ApiClient.delete('${ApiEndpoints.stockLocations}/$id');
  }
}
