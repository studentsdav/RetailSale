import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/modify/receiving_modify_controller.dart';
import '../../core/config/date_time_service.dart';
import '../../models/auth/permission_service.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/supplier_model.dart';
import '../../utils/branding_storage.dart';
import '../../core/printing/pos_invoice_printer.dart';

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

  DateTime selectedDate = DateTimeService.instance.nowInTimeZone;

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

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get subTotal {
    double t = 0;
    for (var i in items) {
      t += _parseDouble(i['qty']) * _parseDouble(i['rate']);
    }
    return t;
  }

  double get totalGST {
    double g = 0;
    for (var i in items) {
      final qty = _parseDouble(i['qty']);
      final rate = _parseDouble(i['rate']);
      final tax = _parseDouble(i['tax']);
      g += (qty * rate) * tax / 100;
    }
    return g;
  }

  double get netAmount => subTotal + totalGST;

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
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

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
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            rightWidget: pw.Container(
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
          ),

          pw.SizedBox(height: 20),

          /// ================= GRN INFO =================
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.grey50,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("VENDOR / BILL FROM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 4),
                      pw.Text(supplier.supplierName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.blueGrey900)),
                      if ((supplier.address ?? '').trim().isNotEmpty)
                        pw.Text(supplier.address!.trim(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      if ((supplier.gstin ?? '').trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text("GSTIN: ${supplier.gstin!.trim()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        ),
                      if ((grn['supplier_bill_no'] ?? '').toString().trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text("Supplier Bill No: ${grn['supplier_bill_no'].toString().trim()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        ),
                    ],
                  ),
                ),
                pw.Container(width: 0.5, height: 45, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("RECEIVING DETAILS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blueGrey800)),
                    pw.SizedBox(height: 4),
                    _metaRow("GRN No", grn['grn_no'].toString()),
                    _metaRow("Date", DateFormat('dd-MMM-yyyy').format(receiptDate)),
                    if ((poNumber).trim().isNotEmpty)
                      _metaRow("PO No", poNumber.trim()),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(50),
              5: const pw.FixedColumnWidth(45),
              6: const pw.FixedColumnWidth(60),
            },
            children: [
              /// HEADER
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _cell("S.No", bold: true, alignment: pw.Alignment.center),
                  _cell("Item", bold: true),
                  _cell("Unit", bold: true, alignment: pw.Alignment.center),
                  _cell("Qty", bold: true, alignment: pw.Alignment.centerRight),
                  _cell("Rate", bold: true, alignment: pw.Alignment.centerRight),
                  _cell("GST", bold: true, alignment: pw.Alignment.centerRight),
                  _cell("Amount", bold: true, alignment: pw.Alignment.centerRight),
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
                    _cell("${i + 1}", alignment: pw.Alignment.center),
                    _cell('${r['item_name'] ?? ''}${r['brand'] != null && r['brand'].toString().isNotEmpty ? ' (${r['brand']})' : ''}'),
                    _cell(r['unit'] ?? "", alignment: pw.Alignment.center),
                    _cell(qty.toString(), alignment: pw.Alignment.centerRight),
                    _cell(rate.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _cell(tax.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _cell(amount.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
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
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  _total("Net Amount", netAmount, bold: true),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Text(
            "Goods received in good condition.",
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Store Incharge", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ]
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Authorized Signatory", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ]
              ),
            ],
          ),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "REPRINT",
              style: pw.TextStyle(
                color: PdfColors.red,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'GRN_${grn['grn_no']}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _cell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? PdfColors.blueGrey900 : PdfColors.grey900,
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

  pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text(
              "$label:",
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
        ],
      ),
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
                          DataColumn(label: Text("GST (%)")),
                          DataColumn(label: Text("Remarks")),
                          DataColumn(label: Text("Amount")),
                        ],
                        rows: List.generate(items.length, (i) {
                          final item = items[i];

                          final qty = _parseDouble(item['qty']);
                          final rate = _parseDouble(item['rate']);
                          final amount = qty * rate;

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
                                  width: 80,
                                  child: TextFormField(
                                    key: ValueKey(
                                      'receiving-$grnId-${item['id'] ?? item['item_code'] ?? item['item_name']}-tax',
                                    ),
                                    initialValue: (item['tax'] ?? 0).toString(),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (v) {
                                      item['tax'] = double.tryParse(v) ?? 0;
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

            /// TOTAL SUMMARY
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _totalSummaryChip(scheme, 'Sub Total', subTotal),
                      _totalSummaryChip(scheme, 'Total GST', totalGST),
                      _totalSummaryChip(scheme, 'Net Amount', netAmount, highlight: true),
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

  Widget _totalSummaryChip(ColorScheme scheme, String label, double value, {bool highlight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label: ",
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            fontSize: highlight ? 14 : 13,
            color: highlight ? scheme.primary : Colors.grey.shade700,
          ),
        ),
        Text(
          "₹ ${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: highlight ? 17 : 14,
            fontWeight: FontWeight.bold,
            color: highlight ? scheme.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}
