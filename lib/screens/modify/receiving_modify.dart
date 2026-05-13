import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/modify/receiving_modify_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/supplier_model.dart';

class ModifyReceivingScreen extends StatefulWidget {
  const ModifyReceivingScreen({super.key});

  @override
  State<ModifyReceivingScreen> createState() => _ModifyReceivingScreenState();
}

class _ModifyReceivingScreenState extends State<ModifyReceivingScreen> {
  final ctrl = ReceivingModifyController();
  final supplierCtrl = SupplierController();
  final propertyCtrl = PropertyInfoController();

  PropertyInfo? propertyInfo;

  DateTime selectedDate = DateTime.now();

  int? grnId;
  int? supplierId;

  List items = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await supplierCtrl.load();
    await propertyCtrl.load();
    propertyInfo = propertyCtrl.data;
    await _loadGRN();
  }

  Future<void> _loadGRN() async {
    final date = DateFormat('yyyy-MM-dd').format(selectedDate);
    await ctrl.loadGRNByDate(date);
    setState(() {
      grnId = null;
      supplierId = null;
      items = [];
    });
  }

  Future<void> _loadDetails(int id) async {
    setState(() {
      grnId = id;
      supplierId = null;
      items = [];
    });

    await ctrl.loadGRNDetails(id);

    setState(() {
      supplierId = ctrl.grnDetails['supplier_id'];
      items = List.from(ctrl.items);
    });
  }

  double get total {
    double t = 0;
    for (var i in items) {
      t += double.parse(i['qty'].toString()) *
          double.parse(i['rate'].toString());
    }
    return t;
  }

  Future<void> _save() async {
    if (grnId == null) {
      _msg("Select GRN");
      return;
    }

    await ctrl.modifyGRN(
      id: grnId!,
      supplierId: supplierId!,
      items: items,
    );

    _msg("Receiving Updated");
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// ================= PRINT =================

  void _print() {
    if (grnId == null) {
      _msg("Select GRN first");
      return;
    }

    _printReceiving();
  }

  void _closeScreen() {
    Navigator.of(context).maybePop();
  }

  Future<void> _printReceiving() async {
    final pdf = pw.Document();

    final supplier = supplierCtrl.list.firstWhere((e) => e.id == supplierId);

    final property = propertyCtrl.data;

    final grn = ctrl.grnDetails;

    final poNumber = grn['po_no'] ?? '';

    final receiptDate = DateTime.parse(grn['receipt_date']);

    /// TOTAL CALCULATIONS
    double subTotal = 0;
    double gstTotal = 0;

    for (var i in items) {
      final qty = double.parse(i['qty'].toString());
      final rate = double.parse(i['rate'].toString());
      final tax = double.parse(i['tax'].toString());

      subTotal += qty * rate;
      gstTotal += (qty * rate) * tax / 100;
    }

    final netAmount = subTotal + gstTotal;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      property!.propertyName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(property.address),
                    pw.Text("GSTIN: ${property.gstNo}"),
                    pw.Text("Mobile: ${property.mobile}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  "GOODS RECEIPT NOTE",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= GRN INFO =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("GRN No: ${grn['grn_no']}"),
                  pw.Text(
                    "Date: ${DateFormat('dd-MMM-yyyy').format(receiptDate)}",
                  ),
                  pw.Text("PO No: $poNumber"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Supplier: ${supplier.supplierName}"),
                  pw.Text(
                    "Bill No: ${grn['supplier_bill_no'] ?? ''}",
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1),
            },
            children: [
              /// HEADER
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell("S.No", bold: true),
                  _cell("Item"),
                  _cell("Unit"),
                  _cell("Qty"),
                  _cell("Rate"),
                  _cell("GST"),
                  _cell("Amount"),
                ],
              ),

              /// ITEMS
              ...List.generate(items.length, (i) {
                final r = items[i];

                final qty = double.parse(r['qty'].toString());
                final rate = double.parse(r['rate'].toString());
                final tax = double.parse(r['tax'].toString());

                final amount = qty * rate;

                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(r['item_name']),
                    _cell(r['unit'] ?? ""),
                    _cell(qty.toString()),
                    _cell(rate.toStringAsFixed(2)),
                    _cell(tax.toStringAsFixed(2)),
                    _cell(amount.toStringAsFixed(2)),
                  ],
                );
              })
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTALS =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _total("Sub Total", subTotal),
                  _total("GST", gstTotal),
                  pw.Divider(),
                  _total("Net Amount", netAmount, bold: true),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Text(
            "Goods received in good condition.",
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Store Incharge"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Authorized Signatory"),
                pw.SizedBox(height: 30),
              ]),
            ],
          ),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(
                color: PdfColors.red,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _total(String label, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value.toStringAsFixed(2),
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  /// ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text("Modify Receiving"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// FILTER CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    /// DATE
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat('dd-MMM-yyyy').format(selectedDate),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );

                        if (d != null) {
                          selectedDate = d;
                          await _loadGRN();
                        }
                      },
                    ),

                    const SizedBox(width: 20),

                    /// GRN
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('grn-$grnId'),
                        value: grnId,
                        decoration: const InputDecoration(
                          labelText: "GRN No",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        items: ctrl.grns.map<DropdownMenuItem<int>>((e) {
                          return DropdownMenuItem(
                            value: e['id'],
                            child: Text(e['grn_no']),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _loadDetails(v);
                        },
                      ),
                    ),

                    const SizedBox(width: 20),

                    /// SUPPLIER
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('supplier-$grnId-$supplierId'),
                        value: supplierId,
                        decoration: const InputDecoration(
                          labelText: "Supplier",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        items: supplierCtrl.list
                            .map((Supplier s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.supplierName),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            supplierId = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ITEMS TABLE
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 40,
                    columns: const [
                      DataColumn(label: Text("S.No")),
                      DataColumn(label: Text("Item")),
                      DataColumn(label: Text("Unit")),
                      DataColumn(label: Text("Qty")),
                      DataColumn(label: Text("Rate")),
                      DataColumn(label: Text("Amount")),
                    ],
                    rows: List.generate(items.length, (i) {
                      final item = items[i];

                      final amount = double.parse(item['qty'].toString()) *
                          double.parse(item['rate'].toString());

                      return DataRow(
                        color: WidgetStateProperty.resolveWith((states) {
                          return i.isEven
                              ? const Color(0xffFAFBFD)
                              : Colors.white;
                        }),
                        cells: [
                          DataCell(Text("${i + 1}")),
                          DataCell(Text(item['item_name'])),
                          DataCell(Text(item['unit'] ?? "")),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                key: ValueKey(
                                  'receiving-$grnId-${item['id'] ?? item['item_code'] ?? item['item_name']}-qty',
                                ),
                                initialValue: item['qty'].toString(),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                onChanged: (v) {
                                  item['qty'] = double.tryParse(v) ?? 0;
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                key: ValueKey(
                                  'receiving-$grnId-${item['id'] ?? item['item_code'] ?? item['item_name']}-rate',
                                ),
                                initialValue: item['rate'].toString(),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                onChanged: (v) {
                                  item['rate'] = double.tryParse(v) ?? 0;
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          DataCell(Text(amount.toStringAsFixed(2))),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// TOTAL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Text(
                    "Total Amount",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    "₹ ${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  Tooltip(
                    message: 'Close modify screen',
                    child: SizedBox(
                      width: 170,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _closeScreen,
                        icon: const Icon(Icons.close_outlined),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Print receiving voucher',
                    child: SizedBox(
                      width: 180,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _print,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Save receiving changes',
                    child: SizedBox(
                      width: 180,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
