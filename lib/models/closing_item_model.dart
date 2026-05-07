class ClosingItem {
  final String group;
  final String name;
  final String unit;
  final double avgRate;
  final double opening;
  final double receive;
  final double issue;
  final double damage;
  final double returned;
  final double supplierReturnQty;
  final double closing;

  ClosingItem({
    required this.group,
    required this.name,
    required this.unit,
    required this.avgRate,
    required this.opening,
    required this.receive,
    required this.issue,
    required this.damage,
    required this.returned,
    required this.supplierReturnQty,
    required this.closing,
  });

  factory ClosingItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v == null ? 0 : double.tryParse(v.toString()) ?? 0;

    return ClosingItem(
      group: json['group'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'] ?? '',
      avgRate: toDouble(json['avgRate']),
      opening: toDouble(json['opening']),
      receive: toDouble(json['receive']),
      issue: toDouble(json['issue']),
      damage: toDouble(json['damage']),
      returned: toDouble(json['returned']),
      supplierReturnQty: toDouble(json['supplierReturnQty']),
      closing: toDouble(json['closing']),
    );
  }

  double get amount => closing * avgRate;
}
