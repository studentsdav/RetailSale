import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/accounting/bank_account_model.dart';

class BankAccountController extends ChangeNotifier {
  bool loading = false;
  List<BankAccountModel> banks = [];

  Future<void> fetchBanks({bool includeInactive = true}) async {
    loading = true;
    notifyListeners();

    try {
      final url = includeInactive ? '${ApiEndpoints.accountingBanks}?include_inactive=true' : ApiEndpoints.accountingBanks;
      final res = await ApiClient.get(url);
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
    bool isPrimary = false,
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
        'is_primary': isPrimary,
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

  Future<bool> updateBank({
    required int id,
    required String bankName,
    required String accountName,
    required String accountNumber,
    String? ifscCode,
    String? branchName,
    String accountType = 'CURRENT',
    double? openingBalance,
    bool? isActive,
    bool? isPrimary,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.put('${ApiEndpoints.accountingBanks}/$id', {
        'bank_name': bankName,
        'account_name': accountName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'branch_name': branchName,
        'account_type': accountType,
        if (openingBalance != null) 'opening_balance': openingBalance,
        if (isActive != null) 'is_active': isActive,
        if (isPrimary != null) 'is_primary': isPrimary,
      });

      if (res['success'] == true) {
        await fetchBanks();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating bank account: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> setPrimaryBank(int id) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post('${ApiEndpoints.accountingBanks}/$id/set-primary', {});
      if (res['success'] == true) {
        await fetchBanks();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error setting primary bank account: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleBankActive(int id) async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.post('${ApiEndpoints.accountingBanks}/$id/toggle-active', {});
      if (res['success'] == true) {
        await fetchBanks();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error toggling bank account active state: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
