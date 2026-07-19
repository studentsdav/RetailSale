import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/stock_ledger_report_controller.dart';

class StockLedgerReportScreen extends StatefulWidget {
  const StockLedgerReportScreen({super.key});

  @override
  State<StockLedgerReportScreen> createState() =>
      _StockLedgerReportScreenState();
}

class _StockLedgerReportScreenState extends State<StockLedgerReportScreen> {
  final ctrl = StockLedgerReportController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;
  String search = '';
  String selectedTxnType = 'ALL';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    fromDate = DateTime(today.year, today.month, 1);
    toDate = today;
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (fromDate == null || toDate == null) return;
    await ctrl.load(from: fromDate, to: toDate);
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {});
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    final query = search.trim().toLowerCase();
    return ctrl.transactions.where((row) {
      final txnType = '${row['txnType'] ?? ''}'.toUpperCase();
      final itemText =
          '${row['itemName'] ?? ''} ${row['itemCode'] ?? ''} ${row['refNo'] ?? ''}'
              .toLowerCase();

      final matchesType =
          selectedTxnType == 'ALL' || txnType == selectedTxnType;
      final matchesSearch = query.isEmpty || itemText.contains(query);
      return matchesType && matchesSearch;
    }).toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (fromDate ?? DateTime.now())
        : (toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        fromDate = picked;
      } else {
        toDate = picked;
      }
    });
  }

  String _fmt(dynamic value) {
    final number = double.tryParse('${value ?? 0}') ?? 0;
    return number.toStringAsFixed(2);
  }

  Future<void> exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Stock Ledger'];
    final rows = _filteredTransactions;

    final headers = [
      'Date',
      'Type',
      'Item',
      'Brand',
      'Ref No',
      'Qty In',
      'Qty Out',
      'Balance',
    ];

    for (var column = 0; column < headers.length; column++) {
      sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
        ..value = exc.TextCellValue(headers[column])
        ..cellStyle = exc.CellStyle(bold: true);
    }

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rawDate = DateTime.tryParse('${row['txnDate'] ?? ''}')?.toLocal();
      final displayDate = rawDate == null
          ? ''
          : DateFormat('dd-MMM-yyyy').format(rawDate);

      final values = [
        displayDate,
        '${row['txnType'] ?? ''}',
        '${row['itemName'] ?? row['itemCode'] ?? ''}',
        '${row['brand'] ?? ''}',
        '${row['refNo'] ?? ''}',
        _fmt(row['qtyIn']),
        _fmt(row['qtyOut']),
        _fmt(row['balance']),
      ];

      for (var column = 0; column < values.length; column++) {
        sheet
            .cell(exc.CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: index + 1,
            ))
          ..value = exc.TextCellValue(values[column]);
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/StockLedgerReport.xlsx');
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final rows = _filteredTransactions;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Stock Ledger Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'From: ${fromDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(fromDate!)}'
            '  To: ${toDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(toDate!)}',
          ),
          pw.Table.fromTextArray(
            headers: const [
              'Date',
              'Type',
              'Item',
              'Brand',
              'Ref No',
              'Qty In',
              'Qty Out',
              'Balance',
            ],
            data: rows.map((row) {
              final rawDate = DateTime.tryParse('${row['txnDate'] ?? ''}')
                  ?.toLocal();
              return [
                rawDate == null
                    ? '--'
                    : DateFormat('dd-MMM-yyyy').format(rawDate),
                '${row['txnType'] ?? ''}',
                '${row['itemName'] ?? row['itemCode'] ?? ''}',
                '${row['brand'] ?? ''}',
                '${row['refNo'] ?? ''}',
                _fmt(row['qtyIn']),
                _fmt(row['qtyOut']),
                _fmt(row['balance']),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'Stock_Ledger_Report', onLayout: (_) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredTransactions;
    final totalIn = rows.fold<double>(
      0,
      (sum, row) => sum + (double.tryParse('${row['qtyIn'] ?? 0}') ?? 0),
    );
    final totalOut = rows.fold<double>(
      0,
      (sum, row) => sum + (double.tryParse('${row['qtyOut'] ?? 0}') ?? 0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Stock Ledger Report'),
        centerTitle: true,
        actions: [
          Tooltip(
            message: 'Export Excel',
            child: ElevatedButton.icon(
              onPressed: rows.isEmpty ? null : exportToExcel,
              icon: const Icon(Icons.file_download),
              label: const Text('Excel'),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Export PDF',
            child: ElevatedButton.icon(
              onPressed: rows.isEmpty ? null : exportToPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF'),
            ),
          ),
          const SizedBox(width: 12),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _summaryChip('Rows', rows.length.toString()),
                    const SizedBox(width: 8),
                    _summaryChip('IN', _fmt(totalIn)),
                    const SizedBox(width: 8),
                    _summaryChip('OUT', _fmt(totalOut)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: rows.isEmpty
                      ? const Center(child: Text('No stock transactions found.'))
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade200,
                                ),
                                 columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Item')),
                                  DataColumn(label: Text('Brand')),
                                  DataColumn(label: Text('Ref No')),
                                  DataColumn(label: Text('Qty In')),
                                  DataColumn(label: Text('Qty Out')),
                                  DataColumn(label: Text('Balance')),
                                ],
                                rows: rows.map((row) {
                                  final rawDate = DateTime.tryParse(
                                    '${row['txnDate'] ?? ''}',
                                  )?.toLocal();
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        rawDate == null
                                            ? '--'
                                            : DateFormat('dd-MMM-yyyy')
                                                .format(rawDate),
                                      )),
                                      DataCell(Text('${row['txnType'] ?? ''}')),
                                      DataCell(Text(
                                        '${row['itemName'] ?? row['itemCode'] ?? ''}',
                                      )),
                                      DataCell(Text('${row['brand'] ?? ''}')),
                                      DataCell(Text('${row['refNo'] ?? ''}')),
                                      DataCell(Text(_fmt(row['qtyIn']))),
                                      DataCell(Text(_fmt(row['qtyOut']))),
                                      DataCell(Text(
                                        _fmt(row['balance']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: true),
              icon: const Icon(Icons.date_range),
              label: Text(
                fromDate == null
                    ? 'From'
                    : DateFormat('dd-MMM-yyyy').format(fromDate!),
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: false),
              icon: const Icon(Icons.event),
              label: Text(
                toDate == null ? 'To' : DateFormat('dd-MMM-yyyy').format(toDate!),
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search item / bill / ref',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                search = value;
                _applyFilter();
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: selectedTxnType,
              decoration: const InputDecoration(
                labelText: 'Transaction Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                DropdownMenuItem(value: 'IN', child: Text('IN')),
                DropdownMenuItem(value: 'ISSUE', child: Text('ISSUE / SALE')),
                DropdownMenuItem(value: 'SALE', child: Text('SALE')),
                DropdownMenuItem(value: 'RETURN', child: Text('RETURN')),
                DropdownMenuItem(value: 'DAMAGE', child: Text('DAMAGE')),
                DropdownMenuItem(
                  value: 'SUPPLIER_RETURN',
                  child: Text('SUPPLIER RETURN'),
                ),
                DropdownMenuItem(
                  value: 'OPENING',
                  child: Text('OPENING'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedTxnType = value ?? 'ALL';
                });
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white,
    );
  }
}
