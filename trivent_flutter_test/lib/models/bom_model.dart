// Bill of Materials — the "recipe" for making a product
class BomMaterial {
  final String materialId;
  final String materialName;
  final double qtyPerUnit;   // How much raw material per 1 finished product
  final String unit;
  final double pricePerUnit;

  BomMaterial({
    required this.materialId,
    required this.materialName,
    required this.qtyPerUnit,
    required this.unit,
    required this.pricePerUnit,
  });

  double get costPerUnit => qtyPerUnit * pricePerUnit;

  Map<String, dynamic> toMap() => {
    'materialId': materialId,
    'materialName': materialName,
    'qtyPerUnit': qtyPerUnit,
    'unit': unit,
    'pricePerUnit': pricePerUnit,
  };

  factory BomMaterial.fromMap(Map<String, dynamic> m) => BomMaterial(
    materialId: m['materialId'] ?? '',
    materialName: m['materialName'] ?? '',
    qtyPerUnit: (m['qtyPerUnit'] ?? 0).toDouble(),
    unit: m['unit'] ?? '',
    pricePerUnit: (m['pricePerUnit'] ?? 0).toDouble(),
  );
}

class BomOtherCost {
  final String type;       // 'Labor', 'Electricity', 'Fuel', etc.
  final double costPerUnit;
  final String unit;

  BomOtherCost({required this.type, required this.costPerUnit, required this.unit});

  Map<String, dynamic> toMap() => {
    'type': type,
    'costPerUnit': costPerUnit,
    'unit': unit,
  };

  factory BomOtherCost.fromMap(Map<String, dynamic> m) => BomOtherCost(
    type: m['type'] ?? '',
    costPerUnit: (m['costPerUnit'] ?? 0).toDouble(),
    unit: m['unit'] ?? '',
  );
}

class BomModel {
  final String id;
  final String productId;
  final String productName;
  final List<BomMaterial> materials;
  final List<BomOtherCost> otherCosts;
  final DateTime createdAt;

  BomModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.materials,
    required this.otherCosts,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalMaterialCost =>
      materials.fold(0, (sum, m) => sum + m.costPerUnit);

  double get totalOtherCost =>
      otherCosts.fold(0, (sum, c) => sum + c.costPerUnit);

  double get totalCostPerUnit => totalMaterialCost + totalOtherCost;

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'materials': materials.map((m) => m.toMap()).toList(),
    'otherCosts': otherCosts.map((c) => c.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory BomModel.fromMap(Map<String, dynamic> map) => BomModel(
    id: map['id'] ?? '',
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    materials: (map['materials'] as List? ?? [])
        .map((m) => BomMaterial.fromMap(m))
        .toList(),
    otherCosts: (map['otherCosts'] as List? ?? [])
        .map((c) => BomOtherCost.fromMap(c))
        .toList(),
    createdAt: map['createdAt'] != null
        ? DateTime.parse(map['createdAt'])
        : DateTime.now(),
  );
}