import 'dart:io';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/sales_report_controller.dart';
import '../../controllers/reports/store_analysis_controller.dart';
import '../../models/reports/sales_report_model.dart';

class StoreAnalysisScreen extends StatefulWidget {
  const StoreAnalysisScreen({super.key});

  @override
  State<StoreAnalysisScreen> createState() => _StoreAnalysisScreenState();
}

class _StoreAnalysisScreenState extends State<StoreAnalysisScreen> {
  final StoreAnalysisController _controller = StoreAnalysisController();
  final SalesReportController _salesController = SalesReportController();

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  int _selectedTabIndex = 0;
  bool _isLoading = false;

  late Future<List<RfmSegmentPoint>> _rfmFuture;
  late Future<List<SalesTrendPoint>> _trendFuture;
  late Future<List<MarketBasketPoint>> _basketFuture;
  late Future<List<TopCustomerItemPoint>> _topCustomerItemsFuture;

  final TooltipBehavior _rfmTooltip = TooltipBehavior(enable: true);
  final TooltipBehavior _trendTooltip = TooltipBehavior(enable: true);
  final TooltipBehavior _basketTooltip = TooltipBehavior(enable: true);
  final ZoomPanBehavior _zoomPan = ZoomPanBehavior(
    enablePinching: true,
    enablePanning: true,
    enableDoubleTapZooming: true,
    zoomMode: ZoomMode.x,
  );

  final List<String> _tabNames = [
    'Marketing & Growth',
    'Financial & Accounting',
    'GST Compliance',
    'Inventory Velocity',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _isLoading = true);
    _rfmFuture = _controller.fetchRfmSegments();
    _trendFuture = _controller.fetchSalesTrend();
    _basketFuture = _controller.fetchMarketBasket();
    _topCustomerItemsFuture = _controller.fetchTopCustomerItems();
    _salesController.load().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Color _segmentColor(String segment) {
    switch (segment.trim().toLowerCase()) {
      case 'champions':
        return const Color(0xFF16A34A);
      case 'at-risk':
        return const Color(0xFFEAB308);
      case 'churned':
        return const Color(0xFFDC2626);
      case 'new':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  double _toDoubleSafe(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _pdfMoney(double val) => val.toStringAsFixed(2);
  List<SalesReport> get _sales => _salesController.list;

  double get _totalRevenue => _sales.fold(0.0, (s, sale) => s + sale.netAmount);
  double get _taxableAmount => _sales.fold(0.0, (s, sale) => s + sale.taxableAmount);
  double get _totalGst => _sales.fold(0.0, (s, sale) => s + sale.totalTax);
  double get _totalDiscount => _sales.fold(0.0, (s, sale) => s + sale.totalDiscount);
  double get _subTotal => _sales.fold(0.0, (s, sale) => s + sale.subTotal);

  Map<int, ({double taxableValue, double taxAmount})> get _realTaxBands {
    final Map<int, ({double taxableValue, double taxAmount})> bands = {};
    for (final sale in _sales) {
      for (final item in sale.items) {
        double itemRate = 0;
        if (item.taxBreakup.isNotEmpty) {
          itemRate = item.taxBreakup.fold<double>(0, (sum, t) => sum + t.rate);
        } else if (item.taxableAmount > 0) {
          itemRate = (item.taxAmount / item.taxableAmount * 100).roundToDouble();
        }
        final key = itemRate.round();
        final current = bands[key] ?? (taxableValue: 0.0, taxAmount: 0.0);
        bands[key] = (
          taxableValue: current.taxableValue + item.taxableAmount,
          taxAmount: current.taxAmount + item.taxAmount,
        );
      }
    }
    return bands;
  }

  // Export Excel
  Future<void> _exportExcel() async {
    final workbook = exc.Excel.createExcel();
    final tabName = _tabNames[_selectedTabIndex].replaceAll(' ', '_');
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null) {
      workbook.rename(defaultSheet, tabName);
    }
    final sheet = workbook[tabName];

    sheet.appendRow([
      'Metric / Item Name',
      'Category / Detail',
      'Volume / Count',
      'Value (₹)'
    ].map(exc.TextCellValue.new).toList());

    sheet.appendRow([
      exc.TextCellValue('Total Net Revenue'),
      exc.TextCellValue('Store Gross'),
      exc.IntCellValue(_sales.length),
      exc.DoubleCellValue(_totalRevenue),
    ]);

    sheet.appendRow([
      exc.TextCellValue('Taxable Revenue'),
      exc.TextCellValue('Pre-Tax Value'),
      exc.IntCellValue(_sales.length),
      exc.DoubleCellValue(_taxableAmount),
    ]);

    sheet.appendRow([
      exc.TextCellValue('GST Collected'),
      exc.TextCellValue('CGST + SGST + IGST'),
      exc.IntCellValue(0),
      exc.DoubleCellValue(_totalGst),
    ]);

    final bytes = workbook.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}store_analysis_${tabName}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel exported: ${file.path}')),
    );
    await OpenFile.open(file.path);
  }

