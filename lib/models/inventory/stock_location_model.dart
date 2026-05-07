class StockLocationdata {
  final int id;
  final String locationCode;
  final String locationName;
  final String description;
  final bool isActive;

  StockLocationdata({
    required this.id,
    required this.locationCode,
    required this.locationName,
    required this.description,
    required this.isActive,
  });

  factory StockLocationdata.fromJson(Map<String, dynamic> json) {
    return StockLocationdata(
      id: json['id'],
      locationCode: json['location_code'],
      locationName: json['location_name'],
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  // ✅ ADD THIS METHOD
  Map<String, dynamic> toJson() {
    return {
      'location_code': locationCode,
      'location_name': locationName,
      'description': description,
      'is_active': isActive,
    };
  }
}
