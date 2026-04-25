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

  PartyModel? _selectedParty;

  final _partyNameCtrl = TextEditingController();
  final _partyPhoneCtrl = TextEditingController();
  final _partyFirmCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _amountPaidCtrl = TextEditingController();
  final _paymentRefCtrl = TextEditingController();

  String _paymentType = 'Cash';
  DateTime _selectedDate = DateTime.now();
  final List<_PurchaseRow> _rows = [];
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  double get _total => _rows.fold(0, (s, r) => s + r.lineTotal);

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final p = widget.existing!;
      _partyNameCtrl.text = p.partyName;
      _partyPhoneCtrl.text = p.partyPhone ?? '';
      _partyFirmCtrl.text = p.partyFirm ?? '';
      _notesCtrl.text = p.notes ?? '';
      _paymentType = p.paymentType;
      _paymentRefCtrl.text = p.paymentRef ?? '';
      _amountPaidCtrl.text = p.amountPaid.toStringAsFixed(2);
      _selectedDate = p.date;
      for (final item in p.items) {
        final row = _PurchaseRow(
          preloadedItemId: item.itemId,
          preloadedItemName: item.itemName,
        );
        row.qtyCtrl.text = item.qty.toStringAsFixed(2);
        row.unitCtrl.text = item.unit;
        row.priceCtrl.text = item.priceExclTax.toStringAsFixed(2);
        row.discountCtrl.text = item.discountPercent.toStringAsFixed(0);
        row.taxCtrl.text = item.taxPercent.toStringAsFixed(0);
        _rows.add(row);
      }
      if (_rows.isEmpty) _rows.add(_PurchaseRow());
    } else {
      _rows.add(_PurchaseRow());
      if (widget.prefilledParty != null) {
        _partyNameCtrl.text = widget.prefilledParty!.name;
        _partyPhoneCtrl.text = widget.prefilledParty!.phone ?? '';
        _partyFirmCtrl.text = widget.prefilledParty!.firm ?? '';
        _selectedParty = widget.prefilledParty;
      }
    }
  }

  @override
  void dispose() {
    _partyNameCtrl.dispose();
    _partyPhoneCtrl.dispose();
    _partyFirmCtrl.dispose();
    _notesCtrl.dispose();
    _amountPaidCtrl.dispose();
    _paymentRefCtrl.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Purchase Bill' : 'New Purchase Bill'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Supplier Section ──────────────────────────────
                  Text('Supplier Details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [

                          StreamBuilder<List<PartyModel>>(
                            stream: svc.streamParties(),
                            builder: (ctx, snap) {
                              final parties = snap.data ?? [];
                              return Autocomplete<PartyModel>(
                                displayStringForOption: (p) => p.displayName,
                                optionsBuilder: (tv) {
                                  if (tv.text.isEmpty) return parties;
                                  return parties.where((p) =>
                                      p.name.toLowerCase().contains(tv.text.toLowerCase()) ||
                                      (p.firm?.toLowerCase().contains(tv.text.toLowerCase()) ?? false));
                                },
                                onSelected: (p) {
                                  setState(() {
                                    _selectedParty = p;
                                    _partyNameCtrl.text = p.name;
                                    _partyPhoneCtrl.text = p.phone ?? '';
                                    _partyFirmCtrl.text = p.firm ?? '';
                                  });
                                },
                                fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                                  if (_partyNameCtrl.text.isNotEmpty && ctrl.text.isEmpty) {
                                    ctrl.text = _partyNameCtrl.text;
                                  }
                                  return TextFormField(
                                    controller: ctrl,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Supplier Name *',
                                      hintText: 'Type or select existing supplier',
                                    ),
                                    onChanged: (v) {
                                      _partyNameCtrl.text = v;
                                      if (_selectedParty != null &&
                                          _selectedParty!.name != v) {
                                        _selectedParty = null;
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
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
                            ],
                          ),

                          const SizedBox(height: 10),

                          TextFormField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notes / Description',
                            ),
                          ),

                          const SizedBox(height: 10),

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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Items ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Items',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.grey)),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Row'),
                        onPressed: () => setState(() => _rows.add(_PurchaseRow())),
                      ),
                    ],
                  ),

                  StreamBuilder<List<ItemModel>>(
                    stream: svc.streamItems(category: 'raw_material'),
                    builder: (ctx, snap) {
                      final items = snap.data ?? [];
                      return Column(
                        children: List.generate(
                          _rows.length,
                          (i) => _buildItemRow(i, items),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Payment ────────────────────────────────────
                  Text('Payment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _paymentType,
                                  decoration: const InputDecoration(labelText: 'Payment Type'),
                                  items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Credit']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _paymentType = v!;
                                    if (v != 'Credit') {
                                      _amountPaidCtrl.text = _total.toStringAsFixed(2);
                                    } else {
                                      _amountPaidCtrl.clear();
                                    }
                                  }),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: TextFormField(
                                  controller: _paymentRefCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Payment Ref. (cheque/UPI no.)'),
                                ),
                              ),
                            ],
                          ),

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

                          const SizedBox(height: 8),

                          _TotalsRow(
                            rows: _rows,
                            amountPaid: double.tryParse(_amountPaidCtrl.text) ?? 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cf.format(_total),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEditing ? 'Update Bill' : 'Save Bill'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int i, List<ItemModel> items) {
    final row = _rows[i];

    if (row.item == null && row.preloadedItemId != null) {
      final matches = items.where((item) => item.id == row.preloadedItemId);
      if (matches.isNotEmpty) row.item = matches.first;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ItemModel>(
                    initialValue: row.item,
                    hint: const Text('Select material'),
                    decoration: const InputDecoration(labelText: 'Material'),
                    items: items.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text('${m.name} (${m.stockQty} ${m.primaryUnit})'),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      row.item = v;
                      row.priceCtrl.text = v?.purchasePrice.toStringAsFixed(2) ?? '';
                      row.unitCtrl.text = v?.primaryUnit ?? '';
                      row.taxCtrl.text = v?.taxPercent.toStringAsFixed(0) ?? '0';
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _rows.length > 1
                      ? () => setState(() {
                            _rows[i].dispose();
                            _rows.removeAt(i);
                          })
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.qtyCtrl,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: TextFormField(
                    controller: row.unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: TextFormField(
                    controller: row.priceCtrl,
                    decoration: const InputDecoration(labelText: '₹/unit'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: TextFormField(
                    controller: row.discountCtrl,
                    decoration: const InputDecoration(labelText: 'Disc %'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Column(
                    children: [
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
                          if (v == null || v == 'custom') return;
                          setState(() => row.taxCtrl.text = v);
                        },
                      ),
                      TextFormField(
                        controller: row.taxCtrl,
                        decoration: const InputDecoration(labelText: '% value', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_partyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Supplier name is required')));
      return;
    }

    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() => _saving = true);

    try {
      String partyId;
      if (_selectedParty != null) {
        partyId = _selectedParty!.id;
      } else if (_isEditing) {
        partyId = widget.existing!.partyId;
      } else {
        partyId = await svc.upsertPartyFromSale(
          name: _partyNameCtrl.text.trim(),
          firm: _partyFirmCtrl.text.trim(),
          phone: _partyPhoneCtrl.text.trim(),
        );
      }

      final billNo = _isEditing
          ? widget.existing!.billNo
          : await svc.nextPurchaseBillNo(_selectedDate);

      final purchase = PurchaseModel(
        id: _isEditing ? widget.existing!.id : const Uuid().v4(),
        billNo: billNo,
        partyId: partyId,
        partyName: _partyNameCtrl.text.trim(),
        partyFirm: _partyFirmCtrl.text.trim().isEmpty ? null : _partyFirmCtrl.text.trim(),
        partyPhone: _partyPhoneCtrl.text.trim().isEmpty ? null : _partyPhoneCtrl.text.trim(),
        items: validRows.map((r) => PurchaseItem(
          itemId: r.effectiveItemId,
          itemName: r.effectiveItemName,
          qty: double.tryParse(r.qtyCtrl.text) ?? 0,
          unit: r.unitCtrl.text,
          priceExclTax: double.tryParse(r.priceCtrl.text) ?? 0,
          taxPercent: double.tryParse(r.taxCtrl.text) ?? 0,
          discountPercent: double.tryParse(r.discountCtrl.text) ?? 0,
        )).toList(),
        paymentType: _paymentType,
        paymentRef: _paymentRefCtrl.text.trim().isEmpty ? null : _paymentRefCtrl.text.trim(),
        amountPaid: double.tryParse(_amountPaidCtrl.text) ?? _total,
        date: _selectedDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (_isEditing) {
        await svc.updatePurchase(purchase);
      } else {
        await svc.addPurchase(purchase);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bill: $e')),
        );
      }
    }
  }
}

// ── Helper classes ────────────────────────────────────────────────────────────

class _PurchaseRow {
  ItemModel? item;
  final String? preloadedItemId;
  final String? preloadedItemName;

  final qtyCtrl = TextEditingController(text: '1');
  final unitCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');
  final taxCtrl = TextEditingController(text: '0');

  _PurchaseRow({this.preloadedItemId, this.preloadedItemName});

  bool get isValid => item != null || preloadedItemId != null;
  String get effectiveItemId => item?.id ?? preloadedItemId ?? '';
  String get effectiveItemName => item?.name ?? preloadedItemName ?? '';

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get priceExclTax => double.tryParse(priceCtrl.text) ?? 0;
  double get discountPercent => double.tryParse(discountCtrl.text) ?? 0;
  double get taxPercent => double.tryParse(taxCtrl.text) ?? 0;

  double get discountAmount => priceExclTax * discountPercent / 100;
  double get priceAfterDiscount => priceExclTax - discountAmount;
  double get taxAmount => priceAfterDiscount * taxPercent / 100;
  double get priceInclTax => priceAfterDiscount + taxAmount;
  double get lineTotal => qty * priceInclTax;

  void dispose() {
    qtyCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
    taxCtrl.dispose();
  }
}

class _TotalsRow extends StatelessWidget {
  final List<_PurchaseRow> rows;
  final double amountPaid;
  const _TotalsRow({required this.rows, required this.amountPaid});

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final subtotal = rows.fold(0.0, (s, r) => s + r.qty * r.priceExclTax);
    final totalDiscount = rows.fold(0.0, (s, r) => s + r.qty * r.discountAmount);
    final totalTax = rows.fold(0.0, (s, r) => s + r.qty * r.taxAmount);
    final total = rows.fold(0.0, (s, r) => s + r.lineTotal);
    final balance = (total - amountPaid).clamp(0.0, double.infinity);

    return Column(
      children: [
        const Divider(),
        _TotalLine('Subtotal', cf.format(subtotal)),
        if (totalDiscount > 0.01)
          _TotalLine('Discount', '- ${cf.format(totalDiscount)}'),
        if (totalTax > 0.01)
          _TotalLine('Tax', '+ ${cf.format(totalTax)}'),
        const Divider(height: 4),
        _TotalLine('Total', cf.format(total), bold: true),
        _TotalLine(
          'Balance Due',
          cf.format(balance),
          color: balance > 0.01 ? AppTheme.payable : AppTheme.receivable,
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _TotalLine(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
      fontSize: bold ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
