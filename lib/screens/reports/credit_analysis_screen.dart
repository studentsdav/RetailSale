import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/finance_hub_controller.dart';
import '../../models/reports/finance_models.dart';

class CreditAnalysisScreen extends StatefulWidget {
  const CreditAnalysisScreen({super.key});

  @override
  State<CreditAnalysisScreen> createState() => _CreditAnalysisScreenState();
}

class _CreditAnalysisScreenState extends State<CreditAnalysisScreen> {
  final FinanceHubController _controller = FinanceHubController();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

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
      await _controller.loadCreditReport(
        fromDate: _fromDate,
        toDate: _toDate,
        customer: '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load credit analysis: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_BillStatusMetric> _getBillStatusMetrics() {
    final Map<String, int> statusCounts = {};
    for (final customer in _controller.creditCustomers) {
      for (final bill in customer.bills) {
        final status = bill.paymentStatus.trim().toUpperCase().isEmpty
            ? 'UNKNOWN'
            : bill.paymentStatus.trim().toUpperCase();
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }

    final totalBills = statusCounts.values.fold<int>(0, (sum, val) => sum + val);

    return statusCounts.entries.map((e) {
      final percentage = totalBills > 0 ? (e.value / totalBills) * 100 : 0.0;
      return _BillStatusMetric(
        status: e.key,
        count: e.value,
        percentage: percentage,
      );
    }).toList();
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
    final customers = _controller.creditCustomers;

    // Filter customers who actually have outstanding debt for the charts leaderboard
    final sortedDebtors = List<CreditCustomerReport>.from(customers)
      ..sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));
    final topDebtors = sortedDebtors.where((c) => c.totalOutstanding > 0.009).take(8).toList();

    final statusMetrics = _getBillStatusMetrics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Ledger & Accounts Analysis'),
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
                            title: 'Total Outstanding Credit',
                            value: _inr.format(_controller.totalOutstanding),
                            icon: Icons.money_off_rounded,
                            color: const Color(0xFFEF4444),
                          ),
                          _kpiCard(
                            title: 'Total Advance Deposits',
                            value: _inr.format(_controller.totalAdvance),
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF16A34A),
                          ),
                          _kpiCard(
                            title: 'Net Receivables Balance',
                            value: _inr.format(_controller.totalOutstanding - _controller.totalAdvance),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                          _kpiCard(
                            title: 'Active Accounts Count',
                            value: '${customers.length} Accounts',
                            icon: Icons.people_outline_rounded,
                            color: const Color(0xFFEA580C),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Visual Analytics Charts Row
                  LayoutBuilder(
                    builder: (context, chartConstraints) {
                      final isWide = chartConstraints.maxWidth >= 960;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children: [
                          // Debtors bar chart
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
                                    'Top Credit Debtors Leaderboard',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Customers with the highest outstanding balance',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                  Expanded(
                                    child: topDebtors.isEmpty
                                        ? const Center(child: Text('No debtors data available'))
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
                                            series: <CartesianSeries<CreditCustomerReport, String>>[
                                              ColumnSeries<CreditCustomerReport, String>(
                                                dataSource: topDebtors,
                                                xValueMapper: (CreditCustomerReport data, _) =>
                                                    data.customerName,
                                                yValueMapper: (CreditCustomerReport data, _) =>
                                                    data.totalOutstanding,
                                                name: 'Outstanding',
                                                color: const Color(0xFFEF4444),
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

                          // Bill status share donut chart
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
                                    'Bill Payment Status Share',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Status breakdown of credit bills',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                  Expanded(
                                    child: statusMetrics.isEmpty
                                        ? const Center(child: Text('No status metrics available'))
                                        : SfCircularChart(
                                            legend: const Legend(
                                              isVisible: true,
                                              overflowMode: LegendItemOverflowMode.wrap,
                                              position: LegendPosition.bottom,
                                            ),
                                            tooltipBehavior: TooltipBehavior(enable: true),
                                            series: <CircularSeries<_BillStatusMetric, String>>[
                                              DoughnutSeries<_BillStatusMetric, String>(
                                                dataSource: statusMetrics,
                                                xValueMapper: (_BillStatusMetric data, _) => data.status,
                                                yValueMapper: (_BillStatusMetric data, _) => data.count,
                                                dataLabelSettings: const DataLabelSettings(
                                                  isVisible: true,
                                                  labelPosition: ChartDataLabelPosition.outside,
                                                ),
                                                name: 'Bill Count',
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

                  // Customer Detailed Table
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
                          'Customer Credit Accounts Breakdown Ledger',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Detailed view of customer balances, deposits, and net receivables',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        customers.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('No credit records found.'),
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
                                        DataColumn(label: Text('Customer Name')),
                                        DataColumn(label: Text('Phone Number')),
                                        DataColumn(label: Text('Outstanding (INR)')),
                                        DataColumn(label: Text('Advance (INR)')),
                                        DataColumn(label: Text('Net Balance (INR)')),
                                      ],
                                      rows: [
                                        ...customers.map((row) {
                                          final net = row.totalOutstanding - row.totalAdvance;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(
                                                row.customerName,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              )),
                                              DataCell(Text(row.customerPhone)),
                                              DataCell(Text(
                                                _inr.format(row.totalOutstanding),
                                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                              )),
                                              DataCell(Text(
                                                _inr.format(row.totalAdvance),
                                                style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                              )),
                                              DataCell(Text(
                                                _inr.format(net),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: net > 0.009 ? const Color(0xFFEF4444) : (net < -0.009 ? const Color(0xFF16A34A) : Colors.black),
                                                ),
                                              )),
                                            ],
                                          );
                                        }),
                                        // Total Row
                                        DataRow(
                                          color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          cells: [
                                            const DataCell(Text(
                                              'TOTAL',
                                              style: TextStyle(fontWeight: FontWeight.w800),
                                            )),
                                            const DataCell(Text('')),
                                            DataCell(Text(
                                              _inr.format(_controller.totalOutstanding),
                                              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                                            )),
                                            DataCell(Text(
                                              _inr.format(_controller.totalAdvance),
                                              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                            )),
                                            DataCell(Text(
                                              _inr.format(_controller.totalOutstanding - _controller.totalAdvance),
                                              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
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

class _BillStatusMetric {
  final String status;
  final int count;
  final double percentage;

  const _BillStatusMetric({
    required this.status,
    required this.count,
    required this.percentage,
  });
}
