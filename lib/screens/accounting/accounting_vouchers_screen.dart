import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../controllers/accounting/accounting_voucher_controller.dart';
import '../../controllers/accounting/bank_account_controller.dart';
import '../../models/accounting/accounting_voucher_model.dart';
import '../inventory/salescreen.dart';
import '../inventory/goods_receiving_screen.dart';
import '../../core/printing/pos_invoice_printer.dart';

class AccountingVouchersScreen extends StatefulWidget {
  const AccountingVouchersScreen({super.key});

  @override
  State<AccountingVouchersScreen> createState() =>
      _AccountingVouchersScreenState();
}

class _AccountingVouchersScreenState extends State<AccountingVouchersScreen> {
  final AccountingVoucherController ctrl = AccountingVoucherController();
  final BankAccountController bankCtrl = BankAccountController();

  final FocusNode _focusNode = FocusNode();
  bool _isCreatingVoucher = false;

  @override
  void initState() {
    super.initState();
    bankCtrl.fetchBanks();
    ctrl.fetchVouchers(type: ctrl.activeType);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    ctrl.dispose();
    bankCtrl.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f4) {
        _selectType('CONTRA');
      } else if (event.logicalKey == LogicalKeyboardKey.f5) {
        _selectType('PAYMENT');
      } else if (event.logicalKey == LogicalKeyboardKey.f6) {
        _selectType('RECEIPT');
      } else if (event.logicalKey == LogicalKeyboardKey.f7) {
        _selectType('JOURNAL');
      } else if (event.logicalKey == LogicalKeyboardKey.f8) {
        _selectType('SALES');
      } else if (event.logicalKey == LogicalKeyboardKey.f9) {
        _selectType('PURCHASE');
      }
    }
  }

  void _selectType(String type) {
    setState(() {
      _isCreatingVoucher = false;
      ctrl.setActiveType(type);
    });
    ctrl.fetchVouchers(type: type);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0B5CAD);
    const tealColor = Color(0xFF0F766E);
    const bgColor = Color(0xFFF4F6F9);

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: primaryColor),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RetailSale Accounting Voucher Hub',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Standalone Double-Entry Financial Vouchers',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                await ctrl.fetchVouchers(type: null);
                if (context.mounted) {
                  _showVoucherHistoryModal(context);
                }
              },
              icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
              label: const Text(
                'Voucher History / Reprint',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tealColor.withOpacity(0.1),
                    border: Border.all(color: tealColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Shortcuts Enabled',
                    style: TextStyle(
                      color: tealColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: ctrl,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // F-Key Shortcut Toolbar
                  _buildShortcutToolbar(primaryColor, tealColor),
                  const SizedBox(height: 16),

                  // Main View Panel (Register List View for ALL Vouchers by Default)
                  Expanded(
                    child: _isCreatingVoucher
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(color: primaryColor),
                                    ),
                                    onPressed: () => setState(() => _isCreatingVoucher = false),
                                    icon: const Icon(Icons.arrow_back, size: 16),
                                    label: Text(
                                      '← Back to ${ctrl.activeType} Register & History',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            _buildVoucherMetaCard(primaryColor, tealColor),
                                            const SizedBox(height: 16),
                                            _buildLedgerBreakdownTable(primaryColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 340,
                                      child: _buildSummaryAndActionCard(primaryColor, tealColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _buildVoucherRegisterPanel(primaryColor, tealColor),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoucherRegisterPanel(Color primaryColor, Color tealColor) {
    final type = ctrl.activeType;

    final titles = {
      'CONTRA': 'Contra Register & Vouchers',
      'PAYMENT': 'Payment Register & Vouchers',
      'RECEIPT': 'Receipt Register & Vouchers',
      'JOURNAL': 'Journal Register & Vouchers',
      'SALES': 'Sales POS Register & Vouchers',
      'PURCHASE': 'Purchase GRN Register & Vouchers'
    };

    final descs = {
      'CONTRA': 'View, search, and reprint saved cash deposit, withdrawal, and bank transfer vouchers.',
      'PAYMENT': 'View, search, and reprint saved cash & bank expense payment vouchers.',
      'RECEIPT': 'View, search, and reprint saved incoming cash & bank receipt vouchers.',
      'JOURNAL': 'View, search, and reprint saved non-cash adjustment and journal vouchers.',
      'SALES': 'View, search, and reprint saved Sales POS invoice vouchers.',
      'PURCHASE': 'View, search, and reprint saved Purchase GRN vendor receive vouchers.'
    };

    final buttonLabels = {
      'CONTRA': '+ Create Contra Entry',
      'PAYMENT': '+ Create Payment Entry',
      'RECEIPT': '+ Create Receipt Entry',
      'JOURNAL': '+ Create Journal Entry',
      'SALES': '+ Open Sales Screen',
      'PURCHASE': '+ Open GRN Receiving'
    };

    final buttonColors = {
      'CONTRA': primaryColor,
      'PAYMENT': primaryColor,
      'RECEIPT': primaryColor,
      'JOURNAL': primaryColor,
      'SALES': Colors.green.shade800,
      'PURCHASE': Colors.amber.shade900
    };

    final badgeColors = {
      'CONTRA': Colors.blue.shade800,
      'PAYMENT': Colors.indigo.shade800,
      'RECEIPT': Colors.teal.shade800,
      'JOURNAL': Colors.purple.shade800,
      'SALES': Colors.green.shade800,
      'PURCHASE': Colors.amber.shade900
    };

    final title = titles[type] ?? 'Accounting Vouchers Register';
    final desc = descs[type] ?? 'View, search, and reprint saved vouchers.';
    final btnLabel = buttonLabels[type] ?? '+ Create Voucher';
    final btnColor = buttonColors[type] ?? primaryColor;
    final defaultBadge = badgeColors[type] ?? primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: btnColor,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  if (type == 'SALES') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen()));
                  } else if (type == 'PURCHASE') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GoodsReceivingScreen()));
                  } else {
                    setState(() => _isCreatingVoucher = true);
                  }
                },
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text(
                  btnLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: ctrl.loading
                ? const Center(child: CircularProgressIndicator())
                : ctrl.vouchers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No $type vouchers recorded yet.',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (type != 'SALES' && type != 'PURCHASE')
                              ElevatedButton(
                                onPressed: () => setState(() => _isCreatingVoucher = true),
                                style: ElevatedButton.styleFrom(backgroundColor: btnColor),
                                child: Text(btnLabel, style: const TextStyle(color: Colors.white)),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: ctrl.vouchers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final v = ctrl.vouchers[index];
                          final badgeColor = badgeColors[v.voucherType] ?? defaultBadge;
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.voucherType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            title: Text(
                              'Voucher No: ${v.voucherNo}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              'Date: ${v.voucherDate} • Mode: ${v.paymentMode} • Ref: ${v.referenceNo ?? 'N/A'}\n${v.narration ?? ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${v.totalDebit.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0B5CAD),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () => _showPrintVoucherSlipDialog(v),
                                  icon: const Icon(Icons.print, size: 14, color: Colors.white),
                                  label: const Text(
                                    'Reprint',
                                    style: TextStyle(fontSize: 11, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutToolbar(Color primaryColor, Color tealColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _voucherTypeBtn('Contra (Deposit/Withdrawal)', ctrl.activeType == 'CONTRA',
                () => _selectType('CONTRA'), primaryColor),
            const SizedBox(width: 8),
            _voucherTypeBtn('Payment (Expenses)', ctrl.activeType == 'PAYMENT',
                () => _selectType('PAYMENT'), primaryColor),
            const SizedBox(width: 8),
            _voucherTypeBtn('Receipt (Income)', ctrl.activeType == 'RECEIPT',
                () => _selectType('RECEIPT'), primaryColor),
            const SizedBox(width: 8),
            _voucherTypeBtn('Journal (Adjustments)', ctrl.activeType == 'JOURNAL',
                () => _selectType('JOURNAL'), primaryColor),
            Container(height: 24, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 10)),
            _voucherTypeBtn('Sales POS (Billing)', ctrl.activeType == 'SALES',
                () => _selectType('SALES'), Colors.green.shade800),
            const SizedBox(width: 8),
            _voucherTypeBtn('Purchase (GRN)', ctrl.activeType == 'PURCHASE',
                () => _selectType('PURCHASE'), Colors.amber.shade900),
          ],
        ),
      ),
    );
  }

  Widget _voucherTypeBtn(String label, bool isActive, VoidCallback onTap, Color primaryColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? primaryColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherMetaCard(Color primaryColor, Color tealColor) {
    final titles = {
      'CONTRA': 'Contra Voucher Entry',
      'PAYMENT': 'Payment Voucher Entry',
      'RECEIPT': 'Receipt Voucher Entry',
      'JOURNAL': 'Journal Voucher Entry'
    };
    final descs = {
      'CONTRA': 'Record cash deposit to bank, withdrawal, or bank-to-bank transfer',
      'PAYMENT': 'Record cash/bank payouts for rent, expenses, salaries, or vendor bills',
      'RECEIPT': 'Record incoming customer payments, dues, advances, or income',
      'JOURNAL': 'Record non-cash double-entry adjustments, depreciation, write-offs'
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
                    titles[ctrl.activeType] ?? 'Accounting Voucher',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                  ),
                  Text(
                    descs[ctrl.activeType] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'AUTO-NO',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: tealColor,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Voucher Date',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: ctrl.voucherDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => ctrl.voucherDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd-MM-yyyy').format(ctrl.voucherDate),
                                style: const TextStyle(fontSize: 12)),
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Mode',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ctrl.paymentMode,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('CASH DRAWER')),
                        DropdownMenuItem(value: 'BANK', child: Text('BANK TRANSFER')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text('CHEQUE')),
                        DropdownMenuItem(value: 'ONLINE', child: Text('ONLINE / UPI')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => ctrl.paymentMode = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reference / Slip No',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: ctrl.refNoCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'e.g. DEP-9912',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerBreakdownTable(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DOUBLE ENTRY LEDGER BREAKDOWN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => ctrl.addLine()),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Row', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ctrl.lines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final line = ctrl.lines[index];
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (line.lineType == 'DEBIT') {
                            line.lineType = 'CREDIT';
                            line.creditAmount = line.debitAmount > 0 ? line.debitAmount : line.creditAmount;
                            line.debitAmount = 0.0;
                          } else {
                            line.lineType = 'DEBIT';
                            line.debitAmount = line.creditAmount > 0 ? line.creditAmount : line.debitAmount;
                            line.creditAmount = 0.0;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: line.lineType == 'DEBIT'
                              ? Colors.blue.shade100
                              : Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: line.lineType == 'DEBIT'
                                ? Colors.blue.shade300
                                : Colors.teal.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              line.lineType == 'DEBIT' ? 'Dr' : 'Cr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: line.lineType == 'DEBIT'
                                    ? Colors.blue.shade900
                                    : Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.swap_vert,
                              size: 12,
                              color: line.lineType == 'DEBIT' ? Colors.blue.shade900 : Colors.teal.shade900,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: line.accountName,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Account / Particulars',
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onChanged: (val) => line.accountName = val,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: line.debitAmount > 0
                            ? line.debitAmount.toStringAsFixed(2)
                            : '',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'Debit (₹)',
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onChanged: (val) {
                          line.debitAmount = double.tryParse(val) ?? 0.0;
                          if (line.debitAmount > 0) {
                            line.creditAmount = 0.0;
                            line.lineType = 'DEBIT';
                          }
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: line.creditAmount > 0
                            ? line.creditAmount.toStringAsFixed(2)
                            : '',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'Credit (₹)',
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onChanged: (val) {
                          line.creditAmount = double.tryParse(val) ?? 0.0;
                          if (line.creditAmount > 0) {
                            line.debitAmount = 0.0;
                            line.lineType = 'CREDIT';
                          }
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () => setState(() => ctrl.removeLine(index)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndActionCard(Color primaryColor, Color tealColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VOUCHER SUMMARY',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Debit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('₹${ctrl.totalDebit.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Credit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('₹${ctrl.totalCredit.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          const Divider(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ctrl.isBalanced ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ctrl.isBalanced ? Colors.green.shade200 : Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  ctrl.isBalanced ? Icons.check_circle : Icons.warning_amber,
                  size: 18,
                  color: ctrl.isBalanced ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ctrl.isBalanced
                        ? 'Voucher Balanced (₹0.00)'
                        : 'Unbalanced (Diff: ₹${ctrl.difference.toStringAsFixed(2)})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ctrl.isBalanced ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Narration / Remarks',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl.narrationCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Add narration or voucher note...',
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: ctrl.loading
                  ? null
                  : () async {
                      final res = await ctrl.submitVoucher();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? (res['success'] ? 'Voucher Saved Successfully!' : 'Error')),
                            backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                          ),
                        );
                        if (res['success'] == true) {
                          setState(() => _isCreatingVoucher = false);
                          ctrl.fetchVouchers(type: ctrl.activeType);
                        }
                      }
                    },
              icon: ctrl.loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white, size: 18),
              label: const Text(
                'Save Voucher (Ctrl+S)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoucherHistoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voucher History & Reprint Slip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ctrl.vouchers.isEmpty
                  ? const Center(child: Text('No accounting vouchers recorded yet.'))
                  : ListView.builder(
                      itemCount: ctrl.vouchers.length,
                      itemBuilder: (context, index) {
                        final v = ctrl.vouchers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                v.voucherType,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B5CAD)),
                              ),
                            ),
                            title: Text('Voucher #${v.voucherNo} • ${v.paymentMode}'),
                            subtitle: Text('Date: ${v.voucherDate}\n${v.narration ?? ''}'),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _showPrintVoucherSlipDialog(v),
                              icon: const Icon(Icons.print, size: 14),
                              label: const Text('Reprint Slip'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrintVoucherSlipDialog(AccountingVoucherModel voucher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Print Slip - Voucher #${voucher.voucherNo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${voucher.voucherType}'),
            Text('Date: ${voucher.voucherDate}'),
            Text('Payment Mode: ${voucher.paymentMode}'),
            Text('Total Amount: ₹${voucher.totalDebit.toStringAsFixed(2)}'),
            if (voucher.narration != null) Text('Remarks: ${voucher.narration}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B5CAD)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _printVoucherSlip(voucher);
            },
            icon: const Icon(Icons.print, color: Colors.white, size: 16),
            label: const Text('Print POS Slip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _printVoucherSlip(AccountingVoucherModel voucher) async {
    try {
      await PosInvoicePrinter.printAccountingVoucherReceipt(
        voucherNo: voucher.voucherNo,
        voucherType: voucher.voucherType,
        dateStr: voucher.voucherDate,
        partyName: voucher.narration ?? 'Accounting Voucher',
        paymentMode: voucher.paymentMode,
        amount: voucher.totalDebit,
        note: voucher.narration ?? '',
        referenceNo: voucher.referenceNo,
      );
    } catch (e) {
      debugPrint('Print Voucher Error: $e');
    }
  }
}
