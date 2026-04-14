import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';
import '../models/bom_model.dart';
import '../models/sale_model.dart';

class FirestoreService {
  // Singleton pattern — only one instance exists
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // For demo: hardcoded userId. Replace with real auth later.
  static const String _userId = 'demo_user';

  // ── Collection references ────────────────────────────────────
  CollectionReference get _items =>
      _db.collection('users').doc(_userId).collection('items');

  CollectionReference get _boms =>
      _db.collection('users').doc(_userId).collection('boms');

  CollectionReference get _sales =>
      _db.collection('users').doc(_userId).collection('sales');

  CollectionReference get _productions =>
      _db.collection('users').doc(_userId).collection('productions');

  // ── ITEMS (Inventory) ────────────────────────────────────────

  Stream<List<ItemModel>> streamItems({String? category}) {
    Query query = _items;
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => ItemModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addItem(ItemModel item) async {
    await _items.doc(item.id).set(item.toMap());
  }

  Future<void> updateItemStock(String itemId, double newQty) async {
    await _items.doc(itemId).update({'stockQty': newQty});
  }

  Future<ItemModel?> getItem(String itemId) async {
    final doc = await _items.doc(itemId).get();
    if (!doc.exists) return null;
    return ItemModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> deleteItem(String itemId) async {
    await _items.doc(itemId).delete();
  }

  // ── BoM ──────────────────────────────────────────────────────

  Stream<List<BomModel>> streamBoms() {
    return _boms.snapshots().map((snap) =>
        snap.docs.map((d) => BomModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveBom(BomModel bom) async {
    await _boms.doc(bom.id).set(bom.toMap());
  }

  Future<BomModel?> getBomForProduct(String productId) async {
    final snap = await _boms.where('productId', isEqualTo: productId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return BomModel.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  // ── MANUFACTURE ──────────────────────────────────────────────

  /// Core manufacturing logic — call this when user triggers production
  Future<String> manufacture({
    required String productId,
    required String productName,
    required double qty,
    required BomModel bom,
  }) async {
    // Use a Firestore batch so all updates succeed or fail together
    final batch = _db.batch();

    // 1. Deduct raw materials
    for (final material in bom.materials) {
      final matRef = _items.doc(material.materialId);
      final matSnap = await matRef.get();
      if (!matSnap.exists) throw Exception('Material not found: ${material.materialName}');

      final current = ItemModel.fromMap(matSnap.data() as Map<String, dynamic>);
      final required = material.qtyPerUnit * qty;

      if (current.stockQty < required) {
        throw Exception(
          'Insufficient stock for ${material.materialName}. '
          'Need: $required ${material.unit}, Have: ${current.stockQty} ${material.unit}'
        );
      }
      batch.update(matRef, {'stockQty': current.stockQty - required});
    }

    // 2. Add finished goods to inventory
    final productRef = _items.doc(productId);
    final productSnap = await productRef.get();
    if (productSnap.exists) {
      final current = ItemModel.fromMap(productSnap.data() as Map<String, dynamic>);
      batch.update(productRef, {'stockQty': current.stockQty + qty});
    }

    // 3. Log the production record
    final productionId = DateTime.now().millisecondsSinceEpoch.toString();
    final productionRef = _productions.doc(productionId);
    batch.set(productionRef, {
      'id': productionId,
      'productId': productId,
      'productName': productName,
      'qty': qty,
      'totalCost': bom.totalCostPerUnit * qty,
      'materialCost': bom.totalMaterialCost * qty,
      'otherCost': bom.totalOtherCost * qty,
      'date': DateTime.now().toIso8601String(),
    });

    await batch.commit();
    return productionId;
  }

  // ── SALES ────────────────────────────────────────────────────

  Stream<List<SaleModel>> streamSales() {
    return _sales
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SaleModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addSale(SaleModel sale) async {
    // Also deduct sold items from inventory
    final batch = _db.batch();
    batch.set(_sales.doc(sale.id), sale.toMap());

    for (final item in sale.items) {
      final itemRef = _items.doc(item.itemId);
      final itemSnap = await itemRef.get();
      if (itemSnap.exists) {
        final current = ItemModel.fromMap(itemSnap.data() as Map<String, dynamic>);
        batch.update(itemRef, {'stockQty': current.stockQty - item.qty});
      }
    }
    await batch.commit();
  }

  // ── DASHBOARD STATS ──────────────────────────────────────────

  Future<Map<String, double>> getDashboardStats() async {
    final salesSnap = await _sales.get();
    double totalSales = 0, totalReceived = 0;

    for (final doc in salesSnap.docs) {
      final sale = SaleModel.fromMap(doc.data() as Map<String, dynamic>);
      totalSales += sale.totalAmount;
      if (sale.isPaid) totalReceived += sale.totalAmount;
    }

    return {
      'totalSales': totalSales,
      'totalReceived': totalReceived,
      'totalBalance': totalSales - totalReceived,
    };
  }
}