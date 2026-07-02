class AttributeValue {
  final int id;
  final int attributeId;
  final String value;
  final bool isActive;
  final String? attributeName;

  AttributeValue({
    required this.id,
    required this.attributeId,
    required this.value,
    this.isActive = true,
    this.attributeName,
  });

  factory AttributeValue.fromJson(Map<String, dynamic> json) {
    String? attrName;
    if (json['attribute'] != null) {
      attrName = json['attribute']['name'];
    }
    return AttributeValue(
      id: json['id'],
      attributeId: json['attribute_id'],
      value: json['value'],
      isActive: json['is_active'] ?? true,
      attributeName: attrName ?? json['attribute_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'attribute_id': attributeId,
      'value': value,
      'is_active': isActive,
      'attribute_name': attributeName,
    };
  }
}

class Attribute {
  final int id;
  final String name;
  final bool isActive;
  final List<AttributeValue> values;

  Attribute({
    required this.id,
    required this.name,
    this.isActive = true,
    this.values = const [],
  });

  factory Attribute.fromJson(Map<String, dynamic> json) {
    var rawValues = json['values'] as List?;
    List<AttributeValue> vals = rawValues != null
        ? rawValues.map((e) => AttributeValue.fromJson(e)).toList()
        : [];

    return Attribute(
      id: json['id'],
      name: json['name'],
      isActive: json['is_active'] ?? true,
      values: vals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      'values': values.map((e) => e.toJson()).toList(),
    };
  }
}
