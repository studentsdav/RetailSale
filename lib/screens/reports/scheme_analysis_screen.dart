import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/sales_report_controller.dart';

class SchemeAnalysisScreen extends StatefulWidget {
  const SchemeAnalysisScreen({super.key});

  @override
  State<SchemeAnalysisScreen> createState() => _SchemeAnalysisScreenState();
}

class _SchemeAnalysisScreenState extends State<SchemeAnalysisScreen> {
  final SalesReportController _controller = SalesReportController();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  final NumberFormat _qtyFmt = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _syncDates();
    _loadData();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  void _syncDates() {
    _fromCtrl.text = DateFormat('dd-MM-yyyy').format(_fromDate);
    _toCtrl.text = DateFormat('dd-MM-yyyy').format(_toDate);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _syncDates();
      });
      _loadData();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _syncDates();
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _controller.fromDate = _fromDate;
      _controller.toDate = _toDate;
      await _controller.load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sales data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Local scheme metrics aggregation
  List<_SchemeMetric> _getSchemeMetrics() {
    final Map<String, _SchemeMetricBuilder> aggregated = {};

    for (final sale in _controller.list) {
      final schemeName = sale.schemeName.trim().isEmpty ? 'No Scheme' : sale.schemeName.trim();
      final builder = aggregated.putIfAbsent(
        schemeName,
        () => _SchemeMetricBuilder(scheme: schemeName),
      );

      builder.quantity += sale.totalQty;
      builder.subTotal += sale.subTotal;
      builder.discount += sale.totalDiscount;
      builder.taxableValue += sale.taxableAmount;
      builder.totalSales += sale.netAmount;
      builder.estimatedCost += sale.estimatedCost;
      builder.estimatedProfit += sale.estimatedProfit;
      builder.transactionCount++;
    }

    final totalSalesAll = aggregated.values.fold<double>(0.0, (sum, e) => sum + e.totalSales);

    final metrics = aggregated.values.map((e) {
      final sharePercent = totalSalesAll > 0 ? (e.totalSales / totalSalesAll) * 100 : 0.0;
      final marginPercent = e.totalSales > 0 ? (e.estimatedProfit / e.totalSales) * 100 : 0.0;

      return _SchemeMetric(
        scheme: e.scheme,
        quantity: e.quantity,
        subTotal: e.subTotal,
        discount: e.discount,
        taxableValue: e.taxableValue,
        totalSales: e.totalSales,
        estimatedCost: e.estimatedCost,
        estimatedProfit: e.estimatedProfit,
        transactionCount: e.transactionCount,
        sharePercent: sharePercent,
        marginPercent: marginPercent,
      );
    }).toList();

    // Sort by sales value descending
    metrics.sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return metrics;
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _getSchemeMetrics();
    final double totalSalesAll = metrics.fold(0.0, (sum, m) => sum + m.totalSales);

    // Scheme-only metrics calculations (excluding "No Scheme")
    final schemeMetricsOnly = metrics.where((m) => m.scheme != 'No Scheme').toList();
    final double totalSchemeSalesSum = schemeMetricsOnly.fold(0.0, (sum, m) => sum + m.totalSales);
    final double totalSchemeUnitsSum = schemeMetricsOnly.fold(0.0, (sum, m) => sum + m.quantity);
    final String topSchemeName = schemeMetricsOnly.isNotEmpty ? schemeMetricsOnly.first.scheme : 'N/A';
    final double topSchemeSales = schemeMetricsOnly.isNotEmpty ? schemeMetricsOnly.first.totalSales : 0.0;
    final int activeSchemesCount = schemeMetricsOnly.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheme Performance Analysis'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _dateField('From Date', _fromCtrl, _pickFromDate),
                        _dateField('To Date', _toCtrl, _pickToDate),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.insights, size: 18),
                          label: const Text('Analyze'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // KPIs Grid
                  LayoutBuilder(
                    builder: (context, kpiConstraints) {
                      final cols = kpiConstraints.maxWidth > 1100 ? 4 : kpiConstraints.maxWidth > 700 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 4 ? 2.3 : 2.5,
                        children: [
                          _kpiCard(
                            title: 'Total Scheme Revenue',
                            value: _inr.format(totalSchemeSalesSum),
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          _kpiCard(
                            title: 'Top Performing Scheme',
                            value: topSchemeName == 'N/A' ? 'N/A' : '$topSchemeName (${_inr.format(topSchemeSales)})',
                            icon: Icons.workspace_premium_outlined,
                            color: const Color(0xFF16A34A),
                          ),
                          _kpiCard(
                            title: 'Scheme Quantities Sold',
                            value: '${_qtyFmt.format(totalSchemeUnitsSum)} Units',
                            icon: Icons.shopping_bag_outlined,
                            color: const Color(0xFF7C3AED),
                          ),
                          _kpiCard(
                            title: 'Active Scheme Portfolio',
                            value: '$activeSchemesCount Schemes',
                            icon: Icons.category_outlined,
                            color: const Color(0xFFEA580C),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Visual Analytics Charts row
                  LayoutBuilder(
                    builder: (context, chartConstraints) {
                      final isWide = chartConstraints.maxWidth >= 960;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children: [
                          // Revenue bar chart
                          Expanded(
                            flex: isWide ? 6 : 0,
                            child: Container(
                              height: 380,
                              margin: EdgeInsets.only(right: isWide ? 12 : 0, bottom: isWide ? 0 : 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Scheme Revenue Leaderboard',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Sales contribution per scheme (excl. No Scheme)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  Expanded(
                                    child: schemeMetricsOnly.isEmpty
                                        ? const Center(child: Text('No scheme sales data available'))
                                        : SfCartesianChart(
                                            primaryXAxis: const CategoryAxis(
                                              labelRotation: 45,
                                              majorGridLines: MajorGridLines(width: 0),
                                            ),
                                            primaryYAxis: NumericAxis(
                                              numberFormat: NumberFormat.compactSimpleCurrency(locale: 'en_IN'),
                                              majorGridLines: const MajorGridLines(width: 0.5, dashArray: [4, 4]),
                                            ),
                                            tooltipBehavior: TooltipBehavior(enable: true),
                                            series: <CartesianSeries<_SchemeMetric, String>>[
                                              ColumnSeries<_SchemeMetric, String>(
                                                dataSource: schemeMetricsOnly.take(8).toList(), // top 8 schemes
                                                xValueMapper: (_SchemeMetric data, _) => data.scheme,
                                                yValueMapper: (_SchemeMetric data, _) => data.totalSales,
                                                name: 'Net Sales',
                                                color: const Color(0xFF3B82F6),
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                  topRight: Radius.circular(6),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Scheme share donut chart
                          Expanded(
                            flex: isWide ? 4 : 0,
                            child: Container(
                              height: 380,
                              margin: EdgeInsets.only(left: isWide ? 12 : 0),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unit Share Distribution',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Percentage split of total units sold', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  Expanded(
                                    child: schemeMetricsOnly.isEmpty
                                        ? const Center(child: Text('No scheme sales data available'))
                                        : SfCircularChart(
                                            legend: const Legend(
                                              isVisible: true,
                                              overflowMode: LegendItemOverflowMode.wrap,
                                              position: LegendPosition.bottom,
                                            ),
                                            tooltipBehavior: TooltipBehavior(enable: true),
                                            series: <CircularSeries<_SchemeMetric, String>>[
                                              DoughnutSeries<_SchemeMetric, String>(
                                                dataSource: schemeMetricsOnly.take(5).toList(), // top 5 schemes
                                                xValueMapper: (_SchemeMetric data, _) => data.scheme,
                                                yValueMapper: (_SchemeMetric data, _) => data.quantity,
                                                dataLabelSettings: const DataLabelSettings(
                                                  isVisible: true,
                                                  labelPosition: ChartDataLabelPosition.outside,
                                                ),
                                                name: 'Units Sold',
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Scheme analysis detailed breakdown table
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scheme Wise Sales & Profit Margin Ledger',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text('Detailed analytics including profit shares and quantity contribution', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        metrics.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('No scheme sales ledger records found.'),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: Scrollbar(
                                  controller: _tableScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _tableScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                      columns: const [
                                        DataColumn(label: Text('Scheme Name')),
                                        DataColumn(label: Text('Transactions')),
                                        DataColumn(label: Text('Units Sold')),
                                        DataColumn(label: Text('Subtotal')),
                                        DataColumn(label: Text('Discounts')),
                                        DataColumn(label: Text('Net Sales (INR)')),
                                        DataColumn(label: Text('Sales Share (%)')),
                                        DataColumn(label: Text('Est. Profit (INR)')),
                                        DataColumn(label: Text('Profit Margin (%)')),
                                      ],
                                      rows: [
                                        ...metrics.map((row) => DataRow(
                                              cells: [
                                                DataCell(Text(
                                                  row.scheme,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                )),
                                                DataCell(Text('${row.transactionCount}')),
                                                DataCell(Text(_qtyFmt.format(row.quantity))),
                                                DataCell(Text(_inr.format(row.subTotal))),
                                                DataCell(Text(_inr.format(row.discount))),
                                                DataCell(Text(
                                                  _inr.format(row.totalSales),
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                )),
                                                DataCell(Text('${row.sharePercent.toStringAsFixed(2)}%')),
                                                DataCell(Text(_inr.format(row.estimatedProfit))),
                                                DataCell(Text('${row.marginPercent.toStringAsFixed(2)}%')),
                                              ],
                                            )),
                                        // Total Row
                                        DataRow(
                                          color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          cells: [
                                            const DataCell(Text(
                                              'TOTAL',
                                              style: TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              '${metrics.fold<int>(0, (sum, m) => sum + m.transactionCount)}',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              _qtyFmt.format(metrics.fold<double>(0.0, (sum, m) => sum + m.quantity)),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              _inr.format(metrics.fold<double>(0.0, (sum, m) => sum + m.subTotal)),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              _inr.format(metrics.fold<double>(0.0, (sum, m) => sum + m.discount)),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              _inr.format(totalSalesAll),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            const DataCell(Text(
                                              '100.00%',
                                              style: TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              _inr.format(metrics.fold<double>(0.0, (sum, m) => sum + m.estimatedProfit)),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              '${totalSalesAll > 0 ? (metrics.fold<double>(0.0, (sum, m) => sum + m.estimatedProfit) / totalSalesAll * 100).toStringAsFixed(2) : 0.00}%',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Helper models for scheme calculations
class _SchemeMetricBuilder {
  final String scheme;
  double quantity = 0;
  double subTotal = 0;
  double discount = 0;
  double taxableValue = 0;
  double totalSales = 0;
  double estimatedCost = 0;
  double estimatedProfit = 0;
  int transactionCount = 0;

  _SchemeMetricBuilder({required this.scheme});
}

class _SchemeMetric {
  final String scheme;
  final double quantity;
  final double subTotal;
  final double discount;
  final double taxableValue;
  final double totalSales;
  final double estimatedCost;
  final double estimatedProfit;
  final int transactionCount;
  final double sharePercent;
  final double marginPercent;

  const _SchemeMetric({
    required this.scheme,
    required this.quantity,
    required this.subTotal,
    required this.discount,
    required this.taxableValue,
    required this.totalSales,
    required this.estimatedCost,
    required this.estimatedProfit,
    required this.transactionCount,
    required this.sharePercent,
    required this.marginPercent,
  });
}
