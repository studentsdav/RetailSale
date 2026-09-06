import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class StockTransferController {

  Future<Map<String, dynamic>?> fetchHierarchy() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.stockTransferHierarchy);
      if (res != null && res['success'] == true) {
        return res['data'];
      }
    } catch (e) {
      debugPrint('Error fetching outlet hierarchy: $e');
    }
    return null;
  }

  Future<bool> setOutletRole({
    required int outletId,
    required bool isMaster,
    int? parentOutletId,
    String? outletRole,
  }) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/hierarchy/role', {
        'outlet_id': outletId,
        'is_master': isMaster,
        'parent_outlet_id': parentOutletId,
        'outlet_role': outletRole ?? (isMaster ? 'MASTER' : 'BRANCH'),
      });
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('Error updating outlet role: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> linkOutletByPin({
    required String targetOutletCode,
    required String pin,
    int? masterOutletId,
  }) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/hierarchy/link-by-pin', {
        'target_outlet_code': targetOutletCode,
        'pin': pin,
        if (masterOutletId != null) 'master_outlet_id': masterOutletId,
      });
      return res ?? {'success': false, 'message': 'Failed to connect to server'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> requestLinkOtp({
    required String targetOutletCode,
  }) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/hierarchy/request-otp', {
        'target_outlet_code': targetOutletCode,
      });
      return res ?? {'success': false, 'message': 'Failed to request OTP'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyLinkOtp({
    required String targetOutletCode,
    required String otp,
    int? masterOutletId,
  }) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/hierarchy/verify-otp', {
        'target_outlet_code': targetOutletCode,
        'otp': otp,
        if (masterOutletId != null) 'master_outlet_id': masterOutletId,
      });
      return res ?? {'success': false, 'message': 'Failed to verify OTP'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unlinkOutlet({int? targetOutletId}) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/hierarchy/unlink', {
        if (targetOutletId != null) 'target_outlet_id': targetOutletId,
      });
      return res ?? {'success': false, 'message': 'Failed to unlink outlet'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> dispatchStock({
    required int destinationOutletId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.stockTransferDispatch, {
        'destination_outlet_id': destinationOutletId,
        'items': items,
        'notes': notes ?? '',
      });
      if (res != null && res['success'] == true) {
        return res;
      } else {
        return {'success': false, 'message': res?['message'] ?? 'Dispatch failed'};
      }
    } catch (e) {
      debugPrint('Error dispatching stock: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> receiveStock(int transferId) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/$transferId/receive', {});
      if (res != null && res['success'] == true) {
        return res;
      } else {
        return {'success': false, 'message': res?['message'] ?? 'Receive failed'};
      }
    } catch (e) {
      debugPrint('Error receiving stock: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> fetchOverallProgress() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.stockTransferOverallProgress);
      if (res != null && res['success'] == true) {
        return res['data'];
      }
    } catch (e) {
      debugPrint('Error fetching overall progress: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchIndividualOutletProgress(int outletId) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.stockTransferOutletProgress}/$outletId');
      if (res != null && res['success'] == true) {
        return res['data'];
      }
    } catch (e) {
      debugPrint('Error fetching individual outlet progress: $e');
    }
    return null;
  }

  Future<List<dynamic>> fetchTransfers({int? outletId, String? status}) async {
    try {
      String query = '';
      if (outletId != null || status != null) {
        final params = <String>[];
        if (outletId != null) params.add('outlet_id=$outletId');
        if (status != null) params.add('status=$status');
        query = '?${params.join('&')}';
      }

      final res = await ApiClient.get('/api/inventory/stock-transfers$query');
      if (res != null && res['success'] == true && res['data'] is List) {
        return res['data'];
      }
    } catch (e) {
      debugPrint('Error fetching transfers: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchTransferDetails(int transferId) async {
    try {
      final res = await ApiClient.get('/api/inventory/stock-transfers/$transferId');
      if (res != null && res['success'] == true) {
        return res['data'];
      }
    } catch (e) {
      debugPrint('Error fetching transfer details: $e');
    }
    return null;
  }

  Future<bool> toggleContactSharing(bool share) async {
    try {
      final res = await ApiClient.post('/api/inventory/stock-transfers/toggle-contact-sharing', {
        'share_contact_info': share,
      });
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('Error toggling contact sharing: $e');
      return false;
    }
  }
}
