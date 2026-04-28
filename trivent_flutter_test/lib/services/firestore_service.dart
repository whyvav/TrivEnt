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
import '../models/worker_model.dart';
import '../models/labor_earning_model.dart';
import '../models/wage_payment_model.dart';
import 'company_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userId = 'demo_user';

  // ── Active-company document ──────────────────────────────────
  DocumentReference get _companyDoc => _db
      .collection('users')
      .doc(_userId)
      .collection('companies')
      .doc(CompanyService.instance.activeCompanyId ?? '_none');

  // ── Collection helpers ───────────────────────────────────────
  CollectionReference get _items       => _companyDoc.collection('items');
  CollectionReference get _boms        => _companyDoc.collection('boms');
  CollectionReference get _sales       => _companyDoc.collection('sales');
  CollectionReference get _purchases   => _companyDoc.collection('purchases');
  CollectionReference get _expenses    => _companyDoc.collection('expenses');
  CollectionReference get _parties     => _companyDoc.collection('parties');
  CollectionReference get _productions => _companyDoc.collection('productions');
  CollectionReference get _counters    => _companyDoc.collection('counters');
  CollectionReference get _units       => _companyDoc.collection('units');
  CollectionReference get _stockTx     => _companyDoc.collection('stock_transactions');
  CollectionReference get _paymentIns   => _companyDoc.collection('payment_ins');
  CollectionReference get _paymentOuts  => _companyDoc.collection('payment_outs');
  CollectionReference get _workers      => _companyDoc.collection('workers');
  CollectionReference get _laborEarnings => _companyDoc.collection('labor_earnings');
  CollectionReference get _wagePayments => _companyDoc.collection('wage_payments');

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
        'paymentout' => 'T',
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
          (s) => s.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList());

  Future<Map<String, dynamic>?> getManufactureRecord(String id) async {
    final doc = await _productions.doc(id).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static String _bomCostToExpenseCategory(String type) {
    switch (type.toLowerCase()) {
      case 'labor': return 'Labor';
      case 'electricity': return 'Utilities';
      case 'fuel': return 'Utilities';
      case 'transport': return 'Transport';
      case 'maintenance': return 'Maintenance';
      default: return 'Misc';
    }
  }

  Future<void> manufacture({
    required String productId, required String productName,
    required double qty, required BomModel bom,
    double salePrice = 0,
    DateTime? date,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();
    final txDate = date != null
        ? DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second)
        : now;

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

    final logId = now.millisecondsSinceEpoch.toString();
    batch.set(_productions.doc(logId), {
      'productId': productId, 'productName': productName,
      'qty': qty,
      'costPerUnit': bom.totalCostPerUnit,
      'totalCost': bom.totalCostPerUnit * qty,
      'salePrice': salePrice,
      'totalValue': salePrice * qty,
      'date': txDate.toIso8601String(),
      'bomSnapshot': {
        'materials': bom.materials.map((m) => m.toMap()).toList(),
        'otherCosts': bom.otherCosts.map((c) => c.toMap()).toList(),
      },
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
      pricePerUnit: salePrice, date: txDate,
      referenceId: logId, notes: 'Manufactured $qty units',
    ).toMap());

    // Auto-generate expense records from BOM other costs
    final qtyLabel = qty.truncateToDouble() == qty
        ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
    for (var i = 0; i < bom.otherCosts.length; i++) {
      final cost = bom.otherCosts[i];
      final expId = '${logId}_exp_cost_$i';
      batch.set(_expenses.doc(expId), ExpenseModel(
        id: expId,
        category: _bomCostToExpenseCategory(cost.type),
        description: 'Manufacturing: $productName × $qtyLabel — ${cost.type}',
        amount: cost.costPerUnit * qty,
        paymentType: '',
        date: txDate,
        source: 'manufacturing',
        referenceId: logId,
      ).toMap());
    }

    // COGS entry for raw materials consumed
    final totalMatCost = bom.totalMaterialCost * qty;
    if (totalMatCost > 0) {
      final cogsId = '${logId}_exp_cogs';
      batch.set(_expenses.doc(cogsId), ExpenseModel(
        id: cogsId,
        category: 'Raw Materials (COGS)',
        description: 'Manufacturing: $productName × $qtyLabel — Materials Used',
        amount: totalMatCost,
        paymentType: '',
        date: txDate,
        source: 'manufacturing',
        referenceId: logId,
      ).toMap());
    }

    // Auto-create earnings for contractors linked to this product
    final contractors = await getContractorsForProduct(productId);
    for (final worker in contractors) {
      if (worker.ratePerUnit == null) continue;
      final earnAmount = worker.ratePerUnit! * qty;
      final earnId = '${logId}_earn_${worker.id}';
      batch.set(_laborEarnings.doc(earnId), LaborEarningModel(
        id: earnId,
        workerId: worker.id,
        workerName: worker.name,
        date: txDate,
        amount: earnAmount,
        qty: qty,
        unit: 'units',
        source: 'manufacturing',
        referenceId: logId,
        notes: 'Manufactured $qtyLabel × $productName',
      ).toMap());
    }

    await batch.commit();
  }

  Future<void> updateManufactureDate(String recordId, DateTime newDate) {
    final now = DateTime.now();
    final combined = DateTime(newDate.year, newDate.month, newDate.day, now.hour, now.minute);
    return _productions.doc(recordId).update({'date': combined.toIso8601String()});
  }

  Future<void> updateManufactureQty({
    required String recordId,
    required double oldQty,
    required double newQty,
    required double salePrice,
    required double costPerUnit,
  }) async {
    if (newQty <= 0) throw Exception('Quantity must be greater than 0');
    if (newQty == oldQty) return;

    final delta = newQty - oldQty;

    // Derive per-material usage from existing stock transactions
    final txSnap = await _stockTx.where('referenceId', isEqualTo: recordId).get();

    // Check raw material availability when increasing
    if (delta > 0) {
      for (final txDoc in txSnap.docs) {
        final tx = txDoc.data() as Map<String, dynamic>;
        if ((tx['type'] as String?) != 'Consumed') continue;
        final itemId = tx['itemId'] as String?;
        if (itemId == null) continue;
        final itemName = tx['itemName'] as String? ?? 'Unknown';
        final txQty = (tx['quantity'] as num).toDouble(); // negative for consumed
        final perUnit = (-txQty) / oldQty;
        final additionalNeeded = perUnit * delta;
        final itemSnap = await _items.doc(itemId).get();
        if (!itemSnap.exists) throw Exception('Material not found: $itemName');
        final item = ItemModel.fromMap(itemSnap.data() as Map<String, dynamic>);
        if (item.stockQty < additionalNeeded) {
          throw Exception(
            'Insufficient stock for $itemName.\n'
            'Need additional: ${additionalNeeded.toStringAsFixed(2)} ${item.primaryUnit}, '
            'Available: ${item.stockQty} ${item.primaryUnit}');
        }
      }
    }

    final batch = _db.batch();

    for (final txDoc in txSnap.docs) {
      final tx = txDoc.data() as Map<String, dynamic>;
      final itemId = tx['itemId'] as String?;
      if (itemId == null) continue;
      final oldTxQty = (tx['quantity'] as num).toDouble();
      final newTxQty = oldTxQty / oldQty * newQty;
      final stockDelta = newTxQty - oldTxQty;

      final itemRef = _items.doc(itemId);
      final itemSnap = await itemRef.get();
      if (itemSnap.exists) {
        final item = ItemModel.fromMap(itemSnap.data() as Map<String, dynamic>);
        batch.update(itemRef, {'stockQty': item.stockQty + stockDelta});
      }
      batch.update(txDoc.reference, {'quantity': newTxQty});
    }

    // Scale manufacturing expenses
    final expSnap = await _expenses.where('referenceId', isEqualTo: recordId).get();
    for (final expDoc in expSnap.docs) {
      final data = expDoc.data() as Map<String, dynamic>;
      if (data['source'] == 'manufacturing') {
        final oldAmount = (data['amount'] as num).toDouble();
        batch.update(expDoc.reference, {'amount': oldAmount * newQty / oldQty});
      }
    }

    // Scale contractor earnings
    final earnSnap = await _laborEarnings.where('referenceId', isEqualTo: recordId).get();
    for (final earnDoc in earnSnap.docs) {
      final data = earnDoc.data() as Map<String, dynamic>;
      final oldAmount = (data['amount'] as num).toDouble();
      batch.update(earnDoc.reference, {
        'amount': oldAmount * newQty / oldQty,
        'qty': newQty,
      });
    }

    batch.update(_productions.doc(recordId), {
      'qty': newQty,
      'totalCost': costPerUnit * newQty,
      'totalValue': salePrice * newQty,
    });

    await batch.commit();
  }

  Future<void> deleteManufactureRecord(String recordId) async {
    final batch = _db.batch();

    // Reverse stock movements
    final txSnap = await _stockTx.where('referenceId', isEqualTo: recordId).get();
    for (final txDoc in txSnap.docs) {
      final tx = txDoc.data() as Map<String, dynamic>;
      final itemId = tx['itemId'] as String?;
      final qty = (tx['quantity'] as num?)?.toDouble() ?? 0;
      if (itemId != null) {
        final itemRef = _items.doc(itemId);
        final itemSnap = await itemRef.get();
        if (itemSnap.exists) {
          final current = ItemModel.fromMap(itemSnap.data() as Map<String, dynamic>);
          batch.update(itemRef, {'stockQty': current.stockQty - qty});
        }
      }
      batch.delete(txDoc.reference);
    }

    // Delete auto-generated expenses linked to this production record
    final expSnap = await _expenses
        .where('referenceId', isEqualTo: recordId)
        .get();
    for (final expDoc in expSnap.docs) {
      final data = expDoc.data() as Map<String, dynamic>;
      if (data['source'] == 'manufacturing') batch.delete(expDoc.reference);
    }

    // Delete contractor earnings linked to this production record
    final earnSnap = await _laborEarnings
        .where('referenceId', isEqualTo: recordId)
        .get();
    for (final earnDoc in earnSnap.docs) {
      batch.delete(earnDoc.reference);
    }

    batch.delete(_productions.doc(recordId));
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
      // Exclude COGS (non-cash, already captured as purchase cost)
      if (e.isCogs) continue;
      if (e.date.isAfter(monthStart)) monthlyExpenses += e.amount;
    }

    return {
      'totalSales': totalSales, 'totalReceived': totalReceived,
      'totalBalance': totalSales - totalReceived,
      'monthlySales': monthlySales, 'monthlyExpenses': monthlyExpenses,
      'monthlyProfit': monthlySales - monthlyExpenses,
    };
  }

  /// All transactions combined (sales + purchases + expenses + pay-ins + pay-outs), newest first
  Future<List<Map<String, dynamic>>> getAllTransactions({int limit = 50}) async {
    final results = await Future.wait([
      _sales.orderBy('date', descending: true).limit(limit).get(),
      _purchases.orderBy('date', descending: true).limit(limit).get(),
      _expenses.orderBy('date', descending: true).limit(limit).get(),
      _paymentIns.orderBy('date', descending: true).limit(limit).get(),
      _paymentOuts.orderBy('date', descending: true).limit(limit).get(),
    ]);

    final List<Map<String, dynamic>> all = [];
    for (final d in results[0].docs) {
      final s = SaleModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'Sale', 'id': s.id, 'ref': s.invoiceNo, 'party': s.partyName,
        'amount': s.totalAmount, 'paid': s.amountPaid, 'date': s.date, 'isPaid': s.isPaid,
        'model': s});
    }
    for (final d in results[1].docs) {
      final p = PurchaseModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'Purchase', 'id': p.id, 'ref': p.billNo, 'party': p.partyName,
        'amount': p.totalAmount, 'paid': p.amountPaid, 'date': p.date, 'isPaid': p.isPaid,
        'model': p});
    }
    for (final d in results[2].docs) {
      final e = ExpenseModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'Expense', 'id': e.id, 'ref': e.category, 'party': e.partyName ?? '-',
        'amount': e.amount, 'paid': e.amount, 'date': e.date, 'isPaid': true});
    }
    for (final d in results[3].docs) {
      final pi = PaymentInModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'PaymentIn', 'id': pi.id, 'ref': pi.receiptNo, 'party': pi.partyName,
        'amount': pi.amount, 'paid': pi.amount, 'date': pi.date, 'isPaid': true,
        'model': pi});
    }
    for (final d in results[4].docs) {
      final po = PaymentOutModel.fromMap(d.data() as Map<String, dynamic>);
      all.add({'type': 'PaymentOut', 'id': po.id, 'ref': po.paymentNo, 'party': po.partyName,
        'amount': po.amount, 'paid': po.amount, 'date': po.date, 'isPaid': true,
        'model': po});
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
      // Exclude COGS (non-cash, already captured as purchase cost)
      if (e.isCogs) continue;
      final day = e.date.day - 1;
      if (day >= 0 && day < daysInMonth) expByDay[day] += e.amount;
    }
    return {'sales': salesByDay, 'expenses': expByDay};
  }

  // ── WORKERS ──────────────────────────────────────────────────

  Stream<List<WorkerModel>> streamWorkers() =>
      _workers.orderBy('name').snapshots().map((s) => s.docs
          .map((d) => WorkerModel.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> saveWorker(WorkerModel worker) =>
      _workers.doc(worker.id).set(worker.toMap());

  Future<void> deleteWorker(String id) => _workers.doc(id).delete();

  Future<List<WorkerModel>> getContractorsForProduct(String productId) async {
    final s = await _workers
        .where('linkedProductId', isEqualTo: productId)
        .get();
    return s.docs
        .map((d) => WorkerModel.fromMap(d.data() as Map<String, dynamic>))
        .where((w) => w.isContractor)
        .toList();
  }

  // ── LABOR EARNINGS ───────────────────────────────────────────

  Stream<List<LaborEarningModel>> streamLaborEarnings(String workerId) =>
      _laborEarnings.where('workerId', isEqualTo: workerId).snapshots().map((s) {
        final list = s.docs
            .map((d) => LaborEarningModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Future<void> addLaborEarning(LaborEarningModel earning) =>
      _laborEarnings.doc(earning.id).set(earning.toMap());

  Future<void> deleteLaborEarning(String id) => _laborEarnings.doc(id).delete();

  // ── WAGE PAYMENTS ────────────────────────────────────────────

  Stream<List<WagePaymentModel>> streamWagePayments(String workerId) =>
      _wagePayments.where('workerId', isEqualTo: workerId).snapshots().map((s) {
        final list = s.docs
            .map((d) => WagePaymentModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Future<void> deleteWagePayment(String id) => _wagePayments.doc(id).delete();

  Future<void> payWages({
    required String workerId,
    required String workerName,
    required double amount,
    required String paymentType,
    String? paymentRef,
    String? notes,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final payDate = date ?? now;
    final id = now.millisecondsSinceEpoch.toString();

    final batch = _db.batch();

    batch.set(_wagePayments.doc(id), WagePaymentModel(
      id: id,
      workerId: workerId,
      workerName: workerName,
      amount: amount,
      paymentType: paymentType,
      paymentRef: paymentRef,
      date: payDate,
      notes: notes,
    ).toMap());

    // Also record as an expense (cash outflow for wages)
    final expId = 'wages_$id';
    batch.set(_expenses.doc(expId), ExpenseModel(
      id: expId,
      category: 'Labor',
      description: 'Wages paid to $workerName',
      amount: amount,
      paymentType: paymentType,
      date: payDate,
      source: 'wages',
      referenceId: workerId,
      notes: notes,
    ).toMap());

    await batch.commit();
  }

  Future<Map<String, double>> getWorkerBalance(String workerId) async {
    final results = await Future.wait([
      _laborEarnings.where('workerId', isEqualTo: workerId).get(),
      _wagePayments.where('workerId', isEqualTo: workerId).get(),
    ]);
    double earned = 0, paid = 0;
    for (final d in results[0].docs) {
      earned += ((d.data() as Map)['amount'] as num).toDouble();
    }
    for (final d in results[1].docs) {
      paid += ((d.data() as Map)['amount'] as num).toDouble();
    }
    return {'earned': earned, 'paid': paid, 'outstanding': earned - paid};
  }
}