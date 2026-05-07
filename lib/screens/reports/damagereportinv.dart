import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/damage_report_controller.dart';
import '../../models/reports/damage_item_model.dart';

class DamageReportScreen extends StatefulWidget {
  const DamageReportScreen({super.key});

  @override
  State<DamageReportScreen> createState() => _DamageReportScreenState();
}

class _DamageReportScreenState extends State<DamageReportScreen> {
  final ctrl = DamageReportController();

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(title: const Text('Damage Report')),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) {
          if (ctrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _kpiRow(),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _categoryChart()),
                      const SizedBox(width: 12),
                      Expanded(child: _trendChart()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(child: _topItemChart()),
                const SizedBox(width: 12),
                //   Expanded(child: _table(context)),

                Expanded(child: _table(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- KPI ----------------
  Widget _kpiRow() {
    return Row(
      children: [
        _kpi('Total Qty', ctrl.totalQty.toString(), Icons.warning, Colors.red),
        const SizedBox(width: 12),
        _kpi('Total Value', '₹${ctrl.totalValue.toStringAsFixed(0)}',
            Icons.currency_rupee, Colors.purple),
        const SizedBox(width: 12),
        _kpi('Today Damage', ctrl.todayQty.toString(), Icons.today,
            Colors.orange),
        const SizedBox(width: 12),
        _kpi('Top Category', ctrl.topCategory, Icons.category, Colors.blue),
      ],
    );
  }

  Widget _kpi(String t, String v, IconData i, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: c, child: Icon(i, color: Colors.white)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text(v,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ---------------- CHARTS ----------------
  Widget _categoryChart() {
    return Card(
      child: SfCircularChart(
        title: const ChartTitle(text: 'Damage by Category'),
        legend: const Legend(isVisible: true),
        series: [
          DoughnutSeries<CategoryDamage, String>(
            dataSource: ctrl.categoryData,
            xValueMapper: (d, _) => d.category,
            yValueMapper: (d, _) => d.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  Widget _trendChart() {
    return Card(
      child: SfCartesianChart(
        title: const ChartTitle(text: 'Last 7 Days Damage'),
        primaryXAxis: const CategoryAxis(),
        series: [
          ColumnSeries<DailyDamage, String>(
            dataSource: ctrl.last7Days,
            xValueMapper: (d, _) => d.day,
            yValueMapper: (d, _) => d.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  Widget _topItemChart() {
    return Builder(builder: (context) {
      return Card(
        child: SfCartesianChart(
          title: const ChartTitle(text: 'Top Damaged Items'),
          primaryXAxis: const CategoryAxis(),
          series: [
            BarSeries<DamageItem, String>(
              dataSource: ctrl.topItems,
              xValueMapper: (d, _) => d.item,
              yValueMapper: (d, _) => d.amount,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            ),
          ],
        ),
      );
    });
  }

  // ---------------- TABLE ----------------
  Widget _table(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHighest),
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Rate')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Reason')),
                    DataColumn(label: Text('User')),
                  ],
                  rows: ctrl.items.map((e) {
                    return DataRow(
                      color: WidgetStateProperty.all(
                        e.amount > 500
                            ? Colors.red.withOpacity(.08)
                            : Colors.transparent,
                      ),
                      cells: [
                        DataCell(Text(DateFormat('dd-MMM').format(e.date))),
                        DataCell(Text(e.item)),
                        DataCell(Text(e.category)),
                        DataCell(Text(e.qty.toString())),
                        DataCell(Text(e.rate.toStringAsFixed(2))),
                        DataCell(Text(e.amount.toStringAsFixed(2))),
                        DataCell(Text(e.reason)),
                        DataCell(Text(e.user)),
                      ],
                    );
                  }).toList(),
                ),
              )));
    });
  }
}

// ---------------- MODELS ----------------
class _CategoryDamage {
  final String category;
  final double value;
  _CategoryDamage(this.category, this.value);
}

class _DailyDamage {
  final String day;
  final double value;
  _DailyDamage(this.day, this.value);
}
