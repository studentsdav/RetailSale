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

import '../../controllers/reports/purchase_report_controller.dart';
import '../../utils/branding_storage.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() =>
      _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen> {
  final ctrl = PurchaseReportController();

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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Purchase Order Report'),
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
                if (ctrl.loading) return const SizedBox();
                return _summaryCard();
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) {
                  if (ctrl.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (ctrl.list.isEmpty) {
                    return const Center(
                        child: Text('No purchase orders found'));
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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                },
              ),

              // 👤 Supplier
              SizedBox(
                width: 250,
                child: DropdownSearch<int>(
                  selectedItem: ctrl.supplierId ?? -1,
                  items: (f, i) => [
                    -1,
                    ...ctrl.suppliers.map((s) => s.id),
                  ],
                  itemAsString: (id) {
                    if (id == -1) return "All Suppliers";
                    final s = ctrl.suppliers.firstWhere((e) => e.id == id);
                    return s.supplierName;
                  },
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: 'Supplier',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    ctrl.supplierId = val == -1 ? null : val;
                  },
                ),
              ),

              // 📊 Status
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: ctrl.status,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                    DropdownMenuItem(value: 'PARTIAL', child: Text('PARTIAL')),
                    DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
                  ],
                  onChanged: (v) => ctrl.status = v,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 🔍 Search
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search PO No',
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
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ctrl.search = _searchCtrl.text;
                    ctrl.load();
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

  // ================= SUMMARY =================
  Widget _summaryCard() {
    return Center(
      child: _card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip('Total Orders', ctrl.totalOrders.toDouble(), Colors.blue),
            _chip('Total Amount', ctrl.totalAmount, Colors.green),
          ],
        ),
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
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columns: const [
                DataColumn(label: Text('PO No')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Supplier')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Total')),
              ],
              rows: ctrl.list.map((po) {
                return DataRow(cells: [
                  DataCell(Text(po.poNo)),
                  DataCell(Text(DateFormat('dd-MMM-yyyy').format(po.poDate))),
                  DataCell(Text(po.supplierName)),
                  DataCell(Text(po.status)),
                  DataCell(Text(po.totalAmount.toStringAsFixed(2))),
                ]);
              }).toList(),
            ),
          ),
        ),
      );
    });
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

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Purchase Order Report'];

    int row = 0;

    // ===== Title =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = exc.TextCellValue('PURCHASE ORDER REPORT');

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue(
            'From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
            'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}');

    row += 2;

    // ===== Headers =====
    final headers = ['PO No', 'Date', 'Supplier', 'Status', 'Total'];

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
    for (int i = 0; i < ctrl.list.length; i++) {
      final po = ctrl.list[i];

      final bgColor = i.isEven
          ? exc.ExcelColor.fromHexString('#FFFFFF')
          : exc.ExcelColor.fromHexString('#F2F2F2');

      void setCell(int col, exc.CellValue value) {
        final cell = sheet.cell(
            exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = value;
        cell.cellStyle = exc.CellStyle(backgroundColorHex: bgColor);
      }

      setCell(0, exc.TextCellValue(po.poNo));
      setCell(
          1, exc.TextCellValue(DateFormat('dd-MMM-yyyy').format(po.poDate)));
      setCell(2, exc.TextCellValue(po.supplierName));
      setCell(3, exc.TextCellValue(po.status));
      setCell(4, exc.DoubleCellValue(po.totalAmount));

      row++;
    }

    row++;

    // ===== Summary =====
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = exc.TextCellValue('Total Amount');
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .cellStyle = exc.CellStyle(
      bold: true,
      fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: exc.ExcelColor.fromHexString('#1E3A8A'),
    );

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = exc.DoubleCellValue(ctrl.totalAmount);
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .cellStyle = exc.CellStyle(
      bold: true,
      fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: exc.ExcelColor.fromHexString('#1E3A8A'),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/PurchaseOrder_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              if (logo != null)
                pw.Container(
                  width: 42,
                  height: 42,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if ((branding?.businessName ?? '').isNotEmpty)
                    pw.Text(
                      branding!.businessName,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.Text(
                    'Purchase Order Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ]),
            pw.Text(
              'From: ${DateFormat('dd-MMM-yyyy').format(ctrl.fromDate)}  '
              'To: ${DateFormat('dd-MMM-yyyy').format(ctrl.toDate)}',
            ),
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
              headers: const ['PO No', 'Date', 'Supplier', 'Status', 'Total'],
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey700),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: ctrl.list.map((po) {
                return [
                  po.poNo,
                  DateFormat('dd-MMM-yyyy').format(po.poDate),
                  po.supplierName,
                  po.status,
                  po.totalAmount.toStringAsFixed(2),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Orders: ${ctrl.totalOrders}     '
                'Total Amount: ${ctrl.totalAmount.toStringAsFixed(2)}',
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
