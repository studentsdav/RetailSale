// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, unused_element

import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/suppliers/supplier_bill_controller.dart';
import '../../models/inventory/supplier_bill_model.dart'
    show PaymentStatus, SupplierBill, SupplierBillDetail;
import '../modify/receiving_modify.dart';

class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({super.key});

  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen> {
  final ctrl = SupplierBillController();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  @override
  void initState() {
    ctrl.init();
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.toDate);
    super.initState();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Supplier Payments'),
        centerTitle: true,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text("Excel"),
            onPressed: exportToExcel,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("PDF"),
            onPressed: exportToPdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _filterCard(),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                if (ctrl.loading) {
                  return const SizedBox();
                }

                return _summaryCard();
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (context, _) {
                  if (ctrl.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (ctrl.bills.isEmpty) {
                    return const Center(
                      child: Text('No supplier bills found'),
                    );
                  }

                  return _tableCard();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FILTER =================
  Widget _filterCard() {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(.05),
            //     blurRadius: 18,
            //     offset: const Offset(0, 6),
            //   ),
            // ],
          ),
          child: Wrap(
            spacing: 20,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 📅 From Date
              _modernDateField(
                'From Date',
                _fromCtrl,
                () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: ctrl.fromDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) {
                    ctrl.fromDate = p;
                    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(p);
                  }
                },
              ),

              // 📅 To Date
              _modernDateField(
                'To Date',
                _toCtrl,
                () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: ctrl.toDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) {
                    ctrl.toDate = p;
                    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(p);
                  }
                },
              ),

              // 🏢 Supplier DropdownSearch
              SizedBox(
                width: 260,
                child: DropdownSearch<int>(
                  selectedItem: ctrl.supplierId == null
                      ? -1
                      : int.tryParse(ctrl.supplierId!),
                  items: (filter, infiniteScrollProps) {
                    return [
                      -1,
                      ...ctrl.suppliers.map((s) => s.id),
                    ];
                  },
                  itemAsString: (id) {
                    if (id == -1) return "All Suppliers";
                    final supplier =
                        ctrl.suppliers.firstWhere((e) => e.id == id);
                    return supplier.supplierName;
                  },
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: "Search supplier...",
                      ),
                    ),
                  ),
                  decoratorProps: DropDownDecoratorProps(
                    decoration: _modernInputDecoration("Supplier"),
                  ),
                  onChanged: (value) {
                    ctrl.supplierId = value == -1 ? null : value.toString();
                    ctrl.load();
                  },
                ),
              ),

              // 📊 Status Dropdown
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: ctrl.status,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'PAID', child: Text('PAID')),
                    DropdownMenuItem(value: 'UNPAID', child: Text('UNPAID')),
                    DropdownMenuItem(value: 'PARTIAL', child: Text('PARTIAL')),
                  ],
                  onChanged: (v) {
                    ctrl.status = v;
                    ctrl.load();
                  },
                  decoration: _modernInputDecoration("Status"),
                ),
              ),

              // ▶ Apply Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text("Apply"),
                  onPressed: () => ctrl.load(),
                ),
              ),

              // 🔄 Reset Button
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reset"),
                  onPressed: () {
                    ctrl.supplierId = null;
                    ctrl.status = null;
                    ctrl.load();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modernDateField(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: _modernInputDecoration(label)
            .copyWith(prefixIcon: const Icon(Icons.calendar_today)),
      ),
    );
  }

  InputDecoration _modernInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ================= SUMMARY =================
  Widget _summaryCard() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('Total Purchase', ctrl.totalPurchase, Colors.blue),
          _chip('Paid', ctrl.totalPaid, Colors.green),
          _chip('Unpaid', ctrl.totalUnpaid, Colors.red),
        ],
      ),
    );
  }

  // ================= TABLE =================
  Widget _tableCard() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest),
                columns: const [
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Bill No')),
                  DataColumn(label: Text('Bill Date')),
                  DataColumn(label: Text('Bill Amount')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Balance')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: ctrl.bills.map((b) {
                  return DataRow(
                    color: WidgetStateProperty.all(_rowColor(b.status)),
                    cells: [
                      DataCell(Text(b.supplier)),
                      DataCell(Text(b.billNo)),
                      DataCell(
                          Text(DateFormat('dd-MMM-yyyy').format(b.billDate))),
                      DataCell(Text(b.billAmount.toStringAsFixed(2))),
                      DataCell(Text(b.paidAmount.toStringAsFixed(2))),
                      DataCell(Text(b.balance.toStringAsFixed(2))),
                      DataCell(Text(b.status.name.toUpperCase())),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showBillDetails(b),
                              child: const Text('View Bill'),
                            ),
                            // const SizedBox(width: 8),
                            // OutlinedButton.icon(
                            //   onPressed: () => _openBillModify(b),
                            //   icon: const Icon(Icons.edit_outlined),
                            //   label: const Text('Edit'),
                            // ),
                            const SizedBox(width: 8),
                            if (b.status != PaymentStatus.PAID)
                              FilledButton(
                                onPressed: () => _openPaymentDialog(b),
                                child: const Text('Pay'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ));
    });
  }

  // ================= PAYMENT DIALOG =================
  Future<void> _openPaymentDialog(SupplierBill bill) async {
    final amountCtrl = TextEditingController();
    final creditAdjustedCtrl = TextEditingController(text: '0');
    final referenceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String paymentMode = 'CASH';
    DateTime paymentDate = DateTime.now();
    String? errorText;
    SupplierBillDetail? detail;
    double availableCredit = 0;

    try {
      detail = await ctrl.getBillDetails(bill.id);
      if (detail.supplierId != null) {
        await ctrl.loadAvailableCredit(detail.supplierId!);
        availableCredit = ctrl.availableCredit;
      }
    } catch (_) {
      detail = null;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final enteredAmount = double.tryParse(amountCtrl.text) ?? 0;
            final enteredCredit = double.tryParse(creditAdjustedCtrl.text) ?? 0;

            void validate() {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              final cred = double.tryParse(creditAdjustedCtrl.text) ?? 0;
              final tot = amt + cred;

              if (amt < 0) {
                errorText = 'Pay amount cannot be negative';
              } else if (cred < 0) {
                errorText = 'Credit adjustment cannot be negative';
              } else if (cred > availableCredit + 0.009) {
                errorText = 'Exceeds available credit (Rs. ${availableCredit.toStringAsFixed(2)})';
              } else if (tot <= 0) {
                errorText = 'Enter pay amount or credit to adjust';
              } else if (tot > bill.balance + 0.009) {
                errorText = 'Total exceeds outstanding balance';
              } else {
                errorText = null;
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.blue.shade800,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplier Payment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Settle outstanding vendor invoice balance',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.blueGrey.shade500,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 💳 Horizontal Metric Cards Grid
                      Container(
                        margin: const EdgeInsets.only(bottom: 18, top: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SUPPLIER',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      bill.supplier,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                color: Colors.blueGrey.shade300,
                                thickness: 1,
                                width: 20,
                                indent: 4,
                                endIndent: 4,
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'BILL NO',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      bill.billNo,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                color: Colors.blueGrey.shade300,
                                thickness: 1,
                                width: 20,
                                indent: 4,
                                endIndent: 4,
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OUTSTANDING BALANCE',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs. ${bill.balance.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (detail != null) ...[
                        _billPreviewCard(detail, compact: true),
                        const SizedBox(height: 18),
                      ],
                      // 💳 Available Credit Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: availableCredit > 0 ? Colors.green.shade50 : Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: availableCredit > 0 ? Colors.green.shade200 : Colors.blueGrey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              availableCredit > 0 ? Icons.stars : Icons.info_outline,
                              color: availableCredit > 0 ? Colors.green.shade800 : Colors.blueGrey.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Available Credit: Rs. ${availableCredit.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: availableCredit > 0 ? Colors.green.shade800 : Colors.blueGrey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 💰 Inputs Section
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Pay Amount',
                          hintText: 'Enter amount to settle',
                          prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                          suffixText: 'INR',
                          errorText: errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (v) {
                          setDialogState(() {
                            validate();
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      if (availableCredit > 0) ...[
                        TextField(
                          controller: creditAdjustedCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Credit to Adjust',
                            hintText: 'Enter credit amount to use',
                            prefixIcon: const Icon(Icons.star_border, size: 20),
                            suffixText: 'INR',
                            errorText: errorText,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blueGrey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blueGrey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (v) {
                            setDialogState(() {
                              validate();
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: paymentMode,
                        decoration: InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon: const Icon(Icons.wallet_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: ['CASH', 'CARD', 'UPI', 'BANK', 'CREDIT']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            paymentMode = v!;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => paymentDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Payment Date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blueGrey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blueGrey.shade200),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: Text(
                            DateFormat('dd-MMM-yyyy').format(paymentDate),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: referenceCtrl,
                        decoration: InputDecoration(
                          labelText: 'Reference No',
                          hintText: 'Transaction ID or receipt number',
                          prefixIcon: const Icon(Icons.tag_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Note',
                          hintText: 'Add remarks for this supplier transaction...',
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey.shade700,
                    side: BorderSide(color: Colors.blueGrey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blueGrey.shade200,
                    disabledForegroundColor: Colors.blueGrey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    elevation: 1,
                  ),
                  onPressed: errorText != null || (enteredAmount + enteredCredit) <= 0
                      ? null
                      : () async {
                          await ctrl.payBill(
                            billId: bill.id,
                            amount: enteredAmount,
                            creditAdjusted: enteredCredit,
                            paymentMode: paymentMode,
                            paymentDate: paymentDate,
                            referenceNo: referenceCtrl.text.trim(),
                            note: noteCtrl.text.trim(),
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                  child: const Text('Pay Settlement', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBillModify(SupplierBill bill) async {
    SupplierBillDetail detail;
    try {
      detail = await ctrl.getBillDetails(bill.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (detail.grnId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This supplier bill is not linked to a GRN.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModifyReceivingScreen(
          initialGrnId: detail.grnId,
          initialReceiptDate: detail.receiptDate,
        ),
      ),
    );
  }

  Future<void> _showBillDetails(SupplierBill bill) async {
    SupplierBillDetail detail;
    try {
      detail = await ctrl.getBillDetails(bill.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bill ${bill.billNo}'),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: _billPreviewCard(detail),
          ),
        ),
        actions: [
          if (detail.grnId != null)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _openDetailModify(detail);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetailModify(SupplierBillDetail detail) async {
    if (detail.grnId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This supplier bill is not linked to a GRN.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModifyReceivingScreen(
          initialGrnId: detail.grnId,
          initialReceiptDate: detail.receiptDate,
        ),
      ),
    );
  }

  // ================= COMMON =================
  Widget _card({String? title, required Widget child}) => Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
              ],
              child,
            ],
          ),
        ),
      );

  Widget _dateField(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _dropdown(
          String l, List<String> d, String? v, ValueChanged<String?> c) =>
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          initialValue: v,
          items:
              d.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: c,
          decoration: InputDecoration(labelText: l),
        ),
      );

  Widget _chip(String label, double val, Color color) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Chip(
          backgroundColor: color.withOpacity(.15),
          label: Text(
            '$label : ${val.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      );

  Widget _info(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(l), Text(v)],
        ),
      );

  Widget _billPreviewCard(
    SupplierBillDetail detail, {
    bool compact = false,
  }) {
    final remarks = detail.items
        .where((item) => item.remarks.trim().isNotEmpty)
        .map((item) => '${item.itemName}: ${item.remarks.trim()}')
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip('GRN', detail.grnNo ?? '-'),
              _metaChip(
                'Receipt Date',
                detail.receiptDate == null
                    ? '-'
                    : DateFormat('dd-MMM-yyyy').format(detail.receiptDate!),
              ),
              _metaChip('Items', detail.items.length.toString()),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Text(
              detail.supplierAddress.isEmpty
                  ? detail.supplierPhone
                  : '${detail.supplierAddress}${detail.supplierPhone.isEmpty ? '' : ' | ${detail.supplierPhone}'}',
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 48,
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Item',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Unit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'Qty',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'Rate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'Tax %',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Remarks',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  rows: detail.items
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            DataCell(Text(item.unit)),
                            DataCell(Text(item.qty.toStringAsFixed(2))),
                            DataCell(Text(item.rate.toStringAsFixed(2))),
                            DataCell(Text(item.tax.toStringAsFixed(2))),
                            DataCell(
                              Text(
                                item.remarks.trim().isEmpty ? '-' : item.remarks,
                                style: TextStyle(
                                  color: item.remarks.trim().isEmpty
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFFB91C1C),
                                  fontWeight: item.remarks.trim().isEmpty
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          if (remarks.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attention Remarks Required',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...remarks.map(
                          (remark) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              remark,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E40AF),
        ),
      ),
    );
  }

  Color _rowColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.PAID:
        return Colors.green.withOpacity(.08);
      case PaymentStatus.PARTIAL:
        return Colors.orange.withOpacity(.08);
      case PaymentStatus.UNPAID:
        return Colors.red.withOpacity(.08);
    }
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Supplier Payments'];

    int row = 0;

    // ===== Title =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('SUPPLIER PAYMENT REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}');

    row += 2;

    // ===== Headers (No Action Column) =====
    final headers = [
      'Supplier',
      'Bill No',
      'Bill Date',
      'Bill Amount',
      'Paid',
      'Balance',
      'Status'
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));

      cell.value = exc.TextCellValue(headers[i]);
      cell.cellStyle = exc.CellStyle(
        bold: true,
        fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: exc.ExcelColor.fromHexString('#305496'),
      );
    }

    row++;

    // ===== Data =====
    for (int i = 0; i < ctrl.bills.length; i++) {
      final b = ctrl.bills[i];

      final bgColor = i.isEven
          ? exc.ExcelColor.fromHexString('#FFFFFF')
          : exc.ExcelColor.fromHexString('#F2F2F2');

      void setCell(int col, exc.CellValue value) {
        final cell = sheet.cell(
            exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = value;
        cell.cellStyle = exc.CellStyle(backgroundColorHex: bgColor);
      }

      setCell(0, exc.TextCellValue(b.supplier));
      setCell(1, exc.TextCellValue(b.billNo));
      setCell(
          2, exc.TextCellValue(DateFormat('dd-MMM-yyyy').format(b.billDate)));
      setCell(3, exc.DoubleCellValue(b.billAmount));
      setCell(4, exc.DoubleCellValue(b.paidAmount));
      setCell(5, exc.DoubleCellValue(b.balance));
      setCell(6, exc.TextCellValue(b.status.name.toUpperCase()));

      row++;
    }

    row++;

    // ===== Summary =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.TextCellValue('Total Purchase');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = exc.DoubleCellValue(ctrl.totalPurchase);

    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.TextCellValue('Total Paid');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = exc.DoubleCellValue(ctrl.totalPaid);

    row++;

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.TextCellValue('Total Unpaid');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = exc.DoubleCellValue(ctrl.totalUnpaid);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/SupplierPayments_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Supplier Payment Report',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
                'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}'),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) {
          return [
            pw.Table.fromTextArray(
              headers: const [
                'Supplier',
                'Bill No',
                'Bill Date',
                'Bill Amount',
                'Paid',
                'Balance',
                'Status'
              ],
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey700),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: ctrl.bills.map((b) {
                return [
                  b.supplier,
                  b.billNo,
                  DateFormat('dd-MMM-yyyy').format(b.billDate),
                  b.billAmount.toStringAsFixed(2),
                  b.paidAmount.toStringAsFixed(2),
                  b.balance.toStringAsFixed(2),
                  b.status.name.toUpperCase(),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Purchase: ${ctrl.totalPurchase.toStringAsFixed(2)}   '
                'Paid: ${ctrl.totalPaid.toStringAsFixed(2)}   '
                'Unpaid: ${ctrl.totalUnpaid.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(name: 'Supplier_Payment_Report', onLayout: (format) async => pdf.save());
  }
}
