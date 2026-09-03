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
import '../../core/config/date_time_service.dart';
import '../../utils/branding_storage.dart';
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
  final ScrollController _horizontalScrollController = ScrollController();

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
    _horizontalScrollController.dispose();
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
            _summaryCards(),
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

  Widget _summaryCards() {
    int activeCount = 0;
    double prepaidSum = 0;
    double remainingSum = 0;
    double consumedQtySum = 0;

    for (final row in _rows) {
      if (row['active_subscription'] == true || row['status'] == 'ACTIVE') {
        activeCount++;
      }
      prepaidSum += _num(row['prepaid_value']);
      remainingSum += _num(row['advance_remaining_amount']);
      consumedQtySum += _num(row['advance_consumed_qty']);
    }

    Widget card(String title, String value, Color color, IconData icon) {
      return Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        card('Active Subscriptions', activeCount.toString(), const Color(0xFF15803D), Icons.subscriptions),
        card('Total Prepaid', 'Rs. ${prepaidSum.toStringAsFixed(2)}', const Color(0xFF2563EB), Icons.payments),
        card('Remaining Balance', 'Rs. ${remainingSum.toStringAsFixed(2)}', const Color(0xFFD97706), Icons.account_balance_wallet),
        card('Delivered Qty', consumedQtySum.toStringAsFixed(consumedQtySum % 1 == 0 ? 0 : 2), const Color(0xFF7C3AED), Icons.local_shipping),
      ],
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
    return Scrollbar(
      controller: _horizontalScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1550,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
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
                    _ReportHeaderCell('Adv Left Qty'),
                    _ReportHeaderCell('Adv Left Amt'),
                    _ReportHeaderCell('Prepaid'),
                    _ReportHeaderCell('Adv Used Amt'),
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
                  final actual = _num(row['advance_consumed_amount'] > 0 ? row['advance_consumed_amount'] : row['actual_value']);
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
                      _ReportCell(() {
                        final brand = row['item']?['brand']?.toString() ?? '';
                        final itemName = row['item_name'] ?? '';
                        return brand.isNotEmpty ? '$itemName ($brand)' : '$itemName';
                      }()),
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
          ),
        ),
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
                Text(() {
                  final brand = row['item']?['brand']?.toString() ?? '';
                  final itemName = row['item_name'] ?? '';
                  return brand.isNotEmpty ? 'Item: $itemName ($brand)' : 'Item: $itemName';
                }()),
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
        (() {
          final brand = entry['item']?['brand']?.toString() ?? '';
          final itemName = entry['item_name'] ?? '';
          return brand.isNotEmpty ? '$itemName ($brand)' : '$itemName';
        }()).toString(),
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
    final nowStr = DateTimeService.instance.formatNow('dd-MMM-yyyy hh:mm a');

    final branding = await BrandingStorage.getCurrentBrandingContext();
    final logo = await BrandingStorage.loadPdfLogo(branding?.logoPath);

    int activeCount = 0;
    double prepaidSum = 0;
    double remainingSum = 0;
    double consumedQtySum = 0;

    for (final row in _rows) {
      if (row['active_subscription'] == true || row['status'] == 'ACTIVE') {
        activeCount++;
      }
      prepaidSum += _num(row['prepaid_value']);
      remainingSum += _num(row['advance_remaining_amount']);
      consumedQtySum += _num(row['advance_consumed_qty']);
    }

    final headers = [
      'Customer',
      'Item',
      'Start',
      'End',
      'Days (T/U/S/L)',
      'Adv Qty',
      'Use Qty',
      'Left Qty',
      'Adv Left Amt',
      'Prepaid',
      'Adv Used Amt',
      'Due',
      'Status',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (context) {
          return pw.Column(
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
                            'SUBSCRIPTION REPORT',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#2563EB'),
                            ),
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
                        'Total Records: ${_rows.length}',
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
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RetailSale POS — Subscription Report',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // KPI Summary Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfKpiBlock('Active Subscriptions', activeCount.toString(), PdfColor.fromHex('#166534')),
                _pdfKpiBlock('Total Prepaid', currency.format(prepaidSum), PdfColor.fromHex('#1E40AF')),
                _pdfKpiBlock('Remaining Balance', currency.format(remainingSum), PdfColor.fromHex('#D97706')),
                _pdfKpiBlock('Delivered Qty', consumedQtySum.toStringAsFixed(consumedQtySum % 1 == 0 ? 0 : 2), PdfColor.fromHex('#6B21A8')),
              ],
            ),
          ),

          // Styled Table
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: _rows.map((row) {
              final totalDays = _num(row['total_days']);
              final consumedDays = _num(row['consumed_days']);
              final missedDays = _num(row['missed_days']);
              final daysLeft = _num(row['days_left']);

              final brand = row['item']?['brand']?.toString() ?? '';
              final itemName = row['item_name'] ?? '';
              final fullItemName = brand.isNotEmpty ? '$itemName\n($brand)' : '$itemName';
              final custName = (row['customer_name'] ?? '').toString();
              final custPhone = (row['customer_phone'] ?? '').toString();
              final custDisplay = custPhone.isNotEmpty ? '$custName\n$custPhone' : custName;

              final status = row['active_subscription'] == true ? 'Active' : '${row['status'] ?? ''}';

              return [
                custDisplay,
                fullItemName,
                (row['start_date'] ?? '').toString(),
                (row['end_date'] ?? '').toString(),
                '${totalDays.toStringAsFixed(0)} / ${consumedDays.toStringAsFixed(0)} / ${missedDays.toStringAsFixed(0)} / ${daysLeft.toStringAsFixed(0)}',
                _num(row['advance_original_qty']).toStringAsFixed(_num(row['advance_original_qty']) % 1 == 0 ? 0 : 2),
                _num(row['advance_consumed_qty']).toStringAsFixed(_num(row['advance_consumed_qty']) % 1 == 0 ? 0 : 2),
                _num(row['advance_remaining_qty']).toStringAsFixed(_num(row['advance_remaining_qty']) % 1 == 0 ? 0 : 2),
                currency.format(_num(row['advance_remaining_amount'])),
                currency.format(_num(row['prepaid_value'])),
                currency.format(_num(row['advance_consumed_amount'] > 0 ? row['advance_consumed_amount'] : row['actual_value'])),
                currency.format(_num(row['outstanding_amount'])),
                status.toUpperCase(),
              ];
            }).toList(),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E293B'),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 7.0,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
              9: pw.Alignment.centerRight,
              10: pw.Alignment.centerRight,
              11: pw.Alignment.centerRight,
              12: pw.Alignment.center,
            },
            rowDecoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#CBD5E1'),
              width: 0.5,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(0.6),
              6: const pw.FlexColumnWidth(0.6),
              7: const pw.FlexColumnWidth(0.6),
              8: const pw.FlexColumnWidth(1.1),
              9: const pw.FlexColumnWidth(1.1),
              10: const pw.FlexColumnWidth(1.1),
              11: const pw.FlexColumnWidth(0.7),
              12: const pw.FlexColumnWidth(0.7),
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'Subscription_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      onLayout: (_) => pdf.save(),
    );
  }

  pw.Widget _pdfKpiBlock(String label, String value, PdfColor valueColor) {
    return pw.Column(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
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
