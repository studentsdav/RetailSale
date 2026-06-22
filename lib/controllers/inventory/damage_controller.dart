import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class DamageController extends ChangeNotifier {
  bool loading = false;

  Future<Map<String, dynamic>> getNextDamageNo() async {
    try {
      final now = DateTime.now();
      final res = await ApiClient.get(
        '/api/inventory/damage/next-no?date=${now.toIso8601String()}',
      );
      return res['data'];
    } catch (_) {
      showErrorSnackbar(
        'Damage numbering is not configured. Please set Damage No in Document Sequence Settings.',
      );
      return {'next_no': 0, 'damage_no': '0'};
    }
  }

  Future<double> getAvailableStock(String itemCode) async {
    final res = await ApiClient.get('/api/inventory/issue/stock/$itemCode');

    return double.parse(res['qty'].toString());
  }

  Future<void> createDamage(Map<String, dynamic> payload) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(ApiEndpoints.damage, payload);

    loading = false;
    notifyListeners();
  }

  Future<void> approveDamage(int damageId) async {
    loading = true;
    notifyListeners();

    await ApiClient.put('${ApiEndpoints.damage}/$damageId/approve', {});

    loading = false;
    notifyListeners();
  }

  Future<void> rejectDamage(int damageId, String rejectionReason) async {
    loading = true;
    notifyListeners();

    await ApiClient.put('${ApiEndpoints.damage}/$damageId/reject', {
      'rejection_reason': rejectionReason,
    });

    loading = false;
    notifyListeners();
  }
}
