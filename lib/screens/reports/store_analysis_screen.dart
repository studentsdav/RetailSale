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
import '../../controllers/reports/stock_balance_controller.dart';
import '../../controllers/reports/store_analysis_controller.dart';
import '../../models/reports/sales_report_model.dart';
import '../../models/reports/stock_item_model.dart';

class StoreAnalysisScreen extends StatefulWidget {
  const StoreAnalysisScreen({super.key});

  @override
  State<StoreAnalysisScreen> createState() => _StoreAnalysisScreenState();
}

class _StoreAnalysisScreenState extends State<StoreAnalysisScreen> {
  final StoreAnalysisController _controller = StoreAnalysisController();
  final SalesReportController _salesController = SalesReportController();
  final StockBalanceController _stockBalanceController = StockBalanceController();

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime toDate = DateTime.now();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  String _velocityFilter = 'ALL'; // 'ALL', 'FAST', 'MODERATE', 'SLOW', 'DEADSTOCK'

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
    _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
    _toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
    _reload();
  }

  void _reload() {
    setState(() => _isLoading = true);
    _salesController.fromDate = fromDate;
    _salesController.toDate = toDate;
    _rfmFuture = _controller.fetchRfmSegments();
    _trendFuture = _controller.fetchSalesTrend();
    _basketFuture = _controller.fetchMarketBasket();
    _topCustomerItemsFuture = _controller.fetchTopCustomerItems();

    Future.wait([
      _salesController.load(),
      _stockBalanceController.load(),
    ]).then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
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
      _reload();
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
      _reload();
    }
  }

  void _applyPreset(int days) {
    setState(() {
      if (days == 0) {
        fromDate = DateTime.now();
        toDate = DateTime.now();
      } else {
        fromDate = DateTime.now().subtract(Duration(days: days - 1));
        toDate = DateTime.now();
      }
      _fromCtrl.text = DateFormat('dd-MMM-yyyy').format(fromDate);
      _toCtrl.text = DateFormat('dd-MMM-yyyy').format(toDate);
    });
    _reload();
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

  List<SalesReport> get _sales => _salesController.list
      .where((s) => !s.saleNo.trim().toUpperCase().startsWith('CUST-'))
      .toList();

  double get _totalRevenue => _sales.fold(0.0, (s, sale) => s + sale.netAmount);
  double get _taxableAmount => _sales.fold(0.0, (s, sale) {
        if (sale.items.isNotEmpty) {
          return s + sale.items.fold(0.0, (isum, item) => isum + item.taxableAmount);
        }
        return s + sale.taxableAmount;
      });
  double get _totalGst => _sales.fold(0.0, (s, sale) => s + sale.totalTax);
  double get _totalDiscount => _sales.fold(0.0, (s, sale) => s + sale.totalDiscount);
  double get _subTotal => _taxableAmount + _totalDiscount;

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

  Widget _filterCard() {
    final rawDays = toDate.difference(fromDate).inDays + 1;
    final days = rawDays < 1 ? 1 : rawDays;
    final isToday = days == 1 && DateFormat('yyyy-MM-dd').format(fromDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final is7Days = days == 7;
    final is30Days = days == 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 6),
              const Text(
                'Analysis Period:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          SizedBox(
            width: 155,
            height: 42,
            child: TextField(
              controller: _fromCtrl,
              readOnly: true,
              onTap: _pickFromDate,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'From Date',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          SizedBox(
            width: 155,
            height: 42,
            child: TextField(
              controller: _toCtrl,
              readOnly: true,
              onTap: _pickToDate,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'To Date',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          ChoiceChip(
            label: const Text('Today'),
            selected: isToday,
            onSelected: (_) => _applyPreset(0),
          ),
          ChoiceChip(
            label: const Text('Last 7 Days'),
            selected: is7Days,
            onSelected: (_) => _applyPreset(7),
          ),
          ChoiceChip(
            label: const Text('Last 30 Days'),
            selected: is30Days,
            onSelected: (_) => _applyPreset(30),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _reload,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Generate Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  _filterCard(),

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

  // --- Tab 3: Inventory Velocity & Deadstock Analysis ---
  Widget _buildInventoryVelocityTab() {
    final rawDays = toDate.difference(fromDate).inDays + 1;
    final days = rawDays < 1 ? 1 : rawDays;

    final Map<String, ({double qty, double amount})> soldMap = {};
    for (final sale in _sales) {
      for (final item in sale.items) {
        final name = item.itemName.trim().isEmpty ? 'Item' : item.itemName.trim();
        final current = soldMap[name] ?? (qty: 0.0, amount: 0.0);
        soldMap[name] = (
          qty: current.qty + item.qty,
          amount: current.amount + item.netAmount,
        );
      }
    }

    // Combine stock balance items and sold items
    final Map<String, ({double soldQty, double revenue, double stockQty, double rate})> unifiedMap = {};

    for (final stockItem in _stockBalanceController.items) {
      final name = stockItem.name.trim().isEmpty ? 'Item' : stockItem.name.trim();
      final sold = soldMap[name];
      unifiedMap[name] = (
        soldQty: sold?.qty ?? 0.0,
        revenue: sold?.amount ?? 0.0,
        stockQty: stockItem.qty,
        rate: stockItem.rate,
      );
    }

    for (final entry in soldMap.entries) {
      if (!unifiedMap.containsKey(entry.key)) {
        unifiedMap[entry.key] = (
          soldQty: entry.value.qty,
          revenue: entry.value.amount,
          stockQty: 0.0,
          rate: 0.0,
        );
      }
    }

    final allItems = unifiedMap.entries.toList();

    int fastCount = 0;
    int moderateCount = 0;
    int slowCount = 0;
    int deadstockCount = 0;
    double deadstockValue = 0.0;

    final List<Map<String, dynamic>> processedItems = [];

    for (final e in allItems) {
      final soldQty = e.value.soldQty;
      final revenue = e.value.revenue;
      final stockQty = e.value.stockQty;
      final rate = e.value.rate;
      final dailyRate = soldQty / days;

      final String status;
      final String code; // 'FAST', 'MODERATE', 'SLOW', 'DEADSTOCK'
      final Color color;
      final String action;

      if (soldQty == 0) {
        code = 'DEADSTOCK';
        status = 'Deadstock (0 Sales in $days Days)';
        color = const Color(0xFFDC2626);
        action = 'Liquidate via promo offer or return to supplier';
        deadstockCount++;
        deadstockValue += stockQty * rate;
      } else if (dailyRate >= 0.5) {
        code = 'FAST';
        status = 'Fast Moving (Top Seller)';
        color = const Color(0xFF16A34A);
        action = 'Reorder immediately to prevent stockouts';
        fastCount++;
      } else if (dailyRate >= 0.1) {
        code = 'MODERATE';
        status = 'Moderate Velocity';
        color = const Color(0xFFD97706);
        action = 'Maintain steady safety stock';
        moderateCount++;
      } else {
        code = 'SLOW';
        status = 'Slow Moving (Low Run-Rate)';
        color = const Color(0xFFEA580C);
        action = 'Run promo offer or bundle discounts';
        slowCount++;
      }

      processedItems.add({
        'name': e.key,
        'soldQty': soldQty,
        'dailyRate': dailyRate,
        'revenue': revenue,
        'stockQty': stockQty,
        'rate': rate,
        'code': code,
        'status': status,
        'color': color,
        'action': action,
      });
    }

    // Default Sort: DEADSTOCK items on top first, then sorted by soldQty
    processedItems.sort((a, b) {
      if (a['code'] == 'DEADSTOCK' && b['code'] != 'DEADSTOCK') return -1;
      if (a['code'] != 'DEADSTOCK' && b['code'] == 'DEADSTOCK') return 1;
      return (b['soldQty'] as double).compareTo(a['soldQty'] as double);
    });

    final filteredList = processedItems.where((item) {
      if (_velocityFilter == 'ALL') return true;
      return item['code'] == _velocityFilter;
    }).toList();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Inventory Velocity & Deadstock Intelligence', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'Analysis Period: ${DateFormat('dd-MMM-yyyy').format(fromDate)} to ${DateFormat('dd-MMM-yyyy').format(toDate)} ($days Days)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Calculation Logic: Velocity = Units Sold ÷ $days Period Days. Deadstock items (0 sales in $days days) are ranked on top.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          ),
          const SizedBox(height: 14),

          // Executive Summary Badges
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _velocityFilterChip('ALL', 'All Items', '${processedItems.length} SKUs', const Color(0xFF2563EB)),
              _velocityFilterChip('DEADSTOCK', '🔴 Deadstock (0 Sales)', '$deadstockCount SKUs (${_inr.format(deadstockValue)} Tied Up)', const Color(0xFFDC2626)),
              _velocityFilterChip('FAST', '🟢 Fast Moving', '$fastCount SKUs', const Color(0xFF16A34A)),
              _velocityFilterChip('MODERATE', '🟡 Moderate', '$moderateCount SKUs', const Color(0xFFD97706)),
              _velocityFilterChip('SLOW', '🟠 Slow Moving', '$slowCount SKUs', const Color(0xFFEA580C)),
            ],
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Item Name')),
                DataColumn(label: Text('Stock Available')),
                DataColumn(label: Text('Units Sold')),
                DataColumn(label: Text('Run-Rate (Units/Day)')),
                DataColumn(label: Text('Revenue / Tied-Up Value')),
                DataColumn(label: Text('Velocity Classification')),
                DataColumn(label: Text('Action Recommended')),
              ],
              rows: filteredList.map((e) {
                final String code = e['code'];
                final Color color = e['color'];
                final double soldQty = e['soldQty'];
                final double stockQty = e['stockQty'];
                final double dailyRate = e['dailyRate'];
                final double revenue = e['revenue'];
                final double rate = e['rate'];
                final Color? rowBg = code == 'DEADSTOCK' ? const Color(0xFFFEF2F2) : null;

                return DataRow(
                  color: WidgetStateProperty.all(rowBg),
                  cells: [
                    DataCell(Text(e['name'], style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(stockQty > 0 ? '${stockQty.toStringAsFixed(0)} in stock' : 'Out of Stock', style: TextStyle(color: stockQty > 0 ? Colors.black87 : Colors.grey))),
                    DataCell(Text('${soldQty.toStringAsFixed(2)} units')),
                    DataCell(Text('${dailyRate.toStringAsFixed(2)} /day', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(code == 'DEADSTOCK' ? _inr.format(stockQty * rate) : _inr.format(revenue), style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(e['status'], style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                    )),
                    DataCell(Text(e['action'], style: TextStyle(color: e['code'] == 'FAST' ? const Color(0xFF2563EB) : color, fontWeight: FontWeight.w600, fontSize: 12))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _velocityFilterChip(String key, String label, String sub, Color color) {
    final isSelected = _velocityFilter == key;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _velocityFilter = key),
      selectedColor: color.withOpacity(0.18),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 1.8 : 1.0),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: isSelected ? color : Colors.black87, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(sub, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5)),
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
