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
    show PaymentStatus, SupplierBill;

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

                  return Expanded(child: _tableCard());
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
                        b.status == PaymentStatus.PAID
                            ? const Text('-')
                            : FilledButton(
                                onPressed: () => _openPaymentDialog(b),
                                child: const Text('Pay'),
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
  void _openPaymentDialog(SupplierBill bill) {
    final amountCtrl = TextEditingController();
    final referenceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String paymentMode = 'CASH';
    DateTime paymentDate = DateTime.now();
    String? errorText;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final enteredAmount = double.tryParse(amountCtrl.text) ?? 0;

            return AlertDialog(
              title: const Text('Supplier Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _info('Supplier', bill.supplier),
                  _info('Bill No', bill.billNo),
                  _info('Balance', bill.balance.toStringAsFixed(2)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Pay Amount',
                      errorText: errorText,
                    ),
                    onChanged: (v) {
                      final amt = double.tryParse(v) ?? 0;

                      setDialogState(() {
                        if (amt <= 0) {
                          errorText = 'Enter valid amount';
                        } else if (amt > bill.balance) {
                          errorText = 'Amount exceeds balance';
                        } else {
                          errorText = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    items: ['CASH', 'CARD', 'UPI', 'BANK']
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        paymentMode = v!;
                      });
                    },
                    decoration:
                        const InputDecoration(labelText: 'Payment Mode'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payment Date'),
                    subtitle: Text(
                      DateFormat('dd-MMM-yyyy').format(paymentDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
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
                  ),
                  TextField(
                    controller: referenceCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Reference No'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: errorText != null || enteredAmount <= 0
                      ? null
                      : () async {
                          await ctrl.payBill(
                            billId: bill.id,
                            amount: enteredAmount,
                            paymentMode: paymentMode,
                            paymentDate: paymentDate,
                            referenceNo: referenceCtrl.text.trim(),
                            note: noteCtrl.text.trim(),
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                  child: const Text('Pay'),
                ),
              ],
            );
          },
        );
      },
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

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}
