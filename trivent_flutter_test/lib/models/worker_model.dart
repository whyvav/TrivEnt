class WorkerModel {
  final String id;
  final String name;
  final String? phone;
  final String role;          // e.g. 'Brick Contractor', 'Cleaner', 'Driver'
  final String type;          // 'contractor' | 'daily_wage'
  final double? dailyWage;    // ₹/day — for daily_wage type
  final double? ratePerUnit;  // ₹/unit — for contractor type
  final String? linkedProductId;
  final String? linkedProductName;
  final bool isActive;
  final DateTime createdAt;

  WorkerModel({
    required this.id,
    required this.name,
    this.phone,
    required this.role,
    required this.type,
    this.dailyWage,
    this.ratePerUnit,
    this.linkedProductId,
    this.linkedProductName,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isContractor => type == 'contractor';
  bool get isDailyWage => type == 'daily_wage';

  String get rateLabel {
    if (isContractor && ratePerUnit != null) return '₹${ratePerUnit!.toStringAsFixed(2)}/unit';
    if (isDailyWage && dailyWage != null) return '₹${dailyWage!.toStringAsFixed(0)}/day';
    return '';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (phone != null) 'phone': phone,
    'role': role,
    'type': type,
    if (dailyWage != null) 'dailyWage': dailyWage,
    if (ratePerUnit != null) 'ratePerUnit': ratePerUnit,
    if (linkedProductId != null) 'linkedProductId': linkedProductId,
    if (linkedProductName != null) 'linkedProductName': linkedProductName,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkerModel.fromMap(Map<String, dynamic> m) => WorkerModel(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'],
    role: m['role'] ?? '',
    type: m['type'] ?? 'daily_wage',
    dailyWage: m['dailyWage'] != null ? (m['dailyWage'] as num).toDouble() : null,
    ratePerUnit: m['ratePerUnit'] != null ? (m['ratePerUnit'] as num).toDouble() : null,
    linkedProductId: m['linkedProductId'],
    linkedProductName: m['linkedProductName'],
    isActive: m['isActive'] ?? true,
    createdAt: m['createdAt'] != null
        ? DateTime.parse(m['createdAt'])
        : DateTime.now(),
  );
}
