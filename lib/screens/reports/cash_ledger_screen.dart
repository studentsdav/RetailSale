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
import '../../models/inventory/supplier_model.dart';
import '../../models/security/app_user_model.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import 'credit_analysis_screen.dart';
import 'expense_analytics_screen.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/printing/pos_invoice_printer.dart';
import '../../utils/branding_storage.dart';
import '../../utils/pdf_report_builder.dart';

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
  bool _showOutstandingOnly = false;

  final Set<String> _expandedBillsCustomers = {};
  final Set<String> _expandedAdvancesCustomers = {};

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
        await ctrl.loadExpenseCategories();
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

  Future<void> _confirmDelete(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense? This will also remove the cash ledger entry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ctrl.deleteExpense(expenseId);
      await ctrl.loadExpenses(
        fromDate: fromDate,
        toDate: toDate,
        categoryId: '',
      );
    }
  }

  Future<void> _showExpenseDialog(
      {ExpenseEntryReport? expense, String initialCategory = ''}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExpenseEntryDialog(
        expense: expense,
        ctrl: ctrl,
        initialCategory: initialCategory,
        onSaved: () async {
          await ctrl.loadExpenses(
            fromDate: fromDate,
            toDate: toDate,
            categoryId: '',
          );
          await ctrl.loadLedger(
            fromDate: fromDate,
            toDate: toDate,
          );
        },
      ),
    );
  }

  void _onLedgerRowTapped(CashLedgerEntry entry) async {
    final isExpense = entry.transactionType.trim().toUpperCase() == 'EXPENSE' ||
        entry.referenceType.trim().toUpperCase() == 'EXPENSE';
        
    if (!isExpense) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Colors.indigo),
                title: Text('Expense: ${entry.referenceNo}'),
                subtitle: Text('Amount: ${_money(entry.amountOut > 0 ? entry.amountOut : entry.adjustmentAmount)}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Edit Expense'),
                onTap: () async {
                  Navigator.pop(context);
                  _editExpenseFromLedger(entry.referenceId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: Colors.green),
                title: const Text('Print Receipt'),
                onTap: () async {
                  Navigator.pop(context);
                  _printExpenseFromLedger(entry.referenceId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editExpenseFromLedger(String? referenceId) async {
    if (referenceId == null || referenceId.isEmpty) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final expense = await ctrl.fetchExpenseById(referenceId);
    
    if (mounted) {
      Navigator.pop(context);
    }
    
    if (expense == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load expense details.')),
        );
      }
      return;
    }
    
    if (mounted) {
      _showExpenseDialog(expense: expense);
    }
  }

  Future<void> _printExpenseFromLedger(String? referenceId) async {
    if (referenceId == null || referenceId.isEmpty) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final expense = await ctrl.fetchExpenseById(referenceId);
    
    if (mounted) {
      Navigator.pop(context);
    }
    
    if (expense == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load expense details.')),
        );
      }
      return;
    }
    
    await ExpenseEntryDialog.printExpenseReceipt(expense);
  }

  Future<void> _addNewCategory() async {
    final nameCtrl = TextEditingController();
    final newCat = await showDialog<ExpenseCategoryModel?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Office Supplies',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                final cat = await ctrl.saveExpenseCategory(name);
                Navigator.pop(context, cat);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save category: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCat != null) {
      setState(() {});
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 17,
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          )
        ],
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
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  bool adjustExtra = false;

                  if (amount > bill.outstanding) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Adjust Excess Payment?'),
                        content: Text(
                            'The entered amount Rs. ${amount.toStringAsFixed(2)} exceeds this bill\'s outstanding balance of Rs. ${bill.outstanding.toStringAsFixed(2)}.\n\nWould you like to automatically adjust the extra Rs. ${(amount - bill.outstanding).toStringAsFixed(2)} towards other outstanding credit bills or customer advance?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false), // Cancel
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true), // Yes, Adjust
                            child: const Text('Adjust Excess'),
                          ),
                        ],
                      ),
                    );

                    if (proceed != true) return; // User cancelled
                    adjustExtra = true;
                  }

                  await ctrl.saveRepayment(
                    repaymentId: payment?.id,
                    saleId: bill.saleId,
                    paymentDate: paymentDate,
                    amount: amount,
                    paymentMode: paymentMode,
                    referenceNo: refCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                    adjustExtra: adjustExtra,
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

  Future<void> _showBulkRepaymentDialog(
      CreditCustomerReport customer, List<CreditBill> bills) async {
    if (bills.isEmpty) return;

    final amountCtrl = TextEditingController(
        text: customer.totalOutstanding.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime paymentDate = DateTime.now();
    String paymentMode = 'CASH';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Bulk Repayment (Settle All)'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      customer.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        'Total Outstanding: ${_money(customer.totalOutstanding)}\nAdvance Balance: ${_money(customer.totalAdvance)}'),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Repayment Amount',
                      hintText: 'Enter amount to settle',
                    ),
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
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  // Sort bills by date ascending to target the oldest bill first
                  final sortedBills = List<CreditBill>.from(bills)
                    ..sort((a, b) => a.billDate.compareTo(b.billDate));
                  final oldestBill = sortedBills.first;

                  await ctrl.saveRepayment(
                    saleId: oldestBill.saleId,
                    paymentDate: paymentDate,
                    amount: amount,
                    paymentMode: paymentMode,
                    referenceNo: refCtrl.text.trim(),
                    note: noteCtrl.text.trim().isNotEmpty 
                        ? noteCtrl.text.trim() 
                        : 'Bulk repayment adjusted across bills',
                    adjustExtra: true,
                  );

                  if (!mounted) return;
                  Navigator.pop(context);
                  await ctrl.loadCreditReport(
                      fromDate: fromDate,
                      toDate: toDate,
                      customer: creditSearchCtrl.text);
                },
                child: const Text('Save Repayment'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ignore: unused_element
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

  Map<String, double> _parseAdvanceBreakdown(AdvanceEntry advance) {
    final note = advance.note;
    final regex = RegExp(r'\(Refunded Rs\.\s*([0-9]+(?:\.[0-9]+)?)\)', caseSensitive: false);
    double totalRefunded = 0.0;
    final matches = regex.allMatches(note);
    for (final match in matches) {
      final amountStr = match.group(1);
      if (amountStr != null) {
        totalRefunded += double.tryParse(amountStr) ?? 0.0;
      }
    }
    
    final totalUsed = advance.originalAmount - advance.availableAmount;
    double totalConsumed = totalUsed - totalRefunded;
    if (totalConsumed < 0) totalConsumed = 0.0;

    return {
      'available': advance.availableAmount,
      'refunded': totalRefunded,
      'consumed': totalConsumed,
    };
  }

  String _cleanAdvanceNote(String note) {
    final regex = RegExp(r'\(Refunded Rs\.\s*[0-9]+(?:\.[0-9]+)?\)', caseSensitive: false);
    return note.replaceAll(regex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _navigateToLedgerForAdvance(CreditCustomerReport customer, AdvanceEntry advance) {
    setState(() {
      _tabController.index = 1;
      ledgerSearchCtrl.text = customer.customerName.isNotEmpty 
          ? customer.customerName 
          : customer.customerPhone;
      fromDate = advance.advanceDate;
      toDate = DateTime.now();
      fromCtrl.text = _fmtDate(fromDate);
      toCtrl.text = _fmtDate(toDate);
      ledgerType = '';
      ledgerPaymentMethod = '';
    });
    _loadCurrentTab();
  }

  Future<void> _showRefundAdvanceDialog(CreditCustomerReport customer) async {
    final nonSubAdvance = customer.advances.where((e) {
      if (e.availableAmount <= 0.009) return false;
      final isSubMode = e.paymentMode.toUpperCase() == 'SUBSCRIPTION';
      final isSubRef = e.referenceNo.toUpperCase().contains('SUBSCRIPTION');
      final isSubNote = e.note.toLowerCase().contains('subscription');
      return !(isSubMode || isSubRef || isSubNote);
    }).fold<double>(0, (sum, e) => sum + e.availableAmount);

    final amountCtrl = TextEditingController(text: nonSubAdvance.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Refund of customer advance');
    String paymentMode = 'CASH';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Refund Customer Advance'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(customer.customerName),
                    subtitle: Text(
                      'Available Non-Subscription Advance: ${_money(nonSubAdvance)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Refund Amount',
                      prefixText: 'Rs. ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    items: const ['CASH', 'CARD', 'UPI', 'BANK']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => paymentMode = value ?? 'CASH'),
                    decoration: const InputDecoration(labelText: 'Refund Method / Payment Mode'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(labelText: 'Reference No (Optional)'),
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
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                onPressed: () async {
                  final refundAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (refundAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid refund amount')),
                    );
                    return;
                  }
                  if (refundAmount > nonSubAdvance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Refund cannot exceed available non-subscription advance of ${_money(nonSubAdvance)}')),
                    );
                    return;
                  }

                  // Distribute the refund amount across non-subscription advances
                  final advancesToRefund = customer.advances.where((e) {
                    if (e.availableAmount <= 0.009) return false; // Ignore fully refunded leftovers
                    final isSubMode = e.paymentMode.toUpperCase() == 'SUBSCRIPTION';
                    final isSubRef = e.referenceNo.toUpperCase().contains('SUBSCRIPTION');
                    final isSubNote = e.note.toLowerCase().contains('subscription');
                    return !(isSubMode || isSubRef || isSubNote);
                  }).toList();

                  // Sort by ID to consume oldest first
                  advancesToRefund.sort((a, b) => a.id.compareTo(b.id));

                  double remainingRefund = refundAmount;

                  try {
                    for (final adv in advancesToRefund) {
                      final currentAvailable = adv.availableAmount;
                      if (currentAvailable <= 0) continue;

                      final deduct = currentAvailable < remainingRefund ? currentAvailable : remainingRefund;

                      // Make a POST call to the new refund endpoint on the backend
                      await ApiClient.post(
                        '${ApiEndpoints.financeAdvances}/${adv.id}/refund',
                        {
                          'amount': deduct,
                          'payment_mode': paymentMode,
                          'reference_no': refCtrl.text.trim(),
                          'note': noteCtrl.text.trim(),
                        },
                      );

                      remainingRefund -= deduct;
                      if (remainingRefund <= 0.009) break;
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to process refund: $e')),
                      );
                    }
                    return;
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  
                  await ctrl.loadCreditReport(
                    fromDate: fromDate,
                    toDate: toDate,
                    customer: creditSearchCtrl.text,
                  );
                },
                child: const Text('Confirm Refund'),
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
        ['Customer Name', 'Phone', 'Address', 'Bill', 'Date', 'Amount', 'Outstanding', 'Status'],
        style: headerStyle,
      );
      for (final customer in ctrl.creditCustomers) {
        for (final bill in customer.bills) {
          writeRow([
            customer.customerName,
            customer.customerPhone,
            customer.customerAddress,
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
        '',
        '',
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
        'Customer Name',
        'Phone',
        'Address',
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
            customer.customerPhone,
            customer.customerAddress,
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
        '',
        '',
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

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    List<PdfKpiItem>? kpis;
    if (_tabController.index == 0) {
      kpis = [
        PdfKpiItem(label: 'Total Credit Bills', value: '${ctrl.totalCreditBills}', color: PdfColor.fromHex('#1E40AF')),
        PdfKpiItem(label: 'Total Outstanding', value: currency.format(ctrl.totalOutstanding), color: PdfColor.fromHex('#DC2626')),
      ];
    } else if (_tabController.index == 6) {
      kpis = [
        PdfKpiItem(label: 'Total Deliveries', value: '${ctrl.deliveries.length}', color: PdfColor.fromHex('#1E40AF')),
        PdfKpiItem(label: 'Delivery Amount', value: currency.format(ctrl.deliveryTotal), color: PdfColor.fromHex('#166534')),
        PdfKpiItem(label: 'Delivery Outstanding', value: currency.format(ctrl.deliveryOutstanding), color: PdfColor.fromHex('#DC2626')),
      ];
    }

    await PdfReportBuilder.generateAndPrintReport(
      title: titles[_tabController.index],
      subtitle: 'From ${_fmtDate(fromDate)} To ${_fmtDate(toDate)}',
      headers: headers,
      data: rows,
      kpis: kpis,
      pdfFileName: 'Cash_Ledger_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
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
              label: const Text('Add Expense'))
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
              if (_tabController.index != 0) _filterCard(),
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

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
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
                  const ['', 'CASH', 'CARD', 'UPI', 'BANK', 'CREDIT', 'SUBSCRIPTION'],
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
        ),
          ),
        );
      },
    );
  }

  Widget _creditTab() {
    final customers = ctrl.creditCustomers.where((customer) {
      if (_showOutstandingOnly && customer.totalOutstanding <= 0.009) {
        return false;
      }
      return customer.totalAdvance > 0.009 || customer.totalOutstanding > 0.009;
    }).toList();



    Widget miniSummaryText(String label, String value, {bool isHighlight = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isHighlight ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isHighlight ? Colors.red.shade100 : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isHighlight ? Colors.red.shade700 : Colors.black87)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // KPIs Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 550 ? 3 : (constraints.maxWidth > 350 ? 2 : 1);
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cols == 3 ? 650 : (cols == 2 ? 440 : 320),
                      ),
                      child: GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 3 ? 2.6 : (cols == 2 ? 2.4 : 3.2),
                        children: [
                          _buildKpiCard(
                            title: 'Total Outstanding',
                            value: _money(ctrl.totalOutstanding),
                            icon: Icons.money_off_rounded,
                            color: const Color(0xFFEF4444),
                          ),
                          _buildKpiCard(
                            title: 'Total Advance',
                            value: _money(ctrl.totalAdvance),
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF16A34A),
                          ),
                          _buildKpiCard(
                            title: 'Net Outstanding',
                            value: _money(ctrl.totalOutstanding - ctrl.totalAdvance),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Search Bar Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: creditSearchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search customer name or phone number...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: creditSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      creditSearchCtrl.clear();
                                      _loadCurrentTab();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _loadCurrentTab(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _loadCurrentTab,
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Search'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Customer List Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Customer Credit Accounts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '(${customers.length} Customers)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('Hide Paid Customers'),
                        selected: _showOutstandingOnly,
                        selectedColor: const Color(0xFFEFF6FF),
                        checkmarkColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: _showOutstandingOnly ? const Color(0xFF2563EB) : Colors.grey.shade700,
                          fontWeight: _showOutstandingOnly ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _showOutstandingOnly = val;
                          });
                        },
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreditAnalysisScreen(),
                            ),
                          ).then((_) {
                            _loadCurrentTab();
                          });
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text('Credit Analysis'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (customers.isEmpty)
                _emptyCard('No customer credit records found.')
              else
                ...customers.map((customer) {
                  final hasOutstanding = customer.totalOutstanding > 0.009;
                  final unpaidBills = customer.bills.where((b) => b.outstanding > 0.009).toList();
                  final isBillsExpanded = _expandedBillsCustomers.contains(customer.customerPhone);
                  final isAdvancesExpanded = _expandedAdvancesCustomers.contains(customer.customerPhone);

                  // Extract Initials
                  String initials = '';
                  if (customer.customerName.trim().isNotEmpty) {
                    final parts = customer.customerName.trim().split(' ');
                    if (parts.length > 1) {
                      initials = (parts[0][0] + parts[1][0]).toUpperCase();
                    } else if (parts[0].isNotEmpty) {
                      initials = parts[0][0].toUpperCase();
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Customer Row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.customerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          customer.customerPhone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (customer.customerGstin.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'GST: ${customer.customerGstin}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Balance Summary on Right
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Outstanding: ',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      Text(
                                        _money(customer.totalOutstanding),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: hasOutstanding ? const Color(0xFFEF4444) : Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Advance: ',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      Text(
                                        _money(customer.totalAdvance),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Actions Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              (() {
                                final nonSubAdvance = customer.advances.where((e) {
                                  if (e.availableAmount <= 0.009) return false;
                                  final isSubMode = e.paymentMode.toUpperCase() == 'SUBSCRIPTION';
                                  final isSubRef = e.referenceNo.toUpperCase().contains('SUBSCRIPTION');
                                  final isSubNote = e.note.toLowerCase().contains('subscription');
                                  return !(isSubMode || isSubRef || isSubNote);
                                }).fold<double>(0, (sum, e) => sum + e.availableAmount);
                                if (nonSubAdvance <= 0.009) return const SizedBox.shrink();
                                return FilledButton.icon(
                                  onPressed: () => _showRefundAdvanceDialog(customer),
                                  icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                                  label: const Text('Refund Advance'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              })(),
                              FilledButton.icon(
                                onPressed: hasOutstanding
                                    ? () => _showBulkRepaymentDialog(customer, unpaidBills)
                                    : null,
                                icon: const Icon(Icons.payment, size: 16),
                                label: const Text('Bulk Pay'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  disabledBackgroundColor: Colors.grey.shade100,
                                  disabledForegroundColor: Colors.grey.shade400,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (isBillsExpanded) {
                                      _expandedBillsCustomers.remove(customer.customerPhone);
                                    } else {
                                      _expandedBillsCustomers.add(customer.customerPhone);
                                    }
                                  });
                                },
                                icon: Icon(
                                  isBillsExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 16,
                                ),
                                label: Text('Show Bills (${unpaidBills.length})'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isBillsExpanded ? const Color(0xFF2563EB) : Colors.grey.shade700,
                                  side: BorderSide(
                                    color: isBillsExpanded ? const Color(0xFF2563EB) : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (isAdvancesExpanded) {
                                      _expandedAdvancesCustomers.remove(customer.customerPhone);
                                    } else {
                                      _expandedAdvancesCustomers.add(customer.customerPhone);
                                    }
                                  });
                                },
                                icon: Icon(
                                  isAdvancesExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 16,
                                ),
                                label: Text('Show Advances (${customer.advances.length})'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isAdvancesExpanded ? const Color(0xFF16A34A) : Colors.grey.shade700,
                                  side: BorderSide(
                                    color: isAdvancesExpanded ? const Color(0xFF16A34A) : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Bills Expanded Section
                          if (isBillsExpanded) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Outstanding Bills Ledger',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (unpaidBills.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'No outstanding bills for this customer.',
                                          style: TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ),
                                    )
                                  else
                                    ...unpaidBills.map((bill) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      bill.billNo,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${_fmtDate(bill.billDate)} - Total: ${_money(bill.amount)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                _statusChip(bill.paymentStatus),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                miniSummaryText('Initial Paid', _money(bill.initialPaid)),
                                                miniSummaryText('Repaid', _money(bill.repaymentTotal)),
                                                miniSummaryText('Total Paid', _money(bill.totalPaid)),
                                                miniSummaryText('Outstanding', _money(bill.outstanding), isHighlight: true),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () => _showRepaymentDialog(bill),
                                                  icon: const Icon(Icons.payment, size: 14),
                                                  label: const Text('Repayment', style: TextStyle(fontSize: 12)),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed: bill.outstanding > 0.009
                                                      ? () => _showWaiveOffDialog(bill)
                                                      : null,
                                                  icon: const Icon(Icons.money_off, size: 14),
                                                  label: const Text('Waive Off', style: TextStyle(fontSize: 12)),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: const Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (bill.payments.isNotEmpty) ...[
                                              const Divider(height: 16),
                                              const Text(
                                                'Repayment History',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              ...bill.payments.map((payment) {
                                                return Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF8FAFC),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.grey.shade100),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              '${_paymentModeLabel(payment.paymentMode)} - ${_money(payment.amount)}',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                            Text(
                                                              '${_fmtDate(payment.paymentDate)} - Ref: ${payment.referenceNo}',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Color(0xFF64748B),
                                                              ),
                                                            ),
                                                            if (payment.note.trim().isNotEmpty)
                                                              Text(
                                                                payment.note,
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  fontStyle: FontStyle.italic,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.blue),
                                                        onPressed: () => _showRepaymentDialog(bill, payment: payment),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],

                          // Advances Expanded Section
                          if (isAdvancesExpanded) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade50),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Advances & Credit Transactions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (customer.advances.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'No advance transactions found.',
                                          style: TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ),
                                    )
                                  else
                                    ...customer.advances.map((advance) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${advance.paymentMode} - Original: ${_money(advance.originalAmount)}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  (() {
                                                    final breakdown = _parseAdvanceBreakdown(advance);
                                                    final avail = breakdown['available']!;
                                                    final refunded = breakdown['refunded']!;
                                                    final consumed = breakdown['consumed']!;

                                                    final List<String> parts = [];
                                                    parts.add('Available: ${_money(avail)}');
                                                    if (consumed > 0.009) {
                                                      parts.add('Consumed: ${_money(consumed)}');
                                                    }
                                                    if (refunded > 0.009) {
                                                      parts.add('Refunded: ${_money(refunded)}');
                                                    }
                                                    return Text(
                                                      '${_fmtDate(advance.advanceDate)} - ${parts.join(" | ")}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    );
                                                  })(),
                                                  if (advance.referenceNo.trim().isNotEmpty)
                                                    Text(
                                                      'Ref: ${advance.referenceNo}',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                    ),
                                                  if (_cleanAdvanceNote(advance.note).isNotEmpty)
                                                    Text(
                                                      _cleanAdvanceNote(advance.note),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () => _navigateToLedgerForAdvance(customer, advance),
                                              icon: const Icon(Icons.list_alt_rounded, size: 16),
                                              label: const Text('Show Transactions', style: TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF2563EB),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
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
        final cols = constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 950
                ? 5
                : constraints.maxWidth > 700
                    ? 4
                    : constraints.maxWidth > 450
                        ? 3
                        : 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: cols >= 5
                    ? 2.3
                    : cols == 4
                        ? 2.1
                        : cols == 3
                            ? 1.9
                            : 1.7,
                children: [
                  _buildKpiCard(
                    title: 'Deposit',
                    value: _money(ctrl.depositTotal),
                    icon: Icons.account_balance_rounded,
                    color: Colors.blueGrey,
                  ),
                  _buildKpiCard(
                    title: 'Credit',
                    value: _money(_ledgerCreditGrandTotal),
                    icon: Icons.arrow_downward_rounded,
                    color: Colors.green,
                  ),
                  _buildKpiCard(
                    title: 'Debit',
                    value: _money(_ledgerDebitGrandTotal),
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.red,
                  ),
                  _buildKpiCard(
                    title: 'Outstanding',
                    value: _money(_ledgerOutstandingGrandTotal),
                    icon: Icons.warning_amber_rounded,
                    color: Colors.deepOrange,
                  ),
                  _buildKpiCard(
                    title: 'Closing',
                    value: _money(ctrl.closingBalance),
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.indigo,
                  ),
                  ...visibleLedgerMethods.map(
                    (entry) => _buildKpiCard(
                      title: entry.paymentMethod,
                      value: _plainAmount(entry.amountIn > 0 ? entry.amountIn : entry.amountOut),
                      icon: Icons.payment_rounded,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.indigo, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selected range opening deposit: ${_money(ctrl.openingBalance)}. Each day below starts with its deposit row first, then the day transactions.',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                      border: Border.all(color: Colors.grey.shade200),
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
          final isExpense = entry.transactionType.trim().toUpperCase() == 'EXPENSE' ||
              entry.referenceType.trim().toUpperCase() == 'EXPENSE';

          Widget wrapCell(Widget cell) {
            if (!isExpense) return cell;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onLedgerRowTapped(entry),
              child: cell,
            );
          }

          return TableRow(
            decoration: BoxDecoration(
              color: _ledgerRowColor(entry),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            children: [
              wrapCell(_LedgerCell(_fmtDateTime(entry.txnDate))),
              wrapCell(_LedgerCell(_ledgerTypeLabel(entry.transactionType))),
              wrapCell(_LedgerCell(entry.referenceNo.isEmpty ? '-' : entry.referenceNo)),
              wrapCell(_LedgerCell(entry.partyName.isEmpty ? '-' : entry.partyName)),
              wrapCell(_LedgerCell(entry.paymentMethod.isEmpty ? '-' : entry.paymentMethod)),
              wrapCell(_LedgerCell(_ledgerNote(entry))),
              wrapCell(_LedgerCell(
                _ledgerOutstanding(entry) <= 0 ? '-' : _money(_ledgerOutstanding(entry)),
                align: TextAlign.right,
                color: _ledgerOutstanding(entry) > 0 ? Colors.deepOrange : null,
                bold: _ledgerOutstanding(entry) > 0,
              )),
              wrapCell(_LedgerCell(
                entry.amountIn <= 0 ? '-' : _money(entry.amountIn),
                align: TextAlign.right,
                color: entry.amountIn > 0 ? Colors.green : null,
                bold: entry.amountIn > 0,
              )),
              wrapCell(_LedgerCell(
                debitAmount <= 0 ? '-' : _money(debitAmount),
                align: TextAlign.right,
                color: debitAmount > 0 ? Colors.red : null,
                bold: debitAmount > 0,
              )),
              wrapCell(_LedgerCell(
                _money(entry.balance),
                align: TextAlign.right,
                color: Colors.indigo,
                bold: true,
              )),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 450 ? 2 : 1;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cols == 2 ? 440 : 320,
                      ),
                      child: GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 2 ? 2.6 : 3.2,
                        children: [
                          _buildKpiCard(
                            title: 'Expense Total',
                            value: _money(ctrl.expenseTotal),
                            icon: Icons.wallet_rounded,
                            color: const Color(0xFFEF4444),
                          ),
                          _buildKpiCard(
                            title: 'Entries',
                            value: '${ctrl.expenses.length}',
                            icon: Icons.list_alt_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExpenseAnalyticsScreen(ctrl: ctrl),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart_outlined, size: 22),
                label: const Text(
                  'View Deep Expense Analytics & Tax Outflows',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick expense entry',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        Text(
                            'Add salary, petrol, diesel, commission, rent and keep remarks like who was paid and why.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        if (ctrl.expenseCategories.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ctrl.expenseCategories
                                .map((cat) => OutlinedButton.icon(
                                    onPressed: () =>
                                        _showExpenseDialog(initialCategory: cat.categoryName),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: Text(cat.categoryName)))
                                .toList(),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _addNewCategory,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Category First'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                      ]),
                ),
              ),
              const SizedBox(height: 12),
              ...ctrl.expenses.map((expense) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text('${expense.category} (${expense.vendorName})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${_fmtDate(expense.expenseDate)}  -  ${expense.note}\n'
                        'Method: ${expense.paymentMethod} | Status: ${expense.status}\n'
                        'Base: ${_money(expense.baseAmount)} | Tax: ${_money(expense.totalTaxAmount)} | Ded: ${_money(expense.totalDeductionAmount)}'
                      ),
                      trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(_money(expense.amount),
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                        IconButton(
                            tooltip: 'Print Receipt',
                            onPressed: () => ExpenseEntryDialog.printExpenseReceipt(expense),
                            icon: const Icon(Icons.print_outlined, color: Colors.teal)),
                        IconButton(
                            onPressed: () => _showExpenseDialog(expense: expense),
                            icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                            onPressed: () => _confirmDelete(expense.id),
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                      ]),
                    ),
                  )),
              if (ctrl.expenses.isEmpty)
                _emptyCard('No expenses found for the selected range.'),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _incomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 450 ? 2 : 1;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cols == 2 ? 440 : 320,
                      ),
                      child: GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 2 ? 2.6 : 3.2,
                        children: [
                          _buildKpiCard(
                            title: 'Income Total',
                            value: _money(ctrl.incomeTotal),
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF16A34A),
                          ),
                          _buildKpiCard(
                            title: 'Entries',
                            value: '${ctrl.incomes.length}',
                            icon: Icons.list_alt_rounded,
                            color: const Color(0xFF0D9488),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Other income',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use this for income like box sale, loading charges, rent recovery, or any extra cash received. It will be adjusted in the ledger automatically.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...ctrl.incomes.map(
                (income) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            fontSize: 15,
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
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withdrawalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 450 ? 2 : 1;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cols == 2 ? 440 : 320,
                      ),
                      child: GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 2 ? 2.6 : 3.2,
                        children: [
                          _buildKpiCard(
                            title: 'Withdrawal Total',
                            value: _money(ctrl.withdrawalTotal),
                            icon: Icons.money_off_rounded,
                            color: const Color(0xFFEF4444),
                          ),
                          _buildKpiCard(
                            title: 'Entries',
                            value: '${ctrl.withdrawals.length}',
                            icon: Icons.list_alt_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash withdrawal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use this tab for owner withdrawal, bank deposit, petty cash movement, or other cash taken out. It will be posted to ledger debit automatically.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...ctrl.withdrawals.map(
                (withdrawal) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            fontSize: 15,
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
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _openingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 450 ? 2 : 1;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cols == 2 ? 440 : 320,
                      ),
                      child: GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 2 ? 2.6 : 3.2,
                        children: [
                          _buildKpiCard(
                            title: 'Carry Forward',
                            value: _money(ctrl.carriedOpeningBalance),
                            icon: Icons.double_arrow_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                          _buildKpiCard(
                            title: 'Saved Days',
                            value: '${ctrl.openings.length}',
                            icon: Icons.date_range_rounded,
                            color: const Color(0xFF0D9488),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: const Text(
                              'Opening deposit is carried forward automatically at local day-end. If you do not save a new deposit for the next day, the previous closing balance will be used.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
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
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(_fmtDate(item.balanceDate),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(item.note),
                      trailing: Text(_money(item.openingBalance),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))))),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deliveryTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final leftWidth = isWide ? 320.0 : constraints.maxWidth;
        final rightWidth = isWide ? 220.0 : constraints.maxWidth;
        final cols = constraints.maxWidth > 550 ? 3 : (constraints.maxWidth > 350 ? 2 : 1);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cols == 3 ? 650 : (cols == 2 ? 440 : 320),
                ),
                child: GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: cols == 3 ? 2.6 : (cols == 2 ? 2.4 : 3.2),
                  children: [
                    _buildKpiCard(
                      title: 'Sales',
                      value: '${ctrl.deliveries.length}',
                      icon: Icons.point_of_sale_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                    _buildKpiCard(
                      title: 'Amount',
                      value: _money(ctrl.deliveryTotal),
                      icon: Icons.currency_rupee_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                    _buildKpiCard(
                      title: 'Outstanding',
                      value: _money(ctrl.deliveryOutstanding),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...ctrl.deliveries.map(
              (item) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 550 ? 3 : (constraints.maxWidth > 350 ? 2 : 1);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cols == 3 ? 650 : (cols == 2 ? 440 : 320),
                ),
                child: GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: cols == 3 ? 2.6 : (cols == 2 ? 2.4 : 3.2),
                  children: [
                    _buildKpiCard(
                      title: 'Expired',
                      value: '${ctrl.expiredCount}',
                      icon: Icons.lock_clock,
                      color: const Color(0xFFEF4444),
                    ),
                    _buildKpiCard(
                      title: 'Near Expiry',
                      value: '${ctrl.nearExpiryCount}',
                      icon: Icons.access_time_filled,
                      color: Colors.amber.shade800,
                    ),
                    _buildKpiCard(
                      title: 'Items',
                      value: '${ctrl.expiryItems.length}',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...ctrl.expiryItems.map((item) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
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
      },
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
      case 'SALE_SCHEME_FREE_EXPENSE':
      case 'SUBSCRIPTION_SCHEME_FREE_EXPENSE':
      case 'SALE_SUBSCRIPTION_FREE_EXPENSE':
      case 'SALE_SUBSCRIPTION_ADJUSTMENT':
        return 'Advance Adjustment';
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

class ExpenseEntryDialog extends StatefulWidget {
  final ExpenseEntryReport? expense;
  final FinanceHubController ctrl;
  final VoidCallback onSaved;
  final String initialCategory;

  const ExpenseEntryDialog({
    super.key,
    this.expense,
    required this.ctrl,
    required this.onSaved,
    this.initialCategory = '',
  });

  static Future<void> printExpenseReceipt(ExpenseEntryReport expense) async {
    final propertyCtrl = PropertyInfoController();
    await propertyCtrl.load();
    final property = propertyCtrl.data;
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);
    
    // Parse manual vendor details
    String displayVendor = expense.vendorName;
    String displayNote = expense.note;
    if (expense.vendorName == 'Direct Cash' && expense.note.startsWith('Paid To: ')) {
      final parts = expense.note.split(' | ');
      displayVendor = parts.first.substring(9);
      displayNote = parts.length > 1 ? parts.sublist(1).join(' | ') : '';
    }
    
    await Printing.layoutPdf(
      name: 'Expense_Receipt_${expense.id.length >= 8 ? expense.id.substring(0, 8) : expense.id}',
      onLayout: (format) async {
        final pdf = pw.Document();
        final mono = pw.Font.courier();
        final bold = pw.Font.helveticaBold();
        final regular = pw.Font.helvetica();
        
        pw.Widget divider() => pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 5),
              width: double.infinity,
              height: 1,
              color: PdfColors.black,
            );

        pw.Widget kvLine(String label, String value, {bool boldFont = false}) {
          final style = pw.TextStyle(
            font: mono,
            fontSize: 9,
            fontWeight: boldFont ? pw.FontWeight.bold : pw.FontWeight.normal,
          );
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: style),
              pw.Text(value, style: style),
            ],
          );
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: const PdfPageFormat(
              72 * PdfPageFormat.mm,
              220 * PdfPageFormat.mm,
              marginLeft: 2 * PdfPageFormat.mm,
              marginRight: 2 * PdfPageFormat.mm,
              marginTop: 3 * PdfPageFormat.mm,
              marginBottom: 3 * PdfPageFormat.mm,
            ),
            build: (context) => [
              PosInvoicePrinter.buildStandardThermalHeader(
                property: property,
                logo: logo,
                fontRegular: regular,
                fontBold: bold,
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'EXPENSE RECEIPT',
                  style: pw.TextStyle(
                    font: mono,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              divider(),
              kvLine('Receipt No:', expense.invoiceRefNo.isNotEmpty ? expense.invoiceRefNo : 'EXP-${expense.id.length >= 8 ? expense.id.substring(0, 8).toUpperCase() : expense.id.toUpperCase()}'),
              kvLine('Date:', DateFormat('dd-MMM-yyyy').format(expense.expenseDate)),
              kvLine('Category:', expense.category),
              kvLine('Vendor:', displayVendor.isNotEmpty ? displayVendor : '-'),
              kvLine('Method:', expense.paymentMethod),
              kvLine('Status:', expense.status),
              if (displayNote.isNotEmpty) ...[
                divider(),
                pw.Text('Notes: $displayNote', style: pw.TextStyle(font: mono, fontSize: 8.5)),
              ],
              divider(),
              kvLine('Base Amount:', 'Rs. ${expense.baseAmount.toStringAsFixed(2)}'),
              if (expense.taxes.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('TAX DETAILS:', style: pw.TextStyle(font: mono, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ...expense.taxes.map((t) => kvLine('  ${t.taxName} (${t.taxPercentage}%):', 'Rs. ${t.taxAmount.toStringAsFixed(2)}')),
              ],
              if (expense.deductions.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('DEDUCTION DETAILS:', style: pw.TextStyle(font: mono, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ...expense.deductions.map((d) => kvLine('  ${d.deductionType} (${d.deductionPercentage}%):', '-Rs. ${d.deductionAmount.toStringAsFixed(2)}')),
              ],
              divider(),
              kvLine('Net Payable:', 'Rs. ${expense.amount.toStringAsFixed(2)}', boldFont: true),
              divider(),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Signature / Authorized Sign',
                  style: pw.TextStyle(font: mono, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Thank you!',
                  style: pw.TextStyle(font: mono, fontSize: 8),
                ),
              ),
            ],
          ),
        );
        return pdf.save();
      },
    );
  }

  @override
  State<ExpenseEntryDialog> createState() => _ExpenseEntryDialogState();
}

class TaxRowState {
  String taxName;
  double taxPercentage;
  bool isCustom;
  final TextEditingController nameCtrl;
  final TextEditingController percentCtrl;

  TaxRowState({
    required this.taxName,
    required this.taxPercentage,
    this.isCustom = false,
  })  : nameCtrl = TextEditingController(text: taxName),
        percentCtrl = TextEditingController(text: taxPercentage.toStringAsFixed(2));
}

class DeductionRowState {
  String deductionType;
  double deductionPercentage;
  final TextEditingController percentCtrl;

  DeductionRowState({
    required this.deductionType,
    required this.deductionPercentage,
  })  : percentCtrl = TextEditingController(text: deductionPercentage.toStringAsFixed(2));
}

class _ExpenseEntryDialogState extends State<ExpenseEntryDialog> {
  final amountCtrl = TextEditingController();
  final invoiceRefNoCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final manualVendorCtrl = TextEditingController();
 
  DateTime paymentDate = DateTime.now();
  String? selectedCategoryId;
  int? selectedVendorId;
  String vendorType = 'Supplier'; // 'Supplier', 'Staff', 'Other'
  List<AppUser> staffList = [];
  AppUser? selectedStaffUser;
  String paymentMethod = 'CASH';
  List<String> paymentMethodsList = ['CASH', 'BANK', 'UPI', 'CARD', 'CREDIT'];
  String status = 'Paid';
  bool isTaxInclusive = false;
 
  List<Supplier> suppliers = [];
  List<TaxRowState> taxRows = [];
  List<DeductionRowState> deductionRows = [];
  bool loadingData = true;
 
  double baseAmount = 0.0;
  double totalTaxAmount = 0.0;
  double totalDeductionAmount = 0.0;
  double netPayableAmount = 0.0;
 
  @override
  void initState() {
    super.initState();
    _initData();
    amountCtrl.addListener(_recalculate);
  }
 
  @override
  void dispose() {
    amountCtrl.dispose();
    invoiceRefNoCtrl.dispose();
    noteCtrl.dispose();
    manualVendorCtrl.dispose();
    for (var r in taxRows) {
      r.nameCtrl.dispose();
      r.percentCtrl.dispose();
    }
    for (var r in deductionRows) {
      r.percentCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      await widget.ctrl.loadExpenseCategories();
      await widget.ctrl.loadTaxesMaster();
      await widget.ctrl.loadCustomPaymentMethods();
      if (widget.ctrl.customPaymentMethods.isNotEmpty) {
        paymentMethodsList = List<String>.from(widget.ctrl.customPaymentMethods);
      }
      final supplierRes = await ApiClient.get('/api/inventory/suppliers');
      suppliers = (supplierRes['data'] as List? ?? [])
          .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      try {
        final userRes = await ApiClient.get(ApiEndpoints.users);
        staffList = (userRes['data'] as List? ?? [])
            .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading staff list: $e');
      }

      if (widget.expense != null) {
        final exp = widget.expense!;
        amountCtrl.text = exp.isTaxInclusive 
            ? (exp.baseAmount + exp.totalTaxAmount).toStringAsFixed(2)
            : exp.baseAmount.toStringAsFixed(2);
        invoiceRefNoCtrl.text = exp.invoiceRefNo;
        if (exp.vendorId != null) {
          vendorType = 'Supplier';
          selectedVendorId = exp.vendorId;
          noteCtrl.text = exp.note;
        } else if (exp.note.startsWith('Paid To Staff: ')) {
          vendorType = 'Staff';
          final parts = exp.note.split(' | ');
          final staffName = parts.first.substring(15);
          final matchIdx = staffList.indexWhere((u) => u.fullName == staffName || u.username == staffName);
          if (matchIdx != -1) {
            selectedStaffUser = staffList[matchIdx];
          } else {
            manualVendorCtrl.text = staffName;
          }
          noteCtrl.text = parts.length > 1 ? parts.sublist(1).join(' | ') : '';
        } else if (exp.note.startsWith('Paid To: ')) {
          vendorType = 'Other';
          final parts = exp.note.split(' | ');
          manualVendorCtrl.text = parts.first.substring(9);
          noteCtrl.text = parts.length > 1 ? parts.sublist(1).join(' | ') : '';
        } else {
          vendorType = 'Supplier';
          noteCtrl.text = exp.note;
        }
        paymentDate = exp.expenseDate;
        selectedCategoryId = exp.categoryId;
        paymentMethod = exp.paymentMethod;
        status = exp.status;
        isTaxInclusive = exp.isTaxInclusive;

        if (!paymentMethodsList.contains(paymentMethod)) {
          paymentMethodsList.add(paymentMethod);
        }

        taxRows = exp.taxes.map((t) {
          final isStd = widget.ctrl.taxesMasterList.any((std) => std.taxName == t.taxName);
          return TaxRowState(
            taxName: t.taxName,
            taxPercentage: t.taxPercentage,
            isCustom: !isStd,
          );
        }).toList();

        deductionRows = exp.deductions.map((d) {
          return DeductionRowState(
            deductionType: d.deductionType,
            deductionPercentage: d.deductionPercentage,
          );
        }).toList();
      } else {
        if (widget.ctrl.expenseCategories.isNotEmpty) {
          if (widget.initialCategory.isNotEmpty) {
            final idx = widget.ctrl.expenseCategories.indexWhere(
              (c) => c.categoryName.trim().toLowerCase() == widget.initialCategory.trim().toLowerCase()
            );
            selectedCategoryId = idx != -1 ? widget.ctrl.expenseCategories[idx].id : widget.ctrl.expenseCategories.first.id;
          } else {
            selectedCategoryId = widget.ctrl.expenseCategories.first.id;
          }
        }
        if (paymentMethodsList.isNotEmpty && !paymentMethodsList.contains(paymentMethod)) {
          paymentMethod = paymentMethodsList.first;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => loadingData = false);
          _recalculate();
        }
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => loadingData = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load form dependencies: $e')),
          );
        }
      });
    }
  }

  void _recalculate() {
    final amount = double.tryParse(amountCtrl.text) ?? 0.0;
    final totalTaxPercent = taxRows.fold<double>(0.0, (sum, row) => sum + (double.tryParse(row.percentCtrl.text) ?? 0.0));

    if (isTaxInclusive) {
      baseAmount = amount / (1.0 + (totalTaxPercent / 100.0));
      totalTaxAmount = amount - baseAmount;
    } else {
      baseAmount = amount;
      totalTaxAmount = baseAmount * (totalTaxPercent / 100.0);
    }

    baseAmount = double.parse(baseAmount.toStringAsFixed(2));
    totalTaxAmount = double.parse(totalTaxAmount.toStringAsFixed(2));

    totalDeductionAmount = 0.0;
    for (var row in deductionRows) {
      final percent = double.tryParse(row.percentCtrl.text) ?? 0.0;
      final dedAmt = baseAmount * (percent / 100.0);
      totalDeductionAmount += double.parse(dedAmt.toStringAsFixed(2));
    }

    totalDeductionAmount = double.parse(totalDeductionAmount.toStringAsFixed(2));

    final grossAmount = isTaxInclusive ? amount : (baseAmount + totalTaxAmount);
    netPayableAmount = double.parse((grossAmount - totalDeductionAmount).toStringAsFixed(2));

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addNewCategory() async {
    final nameCtrl = TextEditingController();
    final newCat = await showDialog<ExpenseCategoryModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Office Supplies, Shipping...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                final cat = await widget.ctrl.saveExpenseCategory(name);
                Navigator.pop(context, cat);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save category: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCat != null) {
      setState(() {
        selectedCategoryId = newCat.id;
      });
      _recalculate();
    }
  }

  void _addTaxRow() {
    setState(() {
      final defaultTax = widget.ctrl.taxesMasterList.isNotEmpty 
          ? widget.ctrl.taxesMasterList.first 
          : null;
      final newRow = TaxRowState(
        taxName: defaultTax?.taxName ?? 'CGST',
        taxPercentage: defaultTax?.defaultRate ?? 9.0,
        isCustom: defaultTax == null,
      );
      newRow.percentCtrl.addListener(_recalculate);
      newRow.nameCtrl.addListener(_recalculate);
      taxRows.add(newRow);
    });
    _recalculate();
  }

  void _addDeductionRow() {
    setState(() {
      final newRow = DeductionRowState(
        deductionType: 'TDS',
        deductionPercentage: 2.0,
      );
      newRow.percentCtrl.addListener(_recalculate);
      deductionRows.add(newRow);
    });
    _recalculate();
  }

  Future<void> _save() async {
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a category.')),
      );
      return;
    }
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0.')),
      );
      return;
    }

    try {
      final taxesPayload = taxRows.map((r) => {
        'tax_name': r.isCustom ? r.nameCtrl.text.trim() : r.taxName,
        'tax_percentage': double.tryParse(r.percentCtrl.text.trim()) ?? 0.0,
      }).toList();

      final deductionsPayload = deductionRows.map((r) => {
        'deduction_type': r.deductionType,
        'deduction_percentage': double.tryParse(r.percentCtrl.text.trim()) ?? 0.0,
      }).toList();

      String finalNote = noteCtrl.text.trim();
      int? finalVendorId = selectedVendorId;
      if (vendorType == 'Staff') {
        finalVendorId = null;
        final staffName = selectedStaffUser?.fullName ?? manualVendorCtrl.text.trim();
        if (staffName.isNotEmpty) {
          finalNote = 'Paid To Staff: $staffName${finalNote.isNotEmpty ? ' | $finalNote' : ''}';
        }
      } else if (vendorType == 'Other') {
        finalVendorId = null;
        if (manualVendorCtrl.text.trim().isNotEmpty) {
          finalNote = 'Paid To: ${manualVendorCtrl.text.trim()}${finalNote.isNotEmpty ? ' | $finalNote' : ''}';
        }
      } else {
        // Supplier case
      }

      final savedExpense = await widget.ctrl.saveExpense(
        expenseId: widget.expense?.id,
        paymentDate: paymentDate,
        categoryId: selectedCategoryId!,
        amount: amount,
        vendorId: finalVendorId,
        invoiceRefNo: invoiceRefNoCtrl.text.trim().isEmpty ? null : invoiceRefNoCtrl.text.trim(),
        paymentMethod: paymentMethod,
        isTaxInclusive: isTaxInclusive,
        note: finalNote,
        status: status,
        taxes: taxesPayload,
        deductions: deductionsPayload,
      );

      widget.onSaved();
      Navigator.pop(context);

      await ExpenseEntryDialog.printExpenseReceipt(savedExpense);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    final initialVendor = selectedVendorId != null
        ? suppliers.firstWhere((s) => s.id == selectedVendorId, orElse: () => suppliers.first)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.expense == null ? 'Add Expense' : 'Edit Expense',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // CARD 1: Vendor & Reference Info
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Vendor & Billing Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Supplier'),
                                          selected: vendorType == 'Supplier',
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                vendorType = 'Supplier';
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Staff'),
                                          selected: vendorType == 'Staff',
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                vendorType = 'Staff';
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Other'),
                                          selected: vendorType == 'Other',
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                vendorType = 'Other';
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (vendorType == 'Supplier')
                                      Autocomplete<Supplier>(
                                        displayStringForOption: (Supplier option) => option.supplierName,
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return suppliers;
                                          }
                                          return suppliers.where((Supplier option) {
                                            return option.supplierName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                                option.phone.contains(textEditingValue.text);
                                          });
                                        },
                                        onSelected: (Supplier selection) {
                                          setState(() {
                                            selectedVendorId = selection.id;
                                          });
                                        },
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          if (initialVendor != null && textEditingController.text.isEmpty) {
                                            textEditingController.text = initialVendor.supplierName;
                                          }
                                          return TextField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            decoration: const InputDecoration(
                                              labelText: 'Vendor / Supplier',
                                              hintText: 'Search vendor...',
                                              prefixIcon: Icon(Icons.business_outlined),
                                            ),
                                          );
                                        },
                                      )
                                    else if (vendorType == 'Staff')
                                      Autocomplete<AppUser>(
                                        displayStringForOption: (AppUser option) => option.fullName,
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return staffList;
                                          }
                                          return staffList.where((AppUser option) {
                                            return option.fullName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                                option.username.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                          });
                                        },
                                        onSelected: (AppUser selection) {
                                          setState(() {
                                            selectedStaffUser = selection;
                                          });
                                        },
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          if (selectedStaffUser != null && textEditingController.text.isEmpty) {
                                            textEditingController.text = selectedStaffUser!.fullName;
                                          }
                                          return TextField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            decoration: const InputDecoration(
                                              labelText: 'Select Staff Member',
                                              hintText: 'Search staff user...',
                                              prefixIcon: Icon(Icons.badge_outlined),
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      TextField(
                                        controller: manualVendorCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Custom Paid To Name',
                                          hintText: 'Type custom name manually (e.g. host name, direct utility)...',
                                          prefixIcon: Icon(Icons.person_outline),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: invoiceRefNoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Invoice / Ref No',
                                        prefixIcon: Icon(Icons.description_outlined),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // CARD 2: Expense Category & Amount Details
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Expense Category & Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: selectedCategoryId,
                                            decoration: const InputDecoration(
                                              labelText: 'Expense Category',
                                              prefixIcon: Icon(Icons.category_outlined),
                                            ),
                                            items: widget.ctrl.expenseCategories.map((cat) {
                                              return DropdownMenuItem(
                                                value: cat.id,
                                                child: Text(cat.categoryName),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setState(() => selectedCategoryId = val);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          onPressed: _addNewCategory,
                                          icon: const Icon(Icons.add),
                                          tooltip: 'Add New Category',
                                        ),
                                      ],
                                    ),
                                    if (widget.ctrl.expenseCategories.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Text('Quick Select Category:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: widget.ctrl.expenseCategories.take(8).map((cat) {
                                          final isSelected = selectedCategoryId == cat.id;
                                          return ChoiceChip(
                                            label: Text(cat.categoryName, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11)),
                                            selected: isSelected,
                                            selectedColor: Theme.of(context).colorScheme.primary,
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                                            onSelected: (selected) {
                                              if (selected) {
                                                setState(() {
                                                  selectedCategoryId = cat.id;
                                                });
                                                _recalculate();
                                              }
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: amountCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'Amount (₹)',
                                              hintText: 'Enter amount',
                                              prefixIcon: Icon(Icons.currency_rupee),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: CheckboxListTile(
                                            title: const Text('Inclusive of Tax', style: TextStyle(fontSize: 12)),
                                            value: isTaxInclusive,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            onChanged: (val) {
                                              setState(() {
                                                isTaxInclusive = val ?? false;
                                              });
                                              _recalculate();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // CARD 3: Tax Rows & Deductions
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Tax Multi-layers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                        TextButton.icon(
                                          onPressed: _addTaxRow,
                                          icon: const Icon(Icons.add_circle_outline, size: 16),
                                          label: const Text('Add Tax', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    ...taxRows.map((row) {
                                      final index = taxRows.indexOf(row);
                                      return Card(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: row.isCustom
                                                    ? TextField(
                                                        controller: row.nameCtrl,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Tax Name',
                                                          isDense: true,
                                                        ),
                                                      )
                                                    : DropdownButtonFormField<String>(
                                                        value: row.taxName,
                                                        decoration: const InputDecoration(isDense: true),
                                                        items: [
                                                          ...widget.ctrl.taxesMasterList.map((t) => DropdownMenuItem(value: t.taxName, child: Text(t.taxName))),
                                                          const DropdownMenuItem(value: 'CUSTOM', child: Text('Custom...')),
                                                        ],
                                                        onChanged: (val) {
                                                          if (val == 'CUSTOM') {
                                                            setState(() {
                                                              row.isCustom = true;
                                                            });
                                                          } else if (val != null) {
                                                            final taxObj = widget.ctrl.taxesMasterList.firstWhere((t) => t.taxName == val);
                                                            setState(() {
                                                              row.taxName = val;
                                                              row.percentCtrl.text = taxObj.defaultRate.toStringAsFixed(2);
                                                            });
                                                            _recalculate();
                                                          }
                                                        },
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: row.percentCtrl,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Rate %',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '₹${((isTaxInclusive ? baseAmount : baseAmount) * (double.tryParse(row.percentCtrl.text) ?? 0) / 100).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    taxRows.removeAt(index);
                                                  });
                                                  _recalculate();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Deductions (TDS, TCS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                        TextButton.icon(
                                          onPressed: _addDeductionRow,
                                          icon: const Icon(Icons.add_circle_outline, size: 16),
                                          label: const Text('Add Deduction', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    ...deductionRows.map((row) {
                                      final index = deductionRows.indexOf(row);
                                      return Card(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: DropdownButtonFormField<String>(
                                                  value: row.deductionType,
                                                  decoration: const InputDecoration(isDense: true),
                                                  items: const [
                                                    DropdownMenuItem(value: 'TDS', child: Text('TDS')),
                                                    DropdownMenuItem(value: 'TCS', child: Text('TCS')),
                                                    DropdownMenuItem(value: 'Penalty', child: Text('Penalty')),
                                                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        row.deductionType = val;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: row.percentCtrl,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Rate %',
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '-₹${(baseAmount * (double.tryParse(row.percentCtrl.text) ?? 0) / 100).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    deductionRows.removeAt(index);
                                                  });
                                                  _recalculate();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),

                            // CARD 4: Payment Method, Status, Date & Remarks
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Payment & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: paymentMethod,
                                            decoration: const InputDecoration(labelText: 'Payment Method'),
                                            items: paymentMethodsList.map((m) {
                                              return DropdownMenuItem(value: m, child: Text(m));
                                            }).toList(),
                                            onChanged: (val) => setState(() => paymentMethod = val ?? 'CASH'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: status,
                                            decoration: const InputDecoration(labelText: 'Status'),
                                            items: const [
                                              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                                              DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                                              DropdownMenuItem(value: 'Void', child: Text('Void')),
                                            ],
                                            onChanged: (val) => setState(() => status = val ?? 'Paid'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Payment Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      subtitle: Text(DateFormat('dd-MMM-yyyy').format(paymentDate)),
                                      trailing: const Icon(Icons.calendar_today, size: 18),
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: paymentDate,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => paymentDate = picked);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: noteCtrl,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Expense Note / Remarks',
                                        hintText: 'Enter any additional details...',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Financial Summary',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            _summaryRow('Base Amount', '₹${baseAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 8),
                            _summaryRow('Total Taxes (+)', '₹${totalTaxAmount.toStringAsFixed(2)}', isBold: true),
                            const SizedBox(height: 4),
                            ...taxRows.map((tr) {
                              final percent = double.tryParse(tr.percentCtrl.text) ?? 0.0;
                              final rowAmt = baseAmount * (percent / 100);
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${tr.isCustom ? tr.nameCtrl.text : tr.taxName} ($percent%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text('₹${rowAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(),
                            _summaryRow('Total Deductions (-)', '₹${totalDeductionAmount.toStringAsFixed(2)}', isBold: true, color: Colors.red),
                            const SizedBox(height: 4),
                            ...deductionRows.map((dr) {
                              final percent = double.tryParse(dr.percentCtrl.text) ?? 0.0;
                              final rowAmt = baseAmount * (percent / 100);
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${dr.deductionType} ($percent%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text('-₹${rowAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 24),
                            Container(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: _summaryRow(
                                'Net Payable',
                                '₹${netPayableAmount.toStringAsFixed(2)}',
                                isBold: true,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.check),
                              label: const Text('Save Expense'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: fontSize,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }
}
