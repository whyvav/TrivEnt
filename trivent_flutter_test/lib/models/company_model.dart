class CompanyModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String gstNumber;
  final String createdAt;

  const CompanyModel({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.gstNumber = '',
    required this.createdAt,
  });

  factory CompanyModel.fromMap(String id, Map<String, dynamic> m) => CompanyModel(
        id: id,
        name: m['name'] as String? ?? '',
        address: m['address'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        gstNumber: m['gstNumber'] as String? ?? '',
        createdAt: m['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'phone': phone,
        'gstNumber': gstNumber,
        'createdAt': createdAt,
      };

  CompanyModel copyWith({
    String? name,
    String? address,
    String? phone,
    String? gstNumber,
  }) =>
      CompanyModel(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        gstNumber: gstNumber ?? this.gstNumber,
        createdAt: createdAt,
      );
}
