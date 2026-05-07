import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/sales/sales_controller.dart';
import '../../widgets/sale_bill_preview_dialog.dart';

class SubscriptionReportScreen extends StatefulWidget {
  const SubscriptionReportScreen({super.key});

  @override
  State<SubscriptionReportScreen> createState() =>
      _SubscriptionReportScreenState();
}

class _SubscriptionReportScreenState extends State<SubscriptionReportScreen> {
  final SalesController ctrl = SalesController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String _statusFilter = '';
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await ctrl.loadInitialData();
    await _reload();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _reload() async {
    final rows = await ctrl.listSubscriptions(
      search: _searchCtrl.text.trim(),
      status: _statusFilter,
    );
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Subscription Report'),
        centerTitle: true,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text('Excel'),
            onPressed: _rows.isEmpty ? null : _exportToExcel,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
            onPressed: _rows.isEmpty ? null : _exportToPdf,
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const Center(child: Text('No subscriptions found'))
                      : _table(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final searchWidth = isWide ? 320.0 : constraints.maxWidth;
        final statusWidth =
            isWide ? 220.0 : math.max(220.0, constraints.maxWidth);

        return Container(
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
                width: searchWidth,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _reload(),
                ),
              ),
              SizedBox(
                width: statusWidth,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter.isEmpty ? null : _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'SETTLED', child: Text('Settled')),
                    DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value ?? '');
                    _reload();
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Load'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _table() {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.8),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.05),
          3: FlexColumnWidth(1.05),
          4: FlexColumnWidth(0.9),
          5: FlexColumnWidth(0.9),
          6: FlexColumnWidth(0.9),
          7: FlexColumnWidth(0.9),
          8: FlexColumnWidth(0.95),
          9: FlexColumnWidth(0.95),
          10: FlexColumnWidth(1.0),
          11: FlexColumnWidth(1.0),
          12: FlexColumnWidth(0.95),
          13: FlexColumnWidth(0.95),
          14: FlexColumnWidth(1.05),
          15: FlexColumnWidth(0.9),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            children: const [
              _ReportHeaderCell('Customer'),
              _ReportHeaderCell('Item'),
              _ReportHeaderCell('Start'),
              _ReportHeaderCell('End'),
              _ReportHeaderCell('Total'),
              _ReportHeaderCell('Used'),
              _ReportHeaderCell('Skip'),
              _ReportHeaderCell('Left'),
              _ReportHeaderCell('Adv Qty'),
              _ReportHeaderCell('Use Qty'),
              _ReportHeaderCell('Adv Left'),
              _ReportHeaderCell('Adv Amt'),
              _ReportHeaderCell('Prepaid'),
              _ReportHeaderCell('Actual'),
              _ReportHeaderCell('Due'),
              _ReportHeaderCell('Status'),
            ],
          ),
          ..._rows.map((row) {
            final totalDays = _num(row['total_days']);
            final consumedDays = _num(row['consumed_days']);
            final skippedDays = _num(row['missed_days']);
            final daysLeft = _num(row['days_left']);
            final advanceQty = _num(row['advance_original_qty']);
            final consumedQty = _num(row['advance_consumed_qty']);
            final advanceLeftQty = _num(row['advance_remaining_qty']);
            final advanceLeftAmt = _num(row['advance_remaining_amount']);
            final prepaid = _num(row['prepaid_value']);
            final actual = _num(row['actual_value']);
            final outstanding = _num(row['outstanding_amount']);
            final status =
                row['active_subscription'] == true ? 'Active' : '${row['status'] ?? ''}';

            return TableRow(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              children: [
                _ReportCell(
                  (row['customer_name'] ?? row['customer_phone'] ?? '').toString(),
                  bold: true,
                  onTap: () => _showTimeline(row),
                ),
                _ReportCell((row['item_name'] ?? '').toString()),
                _ReportCell((row['start_date'] ?? '').toString()),
                _ReportCell((row['end_date'] ?? '').toString()),
                _ReportCell(totalDays.toStringAsFixed(totalDays % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(consumedDays.toStringAsFixed(consumedDays % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(skippedDays.toStringAsFixed(skippedDays % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(daysLeft.toStringAsFixed(daysLeft % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(advanceQty.toStringAsFixed(advanceQty % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(consumedQty.toStringAsFixed(consumedQty % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(
                    advanceLeftQty.toStringAsFixed(advanceLeftQty % 1 == 0 ? 0 : 2),
                    align: TextAlign.right),
                _ReportCell(advanceLeftAmt.toStringAsFixed(2),
                    align: TextAlign.right),
                _ReportCell(prepaid.toStringAsFixed(2), align: TextAlign.right),
                _ReportCell(actual.toStringAsFixed(2), align: TextAlign.right),
                _ReportCell(outstanding.toStringAsFixed(2), align: TextAlign.right),
                _ReportCell(status, align: TextAlign.center, bold: true),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showTimeline(Map<String, dynamic> row) async {
    final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final details = await ctrl.getSubscriptionLedger(id);
    if (!mounted) return;

    final consumptions = (details['consumptions'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final settlements = (details['settlements'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            '${row['customer_name'] ?? row['customer_phone'] ?? ''} timeline'),
        content: SizedBox(
          width: math.min(MediaQuery.of(dialogContext).size.width * 0.9, 980),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: ${row['item_name'] ?? ''}'),
                Text('Period: ${row['start_date']} to ${row['end_date']}'),
                const SizedBox(height: 16),
                const Text('Consumption',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (consumptions.isEmpty)
                  const Text('No consumption rows found.')
                else
                  ...consumptions.map((entry) {
                    final saleNo = (entry['sale_no'] ?? '').toString();
                    final saleId =
                        int.tryParse(entry['sale_id']?.toString() ?? '') ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${entry['txn_date']} | Qty ${entry['covered_qty']}'),
                      subtitle: Text(
                        'Rate ${entry['rate']} | Covered ${entry['covered_amount']} | Bill ${saleNo.isEmpty ? '-' : saleNo}',
                      ),
                      trailing: saleId > 0 && saleNo.isNotEmpty
                          ? TextButton(
                              onPressed: () => _showBillDetails(saleId),
                              child: const Text('Bill'),
                            )
                          : null,
                    );
                  }),
                const Divider(height: 28),
                const Text('Settlements',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (settlements.isEmpty) const Text('No settlement records.'),
                ...settlements.map((entry) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        '${entry['settlement_no'] ?? ''} | ${entry['settlement_date'] ?? ''}'),
                    subtitle: Text(
                      'Actual ${entry['gross_excess_amount']} | Bonus ${entry['bonus_amount']} | Due ${entry['total_due']}',
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBillDetails(int saleId) async {
    final sale = await ctrl.getSaleDetails(saleId);
    if (!mounted) return;
    await showSaleBillPreviewDialog(
      context,
      sale: sale,
    );
  }

  Future<void> _exportToExcel() async {
    final excel = exc.Excel.createExcel();
    final sheet = excel['Subscriptions'];
    const headers = [
      'Customer',
      'Item',
      'Start Date',
      'End Date',
      'Total Days',
      'Consumed Days',
      'Skipped Days',
      'Days Left',
      'Advance Qty',
      'Consumed Qty',
      'Advance Left Qty',
      'Advance Left Amt',
      'Prepaid Amt',
      'Actual Amt',
      'Outstanding Amt',
      'Status',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = exc.TextCellValue(headers[i]);
    }

    for (var row = 0; row < _rows.length; row++) {
      final entry = _rows[row];
      final values = [
        entry['customer_name'] ?? entry['customer_phone'] ?? '',
        entry['item_name'] ?? '',
        entry['start_date'] ?? '',
        entry['end_date'] ?? '',
        entry['total_days'] ?? '',
        entry['consumed_days'] ?? '',
        entry['missed_days'] ?? '',
        entry['days_left'] ?? '',
        entry['advance_original_qty'] ?? '',
        entry['advance_consumed_qty'] ?? '',
        entry['advance_remaining_qty'] ?? '',
        entry['advance_remaining_amount'] ?? '',
        entry['prepaid_value'] ?? '',
        entry['actual_value'] ?? '',
        entry['outstanding_amount'] ?? '',
        entry['status'] ?? '',
      ];
      for (var col = 0; col < values.length; col++) {
        sheet
            .cell(exc.CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: row + 1))
            .value = exc.TextCellValue(values[col].toString());
      }
    }

    final bytes = excel.save();
    if (bytes == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/subscription_report.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Subscription Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'Customer',
              'Item',
              'Start',
              'End',
              'Total',
              'Consumed',
              'Skipped',
              'Left',
              'Advance Qty',
              'Consumed Qty',
              'Advance Left Qty',
              'Advance Left Amt',
              'Prepaid Amt',
              'Actual Amt',
              'Outstanding Amt',
              'Status',
            ],
            data: _rows.map((row) {
              return [
                row['customer_name'] ?? row['customer_phone'] ?? '',
                row['item_name'] ?? '',
                row['start_date'] ?? '',
                row['end_date'] ?? '',
                row['total_days'] ?? '',
                row['consumed_days'] ?? '',
                row['missed_days'] ?? '',
                row['days_left'] ?? '',
                row['advance_original_qty'] ?? '',
                row['advance_consumed_qty'] ?? '',
                row['advance_remaining_qty'] ?? '',
                currency.format(_num(row['advance_remaining_amount'])),
                currency.format(_num(row['prepaid_value'])),
                currency.format(_num(row['actual_value'])),
                currency.format(_num(row['outstanding_amount'])),
                row['status'] ?? '',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}

class _ReportHeaderCell extends StatelessWidget {
  final String text;

  const _ReportHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReportCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool bold;
  final VoidCallback? onTap;

  const _ReportCell(
    this.text, {
    this.align = TextAlign.left,
    this.bold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cellText = Text(
      text,
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: onTap == null ? null : Theme.of(context).colorScheme.primary,
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: cellText,
      ),
    );
  }
}
