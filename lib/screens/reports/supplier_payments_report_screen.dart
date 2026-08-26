// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/supplier_payments_report_controller.dart';
import '../../utils/pdf_report_builder.dart';

class SupplierPaymentsReportScreen extends StatefulWidget {
  const SupplierPaymentsReportScreen({super.key});

  @override
  State<SupplierPaymentsReportScreen> createState() =>
      _SupplierPaymentsReportScreenState();
}

class _SupplierPaymentsReportScreenState extends State<SupplierPaymentsReportScreen> {
  final ctrl = SupplierPaymentsReportController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;
  String search = '';
  String selectedSupplierId = 'ALL';
  String selectedPaymentMode = 'ALL';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    fromDate = DateTime(today.year, today.month, 1);
    toDate = today;
    _initData();
  }

  Future<void> _initData() async {
    await ctrl.loadSuppliers();
    await _loadReportData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    if (fromDate == null || toDate == null) return;
    await ctrl.load(
      from: fromDate,
      to: toDate,
      supplierId: selectedSupplierId == 'ALL' ? null : selectedSupplierId,
      paymentMode: selectedPaymentMode == 'ALL' ? null : selectedPaymentMode,
      search: search,
    );
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
    final sheet = excel['Vendor Payments'];
    final rows = ctrl.transactions;

    final headers = [
      'Date',
      'Vendor Name',
      'Bill No',
      'Payment Mode',
      'Reference No',
      'Cash Paid',
      'Credit Adjusted',
      'Total Applied',
    ];

    for (var column = 0; column < headers.length; column++) {
      final cell = sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0));
      cell.value = exc.TextCellValue(headers[column]);
      cell.cellStyle = exc.CellStyle(bold: true);
    }

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rawDate = DateTime.tryParse('${row['payment_date'] ?? ''}')?.toLocal();
      final displayDate = rawDate == null
          ? ''
          : DateFormat('dd-MMM-yyyy').format(rawDate);

      final cashPaid = double.tryParse('${row['amount'] ?? 0}') ?? 0;
      final creditAdjusted = double.tryParse('${row['credit_adjusted'] ?? 0}') ?? 0;
      final totalApplied = cashPaid + creditAdjusted;

      final values = [
        displayDate,
        '${row['supplier']?['supplier_name'] ?? ''}',
        '${row['bill']?['bill_no'] ?? ''}',
        '${row['payment_mode'] ?? ''}',
        '${row['reference_no'] ?? ''}',
        _fmt(cashPaid),
        _fmt(creditAdjusted),
        _fmt(totalApplied),
      ];

      for (var column = 0; column < values.length; column++) {
        final cell = sheet.cell(exc.CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: index + 1,
        ));
        cell.value = exc.TextCellValue(values[column]);
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/VendorPaymentTransactionReport.xlsx');
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  Future<void> exportToPdf() async {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final rows = ctrl.transactions;
    final totalCashPaid = ctrl.totalPaid;
    final totalCreditAdjusted = ctrl.totalCreditAdjusted;
    final totalApplied = totalCashPaid + totalCreditAdjusted;

    await PdfReportBuilder.generateAndPrintReport(
      title: 'Supplier Payments Report',
      subtitle: 'From: ${fromDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(fromDate!)}  To: ${toDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(toDate!)}',
      headers: [
        'Date',
        'Supplier',
        'Bill No',
        'Payment Mode',
        'Reference No',
        'Cash Paid',
        'Credit Adjusted',
        'Total Applied',
      ],
      data: rows.map((row) {
        final rawDate = DateTime.tryParse('${row['payment_date'] ?? ''}')?.toLocal();
        final cashPaid = double.tryParse('${row['amount'] ?? 0}') ?? 0;
        final creditAdjusted = double.tryParse('${row['credit_adjusted'] ?? 0}') ?? 0;
        final applied = cashPaid + creditAdjusted;
        return [
          rawDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(rawDate),
          '${row['supplier']?['supplier_name'] ?? ''}',
          '${row['bill']?['bill_no'] ?? ''}',
          '${row['payment_mode'] ?? ''}',
          '${row['reference_no'] ?? ''}',
          currency.format(cashPaid),
          currency.format(creditAdjusted),
          currency.format(applied),
        ];
      }).toList(),
      kpis: [
        PdfKpiItem(label: 'Total Cash Paid', value: currency.format(totalCashPaid), color: PdfColor.fromHex('#166534')),
        PdfKpiItem(label: 'Total Credit Adjusted', value: currency.format(totalCreditAdjusted), color: PdfColor.fromHex('#2563EB')),
        PdfKpiItem(label: 'Total Applied Amount', value: currency.format(totalApplied), color: PdfColor.fromHex('#1E40AF')),
      ],
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.9),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.1),
        6: const pw.FlexColumnWidth(1.1),
        7: const pw.FlexColumnWidth(1.2),
      },
      pdfFileName: 'Supplier_Payments_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = ctrl.transactions;
    final totalCashPaid = ctrl.totalPaid;
    final totalCreditAdjusted = ctrl.totalCreditAdjusted;
    final totalApplied = totalCashPaid + totalCreditAdjusted;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Vendor Payment Transaction Report'),
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _summaryChip('Count', ctrl.transactionCount.toString()),
                      const SizedBox(width: 8),
                      _summaryChip('Cash Paid', 'Rs. ${_fmt(totalCashPaid)}'),
                      const SizedBox(width: 8),
                      _summaryChip('Credit Adjusted', 'Rs. ${_fmt(totalCreditAdjusted)}'),
                      const SizedBox(width: 8),
                      _summaryChip('Total Applied', 'Rs. ${_fmt(totalApplied)}'),
                    ],
                  ),
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
                      ? const Center(child: Text('No payment transactions found.'))
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
                                  DataColumn(label: Text('Vendor Name')),
                                  DataColumn(label: Text('Bill No')),
                                  DataColumn(label: Text('Payment Mode')),
                                  DataColumn(label: Text('Reference No')),
                                  DataColumn(label: Text('Cash Paid')),
                                  DataColumn(label: Text('Credit Adjusted')),
                                  DataColumn(label: Text('Total Applied')),
                                ],
                                rows: rows.map((row) {
                                  final rawDate = DateTime.tryParse(
                                    '${row['payment_date'] ?? ''}',
                                  )?.toLocal();
                                  final cashPaid = double.tryParse('${row['amount'] ?? 0}') ?? 0;
                                  final creditAdjusted = double.tryParse('${row['credit_adjusted'] ?? 0}') ?? 0;
                                  final totalAppliedRow = cashPaid + creditAdjusted;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        rawDate == null
                                            ? '--'
                                            : DateFormat('dd-MMM-yyyy')
                                                .format(rawDate),
                                      )),
                                      DataCell(Text(
                                        '${row['supplier']?['supplier_name'] ?? ''}',
                                      )),
                                      DataCell(Text('${row['bill']?['bill_no'] ?? ''}')),
                                      DataCell(Text('${row['payment_mode'] ?? ''}')),
                                      DataCell(Text('${row['reference_no'] ?? ''}')),
                                      DataCell(Text('Rs. ${_fmt(cashPaid)}')),
                                      DataCell(Text('Rs. ${_fmt(creditAdjusted)}')),
                                      DataCell(Text(
                                        'Rs. ${_fmt(totalAppliedRow)}',
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
            width: 250,
            child: DropdownButtonFormField<String>(
              initialValue: selectedSupplierId,
              decoration: const InputDecoration(
                labelText: 'Vendor / Supplier',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('All Vendors')),
                ...ctrl.suppliers.map(
                  (s) => DropdownMenuItem(
                    value: s.id.toString(),
                    child: Text(s.supplierName),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedSupplierId = value ?? 'ALL';
                });
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: selectedPaymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Modes')),
                DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                DropdownMenuItem(value: 'BANK', child: Text('BANK')),
                DropdownMenuItem(value: 'CARD', child: Text('CARD')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'CREDIT', child: Text('CREDIT')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedPaymentMode = value ?? 'ALL';
                });
              },
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search Bill / Reference',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                search = value;
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loadReportData,
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
