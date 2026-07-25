import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../controllers/reports/finance_hub_controller.dart';
import '../../models/reports/finance_models.dart';
import '../../models/inventory/supplier_model.dart';
import '../../core/api/api_client.dart';

class ExpenseAnalyticsScreen extends StatefulWidget {
  final FinanceHubController ctrl;

  const ExpenseAnalyticsScreen({super.key, required this.ctrl});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  bool allOutlets = false;
  bool loading = true;
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncDates();
    _fetchData();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  void _syncDates() {
    _fromCtrl.text = DateFormat('dd-MM-yyyy').format(fromDate);
    _toCtrl.text = DateFormat('dd-MM-yyyy').format(toDate);
  }

  Future<void> _fetchData() async {
    if (!loading) {
      if (mounted) {
        setState(() => loading = true);
      }
    }
    try {
      await widget.ctrl.loadExpenseAnalytics(
        fromDate: fromDate,
        toDate: toDate,
        allOutlets: allOutlets,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _fmt(double val) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(val);
  }

  String _dateStr(DateTime date) {
    return DateFormat('dd-MMM-yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final analytics = widget.ctrl.expenseAnalytics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense & Tax Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : analytics == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No analytics data available.'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFiltersCard(),
                          const SizedBox(height: 16),
                          _buildMetricsGrid(analytics),
                          const SizedBox(height: 24),
                          if (MediaQuery.of(context).size.width > 750)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildCategorySpendChart(analytics)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTaxOutflowChart(analytics)),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildCategorySpendChart(analytics),
                                const SizedBox(height: 16),
                                _buildTaxOutflowChart(analytics),
                              ],
                            ),
                          const SizedBox(height: 24),
                          _buildVendorsLeaderboard(analytics),
                          const SizedBox(height: 24),
                          _buildVendorsTable(analytics),
                          const SizedBox(height: 24),
                          _buildTransactionsTable(analytics),
                        ],
                      ),
                    ),
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

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
        _syncDates();
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        toDate = picked;
        _syncDates();
      });
    }
  }

  Widget _buildFiltersCard() {
    return Container(
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
            onPressed: _fetchData,
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
    );
  }

  Widget _buildMetricsGrid(ExpenseAnalyticsModel data) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          _buildMetricCard(
            title: 'Total Spend (Gross)',
            value: _fmt(data.totalSpend),
            icon: Icons.wallet_outlined,
            color: Colors.indigo,
          ),
          _buildMetricCard(
            title: 'Input Tax Credit (GST)',
            value: _fmt(data.totalInputTaxPaid),
            icon: Icons.receipt_long_outlined,
            color: Colors.teal,
          ),
          _buildMetricCard(
            title: 'TDS Deducted',
            value: _fmt(data.totalTdsDeducted),
            icon: Icons.shield_outlined,
            color: Colors.orange,
          ),
          _buildMetricCard(
            title: 'TCS Collected',
            value: _fmt(data.totalTcsCollected),
            icon: Icons.currency_rupee_outlined,
            color: Colors.deepOrange,
          ),
        ],
      );
    });
  }

  Widget _buildMetricCard({
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
        padding: const EdgeInsets.all(16),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
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

  Widget _buildCategorySpendChart(ExpenseAnalyticsModel data) {
    final list = data.categoryBreakdown;
    final chartData = list.map((item) {
      return CategoryChartData(
        categoryName: item['category']?.toString() ?? 'General',
        totalSpend: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Spend Share',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (chartData.isEmpty)
              const SizedBox(
                height: 250,
                child: Center(child: Text('No category data available.')),
              )
            else
              SizedBox(
                height: 250,
                child: SfCircularChart(
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.right,
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CircularSeries>[
                    DoughnutSeries<CategoryChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (CategoryChartData d, _) => d.categoryName,
                      yValueMapper: (CategoryChartData d, _) => d.totalSpend,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                      enableTooltip: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxOutflowChart(ExpenseAnalyticsModel data) {
    final list = data.taxBreakdown;
    final chartData = list.map((item) {
      return TaxChartData(
        taxName: item['name']?.toString() ?? 'Custom',
        taxAmount: double.tryParse(item['value']?.toString() ?? '0') ?? 0.0,
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tax Outflow Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (chartData.isEmpty)
              const SizedBox(
                height: 250,
                child: Center(child: Text('No tax data available.')),
              )
            else
              SizedBox(
                height: 250,
                child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    ColumnSeries<TaxChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (TaxChartData d, _) => d.taxName,
                      yValueMapper: (TaxChartData d, _) => d.taxAmount,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                      color: const Color(0xFF3A7BD5),
                      enableTooltip: true,
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsLeaderboard(ExpenseAnalyticsModel data) {
    final list = data.vendorSpend.take(5).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Spend Leaderboard (Vendors)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No vendor spending data available.')),
              )
            else
              Column(
                children: list.map((item) {
                  final index = list.indexOf(item);
                  final name = item['vendor']?.toString() ?? 'Direct Cash / Unknown';
                  final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                  final maxAmt = double.tryParse(list.first['amount']?.toString() ?? '1') ?? 1.0;
                  final percent = maxAmt > 0 ? amount / maxAmt : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${index + 1}. $name',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              _fmt(amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade100,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsTable(ExpenseAnalyticsModel data) {
    final list = data.vendorSpend;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vendor-wise Spend Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No vendor spend records.')))
            else
              Theme(
                data: Theme.of(context).copyWith(dividerColor: const Color(0xFFE2E8F0)),
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Vendor Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total Spend (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: list.map((item) {
                        final name = item['vendor']?.toString() ?? 'Direct Cash / Unknown';
                        final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                        return DataRow(
                          cells: [
                            DataCell(Text(name)),
                            DataCell(Text(_fmt(amount))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTable(ExpenseAnalyticsModel data) {
    final list = data.expenses;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Transactions List',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No expense transactions recorded.')))
            else
              Theme(
                data: Theme.of(context).copyWith(dividerColor: const Color(0xFFE2E8F0)),
                child: Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Method', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Ref No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Base Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Tax (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Deduction (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Net Total (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Remarks / Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: list.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(DateFormat('dd-MMM-yyyy').format(item.expenseDate))),
                            DataCell(Text(item.category)),
                            DataCell(Text(item.vendorName.isNotEmpty ? item.vendorName : 'Direct Cash')),
                            DataCell(Text(item.paymentMethod)),
                            DataCell(Text(item.invoiceRefNo.isNotEmpty ? item.invoiceRefNo : '-')),
                            DataCell(Text(item.baseAmount.toStringAsFixed(2))),
                            DataCell(Text(item.totalTaxAmount.toStringAsFixed(2))),
                            DataCell(Text(item.totalDeductionAmount.toStringAsFixed(2))),
                            DataCell(Text(item.amount.toStringAsFixed(2))),
                            DataCell(Text(item.note.isNotEmpty ? item.note : '-')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryChartData {
  final String categoryName;
  final double totalSpend;

  CategoryChartData({required this.categoryName, required this.totalSpend});
}

class TaxChartData {
  final String taxName;
  final double taxAmount;

  TaxChartData({required this.taxName, required this.taxAmount});
}
