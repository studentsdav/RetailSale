import 'purchase_item_model.dart';

class PurchaseOrder {
  final String poNo;
  final String manualNo;
  final int supplierId;
  final DateTime poDate;
  final DateTime? createdAt;
  final List<PurchaseItem> items;

  PurchaseOrder({
    required this.poNo,
    required this.manualNo,
    required this.supplierId,
    required this.poDate,
    this.createdAt,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      poNo: json['po_no'] ?? '',
      manualNo: json['manual_no'] ?? '',
      supplierId: json['supplier_id'],
      poDate: DateTime.parse(json['po_date']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      items:
          (json['items'] as List).map((e) => PurchaseItem.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'po_no': poNo,
        'manual_no': manualNo,
        'supplier_id': supplierId,
        'po_date': poDate.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };
}
