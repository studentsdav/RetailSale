import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/sales_report_controller.dart';
import '../../models/reports/sales_report_model.dart';

class PaymentAnalysisScreen extends StatefulWidget {
  const PaymentAnalysisScreen({super.key});

  @override
  State<PaymentAnalysisScreen> createState() => _PaymentAnalysisScreenState();
}

class _PaymentAnalysisScreenState extends State<PaymentAnalysisScreen> {
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
          SnackBar(content: Text('Failed to load payment data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                      fontSize: 22,
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
    final list = _controller.paymentModes;
    list.sort((a, b) => b.amount.compareTo(a.amount));

    final double totalPaymentsSum = list.fold(0.0, (sum, m) => sum + m.amount);
    final int totalCountSum = list.fold(0, (sum, m) => sum + m.count);
    final String topMethodName = list.isNotEmpty ? list.first.label : 'N/A';
    final double topMethodSales = list.isNotEmpty ? list.first.amount : 0.0;
    final int activeMethodsCount = list.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Method Analysis'),
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
                            title: 'Total Volume',
                            value: _inr.format(totalPaymentsSum),
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          _kpiCard(
                            title: 'Top Method',
                            value: '$topMethodName (${_inr.format(topMethodSales)})',
                            icon: Icons.workspace_premium_outlined,
                            color: const Color(0xFF16A34A),
                          ),
                          _kpiCard(
                            title: 'Total Transactions',
                            value: '${_qtyFmt.format(totalCountSum)} Txns',
                            icon: Icons.shopping_bag_outlined,
                            color: const Color(0xFF7C3AED),
                          ),
                          _kpiCard(
                            title: 'Active Methods',
                            value: '$activeMethodsCount Methods',
                            icon: Icons.category_outlined,
                            color: const Color(0xFFEA580C),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, chartConstraints) {
                      final isWide = chartConstraints.maxWidth >= 960;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children: [
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
                                    'Payment Volume Leaderboard',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Received volume per payment mode', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  Expanded(
                                    child: list.isEmpty
                                        ? const Center(child: Text('No payment data available'))
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
                                            series: <CartesianSeries<SalesBreakdownEntry, String>>[
                                              ColumnSeries<SalesBreakdownEntry, String>(
                                                dataSource: list,
                                                xValueMapper: (SalesBreakdownEntry data, _) => data.label,
                                                yValueMapper: (SalesBreakdownEntry data, _) => data.amount,
                                                name: 'Volume Received',
                                                color: const Color(0xFF10B981),
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
                                    'Transaction Share Distribution',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Percentage split of total transactions', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  Expanded(
                                    child: list.isEmpty
                                        ? const Center(child: Text('No payment data available'))
                                        : SfCircularChart(
                                            legend: const Legend(
                                              isVisible: true,
                                              overflowMode: LegendItemOverflowMode.wrap,
                                              position: LegendPosition.bottom,
                                            ),
                                            tooltipBehavior: TooltipBehavior(enable: true),
                                            series: <CircularSeries<SalesBreakdownEntry, String>>[
                                              DoughnutSeries<SalesBreakdownEntry, String>(
                                                dataSource: list,
                                                xValueMapper: (SalesBreakdownEntry data, _) => data.label,
                                                yValueMapper: (SalesBreakdownEntry data, _) => data.count,
                                                dataLabelSettings: const DataLabelSettings(
                                                  isVisible: true,
                                                  labelPosition: ChartDataLabelPosition.outside,
                                                ),
                                                name: 'Transactions',
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
                          'Payment Wise Volume & Transactions Ledger',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text('Detailed analytics including transaction share percent and counts', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        list.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('No payment method records found.'),
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
                                        DataColumn(label: Text('Payment Method')),
                                        DataColumn(label: Text('Transactions')),
                                        DataColumn(label: Text('Volume (INR)')),
                                        DataColumn(label: Text('Share (%)')),
                                      ],
                                      rows: [
                                        ...list.map((row) {
                                          final share = totalPaymentsSum > 0 ? (row.amount / totalPaymentsSum) * 100 : 0.0;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(
                                                row.label,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              )),
                                              DataCell(Text('${row.count}')),
                                              DataCell(Text(
                                                _inr.format(row.amount),
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              )),
                                              DataCell(Text('${share.toStringAsFixed(2)}%')),
                                            ],
                                          );
                                        }),
                                        DataRow(
                                          color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          cells: [
                                            const DataCell(Text(
                                              'TOTAL',
                                              style: TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              '$totalCountSum',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            DataCell(Text(
                                              _inr.format(totalPaymentsSum),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            const DataCell(Text(
                                              '100.00%',
                                              style: TextStyle(fontWeight: FontWeight.w800),
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
