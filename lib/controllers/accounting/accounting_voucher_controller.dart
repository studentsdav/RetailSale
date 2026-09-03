import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';
import '../../models/accounting/accounting_voucher_model.dart';

class AccountingVoucherController extends ChangeNotifier {
  bool loading = false;
  List<AccountingVoucherModel> vouchers = [];

  String activeType = 'CONTRA'; // CONTRA, PAYMENT, RECEIPT, JOURNAL
  DateTime voucherDate = DateTimeService.instance.nowInTimeZone;
  String paymentMode = 'CASH'; // CASH, BANK, CHEQUE, ONLINE
  int? selectedBankId;
  final refNoCtrl = TextEditingController();
  final narrationCtrl = TextEditingController();

  List<VoucherLineModel> lines = [];

  AccountingVoucherController() {
    resetLines();
  }

  void resetLines() {
    lines = [
      VoucherLineModel(
        lineType: 'DEBIT',
        accountName: 'HDFC Bank - Current A/c',
        debitAmount: 0.0,
        creditAmount: 0.0,
      ),
      VoucherLineModel(
        lineType: 'CREDIT',
        accountName: 'Main Cash Drawer',
        debitAmount: 0.0,
        creditAmount: 0.0,
      ),
    ];
    notifyListeners();
  }

  void setActiveType(String type) {
    activeType = type;
    if (type == 'CONTRA') {
      lines[0].accountName = 'HDFC Bank - Current A/c';
      lines[1].accountName = 'Main Cash Drawer';
    } else if (type == 'PAYMENT') {
      lines[0].accountName = 'Expense Account / Vendor';
      lines[1].accountName = 'Main Cash Drawer';
    } else if (type == 'RECEIPT') {
      lines[0].accountName = 'Main Cash Drawer';
      lines[1].accountName = 'Customer Dues / Revenue';
    } else if (type == 'JOURNAL') {
      lines[0].accountName = 'Depreciation / Adjustment A/c';
      lines[1].accountName = 'Fixed Asset / Ledger A/c';
    }
    notifyListeners();
  }

  void addLine() {
    lines.add(VoucherLineModel(
      lineType: 'DEBIT',
      accountName: 'General Ledger Account',
      debitAmount: 0.0,
      creditAmount: 0.0,
    ));
    notifyListeners();
  }

  void removeLine(int index) {
    if (lines.length > 2) {
      lines.removeAt(index);
      notifyListeners();
    }
  }

  double get totalDebit {
    return lines.fold(0.0, (sum, item) => sum + item.debitAmount);
  }

  double get totalCredit {
    return lines.fold(0.0, (sum, item) => sum + item.creditAmount);
  }

  double get difference {
    return (totalDebit - totalCredit).abs();
  }

  bool get isBalanced {
    return difference < 0.01 && totalDebit > 0;
  }

  Future<void> fetchVouchers({String? type}) async {
    loading = true;
    notifyListeners();

    try {
      String url = ApiEndpoints.accountingVouchers;
      if (type != null && type.isNotEmpty) {
        url += '?voucher_type=$type';
      }
      final res = await ApiClient.get(url);
      if (res['success'] == true && res['data'] is List) {
        vouchers = (res['data'] as List)
            .map((e) => AccountingVoucherModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching vouchers: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> submitVoucher() async {
    if (!isBalanced) {
      return {
        'success': false,
        'message':
            'Voucher is unbalanced! Total Debit (₹${totalDebit.toStringAsFixed(2)}) must equal Total Credit (₹${totalCredit.toStringAsFixed(2)}).'
      };
    }

    loading = true;
    notifyListeners();

    try {
      final payload = {
        'voucher_type': activeType,
        'voucher_date': voucherDate.toIso8601String().split('T')[0],
        'payment_mode': paymentMode,
        'bank_account_id': selectedBankId,
        'reference_no': refNoCtrl.text.trim(),
        'narration': narrationCtrl.text.trim(),
        'lines': lines.map((e) => e.toJson()).toList(),
      };

      final res = await ApiClient.post(ApiEndpoints.accountingVouchers, payload);
      if (res['success'] == true) {
        resetLines();
        refNoCtrl.clear();
        narrationCtrl.clear();
        await fetchVouchers(type: activeType);
        return {'success': true, 'data': res['data']};
      }
      return {
        'success': false,
        'message': res['message'] ?? 'Failed to create voucher'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
