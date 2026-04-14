class ExpenseModel {
  final String id;
  final String category;    // 'Raw Materials', 'Labor', 'Utilities', 'Misc'
  final String description;
  final double amount;
  final String paymentType;
  final DateTime date;
  final String? notes;
  final String? partyName;

  ExpenseModel({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentType,
    DateTime? date,
    this.notes,
    this.partyName,
  }) : date = date ?? DateTime.now();

  static const List<String> categories = [
    'Raw Materials', 'Labor', 'Utilities', 'Transport', 'Maintenance', 'Misc'
  ];

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'paymentType': paymentType,
    'date': date.toIso8601String(),
    'notes': notes,
    'partyName': partyName,
  };

  factory ExpenseModel.fromMap(Map<String, dynamic> m) => ExpenseModel(
    id: m['id'] ?? '',
    category: m['category'] ?? 'Misc',
    description: m['description'] ?? '',
    amount: (m['amount'] ?? 0).toDouble(),
    paymentType: m['paymentType'] ?? 'Cash',
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    notes: m['notes'],
    partyName: m['partyName'],
  );
}