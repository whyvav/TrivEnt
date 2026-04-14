import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';
import '../models/bom_model.dart';
import '../models/sale_model.dart';
import '../models/party_model.dart';
import '../models/purchase_model.dart';
import '../models/expense_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userId = 'demo_user';

  // ── Collections ──────────────────────────────────────────────
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

  // ── Invoice / Bill Numbering ─────────────────────────────────

  Future<String> _nextNumber(String type, String prefix) async {
    final ref = _counters.doc(type);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists ? (snap.data() as Map)['value'] as int : 0;
      final next = current + 1;
      tx.set(ref, {'value': next});
      return '$prefix${next.toString().padLeft(4, '0')}';
    });
  }

  Future<String> nextInvoiceNo() => _nextNumber('sale_invoice', 'INV-');
  Future<String> nextBillNo() => _nextNumber('purchase_bill', 'PUR-');

  // ── PARTIES ──────────────────────────────────────────────────

  Stream<List<PartyModel>> streamParties() {
    return _parties
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs
            .map((d) => PartyModel.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> saveParty(PartyModel party) async {
    await _parties.doc(party.id).set(party.toMap());
  }

  Future<void> deleteParty(String id) => _parties.doc(id).delete();

  // Auto-create or update party from a sale
  Future<String> upsertPartyFromSale({
    required String name,
    String? firm,
    String? phone,
  }) async {
    // Check if party with same name already exists
    final snap = await _parties.where('name', isEqualTo: name).limit(1).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;

    // Create new
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await saveParty(PartyModel(id: id, name: name, firm: firm, phone: phone));
    return id;
  }

  // ── ITEMS ────────────────────────────────────────────────────

  Stream<List<ItemModel>> streamItems({String? category}) {
    Query q = _items;
    if (category != null) q = q.where('category', isEqualTo: category);
    return q.snapshots().map((s) =>
        s.docs.map((d) => ItemModel.fromMap(d.data() as Map<String, dynamic>)).toList());
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

  Future<void> deleteItem(String id) => _items.doc(id).delete();

  // ── BoM ──────────────────────────────────────────────────────

  Stream<List<BomModel>> streamBoms() => _boms.snapshots().map((s) =>
      s.docs.map((d) => BomModel.fromMap(d.data() as Map<String, dynamic>)).toList());

  Future<void> saveBom(BomModel bom) => _boms.doc(bom.id).set(bom.toMap());

  Future<BomModel?> getBomForProduct(String productId) async {
    final s = await _boms.where('productId', isEqualTo: productId).limit(1).get();
    if (s.docs.isEmpty) return null;
    return BomModel.fromMap(s.docs.first.data() as Map<String, dynamic>);
  }

  // ── MANUFACTURE ──────────────────────────────────────────────

  Future<void> manufacture({
    required String productId,
    required String productName,
    required double qty,
    required BomModel bom,
  }) async {
    final batch = _db.batch();

    for (final m in bom.materials) {
      final ref = _items.doc(m.materialId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Material not found: ${m.materialName}');
      final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
      final needed = m.qtyPerUnit * qty;
      if (current.stockQty < needed) {
        throw Exception(
          'Insufficient stock for ${m.materialName}.\n'
          'Need: $needed ${m.unit}, Available: ${current.stockQty} ${m.unit}',
        );
      }
      batch.update(ref, {'stockQty': current.stockQty - needed});
    }

    final prodRef = _items.doc(productId);
    final prodSnap = await prodRef.get();
    if (prodSnap.exists) {
      final current = ItemModel.fromMap(prodSnap.data() as Map<String, dynamic>);
      batch.update(prodRef, {'stockQty': current.stockQty + qty});
    }

    final logRef = _productions.doc(DateTime.now().millisecondsSinceEpoch.toString());
    batch.set(logRef, {
      'productId': productId,
      'productName': productName,
      'qty': qty,
      'totalCost': bom.totalCostPerUnit * qty,
      'date': DateTime.now().toIso8601String(),
    });

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
    batch.set(_sales.doc(sale.id), sale.toMap());
    for (final item in sale.items) {
      final ref = _items.doc(item.itemId);
      final snap = await ref.get();
      if (snap.exists) {
        final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
        batch.update(ref, {'stockQty': current.stockQty - item.qty});
      }
    }
    await batch.commit();
  }

  Future<void> updateSale(SaleModel sale) => _sales.doc(sale.id).update(sale.toMap());

  Future<void> deleteSale(String id) => _sales.doc(id).delete();

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
    // Increase raw material stock
    for (final item in purchase.items) {
      final ref = _items.doc(item.itemId);
      final snap = await ref.get();
      if (snap.exists) {
        final current = ItemModel.fromMap(snap.data() as Map<String, dynamic>);
        batch.update(ref, {'stockQty': current.stockQty + item.qty});
      }
    }
    await batch.commit();
  }

  Future<void> deletePurchase(String id) => _purchases.doc(id).delete();

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

  // ── DASHBOARD STATS ──────────────────────────────────────────

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
      'totalSales': totalSales,
      'totalReceived': totalReceived,
      'totalBalance': totalSales - totalReceived,
      'monthlySales': monthlySales,
      'monthlyExpenses': monthlyExpenses,
      'monthlyProfit': monthlySales - monthlyExpenses,
    };
  }

  /// Returns daily sales and expenses for the current month
  Future<Map<String, List<double>>> getMonthlyChartData() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDay.day;

    final salesByDay = List<double>.filled(daysInMonth, 0);
    final expensesByDay = List<double>.filled(daysInMonth, 0);

    final salesSnap = await _sales
        .where('date', isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1).toIso8601String())
        .get();
    for (final d in salesSnap.docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      final day = s.date.day - 1;
      if (day >= 0 && day < daysInMonth) salesByDay[day] += s.totalAmount;
    }

    final expSnap = await _expenses
        .where('date', isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1).toIso8601String())
        .get();
    for (final d in expSnap.docs) {
      final e = ExpenseModel.fromMap(d.data() as Map<String, dynamic>);
      final day = e.date.day - 1;
      if (day >= 0 && day < daysInMonth) expensesByDay[day] += e.amount;
    }

    return {'sales': salesByDay, 'expenses': expensesByDay};
  }
}