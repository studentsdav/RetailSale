import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/return_report_controller.dart'
    show ReturnReportController;
import '../../utils/branding_storage.dart';

class ReturnReportScreen extends StatefulWidget {
  const ReturnReportScreen({super.key});

  @override
  State<ReturnReportScreen> createState() => _ReturnReportScreenState();
}

class _ReturnReportScreenState extends State<ReturnReportScreen> {
  final ctrl = ReturnReportController();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.init();

    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.toDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Return Report'),
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
            Expanded(
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  if (ctrl.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (ctrl.list.isEmpty) {
                    return const Center(child: Text('No returns found'));
                  }

                  return _returnList();
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
        //   )
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
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 📅 From Date
              _modernDateField(
                label: 'From Date',
                controller: _fromCtrl,
                onTap: () async {
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
                  setState(() {});
                },
              ),

              // 📅 To Date
              _modernDateField(
                label: 'To Date',
                controller: _toCtrl,
                onTap: () async {
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
                  setState(() {});
                },
              ),

              // 🔍 Search Return No
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Return No',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ▶ Apply Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ctrl.search = _searchCtrl.text;
                    ctrl.load();
                    setState(() {});
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Apply'),
                ),
              ),

              // 🔄 Reset Button
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ctrl.reset();
                    _searchCtrl.clear();
                    ctrl.load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modernDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ================= RETURN LIST =================
  Widget _returnList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: ctrl.list.length,
      itemBuilder: (context, index) {
        final header = ctrl.list[index];
        final items = header.items;

        return Container(
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HEADER =================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT INFO
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Return #${header.returnNo}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd-MMM-yyyy').format(header.returnDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Issue Ref: ${header.issueNo ?? '-'}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // RIGHT SECTION (Amount)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Net Amount",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "₹ ${header.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 14),

                // ================= TABLE =================
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade100),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 48,
                    columns: const [
                      DataColumn(label: Text('Item Name')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Rate')),
                      DataColumn(label: Text('Amount')),
                    ],
                    rows: List.generate(items.length, (i) {
                      final item = items[i];

                      return DataRow(
                        color: WidgetStateProperty.all(
                          i.isEven ? Colors.grey.shade50 : Colors.white,
                        ),
                        cells: [
                          DataCell(Text(
                            item.itemName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          )),
                          DataCell(Text(item.qty.toString())),
                          DataCell(Text(item.rate.toStringAsFixed(2))),
                          DataCell(Text(
                            item.amount.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          )),
                        ],
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 10),

                // ================= FOOTER =================
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Return Total : ₹ ${header.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      String label, TextEditingController controller, VoidCallback onTap) {
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

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Return Report'];

    int row = 0;
    double grandTotal = 0;

    // ===== Title =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('RETURN REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}');

    row += 2;

    for (final header in ctrl.list) {
      // ===== Header Row =====
      final headerCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));

      headerCell.value = exc.TextCellValue('Return: ${header.returnNo} | '
          '${DateFormat('dd-MMM-yyyy').format(header.returnDate)} | '
          'Issue Ref: ${header.issueNo ?? '-'}');

      headerCell.cellStyle = exc.CellStyle(
        bold: true,
        backgroundColorHex: exc.ExcelColor.fromHexString('#DCE6F1'),
      );

      row++;

      // ===== Table Header =====
      final columns = ['Item Name', 'Qty', 'Rate', 'Amount'];

      for (int i = 0; i < columns.length; i++) {
        final cell = sheet.cell(
            exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));

        cell.value = exc.TextCellValue(columns[i]);
        cell.cellStyle = exc.CellStyle(
          bold: true,
          fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
          backgroundColorHex: exc.ExcelColor.fromHexString('#305496'),
        );
      }

      row++;

      // ===== Items =====
      for (int i = 0; i < header.items.length; i++) {
        final item = header.items[i];

        final bgColor = i.isEven
            ? exc.ExcelColor.fromHexString('#FFFFFF')
            : exc.ExcelColor.fromHexString('#F2F2F2');

        void setCell(int col, exc.CellValue value) {
          final cell = sheet.cell(
              exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = value;
          cell.cellStyle = exc.CellStyle(backgroundColorHex: bgColor);
        }

        setCell(0, exc.TextCellValue(item.itemName));
        setCell(1, exc.DoubleCellValue(item.qty));
        setCell(2, exc.DoubleCellValue(item.rate));
        setCell(3, exc.DoubleCellValue(item.amount));

        row++;
      }

      // ===== Return Total =====
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = exc.TextCellValue('Return Total');

      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = exc.DoubleCellValue(header.totalAmount);

      grandTotal += header.totalAmount;

      row += 2;
    }

    // ===== Grand Total =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = exc.TextCellValue('Grand Total');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.DoubleCellValue(grandTotal);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/ReturnReport_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);
    final nowStr = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    double grandTotal = 0;
    for (final header in ctrl.list) {
      grandTotal += header.totalAmount;
    }

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
                          'RETURN REPORT',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#2563EB'),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}',
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
                      'Total Returns: ${ctrl.list.length}',
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
                'RetailSale POS — Return Report',
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
                  _pdfKpiBlock('Total Return Transactions', ctrl.list.length.toString(), PdfColor.fromHex('#1E40AF')),
                  _pdfKpiBlock('Grand Total Return Value', currency.format(grandTotal), PdfColor.fromHex('#D97706')),
                ],
              ),
            ),
          );

          for (final header in ctrl.list) {
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
                      'Return Ref: ${header.returnNo} | Issue Ref: ${header.issueNo ?? '-'}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#1E293B')),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('dd-MMM-yyyy').format(header.returnDate)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#2563EB')),
                    ),
                  ],
                ),
              ),
            );

            final tableHeaders = ['Item Name', 'Qty', 'Rate', 'Amount'];
            final tableData = header.items.map((item) {
              return [
                item.itemName,
                item.qty.toString(),
                item.rate.toStringAsFixed(2),
                currency.format(item.amount),
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
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.0),
                  1: pw.FlexColumnWidth(1.0),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.5),
                },
              ),
            );

            widgets.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
                  child: pw.Text(
                    'Return Total: ${currency.format(header.totalAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#D97706')),
                  ),
                ),
              ),
            );
          }

          widgets.add(pw.Divider(color: PdfColor.fromHex('#CBD5E1')));
          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E293B'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  "Grand Total Return: ${currency.format(grandTotal)}",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(name: 'Return_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}', onLayout: (format) async => pdf.save());
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
}
