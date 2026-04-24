import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String itemId;
  final String itemName;
  final double qty;
  final String unit;
  final double priceExclTax;
  final double taxPercent;
  final double discountPercent;

  SaleItem({
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
    'itemId': itemId, 'itemName': itemName, 'qty': qty, 'unit': unit,
    'priceExclTax': priceExclTax, 'taxPercent': taxPercent,
    'discountPercent': discountPercent,
  };

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
    itemId: m['itemId'] ?? '', itemName: m['itemName'] ?? '',
    qty: (m['qty'] ?? 0).toDouble(), unit: m['unit'] ?? '',
    priceExclTax: (m['priceExclTax'] ?? m['pricePerUnit'] ?? 0).toDouble(),
    taxPercent: (m['taxPercent'] ?? 0).toDouble(),
    discountPercent: (m['discountPercent'] ?? 0).toDouble(),
  );
}

class SaleModel {
  final String id;
  final String invoiceNo;
  final String partyId;
  final String partyName;
  final String? partyFirm;
  final String? partyPhone;
  final List<SaleItem> items;
  final String paymentType;
  final String? paymentRef;     // cheque no., UPI ref, etc.
  final double amountPaid;
  final DateTime date;
  final DateTime? dueDate;
  final String? notes;

  SaleModel({
    required this.id,
    required this.invoiceNo,
    required this.partyId,
    required this.partyName,
    this.partyFirm,
    this.partyPhone,
    required this.items,
    required this.paymentType,
    this.paymentRef,
    double? amountPaid,
    DateTime? date,
    this.dueDate,
    this.notes,
  })  : date = date ?? DateTime.now(),
        amountPaid = amountPaid ?? 0;

  double get subtotal => items.fold(0, (s, i) => s + i.qty * i.priceExclTax);
  double get totalDiscount => items.fold(0, (s, i) => s + i.qty * i.discountAmount);
  double get totalTax => items.fold(0, (s, i) => s + i.qty * i.taxAmount);
  double get totalAmount => items.fold(0, (s, i) => s + i.lineTotal);
  double get balanceDue => totalAmount - amountPaid;
  bool get isPaid => balanceDue <= 0.01;

  Map<String, dynamic> toMap() => {
    'id': id, 'invoiceNo': invoiceNo, 'partyId': partyId,
    'partyName': partyName, 'partyFirm': partyFirm, 'partyPhone': partyPhone,
    'items': items.map((i) => i.toMap()).toList(),
    'paymentType': paymentType, 'paymentRef': paymentRef,
    'amountPaid': amountPaid, 'totalAmount': totalAmount,
    'date': Timestamp.fromDate(date), 'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    'notes': notes,
  };

  factory SaleModel.fromMap(Map<String, dynamic> m) => SaleModel(
    id: m['id'] ?? '', invoiceNo: m['invoiceNo'] ?? '',
    partyId: m['partyId'] ?? '', partyName: m['partyName'] ?? '',
    partyFirm: m['partyFirm'], partyPhone: m['partyPhone'],
    items: (m['items'] as List? ?? []).map((i) => SaleItem.fromMap(i)).toList(),
    paymentType: m['paymentType'] ?? 'Cash', paymentRef: m['paymentRef'],
    amountPaid: (m['amountPaid'] ??
        (m['isPaid'] == true ? (m['totalAmount'] ?? 0) : 0) ?? 0).toDouble(),
    date: _parseDate(m['date']) ?? DateTime.now(),
    dueDate: _parseDate(m['dueDate']),
    notes: m['notes'],
  );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;

  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);

  return null;
}