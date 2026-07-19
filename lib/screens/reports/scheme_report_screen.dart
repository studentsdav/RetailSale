import 'dart:io';

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/reports/scheme_report_controller.dart';
import '../../models/inventory/sale_scheme_model.dart';

class SchemeReportScreen extends StatefulWidget {
  const SchemeReportScreen({super.key});

  @override
  State<SchemeReportScreen> createState() => _SchemeReportScreenState();
}

class _SchemeReportScreenState extends State<SchemeReportScreen> {
  final ctrl = SchemeReportController();
  final _dateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.init();
    _dateCtrl.text = DateFormat('dd-MMM-yyyy').format(ctrl.asOfDate);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Scheme Report'),
        centerTitle: true,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text('Excel'),
            onPressed: exportToExcel,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
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
                  if (ctrl.selectedScheme == null) {
                    return const Center(child: Text('Select a scheme'));
                  }
                  if (ctrl.rows.isEmpty) {
                    return const Center(child: Text('No data'));
                  }
                  return _table();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard() {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<SaleScheme>(
                value: ctrl.selectedScheme,
                items: ctrl.schemes
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.schemeName),
                      ),
                    )
                    .toList(),
                onChanged: (s) async {
                  ctrl.selectedScheme = s;
                  await ctrl.loadReport();
                },
                decoration: const InputDecoration(labelText: 'Scheme'),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'As Of Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: ctrl.asOfDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    ctrl.asOfDate = picked;
                    _dateCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                    await ctrl.loadReport();
                  }
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: ctrl.reportFilter,
                decoration: const InputDecoration(labelText: 'Status Filter'),
                items: const [
                  DropdownMenuItem(
                    value: 'RUNNING',
                    child: Text('Running'),
                  ),
                  DropdownMenuItem(
                    value: 'CONSUMED',
                    child: Text('Consumed'),
                  ),
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  ctrl.reportFilter = value;
                  await ctrl.loadReport();
                },
              ),
            ),
            FilledButton.icon(
              onPressed: ctrl.selectedScheme == null ? null : ctrl.loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Load'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          columns: const [
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Start')),
            DataColumn(label: Text('Cycle Start')),
            DataColumn(label: Text('Cycle End')),
            DataColumn(label: Text('Consumed Qty')),
            DataColumn(label: Text('Left Qty')),
            DataColumn(label: Text('Qualified Days')),
            DataColumn(label: Text('Days Left')),
            DataColumn(label: Text('Missing Days')),
          ],
          rows: ctrl.rows.map((r) {
            final e = r.enrollment;
            final p = r.progress ?? const {};
            final customerName = (e['customer_name'] ?? '').toString();
            final phone = (e['customer_phone'] ?? '').toString();
            final start = (e['start_date'] ?? '').toString();
            final cycleStart = (p['cycle_start'] ?? '').toString();
            final cycleEnd = (p['cycle_end'] ?? '').toString();
            final consumedQty = (p['consumed_qty'] ?? p['total_qty'] ?? 0).toString();
            final leftQtyNum = _num(p['remaining_qty']);
            final leftQty =
                leftQtyNum.toStringAsFixed(leftQtyNum % 1 == 0 ? 0 : 2);
            final daysUsed = (p['qualified_days'] ?? p['days_elapsed'] ?? 0).toString();
            final daysLeft = (p['days_left'] ?? 0).toString();
            final missingDays = (p['missing_days'] as List? ?? const []).length;

            final leftColor =
                leftQtyNum <= 0 ? Colors.green.shade700 : Colors.red.shade700;
            final missingColor =
                missingDays == 0 ? Colors.green.shade700 : Colors.red.shade700;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => _showCustomerCycleDetailDialog(r),
                ),
                DataCell(Text(phone)),
                DataCell(Text(start)),
                DataCell(Text(cycleStart)),
                DataCell(Text(cycleEnd)),
                DataCell(Text(consumedQty)),
                DataCell(Text(
                  leftQty,
                  style: TextStyle(
                    color: leftColor,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                DataCell(Text(daysUsed)),
                DataCell(Text(daysLeft)),
                DataCell(Text(
                  '$missingDays',
                  style: TextStyle(
                    color: missingColor,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showCustomerCycleDetailDialog(SchemeReportRow row) async {
    final scheme = ctrl.selectedScheme;
    final e = row.enrollment;
    final customerName = (e['customer_name'] ?? '').toString();
    final customerPhone = (e['customer_phone'] ?? '').toString();
    final customerGstin = (e['customer_gstin'] ?? '').toString();
    if (scheme == null) return;

    Map<String, dynamic> detail = const {};
    try {
      detail = await ctrl.loadCycleDetail(
        enrollmentId: e['id'],
        customerName: customerName,
        customerPhone: customerPhone,
        customerGstin: customerGstin,
        date: ctrl.asOfDate,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load cycle detail')),
      );
      return;
    }

    if (!mounted) return;
    final progress = Map<String, dynamic>.from(detail['progress'] ?? const {});
    final days = (detail['days'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final cycleStart = (progress['cycle_start'] ?? '').toString();
    final cycleEnd = (progress['cycle_end'] ?? '').toString();
    final consumedQty = _num(progress['consumed_qty']);
    final leftQty = _num(progress['remaining_qty']);
    final requiredDailyQty = _num(progress['required_daily_qty']);
    final requiredTotalQty = _num(progress['required_total_qty']);
    final daysUsed = _num(progress['days_elapsed']);
    final daysLeft = _num(progress['days_left']);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cycle Detail - ${scheme.schemeName}'),
        content: SizedBox(
          width: 980,
          height: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: ${customerName.isEmpty ? 'Walk-in' : customerName} ${customerPhone.isEmpty ? '' : '($customerPhone)'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('Cycle: $cycleStart to $cycleEnd'),
                Text('Required per day: ${requiredDailyQty.toStringAsFixed(requiredDailyQty % 1 == 0 ? 0 : 2)} | Cycle target: ${requiredTotalQty.toStringAsFixed(requiredTotalQty % 1 == 0 ? 0 : 2)}'),
                Text('Consumed: ${consumedQty.toStringAsFixed(consumedQty % 1 == 0 ? 0 : 2)} | Left: ${leftQty.toStringAsFixed(leftQty % 1 == 0 ? 0 : 2)}'),
                Text('Qualified days: ${daysUsed.toStringAsFixed(0)} | Days left: ${daysLeft.toStringAsFixed(0)}'),
                const SizedBox(height: 16),
                if (days.isEmpty)
                  const Text('No cycle days found.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Required Qty')),
                        DataColumn(label: Text('Consumed Qty')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Bills')),
                      ],
                      rows: days.map((day) {
                        final date = (day['date'] ?? '').toString();
                        final requiredQty = _num(day['required_qty']);
                        final dayConsumed = _num(day['consumed_qty']);
                        final met = day['met'] == true;
                        final missed = day['missed'] == true;
                        final bills = (day['bills'] as List? ?? const [])
                            .map((e) => Map<String, dynamic>.from(e))
                            .toList();
                        return DataRow(
                          cells: [
                            DataCell(Text(date)),
                            DataCell(Text(requiredQty.toStringAsFixed(requiredQty % 1 == 0 ? 0 : 2))),
                            DataCell(Text(dayConsumed.toStringAsFixed(dayConsumed % 1 == 0 ? 0 : 2))),
                            DataCell(
                              Text(
                                met ? 'Met' : (missed ? 'Missed' : 'Short'),
                                style: TextStyle(
                                  color: met ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 340,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: bills.isEmpty
                                        ? [const Text('-')]
                                        : bills.map((bill) {
                                            final saleId = int.tryParse(bill['sale_id']?.toString() ?? '') ?? 0;
                                            final saleNo = (bill['sale_no'] ?? '').toString();
                                            return OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: const Size(0, 30),
                                              ),
                                              onPressed: saleId <= 0 ? null : () => _showBillDetails(saleId),
                                              child: Text(saleNo.isEmpty ? 'Bill' : saleNo),
                                            );
                                          }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBillDetails(int saleId) async {
    Map<String, dynamic> sale = const {};
    try {
      sale = await ctrl.loadSaleDetails(saleId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load bill')),
      );
      return;
    }
    if (!mounted) return;

    final items = (sale['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final saleNo = (sale['sale_no'] ?? '').toString();
    final customerName = (sale['customer_name'] ?? '').toString();
    final saleDate = DateTime.tryParse((sale['sale_date'] ?? '').toString());

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill $saleNo'),
        content: SizedBox(
          width: 900,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${customerName.isEmpty ? 'Walk-in' : customerName}'),
                Text('Date: ${saleDate == null ? '--' : DateFormat('dd-MMM-yyyy').format(saleDate)}'),
                Text('Status: ${(sale['status'] ?? '').toString()}'),
                Text('Net Amount: ${(sale['net_amount'] ?? 0).toString()}'),
                const SizedBox(height: 16),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text('No items found.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Rate')),
                        DataColumn(label: Text('Amount')),
                      ],
                      rows: items.map((item) {
                        final name = (item['item_name'] ?? '').toString();
                        final qty = _num(item['qty']);
                        final rate = _num(item['rate']);
                        final amount = _num(item['net_amount'] ?? item['line_total']);
                        return DataRow(
                          cells: [
                            DataCell(Text(name)),
                            DataCell(Text(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2))),
                            DataCell(Text(rate.toStringAsFixed(2))),
                            DataCell(Text(amount.toStringAsFixed(2))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> exportToExcel() async {
    if (ctrl.selectedScheme == null || ctrl.rows.isEmpty) return;

    final excel = exc.Excel.createExcel();
    final sheet = excel['Scheme'];

    sheet.appendRow([
      exc.TextCellValue('Customer'),
      exc.TextCellValue('Phone'),
      exc.TextCellValue('Start Date'),
      exc.TextCellValue('Cycle Start'),
      exc.TextCellValue('Cycle End'),
      exc.TextCellValue('Consumed Qty'),
      exc.TextCellValue('Left Qty'),
      exc.TextCellValue('Qualified Days'),
      exc.TextCellValue('Days Left'),
      exc.TextCellValue('Missing Days'),
    ]);

    for (final r in ctrl.rows) {
      final e = r.enrollment;
      final p = r.progress ?? const {};
      sheet.appendRow([
        exc.TextCellValue((e['customer_name'] ?? '').toString()),
        exc.TextCellValue((e['customer_phone'] ?? '').toString()),
        exc.TextCellValue((e['start_date'] ?? '').toString()),
        exc.TextCellValue((p['cycle_start'] ?? '').toString()),
        exc.TextCellValue((p['cycle_end'] ?? '').toString()),
        exc.TextCellValue((p['consumed_qty'] ?? p['total_qty'] ?? 0).toString()),
        exc.TextCellValue((p['remaining_qty'] ?? 0).toString()),
        exc.TextCellValue((p['qualified_days'] ?? p['days_elapsed'] ?? 0).toString()),
        exc.TextCellValue((p['days_left'] ?? 0).toString()),
        exc.TextCellValue(((p['missing_days'] as List? ?? const []).length).toString()),
      ]);
    }

    final directory = await getTemporaryDirectory();
    final fileName = 'scheme_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final path = '${directory.path}/$fileName';
    final file = File(path);
    final bytes = excel.encode();
    if (bytes == null) return;
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(path);
  }

  Future<void> exportToPdf() async {
    if (ctrl.selectedScheme == null || ctrl.rows.isEmpty) return;
    final pdf = pw.Document();
    final schemeName = ctrl.selectedScheme!.schemeName;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Scheme Report: $schemeName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Customer',
              'Phone',
              'Start',
              'Cycle Start',
              'Cycle End',
              'Consumed',
              'Left',
              'Qualified Days',
              'Days Left',
              'Missing',
            ],
            data: ctrl.rows.map((r) {
              final e = r.enrollment;
              final p = r.progress ?? const {};
              return [
                (e['customer_name'] ?? '').toString(),
                (e['customer_phone'] ?? '').toString(),
                (e['start_date'] ?? '').toString(),
                (p['cycle_start'] ?? '').toString(),
                (p['cycle_end'] ?? '').toString(),
                (p['consumed_qty'] ?? p['total_qty'] ?? 0).toString(),
                (p['remaining_qty'] ?? 0).toString(),
                (p['qualified_days'] ?? p['days_elapsed'] ?? 0).toString(),
                (p['days_left'] ?? 0).toString(),
                ((p['missing_days'] as List? ?? const []).length).toString(),
              ];
            }).toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'Scheme_Report',
      onLayout: (format) async => pdf.save(),
    );
  }
}
