import 'damage_item_model.dart';

class Damage {
  final String damageNo;
  final DateTime damageDate;
  final List<DamageItem> items;

  Damage({
    required this.damageNo,
    required this.damageDate,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'header': {
        'damage_no': damageNo,
        'damage_date': damageDate.toIso8601String(),
      },
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
