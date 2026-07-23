import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/modify/receiving_modify_controller.dart';
import '../../models/auth/permission_service.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/supplier_model.dart';

class ModifyReceivingScreen extends StatefulWidget {
  final int? initialGrnId;
  final DateTime? initialReceiptDate;

  const ModifyReceivingScreen({
    super.key,
    this.initialGrnId,
    this.initialReceiptDate,
  });

  @override
  State<ModifyReceivingScreen> createState() => _ModifyReceivingScreenState();
}

class _ModifyReceivingScreenState extends State<ModifyReceivingScreen> {
  final ctrl = ReceivingModifyController();
  bool get _canReprint =>
      PermissionService.can('REPRINT_RECEIVING') || PermissionService.can('MODIFY_RECEIVING');
  bool get _canModify => PermissionService.can('MODIFY_RECEIVING');
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

    if (widget.initialGrnId != null) {
      await ctrl.loadGRNDetails(widget.initialGrnId!);
      final rawReceiptDate = ctrl.grnDetails['receipt_date']?.toString();
      final parsedReceiptDate = rawReceiptDate == null
          ? null
          : DateTime.tryParse(rawReceiptDate);
      if (widget.initialReceiptDate != null) {
        selectedDate = widget.initialReceiptDate!;
      } else if (parsedReceiptDate != null) {
        selectedDate = parsedReceiptDate;
      }

      await ctrl.loadGRNByDate(DateFormat('yyyy-MM-dd').format(selectedDate));
      await _loadDetails(widget.initialGrnId!);
    } else {
      await _loadGRN();
    }
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
                    if (property.printMobile != false && property.mobile.isNotEmpty)
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
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("GRN No: ${grn['grn_no']}"),
                    pw.Text(
                      "Date: ${DateFormat('dd-MMM-yyyy').format(receiptDate)}",
                    ),
                    pw.Text("PO No: $poNumber"),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Supplier: ${supplier.supplierName}"),
                    pw.Text(
                      "Bill No: ${grn['supplier_bill_no'] ?? ''}",
                    ),
                  ],
                ),
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
                    _cell('${r['item_name'] ?? ''}${r['brand'] != null && r['brand'].toString().isNotEmpty ? ' (${r['brand']})' : ''}'),
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

    await Printing.layoutPdf(name: 'GRN_${grn['grn_no']}', onLayout: (format) async => pdf.save());
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
    final scheme = Theme.of(context).colorScheme;

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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    /// DATE
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Date",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 160,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              DateFormat('dd-MMM-yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
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
                        ),
                      ],
                    ),

                    /// GRN
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GRN No",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('grn-$grnId'),
                            initialValue: grnId,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: ctrl.grns.map<DropdownMenuItem<int>>((e) {
                              return DropdownMenuItem(
                                value: e['id'],
                                child: Text(e['grn_no'], style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              _loadDetails(v);
                            },
                          ),
                        ),
                      ],
                    ),

                    /// SUPPLIER
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Supplier",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          width: 260,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('supplier-$grnId-$supplierId'),
                            initialValue: supplierId,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: supplierCtrl.list
                                .map((Supplier s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.supplierName, style: const TextStyle(fontSize: 13)),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ITEMS TABLE
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
                        columnSpacing: 40,
                        columns: const [
                          DataColumn(label: Text("S.No")),
                          DataColumn(label: Text("Item")),
                          DataColumn(label: Text("Unit")),
                          DataColumn(label: Text("Qty")),
                          DataColumn(label: Text("Rate")),
                          DataColumn(label: Text("Remarks")),
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
                              DataCell(Text(
                                '${item['item_name'] ?? ''}${item['brand'] != null && item['brand'].toString().isNotEmpty ? ' (${item['brand']})' : ''}'
                              )),
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
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (v) {
                                      item['rate'] = double.tryParse(v) ?? 0;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'receiving-$grnId-${item['id'] ?? item['item_code'] ?? item['item_name']}-remarks',
                                    ),
                                    initialValue: (item['remarks'] ?? '').toString(),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (v) {
                                      item['remarks'] = v;
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
              ),
            ),

            const SizedBox(height: 16),

            /// TOTAL
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        "₹ ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  if (_canModify)
                    Tooltip(
                      message: 'Close modify screen',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _closeScreen,
                          icon: const Icon(Icons.close_outlined, size: 18),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ),
                  if (_canReprint)
                    Tooltip(
                      message: 'Print receiving voucher',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _print,
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print'),
                        ),
                      ),
                    ),
                  if (_canModify)
                    Tooltip(
                      message: 'Save receiving changes',
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined, size: 18),
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
