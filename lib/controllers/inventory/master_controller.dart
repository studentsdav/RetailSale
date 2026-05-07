import '../../core/api/api_client.dart';

class MasterController {
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
}
