import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';
import '../models/bom_model.dart';
import '../models/sale_model.dart';
import '../models/party_model.dart';
import '../models/purchase_model.dart';
import '../models/expense_model.dart';
import '../models/unit_model.dart';
import '../models/stock_transaction_model.dart';
import '../models/payment_in_model.dart';
import '../models/payment_out_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userId = 'demo_user';

  // ── Collection helpers ───────────────────────────────────────
  CollectionReference get _items =>
      _db.collection('users').doc(_userId).collection('items');
  CollectionReference get _boms =>
      _db.collection('users').doc(_userId).collection('boms');
  CollectionReference get _sales =>
      _db.collection('users').doc(_userId).collection('sales');
  CollectionReference get _purchases =>
      _db.collection('users').doc(_userId).collection('purchases');
  CollectionReference get _expenses =>
      _db.collection('users').doc(_userId).collection('expenses');
  CollectionReference get _parties =>
      _db.collection('users').doc(_userId).collection('parties');
  CollectionReference get _productions =>
      _db.collection('users').doc(_userId).collection('productions');
  CollectionReference get _counters =>
      _db.collection('users').doc(_userId).collection('counters');
  CollectionReference get _units =>
      _db.collection('users').doc(_userId).collection('units');
  CollectionReference get _stockTx =>
      _db.collection('users').doc(_userId).collection('stock_transactions');
  CollectionReference get _paymentIns =>
      _db.collection('users').doc(_userId).collection('payment_ins');
  CollectionReference get _paymentOuts =>
      _db.collection('users').doc(_userId).collection('payment_outs');

  // ── Invoice Numbering ────────────────────────────────────────

  static String financialYear(DateTime d) {
    if (d.month >= 4) {
      return '${d.year}-${(d.year + 1).toString().substring(2)}';
    } else {
      return '${d.year - 1}-${d.year.toString().substring(2)}';
    }
  }

  static String dateCode(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<String> _nextDailyNumber(String type, DateTime date) async {
    final key = '${type}_${dateCode(date)}';
    final ref = _counters.doc(key);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists ? (snap.data() as Map)['value'] as int : 0;
      final next = current + 1;
      tx.set(ref, {'value': next});
      final prefix = switch (type) {
        'sale'       => 'S',
        'purchase'   => 'P',
        'receipt'    => 'R',
        'paymentout' => 'PMT',
        _            => type[0].toUpperCase(),
      };
      return '${financialYear(date)}/${dateCode(date)}/$prefix${next.toString().padLeft(2, '0')}';
    });
  }

  Future<String> nextSaleInvoiceNo([DateTime? date]) =>
      _nextDailyNumber('sale', date ?? DateTime.now());
  Future<String> nextPurchaseBillNo([DateTime? date]) =>
      _nextDailyNumber('purchase', date ?? DateTime.now());
  Future<String> nextPaymentInNo([DateTime? date]) =>
      _nextDailyNumber('receipt', date ?? DateTime.now());
  Future<String> nextPaymentOutNo([DateTime? date]) =>
      _nextDailyNumber('paymentout', date ?? DateTime.now());

  // ── UNITS ────────────────────────────────────────────────────

  Future<List<UnitModel>> getAllUnits() async {
    final customSnap = await _units.get();
    final custom = customSnap.docs
        .map((d) => UnitModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
    final defaults = UnitModel.defaults;
    // Merge: defaults first, then custom, no duplicates by shortName
    final allShortNames = defaults.map((u) => u.shortName).toSet();
    final uniqueCustom = custom.where((u) => !allShortNames.contains(u.shortName)).toList();
    return [...defaults, ...uniqueCustom];
  }

  Stream<List<UnitModel>> streamCustomUnits() =>
      _units.snapshots().map((s) =>
          s.docs.map((d) => UnitModel.fromMap(d.data() as Map<String, dynamic>)).toList());

  Future<UnitModel?> addCustomUnit(String fullName, String shortName) async {
    // Check uniqueness
    final existing = await getAllUnits();
    final conflict = existing.any(
      (u) => u.fullName.toLowerCase() == fullName.toLowerCase() ||
             u.shortName.toLowerCase() == shortName.toLowerCase(),
    );
    if (conflict) return null; // signal duplicate
    final unit = UnitModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName.trim(),
      shortName: shortName.trim(),
    );
    await _units.doc(unit.id).set(unit.toMap());
    return unit;
  }

  // ── PARTIES ──────────────────────────────────────────────────

  Stream<List<PartyModel>> streamParties() => _parties
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs
          .map((d) => PartyModel.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> saveParty(PartyModel party) =>
      _parties.doc(party.id).set(party.toMap());

  Future<void> deleteParty(String id) => _parties.doc(id).delete();

  Future<String> upsertPartyFromSale({
    required String name, String? firm, String? phone,
  }) async {
    final snap = await _parties.where('name', isEqualTo: name).limit(1).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await saveParty(PartyModel(id: id, name: name, firm: firm, phone: phone));
    return id;
  }

  // ── PAYMENT IN ───────────────────────────────────────────────

  Stream<List<PaymentInModel>> streamPaymentIns() => _paymentIns
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => PaymentInModel.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> addPaymentIn(PaymentInModel p) =>
      _paymentIns.doc(p.id).set(p.toMap());

  Future<void> updatePaymentIn(PaymentInModel p) =>
      _paymentIns.doc(p.id).update(p.toMap());

  Future<void> deletePaymentIn(String id) => _paymentIns.doc(id).delete();

  // ── PAYMENT OUT ──────────────────────────────────────────────────────────

  Stream<List<PaymentOutModel>> streamPaymentOuts() => _paymentOuts
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => PaymentOutModel.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> addPaymentOut(PaymentOutModel p) =>
      _paymentOuts.doc(p.id).set(p.toMap());

  Future<void> updatePaymentOut(PaymentOutModel p) =>
      _paymentOuts.doc(p.id).update(p.toMap());

  Future<void> deletePaymentOut(String id) => _paymentOuts.doc(id).delete();

  /// Returns {receivable, received, payable, paid, netBalance}
  /// received includes payment-ins; paid includes payment-outs.
  Future<Map<String, double>> getPartyBalance(String partyId) async {
    final results = await Future.wait([
      _sales.where('partyId', isEqualTo: partyId).get(),
      _purchases.where('partyId', isEqualTo: partyId).get(),
      _paymentIns.where('partyId', isEqualTo: partyId).get(),
      _paymentOuts.where('partyId', isEqualTo: partyId).get(),
    ]);

    double receivable = 0, received = 0, payable = 0, paid = 0;
    for (final d in results[0].docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      receivable += s.totalAmount;
      received += s.amountPaid;
    }
    for (final d in results[1].docs) {
      final p = PurchaseModel.fromMap(d.data() as Map<String, dynamic>);
      payable += p.totalAmount;
      paid += p.amountPaid;
    }
    for (final d in results[2].docs) {
      final pi = PaymentInModel.fromMap(d.data() as Map<String, dynamic>);
      received += pi.amount;
    }
    for (final d in results[3].docs) {
      final po = PaymentOutModel.fromMap(d.data() as Map<String, dynamic>);
      paid += po.amount;
    }
    return {
      'receivable': receivable,
      'received': received,
      'payable': payable,
      'paid': paid,
      'netBalance': (receivable - received) - (payable - paid),
    };
  }

  Future<List<Map<String, dynamic>>> getPartyTransactions(String partyId) async {
    final results = await Future.wait([
      _sales.where('partyId', isEqualTo: partyId).get(),
      _purchases.where('partyId', isEqualTo: partyId).get(),
      _paymentIns.where('partyId', isEqualTo: partyId).get(),
      _paymentOuts.where('partyId', isEqualTo: partyId).get(),
    ]);

    final List<Map<String, dynamic>> all = [];
    for (final d in results[0].docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({
        'type': 'Sale', 'id': s.id, 'refNo': s.invoiceNo,
        'date': s.date, 'amount': s.totalAmount,
        'paid': s.amountPaid, 'balance': s.balanceDue,
      });
    }
    for (final d in results[1].docs) {
      final p = PurchaseModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({
        'type': 'Purchase', 'id': p.id, 'refNo': p.billNo,
        'date': p.date, 'amount': p.totalAmount,
        'paid': p.amountPaid, 'balance': p.balanceDue,
      });
    }
    for (final d in results[2].docs) {
      final pi = PaymentInModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({
        'type': 'PaymentIn', 'id': pi.id, 'refNo': pi.receiptNo,
        'date': pi.date, 'amount': pi.amount,
        'paid': pi.amount, 'balance': 0.0,
      });
    }
    for (final d in results[3].docs) {
      final po = PaymentOutModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({
        'type': 'PaymentOut', 'id': po.id, 'refNo': po.paymentNo,
        'date': po.date, 'amount': po.amount,
        'paid': po.amount, 'balance': 0.0,
      });
    }
    all.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return all;
  }

  // ── ITEMS ────────────────────────────────────────────────────

  Stream<List<ItemModel>> streamItems({String? category}) {
    Query q = _items;
    if (category != null) q = q.where('category', isEqualTo: category);
    return q.snapshots().map((s) => s.docs
        .map((d) => ItemModel.fromMap(d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> saveItem(ItemModel item) => _items.doc(item.id).set(item.toMap());
  Future<void> updateItem(ItemModel item) => _items.doc(item.id).update(item.toMap());
  Future<void> updateItemStock(String id, double qty) =>
      _items.doc(id).update({'stockQty': qty});

  Future<ItemModel?> getItem(String id) async {
    final d = await _items.doc(id).get();
    if (!d.exists) return null;
    return ItemModel.fromMap(d.data() as Map<String, dynamic>);
  }

  Future<void> deleteItem(String id) async {
    final item = await getItem(id);
    if (item != null && item.stockQty != 0) {
      await logStockTx(StockTransactionModel(
        id: 'deleted_${id}_${DateTime.now().millisecondsSinceEpoch}',
        itemId: id, itemName: item.name,
        type: 'Deleted', quantity: -item.stockQty,
        pricePerUnit: item.stockAtPrice, date: DateTime.now(),
        notes: 'Item deleted (${item.stockQty} ${item.primaryUnit} written off)',
      ));
    }
    await _items.doc(id).delete();
  }

  // ── STOCK TRANSACTIONS ───────────────────────────────────────

  Stream<List<StockTransactionModel>> streamStockTransactions(String itemId) =>
      _stockTx
          .where('itemId', isEqualTo: itemId)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => StockTransactionModel.fromMap(d.data() as Map<String, dynamic>))
                .toList();
            list.sort((a, b) => b.date.compareTo(a.date));
            return list;
          });

  Future<void> logStockTx(StockTransactionModel tx) =>
      _stockTx.doc(tx.id).set(tx.toMap());

  Future<void> adjustStock({
    required String itemId,
    required String itemName,
    required double quantityChange,  // positive or negative
    required double pricePerUnit,
    required DateTime date,
    String? notes,
  }) async {
    final item = await getItem(itemId);
    if (item == null) throw Exception('Item not found');
    final newQty = item.stockQty + quantityChange;
    if (newQty < 0) throw Exception('Cannot reduce stock below zero');

    await updateItemStock(itemId, newQty);
    await logStockTx(StockTransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      itemId: itemId,
      itemName: itemName,
      type: 'Adjusted',
      quantity: quantityChange,
      pricePerUnit: pricePerUnit,
      date: date,
      notes: notes,
    ));
  }

  // ── BoM ──────────────────────────────────────────────────────

  Stream<List<BomModel>> streamBoms() => _boms.snapshots().map((s) =>
      s.docs.map((d) => BomModel.fromMap(d.data() as Map<String, dynamic>)).toList());

  Future<void> saveBom(BomModel bom) => _boms.doc(bom.id).set(bom.toMap());

  Future<void> deleteBom(String id) => _boms.doc(id).delete();

  Future<BomModel?> getBomForProduct(String productId) async {
    final s = await _boms.where('productId', isEqualTo: productId).limit(1).get();
    if (s.docs.isEmpty) return null;
    return BomModel.fromMap(s.docs.first.data() as Map<String, dynamic>);
  }

  // ── MANUFACTURE ──────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamProductions() =>
      _productions.orderBy('date', descending: true).snapshots().map(
          (s) => s.docs.map((d) => d.data() as Map<String, dynamic>).toList());

  Future<void> manufacture({
    required String productId, required String productName,
    required double qty, required BomModel bom,
    double salePrice = 0,
  }) async {
    final batch = _db.batch();
    final txDate = DateTime.now();

    for (final m in bom.materials) {
      final ref = _items.doc(m.materialId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Material not found: ${m.materialName}');
      final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
      final needed = m.qtyPerUnit * qty;
      if (current.stockQty < needed) {
        throw Exception(
          'Insufficient stock for ${m.materialName}.\n'
          'Need: $needed ${m.unit}, Available: ${current.stockQty} ${m.unit}');
      }
      batch.update(ref, {'stockQty': current.stockQty - needed});
    }

    final prodRef = _items.doc(productId);
    final prodSnap = await prodRef.get();
    if (prodSnap.exists) {
      final current = ItemModel.fromMap(prodSnap.data() as Map<String, dynamic>);
      batch.update(prodRef, {'stockQty': current.stockQty + qty});
    }

    final logId = txDate.millisecondsSinceEpoch.toString();
    batch.set(_productions.doc(logId), {
      'productId': productId, 'productName': productName,
      'qty': qty,
      'costPerUnit': bom.totalCostPerUnit,
      'totalCost': bom.totalCostPerUnit * qty,
      'salePrice': salePrice,
      'totalValue': salePrice * qty,
      'date': txDate.toIso8601String(),
    });

    // Log stock transactions
    for (final m in bom.materials) {
      final txRef = _stockTx.doc('${logId}_${m.materialId}');
      batch.set(txRef, StockTransactionModel(
        id: '${logId}_${m.materialId}',
        itemId: m.materialId, itemName: m.materialName,
        type: 'Consumed', quantity: -(m.qtyPerUnit * qty),
        pricePerUnit: m.pricePerUnit, date: txDate,
        referenceId: logId, notes: 'Manufactured $qty × $productName',
      ).toMap());
    }
    final mfgTxRef = _stockTx.doc('${logId}_$productId');
    batch.set(mfgTxRef, StockTransactionModel(
      id: '${logId}_$productId',
      itemId: productId, itemName: productName,
      type: 'Manufactured', quantity: qty,
      pricePerUnit: bom.totalCostPerUnit, date: txDate,
      referenceId: logId, notes: 'Manufactured $qty units',
    ).toMap());

    await batch.commit();
  }

  // ── SALES ────────────────────────────────────────────────────

  Stream<List<SaleModel>> streamSales() => _sales
    .orderBy('date', descending: true)
    .snapshots()
    .map((s) => s.docs
        .map((d) => SaleModel.fromMap(d.data() as Map<String, dynamic>))
        .toList());

Future<void> addSale(SaleModel sale) async {
  final batch = _db.batch();

  // ✅ Ensure date is stored (this is the key change)
  batch.set(_sales.doc(sale.id), sale.toMap());

  for (final item in sale.items) {
    final ref = _items.doc(item.itemId);
    final snap = await ref.get();

    if (snap.exists) {
      final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);

      batch.update(ref, {
        'stockQty': current.stockQty - item.qty,
      });

      // ✅ Stock transaction now uses invoice date (already correct but now meaningful)
      final txRef = _stockTx.doc('sale_${sale.id}_${item.itemId}');
      batch.set(txRef, StockTransactionModel(
        id: 'sale_${sale.id}_${item.itemId}',
        itemId: item.itemId,
        itemName: item.itemName,
        type: 'Sale',
        quantity: -item.qty,
        pricePerUnit: item.priceExclTax,
        date: sale.date, // ✅ this now reflects _selectedDate
        referenceId: sale.id,
        referenceNo: sale.invoiceNo,
        notes: 'Sale to ${sale.partyName}',
      ).toMap());
    }
  }

  await batch.commit();
}

  Future<void> updateSale(SaleModel sale) =>
      _sales.doc(sale.id).update(sale.toMap());

  Future<void> deleteSale(String id) async {
    final saleDoc = await _sales.doc(id).get();
    if (!saleDoc.exists) { await _sales.doc(id).delete(); return; }
    final sale = SaleModel.fromMap(saleDoc.data() as Map<String, dynamic>);

    final batch = _db.batch();
    batch.delete(_sales.doc(id));
    for (final si in sale.items) {
      final ref = _items.doc(si.itemId);
      final snap = await ref.get();
      if (snap.exists) {
        final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
        batch.update(ref, {'stockQty': current.stockQty + si.qty});
      }
      batch.delete(_stockTx.doc('sale_${id}_${si.itemId}'));
    }
    await batch.commit();
  }

  // ── PURCHASES ────────────────────────────────────────────────

  Stream<List<PurchaseModel>> streamPurchases() => _purchases
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => PurchaseModel.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> addPurchase(PurchaseModel purchase) async {
    final batch = _db.batch();
    batch.set(_purchases.doc(purchase.id), purchase.toMap());
    for (final item in purchase.items) {
      final ref = _items.doc(item.itemId);
      final snap = await ref.get();
      if (snap.exists) {
        final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
        batch.update(ref, {'stockQty': current.stockQty + item.qty});
        final txRef = _stockTx.doc('pur_${purchase.id}_${item.itemId}');
        batch.set(txRef, StockTransactionModel(
          id: 'pur_${purchase.id}_${item.itemId}',
          itemId: item.itemId, itemName: item.itemName,
          type: 'Purchase', quantity: item.qty,
          pricePerUnit: item.priceExclTax, date: purchase.date,
          referenceId: purchase.id, referenceNo: purchase.billNo,
          notes: 'Purchase from ${purchase.partyName}',
        ).toMap());
      }
    }
    await batch.commit();
  }

  Future<void> updatePurchase(PurchaseModel purchase) =>
      _purchases.doc(purchase.id).update(purchase.toMap());

  Future<void> deletePurchase(String id) async {
    final purchaseDoc = await _purchases.doc(id).get();
    if (!purchaseDoc.exists) { await _purchases.doc(id).delete(); return; }
    final purchase = PurchaseModel.fromMap(purchaseDoc.data() as Map<String, dynamic>);

    final batch = _db.batch();
    batch.delete(_purchases.doc(id));
    for (final pi in purchase.items) {
      final ref = _items.doc(pi.itemId);
      final snap = await ref.get();
      if (snap.exists) {
        final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
        batch.update(ref, {'stockQty': current.stockQty - pi.qty});
      }
      batch.delete(_stockTx.doc('pur_${id}_${pi.itemId}'));
    }
    await batch.commit();
  }

  // ── EXPENSES ─────────────────────────────────────────────────

  Stream<List<ExpenseModel>> streamExpenses() => _expenses
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ExpenseModel.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> addExpense(ExpenseModel expense) =>
      _expenses.doc(expense.id).set(expense.toMap());
  Future<void> deleteExpense(String id) => _expenses.doc(id).delete();

  // ── DASHBOARD ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final salesSnap = await _sales.get();
    final purchasesSnap = await _purchases.get();
    final expensesSnap = await _expenses.get();

    double totalSales = 0, totalReceived = 0;
    double monthlySales = 0, monthlyExpenses = 0;

    for (final d in salesSnap.docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      totalSales += s.totalAmount;
      totalReceived += s.amountPaid;
      if (s.date.isAfter(monthStart)) monthlySales += s.totalAmount;
    }
    for (final d in purchasesSnap.docs) {
      final p = PurchaseModel.fromMap(d.data() as Map<String, dynamic>);
      if (p.date.isAfter(monthStart)) monthlyExpenses += p.totalAmount;
    }
    for (final d in expensesSnap.docs) {
      final e = ExpenseModel.fromMap(d.data() as Map<String, dynamic>);
      if (e.date.isAfter(monthStart)) monthlyExpenses += e.amount;
    }

    return {
      'totalSales': totalSales, 'totalReceived': totalReceived,
      'totalBalance': totalSales - totalReceived,
      'monthlySales': monthlySales, 'monthlyExpenses': monthlyExpenses,
      'monthlyProfit': monthlySales - monthlyExpenses,
    };
  }

  /// All transactions combined (sales + purchases + expenses), newest first
  Future<List<Map<String, dynamic>>> getAllTransactions({int limit = 50}) async {
    final salesSnap = await _sales.orderBy('date', descending: true).limit(limit).get();
    final purchasesSnap = await _purchases.orderBy('date', descending: true).limit(limit).get();
    final expensesSnap = await _expenses.orderBy('date', descending: true).limit(limit).get();

    final List<Map<String, dynamic>> all = [];
    for (final d in salesSnap.docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'Sale', 'id': s.id, 'ref': s.invoiceNo, 'party': s.partyName,
        'amount': s.totalAmount, 'paid': s.amountPaid, 'date': s.date, 'isPaid': s.isPaid});
    }
    for (final d in purchasesSnap.docs) {
      final p = PurchaseModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'Purchase', 'id': p.id, 'ref': p.billNo, 'party': p.partyName,
        'amount': p.totalAmount, 'paid': p.amountPaid, 'date': p.date, 'isPaid': p.isPaid});
    }
    for (final d in expensesSnap.docs) {
      final e = ExpenseModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'Expense', 'id': e.id, 'ref': e.category, 'party': e.partyName ?? '-',
        'amount': e.amount, 'paid': e.amount, 'date': e.date, 'isPaid': true});
    }
    all.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return all.take(limit).toList();
  }

  Future<Map<String, List<double>>> getMonthlyChartData() async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final salesByDay = List<double>.filled(daysInMonth, 0);
    final expByDay = List<double>.filled(daysInMonth, 0);

    final monthStartStr = DateTime(now.year, now.month, 1).toIso8601String();
    final salesSnap = await _sales.where('date', isGreaterThanOrEqualTo: monthStartStr).get();
    for (final d in salesSnap.docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      final day = s.date.day - 1;
      if (day >= 0 && day < daysInMonth) salesByDay[day] += s.totalAmount;
    }
    final expSnap = await _expenses.where('date', isGreaterThanOrEqualTo: monthStartStr).get();
    for (final d in expSnap.docs) {
      final e = ExpenseModel.fromMap(d.data() as Map<String, dynamic>);
      final day = e.date.day - 1;
      if (day >= 0 && day < daysInMonth) expByDay[day] += e.amount;
    }
    return {'sales': salesByDay, 'expenses': expByDay};
  }
}