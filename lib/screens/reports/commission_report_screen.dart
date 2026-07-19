import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/sales/sales_controller.dart';

class CommissionReportScreen extends StatefulWidget {
  const CommissionReportScreen({super.key});

  @override
  State<CommissionReportScreen> createState() => _CommissionReportScreenState();
}

class _CommissionReportScreenState extends State<CommissionReportScreen> {
  final SalesController _controller = SalesController();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _selectedSource = 'ALL';
  List<String> _availableSources = ['ALL'];
  bool _isLoading = false;

  Map<String, dynamic> _reportSummary = {};
  List<Map<String, dynamic>> _reportData = [];

  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _syncDates();
    _loadSources();
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

  Future<void> _loadSources() async {
    try {
      final sources = await _controller.listSaleSources();
      final activeSources = sources
          .where((e) => e['is_active'] == true)
          .map((e) => e['name'].toString())
          .toList();
      if (mounted) {
        setState(() {
          _availableSources = ['ALL', ...activeSources];
        });
      }
    } catch (_) {}
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
      final res = await _controller.getCommissionReport(
        fromDate: _fromDate,
        toDate: _toDate,
        saleSource: _selectedSource,
      );
      if (mounted) {
        setState(() {
          _reportSummary = res['summary'] ?? {};
          _reportData = (res['data'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load commission report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _dateField(String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 170,
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
                      fontSize: 13,
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

  List<_ChartData> _getChartData() {
    final double payout = double.tryParse('${_reportSummary['total_net_payout'] ?? 0}') ?? 0.0;
    final double comm = double.tryParse('${_reportSummary['total_commission'] ?? 0}') ?? 0.0;
    final double gst = double.tryParse('${_reportSummary['total_commission_tax'] ?? 0}') ?? 0.0;
    final double tcs = double.tryParse('${_reportSummary['total_tcs'] ?? 0}') ?? 0.0;
    final double tds = double.tryParse('${_reportSummary['total_tds'] ?? 0}') ?? 0.0;

    return [
      _ChartData('Net Realized', payout, const Color(0xFF10B981)),
      _ChartData('Platform Commission', comm, const Color(0xFF3B82F6)),
      _ChartData('GST on Commission', gst, const Color(0xFFF59E0B)),
      _ChartData('TCS Collected', tcs, const Color(0xFFEF4444)),
      _ChartData('TDS Deducted', tds, const Color(0xFF8B5CF6)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double totalSales = double.tryParse('${_reportSummary['total_sales_amount'] ?? 0}') ?? 0.0;
    final double totalTaxable = double.tryParse('${_reportSummary['total_taxable_amount'] ?? 0}') ?? 0.0;
    final double totalComm = double.tryParse('${_reportSummary['total_commission'] ?? 0}') ?? 0.0;
    final double totalCommTax = double.tryParse('${_reportSummary['total_commission_tax'] ?? 0}') ?? 0.0;
    final double totalTcsTds = (double.tryParse('${_reportSummary['total_tcs'] ?? 0}') ?? 0.0) +
        (double.tryParse('${_reportSummary['total_tds'] ?? 0}') ?? 0.0);
    final double netPayout = double.tryParse('${_reportSummary['total_net_payout'] ?? 0}') ?? 0.0;
    final double totalPctComm = double.tryParse('${_reportSummary['total_commission_percentage_amount'] ?? 0}') ?? 0.0;
    final double totalFixedComm = double.tryParse('${_reportSummary['total_commission_fixed_amount'] ?? 0}') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Commission & Deductions Report'),
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
                  // Filters Container
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
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSource,
                            decoration: InputDecoration(
                              labelText: 'Sales Source / Channel',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                            items: _availableSources.map((src) {
                              return DropdownMenuItem<String>(
                                value: src,
                                child: Text(src),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSource = val;
                                });
                                _loadData();
                              }
                            },
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.insights, size: 18),
                          label: const Text('Generate Report'),
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

                  // KPI Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1100 ? 5 : constraints.maxWidth > 700 ? 3 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 5 ? 2.0 : 2.5,
                        children: [
                          _kpiCard(
                            title: 'Total Gross Sales',
                            value: _inr.format(totalSales),
                            icon: Icons.store_outlined,
                            color: const Color(0xFF3B82F6),
                          ),
                          _kpiCard(
                            title: 'Platform Commission',
                            value: _inr.format(totalComm),
                            icon: Icons.percent_outlined,
                            color: const Color(0xFFEF4444),
                          ),
                          _kpiCard(
                            title: 'GST on Commission',
                            value: _inr.format(totalCommTax),
                            icon: Icons.receipt_outlined,
                            color: const Color(0xFFF59E0B),
                          ),
                          _kpiCard(
                            title: 'TCS & TDS Deducted',
                            value: _inr.format(totalTcsTds),
                            icon: Icons.account_balance_outlined,
                            color: const Color(0xFF8B5CF6),
                          ),
                          _kpiCard(
                            title: 'Net Realized Payout',
                            value: _inr.format(netPayout),
                            icon: Icons.monetization_on_outlined,
                            color: const Color(0xFF10B981),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Chart & Summary Section
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double chartWidth = constraints.maxWidth > 800 ? constraints.maxWidth * 0.45 : constraints.maxWidth;
                      final double detailsWidth = constraints.maxWidth > 800 ? constraints.maxWidth * 0.50 : constraints.maxWidth;

                      return Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          // Deductions Breakdown Chart
                          Container(
                            width: chartWidth,
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
                                  'Payout vs Deductions Breakdown',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 220,
                                  child: totalSales == 0
                                      ? const Center(child: Text('No platform data available to chart'))
                                      : SfCircularChart(
                                          legend: const Legend(
                                            isVisible: true,
                                            overflowMode: LegendItemOverflowMode.wrap,
                                            position: LegendPosition.bottom,
                                          ),
                                          tooltipBehavior: TooltipBehavior(enable: true),
                                          series: <CircularSeries<_ChartData, String>>[
                                            DoughnutSeries<_ChartData, String>(
                                              dataSource: _getChartData(),
                                              xValueMapper: (_ChartData data, _) => data.category,
                                              yValueMapper: (_ChartData data, _) => data.value,
                                              pointColorMapper: (_ChartData data, _) => data.color,
                                              dataLabelSettings: const DataLabelSettings(
                                                isVisible: true,
                                                labelPosition: ChartDataLabelPosition.outside,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),

                          // Detailed Summary Metrics
                          Container(
                            width: detailsWidth,
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
                                  'Financial Statement Summary',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 16),
                                _summaryRow('Total Invoice Value (Gross Sales)', totalSales, isPrimary: true),
                                const SizedBox(height: 12),
                                _summaryRow('Total Base Taxable Value', totalTaxable, isPrimary: false),
                                const Divider(height: 24),
                                _summaryRow('(-) Commission Charges', totalComm, color: const Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                _summaryRow('(-) GST on Commission (18%)', totalCommTax, color: const Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                _summaryRow('(-) Tax Collected at Source (TCS)', double.tryParse('${_reportSummary['total_tcs'] ?? 0}') ?? 0.0, color: const Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                _summaryRow('(-) Tax Deductible at Source (TDS)', double.tryParse('${_reportSummary['total_tds'] ?? 0}') ?? 0.0, color: const Color(0xFFEF4444)),
                                const Divider(height: 24),
                                _summaryRow('Net Realized Settlement (Payout)', netPayout, isSuccess: true),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Ledger / Detailed Table
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
                          'Transaction Payout & Deductions Ledger',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text('Itemized sales with breakdown of all channel commission, GST, TCS and TDS deductions', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        _reportData.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('No transactions found with platform deductions in this range.'),
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
                                        DataColumn(label: Text('Sale No')),
                                        DataColumn(label: Text('Date')),
                                        DataColumn(label: Text('Source')),
                                        DataColumn(label: Text('Applied Rule')),
                                        DataColumn(label: Text('Customer')),
                                        DataColumn(label: Text('Taxable Value')),
                                        DataColumn(label: Text('Net Amount')),
                                        DataColumn(label: Text('Comm (%)')),
                                        DataColumn(label: Text('Pct Comm (₹)')),
                                        DataColumn(label: Text('Fixed Comm (₹)')),
                                        DataColumn(label: Text('Total Comm (₹)')),
                                        DataColumn(label: Text('Comm GST')),
                                        DataColumn(label: Text('TCS')),
                                        DataColumn(label: Text('TDS')),
                                        DataColumn(label: Text('Total Ded.')),
                                        DataColumn(label: Text('Net Payout')),
                                      ],
                                      rows: [
                                        ..._reportData.map((row) {
                                          final dateStr = row['sale_date'] != null
                                              ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(row['sale_date']))
                                              : 'N/A';
                                          final double deductions = double.tryParse('${row['deductions'] ?? 0}') ?? 0.0;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(
                                                '${row['sale_no']}',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              )),
                                              DataCell(Text(dateStr)),
                                              DataCell(Chip(
                                                label: Text('${row['sale_source']}'),
                                                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                padding: EdgeInsets.zero,
                                                backgroundColor: const Color(0xFFEFF6FF),
                                                side: BorderSide.none,
                                              )),
                                              DataCell(Text(
                                                '${row['applied_rules'] ?? 'Platform Fallback'}',
                                                style: TextStyle(
                                                  color: Colors.blue.shade800,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              )),
                                              DataCell(Text('${row['customer_name'] ?? 'Walk-in'}')),
                                              DataCell(Text(_inr.format(double.tryParse('${row['taxable_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(_inr.format(double.tryParse('${row['net_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text('${row['commission_rate']}%')),
                                              DataCell(Text(_inr.format(double.tryParse('${row['commission_percentage_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(_inr.format(double.tryParse('${row['commission_fixed_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(_inr.format(double.tryParse('${row['commission_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(_inr.format(double.tryParse('${row['commission_tax_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(_inr.format(double.tryParse('${row['tcs_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(_inr.format(double.tryParse('${row['tds_amount'] ?? 0}') ?? 0.0))),
                                              DataCell(Text(
                                                _inr.format(deductions),
                                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                              )),
                                              DataCell(Text(
                                                _inr.format(double.tryParse('${row['net_payout'] ?? 0}') ?? 0.0),
                                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                              )),
                                            ],
                                          );
                                        }),
                                        // Totals Row
                                        DataRow(
                                          color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          cells: [
                                            const DataCell(Text('TOTALS', style: TextStyle(fontWeight: FontWeight.w900))),
                                            const DataCell(Text('')),
                                            const DataCell(Text('')),
                                            const DataCell(Text('')),
                                            const DataCell(Text('')),
                                            DataCell(Text(_inr.format(totalTaxable), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(totalSales), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            const DataCell(Text('')),
                                            DataCell(Text(_inr.format(totalPctComm), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(totalFixedComm), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(totalComm), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(totalCommTax), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(double.tryParse('${_reportSummary['total_tcs'] ?? 0}') ?? 0.0), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(double.tryParse('${_reportSummary['total_tds'] ?? 0}') ?? 0.0), style: const TextStyle(fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(double.tryParse('${_reportSummary['total_deductions'] ?? 0}') ?? 0.0), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900))),
                                            DataCell(Text(_inr.format(netPayout), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900))),
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

  Widget _summaryRow(String label, double amount, {bool isPrimary = false, bool isSuccess = false, Color? color}) {
    final style = TextStyle(
      fontSize: isPrimary || isSuccess ? 15 : 14,
      fontWeight: isPrimary || isSuccess ? FontWeight.w800 : FontWeight.w600,
      color: isSuccess
          ? const Color(0xFF10B981)
          : color ?? const Color(0xFF1E293B),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          _inr.format(amount),
          style: style,
        ),
      ],
    );
  }
}

class _ChartData {
  final String category;
  final double value;
  final Color color;

  _ChartData(this.category, this.value, this.color);
}
