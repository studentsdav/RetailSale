import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

enum Period { day, week, month }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Period _period = Period.day;
  final bool _loading = false;
  final _rnd = Random(10);

  // KPIs
  final int _totalItems = 520;
  final int _lowStock = 18;
  final int _todayTxn = 42;
  final double _stockValue = 845230.50;

  // Charts
  late List<_StockMove> _stockMovement;
  late List<_CategoryStock> _categoryStock;
  late List<_DeptIssue> _deptIssue;
  late List<_DamageTrend> _damageTrend;

  @override
  void initState() {
    super.initState();
    _generateMock();
  }

  void _generateMock() {
    _stockMovement = List.generate(7, (i) {
      return _StockMove(
        'D${i + 1}',
        200 + _rnd.nextInt(300),
        150 + _rnd.nextInt(200),
      );
    });

    _categoryStock = [
      _CategoryStock('F&B', 45),
      _CategoryStock('Housekeeping', 30),
      _CategoryStock('Maintenance', 15),
      _CategoryStock('Amenities', 10),
    ];

    _deptIssue = [
      _DeptIssue('Kitchen', 320),
      _DeptIssue('HK', 260),
      _DeptIssue('FO', 140),
      _DeptIssue('Maintenance', 180),
    ];

    _damageTrend = List.generate(6, (i) {
      return _DamageTrend('M${i + 1}', 20 + _rnd.nextInt(50));
    });

    setState(() {});
  }

  // ================= KPI CARD =================
  Widget _kpi(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ================= PERIOD =================
  Widget _periodToggle() {
    return ToggleButtons(
      borderRadius: BorderRadius.circular(8),
      isSelected: [
        _period == Period.day,
        _period == Period.week,
        _period == Period.month,
      ],
      onPressed: (i) => setState(() => _period = Period.values[i]),
      children: const [
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Day')),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Week')),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Month')),
      ],
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Retail Dashboard'),
        actions: [
          IconButton(onPressed: _generateMock, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // KPI ROW
                  Row(
                    children: [
                      Expanded(
                          child: _kpi('Total Items', '$_totalItems',
                              Icons.inventory_2, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _kpi('Low Stock', '$_lowStock', Icons.warning,
                              Colors.red)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _kpi('Today Txn', '$_todayTxn', Icons.sync,
                              Colors.teal)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _kpi(
                              'Stock Value',
                              '₹${_stockValue.toStringAsFixed(0)}',
                              Icons.currency_rupee,
                              Colors.purple)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _periodToggle(),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.inventory),
                        label: const Text('Item Master'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.receipt),
                        label: const Text('GRN'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call_split),
                        label: const Text('Issue'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: Row(
                      children: [
                        // LEFT
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _card(_stockMovementChart()),
                                const SizedBox(height: 12),
                                _card(_damageChart()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // RIGHT
                        SizedBox(
                          width: isWide ? 420 : 320,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _card(_categoryChart()),
                                const SizedBox(height: 12),
                                _card(_deptIssueChart()),
                              ],
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

  // ================= CHARTS =================
  Widget _stockMovementChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Stock Movement'),
      primaryXAxis: const CategoryAxis(),
      legend: const Legend(isVisible: true),
      series: [
        ColumnSeries<_StockMove, String>(
          name: 'Received',
          dataSource: _stockMovement,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.received,
        ),
        ColumnSeries<_StockMove, String>(
          name: 'Issued',
          dataSource: _stockMovement,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.issued,
        ),
      ],
    );
  }

  Widget _categoryChart() {
    return SfCircularChart(
      title: const ChartTitle(text: 'Stock by Category'),
      legend: const Legend(isVisible: true),
      series: [
        DoughnutSeries<_CategoryStock, String>(
          dataSource: _categoryStock,
          xValueMapper: (d, _) => d.category,
          yValueMapper: (d, _) => d.percent,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        )
      ],
    );
  }

  Widget _deptIssueChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Department-wise Issue'),
      primaryXAxis: const CategoryAxis(),
      series: [
        BarSeries<_DeptIssue, String>(
          dataSource: _deptIssue,
          xValueMapper: (d, _) => d.dept,
          yValueMapper: (d, _) => d.qty,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        )
      ],
    );
  }

  Widget _damageChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Damage / Wastage'),
      primaryXAxis: const CategoryAxis(),
      series: [
        LineSeries<_DamageTrend, String>(
          dataSource: _damageTrend,
          xValueMapper: (d, _) => d.month,
          yValueMapper: (d, _) => d.qty,
          markerSettings: const MarkerSettings(isVisible: true),
        )
      ],
    );
  }

  Widget _card(Widget child) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

// ================= DATA MODELS =================
class _StockMove {
  final String day;
  final int received;
  final int issued;
  _StockMove(this.day, this.received, this.issued);
}

class _CategoryStock {
  final String category;
  final int percent;
  _CategoryStock(this.category, this.percent);
}

class _DeptIssue {
  final String dept;
  final int qty;
  _DeptIssue(this.dept, this.qty);
}

class _DamageTrend {
  final String month;
  final int qty;
  _DamageTrend(this.month, this.qty);
}
