import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/purchase_model.dart';
import '../../models/item_model.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class AddPurchaseScreen extends StatefulWidget {
  final PurchaseModel? existing;
  final PartyModel? prefilledParty;

  const AddPurchaseScreen({super.key, this.existing, this.prefilledParty});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final svc = FirestoreService();

  final _partyNameCtrl = TextEditingController();
  final _partyPhoneCtrl = TextEditingController();
  final _partyFirmCtrl = TextEditingController(); // ✅ NEW

  final _amountPaidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _paymentRefCtrl = TextEditingController(); // ✅ NEW

  PartyModel? _selectedParty;

  String _paymentType = 'Cash';

  DateTime _selectedDate = DateTime.now(); // ✅ NEW

  final List<_PurchaseRow> _rows = [];
  bool _saving = false;

  double get _total => _rows.fold(0, (s, r) => s + r.lineTotal);

  @override
  void initState() {
    super.initState();
    _rows.add(_PurchaseRow());
    if (widget.prefilledParty != null) {
      _partyNameCtrl.text = widget.prefilledParty!.name;
      _partyPhoneCtrl.text = widget.prefilledParty!.phone ?? '';
      _partyFirmCtrl.text = widget.prefilledParty!.firm ?? '';
      _selectedParty = widget.prefilledParty;
    }
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

              // ── Supplier ──────────────────────────────
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
                            : parties.where((p) =>
                                p.name.toLowerCase().contains(tv.text.toLowerCase())),
                        onSelected: (p) => setState(() {
                          _selectedParty = p;
                          _partyNameCtrl.text = p.name;
                          _partyPhoneCtrl.text = p.phone ?? '';
                          _partyFirmCtrl.text = p.firm ?? ''; // ✅
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

                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _partyPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _partyFirmCtrl,
                        decoration: const InputDecoration(labelText: 'Firm / Company'),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // ✅ DATE PICKER
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Bill Date'),
                      child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                    ),
                  ),

                ]),
              )),

              const SizedBox(height: 16),

              // ── Items ──────────────────────────────
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
                              initialValue: row.item,
                              hint: const Text('Select raw material'),
                              decoration: const InputDecoration(labelText: 'Material'),
                              items: items.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.name),
                              )).toList(),
                              onChanged: (v) => setState(() {
                                row.item = v;
                                row.priceCtrl.text = v?.purchasePrice.toStringAsFixed(2) ?? '';
                                row.unitCtrl.text = v?.primaryUnit ?? '';
                                row.taxCtrl.text = v?.taxPercent.toStringAsFixed(0) ?? '0';
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
                        Expanded(child: TextFormField(
                          controller: row.qtyCtrl,
                          decoration: const InputDecoration(labelText: 'Qty'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        )),

                        const SizedBox(width: 6),

                        Expanded(child: TextFormField(
                          controller: row.unitCtrl,
                          decoration: const InputDecoration(labelText: 'Unit'),
                        )),

                        const SizedBox(width: 6),

                        Expanded(child: TextFormField(
                          controller: row.priceCtrl,
                          decoration: const InputDecoration(labelText: '₹/unit'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        )),

                        const SizedBox(width: 6),

                        // ✅ Discount
                        Expanded(child: TextFormField(
                          controller: row.discountCtrl,
                          decoration: const InputDecoration(labelText: 'Disc %'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        )),

                        const SizedBox(width: 6),

                        // ✅ Smart Tax Dropdown
                        Expanded(child: Column(children: [
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Tax', isDense: true),
                            items: const [
                              DropdownMenuItem(value: '0', child: Text('None (0%)')),
                              DropdownMenuItem(value: '5', child: Text('GST 5%')),
                              DropdownMenuItem(value: '12', child: Text('GST 12%')),
                              DropdownMenuItem(value: '18', child: Text('GST 18%')),
                              DropdownMenuItem(value: '28', child: Text('GST 28%')),
                              DropdownMenuItem(value: 'custom', child: Text('Custom...')),
                            ],
                            onChanged: (v) {
                              if (v == 'custom') return;
                              if (v != null) setState(() => row.taxCtrl.text = v);
                            },
                          ),
                          TextFormField(
                            controller: row.taxCtrl,
                            decoration: const InputDecoration(labelText: '% value', isDense: true),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ])),
                      ]),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('Amount: ₹${row.lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      ),

                    ]),
                  ),
                );
              }),

              const SizedBox(height: 12),

              // ── Payment ──────────────────────────────
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [

                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: _paymentType,
                      decoration: const InputDecoration(labelText: 'Payment Type'),
                      items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Credit']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() {
                        _paymentType = v!;
                        if (v != 'Credit') {
                          _amountPaidCtrl.text = _total.toStringAsFixed(2);
                        } else {
                          _amountPaidCtrl.clear();
                        }
                      }),
                    )),

                    const SizedBox(width: 10),

                    // ✅ Payment Ref
                    Expanded(child: TextFormField(
                      controller: _paymentRefCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Payment Ref. (cheque/UPI no.)'),
                    )),
                  ]),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _amountPaidCtrl,
                    decoration: InputDecoration(
                      labelText: 'Amount Paid ₹',
                      hintText: cf.format(_total),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),

                ]),
              )),

            ]),
          ),
        ),

        // Bottom bar unchanged
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text(cf.format(_total),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Save Bill'),
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
          firm: _partyFirmCtrl.text.isEmpty ? null : _partyFirmCtrl.text.trim(),
          phone: _partyPhoneCtrl.text.isEmpty ? null : _partyPhoneCtrl.text.trim(),
        );
      }

      final billNo = await svc.nextPurchaseBillNo(_selectedDate); // ✅

      final purchase = PurchaseModel(
        id: const Uuid().v4(),
        billNo: billNo,
        partyId: partyId,
        partyName: _partyNameCtrl.text.trim(),
        partyFirm: _partyFirmCtrl.text.isEmpty ? null : _partyFirmCtrl.text.trim(),
        partyPhone: _partyPhoneCtrl.text.isEmpty ? null : _partyPhoneCtrl.text.trim(),

        items: _rows.where((r) => r.item != null).map((r) => PurchaseItem(
          itemId: r.item!.id,
          itemName: r.item!.name,
          qty: double.tryParse(r.qtyCtrl.text) ?? 0,
          unit: r.unitCtrl.text,
          priceExclTax: double.tryParse(r.priceCtrl.text) ?? 0,
          taxPercent: double.tryParse(r.taxCtrl.text) ?? 0,
          discountPercent: double.tryParse(r.discountCtrl.text) ?? 0,
        )).toList(),

        paymentType: _paymentType,
        paymentRef: _paymentRefCtrl.text.isEmpty ? null : _paymentRefCtrl.text.trim(),
        amountPaid: double.tryParse(_amountPaidCtrl.text) ?? _total,

        date: _selectedDate, // ✅ CRITICAL

        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
      );

      await svc.addPurchase(purchase);

      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() => _saving = false);
    }
  }
}

class _PurchaseRow {
  ItemModel? item;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final taxCtrl = TextEditingController(text: '0');
  final discountCtrl = TextEditingController(text: '0'); // ✅ NEW

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    final tax = double.tryParse(taxCtrl.text) ?? 0;
    final disc = double.tryParse(discountCtrl.text) ?? 0;

    final priceAfterDisc = price * (1 - disc / 100);
    return qty * priceAfterDisc * (1 + tax / 100);
  }
}