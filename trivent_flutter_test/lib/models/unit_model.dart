class UnitModel {
  final String id;
  final String fullName;   // "Kilogram"
  final String shortName;  // "kg"
  final bool isDefault;    // built-in, cannot be deleted

  UnitModel({
    required this.id,
    required this.fullName,
    required this.shortName,
    this.isDefault = false,
  });

  String get display => '$fullName ($shortName)';

  Map<String, dynamic> toMap() => {
    'id': id,
    'fullName': fullName,
    'shortName': shortName,
    'isDefault': isDefault,
  };

  factory UnitModel.fromMap(Map<String, dynamic> m) => UnitModel(
    id: m['id'] ?? '',
    fullName: m['fullName'] ?? '',
    shortName: m['shortName'] ?? '',
    isDefault: m['isDefault'] ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UnitModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  static List<UnitModel> get defaults => [
    UnitModel(id: 'pcs', fullName: 'Piece', shortName: 'pcs', isDefault: true),
    UnitModel(id: 'kg', fullName: 'Kilogram', shortName: 'kg', isDefault: true),
    UnitModel(id: 'g', fullName: 'Gram', shortName: 'g', isDefault: true),
    UnitModel(id: 'ton', fullName: 'Metric Ton', shortName: 'ton', isDefault: true),
    UnitModel(id: 'L', fullName: 'Liter', shortName: 'L', isDefault: true),
    UnitModel(id: 'bag', fullName: 'Bag', shortName: 'bag', isDefault: true),
    UnitModel(id: 'm3', fullName: 'Cubic Meter', shortName: 'm³', isDefault: true),
    UnitModel(id: 'sqft', fullName: 'Square Foot', shortName: 'sq ft', isDefault: true),
    UnitModel(id: 'no', fullName: 'Number', shortName: 'no.', isDefault: true),
    UnitModel(id: 'truck', fullName: 'Truck Load', shortName: 'truck', isDefault: true),
  ];
}