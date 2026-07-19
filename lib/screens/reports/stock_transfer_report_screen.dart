import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/stock_transfer_report_controller.dart';

class StockTransferReportScreen extends StatefulWidget {
  const StockTransferReportScreen({super.key});

  @override
  State<StockTransferReportScreen> createState() =>
      _StockTransferReportScreenState();
}

class _StockTransferReportScreenState extends State<StockTransferReportScreen> {
  final ctrl = StockTransferReportController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? fromDate : toDate;
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
        _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
      } else {
        toDate = picked;
        _toCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
      }
    });
  }

  Future<void> _onGenerate() async {
    ctrl.fromDate = fromDate;
    ctrl.toDate = toDate;
    ctrl.search = _searchCtrl.text.trim();
    await ctrl.load();
  }

  String _fmt(dynamic value) {
    final number = double.tryParse('${value ?? 0}') ?? 0;
    return number.toStringAsFixed(2);
  }

  String _dateText(dynamic value) {
    final raw = DateTime.tryParse('${value ?? ''}')?.toLocal();
    return raw == null ? '--' : DateFormat('dd-MMM-yyyy').format(raw);
  }

  Future<void> _exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Stock Transfer'];
    final rows = ctrl.transfers;

    final headers = [
      'Date',
      'Ref No',
      'Source Item',
      'Source Unit',
      'Pack Count',
      'Loose Item',
      'Loose Unit',
      'Loose Qty',
    ];

    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
        ..value = exc.TextCellValue(headers[column])
        ..cellStyle = exc.CellStyle(bold: true);
    }

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final values = [
        _dateText(row['transfer_date']),
        '${row['ref_no'] ?? ''}',
        '${row['source_item_name'] ?? row['source_item_code'] ?? ''}',
        '${row['source_unit'] ?? ''}',
        _fmt(row['pack_count']),
        '${row['loose_item_name'] ?? row['loose_item_code'] ?? ''}',
        '${row['loose_unit'] ?? ''}',
        _fmt(row['loose_qty']),
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
    final file = File('${directory.path}/StockTransferReport.xlsx');
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final rows = ctrl.transfers;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Stock Transfer Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'From: ${DateFormat('dd-MMM-yyyy').format(fromDate)}  To: ${DateFormat('dd-MMM-yyyy').format(toDate)}',
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'Date',
              'Ref No',
              'Source Item',
              'Source Unit',
              'Pack Count',
              'Loose Item',
              'Loose Unit',
              'Loose Qty',
            ],
            data: rows.map((row) {
              return [
                _dateText(row['transfer_date']),
                '${row['ref_no'] ?? ''}',
                '${row['source_item_name'] ?? row['source_item_code'] ?? ''}',
                '${row['source_unit'] ?? ''}',
                _fmt(row['pack_count']),
                '${row['loose_item_name'] ?? row['loose_item_code'] ?? ''}',
                '${row['loose_unit'] ?? ''}',
                _fmt(row['loose_qty']),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(name: 'Stock_Transfer_Report', onLayout: (_) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Stock Transfer Report'),
        centerTitle: true,
        actions: [
          ElevatedButton.icon(
            onPressed: ctrl.transfers.isEmpty ? null : _exportToExcel,
            icon: const Icon(Icons.file_download),
            label: const Text('Excel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: ctrl.transfers.isEmpty ? null : _exportToPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
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

          final rows = ctrl.transfers;

          return Column(
            children: [
              _filterCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _summaryChip('Transfers', rows.length.toString()),
                    const SizedBox(width: 8),
                    _summaryChip('Packs', _fmt(ctrl.totalPackCount)),
                    const SizedBox(width: 8),
                    _summaryChip('Loose Qty', _fmt(ctrl.totalLooseQty)),
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
                      ? const Center(child: Text('No stock transfers found.'))
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
                                  DataColumn(label: Text('Ref No')),
                                  DataColumn(label: Text('Source Item')),
                                  DataColumn(label: Text('Source Unit')),
                                  DataColumn(label: Text('Pack Count')),
                                  DataColumn(label: Text('Loose Item')),
                                  DataColumn(label: Text('Loose Unit')),
                                  DataColumn(label: Text('Loose Qty')),
                                ],
                                rows: rows.map((row) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(_dateText(row['transfer_date']))),
                                      DataCell(Text('${row['ref_no'] ?? ''}')),
                                      DataCell(Text(
                                        '${row['source_item_name'] ?? row['source_item_code'] ?? ''}',
                                      )),
                                      DataCell(Text('${row['source_unit'] ?? ''}')),
                                      DataCell(Text(_fmt(row['pack_count']))),
                                      DataCell(Text(
                                        '${row['loose_item_name'] ?? row['loose_item_code'] ?? ''}',
                                      )),
                                      DataCell(Text('${row['loose_unit'] ?? ''}')),
                                      DataCell(Text(
                                        _fmt(row['loose_qty']),
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
            child: TextField(
              controller: _fromCtrl,
              readOnly: true,
              onTap: () => _pickDate(isFrom: true),
              decoration: const InputDecoration(
                labelText: 'From Date',
                prefixIcon: Icon(Icons.date_range),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: TextField(
              controller: _toCtrl,
              readOnly: true,
              onTap: () => _pickDate(isFrom: false),
              decoration: const InputDecoration(
                labelText: 'To Date',
                prefixIcon: Icon(Icons.event),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search ref / item',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _onGenerate,
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
