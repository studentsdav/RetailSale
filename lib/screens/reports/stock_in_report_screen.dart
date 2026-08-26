import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/stock_in_report_controller.dart';
import '../../models/reports/stock_in_model.dart';
import '../../utils/branding_storage.dart';

class StockInReportScreen extends StatefulWidget {
  const StockInReportScreen({super.key});

  @override
  State<StockInReportScreen> createState() => _StockInReportScreenState();
}

class _StockInReportScreenState extends State<StockInReportScreen> {
  final ctrl = StockInReportController();

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  String? selectedSupplier;
  String? selectedItem;
  String search = '';

  String _fmtNumber(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  @override
  void initState() {
    super.initState();
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
  }

  void _onGenerate() async {
    ctrl.fromDate = fromDate;
    ctrl.toDate = toDate;
    ctrl.search = search;

    selectedSupplier = null;
    selectedItem = null;

    await ctrl.load();
    setState(() {});
  }

  void _applyLocalFilter() {
    ctrl.applyLocalFilter(
      supplier: selectedSupplier,
      item: selectedItem,
      search: search,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Receiving Report'),
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
            Expanded(child: _reportBody()),
          ],
        ),
      ),
    );
  }

  // ================= FILTER CARD =================
  Widget _filterCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter Options",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 📅 From Date
              _modernDateField('From Date', _fromCtrl, _pickFromDate),

              // 📅 To Date
              _modernDateField('To Date', _toCtrl, _pickToDate),

              // 🔍 Search
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search Item / Supplier',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    search = v;
                    _applyLocalFilter();
                  },
                ),
              ),

              // 🏢 Supplier Filter
              if (ctrl.originalData.isNotEmpty)
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: selectedSupplier,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Suppliers'),
                      ),
                      ...ctrl.suppliers.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      selectedSupplier = v;
                      _applyLocalFilter();
                    },
                    decoration: _modernInputDecoration('Supplier'),
                  ),
                ),

              // 📦 Item Filter
              if (ctrl.originalData.isNotEmpty)
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: selectedItem,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Items'),
                      ),
                      ...ctrl.items.map(
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      selectedItem = v;
                      _applyLocalFilter();
                    },
                    decoration: _modernInputDecoration('Item'),
                  ),
                ),

              // ▶ Generate Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Generate'),
                  onPressed: _onGenerate,
                ),
              ),
            ],
          ),
        ],
      ),
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

  // ================= REPORT BODY =================
  Widget _reportBody() {
    if (ctrl.filteredData.isEmpty) {
      return const Center(
        child: Text(
          'Select date and click Generate',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        _summaryCard(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ctrl.groupFilteredByInvoice.entries.map((entry) {
              final invNo = entry.key;
              final items = entry.value;
              final header = items.first;

              final invoiceTotal =
                  items.fold<double>(0, (s, e) => s + e.netAmount);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔷 HEADER
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _headerChip(
                            "Receiving No: ${header.grnNo}",
                            Colors.deepOrange,
                          ),
                          _headerChip(
                            "Supplier Invoice: ${header.supplierBill.isEmpty ? '--' : header.supplierBill}",
                            Colors.blueGrey,
                          ),
                          _headerChip(
                            "Date: ${DateFormat('dd-MMM-yyyy').format(header.date)}",
                            Colors.indigo,
                          ),
                          _headerChip(header.supplier, Colors.teal),
                          _headerChip(
                            "State: ${header.supplierState}",
                            Colors.brown,
                          ),
                          _headerChip(
                            "Paid: ${header.paidAmount.toStringAsFixed(2)}",
                            Colors.green,
                          ),
                          _headerChip(
                            "Outstanding: ${header.outstandingAmount.toStringAsFixed(2)}",
                            header.billStatus.toUpperCase() == 'PAID'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              "Receiving No: ${header.grnNo} | Supplier Invoice: ${header.supplierBill.isEmpty ? '--' : header.supplierBill}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                header.supplier,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Receiving No: ${header.grnNo}  Supplier Invoice: ${header.supplierBill.isEmpty ? '--' : header.supplierBill}  GST: ${header.supplierGstin}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "State: ${header.supplierState}  ${header.billStatus}  Paid: ${header.paidAmount.toStringAsFixed(2)}  Outstanding: ${header.outstandingAmount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "Total",
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                "₹${invoiceTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 10),

                      // 🔷 TABLE
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(Colors.grey.shade100),
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          columns: const [
                            DataColumn(label: Text('Item')),
                            DataColumn(label: Text('Unit')),
                            DataColumn(label: Text('Qty')),
                            DataColumn(label: Text('Rate')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('GST %')),
                            DataColumn(label: Text('GST Amount')),
                            DataColumn(label: Text('Net Amount')),
                          ],
                          rows: items.map((e) {
                            return DataRow(
                              cells: [
                  DataCell(Text('${e.itemName}${e.brand.isNotEmpty ? ' (${e.brand})' : ''}')),
                                DataCell(Text(e.unit)),
                                DataCell(Text(e.qty.toString())),
                                DataCell(Text(e.rate.toStringAsFixed(2))),
                                DataCell(Text(e.amount.toStringAsFixed(2))),
                                DataCell(Text(e.gst.toString())),
                                DataCell(Text(e.taxAmount.toStringAsFixed(2))),
                                DataCell(Text(
                                  e.netAmount.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🔷 FOOTER TOTAL
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Invoice Total : ₹${invoiceTotal.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ================= SUMMARY =================
  // Widget _summaryCard() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(18),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(18),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(.05),
  //           blurRadius: 16,
  //           offset: const Offset(0, 6),
  //         ),
  //       ],
  //     ),
  //     child: Wrap(
  //       spacing: 20,
  //       runSpacing: 16,
  //       alignment: WrapAlignment.center,
  //       children: [
  //         _modernStatTile(
  //           title: "Total Records",
  //           value: ctrl.originalData.length.toString(),
  //           color: Colors.blue,
  //         ),
  //         _modernStatTile(
  //           title: "Selected Records",
  //           value: ctrl.filteredData.length.toString(),
  //           color: Colors.orange,
  //         ),
  //         _modernStatTile(
  //           title: "Total Net",
  //           value: "₹${ctrl.totalNet.toStringAsFixed(2)}",
  //           color: Colors.green,
  //           isAmount: true,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _summaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip('Total Records', ctrl.originalData.length.toDouble(),
                Colors.blue),
            const SizedBox(width: 16),
            _chip('Selected Records', ctrl.filteredData.length.toDouble(),
                Colors.orange),
            const SizedBox(width: 16),
            _chip('Total Net', ctrl.totalNet, Colors.green),
          ],
        ),
      ),
    );
  }

  // Widget _modernStatTile({
  //   required String title,
  //   required String value,
  //   required Color color,
  //   bool isAmount = false,
  // }) {
  //   return Container(
  //     width: 220,
  //     padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(.08),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: color.withOpacity(.25)),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Container(
  //           height: 4,
  //           width: 40,
  //           decoration: BoxDecoration(
  //             color: color,
  //             borderRadius: BorderRadius.circular(4),
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         Text(
  //           title,
  //           style: const TextStyle(
  //             fontSize: 13,
  //             color: Colors.grey,
  //           ),
  //         ),
  //         const SizedBox(height: 6),
  //         Text(
  //           value,
  //           style: TextStyle(
  //             fontSize: isAmount ? 18 : 20,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.black87,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ================= ITEM ROW =================
  DataRow _buildItemRow(StockInModel e) {
    return DataRow(
      cells: [
        DataCell(Text(e.itemName)),
        DataCell(Text(e.unit)),
        DataCell(Text(e.qty.toString())),
        DataCell(Text(e.rate.toStringAsFixed(2))),
        DataCell(Text(e.gst.toStringAsFixed(0))),
        DataCell(Text(
          e.netAmount.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        )),
      ],
    );
  }

  Widget _dateField(
      String label, TextEditingController ctrl, VoidCallback onTap) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _chip(String label, double value, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(.15),
      label: Text(
        '$label : ${value.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _headerChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _pickFromDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        fromDate = d;
        _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(d);
      });
    }
  }

  void _pickToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        toDate = d;
        _toCtrl.text = DateFormat('dd-MMM-yyyy').format(d);
      });
    }
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Receiving Report'];

    int row = 0;

    // ================= TITLE =================
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('RECEIVING REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(toDate)}');

    row += 2;

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 15);
    // ================= GROUP LOOP =================
    for (final entry in ctrl.groupFilteredByInvoice.entries) {
      final invNo = entry.key;
      final items = entry.value;
      final header = items.first;

      double invoiceTotal = 0;

      // Invoice Header
      final invCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));

      invCell.value = exc.TextCellValue(
          'Receiving No: ${header.grnNo} | Supplier Invoice: ${header.supplierBill} | Date: ${DateFormat('dd-MMM-yyyy').format(header.date)} | ${header.supplier}');

      invCell.cellStyle = exc.CellStyle(
        bold: true,
        backgroundColorHex: exc.ExcelColor.fromHexString('#DCE6F1'),
      );

      row++;

      sheet
              .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value =
          exc.TextCellValue(
              'GST No: ${header.supplierGstin} | State: ${header.supplierState} | ${header.billStatus} | Paid: ${header.paidAmount.toStringAsFixed(2)} | Outstanding: ${header.outstandingAmount.toStringAsFixed(2)}');

      row++;

      // Table Header
      final headers = [
        "Item",
        "Unit",
        "Qty",
        "Rate",
        "Amount",
        "GST %",
        "GST Amount",
        "Net Amount"
      ];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
            exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

        cell.value = exc.TextCellValue(headers[col]);
        cell.cellStyle = exc.CellStyle(
          bold: true,
          fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
          backgroundColorHex: exc.ExcelColor.fromHexString('#305496'),
        );
      }

      row++;

      // Data Rows
      for (int i = 0; i < items.length; i++) {
        final e = items[i];
        final bgColor = i.isEven
            ? exc.ExcelColor.fromHexString('#FFFFFF')
            : exc.ExcelColor.fromHexString('#F2F2F2');

        void setCell(int col, exc.CellValue value) {
          final cell = sheet.cell(
              exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = value;
          cell.cellStyle = exc.CellStyle(backgroundColorHex: bgColor);
        }

        setCell(0, exc.TextCellValue('${e.itemName}${e.brand.isNotEmpty ? ' (${e.brand})' : ''}'));
        setCell(1, exc.TextCellValue(e.unit));
        setCell(2, exc.DoubleCellValue(e.qty));
        setCell(3, exc.DoubleCellValue(e.rate));
        setCell(4, exc.DoubleCellValue(e.amount));
        setCell(5, exc.DoubleCellValue(e.gst));
        setCell(6, exc.DoubleCellValue(e.taxAmount));
        setCell(7, exc.DoubleCellValue(e.netAmount));

        invoiceTotal += e.netAmount;
        row++;
      }

      // Invoice Total
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = exc.TextCellValue('Invoice Total');

      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = exc.DoubleCellValue(invoiceTotal);
      row += 2;
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/ReceivingReport_$timestamp.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);
    final nowStr = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    final invoicesCount = ctrl.groupFilteredByInvoice.keys.length;
    final totalNetAmt = ctrl.totalNet;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 45,
                        height: 45,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if ((branding?.businessName ?? '').isNotEmpty)
                          pw.Text(
                            branding!.businessName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#1E293B'),
                            ),
                          ),
                        pw.Text(
                          'RECEIVING / STOCK IN REPORT',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#2563EB'),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  To: ${DateFormat('dd-MMM-yyyy').format(toDate)}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $nowStr',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Total Invoices: $invoicesCount',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#475569'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'RetailSale POS — Receiving Report',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          // KPI Summary Bar
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfKpiBlock('Total Invoices', invoicesCount.toString(), PdfColor.fromHex('#1E40AF')),
                  _pdfKpiBlock('Total Items', ctrl.filteredData.length.toString(), PdfColor.fromHex('#2563EB')),
                  _pdfKpiBlock('Total Net Amount', currency.format(totalNetAmt), PdfColor.fromHex('#166534')),
                ],
              ),
            ),
          );

          for (final entry in ctrl.groupFilteredByInvoice.entries) {
            final items = entry.value;
            final headerData = items.first;

            double invoiceTotal = 0;

            // Invoice Subheader
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E2E8F0'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRN: ${headerData.grnNo} | Bill: ${headerData.supplierBill} | Supplier: ${headerData.supplier}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#1E293B')),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('dd-MMM-yyyy').format(headerData.date)} | ${headerData.billStatus}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#2563EB')),
                    ),
                  ],
                ),
              ),
            );

            final tableHeaders = ["Item", "Unit", "Qty", "Rate", "Amount", "GST %", "GST Amt", "Net Amount"];
            final tableData = items.map((e) {
              invoiceTotal += e.netAmount;
              return [
                e.brand.isNotEmpty ? '${e.itemName} (${e.brand})' : e.itemName,
                e.unit,
                e.qty.toString(),
                e.rate.toStringAsFixed(2),
                currency.format(e.amount),
                '${e.gst.toStringAsFixed(0)}%',
                currency.format(e.taxAmount),
                currency.format(e.netAmount),
              ];
            }).toList();

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 7.0),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                },
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.8),
                  1: pw.FlexColumnWidth(0.8),
                  2: pw.FlexColumnWidth(0.8),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(0.8),
                  6: pw.FlexColumnWidth(1.0),
                  7: pw.FlexColumnWidth(1.2),
                },
              ),
            );

            widgets.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 10),
                  child: pw.Text(
                    'Invoice Total: ${currency.format(invoiceTotal)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#166534')),
                  ),
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(name: 'Receiving_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}', onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfKpiBlock(String label, String value, PdfColor valueColor) {
    return pw.Column(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    );
  }
}
