class PaymentOutModel {
  final String id;
  final String paymentNo;
  final String partyId;
  final String partyName;
  final String? partyFirm;
  final String? partyPhone;
  final double amount;
  final String paymentType;
  final String? paymentRef;
  final String? notes;
  final DateTime date;

  const PaymentOutModel({
    required this.id,
    required this.paymentNo,
    required this.partyId,
    required this.partyName,
    this.partyFirm,
    this.partyPhone,
    required this.amount,
    required this.paymentType,
    this.paymentRef,
    this.notes,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'paymentNo': paymentNo,
    'partyId': partyId,
    'partyName': partyName,
    if (partyFirm != null) 'partyFirm': partyFirm,
    if (partyPhone != null) 'partyPhone': partyPhone,
    'amount': amount,
    'paymentType': paymentType,
    if (paymentRef != null) 'paymentRef': paymentRef,
    if (notes != null) 'notes': notes,
    'date': date.toIso8601String(),
  };

  factory PaymentOutModel.fromMap(Map<String, dynamic> m) => PaymentOutModel(
    id: m['id'] as String,
    paymentNo: m['paymentNo'] as String,
    partyId: m['partyId'] as String,
    partyName: m['partyName'] as String,
    partyFirm: m['partyFirm'] as String?,
    partyPhone: m['partyPhone'] as String?,
    amount: (m['amount'] as num).toDouble(),
    paymentType: m['paymentType'] as String,
    paymentRef: m['paymentRef'] as String?,
    notes: m['notes'] as String?,
    date: DateTime.parse(m['date'] as String),
  );
}
