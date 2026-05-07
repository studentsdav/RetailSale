import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class RfmSegmentPoint {
  final String segment;
  final int customerCount;

  const RfmSegmentPoint({
    required this.segment,
    required this.customerCount,
  });

  factory RfmSegmentPoint.fromJson(Map<String, dynamic> json) {
    return RfmSegmentPoint(
      segment: (json['segment'] ?? '').toString(),
      customerCount: _toIntSafe(json['customerCount']),
    );
  }
}

class SalesTrendPoint {
  final DateTime date;
  final double revenue;
  final double subscriptionVolume;

  const SalesTrendPoint({
    required this.date,
    required this.revenue,
    required this.subscriptionVolume,
  });

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    return SalesTrendPoint(
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      revenue: _toDoubleSafe(json['revenue']),
      subscriptionVolume: _toDoubleSafe(json['subscriptionVolume']),
    );
  }
}

class MarketBasketPoint {
  final String pairName;
  final int occurrenceCount;

  const MarketBasketPoint({
    required this.pairName,
    required this.occurrenceCount,
  });

  factory MarketBasketPoint.fromJson(Map<String, dynamic> json) {
    return MarketBasketPoint(
      pairName: (json['pairName'] ?? '').toString(),
      occurrenceCount: _toIntSafe(json['occurrenceCount']),
    );
  }
}

class TopCustomerItemPoint {
  final String customerName;
  final String itemName;
  final String label;
  final double totalQty;
  final int billCount;

  const TopCustomerItemPoint({
    required this.customerName,
    required this.itemName,
    required this.label,
    required this.totalQty,
    required this.billCount,
  });

  factory TopCustomerItemPoint.fromJson(Map<String, dynamic> json) {
    return TopCustomerItemPoint(
      customerName: (json['customerName'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      totalQty: _toDoubleSafe(json['totalQty']),
      billCount: _toIntSafe(json['billCount']),
    );
  }
}

double _toDoubleSafe(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toIntSafe(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ??
      double.tryParse(value?.toString() ?? '')?.toInt() ??
      0;
}

class StoreAnalysisController {
  Future<List<RfmSegmentPoint>> fetchRfmSegments() async {
    final res = await ApiClient.get(ApiEndpoints.analyticsRfmSegments);
    final rows = List<Map<String, dynamic>>.from(
      (res['data'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return rows.map(RfmSegmentPoint.fromJson).toList();
  }

  Future<List<SalesTrendPoint>> fetchSalesTrend() async {
    final res = await ApiClient.get(ApiEndpoints.analyticsSalesTrend);
    final rows = List<Map<String, dynamic>>.from(
      (res['data'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return rows.map(SalesTrendPoint.fromJson).toList();
  }

  Future<List<MarketBasketPoint>> fetchMarketBasket() async {
    final res = await ApiClient.get(ApiEndpoints.analyticsMarketBasket);
    final rows = List<Map<String, dynamic>>.from(
      (res['data'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return rows.map(MarketBasketPoint.fromJson).toList();
  }

  Future<List<TopCustomerItemPoint>> fetchTopCustomerItems() async {
    final res = await ApiClient.get(ApiEndpoints.analyticsTopCustomerItems);
    final rows = List<Map<String, dynamic>>.from(
      (res['data'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return rows.map(TopCustomerItemPoint.fromJson).toList();
  }
}
