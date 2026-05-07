class DamageReportModel {
  final int damageId;
  final String damageNo;
  final DateTime date;
  final String status;
  final String approvalStatus;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String rejectionReason;
  final double totalValue;
  final List<DamageItemModel> items;

  DamageReportModel({
    required this.damageId,
    required this.damageNo,
    required this.date,
    required this.status,
    required this.approvalStatus,
    required this.approvedAt,
    required this.rejectedAt,
    required this.rejectionReason,
    required this.totalValue,
    required this.items,
  });

  factory DamageReportModel.fromJson(Map<String, dynamic> json) {
    return DamageReportModel(
      damageId: json['id'],
      damageNo: json['damage_no'],
      date: DateTime.parse(json['damage_date']),
      status: json['status'] ?? 'OPEN',
      approvalStatus: json['approval_status'] ?? 'PENDING',
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'].toString())
          : null,
      rejectionReason: json['rejection_reason'] ?? '',
      totalValue: double.tryParse(json['total_value'].toString()) ?? 0,
      items: (json['items'] as List)
          .map((e) => DamageItemModel.fromJson(e))
          .toList(),
    );
  }
}

class DamageItemModel {
  final String itemName;
  final String unit;
  final double qty;
  final double rate;
  final double amount;
  final String? remarks;

  DamageItemModel({
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.amount,
    this.remarks,
  });

  factory DamageItemModel.fromJson(Map<String, dynamic> json) {
    return DamageItemModel(
      itemName: json['item']['item_name'],
      unit: json['item']['unit'],
      qty: double.parse(json['qty'].toString()),
      rate: double.parse(json['rate'].toString()),
      amount: double.parse(json['amount'].toString()),
      remarks: json['remarks'],
    );
  }
}
