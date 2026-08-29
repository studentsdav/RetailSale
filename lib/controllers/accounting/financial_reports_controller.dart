import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class FinancialReportsController extends ChangeNotifier {
  bool loading = false;

  Map<String, dynamic> trialBalanceData = {};
  Map<String, dynamic> profitLossData = {};
  Map<String, dynamic> balanceSheetData = {};
  Map<String, dynamic> brsData = {};

  Future<void> fetchTrialBalance() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.accountingTrialBalance);
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

  Future<void> fetchProfitLoss() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.accountingProfitLoss);
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

  Future<void> fetchBalanceSheet() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.accountingBalanceSheet);
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

  Future<void> fetchBrs({int? bankId}) async {
    loading = true;
    notifyListeners();
    try {
      String url = ApiEndpoints.accountingBrs;
      if (bankId != null) {
        url += '?bank_account_id=$bankId';
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