  // Export PDF
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final title = 'Store Analysis Report - ${_tabNames[_selectedTabIndex]}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Period: ${DateFormat('dd-MM-yyyy').format(_salesController.fromDate)} to ${DateFormat('dd-MM-yyyy').format(_salesController.toDate)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfBlock('Total Revenue', _pdfMoney(_totalRevenue)),
                  _pdfBlock('Taxable Value', _pdfMoney(_taxableAmount)),
                  _pdfBlock('Total GST Collected', _pdfMoney(_totalGst)),
                  _pdfBlock('Total Bills', '${_sales.length}'),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: ['Metric / Parameter', 'Category / Detail', 'Txn Count', 'Total Amount'],
              data: [
                ['Total Gross Revenue', 'Sales Revenue', '${_sales.length}', _pdfMoney(_totalRevenue)],
                ['Pre-Tax Taxable Value', 'Taxable Amount', '${_sales.length}', _pdfMoney(_taxableAmount)],
                ['Total GST Liability', 'CGST/SGST/IGST', '-', _pdfMoney(_totalGst)],
                ['Total Discounts Given', 'Discounts', '-', _pdfMoney(_totalDiscount)],
              ],
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}store_analysis_${_selectedTabIndex}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF exported: ${file.path}')),
    );
    await OpenFile.open(file.path);
  }

  pw.Widget _pdfBlock(String label, String val) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(val, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  Widget _chartShell({
    required String title,
    required String subtitle,
    required AsyncSnapshot snapshot,
    required Widget Function() builder,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 340),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 12),
          Expanded(
            child: () {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load analytics'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => setState(_reload),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              return builder();
            }(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Analysis & Retail Growth Intelligence'),
        actions: [
          IconButton(
            tooltip: 'Export Excel',
            icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
            onPressed: _exportPdf,
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Executive Metric Cards
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(width: 230, child: _kpiCard('Gross Revenue', _inr.format(_totalRevenue), Icons.account_balance_wallet, const Color(0xFF2563EB))),
                      SizedBox(width: 230, child: _kpiCard('Taxable Value', _inr.format(_taxableAmount), Icons.pie_chart_outline, const Color(0xFF0F766E))),
                      SizedBox(width: 230, child: _kpiCard('GST Collected', _inr.format(_totalGst), Icons.receipt_long, const Color(0xFF16A34A))),
                      SizedBox(width: 230, child: _kpiCard('Total Discounts', _inr.format(_totalDiscount), Icons.local_offer_outlined, const Color(0xFFEA580C))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tab Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabNames.length, (index) {
                        final selected = _selectedTabIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_tabNames[index]),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedTabIndex = index),
                            selectedColor: const Color(0xFF17324D),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF17324D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Content Views
                  if (_selectedTabIndex == 0) _buildMarketingTab(),
                  if (_selectedTabIndex == 1) _buildFinancialTab(),
                  if (_selectedTabIndex == 2) _buildGstTab(),
                  if (_selectedTabIndex == 3) _buildInventoryVelocityTab(),
                ],
              ),
            ),
    );
  }

  // --- Tab 0: Marketing & Growth ---
  Widget _buildMarketingTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        return Column(
          children: [
            Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 360,
                    child: FutureBuilder<List<RfmSegmentPoint>>(
                      future: _rfmFuture,
                      builder: (context, snapshot) {
                        final data = snapshot.data ?? const <RfmSegmentPoint>[];
                        return _chartShell(
                          title: 'Customer Segmentation (RFM)',
                          subtitle: 'Champions, At-Risk, Churned & New Shoppers',
                          snapshot: snapshot,
                          builder: () => SfCircularChart(
                            tooltipBehavior: _rfmTooltip,
                            legend: const Legend(
                              isVisible: true,
                              position: LegendPosition.bottom,
                            ),
                            series: <CircularSeries>[
                              DoughnutSeries<RfmSegmentPoint, String>(
                                dataSource: data,
                                xValueMapper: (d, _) => d.segment,
                                yValueMapper: (d, _) => d.customerCount,
                                pointColorMapper: (d, _) => _segmentColor(d.segment),
                                dataLabelSettings: const DataLabelSettings(isVisible: true),
                                enableTooltip: true,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
                Expanded(
                  child: SizedBox(
                    height: 360,
                    child: FutureBuilder<List<MarketBasketPoint>>(
                      future: _basketFuture,
                      builder: (context, snapshot) {
                        final data = snapshot.data ?? const <MarketBasketPoint>[];
                        return _chartShell(
                          title: 'Market Basket (Top Cross-Sell Pairs)',
                          subtitle: 'Items frequently billed together',
                          snapshot: snapshot,
                          builder: () => SfCartesianChart(
                            tooltipBehavior: _basketTooltip,
                            primaryXAxis: const CategoryAxis(title: AxisTitle(text: 'Item Pair')),
                            primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Occurrences')),
                            series: <CartesianSeries>[
                              BarSeries<MarketBasketPoint, String>(
                                dataSource: data,
                                xValueMapper: (d, _) => d.pairName,
                                yValueMapper: (d, _) => d.occurrenceCount,
                                color: const Color(0xFF0EA5E9),
                                enableTooltip: true,
                                dataLabelSettings: const DataLabelSettings(isVisible: true),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: FutureBuilder<List<SalesTrendPoint>>(
                future: _trendFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? const <SalesTrendPoint>[];
                  return _chartShell(
                    title: 'Sales Revenue & Subscription Velocity',
                    subtitle: '30-Day store performance trend',
                    snapshot: snapshot,
                    builder: () => SfCartesianChart(
                      tooltipBehavior: _trendTooltip,
                      zoomPanBehavior: _zoomPan,
                      primaryXAxis: DateTimeAxis(
                        intervalType: DateTimeIntervalType.days,
                        dateFormat: DateFormat('dd MMM'),
                      ),
                      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Revenue (₹)')),
                      axes: const <ChartAxis>[
                        NumericAxis(
                          name: 'subscriptionAxis',
                          opposedPosition: true,
                          title: AxisTitle(text: 'Subscription Qty'),
                        ),
                      ],
                      series: <CartesianSeries>[
                        ColumnSeries<SalesTrendPoint, DateTime>(
                          name: 'Revenue',
                          dataSource: data,
                          xValueMapper: (d, _) => d.date,
                          yValueMapper: (d, _) => d.revenue,
                          color: const Color(0xFF2563EB),
                          enableTooltip: true,
                        ),
                        SplineSeries<SalesTrendPoint, DateTime>(
                          name: 'Subscription Qty',
                          dataSource: data,
                          xValueMapper: (d, _) => d.date,
                          yValueMapper: (d, _) => d.subscriptionVolume,
                          yAxisName: 'subscriptionAxis',
                          color: const Color(0xFF16A34A),
                          enableTooltip: true,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Tab 1: Financial & Accounting ---
  Widget _buildFinancialTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial & Gross Profitability Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Financial Parameter')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Amount (₹)')),
            ],
            rows: [
              DataRow(cells: [
                const DataCell(Text('Sub-Total (Gross Billing)', style: TextStyle(fontWeight: FontWeight.w700))),
                const DataCell(Text('Total billing volume before discount & tax')),
                DataCell(Text(_inr.format(_subTotal))),
              ]),
              DataRow(cells: [
                const DataCell(Text('Pre-Tax Taxable Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                const DataCell(Text('Net sales value excluding GST')),
                DataCell(Text(_inr.format(_taxableAmount))),
              ]),
              DataRow(cells: [
                const DataCell(Text('Total GST Liability Collected', style: TextStyle(fontWeight: FontWeight.w700))),
                const DataCell(Text('CGST + SGST + IGST collected from buyers')),
                DataCell(Text(_inr.format(_totalGst), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700))),
              ]),
              DataRow(cells: [
                const DataCell(Text('Total Discounts & Offers', style: TextStyle(fontWeight: FontWeight.w700))),
                const DataCell(Text('Scheme & manual discounts given')),
                DataCell(Text(_inr.format(_totalDiscount), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700))),
              ]),
              DataRow(cells: [
                const DataCell(Text('Net Revenue Realized', style: TextStyle(fontWeight: FontWeight.w800))),
                const DataCell(Text('Final store cash & digital realization')),
                DataCell(Text(_inr.format(_totalRevenue), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800))),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  // --- Tab 2: GST Compliance ---
  Widget _buildGstTab() {
    final bands = _realTaxBands;
    final rates = [0, 5, 12, 18, 28];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GST Compliance & Tax Breakdown Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Tax Bracket / Component')),
              DataColumn(label: Text('Tax Rate')),
              DataColumn(label: Text('Taxable Amount (₹)')),
              DataColumn(label: Text('GST Amount (₹)')),
            ],
            rows: rates.map((r) {
              final bandData = bands[r] ?? (taxableValue: 0.0, taxAmount: 0.0);
              return DataRow(cells: [
                DataCell(Text(r == 0 ? 'GST 0% (Exempt)' : 'GST $r%', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text('$r%')),
                DataCell(Text(_inr.format(bandData.taxableValue))),
                DataCell(Text(_inr.format(bandData.taxAmount), style: TextStyle(color: bandData.taxAmount > 0 ? Colors.green : Colors.black, fontWeight: bandData.taxAmount > 0 ? FontWeight.w700 : FontWeight.normal))),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Tab 3: Inventory Velocity ---
  Widget _buildInventoryVelocityTab() {
    final Map<String, ({double qty, double amount})> itemMap = {};
    for (final sale in _sales) {
      for (final item in sale.items) {
        final name = item.itemName.trim().isEmpty ? 'Item' : item.itemName.trim();
        final current = itemMap[name] ?? (qty: 0.0, amount: 0.0);
        itemMap[name] = (
          qty: current.qty + item.qty,
          amount: current.amount + item.netAmount,
        );
      }
    }

    final sortedItems = itemMap.entries.toList()
      ..sort((a, b) => b.value.qty.compareTo(a.value.qty));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Velocity & Deadstock Health', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Purpose: Identify fast-selling items to reorder before stockout, and slow-moving deadstock to discount and release working capital.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),
          DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Item Name / Category')),
              DataColumn(label: Text('Units Sold')),
              DataColumn(label: Text('Revenue Generated')),
              DataColumn(label: Text('Turnover Velocity')),
              DataColumn(label: Text('Business Action Required')),
            ],
            rows: [
              ...sortedItems.take(5).map((e) => DataRow(cells: [
                    DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(e.value.qty.toStringAsFixed(2))),
                    DataCell(Text(_inr.format(e.value.amount), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700))),
                    const DataCell(Text('Fast Moving (Top Seller)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700))),
                    const DataCell(Text('Reorder immediately to prevent stockouts', style: TextStyle(color: Colors.blue))),
                  ])),
              if (sortedItems.length > 5)
                ...sortedItems.skip(5).take(3).map((e) => DataRow(cells: [
                      DataCell(Text(e.key)),
                      DataCell(Text(e.value.qty.toStringAsFixed(2))),
                      DataCell(Text(_inr.format(e.value.amount))),
                      const DataCell(Text('Medium Velocity')),
                      const DataCell(Text('Maintain steady reorder stock')),
                    ])),
              DataRow(
                color: WidgetStateProperty.all(const Color(0xFFFEF2F2)),
                cells: const [
                  DataCell(Text('Deadstock / Unsold Items', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red))),
                  DataCell(Text('0.00 Units', style: TextStyle(color: Colors.red))),
                  DataCell(Text('₹0.00', style: TextStyle(color: Colors.red))),
                  DataCell(Text('Slow / Deadstock', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
                  DataCell(Text('Run discount offer or return to supplier', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
