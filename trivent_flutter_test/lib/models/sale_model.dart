class SaleItem {
  final String itemId;
  final String itemName;
  final double qty;
  final String unit;
  final double pricePerUnit;
  final double taxPercent;
  final double discountPercent;

  SaleItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.pricePerUnit,
    this.taxPercent = 0,
    this.discountPercent = 0,
  });

  double get subtotal => qty * pricePerUnit;
  double get discountAmount => subtotal * discountPercent / 100;
  double get taxAmount => (subtotal - discountAmount) * taxPercent / 100;
  double get total => subtotal - discountAmount + taxAmount;

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'qty': qty,
    'unit': unit,
    'pricePerUnit': pricePerUnit,
    'taxPercent': taxPercent,
    'discountPercent': discountPercent,
  };

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
    itemId: m['itemId'] ?? '',
    itemName: m['itemName'] ?? '',
    qty: (m['qty'] ?? 0).toDouble(),
    unit: m['unit'] ?? '',
    pricePerUnit: (m['pricePerUnit'] ?? 0).toDouble(),
    taxPercent: (m['taxPercent'] ?? 0).toDouble(),
    discountPercent: (m['discountPercent'] ?? 0).toDouble(),
  );
}

class SaleModel {
  final String id;
  final String invoiceNo;
  final String partyName;
  final String? partyPhone;
  final List<SaleItem> items;
  final String paymentType;   // 'Cash', 'UPI', 'Credit'
  final bool isPaid;
  final DateTime date;
  final DateTime? dueDate;
  final String? notes;

  SaleModel({
    required this.id,
    required this.invoiceNo,
    required this.partyName,
    this.partyPhone,
    required this.items,
    required this.paymentType,
    this.isPaid = false,
    DateTime? date,
    this.dueDate,
    this.notes,
  }) : date = date ?? DateTime.now();

  double get totalAmount => items.fold(0, (sum, item) => sum + item.total);

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoiceNo': invoiceNo,
    'partyName': partyName,
    'partyPhone': partyPhone,
    'items': items.map((i) => i.toMap()).toList(),
    'paymentType': paymentType,
    'isPaid': isPaid,
    'totalAmount': totalAmount,
    'date': date.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'notes': notes,
  };

  factory SaleModel.fromMap(Map<String, dynamic> map) => SaleModel(
    id: map['id'] ?? '',
    invoiceNo: map['invoiceNo'] ?? '',
    partyName: map['partyName'] ?? '',
    partyPhone: map['partyPhone'],
    items: (map['items'] as List? ?? [])
        .map((i) => SaleItem.fromMap(i))
        .toList(),
    paymentType: map['paymentType'] ?? 'Cash',
    isPaid: map['isPaid'] ?? false,
    date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
    notes: map['notes'],
  );
}