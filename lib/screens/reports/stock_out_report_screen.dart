import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/stock_out_report_controller.dart';

class StockOutReportScreen extends StatefulWidget {
  const StockOutReportScreen({super.key});

  @override
  State<StockOutReportScreen> createState() => _StockOutReportScreenState();
}

class _StockOutReportScreenState extends State<StockOutReportScreen> {
  final ctrl = StockOutReportController();

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
  }

  void _onGenerate() async {
    ctrl.fromDate = fromDate;
    ctrl.toDate = toDate;

    // Reset filters before loading
    ctrl.selectedDepartment = null;
    ctrl.selectedItem = null;

    await ctrl.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Stock Dispatch Report'),
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
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) => _filterCard(),
            ),
            const SizedBox(height: 16),
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
            "Report Filters",
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

              // 📊 Report Type
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: ctrl.reportType,
                  items: const [
                    DropdownMenuItem(
                      value: 'detail',
                      child: Text('Detail Report'),
                    ),
                    DropdownMenuItem(
                      value: 'summary',
                      child: Text('Summary Report'),
                    ),
                  ],
                  onChanged: (v) {
                    ctrl.reportType = v!;
                    ctrl.selectedDepartment = null;
                    ctrl.selectedItem = null;
                    ctrl.data = [];
                    ctrl.notifyListeners();
                  },
                  decoration: _modernInputDecoration('Report Type'),
                ),
              ),

              // 🔎 Detail Filters
              if (ctrl.reportType == 'detail' &&
                  ctrl.originalData.isNotEmpty) ...[
                // 🏢 Department
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String?>(
                    initialValue: ctrl.selectedDepartment,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Departments'),
                      ),
                      ...ctrl.departments.map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      ctrl.selectedDepartment = v;
                      ctrl.applyLocalFilter();
                    },
                    decoration: _modernInputDecoration('Department'),
                  ),
                ),

                // 📦 Item
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String?>(
                    initialValue: ctrl.selectedItem,
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
                      ctrl.selectedItem = v;
                      ctrl.applyLocalFilter();
                    },
                    decoration: _modernInputDecoration('Item'),
                  ),
                ),
              ],

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
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        if (ctrl.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ctrl.data.isEmpty) {
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
            const SizedBox(height: 12),
            Expanded(child: _tableSection()),
          ],
        );
      },
    );
  }

  Widget _summaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryChip(
                'Total Records', ctrl.data.length.toDouble(), Colors.blue),
            const SizedBox(width: 16),
            _summaryChip('Total Net', ctrl.totalNet, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _tableSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          columns: _buildColumns(),
          rows: List.generate(
            ctrl.data.length,
            (i) => _buildRow(ctrl.data[i], i),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (ctrl.reportType == 'summary') {
      return const [
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Brand')),
        DataColumn(label: Text('Unit')),
        DataColumn(label: Text('Total Qty')),
        DataColumn(label: Text('Avg Rate')),
        DataColumn(label: Text('Net')),
      ];
    }

    return const [
      DataColumn(label: Text('Item')),
      DataColumn(label: Text('Brand')),
      DataColumn(label: Text('Unit')),
      DataColumn(label: Text('Qty')),
      DataColumn(label: Text('Rate')),
      DataColumn(label: Text('Net')),
      DataColumn(label: Text('Department')),
    ];
  }

  DataRow _buildRow(dynamic e, int index) {
    return DataRow(
      color: WidgetStateProperty.all(
          index.isEven ? Colors.grey.shade50 : Colors.white),
      cells: ctrl.reportType == 'summary'
          ? [
              DataCell(Text('${e['item_name'] ?? ''}${e['brand'] != null && e['brand'].toString().isNotEmpty ? ' (${e['brand']})' : ''}')),
              DataCell(Text(e['brand'] ?? '')),
              DataCell(Text(e['unit'] ?? '')),
              DataCell(Text(e['total_qty'].toString())),
              DataCell(Text(
                  double.parse(e['avg_rate'].toString()).toStringAsFixed(2))),
              DataCell(Text(
                double.parse(e['total_amount'].toString()).toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
            ]
          : [
              DataCell(Text('${e['item_name'] ?? ''}${e['brand'] != null && e['brand'].toString().isNotEmpty ? ' (${e['brand']})' : ''}')),
              DataCell(Text(e['brand'] ?? '')),
              DataCell(Text(e['unit'] ?? '')),
              DataCell(Text(e['qty'].toString())),
              DataCell(
                  Text(double.parse(e['rate'].toString()).toStringAsFixed(2))),
              DataCell(Text(
                double.parse(e['amount'].toString()).toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              DataCell(Text(e['department'] ?? '')),
            ],
    );
  }

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

  Widget _summaryChip(String label, double value, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(.15),
      label: Text(
        '$label : ${value.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _pickFromDate() async {
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

  Future<void> _pickToDate() async {
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
    final sheet = excel['Issue Transfer Report'];

    int row = 0;

    // ===== Title =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('ISSUE / STOCK TRANSFER REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(toDate)}');

    row += 2;

    final columns = ctrl.reportType == 'summary'
        ? ["Item", "Brand", "Unit", "Total Qty", "Avg Rate", "Net"]
        : ["Item", "Brand", "Unit", "Qty", "Rate", "Net", "Department"];

    // ===== Header =====
    for (int i = 0; i < columns.length; i++) {
      final cell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));

      cell.value = exc.TextCellValue(columns[i]);
      cell.cellStyle = exc.CellStyle(
        bold: true,
        fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: exc.ExcelColor.fromHexString('#305496'),
      );
    }

    row++;

    // ===== Data =====
    for (int i = 0; i < ctrl.data.length; i++) {
      final e = ctrl.data[i];

      final bgColor = i.isEven
          ? exc.ExcelColor.fromHexString('#FFFFFF')
          : exc.ExcelColor.fromHexString('#F2F2F2');

      void setCell(int col, dynamic value) {
        final cell = sheet.cell(
            exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = value;
        cell.cellStyle = exc.CellStyle(backgroundColorHex: bgColor);
      }

      if (ctrl.reportType == 'summary') {
        setCell(0, exc.TextCellValue('${e['item_name'] ?? ''}${e['brand'] != null && e['brand'].toString().isNotEmpty ? ' (${e['brand']})' : ''}'));
        setCell(1, exc.TextCellValue(e['brand'] ?? ''));
        setCell(2, exc.TextCellValue(e['unit'] ?? ''));
        setCell(
            3, exc.DoubleCellValue(double.parse(e['total_qty'].toString())));
        setCell(4, exc.DoubleCellValue(double.parse(e['avg_rate'].toString())));
        setCell(
            5, exc.DoubleCellValue(double.parse(e['net_amount'].toString())));
      } else {
        setCell(0, exc.TextCellValue('${e['item_name'] ?? ''}${e['brand'] != null && e['brand'].toString().isNotEmpty ? ' (${e['brand']})' : ''}'));
        setCell(1, exc.TextCellValue(e['brand'] ?? ''));
        setCell(2, exc.TextCellValue(e['unit'] ?? ''));
        setCell(3, exc.DoubleCellValue(double.parse(e['qty'].toString())));
        setCell(4, exc.DoubleCellValue(double.parse(e['rate'].toString())));
        setCell(
            5, exc.DoubleCellValue(double.parse(e['net_amount'].toString())));
        setCell(6, exc.TextCellValue(e['department'] ?? ''));
      }

      row++;
    }

    row++;

    // ===== Total Net =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(
            columnIndex: columns.length - 2, rowIndex: row))
        .value = exc.TextCellValue('Total');

    sheet
        .cell(exc.CellIndex.indexByColumnRow(
            columnIndex: columns.length - 1, rowIndex: row))
        .value = exc.DoubleCellValue(ctrl.totalNet);

    // ===== Save File =====
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/StockDispatch_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Stock Dispatch Report',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('From: ${DateFormat('dd-MMM-yyyy').format(fromDate)} '
                'To: ${DateFormat('dd-MMM-yyyy').format(toDate)}'),
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
          final columns = ctrl.reportType == 'summary'
              ? ["Item", "Brand", "Unit", "Total Qty", "Avg Rate", "Net"]
              : ["Item", "Brand", "Unit", "Qty", "Rate", "Net", "Department"];

          return [
            pw.Table.fromTextArray(
              headers: columns,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey700),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: ctrl.data.map((e) {
                if (ctrl.reportType == 'summary') {
                  return [
                    '${e['item_name'] ?? ''}${e['brand'] != null && e['brand'].toString().isNotEmpty ? ' (${e['brand']})' : ''}',
                    e['brand'] ?? '',
                    e['unit'] ?? '',
                    e['total_qty'].toString(),
                    double.parse(e['avg_rate'].toString()).toStringAsFixed(2),
                    double.parse(e['net_amount'].toString()).toStringAsFixed(2),
                  ];
                } else {
                  return [
                    '${e['item_name'] ?? ''}${e['brand'] != null && e['brand'].toString().isNotEmpty ? ' (${e['brand']})' : ''}',
                    e['brand'] ?? '',
                    e['unit'] ?? '',
                    e['qty'].toString(),
                    double.parse(e['rate'].toString()).toStringAsFixed(2),
                    double.parse(e['net_amount'].toString()).toStringAsFixed(2),
                    e['department'] ?? '',
                  ];
                }
              }).toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Net : ${ctrl.totalNet.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(name: 'Stock_Out_Report', onLayout: (format) async => pdf.save());
  }
}
