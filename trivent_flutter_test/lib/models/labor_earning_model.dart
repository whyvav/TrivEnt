class LaborEarningModel {
  final String id;
  final String workerId;
  final String workerName;
  final DateTime date;
  final double amount;
  final double qty;           // days worked (daily) or units produced (contractor)
  final String unit;          // 'day' | product unit e.g. 'pcs'
  final String source;        // 'attendance' | 'manufacturing'
  final String? referenceId;  // production record ID for manufacturing-sourced earnings
  final String? notes;

  LaborEarningModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.date,
    required this.amount,
    required this.qty,
    required this.unit,
    required this.source,
    this.referenceId,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'workerId': workerId,
    'workerName': workerName,
    'date': date.toIso8601String(),
    'amount': amount,
    'qty': qty,
    'unit': unit,
    'source': source,
    if (referenceId != null) 'referenceId': referenceId,
    if (notes != null) 'notes': notes,
  };

  factory LaborEarningModel.fromMap(Map<String, dynamic> m) => LaborEarningModel(
    id: m['id'] ?? '',
    workerId: m['workerId'] ?? '',
    workerName: m['workerName'] ?? '',
    date: DateTime.parse(m['date']),
    amount: (m['amount'] as num).toDouble(),
    qty: (m['qty'] as num).toDouble(),
    unit: m['unit'] ?? '',
    source: m['source'] ?? 'attendance',
    referenceId: m['referenceId'],
    notes: m['notes'],
  );
}
