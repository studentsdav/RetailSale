import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../models/inventory/bom_model.dart';

class BOMController extends ChangeNotifier {
  bool loading = false;
  BOMDefinition? activeBOM;
  List<AssemblyHeader> assemblyList = [];

  Future<BOMDefinition?> getBOM(int parentItemId) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get('/api/inventory/boms/$parentItemId');
      if (res['success'] == true && res['data'] != null) {
        activeBOM = BOMDefinition.fromJson(res['data']);
      } else {
        activeBOM = BOMDefinition(parentItemId: parentItemId, components: [], compositeCost: 0.0);
      }
    } catch (e) {
      activeBOM = BOMDefinition(parentItemId: parentItemId, components: [], compositeCost: 0.0);
    }

    loading = false;
    notifyListeners();
    return activeBOM;
  }

  Future<bool> saveBOM(int parentItemId, List<Map<String, dynamic>> components) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post('/api/inventory/boms', {
        'parent_item_id': parentItemId,
        'components': components,
      });
      loading = false;
      notifyListeners();
      return res['success'] == true;
    } catch (e) {
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<double?> updateParentCost(int parentItemId) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post('/api/inventory/boms/$parentItemId/update-cost', {});
      loading = false;
      notifyListeners();
      if (res['success'] == true && res['data'] != null) {
        return double.tryParse(res['data']['rate']?.toString() ?? '0.0');
      }
      return null;
    } catch (e) {
      loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<String> getNextAssemblyNo() async {
    try {
      final res = await ApiClient.get('/api/inventory/assemblies/next-no');
      return res['data'] ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<bool> createAssembly({
    required int parentItemId,
    required double qty,
    required String notes,
    required String assemblyDate,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post('/api/inventory/assemblies', {
        'parent_item_id': parentItemId,
        'qty': qty,
        'notes': notes,
        'assembly_date': assemblyDate,
      });
      loading = false;
      notifyListeners();
      return res['success'] == true;
    } catch (e) {
      loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadAssemblies() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get('/api/inventory/assemblies');
      if (res['success'] == true && res['data'] != null) {
        assemblyList = (res['data'] as List).map((e) => AssemblyHeader.fromJson(e)).toList();
      }
    } catch (e) {
      assemblyList = [];
    }

    loading = false;
    notifyListeners();
  }

  Future<AssemblyHeader?> getAssemblyDetails(int id) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get('/api/inventory/assemblies/$id');
      loading = false;
      notifyListeners();
      if (res['success'] == true && res['data'] != null) {
        return AssemblyHeader.fromJson(res['data']);
      }
      return null;
    } catch (e) {
      loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> stopAssembly(int id) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.put('/api/inventory/assemblies/$id/stop', {});
      loading = false;
      notifyListeners();
      return res['success'] == true;
    } catch (e) {
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
