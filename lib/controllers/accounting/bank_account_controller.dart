import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/accounting/bank_account_model.dart';

class BankAccountController extends ChangeNotifier {
  bool loading = false;
  List<BankAccountModel> banks = [];

  Future<void> fetchBanks() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiEndpoints.accountingBanks);
      if (res['success'] == true && res['data'] is List) {
        banks = (res['data'] as List)
            .map((e) => BankAccountModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching bank accounts: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createBank({
    required String bankName,
    required String accountName,
    required String accountNumber,
    String? ifscCode,
    String? branchName,
    String accountType = 'CURRENT',
    double openingBalance = 0.0,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post(ApiEndpoints.accountingBanks, {
        'bank_name': bankName,
        'account_name': accountName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'branch_name': branchName,
        'account_type': accountType,
        'opening_balance': openingBalance,
      });

      if (res['success'] == true) {
        await fetchBanks();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating bank account: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
