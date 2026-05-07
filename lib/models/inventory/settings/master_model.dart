class GroupModel {
  final int id;
  final String groupName;

  GroupModel({
    required this.id,
    required this.groupName,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      groupName: json['group_name'] ?? '',
    );
  }
}

class SubCategoryModel {
  final int id;
  final int groupId;
  final String subCategoryName;

  SubCategoryModel({
    required this.id,
    required this.groupId,
    required this.subCategoryName,
  });

  factory SubCategoryModel.fromJson(Map<String, dynamic> json) {
    return SubCategoryModel(
      id: json['id'],
      groupId: json['group_id'],
      subCategoryName: json['subcategory_name'] ?? '',
    );
  }
}

class BrandModel {
  final int id;
  final String brandName;

  BrandModel({
    required this.id,
    required this.brandName,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'],
      brandName: json['brand_name'] ?? '',
    );
  }
}
