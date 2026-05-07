import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/finance_models.dart';

class FinanceHubController extends ChangeNotifier {
  bool loading = false;

  List<LedgerDayGroup> ledgerDays = [];
  double openingBalance = 0;
  double depositTotal = 0;
  double totalIn = 0;
  double totalOut = 0;
  double closingBalance = 0;
  List<LedgerPaymentMethodSummary> ledgerPaymentMethods = [];

  List<CreditCustomerReport> creditCustomers = [];
  double totalOutstanding = 0;
  double totalAdvance = 0;
  int totalCreditBills = 0;

  List<ExpenseEntryReport> expenses = [];
  double expenseTotal = 0;

  List<IncomeEntryReport> incomes = [];
  double incomeTotal = 0;

  List<WithdrawalEntryReport> withdrawals = [];
  double withdrawalTotal = 0;

  List<OpeningBalanceEntry> openings = [];
  double carriedOpeningBalance = 0;

  List<DeliveryReportEntry> deliveries = [];
  double deliveryTotal = 0;
  double deliveryOutstanding = 0;

  List<ExpiryReportEntry> expiryItems = [];
  int expiredCount = 0;
  int nearExpiryCount = 0;

  Future<void> _run(Future<void> Function() action) async {
    loading = true;
    notifyListeners();
    try {
      await action();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadLedger({
    required DateTime fromDate,
    required DateTime toDate,
    String search = '',
    String type = '',
    String paymentMethod = '',
  }) async {
    await _run(() async {
      final params = <String>[
        'from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}',
        'to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
      ];
      if (search.trim().isNotEmpty) params.add('search=${Uri.encodeComponent(search.trim())}');
      if (type.trim().isNotEmpty) params.add('type=${Uri.encodeComponent(type.trim())}');
      if (paymentMethod.trim().isNotEmpty) {
        params.add('payment_method=${Uri.encodeComponent(paymentMethod.trim())}');
      }
      final res = await ApiClient.get('${ApiEndpoints.financeLedger}?${params.join('&')}');
      openingBalance = _num(res['summary']?['openingBalance']);
      depositTotal = _num(res['summary']?['depositTotal']);
      totalIn = _num(res['summary']?['totalIn']);
      totalOut = _num(res['summary']?['totalOut']);
      closingBalance = _num(res['summary']?['closingBalance']);
      ledgerPaymentMethods =
          (res['payment_method_summary'] as List? ?? const [])
              .map((e) => LedgerPaymentMethodSummary.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
      ledgerDays = (res['daily'] as List? ?? const [])
          .map((e) => LedgerDayGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> loadCreditReport({required DateTime fromDate, required DateTime toDate, String customer = ''}) async {
    await _run(() async {
      final params = <String>[
        'from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}',
        'to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
      ];
      if (customer.trim().isNotEmpty) params.add('customer=${Uri.encodeComponent(customer.trim())}');
      final res = await ApiClient.get('${ApiEndpoints.financeCreditReport}?${params.join('&')}');
      totalOutstanding = _num(res['summary']?['total_outstanding']);
      totalAdvance = _num(res['summary']?['total_advance']);
      totalCreditBills = _intVal(res['summary']?['total_credit_bills']);
      creditCustomers = (res['data'] as List? ?? const [])
          .map((e) => CreditCustomerReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> saveRepayment({int? repaymentId, required int saleId, required DateTime paymentDate, required double amount, required String paymentMode, String referenceNo = '', String note = ''}) async {
    final body = {
      'sale_id': saleId,
      'payment_date': DateFormat('yyyy-MM-dd').format(paymentDate),
      'amount': amount,
      'payment_mode': paymentMode,
      'reference_no': referenceNo,
      'note': note,
    };
    if (repaymentId == null) {
      await ApiClient.post(ApiEndpoints.financeRepayments, body);
    } else {
      await ApiClient.put('${ApiEndpoints.financeRepayments}/$repaymentId', body);
    }
  }

  Future<void> saveAdvance({
    int? advanceId,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required DateTime advanceDate,
    required double amount,
    required String paymentMode,
    String referenceNo = '',
    String note = '',
    int? sourceSaleId,
  }) async {
    final body = {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_gstin': customerGstin,
      'advance_date': DateFormat('yyyy-MM-dd').format(advanceDate),
      'amount': amount,
      'payment_mode': paymentMode,
      'reference_no': referenceNo,
      'note': note,
      'source_sale_id': sourceSaleId,
    };
    if (advanceId == null) {
      await ApiClient.post(ApiEndpoints.financeAdvances, body);
    } else {
      await ApiClient.put('${ApiEndpoints.financeAdvances}/$advanceId', body);
    }
  }

  Future<void> loadExpenses({required DateTime fromDate, required DateTime toDate, String category = ''}) async {
    await _run(() async {
      final params = <String>[
        'from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}',
        'to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
      ];
      if (category.trim().isNotEmpty) params.add('category=${Uri.encodeComponent(category.trim())}');
      final res = await ApiClient.get('${ApiEndpoints.financeExpenses}?${params.join('&')}');
      expenseTotal = _num(res['summary']?['totalAmount']);
      expenses = (res['data'] as List? ?? const [])
          .map((e) => ExpenseEntryReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> saveExpense({int? expenseId, required DateTime expenseDate, required String category, required double amount, String note = ''}) async {
    final body = {
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'category': category,
      'amount': amount,
      'note': note,
    };
    if (expenseId == null) {
      await ApiClient.post(ApiEndpoints.financeExpenses, body);
    } else {
      await ApiClient.put('${ApiEndpoints.financeExpenses}/$expenseId', body);
    }
  }

  Future<void> loadIncome({required DateTime fromDate, required DateTime toDate, String search = ''}) async {
    await _run(() async {
      final params = <String>[
        'from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}',
        'to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
      ];
      if (search.trim().isNotEmpty) params.add('search=${Uri.encodeComponent(search.trim())}');
      final res = await ApiClient.get('${ApiEndpoints.financeIncome}?${params.join('&')}');
      incomeTotal = _num(res['summary']?['totalAmount']);
      incomes = (res['data'] as List? ?? const [])
          .map((e) => IncomeEntryReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> saveIncome({
    int? incomeId,
    required DateTime incomeDate,
    required String source,
    required double amount,
    required String paymentMode,
    String partyName = '',
    String referenceNo = '',
    String note = '',
  }) async {
    final body = {
      'income_date': DateFormat('yyyy-MM-dd').format(incomeDate),
      'source': source,
      'amount': amount,
      'payment_mode': paymentMode,
      'party_name': partyName,
      'reference_no': referenceNo,
      'note': note,
    };
    if (incomeId == null) {
      await ApiClient.post(ApiEndpoints.financeIncome, body);
    } else {
      await ApiClient.put('${ApiEndpoints.financeIncome}/$incomeId', body);
    }
  }

  Future<void> loadWithdrawals({
    required DateTime fromDate,
    required DateTime toDate,
    String search = '',
  }) async {
    await _run(() async {
      final params = <String>[
        'from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}',
        'to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
      ];
      if (search.trim().isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search.trim())}');
      }
      final res = await ApiClient.get(
        '${ApiEndpoints.financeWithdrawals}?${params.join('&')}',
      );
      withdrawalTotal = _num(res['summary']?['totalAmount']);
      withdrawals = (res['data'] as List? ?? const [])
          .map((e) =>
              WithdrawalEntryReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> saveWithdrawal({
    int? withdrawalId,
    required DateTime withdrawalDate,
    required String purpose,
    required double amount,
    required String paymentMode,
    String referenceNo = '',
    String note = '',
  }) async {
    final body = {
      'withdrawal_date': DateFormat('yyyy-MM-dd').format(withdrawalDate),
      'purpose': purpose,
      'amount': amount,
      'payment_mode': paymentMode,
      'reference_no': referenceNo,
      'note': note,
    };
    if (withdrawalId == null) {
      await ApiClient.post(ApiEndpoints.financeWithdrawals, body);
    } else {
      await ApiClient.put('${ApiEndpoints.financeWithdrawals}/$withdrawalId', body);
    }
  }

  Future<void> loadOpeningBalances({required DateTime fromDate, required DateTime toDate}) async {
    await _run(() async {
      final res = await ApiClient.get('${ApiEndpoints.financeOpeningBalance}?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}');
      carriedOpeningBalance = _num(res['summary']?['carried_opening_balance']);
      openings = (res['data'] as List? ?? const [])
          .map((e) => OpeningBalanceEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> saveOpeningBalance({required DateTime balanceDate, required double openingBalance, String note = ''}) async {
    await ApiClient.post(ApiEndpoints.financeOpeningBalance, {
      'balance_date': DateFormat('yyyy-MM-dd').format(balanceDate),
      'opening_balance': openingBalance,
      'note': note,
    });
  }

  Future<void> loadDeliveryReport({required DateTime fromDate, required DateTime toDate, String search = '', String status = ''}) async {
    await _run(() async {
      final params = <String>[
        'from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}',
        'to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
      ];
      if (search.trim().isNotEmpty) params.add('search=${Uri.encodeComponent(search.trim())}');
      if (status.trim().isNotEmpty) params.add('status=${Uri.encodeComponent(status.trim())}');
      final res = await ApiClient.get('${ApiEndpoints.financeDeliveryReport}?${params.join('&')}');
      deliveryTotal = _num(res['summary']?['total_amount']);
      deliveryOutstanding = _num(res['summary']?['total_outstanding']);
      deliveries = (res['data'] as List? ?? const [])
          .map((e) => DeliveryReportEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> loadExpiryReport({String search = '', String status = 'ALL', int alertDays = 7}) async {
    await _run(() async {
      final params = <String>['status=$status', 'alert_days=$alertDays'];
      if (search.trim().isNotEmpty) params.add('search=${Uri.encodeComponent(search.trim())}');
      final res = await ApiClient.get('${ApiEndpoints.financeExpiryReport}?${params.join('&')}');
      expiredCount = _intVal(res['summary']?['expired_count']);
      nearExpiryCount = _intVal(res['summary']?['near_expiry_count']);
      expiryItems = (res['data'] as List? ?? const [])
          .map((e) => ExpiryReportEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  double _num(dynamic value) => double.tryParse((value ?? 0).toString()) ?? 0;
  int _intVal(dynamic value) => int.tryParse((value ?? 0).toString()) ?? 0;
}
