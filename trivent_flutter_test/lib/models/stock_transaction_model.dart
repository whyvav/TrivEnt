class StockTransactionModel {
  final String id;
  final String itemId;
  final String itemName;
  final String type;        // 'Opening Stock','Sale','Purchase','Manufactured',
                            // 'Consumed','Adjusted','Deleted'
  final double quantity;    // positive = added, negative = removed
  final double pricePerUnit;
  final DateTime date;
  final String? referenceId;   // saleId / purchaseId / productionId
  final String? referenceNo;   // invoiceNo / billNo (human-readable)
  final String? notes;

  StockTransactionModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    DateTime? date,
    this.referenceId,
    this.referenceNo,
    this.notes,
  }) : date = date ?? DateTime.now();

  double get value => quantity * pricePerUnit;

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'itemName': itemName,
    'type': type,
    'quantity': quantity,
    'pricePerUnit': pricePerUnit,
    'date': date.toIso8601String(),
    'referenceId': referenceId,
    'referenceNo': referenceNo,
    'notes': notes,
  };

  factory StockTransactionModel.fromMap(Map<String, dynamic> m) =>
      StockTransactionModel(
        id: m['id'] ?? '',
        itemId: m['itemId'] ?? '',
        itemName: m['itemName'] ?? '',
        type: m['type'] ?? '',
        quantity: (m['quantity'] ?? 0).toDouble(),
        pricePerUnit: (m['pricePerUnit'] ?? 0).toDouble(),
        date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
        referenceId: m['referenceId'],
        referenceNo: m['referenceNo'],
        notes: m['notes'],
      );
}