import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class FinancialReportsController extends ChangeNotifier {
  bool loading = false;

  Map<String, dynamic> trialBalanceData = {};
  Map<String, dynamic> profitLossData = {};
  Map<String, dynamic> balanceSheetData = {};
  Map<String, dynamic> brsData = {};

  Future<void> fetchTrialBalance({String? outletId}) async {
    loading = true;
    notifyListeners();
    try {
      String url = ApiEndpoints.accountingTrialBalance;
      if (outletId != null && outletId.isNotEmpty) {
        url += '?outlet_id=$outletId';
      }
      final res = await ApiClient.get(url);
      if (res['success'] == true) {
        trialBalanceData = res;
      }
    } catch (e) {
      debugPrint('Error fetching Trial Balance: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfitLoss({String? startDate, String? endDate, String? period, String? outletId}) async {
    loading = true;
    notifyListeners();
    try {
      String url = ApiEndpoints.accountingProfitLoss;
      List<String> params = [];
      if (startDate != null && startDate.isNotEmpty) params.add('startDate=$startDate');
      if (endDate != null && endDate.isNotEmpty) params.add('endDate=$endDate');
      if (period != null && period.isNotEmpty) params.add('period=$period');
      if (outletId != null && outletId.isNotEmpty) params.add('outlet_id=$outletId');
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      final res = await ApiClient.get(url);
      if (res['success'] == true) {
        profitLossData = res['data'] ?? {};
      }
    } catch (e) {
      debugPrint('Error fetching P&L: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBalanceSheet({String? outletId}) async {
    loading = true;
    notifyListeners();
    try {
      String url = ApiEndpoints.accountingBalanceSheet;
      if (outletId != null && outletId.isNotEmpty) {
        url += '?outlet_id=$outletId';
      }
      final res = await ApiClient.get(url);
      if (res['success'] == true) {
        balanceSheetData = res['data'] ?? {};
      }
    } catch (e) {
      debugPrint('Error fetching Balance Sheet: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBrs({int? bankId, String? outletId}) async {
    loading = true;
    notifyListeners();
    try {
      String url = ApiEndpoints.accountingBrs;
      List<String> params = [];
      if (bankId != null) params.add('bank_account_id=$bankId');
      if (outletId != null && outletId.isNotEmpty) params.add('outlet_id=$outletId');
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      final res = await ApiClient.get(url);
      if (res['success'] == true) {
        brsData = res;
      }
    } catch (e) {
      debugPrint('Error fetching BRS: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
