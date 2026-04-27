import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';

class CompanyService extends ChangeNotifier {
  static final CompanyService instance = CompanyService._();
  CompanyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Keep this in sync with FirestoreService._userId.
  // Both will be migrated to real Firebase Auth UID in a future step.
  static const String _userId = 'demo_user';

  List<CompanyModel> _companies = [];
  CompanyModel? _activeCompany;
  bool _initialized = false;
  bool _migrationAvailable = false;

  List<CompanyModel> get companies => List.unmodifiable(_companies);
  CompanyModel? get activeCompany => _activeCompany;
  String? get activeCompanyId => _activeCompany?.id;
  bool get isInitialized => _initialized;
  bool get hasCompanies => _companies.isNotEmpty;

  /// True when data exists at the old (pre-company) path but no companies have
  /// been created yet — prompts the user to migrate during first-time setup.
  bool get migrationAvailable => _migrationAvailable;

  DocumentReference get _userDoc =>
      _db.collection('users').doc(_userId);
  CollectionReference get _companiesCol =>
      _userDoc.collection('companies');

  // ── Lifecycle ──────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    final snap = await _companiesCol.orderBy('createdAt').get();
    _companies = snap.docs
        .map((d) => CompanyModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();

    if (_companies.isEmpty) {
      // Check if old-path data exists so we can offer migration.
      final probe = await _userDoc.collection('items').limit(1).get();
      _migrationAvailable = probe.docs.isNotEmpty;
    } else {
      final userSnap = await _userDoc.get();
      final activeId =
          (userSnap.data() as Map<String, dynamic>?)?['activeCompanyId'] as String?;
      _activeCompany = _companies.firstWhere(
        (c) => c.id == activeId,
        orElse: () => _companies.first,
      );
    }

    _initialized = true;
    notifyListeners();
  }

  void reset() {
    _initialized = false;
    _companies = [];
    _activeCompany = null;
    _migrationAvailable = false;
    notifyListeners();
  }

  // ── Company CRUD ───────────────────────────────────────────────

  Future<CompanyModel> addCompany({
    required String name,
    String address = '',
    String phone = '',
    String gstNumber = '',
  }) async {
    final ref = _companiesCol.doc();
    final company = CompanyModel(
      id: ref.id,
      name: name,
      address: address,
      phone: phone,
      gstNumber: gstNumber,
      createdAt: DateTime.now().toIso8601String(),
    );
    await ref.set(company.toMap());
    _companies.add(company);
    await _setActiveCompanyLocal(company.id);
    return company;
  }

  Future<void> updateCompany(CompanyModel updated) async {
    await _companiesCol.doc(updated.id).update(updated.toMap());
    final idx = _companies.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) _companies[idx] = updated;
    if (_activeCompany?.id == updated.id) _activeCompany = updated;
    notifyListeners();
  }

  Future<void> setActiveCompany(String companyId) async {
    await _setActiveCompanyLocal(companyId);
  }

  Future<void> _setActiveCompanyLocal(String companyId) async {
    _activeCompany = _companies.firstWhere((c) => c.id == companyId);
    await _userDoc.set({'activeCompanyId': companyId}, SetOptions(merge: true));
    notifyListeners();
  }

  // ── Migration ─────────────────────────────────────────────────

  /// Copies all documents from the old flat collections under `users/demo_user/`
  /// into the new `users/demo_user/companies/{companyId}/` structure.
  /// Call this after [addCompany] returns the first company.
  Future<void> migrateOldData(String companyId) async {
    const cols = [
      'items', 'boms', 'sales', 'purchases', 'expenses',
      'parties', 'productions', 'counters', 'units',
      'stock_transactions', 'payment_ins', 'payment_outs',
    ];

    for (final col in cols) {
      final snap = await _userDoc.collection(col).get();
      if (snap.docs.isEmpty) continue;

      var batch = _db.batch();
      var count = 0;
      for (final doc in snap.docs) {
        final dest = _userDoc
            .collection('companies')
            .doc(companyId)
            .collection(col)
            .doc(doc.id);
        batch.set(dest, doc.data());
        count++;
        if (count == 499) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();
    }

    _migrationAvailable = false;
    notifyListeners();
  }
}
