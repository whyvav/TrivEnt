// Represents both Products (finished bricks) and Raw Materials (clay, coal, etc.)
class ItemModel {
  final String id;
  final String name;
  final String category;      // 'product' or 'raw_material'
  final String unit;          // 'pieces', 'kg', 'tons', etc.
  final double salePrice;
  final double purchasePrice;
  final double taxPercent;
  final double stockQty;
  final double minStockAlert;
  final String? hsn;
  final String? description;
  final DateTime createdAt;

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.taxPercent = 0,
    this.stockQty = 0,
    this.minStockAlert = 0,
    this.hsn,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'salePrice': salePrice,
      'purchasePrice': purchasePrice,
      'taxPercent': taxPercent,
      'stockQty': stockQty,
      'minStockAlert': minStockAlert,
      'hsn': hsn,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore Map
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'product',
      unit: map['unit'] ?? 'pieces',
      salePrice: (map['salePrice'] ?? 0).toDouble(),
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      taxPercent: (map['taxPercent'] ?? 0).toDouble(),
      stockQty: (map['stockQty'] ?? 0).toDouble(),
      minStockAlert: (map['minStockAlert'] ?? 0).toDouble(),
      hsn: map['hsn'],
      description: map['description'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  // Copy with some fields changed (like Python dataclass replace)
  ItemModel copyWith({double? stockQty}) {
    return ItemModel(
      id: id,
      name: name,
      category: category,
      unit: unit,
      salePrice: salePrice,
      purchasePrice: purchasePrice,
      taxPercent: taxPercent ?? this.taxPercent,
      stockQty: stockQty ?? this.stockQty,
      minStockAlert: minStockAlert,
      hsn: hsn,
      description: description,
      createdAt: createdAt,
    );
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ItemModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}