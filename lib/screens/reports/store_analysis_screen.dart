import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/reports/store_analysis_controller.dart';

class StoreAnalysisScreen extends StatefulWidget {
  const StoreAnalysisScreen({super.key});

  @override
  State<StoreAnalysisScreen> createState() => _StoreAnalysisScreenState();
}

class _StoreAnalysisScreenState extends State<StoreAnalysisScreen> {
  final StoreAnalysisController _controller = StoreAnalysisController();
  final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _rfmFuture = _controller.fetchRfmSegments();
    _trendFuture = _controller.fetchSalesTrend();
    _basketFuture = _controller.fetchMarketBasket();
    _topCustomerItemsFuture = _controller.fetchTopCustomerItems();
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
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
        title: const Text('Store Analysis'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
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
                              subtitle: 'Champions, At-Risk, Churned and New',
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
                                    pointColorMapper: (d, _) =>
                                        _segmentColor(d.segment),
                                    dataLabelSettings: const DataLabelSettings(
                                      isVisible: true,
                                    ),
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
                            final data =
                                snapshot.data ?? const <MarketBasketPoint>[];
                            return _chartShell(
                              title: 'Market Basket (Top 10 Pairs)',
                              subtitle: 'Frequently billed together',
                              snapshot: snapshot,
                              builder: () => SfCartesianChart(
                                tooltipBehavior: _basketTooltip,
                                primaryXAxis: const CategoryAxis(
                                  title: AxisTitle(text: 'Item Pair'),
                                ),
                                primaryYAxis: const NumericAxis(
                                  title: AxisTitle(text: 'Occurrences'),
                                ),
                                series: <CartesianSeries>[
                                  BarSeries<MarketBasketPoint, String>(
                                    dataSource: data,
                                    xValueMapper: (d, _) => d.pairName,
                                    yValueMapper: (d, _) => d.occurrenceCount,
                                    color: const Color(0xFF0EA5E9),
                                    enableTooltip: true,
                                    dataLabelSettings: const DataLabelSettings(
                                      isVisible: true,
                                    ),
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
                  height: 420,
                  child: FutureBuilder<List<SalesTrendPoint>>(
                    future: _trendFuture,
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? const <SalesTrendPoint>[];
                      return _chartShell(
                        title: 'Sales Trend & Subscription Consumption',
                        subtitle: 'Last 30 days',
                        snapshot: snapshot,
                        builder: () => SfCartesianChart(
                          tooltipBehavior: _trendTooltip,
                          zoomPanBehavior: _zoomPan,
                          primaryXAxis: DateTimeAxis(
                            intervalType: DateTimeIntervalType.days,
                            dateFormat: DateFormat('dd MMM'),
                          ),
                          primaryYAxis: const NumericAxis(
                            title: AxisTitle(text: 'Revenue'),
                          ),
                          axes: const <ChartAxis>[
                            NumericAxis(
                              name: 'subscriptionAxis',
                              opposedPosition: true,
                              title: AxisTitle(text: 'Subscription Items'),
                            ),
                          ],
                          onTooltipRender: (TooltipArgs args) {
                            final int pointIdx =
                                (args.pointIndex ?? 0).toInt();
                            if (args.seriesIndex == 0) {
                              final y =
                                  _toDoubleSafe(args.dataPoints?[pointIdx].y);
                              args.text = 'Revenue: ${_inr.format(y)}';
                            } else if (args.seriesIndex == 1) {
                              final y =
                                  _toDoubleSafe(args.dataPoints?[pointIdx].y);
                              args.text =
                                  'Subscription Items: ${y.toStringAsFixed(2)}';
                            }
                          },
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
                              name: 'Subscription Items',
                              dataSource: data,
                              xValueMapper: (d, _) => d.date,
                              yValueMapper: (d, _) => d.subscriptionVolume,
                              yAxisName: 'subscriptionAxis',
                              color: const Color(0xFF16A34A),
                              enableTooltip: true,
                              markerSettings:
                                  const MarkerSettings(isVisible: true),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 420,
                  child: FutureBuilder<List<TopCustomerItemPoint>>(
                    future: _topCustomerItemsFuture,
                    builder: (context, snapshot) {
                      final data =
                          snapshot.data ?? const <TopCustomerItemPoint>[];
                      return _chartShell(
                        title: 'Top 10 Customer-Item Purchases',
                        subtitle:
                            'Shows which customer bought which item the most (by qty)',
                        snapshot: snapshot,
                        builder: () => SfCartesianChart(
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            format: 'point.x\nQty: point.y',
                          ),
                          primaryXAxis: const CategoryAxis(
                            title: AxisTitle(text: 'Customer + Item'),
                            labelRotation: -35,
                          ),
                          primaryYAxis: const NumericAxis(
                            title: AxisTitle(text: 'Total Qty'),
                          ),
                          series: <CartesianSeries>[
                            ColumnSeries<TopCustomerItemPoint, String>(
                              dataSource: data,
                              xValueMapper: (d, _) => d.label,
                              yValueMapper: (d, _) => d.totalQty,
                              dataLabelMapper: (d, _) =>
                                  '${d.totalQty.toStringAsFixed(2)} (${d.billCount} bills)',
                              color: const Color(0xFF0F766E),
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelAlignment: ChartDataLabelAlignment.top,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
