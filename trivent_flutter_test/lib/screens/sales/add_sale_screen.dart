import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../models/item_model.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class AddSaleScreen extends StatefulWidget {
  final SaleModel? existing;
  const AddSaleScreen({super.key, this.existing});
  @override State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final svc = FirestoreService();
  PartyModel? _selectedParty;
  final _partyNameCtrl = TextEditingController();
  final _partyPhoneCtrl = TextEditingController();
  final _partyFirmCtrl = TextEditingController();
  String _paymentType = 'Cash';
  final _amountPaidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _orderNoCtrl = TextEditingController();
  final List<_SaleRow> _rows = [];
  bool _saving = false;

  double get _total => _rows.fold(0, (s, r) => s + r.lineTotal);

  @override
  void initState() {
    super.initState();
    _rows.add(_SaleRow());
  }

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(title: const Text('New Sale Invoice')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Party Section ──────────────────────────────
                Text('Party Details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    // Party autocomplete
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
                            // Sync controller
                            if (_partyNameCtrl.text.isNotEmpty && ctrl.text.isEmpty) {
                              ctrl.text = _partyNameCtrl.text;
                            }
                            return TextFormField(
                              controller: ctrl,
                              focusNode: focusNode,
                              decoration: const InputDecoration(labelText: 'Party Name *',
                                  hintText: 'Type or select existing party'),
                              onChanged: (v) => _partyNameCtrl.text = v,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _partyPhoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone'),
                          keyboardType: TextInputType.phone)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _partyFirmCtrl,
                          decoration: const InputDecoration(labelText: 'Firm / Company'))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _orderNoCtrl,
                          decoration: const InputDecoration(labelText: 'Order No. (optional)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes (optional)'))),
                    ]),
                  ]),
                )),
                const SizedBox(height: 16),

                // ── Items Table ────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Items', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                    onPressed: () => setState(() => _rows.add(_SaleRow())),
                  ),
                ]),
                ...List.generate(_rows.length, (i) => _buildItemRow(i)),
                const SizedBox(height: 16),

                // ── Payment ────────────────────────────────────
                Text('Payment', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        value: _paymentType,
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
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _amountPaidCtrl,
                        decoration: InputDecoration(
                          labelText: 'Amount Paid ₹',
                          hintText: cf.format(_total),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    // Totals summary
                    _TotalsRow(rows: _rows, amountPaid: double.tryParse(_amountPaidCtrl.text) ?? 0),
                  ]),
                )),
              ]),
            ),
          ),

          // Bottom bar
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                if ((double.tryParse(_amountPaidCtrl.text) ?? 0) < _total && _total > 0)
                  Text('Balance: ${cf.format(_total - (double.tryParse(_amountPaidCtrl.text) ?? 0))}',
                      style: const TextStyle(color: AppTheme.payable, fontSize: 12)),
              ])),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Invoice'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final row = _rows[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: StreamBuilder<List<ItemModel>>(
              stream: svc.streamItems(category: 'product'),
              builder: (ctx, snap) {
                final items = snap.data ?? [];
                return DropdownButtonFormField<ItemModel>(
                  value: row.item,
                  hint: const Text('Select product'),
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: items.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (${p.stockQty} ${p.unit})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    row.item = v;
                    row.priceCtrl.text = v?.salePrice.toStringAsFixed(2) ?? '';
                    row.unitCtrl.text = v?.unit ?? '';
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
              decoration: const InputDecoration(labelText: '₹/unit (excl tax)'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 6),
            Expanded(child: TextFormField(
              controller: row.discountCtrl,
              decoration: const InputDecoration(labelText: 'Disc %'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 6),
            Expanded(child: TextFormField(
              controller: row.taxCtrl,
              decoration: const InputDecoration(labelText: 'Tax %'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            )),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Price incl. tax: ₹${row.priceInclTax.toStringAsFixed(2)}/unit   '
              'Amount: ₹${row.lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_partyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Party name is required')));
      return;
    }
    if (_rows.isEmpty || _rows.every((r) => r.item == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one item')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Auto-create party if not selected from list
      String partyId = _selectedParty?.id ?? '';
      if (_selectedParty == null) {
        partyId = await svc.upsertPartyFromSale(
          name: _partyNameCtrl.text.trim(),
          firm: _partyFirmCtrl.text.isEmpty ? null : _partyFirmCtrl.text.trim(),
          phone: _partyPhoneCtrl.text.isEmpty ? null : _partyPhoneCtrl.text.trim(),
        );
      }

      final invoiceNo = await svc.nextInvoiceNo();
      final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? _total;

      final sale = SaleModel(
        id: const Uuid().v4(),
        invoiceNo: invoiceNo,
        partyId: partyId,
        partyName: _partyNameCtrl.text.trim(),
        partyFirm: _partyFirmCtrl.text.isEmpty ? null : _partyFirmCtrl.text.trim(),
        partyPhone: _partyPhoneCtrl.text.isEmpty ? null : _partyPhoneCtrl.text.trim(),
        items: _rows.where((r) => r.item != null).map((r) => SaleItem(
          itemId: r.item!.id,
          itemName: r.item!.name,
          qty: double.tryParse(r.qtyCtrl.text) ?? 0,
          unit: r.unitCtrl.text,
          priceExclTax: double.tryParse(r.priceCtrl.text) ?? 0,
          taxPercent: double.tryParse(r.taxCtrl.text) ?? 0,
          discountPercent: double.tryParse(r.discountCtrl.text) ?? 0,
        )).toList(),
        paymentType: _paymentType,
        amountPaid: amountPaid,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
        orderNo: _orderNoCtrl.text.isEmpty ? null : _orderNoCtrl.text.trim(),
      );

      await svc.addSale(sale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

class _SaleRow {
  ItemModel? item;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');
  final taxCtrl = TextEditingController(text: '0');

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get price => double.tryParse(priceCtrl.text) ?? 0;
  double get discount => double.tryParse(discountCtrl.text) ?? 0;
  double get tax => double.tryParse(taxCtrl.text) ?? 0;
  double get discountAmount => price * discount / 100;
  double get priceAfterDiscount => price - discountAmount;
  double get taxAmount => priceAfterDiscount * tax / 100;
  double get priceInclTax => priceAfterDiscount + taxAmount;
  double get lineTotal => qty * priceInclTax;
}

class _TotalsRow extends StatelessWidget {
  final List<_SaleRow> rows;
  final double amountPaid;
  const _TotalsRow({required this.rows, required this.amountPaid});

  @override
  Widget build(BuildContext context) {
    final subtotal = rows.fold<double>(0, (s, r) => s + (r.qty * r.price));
    final discount = rows.fold<double>(0, (s, r) => s + (r.qty * r.discountAmount));
    final tax = rows.fold<double>(0, (s, r) => s + (r.qty * r.taxAmount));
    final total = subtotal - discount + tax;
    final balance = total - amountPaid;
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(children: [
      _Row('Subtotal', cf.format(subtotal), Colors.black87),
      if (discount > 0) _Row('Discount', '- ${cf.format(discount)}', Colors.orange),
      if (tax > 0) _Row('Tax', '+ ${cf.format(tax)}', Colors.grey),
      const Divider(),
      _Row('Total', cf.format(total), AppTheme.primary, bold: true),
      _Row('Amount Paid', cf.format(amountPaid), AppTheme.receivable),
      if (balance > 0.01) _Row('Balance Due', cf.format(balance), AppTheme.payable, bold: true),
    ]);
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Row(this.label, this.value, this.color, {this.bold = false});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600)),
      Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    ]),
  );
}