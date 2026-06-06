import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/finance_hub_controller.dart';
import '../../models/reports/finance_models.dart';

class CashLedgerScreen extends StatefulWidget {
  const CashLedgerScreen({super.key});

  @override
  State<CashLedgerScreen> createState() => _CashLedgerScreenState();
}

class _CashLedgerScreenState extends State<CashLedgerScreen>
    with SingleTickerProviderStateMixin {
  final ctrl = FinanceHubController();
  late final TabController _tabController;

  final List<String> expensePresets = const [
    'Salary',
    'Petrol',
    'Diesel',
    'Commission',
    'Rent',
    'Basic Expense',
  ];

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  DateTime openingDate = DateTime.now();

  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  final creditSearchCtrl = TextEditingController();
  final ledgerSearchCtrl = TextEditingController();
  final expenseCategoryCtrl = TextEditingController();
  final incomeSearchCtrl = TextEditingController();
  final withdrawalSearchCtrl = TextEditingController();
  final deliverySearchCtrl = TextEditingController();
  final expirySearchCtrl = TextEditingController();
  final openingAmountCtrl = TextEditingController();
  final openingNoteCtrl = TextEditingController();
  final alertDaysCtrl = TextEditingController(text: '7');

  String ledgerType = '';
  String ledgerPaymentMethod = '';
  String deliveryStatus = '';
  String expiryStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCurrentTab();
        setState(() {});
      }
    });
    fromCtrl.text = _fmtDate(fromDate);
    toCtrl.text = _fmtDate(toDate);
    _loadCurrentTab();
  }

  @override
  void dispose() {
    _tabController.dispose();
    fromCtrl.dispose();
    toCtrl.dispose();
    creditSearchCtrl.dispose();
    ledgerSearchCtrl.dispose();
    expenseCategoryCtrl.dispose();
    incomeSearchCtrl.dispose();
    withdrawalSearchCtrl.dispose();
    deliverySearchCtrl.dispose();
    expirySearchCtrl.dispose();
    openingAmountCtrl.dispose();
    openingNoteCtrl.dispose();
    alertDaysCtrl.dispose();
    ctrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime value) => DateFormat('dd-MMM-yyyy').format(value);
  String _fmtDateTime(DateTime value) {
    final local = value.toLocal();
    if (local.hour == 0 && local.minute == 0) {
      return DateFormat('dd-MMM-yyyy').format(local);
    }
    return DateFormat('dd-MMM-yyyy hh:mm a').format(local);
  }
  String _money(double value) => 'Rs. ${value.toStringAsFixed(2)}';
  String _plainAmount(double value) => value.toStringAsFixed(2);
  List<LedgerDayGroup> get _ledgerDaysAsc {
    final days = [...ctrl.ledgerDays];
    days.sort((a, b) => a.date.compareTo(b.date));
    return days;
  }
  double get _ledgerOutstandingGrandTotal => _ledgerDaysAsc.fold<double>(
        0,
        (sum, day) => sum +
            day.entries.fold<double>(
              0,
              (entrySum, entry) => entrySum + _ledgerOutstanding(entry),
            ),
      );
  double get _ledgerCreditGrandTotal => _ledgerDaysAsc.fold<double>(
        0,
        (sum, day) =>
            sum + day.entries.fold<double>(0, (entrySum, entry) => entrySum + entry.amountIn),
      );
  double get _ledgerDebitGrandTotal => _ledgerDaysAsc.fold<double>(
        0,
        (sum, day) => sum +
            day.entries.fold<double>(
              0,
              (entrySum, entry) =>
                  entrySum +
                  (entry.amountOut > 0 ? entry.amountOut : entry.adjustmentAmount),
            ),
      );

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        fromDate = picked;
        fromCtrl.text = _fmtDate(picked);
      } else {
        toDate = picked;
        toCtrl.text = _fmtDate(picked);
      }
    });
  }

  Future<void> _loadCurrentTab() async {
    switch (_tabController.index) {
      case 0:
        await ctrl.loadCreditReport(
            fromDate: fromDate,
            toDate: toDate,
            customer: creditSearchCtrl.text);
        break;
      case 1:
        await ctrl.loadLedger(
            fromDate: fromDate,
            toDate: toDate,
            search: ledgerSearchCtrl.text,
            type: ledgerType,
            paymentMethod: ledgerPaymentMethod);
        break;
      case 2:
        await ctrl.loadExpenses(
            fromDate: fromDate,
            toDate: toDate,
            category: expenseCategoryCtrl.text);
        break;
      case 3:
        await ctrl.loadIncome(
            fromDate: fromDate, toDate: toDate, search: incomeSearchCtrl.text);
        break;
      case 4:
        await ctrl.loadWithdrawals(
            fromDate: fromDate,
            toDate: toDate,
            search: withdrawalSearchCtrl.text);
        break;
      case 5:
        await ctrl.loadOpeningBalances(fromDate: fromDate, toDate: toDate);
        openingAmountCtrl.text = ctrl.carriedOpeningBalance.toStringAsFixed(2);
        break;
      case 6:
        await ctrl.loadDeliveryReport(
            fromDate: fromDate,
            toDate: toDate,
            search: deliverySearchCtrl.text,
            status: deliveryStatus);
        break;
      case 7:
        await ctrl.loadExpiryReport(
            search: expirySearchCtrl.text,
            status: expiryStatus,
            alertDays: int.tryParse(alertDaysCtrl.text) ?? 7);
        break;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'SAFE':
        return Colors.green;
      case 'PARTIAL':
      case 'NEAR_EXPIRY':
        return Colors.amber.shade800;
      default:
        return Colors.red;
    }
  }

  Future<void> _showExpenseDialog(
      {ExpenseEntryReport? expense, String initialCategory = ''}) async {
    final categoryCtrl =
        TextEditingController(text: expense?.category ?? initialCategory);
    final amountCtrl = TextEditingController(
        text: expense == null ? '' : expense.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: expense?.note ?? '');
    DateTime expenseDate = expense?.expenseDate ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(expense == null ? 'Add Expense' : 'Edit Expense'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expensePresets
                        .map((preset) => ActionChip(
                              label: Text(preset),
                              onPressed: () {
                                categoryCtrl.text = preset;
                                setDialogState(() {});
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Expense Type',
                      hintText: 'Salary / Petrol / Diesel / Commission / Rent',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expense Date'),
                    subtitle: Text(_fmtDate(expenseDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expenseDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setDialogState(() => expenseDate = picked);
                    },
                  ),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remark / Note',
                      hintText:
                          'Salary given to Ravi, Rent paid for April, Diesel for van',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await ctrl.saveExpense(
                    expenseId: expense?.id,
                    expenseDate: expenseDate,
                    category: categoryCtrl.text.trim(),
                    amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                    note: noteCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await ctrl.loadExpenses(
                      fromDate: fromDate,
                      toDate: toDate,
                      category: expenseCategoryCtrl.text);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showIncomeDialog({IncomeEntryReport? income}) async {
    final sourceCtrl = TextEditingController(text: income?.source ?? '');
    final partyCtrl = TextEditingController(text: income?.partyName ?? '');
    final amountCtrl = TextEditingController(
        text: income == null ? '' : income.amount.toStringAsFixed(2));
    final refCtrl = TextEditingController(text: income?.referenceNo ?? '');
    final noteCtrl = TextEditingController(text: income?.note ?? '');
    DateTime incomeDate = income?.incomeDate ?? DateTime.now();
    String paymentMode = income?.paymentMethod.isNotEmpty == true
        ? income!.paymentMethod
        : 'CASH';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(income == null ? 'Add Income' : 'Edit Income'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: sourceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Income Source',
                      hintText: 'Box sale / loading income / misc income',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Received From',
                      hintText: 'Party name or helper name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    items: const [
                      'CASH',
                      'CARD',
                      'UPI',
                      'BANK',
                      'WAIVEOFF',
                    ]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e == 'WAIVEOFF' ? 'Waive Off' : e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => paymentMode = value ?? 'CASH'),
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Income Date'),
                    subtitle: Text(_fmtDate(incomeDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: incomeDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => incomeDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: refCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Reference No'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ctrl.saveIncome(
                    incomeId: income?.id,
                    incomeDate: incomeDate,
                    source: sourceCtrl.text.trim(),
                    amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                    paymentMode: paymentMode,
                    partyName: partyCtrl.text.trim(),
                    referenceNo: refCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await ctrl.loadIncome(
                    fromDate: fromDate,
                    toDate: toDate,
                    search: incomeSearchCtrl.text,
                  );
                  await ctrl.loadLedger(
                    fromDate: fromDate,
                    toDate: toDate,
                    search: ledgerSearchCtrl.text,
                    type: ledgerType,
                    paymentMethod: ledgerPaymentMethod,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRepaymentDialog(CreditBill bill,
      {RepaymentEntry? payment}) async {
    final amountCtrl = TextEditingController(
        text: (payment?.amount ?? bill.outstanding).toStringAsFixed(2));
    final refCtrl = TextEditingController(text: payment?.referenceNo ?? '');
    final noteCtrl = TextEditingController(text: payment?.note ?? '');
    DateTime paymentDate = payment?.paymentDate ?? DateTime.now();
    String paymentMode =
        payment?.paymentMode.isNotEmpty == true ? payment!.paymentMode : 'CASH';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(payment == null ? 'Add Repayment' : 'Edit Repayment'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(bill.billNo),
                    subtitle: Text('Outstanding ${_money(bill.outstanding)}'),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    items: const ['CASH', 'CARD', 'UPI', 'BANK', 'WAIVEOFF']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e == 'WAIVEOFF' ? 'Waive Off' : e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => paymentMode = value ?? 'CASH'),
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payment Date'),
                    subtitle: Text(_fmtDate(paymentDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setDialogState(() => paymentDate = picked);
                    },
                  ),
                  TextField(
                      controller: refCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Reference No')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Note')),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await ctrl.saveRepayment(
                    repaymentId: payment?.id,
                    saleId: bill.saleId,
                    paymentDate: paymentDate,
                    amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                    paymentMode: paymentMode,
                    referenceNo: refCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await ctrl.loadCreditReport(
                      fromDate: fromDate,
                      toDate: toDate,
                      customer: creditSearchCtrl.text);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAdvanceDialog(
    CreditCustomerReport customer, {
    AdvanceEntry? advance,
  }) async {
    final amountCtrl = TextEditingController(
      text: (advance?.originalAmount ?? customer.totalAdvance)
          .toStringAsFixed(2),
    );
    final refCtrl = TextEditingController(text: advance?.referenceNo ?? '');
    final noteCtrl = TextEditingController(text: advance?.note ?? '');
    DateTime advanceDate = advance?.advanceDate ?? DateTime.now();
    String paymentMode =
        advance?.paymentMode.isNotEmpty == true ? advance!.paymentMode : 'CASH';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(advance == null ? 'Add Advance' : 'Edit Advance'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(customer.customerName),
                    subtitle: Text(
                      'Available advance ${_money(customer.totalAdvance)}',
                    ),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Advance Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    items: const [
                      'CASH',
                      'CARD',
                      'UPI',
                      'BANK',
                      'SUBSCRIPTION',
                    ]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e == 'SUBSCRIPTION' ? 'Subscription' : e,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => paymentMode = value ?? 'CASH'),
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Advance Date'),
                    subtitle: Text(_fmtDate(advanceDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: advanceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => advanceDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: refCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Reference No'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ctrl.saveAdvance(
                    advanceId: advance?.id,
                    customerName: customer.customerName,
                    customerPhone: customer.customerPhone,
                    customerGstin: customer.customerGstin,
                    advanceDate: advanceDate,
                    amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                    paymentMode: paymentMode,
                    referenceNo: refCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                    sourceSaleId: advance?.sourceSaleId,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await ctrl.loadCreditReport(
                    fromDate: fromDate,
                    toDate: toDate,
                    customer: creditSearchCtrl.text,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showWithdrawalDialog(
      {WithdrawalEntryReport? withdrawal}) async {
    final purposeCtrl = TextEditingController(text: withdrawal?.purpose ?? '');
    final amountCtrl = TextEditingController(
        text: withdrawal == null ? '' : withdrawal.amount.toStringAsFixed(2));
    final refCtrl = TextEditingController(text: withdrawal?.referenceNo ?? '');
    final noteCtrl = TextEditingController(text: withdrawal?.note ?? '');
    DateTime withdrawalDate = withdrawal?.withdrawalDate ?? DateTime.now();
    String paymentMode = withdrawal?.paymentMethod.isNotEmpty == true
        ? withdrawal!.paymentMethod
        : 'CASH';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title:
                Text(withdrawal == null ? 'Add Withdrawal' : 'Edit Withdrawal'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Owner Withdrawal',
                      'Bank Deposit',
                      'Cash Transfer',
                      'Petty Cash',
                    ]
                        .map(
                          (preset) => ActionChip(
                            label: Text(preset),
                            onPressed: () {
                              purposeCtrl.text = preset;
                              setDialogState(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: purposeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      hintText: 'Owner withdrawal / bank deposit / cash transfer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    items: const ['CASH', 'CARD', 'UPI', 'BANK']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => paymentMode = value ?? 'CASH'),
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Withdrawal Date'),
                    subtitle: Text(_fmtDate(withdrawalDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: withdrawalDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => withdrawalDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: refCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Reference No'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ctrl.saveWithdrawal(
                    withdrawalId: withdrawal?.id,
                    withdrawalDate: withdrawalDate,
                    purpose: purposeCtrl.text.trim(),
                    amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                    paymentMode: paymentMode,
                    referenceNo: refCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await ctrl.loadWithdrawals(
                    fromDate: fromDate,
                    toDate: toDate,
                    search: withdrawalSearchCtrl.text,
                  );
                  await ctrl.loadLedger(
                    fromDate: fromDate,
                    toDate: toDate,
                    search: ledgerSearchCtrl.text,
                    type: ledgerType,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveOpeningBalance() async {
    await ctrl.saveOpeningBalance(
      balanceDate: openingDate,
      openingBalance: double.tryParse(openingAmountCtrl.text.trim()) ?? 0,
      note: openingNoteCtrl.text.trim(),
    );
    await ctrl.loadOpeningBalances(fromDate: fromDate, toDate: toDate);
    await ctrl.loadLedger(fromDate: fromDate, toDate: toDate);
  }

  Future<void> _exportExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Report'];
    int row = 0;
    void writeRow(
      List<String> values, {
      exc.CellStyle? style,
      int startColumn = 0,
    }) {
      for (int i = 0; i < values.length; i++) {
        final cell = sheet.cell(
          exc.CellIndex.indexByColumnRow(
            columnIndex: startColumn + i,
            rowIndex: row,
          ),
        );
        cell.value = exc.TextCellValue(values[i]);
        if (style != null) {
          cell.cellStyle = style;
        }
      }
      row++;
    }

    final headerStyle = exc.CellStyle(
      bold: true,
      fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: exc.ExcelColor.fromHexString('#1D4ED8'),
    );
    final totalStyle = exc.CellStyle(
      bold: true,
      backgroundColorHex: exc.ExcelColor.fromHexString('#DBEAFE'),
    );
    final ledgerEvenStyle = exc.CellStyle(
      backgroundColorHex: exc.ExcelColor.fromHexString('#F8FAFC'),
    );
    final ledgerOddStyle = exc.CellStyle(
      backgroundColorHex: exc.ExcelColor.fromHexString('#EEF4FF'),
    );
    final ledgerOpeningStyle = exc.CellStyle(
      bold: true,
      backgroundColorHex: exc.ExcelColor.fromHexString('#E0E7FF'),
    );
    final ledgerDayTotalStyle = exc.CellStyle(
      bold: true,
      backgroundColorHex: exc.ExcelColor.fromHexString('#FEF3C7'),
    );
    final ledgerGrandTotalStyle = exc.CellStyle(
      bold: true,
      fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: exc.ExcelColor.fromHexString('#1E3A8A'),
    );
    final creditTotalStyle = exc.CellStyle(
      bold: true,
      backgroundColorHex: exc.ExcelColor.fromHexString('#E0F2FE'),
    );
    final salesTotalStyle = exc.CellStyle(
      bold: true,
      backgroundColorHex: exc.ExcelColor.fromHexString('#DCFCE7'),
    );

    if (_tabController.index == 2) {
      writeRow(['Date', 'Type', 'Amount', 'Remark']);
      for (final item in ctrl.expenses) {
        writeRow([
          _fmtDate(item.expenseDate),
          item.category,
          item.amount.toStringAsFixed(2),
          item.note
        ]);
      }
    } else if (_tabController.index == 0) {
      writeRow(
        ['Customer', 'Bill', 'Date', 'Amount', 'Outstanding', 'Status'],
        style: headerStyle,
      );
      for (final customer in ctrl.creditCustomers) {
        for (final bill in customer.bills) {
          writeRow([
            customer.customerName,
            bill.billNo,
            _fmtDate(bill.billDate),
            bill.amount.toStringAsFixed(2),
            bill.outstanding.toStringAsFixed(2),
            bill.paymentStatus
          ]);
        }
      }
      writeRow([
        'TOTAL',
        '${ctrl.totalCreditBills}',
        '',
        ctrl.creditCustomers
            .fold<double>(
              0,
              (sum, customer) =>
                  sum +
                  customer.bills.fold<double>(
                    0,
                    (billSum, bill) => billSum + bill.amount,
                  ),
            )
            .toStringAsFixed(2),
        ctrl.totalOutstanding.toStringAsFixed(2),
        '',
      ], style: creditTotalStyle);
    } else if (_tabController.index == 1) {
      writeRow([
        'Date',
        'Type',
        'Ref',
        'Party',
        'Note',
        'Outstanding',
        'Credit',
        'Debit',
        'Balance'
      ]);
      final ledgerDays = _ledgerDaysAsc;
      int ledgerRowIndex = 0;
      for (final day in ledgerDays) {
        final dayOutstandingTotal = day.entries.fold<double>(
          0,
          (sum, entry) => sum + _ledgerOutstanding(entry),
        );
        final dayCreditTotal = day.entries.fold<double>(
          0,
          (sum, entry) => sum + entry.amountIn,
        );
        final dayDebitTotal = day.entries.fold<double>(
          0,
          (sum, entry) =>
              sum +
              (entry.amountOut > 0 ? entry.amountOut : entry.adjustmentAmount),
        );
        writeRow([
          _fmtDate(day.date),
          'OPENING DEPOSIT',
          '',
          '',
          'Opening deposit carried for business',
          '',
          day.openingBalance.toStringAsFixed(2),
          '',
          day.openingBalance.toStringAsFixed(2),
        ], style: ledgerOpeningStyle);
        for (final entry in day.entries) {
          writeRow([
            _fmtDateTime(entry.txnDate),
            entry.transactionType,
            entry.referenceNo,
            entry.partyName,
            _ledgerNote(entry),
            _ledgerOutstanding(entry) <= 0
                ? ''
                : _ledgerOutstanding(entry).toStringAsFixed(2),
            entry.amountIn.toStringAsFixed(2),
            (entry.amountOut > 0 ? entry.amountOut : entry.adjustmentAmount)
                .toStringAsFixed(2),
            entry.balance.toStringAsFixed(2)
          ], style: ledgerRowIndex.isEven ? ledgerEvenStyle : ledgerOddStyle);
          ledgerRowIndex++;
        }
        writeRow([
          'DAY TOTAL',
          '',
          '',
          '',
          '',
          dayOutstandingTotal <= 0 ? '' : dayOutstandingTotal.toStringAsFixed(2),
          dayCreditTotal.toStringAsFixed(2),
          dayDebitTotal.toStringAsFixed(2),
          '',
        ], style: ledgerDayTotalStyle);
      }
      writeRow([
        'TOTAL',
        '',
        '',
        '',
        '',
        _ledgerOutstandingGrandTotal.toStringAsFixed(2),
        _ledgerCreditGrandTotal.toStringAsFixed(2),
        _ledgerDebitGrandTotal.toStringAsFixed(2),
        ''
      ], style: ledgerGrandTotalStyle);
    } else if (_tabController.index == 3) {
      writeRow([
        'Date',
        'Source',
        'Received From',
        'Mode',
        'Amount',
        'Reference',
        'Note'
      ]);
      for (final item in ctrl.incomes) {
        writeRow([
          _fmtDate(item.incomeDate),
          item.source,
          item.partyName,
          item.paymentMethod,
          item.amount.toStringAsFixed(2),
          item.referenceNo,
          item.note,
        ]);
      }
    } else if (_tabController.index == 4) {
      writeRow([
        'Date',
        'Purpose',
        'Mode',
        'Amount',
        'Reference',
        'Note'
      ]);
      for (final item in ctrl.withdrawals) {
        writeRow([
          _fmtDate(item.withdrawalDate),
          item.purpose,
          item.paymentMethod,
          item.amount.toStringAsFixed(2),
          item.referenceNo,
          item.note,
        ]);
      }
    } else if (_tabController.index == 5) {
      writeRow(['Date', 'Opening Deposit', 'Note']);
      for (final item in ctrl.openings) {
        writeRow([
          _fmtDate(item.balanceDate),
          item.openingBalance.toStringAsFixed(2),
          item.note
        ]);
      }
    } else if (_tabController.index == 6) {
      writeRow(
        ['Date', 'Bill', 'Customer', 'Amount', 'Outstanding', 'Status'],
        style: headerStyle,
      );
      for (final item in ctrl.deliveries) {
        writeRow([
          _fmtDate(item.date),
          item.billNo,
          item.customerName,
          item.amount.toStringAsFixed(2),
          item.outstanding.toStringAsFixed(2),
          item.paymentStatus
        ]);
      }
      writeRow([
        'TOTAL',
        '${ctrl.deliveries.length}',
        '',
        ctrl.deliveryTotal.toStringAsFixed(2),
        ctrl.deliveryOutstanding.toStringAsFixed(2),
        '',
      ], style: salesTotalStyle);
    } else {
      writeRow(['Item', 'Code', 'Qty', 'Expiry', 'Days', 'Status']);
      for (final item in ctrl.expiryItems) {
        writeRow([
          item.itemName,
          item.itemCode,
          item.qty.toStringAsFixed(2),
          _fmtDate(item.expiryDate),
          item.daysLeft.toString(),
          item.status
        ]);
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/finance_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final rows = <List<String>>[];
    List<String> headers = const [];
    PdfColor accent = PdfColors.blueGrey700;
    pw.BoxDecoration tableRowDecoration =
        const pw.BoxDecoration(color: PdfColors.white);
    pw.BoxDecoration tableOddRowDecoration =
        const pw.BoxDecoration(color: PdfColors.grey100);
    final titles = [
      'Credit Report',
      'Ledger',
      'Expense Report',
      'Income Report',
      'Withdrawal Report',
      'Opening Deposit',
      'Sales Report',
      'Expiry Report'
    ];

    if (_tabController.index == 2) {
      headers = const ['Date', 'Type', 'Amount', 'Remark'];
      for (final item in ctrl.expenses) {
        rows.add([
          _fmtDate(item.expenseDate),
          item.category,
          item.amount.toStringAsFixed(2),
          item.note
        ]);
      }
    } else if (_tabController.index == 0) {
      accent = PdfColors.lightBlue700;
      headers = const [
        'Customer',
        'Bill',
        'Date',
        'Amount',
        'Outstanding',
        'Status'
      ];
      for (final customer in ctrl.creditCustomers) {
        for (final bill in customer.bills) {
          rows.add([
            customer.customerName,
            bill.billNo,
            _fmtDate(bill.billDate),
            bill.amount.toStringAsFixed(2),
            bill.outstanding.toStringAsFixed(2),
            bill.paymentStatus
          ]);
        }
      }
      rows.add([
        'TOTAL',
        '${ctrl.totalCreditBills}',
        '',
        ctrl.creditCustomers
            .fold<double>(
              0,
              (sum, customer) =>
                  sum +
                  customer.bills.fold<double>(
                    0,
                    (billSum, bill) => billSum + bill.amount,
                  ),
            )
            .toStringAsFixed(2),
        ctrl.totalOutstanding.toStringAsFixed(2),
        '',
      ]);
    } else if (_tabController.index == 1) {
      accent = PdfColors.indigo700;
      tableRowDecoration = const pw.BoxDecoration(color: PdfColors.blue50);
      tableOddRowDecoration =
          const pw.BoxDecoration(color: PdfColors.indigo50);
      headers = const [
        'Date',
        'Type',
        'Ref',
        'Party',
        'Note',
        'Outstanding',
        'Credit',
        'Debit',
        'Balance'
      ];
      for (final day in _ledgerDaysAsc) {
        final dayOutstandingTotal = day.entries.fold<double>(
          0,
          (sum, entry) => sum + _ledgerOutstanding(entry),
        );
        final dayCreditTotal = day.entries.fold<double>(
          0,
          (sum, entry) => sum + entry.amountIn,
        );
        final dayDebitTotal = day.entries.fold<double>(
          0,
          (sum, entry) =>
              sum +
              (entry.amountOut > 0 ? entry.amountOut : entry.adjustmentAmount),
        );
        rows.add([
          _fmtDate(day.date),
          'OPENING DEPOSIT',
          '',
          '',
          'Opening deposit carried for business',
          '',
          day.openingBalance.toStringAsFixed(2),
          '',
          day.openingBalance.toStringAsFixed(2)
        ]);
        for (final entry in day.entries) {
          rows.add([
            _fmtDateTime(entry.txnDate),
            entry.transactionType,
            entry.referenceNo,
            entry.partyName,
            _ledgerNote(entry),
            _ledgerOutstanding(entry) <= 0
                ? ''
                : _ledgerOutstanding(entry).toStringAsFixed(2),
            entry.amountIn.toStringAsFixed(2),
            (entry.amountOut > 0 ? entry.amountOut : entry.adjustmentAmount)
                .toStringAsFixed(2),
            entry.balance.toStringAsFixed(2)
          ]);
        }
        rows.add([
          'DAY TOTAL',
          '',
          '',
          '',
          '',
          dayOutstandingTotal <= 0 ? '' : dayOutstandingTotal.toStringAsFixed(2),
          dayCreditTotal.toStringAsFixed(2),
          dayDebitTotal.toStringAsFixed(2),
          '',
        ]);
      }
      rows.add([
        'TOTAL',
        '',
        '',
        '',
        '',
        _ledgerOutstandingGrandTotal.toStringAsFixed(2),
        _ledgerCreditGrandTotal.toStringAsFixed(2),
        _ledgerDebitGrandTotal.toStringAsFixed(2),
        ''
      ]);
    } else if (_tabController.index == 3) {
      headers = const [
        'Date',
        'Source',
        'Received From',
        'Mode',
        'Amount',
        'Reference',
        'Note'
      ];
      for (final item in ctrl.incomes) {
        rows.add([
          _fmtDate(item.incomeDate),
          item.source,
          item.partyName,
          item.paymentMethod,
          item.amount.toStringAsFixed(2),
          item.referenceNo,
          item.note
        ]);
      }
    } else if (_tabController.index == 4) {
      headers = const [
        'Date',
        'Purpose',
        'Mode',
        'Amount',
        'Reference',
        'Note'
      ];
      for (final item in ctrl.withdrawals) {
        rows.add([
          _fmtDate(item.withdrawalDate),
          item.purpose,
          item.paymentMethod,
          item.amount.toStringAsFixed(2),
          item.referenceNo,
          item.note
        ]);
      }
    } else if (_tabController.index == 5) {
      headers = const ['Date', 'Opening Deposit', 'Note'];
      for (final item in ctrl.openings) {
        rows.add([
          _fmtDate(item.balanceDate),
          item.openingBalance.toStringAsFixed(2),
          item.note
        ]);
      }
    } else if (_tabController.index == 6) {
      accent = PdfColors.green700;
      headers = const [
        'Date',
        'Bill',
        'Customer',
        'Amount',
        'Outstanding',
        'Status'
      ];
      for (final item in ctrl.deliveries) {
        rows.add([
          _fmtDate(item.date),
          item.billNo,
          item.customerName,
          item.amount.toStringAsFixed(2),
          item.outstanding.toStringAsFixed(2),
          item.paymentStatus
        ]);
      }
      rows.add([
        'TOTAL',
        '${ctrl.deliveries.length}',
        '',
        ctrl.deliveryTotal.toStringAsFixed(2),
        ctrl.deliveryOutstanding.toStringAsFixed(2),
        '',
      ]);
    } else {
      headers = const ['Item', 'Code', 'Qty', 'Expiry', 'Days', 'Status'];
      for (final item in ctrl.expiryItems) {
        rows.add([
          item.itemName,
          item.itemCode,
          item.qty.toStringAsFixed(2),
          _fmtDate(item.expiryDate),
          item.daysLeft.toString(),
          item.status
        ]);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  titles[_tabController.index],
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'From ${_fmtDate(fromDate)} To ${_fmtDate(toDate)}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          if (_tabController.index == 0)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.lightBlue50,
                border: pw.Border.all(color: PdfColors.lightBlue200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfMiniStat('Bills', '${ctrl.totalCreditBills}'),
                  _pdfMiniStat('Outstanding', ctrl.totalOutstanding.toStringAsFixed(2)),
                  _pdfMiniStat('Advance', ctrl.totalAdvance.toStringAsFixed(2)),
                ],
              ),
            ),
          if (_tabController.index == 6)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfMiniStat('Sales', '${ctrl.deliveries.length}'),
                  _pdfMiniStat('Amount', ctrl.deliveryTotal.toStringAsFixed(2)),
                  _pdfMiniStat(
                    'Outstanding',
                    ctrl.deliveryOutstanding.toStringAsFixed(2),
                  ),
                ],
              ),
            ),
          if (_tabController.index == 0 || _tabController.index == 6)
            pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerDecoration: pw.BoxDecoration(color: accent),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            rowDecoration: tableRowDecoration,
            oddRowDecoration: tableOddRowDecoration,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfMiniStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Finance & Reports'),
        actions: [
          IconButton(
              onPressed: _exportExcel,
              icon: const Icon(Icons.file_download_outlined)),
          IconButton(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined)),
          IconButton(
              onPressed: _loadCurrentTab, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Credit'),
            Tab(text: 'Ledger'),
            Tab(text: 'Expenses'),
            Tab(text: 'Income'),
            Tab(text: 'Withdrawal'),
            Tab(text: 'Opening'),
            Tab(text: 'Sales'),
            Tab(text: 'Expiry'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              onPressed: () => _showExpenseDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Expense'))
          : _tabController.index == 3
              ? FloatingActionButton.extended(
                  onPressed: () => _showIncomeDialog(),
                  icon: const Icon(Icons.add_chart_outlined),
                  label: const Text('Income'))
              : _tabController.index == 4
                  ? FloatingActionButton.extended(
                      onPressed: () => _showWithdrawalDialog(),
                      icon: const Icon(Icons.money_off_csred_outlined),
                      label: const Text('Withdrawal'))
              : null,
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading)
            return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              _filterCard(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _creditTab(),
                    _ledgerTab(),
                    _expenseTab(),
                    _incomeTab(),
                    _withdrawalTab(),
                    _openingTab(),
                    _deliveryTab(),
                    _expiryTab()
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final isMedium = constraints.maxWidth >= 760;
        final fieldWidth = isWide
            ? 220.0
            : isMedium
                ? (constraints.maxWidth - 60) / 3
                : constraints.maxWidth;
        final smallFieldWidth = isWide
            ? 170.0
            : isMedium
                ? (constraints.maxWidth - 48) / 2
                : constraints.maxWidth;
        final narrowFieldWidth = isWide
            ? 160.0
            : isMedium
                ? (constraints.maxWidth - 60) / 3
                : constraints.maxWidth;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dateField('From', fromCtrl, () => _pickDate(true),
                  width: smallFieldWidth),
              _dateField('To', toCtrl, () => _pickDate(false),
                  width: smallFieldWidth),
              if (_tabController.index == 0)
                _textField(creditSearchCtrl, 'Customer name / number',
                    width: fieldWidth),
              if (_tabController.index == 1) ...[
                _textField(ledgerSearchCtrl, 'Ledger search', width: fieldWidth),
                _dropdown(
                  ledgerType,
                  'Type',
                  const [
                    '',
                    'SALE_CASH',
                    'SALE_CREDIT',
                    'REPAYMENT',
                    'EXPENSE',
                    'SUPPLIER_PAYMENT',
                    'INCOME',
                    'OPENING_DEPOSIT',
                    'WITHDRAWAL',
                    'SUBSCRIPTION',
                    'OUTSTANDING'
                  ],
                  (v) => setState(() => ledgerType = v ?? ''),
                  width: narrowFieldWidth,
                ),
                _dropdown(
                  ledgerPaymentMethod,
                  'Payment',
                  const ['', 'CASH', 'CARD', 'UPI', 'BANK', 'CREDIT'],
                  (v) => setState(() => ledgerPaymentMethod = v ?? ''),
                  width: narrowFieldWidth,
                ),
              ],
              if (_tabController.index == 2)
                _textField(expenseCategoryCtrl, 'Expense type',
                    width: fieldWidth),
              if (_tabController.index == 3)
                _textField(incomeSearchCtrl, 'Income source / note',
                    width: fieldWidth),
              if (_tabController.index == 4)
                _textField(withdrawalSearchCtrl, 'Withdrawal purpose / note',
                    width: fieldWidth),
              if (_tabController.index == 6) ...[
                _textField(deliverySearchCtrl, 'Customer / Bill search',
                    width: fieldWidth),
                _dropdown(
                  deliveryStatus,
                  'Status',
                  const ['', 'PAID', 'PARTIAL', 'UNPAID'],
                  (v) => setState(() => deliveryStatus = v ?? ''),
                  width: narrowFieldWidth,
                ),
              ],
              if (_tabController.index == 7) ...[
                _textField(expirySearchCtrl, 'Item search', width: fieldWidth),
                _dropdown(
                  expiryStatus,
                  'Status',
                  const ['ALL', 'NEAR_EXPIRY', 'EXPIRED', 'SAFE'],
                  (v) => setState(() => expiryStatus = v ?? 'ALL'),
                  width: narrowFieldWidth,
                ),
                SizedBox(
                  width: narrowFieldWidth,
                  child: TextField(
                    controller: alertDaysCtrl,
                    decoration: const InputDecoration(labelText: 'Alert Days'),
                  ),
                ),
              ],
              SizedBox(
                width: isMedium ? null : constraints.maxWidth,
                child: FilledButton.icon(
                  onPressed: _loadCurrentTab,
                  icon: const Icon(Icons.search),
                  label: const Text('Apply'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _creditTab() {
    final visibleCustomers = ctrl.creditCustomers
        .map<Map<String, dynamic>>(
          (customer) => {
            'customer': customer,
            'bills': customer.bills
                .where((bill) => bill.outstanding > 0.009)
                .toList(growable: false),
          },
        )
        .where(
          (entry) =>
              (entry['bills'] as List).isNotEmpty ||
              (entry['customer'] as CreditCustomerReport).totalAdvance > 0.009,
        )
        .toList(growable: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _summaryWrap([
            _summaryCard(
                'Credit Bills', '${ctrl.totalCreditBills}', Colors.blue),
            _summaryCard(
                'Outstanding', _money(ctrl.totalOutstanding), Colors.red),
            _summaryCard('Advance', _money(ctrl.totalAdvance), Colors.green),
          ]),
          const SizedBox(height: 12),
          ...visibleCustomers.map(
            (entry) {
              final customer = entry['customer'] as CreditCustomerReport;
              final bills = entry['bills'] as List<CreditBill>;
              return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  customer.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${customer.customerPhone} - Outstanding ${_money(customer.totalOutstanding)} - Advance ${_money(customer.totalAdvance)}',
                ),
                children: bills
                    .map(
                      (bill) => Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill.billNo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${_fmtDate(bill.billDate)} - ${_money(bill.amount)}',
                                    ),
                                  ],
                                ),
                                _statusChip(bill.paymentStatus),
                                FilledButton.tonal(
                                  onPressed: () => _showRepaymentDialog(bill),
                                  child: const Text('Repayment'),
                                ),
                                FilledButton.tonal(
                                  onPressed: bill.outstanding > 0.009
                                      ? () => _showWaiveOffDialog(bill)
                                      : null,
                                  child: const Text('Waive Off'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                _summaryCard(
                                  'Initial Paid',
                                  _money(bill.initialPaid),
                                  Colors.blueGrey,
                                ),
                                _summaryCard(
                                  'Repaid',
                                  _money(bill.repaymentTotal),
                                  Colors.green,
                                ),
                                _summaryCard(
                                  'Total Paid',
                                  _money(bill.totalPaid),
                                  Colors.blue,
                                ),
                                _summaryCard(
                                  'Outstanding',
                                  _money(bill.outstanding),
                                  Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (bill.payments.isEmpty)
                              const Text('No repayment transactions yet.')
                            else
                              ...bill.payments.map(
                                (payment) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    runSpacing: 8,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                          '${_paymentModeLabel(payment.paymentMode)} - ${_money(payment.amount)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                          Text(
                                            '${_fmtDate(payment.paymentDate)} - ${payment.referenceNo}',
                                          ),
                                          if (payment.note.trim().isNotEmpty)
                                            Text(payment.note),
                                        ],
                                      ),
                                      IconButton(
                                        onPressed: () => _showRepaymentDialog(
                                          bill,
                                          payment: payment,
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
            },
          ),
          ...visibleCustomers
              .where(
                (entry) =>
                    (entry['customer'] as CreditCustomerReport)
                        .advances
                        .isNotEmpty,
              )
              .map(
                (entry) {
                  final customer = entry['customer'] as CreditCustomerReport;
                  return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${customer.customerName} Advances',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Available ${_money(customer.totalAdvance)}',
                                ),
                              ],
                            ),
                            FilledButton.tonal(
                              onPressed: () => _showAdvanceDialog(customer),
                              child: const Text('Add Advance'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...customer.advances.map(
                          (advance) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black12,
                              ),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              runSpacing: 8,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${advance.paymentMode} - ${_money(advance.originalAmount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${_fmtDate(advance.advanceDate)} - Available ${_money(advance.availableAmount)}',
                                    ),
                                    if (advance.referenceNo.trim().isNotEmpty)
                                      Text(advance.referenceNo),
                                    if (advance.note.trim().isNotEmpty)
                                      Text(advance.note),
                                  ],
                                ),
                                if (advance.paymentMode.trim().toUpperCase() !=
                                        'SUBSCRIPTION')
                                  IconButton(
                                    onPressed: () =>
                                        _showAdvanceDialog(customer, advance: advance),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                },
              ),
          if (visibleCustomers.isEmpty)
            _emptyCard('No credit bills found for the selected filters.'),
        ],
      ),
    );
  }

  Future<void> _showWaiveOffDialog(CreditBill bill) async {
    final amountCtrl = TextEditingController(
      text: bill.outstanding.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(
      text: 'Waive off for ${bill.billNo}',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waive Off Outstanding'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(bill.billNo),
                subtitle: Text('Outstanding ${_money(bill.outstanding)}'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Waive Off Amount',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ctrl.saveRepayment(
                saleId: bill.saleId,
                paymentDate: DateTime.now(),
                amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                paymentMode: 'WAIVEOFF',
                referenceNo: '',
                note: noteCtrl.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              await ctrl.loadCreditReport(
                fromDate: fromDate,
                toDate: toDate,
                customer: creditSearchCtrl.text,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _ledgerTab() {
    final visibleLedgerMethods = ctrl.ledgerPaymentMethods.where((entry) {
      final method = entry.paymentMethod.trim().toUpperCase();
      return method != 'ADVANCE' && method != 'CREDIT';
    }).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
          _summaryWrap([
            _summaryCard(
                'Deposit', _money(ctrl.depositTotal), Colors.blueGrey),
            _summaryCard('Credit', _money(_ledgerCreditGrandTotal), Colors.green),
            _summaryCard('Debit', _money(_ledgerDebitGrandTotal), Colors.red),
            _summaryCard(
                'Outstanding', _money(_ledgerOutstandingGrandTotal), Colors.deepOrange),
            _summaryCard('Closing', _money(ctrl.closingBalance), Colors.indigo),
            ...visibleLedgerMethods.map(
              (entry) => _summaryCard(
                entry.paymentMethod,
                _plainAmount(entry.amountIn > 0 ? entry.amountIn : entry.amountOut),
                const Color(0xFF0F766E),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Selected range opening deposit: ${_money(ctrl.openingBalance)}. Each day below starts with its deposit row first, then the day transactions.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
              ..._ledgerDaysAsc.map(
            (day) {
              final dayOutstandingTotal = day.entries.fold<double>(
                0,
                (sum, entry) => sum + _ledgerOutstanding(entry),
              );
              final dayCreditTotal = day.entries.fold<double>(
                0,
                (sum, entry) => sum + entry.amountIn,
              );
              final dayDebitTotal = day.entries.fold<double>(
                0,
                (sum, entry) =>
                    sum +
                    (entry.amountOut > 0
                        ? entry.amountOut
                        : entry.adjustmentAmount),
              );
              return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          _fmtDate(day.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Deposit ${_money(day.openingBalance)}',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Closing ${_money(day.closingBalance)}',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Methods: ${day.entries.map((e) => e.paymentMethod).where((e) { final method = e.trim().toUpperCase(); return method.isNotEmpty && method != 'ADVANCE' && method != 'CREDIT'; }).toSet().join(', ')}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLedgerCompactTable(
                    day: day,
                    dayOutstandingTotal: dayOutstandingTotal,
                    dayCreditTotal: dayCreditTotal,
                    dayDebitTotal: dayDebitTotal,
                  ),
                ],
              ),
            );
            },
          ),
              if (ctrl.ledgerDays.isEmpty)
                _emptyCard('No ledger entries found.'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLedgerCompactTable({
    required LedgerDayGroup day,
    required double dayOutstandingTotal,
    required double dayCreditTotal,
    required double dayDebitTotal,
  }) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.25),
        1: FlexColumnWidth(1.15),
        2: FlexColumnWidth(0.85),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(1.9),
        6: FlexColumnWidth(0.95),
        7: FlexColumnWidth(0.95),
        8: FlexColumnWidth(0.95),
        9: FlexColumnWidth(0.95),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          children: const [
            _LedgerHeaderCell('Time'),
            _LedgerHeaderCell('Type'),
            _LedgerHeaderCell('Ref'),
            _LedgerHeaderCell('Party'),
            _LedgerHeaderCell('Pay'),
            _LedgerHeaderCell('Note'),
            _LedgerHeaderCell('Outstanding'),
            _LedgerHeaderCell('Credit'),
            _LedgerHeaderCell('Debit'),
            _LedgerHeaderCell('Balance'),
          ],
        ),
        TableRow(
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(.08),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          children: [
            _LedgerCell(_fmtDate(day.date)),
            const _LedgerCell('OPENING', bold: true),
            const _LedgerCell('-'),
            const _LedgerCell('-'),
            const _LedgerCell('-'),
            const _LedgerCell('Opening deposit carried for business'),
            const _LedgerCell('-', align: TextAlign.right),
            _LedgerCell(
              _money(day.openingBalance),
              align: TextAlign.right,
              bold: true,
              color: Colors.green,
            ),
            const _LedgerCell('-', align: TextAlign.right),
            _LedgerCell(
              _money(day.openingBalance),
              align: TextAlign.right,
              bold: true,
              color: Colors.indigo,
            ),
          ],
        ),
        ...day.entries.map((entry) {
          final debitAmount = entry.amountOut > 0
              ? entry.amountOut
              : entry.adjustmentAmount;
          return TableRow(
            decoration: BoxDecoration(
              color: _ledgerRowColor(entry),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            children: [
              _LedgerCell(_fmtDateTime(entry.txnDate)),
              _LedgerCell(_ledgerTypeLabel(entry.transactionType)),
              _LedgerCell(entry.referenceNo.isEmpty ? '-' : entry.referenceNo),
              _LedgerCell(entry.partyName.isEmpty ? '-' : entry.partyName),
              _LedgerCell(entry.paymentMethod.isEmpty ? '-' : entry.paymentMethod),
              _LedgerCell(_ledgerNote(entry)),
              _LedgerCell(
                _ledgerOutstanding(entry) <= 0 ? '-' : _money(_ledgerOutstanding(entry)),
                align: TextAlign.right,
                color: _ledgerOutstanding(entry) > 0 ? Colors.deepOrange : null,
                bold: _ledgerOutstanding(entry) > 0,
              ),
              _LedgerCell(
                entry.amountIn <= 0 ? '-' : _money(entry.amountIn),
                align: TextAlign.right,
                color: entry.amountIn > 0 ? Colors.green : null,
                bold: entry.amountIn > 0,
              ),
              _LedgerCell(
                debitAmount <= 0 ? '-' : _money(debitAmount),
                align: TextAlign.right,
                color: debitAmount > 0 ? Colors.red : null,
                bold: debitAmount > 0,
              ),
              _LedgerCell(
                _money(entry.balance),
                align: TextAlign.right,
                color: Colors.indigo,
                bold: true,
              ),
            ],
          );
        }),
        TableRow(
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(.08),
          ),
          children: [
            const _LedgerCell('DAY TOTAL', bold: true),
            const _LedgerCell('-'),
            const _LedgerCell('-'),
            const _LedgerCell('-'),
            const _LedgerCell('-'),
            const _LedgerCell('-'),
            _LedgerCell(
              dayOutstandingTotal <= 0 ? '-' : _money(dayOutstandingTotal),
              align: TextAlign.right,
              color: Colors.deepOrange,
              bold: true,
            ),
            _LedgerCell(
              _money(dayCreditTotal),
              align: TextAlign.right,
              color: Colors.green,
              bold: true,
            ),
            _LedgerCell(
              _money(dayDebitTotal),
              align: TextAlign.right,
              color: Colors.red,
              bold: true,
            ),
            const _LedgerCell('-', align: TextAlign.right, color: Colors.indigo, bold: true),
          ],
        ),
      ],
    );
  }

  Widget _expenseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _summaryWrap([
            _summaryCard(
                'Expense Total', _money(ctrl.expenseTotal), Colors.red),
            _summaryCard('Entries', '${ctrl.expenses.length}', Colors.orange),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick expense entry',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Add salary, petrol, diesel, commission, rent and keep remarks like who was paid and why.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: expensePresets
                          .map((preset) => OutlinedButton(
                              onPressed: () =>
                                  _showExpenseDialog(initialCategory: preset),
                              child: Text(preset)))
                          .toList(),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          ...ctrl.expenses.map((expense) => Card(
                child: ListTile(
                  title: Text(expense.category,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${_fmtDate(expense.expenseDate)}  -  ${expense.note}'),
                  trailing: Wrap(spacing: 8, children: [
                    Text(_money(expense.amount),
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: () => _showExpenseDialog(expense: expense),
                        icon: const Icon(Icons.edit_outlined)),
                  ]),
                ),
              )),
          if (ctrl.expenses.isEmpty)
            _emptyCard('No expenses found for the selected range.'),
        ],
      ),
    );
  }

  Widget _incomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _summaryWrap([
            _summaryCard(
                'Income Total', _money(ctrl.incomeTotal), Colors.green),
            _summaryCard('Entries', '${ctrl.incomes.length}', Colors.teal),
          ]),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Other income',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use this for income like box sale, loading charges, rent recovery, or any extra cash received. It will be adjusted in the ledger automatically.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...ctrl.incomes.map(
            (income) => Card(
              child: ListTile(
                title: Text(
                  income.source,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${_fmtDate(income.incomeDate)}  -  ${income.partyName.isEmpty ? income.note : income.partyName}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _money(income.amount),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showIncomeDialog(income: income),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (ctrl.incomes.isEmpty)
            _emptyCard('No income entries found for the selected range.'),
        ],
      ),
    );
  }

  Widget _withdrawalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _summaryWrap([
            _summaryCard(
                'Withdrawal Total', _money(ctrl.withdrawalTotal), Colors.red),
            _summaryCard(
                'Entries', '${ctrl.withdrawals.length}', Colors.deepOrange),
          ]),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash withdrawal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use this tab for owner withdrawal, bank deposit, petty cash movement, or other cash taken out. It will be posted to ledger debit automatically.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...ctrl.withdrawals.map(
            (withdrawal) => Card(
              child: ListTile(
                title: Text(
                  withdrawal.purpose,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${_fmtDate(withdrawal.withdrawalDate)}  -  ${withdrawal.note}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _money(withdrawal.amount),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _showWithdrawalDialog(withdrawal: withdrawal),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (ctrl.withdrawals.isEmpty)
            _emptyCard('No withdrawals found for the selected range.'),
        ],
      ),
    );
  }

  Widget _openingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        _summaryWrap([
          _summaryCard(
              'Carry Forward', _money(ctrl.carriedOpeningBalance), Colors.blue),
          _summaryCard('Saved Days', '${ctrl.openings.length}', Colors.teal),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Opening deposit is carried forward automatically at local day-end. If you do not save a new deposit for the next day, the previous closing balance will be used.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Balance Date'),
                subtitle: Text(_fmtDate(openingDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: openingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (picked != null) setState(() => openingDate = picked);
                },
              ),
              TextField(
                  controller: openingAmountCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Opening Deposit')),
              const SizedBox(height: 12),
              TextField(
                  controller: openingNoteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Note')),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                      onPressed: _saveOpeningBalance,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        ...ctrl.openings.map((item) => Card(
            child: ListTile(
                title: Text(_fmtDate(item.balanceDate)),
                subtitle: Text(item.note),
                trailing: Text(_money(item.openingBalance))))),
      ]),
    );
  }

  Widget _deliveryTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final leftWidth = isWide ? 320.0 : constraints.maxWidth;
        final rightWidth = isWide ? 220.0 : constraints.maxWidth;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
          _summaryWrap([
          _summaryCard('Sales', '${ctrl.deliveries.length}', Colors.blue),
          _summaryCard('Amount', _money(ctrl.deliveryTotal), Colors.green),
          _summaryCard(
              'Outstanding', _money(ctrl.deliveryOutstanding), Colors.red),
        ]),
        const SizedBox(height: 12),
        ...ctrl.deliveries.map(
          (item) => Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.billNo} - ${item.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('${_fmtDate(item.date)} - ${item.customerPhone}'),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount: ${_money(item.amount)}'),
                        Text('Paid: ${_money(item.paidAmount)}'),
                        Text('Outstanding: ${_money(item.outstanding)}'),
                      ],
                    ),
                  ),
                  _statusChip(item.paymentStatus),
                ],
              ),
            ),
          ),
        ),
        if (ctrl.deliveries.isEmpty) _emptyCard('No sales found.'),
      ]),
        );
      },
    );
  }

  Widget _expiryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        _summaryWrap([
          _summaryCard('Expired', '${ctrl.expiredCount}', Colors.red),
          _summaryCard(
              'Near Expiry', '${ctrl.nearExpiryCount}', Colors.amber.shade800),
          _summaryCard('Items', '${ctrl.expiryItems.length}', Colors.blue),
        ]),
        const SizedBox(height: 12),
        ...ctrl.expiryItems.map((item) => Card(
                child: ListTile(
              title: Text('${item.itemName} (${item.itemCode})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'Qty ${item.qty.toStringAsFixed(2)} ${item.unit}  -  Expiry ${_fmtDate(item.expiryDate)}'),
              trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusChip(item.status),
                    Text('${item.daysLeft} days')
                  ]),
            ))),
        if (ctrl.expiryItems.isEmpty) _emptyCard('No expiry items found.'),
      ]),
    );
  }

  Widget _summaryWrap(List<Widget> children) =>
      Wrap(spacing: 12, runSpacing: 12, children: children);

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(.16),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _dateField(
          String label, TextEditingController controller, VoidCallback onTap,
          {double width = 170}) =>
      SizedBox(
        width: width,
        child: TextField(
            controller: controller,
            readOnly: true,
            onTap: onTap,
            decoration: InputDecoration(
                labelText: label,
                suffixIcon: const Icon(Icons.calendar_today))),
      );

  Widget _textField(TextEditingController controller, String label,
          {double width = 220}) =>
      SizedBox(
        width: width,
        child: TextField(
            controller: controller,
            decoration: InputDecoration(
                labelText: label, prefixIcon: const Icon(Icons.search))),
      );

  Widget _dropdown(String value, String label, List<String> items,
          ValueChanged<String?> onChanged,
          {double width = 160}) =>
      SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(
                  value: item, child: Text(item.isEmpty ? 'All' : item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      );

  String _paymentModeLabel(String paymentMode) {
    switch (paymentMode.trim().toUpperCase()) {
      case 'WAIVEOFF':
      case 'WRITEOFF':
      case 'WRITE_OFF':
      case 'WAIVE_OFF':
        return 'Waive Off';
      default:
        return paymentMode.trim().isEmpty ? 'CASH' : paymentMode.trim();
    }
  }

  String _ledgerNote(CashLedgerEntry entry) {
    if (entry.transactionType.toUpperCase() == 'INCOME' &&
        entry.notes.startsWith('SOURCE:')) {
      String source = '';
      String note = '';
      for (final line in entry.notes.split('\n')) {
        if (line.startsWith('SOURCE:')) {
          source = line.substring(7).trim();
        } else if (line.startsWith('NOTE:')) {
          note = line.substring(5).trim();
        }
      }
      if (note.isEmpty) return source;
      return '$source - $note';
    }
    return entry.notes.trim().isEmpty ? '-' : entry.notes.trim();
  }

  double _ledgerOutstanding(CashLedgerEntry entry) {
    final text = entry.notes.trim();
    if (text.isEmpty) return 0;
    final match =
        RegExp(r'outstanding\s+([0-9]+(?:\.[0-9]+)?)', caseSensitive: false)
            .firstMatch(text);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  String _ledgerTypeLabel(String type) {
    switch (type.trim().toUpperCase()) {
      case 'SALE_CASH':
        return 'Sales';
      case 'SALE_CREDIT':
        return 'Sales Credit';
      case 'REPAYMENT':
        return 'Credit Payment';
      case 'WAIVE_OFF':
        return 'Waive Off';
      case 'ADVANCE_APPLY':
        return 'Advance Adjustment';
      case 'OPENING_DEPOSIT':
        return 'Opening Deposit';
      case 'WITHDRAWAL':
        return 'Cash Withdrawal';
      case 'INCOME':
        return 'Other Income';
      case 'EXPENSE':
        return 'Expense';
      case 'SUPPLIER_PAYMENT':
        return 'Supplier Payment';
      case 'SUBSCRIPTION_SCHEME_FREE_EXPENSE':
        return 'Subscription Advance Adjustment';
      case 'SALE_SUBSCRIPTION_FREE_EXPENSE':
        return 'Subscription Advance Adjustment';
      case 'SALE_SUBSCRIPTION_ADJUSTMENT':
        return 'Subscription Advance Adjustment';
      case 'SALE_MODIFY_ADJUSTMENT':
        return 'Bill Adjustment';
      default:
        return type
            .trim()
            .split('_')
            .where((part) => part.isNotEmpty)
            .map(
              (part) => '${part[0]}${part.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  Color _ledgerRowColor(CashLedgerEntry entry) {
    if (entry.amountIn > 0) return Colors.green.withOpacity(.05);
    if (entry.amountOut > 0) return Colors.red.withOpacity(.05);
    return Colors.white;
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Chip(
      backgroundColor: color.withOpacity(.12),
      label: Text(status,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _LedgerHeaderCell extends StatelessWidget {
  final String text;

  const _LedgerHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LedgerCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool bold;
  final Color? color;

  const _LedgerCell(
    this.text, {
    this.align = TextAlign.left,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
