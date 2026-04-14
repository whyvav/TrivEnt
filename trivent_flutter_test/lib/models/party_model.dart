class PartyModel {
  final String id;
  final String name;
  final String? firm;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? billingAddress;
  final String? shippingAddress;
  final String gstType;   // 'registered', 'unregistered', 'consumer'
  final DateTime createdAt;

  PartyModel({
    required this.id,
    required this.name,
    this.firm,
    this.phone,
    this.email,
    this.gstin,
    this.billingAddress,
    this.shippingAddress,
    this.gstType = 'consumer',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'firm': firm,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'billingAddress': billingAddress,
    'shippingAddress': shippingAddress,
    'gstType': gstType,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PartyModel.fromMap(Map<String, dynamic> m) => PartyModel(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    firm: m['firm'],
    phone: m['phone'],
    email: m['email'],
    gstin: m['gstin'],
    billingAddress: m['billingAddress'],
    shippingAddress: m['shippingAddress'],
    gstType: m['gstType'] ?? 'consumer',
    createdAt: m['createdAt'] != null
        ? DateTime.parse(m['createdAt'])
        : DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PartyModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  String get displayName => firm != null && firm!.isNotEmpty ? '$name ($firm)' : name;
}