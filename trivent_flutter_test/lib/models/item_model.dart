class ItemModel {
  final String id;
  final String name;
  final String category;          // 'product' or 'raw_material'
  final String primaryUnit;
  final String? secondaryUnit;
  final double? conversionFactor; // 1 primaryUnit = conversionFactor secondaryUnits
  final String? itemCode;
  final String? description;
  final String? hsn;
  final double salePrice;
  final bool salePriceWithTax;    // whether salePrice already includes tax
  final double purchasePrice;
  final bool purchasePriceWithTax;
  final double taxPercent;
  final double stockQty;
  final double minStockAlert;
  final DateTime? stockAsOfDate;
  final double stockAtPrice;      // average price of opening stock
  final String? itemLocation;
  final DateTime createdAt;

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryUnit,
    this.secondaryUnit,
    this.conversionFactor,
    this.itemCode,
    this.description,
    this.hsn,
    this.salePrice = 0,
    this.salePriceWithTax = false,
    this.purchasePrice = 0,
    this.purchasePriceWithTax = false,
    this.taxPercent = 0,
    this.stockQty = 0,
    this.minStockAlert = 0,
    this.stockAsOfDate,
    this.stockAtPrice = 0,
    this.itemLocation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Effective prices (always excl. tax, for calculations)
  double get effectiveSalePrice => salePriceWithTax && taxPercent > 0
      ? salePrice / (1 + taxPercent / 100)
      : salePrice;

  double get effectivePurchasePrice => purchasePriceWithTax && taxPercent > 0
      ? purchasePrice / (1 + taxPercent / 100)
      : purchasePrice;

  double get stockValue => stockQty * (category == 'product' ? salePrice : purchasePrice);

  String get unitDisplay => primaryUnit;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'primaryUnit': primaryUnit,
    'secondaryUnit': secondaryUnit,
    'conversionFactor': conversionFactor,
    'itemCode': itemCode,
    'description': description,
    'hsn': hsn,
    'salePrice': salePrice,
    'salePriceWithTax': salePriceWithTax,
    'purchasePrice': purchasePrice,
    'purchasePriceWithTax': purchasePriceWithTax,
    'taxPercent': taxPercent,
    'stockQty': stockQty,
    'minStockAlert': minStockAlert,
    'stockAsOfDate': stockAsOfDate?.toIso8601String(),
    'stockAtPrice': stockAtPrice,
    'itemLocation': itemLocation,
    'createdAt': createdAt.toIso8601String(),
    // Legacy compat
    'unit': primaryUnit,
  };

  factory ItemModel.fromMap(Map<String, dynamic> m) => ItemModel(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    category: m['category'] ?? 'product',
    primaryUnit: m['primaryUnit'] ?? m['unit'] ?? 'pcs',
    secondaryUnit: m['secondaryUnit'],
    conversionFactor: m['conversionFactor'] != null
        ? (m['conversionFactor'] as num).toDouble()
        : null,
    itemCode: m['itemCode'],
    description: m['description'],
    hsn: m['hsn'],
    salePrice: (m['salePrice'] ?? 0).toDouble(),
    salePriceWithTax: m['salePriceWithTax'] ?? false,
    purchasePrice: (m['purchasePrice'] ?? 0).toDouble(),
    purchasePriceWithTax: m['purchasePriceWithTax'] ?? false,
    taxPercent: (m['taxPercent'] ?? 0).toDouble(),
    stockQty: (m['stockQty'] ?? 0).toDouble(),
    minStockAlert: (m['minStockAlert'] ?? 0).toDouble(),
    stockAsOfDate: m['stockAsOfDate'] != null
        ? DateTime.parse(m['stockAsOfDate'])
        : null,
    stockAtPrice: (m['stockAtPrice'] ?? 0).toDouble(),
    itemLocation: m['itemLocation'],
    createdAt: m['createdAt'] != null
        ? DateTime.parse(m['createdAt'])
        : DateTime.now(),
  );

  ItemModel copyWith({double? stockQty, double? taxPercent}) => ItemModel(
    id: id, name: name, category: category,
    primaryUnit: primaryUnit, secondaryUnit: secondaryUnit,
    conversionFactor: conversionFactor, itemCode: itemCode,
    description: description, hsn: hsn,
    salePrice: salePrice, salePriceWithTax: salePriceWithTax,
    purchasePrice: purchasePrice, purchasePriceWithTax: purchasePriceWithTax,
    taxPercent: taxPercent ?? this.taxPercent,
    stockQty: stockQty ?? this.stockQty,
    minStockAlert: minStockAlert,
    stockAsOfDate: stockAsOfDate, stockAtPrice: stockAtPrice,
    itemLocation: itemLocation, createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ItemModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}