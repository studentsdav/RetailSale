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

class FinancialMetricPoint {
  final String category;
  final double netSales;
  final double estimatedCogs;
  final double grossMargin;
  final double grossMarginPercent;

  const FinancialMetricPoint({
    required this.category,
    required this.netSales,
    required this.estimatedCogs,
    required this.grossMargin,
    required this.grossMarginPercent,
  });
}

class CreditAgingPoint {
  final String bracket;
  final double amount;
  final int customerCount;

  const CreditAgingPoint({
    required this.bracket,
    required this.amount,
    required this.customerCount,
  });
}

class GstCompliancePoint {
  final String hsnCode;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double totalTax;

  const GstCompliancePoint({
    required this.hsnCode,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalTax,
  });
}

class DeadstockPoint {
  final String itemCode;
  final String itemName;
  final String category;
  final double currentStock;
  final int daysWithoutSale;
  final double stockValue;

  const DeadstockPoint({
    required this.itemCode,
    required this.itemName,
    required this.category,
    required this.currentStock,
    required this.daysWithoutSale,
    required this.stockValue,
  });
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
    try {
      final res = await ApiClient.get(ApiEndpoints.analyticsRfmSegments);
      final rows = List<Map<String, dynamic>>.from(
        (res['data'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      return rows.map(RfmSegmentPoint.fromJson).toList();
    } catch (_) {
      return const [
        RfmSegmentPoint(segment: 'Champions', customerCount: 42),
        RfmSegmentPoint(segment: 'Loyal', customerCount: 88),
        RfmSegmentPoint(segment: 'At-Risk', customerCount: 25),
        RfmSegmentPoint(segment: 'New', customerCount: 34),
        RfmSegmentPoint(segment: 'Churned', customerCount: 12),
      ];
    }
  }

  Future<List<SalesTrendPoint>> fetchSalesTrend() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.analyticsSalesTrend);
      final rows = List<Map<String, dynamic>>.from(
        (res['data'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      return rows.map(SalesTrendPoint.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MarketBasketPoint>> fetchMarketBasket() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.analyticsMarketBasket);
      final rows = List<Map<String, dynamic>>.from(
        (res['data'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      return rows.map(MarketBasketPoint.fromJson).toList();
    } catch (_) {
      return const [
        MarketBasketPoint(pairName: 'Milk + Bread', occurrenceCount: 45),
        MarketBasketPoint(pairName: 'Butter + Biscuit', occurrenceCount: 28),
        MarketBasketPoint(pairName: 'Tea + Sugar', occurrenceCount: 22),
      ];
    }
  }

  Future<List<TopCustomerItemPoint>> fetchTopCustomerItems() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.analyticsTopCustomerItems);
      final rows = List<Map<String, dynamic>>.from(
        (res['data'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      return rows.map(TopCustomerItemPoint.fromJson).toList();
    } catch (_) {
      return [];
    }
  }
}
