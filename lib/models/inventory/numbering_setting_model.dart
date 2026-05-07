class NumberingSetting {
  final int? id;
  final String module;
  final DateTime startDate;
  final int startNo;
  final String prefix;
  final String postfix;

  NumberingSetting({
    this.id,
    required this.module,
    required this.startDate,
    required this.startNo,
    required this.prefix,
    required this.postfix,
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  factory NumberingSetting.fromJson(Map<String, dynamic> json) {
    return NumberingSetting(
      id: json['id'],
      module: json['module'],
      startDate: DateTime.parse(json['start_date']),
      startNo: _toInt(json['start_no']),
      prefix: json['prefix'] ?? '',
      postfix: json['postfix'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'module': module,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'start_no': startNo,
      'prefix': prefix,
      'postfix': postfix,
    };
  }
}
