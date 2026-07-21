import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/closing_report_controller.dart';
import '../../models/closing_item_model.dart';
import '../../utils/branding_storage.dart';

class ClosingReportScreen extends StatefulWidget {
  const ClosingReportScreen({super.key});

  @override
  State<ClosingReportScreen> createState() => _ClosingReportScreenState();
}

class _ClosingReportScreenState extends State<ClosingReportScreen> {
  final ClosingReportController ctrl = ClosingReportController();
  final ScrollController _reportListController = ScrollController();

  DateTime? fromDate;
  DateTime? toDate;

  String search = '';
  String? selectedGroup;
  String? selectedItem;

  List<ClosingItem> filteredList = [];

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    fromDate = today;
    toDate = today;

    _loadData();
  }

  @override
  void dispose() {
    _reportListController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ctrl.load(from: fromDate, to: toDate);
    filteredList = List.from(ctrl.list);
    setState(() {});
  }

  // ---------------- DATE PICKERS ----------------
  Future<void> _pickFromDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => fromDate = date);
  }

  Future<void> _pickToDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => toDate = date);
  }

  Future<void> _onGenerate() async {
    await _loadData();
  }

  // ---------------- LOCAL FILTER ----------------
  void _applyFilter() {
    filteredList = ctrl.list.where((e) {
      final matchSearch =
          search.isEmpty || e.name.toLowerCase().contains(search.toLowerCase());

      final matchGroup = selectedGroup == null || e.group == selectedGroup;

      final matchItem = selectedItem == null || e.name == selectedItem;

      return matchSearch && matchGroup && matchItem;
    }).toList();

    setState(() {});
  }

  // ---------------- GROUPING ----------------
  Map<String, List<ClosingItem>> get grouped {
    final map = <String, List<ClosingItem>>{};
    for (final i in filteredList) {
      map.putIfAbsent(i.group, () => []);
      map[i.group]!.add(i);
    }
    return map;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Stock Closing Report'),
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
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _filterCard(),
              Expanded(child: _reportSection()),
            ],
          );
        },
      ),
    );
  }

  // ================= FILTER CARD =================
  Widget _filterCard() {
    final groups = ctrl.list.map((e) => e.group).toSet().toList()..sort();
    final items = ctrl.list.map((e) => e.name).toSet().toList()..sort();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black.withOpacity(.06),
        //     blurRadius: 16,
        //     offset: const Offset(0, 6),
        //   )
        // ],
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _roundedDateField("From Date", fromDate, _pickFromDate),
          _roundedDateField("To Date", toDate, _pickToDate),

          // 🔍 Search
          SizedBox(
            width: 260,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Item...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                search = v;
                _applyFilter();
              },
            ),
          ),

          // 🏷 Group Filter
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: selectedGroup,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Groups")),
                ...groups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g))),
              ],
              onChanged: (v) {
                selectedGroup = v;
                _applyFilter();
              },
              decoration: InputDecoration(
                labelText: "Group",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 📦 Item Filter
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: selectedItem,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Items")),
                ...items.map((i) => DropdownMenuItem(value: i, child: Text(i))),
              ],
              onChanged: (v) {
                selectedItem = v;
                _applyFilter();
              },
              decoration: InputDecoration(
                labelText: "Item",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ▶ Generate Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text("Generate"),
              onPressed: _onGenerate,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Stock Closing'];

    int row = 0;
    double grandTotal = 0;

    // ================= TITLE =================
    var titleCell = sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));

    titleCell.value = exc.TextCellValue('STOCK CLOSING REPORT');
    titleCell.cellStyle = exc.CellStyle(
      bold: true,
      fontSize: 16,
    );

    row++;

    sheet
            .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value =
        exc.TextCellValue('From: ${fromDate?.toString().substring(0, 10)}   '
            'To: ${toDate?.toString().substring(0, 10)}');

    row += 2;

    // ================= COLUMN WIDTH =================
    sheet.setColumnWidth(0, 25);
    for (int i = 1; i <= 9; i++) {
      sheet.setColumnWidth(i, 14);
    }

    // ================= GROUP LOOP =================
    for (final entry in grouped.entries) {
      final group = entry.key;
      final items = entry.value;

      // ---------- Group Header ----------
      final groupCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));

      groupCell.value = exc.TextCellValue('Group: $group');
      groupCell.cellStyle = exc.CellStyle(
        bold: true,
        backgroundColorHex: exc.ExcelColor.fromHexString('#DCE6F1'),
      );

      row++;

      // ---------- Table Header ----------
      final headers = [
        "Item",
        "Brand",
        "Rate",
        "Opening",
        "IN",
        "OUT/Sale",
        "Damage",
        "Return",
        "Supplier Return Qty",
        "Closing",
        "Amount"
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

      double groupTotal = 0;

      // ---------- Data Rows ----------
      for (int i = 0; i < items.length; i++) {
        final e = items[i];

        final bgColor = i.isEven
            ? exc.ExcelColor.fromHexString('#FFFFFF')
            : exc.ExcelColor.fromHexString('#F2F2F2');

        void setCell(int col, exc.CellValue value) {
          final cell = sheet.cell(
              exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

          cell.value = value;
          cell.cellStyle = exc.CellStyle(
            backgroundColorHex: bgColor,
          );
        }

        setCell(0, exc.TextCellValue(e.name));
        setCell(1, exc.TextCellValue(e.brand));
        setCell(2, exc.DoubleCellValue(e.avgRate));
        setCell(3, exc.DoubleCellValue(e.opening));
        setCell(4, exc.DoubleCellValue(e.receive));
        setCell(5, exc.DoubleCellValue(e.issue));
        setCell(6, exc.DoubleCellValue(e.damage));
        setCell(7, exc.DoubleCellValue(e.returned));
        setCell(8, exc.DoubleCellValue(e.supplierReturnQty));
        setCell(9, exc.DoubleCellValue(e.closing));
        setCell(10, exc.DoubleCellValue(e.amount));

        groupTotal += e.amount;
        row++;
      }

      // ---------- Group Total ----------
      final totalLabelCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row));

      totalLabelCell.value = exc.TextCellValue('Group Total');
      totalLabelCell.cellStyle = exc.CellStyle(
        bold: true,
      );

      final totalValueCell = sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row));

      totalValueCell.value = exc.DoubleCellValue(groupTotal);
      totalValueCell.cellStyle = exc.CellStyle(
        bold: true,
        backgroundColorHex: exc.ExcelColor.fromHexString('#FFF2CC'),
      );

      grandTotal += groupTotal;
      row += 2;
    }

    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        .value = exc.TextCellValue('Grand Total');
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        .cellStyle = exc.CellStyle(
      bold: true,
      fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: exc.ExcelColor.fromHexString('#1E3A8A'),
    );
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        .value = exc.DoubleCellValue(grandTotal);
    sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        .cellStyle = exc.CellStyle(
      bold: true,
      fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: exc.ExcelColor.fromHexString('#1E3A8A'),
    );

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/StockClosingReport.xlsx';

    final file = File(filePath);

