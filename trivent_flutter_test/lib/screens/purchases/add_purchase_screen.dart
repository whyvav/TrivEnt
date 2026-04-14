import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_model.dart';
import '../../models/item_model.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});
  @override State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final svc = FirestoreService();
  final _partyNameCtrl = TextEditingController();
  final _partyPhoneCtrl = TextEditingController();
  PartyModel? _selectedParty;
  String _paymentType = 'Cash';
  final _amountPaidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_PurchaseRow> _rows = [];
  bool _saving = false;

  double get _total => _rows.fold(0, (s, r) => s + r.lineTotal);

  @override
  void initState() {
    super.initState();
    _rows.add(_PurchaseRow());
  }

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Bill')),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Supplier
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  StreamBuilder<List<PartyModel>>(
                    stream: svc.streamParties(),
                    builder: (ctx, snap) {
                      final parties = snap.data ?? [];
                      return Autocomplete<PartyModel>(
                        displayStringForOption: (p) => p.displayName,
                        optionsBuilder: (tv) => tv.text.isEmpty
                            ? parties
                            : parties.where((p) => p.name.toLowerCase().contains(tv.text.toLowerCase())),
                        onSelected: (p) => setState(() {
                          _selectedParty = p;
                          _partyNameCtrl.text = p.name;
                          _partyPhoneCtrl.text = p.phone ?? '';
                        }),
                        fieldViewBuilder: (ctx, ctrl, fn, _) => TextFormField(
                          controller: ctrl,
                          focusNode: fn,
                          decoration: const InputDecoration(labelText: 'Supplier Name *'),
                          onChanged: (v) => _partyNameCtrl.text = v,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: _partyPhoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone),
                ]),
              )),
              const SizedBox(height: 16),

              // Items (raw materials)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Items (Raw Materials)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                  onPressed: () => setState(() => _rows.add(_PurchaseRow())),
                ),
              ]),
              ...List.generate(_rows.length, (i) {
                final row = _rows[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: StreamBuilder<List<ItemModel>>(
                          stream: svc.streamItems(category: 'raw_material'),
                          builder: (ctx, snap) {
                            final items = snap.data ?? [];
                            return DropdownButtonFormField<ItemModel>(
                              value: row.item,
                              hint: const Text('Select raw material'),
                              decoration: const InputDecoration(labelText: 'Material'),
                              items: items.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.name, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => setState(() {
                                row.item = v;
                                row.priceCtrl.text = v?.purchasePrice.toStringAsFixed(2) ?? '';
                                row.unitCtrl.text = v?.unit ?? '';
                              }),
                            );
                          },
                        )),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _rows.removeAt(i)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextFormField(controller: row.qtyCtrl,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: row.unitCtrl,
                            decoration: const InputDecoration(labelText: 'Unit'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: row.priceCtrl,
                            decoration: const InputDecoration(labelText: '₹/unit'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: row.taxCtrl,
                            decoration: const InputDecoration(labelText: 'Tax %'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}))),
                      ]),
                      Align(alignment: Alignment.centerRight,
                        child: Text('Amount: ₹${row.lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary))),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Payment
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _paymentType,
                    decoration: const InputDecoration(labelText: 'Payment Type'),
                    items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Credit']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() {
                      _paymentType = v!;
                      if (v != 'Credit') _amountPaidCtrl.text = _total.toStringAsFixed(2);
                    }),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _amountPaidCtrl,
                      decoration: InputDecoration(labelText: 'Amount Paid ₹', hintText: cf.format(_total)),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}))),
                ]),
              )),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.1))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(cf.format(_total),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.payable)),
            ])),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Bill'),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_partyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      String partyId = _selectedParty?.id ?? '';
      if (_selectedParty == null) {
        partyId = await svc.upsertPartyFromSale(
          name: _partyNameCtrl.text.trim(),
          phone: _partyPhoneCtrl.text.isEmpty ? null : _partyPhoneCtrl.text.trim(),
        );
      }
      final billNo = await svc.nextBillNo();
      final purchase = PurchaseModel(
        id: const Uuid().v4(),
        billNo: billNo,
        partyId: partyId,
        partyName: _partyNameCtrl.text.trim(),
        partyPhone: _partyPhoneCtrl.text.isEmpty ? null : _partyPhoneCtrl.text.trim(),
        items: _rows.where((r) => r.item != null).map((r) => PurchaseItem(
          itemId: r.item!.id,
          itemName: r.item!.name,
          qty: double.tryParse(r.qtyCtrl.text) ?? 0,
          unit: r.unitCtrl.text,
          priceExclTax: double.tryParse(r.priceCtrl.text) ?? 0,
          taxPercent: double.tryParse(r.taxCtrl.text) ?? 0,
        )).toList(),
        paymentType: _paymentType,
        amountPaid: double.tryParse(_amountPaidCtrl.text) ?? _total,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
      );
      await svc.addPurchase(purchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

class _PurchaseRow {
  ItemModel? item;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final taxCtrl = TextEditingController(text: '0');

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    final tax = double.tryParse(taxCtrl.text) ?? 0;
    return qty * price * (1 + tax / 100);
  }
}