class BOMItem {
  final int? id;
  final int componentItemId;
  final String itemCode;
  final String itemName;
  final String unit;
  final double rate;
  final double quantity;
  final double cost;

  BOMItem({
    this.id,
    required this.componentItemId,
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.rate,
    required this.quantity,
    required this.cost,
  });

  factory BOMItem.fromJson(Map<String, dynamic> json) {
    return BOMItem(
      id: json['id'],
      componentItemId: json['component_item_id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      unit: json['unit'] ?? '',
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      cost: double.tryParse(json['cost']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'component_item_id': componentItemId,
      'item_code': itemCode,
      'item_name': itemName,
      'unit': unit,
      'rate': rate,
      'quantity': quantity,
      'cost': cost,
    };
  }
}

class BOMDefinition {
  final int parentItemId;
  final List<BOMItem> components;
  final double compositeCost;

  BOMDefinition({
    required this.parentItemId,
    required this.components,
    required this.compositeCost,
  });

  factory BOMDefinition.fromJson(Map<String, dynamic> json) {
    var compsList = json['components'] as List? ?? [];
    List<BOMItem> comps = compsList.map((e) => BOMItem.fromJson(e)).toList();

    return BOMDefinition(
      parentItemId: json['parent_item_id'] ?? 0,
      components: comps,
      compositeCost: double.tryParse(json['composite_cost']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class AssemblyHeader {
  final int? id;
  final String assemblyNo;
  final String assemblyDate;
  final int parentItemId;
  final String parentItemName;
  final String parentItemCode;
  final String parentUnit;
  final double qty;
  final double compositeCost;
  final double totalCost;
  final String notes;
  final int createdBy;
  final String status;
  final List<AssemblyItem> items;

  AssemblyHeader({
    this.id,
    required this.assemblyNo,
    required this.assemblyDate,
    required this.parentItemId,
    required this.parentItemName,
    required this.parentItemCode,
    required this.parentUnit,
    required this.qty,
    required this.compositeCost,
    required this.totalCost,
    required this.notes,
    required this.createdBy,
    this.status = 'RUNNING',
    this.items = const [],
  });

  factory AssemblyHeader.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<AssemblyItem> parsedItems = itemsList.map((e) => AssemblyItem.fromJson(e)).toList();
    
    var parent = json['parent_item'] as Map? ?? {};

    return AssemblyHeader(
      id: json['id'],
      assemblyNo: json['assembly_no'] ?? '',
      assemblyDate: json['assembly_date'] ?? '',
      parentItemId: json['parent_item_id'] ?? 0,
      parentItemName: parent['item_name'] ?? '',
      parentItemCode: parent['item_code'] ?? '',
      parentUnit: parent['unit'] ?? '',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      compositeCost: double.tryParse(json['composite_cost']?.toString() ?? '0') ?? 0.0,
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] ?? '',
      createdBy: json['created_by'] ?? 0,
      status: json['status'] ?? 'RUNNING',
      items: parsedItems,
    );
  }
}

class AssemblyItem {
  final int? id;
  final int componentItemId;
  final String componentItemName;
  final String componentItemCode;
  final String componentUnit;
  final double qtyRequired;
  final double qtyUsed;
  final double rate;
  final double totalCost;

  AssemblyItem({
    this.id,
    required this.componentItemId,
    required this.componentItemName,
    required this.componentItemCode,
    required this.componentUnit,
    required this.qtyRequired,
    required this.qtyUsed,
    required this.rate,
    required this.totalCost,
  });

  factory AssemblyItem.fromJson(Map<String, dynamic> json) {
    var comp = json['component_item'] as Map? ?? {};
    return AssemblyItem(
      id: json['id'],
      componentItemId: json['component_item_id'] ?? 0,
      componentItemName: comp['item_name'] ?? '',
      componentItemCode: comp['item_code'] ?? '',
      componentUnit: comp['unit'] ?? '',
      qtyRequired: double.tryParse(json['qty_required']?.toString() ?? '0') ?? 0.0,
      qtyUsed: double.tryParse(json['qty_used']?.toString() ?? '0') ?? 0.0,
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0.0,
    );
  }
}