// If file exists → delete it first
    if (await file.exists()) {
      await file.delete();
    }

    await file.writeAsBytes(excel.encode()!);

    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);
    double grandTotal = 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 1),
            ),
          ),
          child: pw.Row(
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
                      "Stock Closing Report",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ]),
              pw.Text(
                "From: ${fromDate?.toString().substring(0, 10)}  "
                "To: ${toDate?.toString().substring(0, 10)}",
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (final entry in grouped.entries) {
            final group = entry.key;
            final items = entry.value;

            double groupTotal = 0;

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20, bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.blueGrey100,
                child: pw.Text(
                  "Group: $group",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            );

            widgets.add(
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headers: const [
                  "Item",
                  "Brand",
                  "Rate",
                  "Opening",
                  "IN",
                  "Sale",
                  "Damage",
                  "Return",
                  "Supplier Return Qty",
                  "Closing",
                  "Amount"
                ],
                data: List.generate(items.length, (i) {
                  final e = items[i];
                  groupTotal += e.amount;

                  return [
                    e.name,
                    e.brand,
                    e.avgRate.toStringAsFixed(2),
                    e.opening.toString(),
                    e.receive.toString(),
                    e.issue.toString(),
                    e.damage.toString(),
                    e.returned.toString(),
                    e.supplierReturnQty.toString(),
                    e.closing.toString(),
                    e.amount.toStringAsFixed(2),
                  ];
                }),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
              ),
            );

            widgets.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text(
                  "Group Total : ${groupTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );

            grandTotal += groupTotal;
          }

          widgets.add(pw.Divider());
          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: PdfColors.blueGrey700,
                child: pw.Text(
                  "Grand Total : ${grandTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(name: 'Stock_Closing_Report', onLayout: (format) async => pdf.save());
  }

  Widget _roundedDateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 10),
            Text(
              value == null ? label : value.toString().substring(0, 10),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value == null ? label : value.toString().substring(0, 10),
        ),
      ),
    );
  }

  // ================= REPORT SECTION =================
  Widget _reportSection() {
    if (grouped.isEmpty) {
      return const Center(child: Text("No Data Found"));
    }

    return Scrollbar(
        controller: _reportListController,
        thumbVisibility: true,
        child: ListView(
          controller: _reportListController,
          padding: const EdgeInsets.all(12),
          children: [
            ...grouped.entries.map((entry) => _groupCard(entry.key, entry.value)),
          ],
        ));
  }

  // ================= GROUP CARD =================
  Widget _groupCard(String group, List<ClosingItem> items) {
    final groupTotal = items.fold<double>(0, (s, e) => s + e.amount);

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Group: $group",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            _ScrollableTableWrapper(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                 columns: const [
                  DataColumn(label: Text("Item")),
                  DataColumn(label: Text("Brand")),
                  DataColumn(label: Text("Rate")),
                  DataColumn(label: Text("Opening")),
                  DataColumn(label: Text("IN")),
                  DataColumn(label: Text("Sale")),
                  DataColumn(label: Text("Damage")),
                  DataColumn(label: Text("Return")),
                  DataColumn(label: Text("Supplier Return Qty")),
                  DataColumn(label: Text("Closing")),
                  DataColumn(label: Text("Amount")),
                ],
                rows: items.map((e) {
                  return DataRow(
                    cells: [
                      DataCell(Text(e.name)),
                      DataCell(Text(e.brand)),
                      DataCell(Text(e.avgRate.toStringAsFixed(2))),
                      DataCell(Text(e.opening.toString())),
                      DataCell(Text(e.receive.toString())),
                      DataCell(Text(e.issue.toString())),
                      DataCell(Text(e.damage.toString())),
                      DataCell(Text(e.returned.toString())),
                      DataCell(Text(e.supplierReturnQty.toString())),
                      DataCell(Text(e.closing.toString())),
                      DataCell(Text(
                        e.amount.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Group Total : ${groupTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock In / Out Transactions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            _ScrollableTableWrapper(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                columns: const [
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Type")),
                  DataColumn(label: Text("Item")),
                  DataColumn(label: Text("Brand")),
                  DataColumn(label: Text("Ref No")),
                  DataColumn(label: Text("Qty In")),
                  DataColumn(label: Text("Qty Out")),
                  DataColumn(label: Text("Balance")),
                ],
                rows: ctrl.transactions.map((txn) {
                  final rawDate = DateTime.tryParse('${txn['txnDate'] ?? ''}');
                  final txnDate = rawDate?.toLocal();
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        txnDate == null
                             ? '--'
                            : DateFormat('dd-MMM-yyyy').format(txnDate),
                      )),
                      DataCell(Text('${txn['txnType'] ?? ''}')),
                      DataCell(Text(
                        '${txn['itemName'] ?? txn['itemCode'] ?? ''}',
                      )),
                      DataCell(Text('${txn['brand'] ?? ''}')),
                      DataCell(Text('${txn['refNo'] ?? ''}')),
                      DataCell(Text(
                        double.tryParse('${txn['qtyIn'] ?? 0}')?.toStringAsFixed(2) ?? '0.00',
                      )),
                      DataCell(Text(
                        double.tryParse('${txn['qtyOut'] ?? 0}')?.toStringAsFixed(2) ?? '0.00',
                      )),
                      DataCell(Text(
                        double.tryParse('${txn['balance'] ?? 0}')?.toStringAsFixed(2) ?? '0.00',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollableTableWrapper extends StatefulWidget {
  final Widget child;
  const _ScrollableTableWrapper({required this.child});

  @override
  State<_ScrollableTableWrapper> createState() => _ScrollableTableWrapperState();
}

class _ScrollableTableWrapperState extends State<_ScrollableTableWrapper> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}
