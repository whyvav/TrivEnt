class WagePaymentModel {
  final String id;
  final String workerId;
  final String workerName;
  final double amount;
  final String paymentType;
  final String? paymentRef;
  final DateTime date;
  final String? notes;

  WagePaymentModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.amount,
    required this.paymentType,
    this.paymentRef,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'workerId': workerId,
    'workerName': workerName,
    'amount': amount,
    'paymentType': paymentType,
    if (paymentRef != null) 'paymentRef': paymentRef,
    'date': date.toIso8601String(),
    if (notes != null) 'notes': notes,
  };

  factory WagePaymentModel.fromMap(Map<String, dynamic> m) => WagePaymentModel(
    id: m['id'] ?? '',
    workerId: m['workerId'] ?? '',
    workerName: m['workerName'] ?? '',
    amount: (m['amount'] as num).toDouble(),
    paymentType: m['paymentType'] ?? 'Cash',
    paymentRef: m['paymentRef'],
    date: DateTime.parse(m['date']),
    notes: m['notes'],
  );
}
