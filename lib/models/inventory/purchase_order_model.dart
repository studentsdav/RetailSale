import 'purchase_item_model.dart';

class PurchaseOrder {
  final String poNo;
  final String manualNo;
  final int supplierId;
  final DateTime poDate;
  final List<PurchaseItem> items;

  PurchaseOrder({
    required this.poNo,
    required this.manualNo,
    required this.supplierId,
    required this.poDate,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      poNo: json['po_no'] ?? '',
      manualNo: json['manual_no'] ?? '',
      supplierId: json['supplier_id'],
      poDate: DateTime.parse(json['po_date']),
      items:
          (json['items'] as List).map((e) => PurchaseItem.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'po_no': poNo,
        'manual_no': manualNo,
        'supplier_id': supplierId,
        'po_date': poDate.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };
}
