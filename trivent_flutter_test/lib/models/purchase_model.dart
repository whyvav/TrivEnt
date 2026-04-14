// Mirror of SaleModel but for purchases (raw materials from suppliers)
class PurchaseItem {
  final String itemId;
  final String itemName;
  final double qty;
  final String unit;
  final double priceExclTax;
  final double taxPercent;
  final double discountPercent;

  PurchaseItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.priceExclTax,
    this.taxPercent = 0,
    this.discountPercent = 0,
  });

  double get discountAmount => priceExclTax * discountPercent / 100;
  double get priceAfterDiscount => priceExclTax - discountAmount;
  double get taxAmount => priceAfterDiscount * taxPercent / 100;
  double get priceInclTax => priceAfterDiscount + taxAmount;
  double get lineTotal => qty * priceInclTax;

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'qty': qty,
    'unit': unit,
    'priceExclTax': priceExclTax,
    'taxPercent': taxPercent,
    'discountPercent': discountPercent,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
    itemId: m['itemId'] ?? '',
    itemName: m['itemName'] ?? '',
    qty: (m['qty'] ?? 0).toDouble(),
    unit: m['unit'] ?? '',
    priceExclTax: (m['priceExclTax'] ?? 0).toDouble(),
    taxPercent: (m['taxPercent'] ?? 0).toDouble(),
    discountPercent: (m['discountPercent'] ?? 0).toDouble(),
  );
}

class PurchaseModel {
  final String id;
  final String billNo;
  final String partyId;
  final String partyName;
  final String? partyPhone;
  final List<PurchaseItem> items;
  final String paymentType;
  final double amountPaid;
  final DateTime date;
  final DateTime? dueDate;
  final String? notes;

  PurchaseModel({
    required this.id,
    required this.billNo,
    required this.partyId,
    required this.partyName,
    this.partyPhone,
    required this.items,
    required this.paymentType,
    double? amountPaid,
    DateTime? date,
    this.dueDate,
    this.notes,
  })  : date = date ?? DateTime.now(),
        amountPaid = amountPaid ?? 0;

  double get totalAmount => items.fold(0, (s, i) => s + i.lineTotal);
  double get balanceDue => totalAmount - amountPaid;
  bool get isPaid => balanceDue <= 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'billNo': billNo,
    'partyId': partyId,
    'partyName': partyName,
    'partyPhone': partyPhone,
    'items': items.map((i) => i.toMap()).toList(),
    'paymentType': paymentType,
    'amountPaid': amountPaid,
    'totalAmount': totalAmount,
    'date': date.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'notes': notes,
  };

  factory PurchaseModel.fromMap(Map<String, dynamic> m) => PurchaseModel(
    id: m['id'] ?? '',
    billNo: m['billNo'] ?? '',
    partyId: m['partyId'] ?? '',
    partyName: m['partyName'] ?? '',
    partyPhone: m['partyPhone'],
    items: (m['items'] as List? ?? []).map((i) => PurchaseItem.fromMap(i)).toList(),
    paymentType: m['paymentType'] ?? 'Cash',
    amountPaid: (m['amountPaid'] ?? 0).toDouble(),
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate']) : null,
    notes: m['notes'],
  );
}