import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../models/item_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});
  @override State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final svc = FirestoreService();
  final _partyName = TextEditingController();
  final _partyPhone = TextEditingController();
  String _paymentType = 'Cash';
  bool _isPaid = false;
  final List<_SaleItemRow> _rows = [];
  bool _saving = false;
  int _invoiceCounter = 1;

  String get _invoiceNo =>
      'INV-${DateFormat('yyyyMM').format(DateTime.now())}-${_invoiceCounter.toString().padLeft(3, '0')}';

  double get _total => _rows.fold(0, (s, r) {
    final qty = double.tryParse(r.qtyController.text) ?? 0;
    final price = double.tryParse(r.priceController.text) ?? 0;
    return s + (qty * price);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Party info
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _partyName,
                      decoration: const InputDecoration(labelText: 'Party Name *'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _partyPhone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    )),
                  ]),
                  const SizedBox(height: 16),

                  // Items table
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                      onPressed: () => setState(() => _rows.add(_SaleItemRow())),
                    ),
                  ]),
                  ...List.generate(_rows.length, (i) {
                    final row = _rows[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          StreamBuilder<List<ItemModel>>(
                            stream: svc.streamItems(category: 'product'),
                            builder: (ctx, snap) {
                              final items = snap.data ?? [];
                              return DropdownButtonFormField<ItemModel>(
                                value: row.item,
                                hint: const Text('Select product'),
                                decoration: const InputDecoration(labelText: 'Product'),
                                items: items.map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.name} (Stock: ${p.stockQty})'),
                                )).toList(),
                                onChanged: (v) => setState(() {
                                  row.item = v;
                                  row.priceController.text = v?.salePrice.toString() ?? '';
                                  row.unitController.text = v?.unit ?? '';
                                }),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: TextFormField(
                              controller: row.qtyController,
                              decoration: const InputDecoration(labelText: 'Qty'),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(
                              controller: row.unitController,
                              decoration: const InputDecoration(labelText: 'Unit'),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(
                              controller: row.priceController,
                              decoration: const InputDecoration(labelText: '₹/unit'),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            )),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _rows.removeAt(i)),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Payment
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: _paymentType,
                      decoration: const InputDecoration(labelText: 'Payment Type'),
                      items: ['Cash', 'UPI', 'Bank Transfer', 'Credit']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() {
                        _paymentType = v!;
                        _isPaid = v != 'Credit';
                      }),
                    )),
                    const SizedBox(width: 16),
                    Row(children: [
                      Checkbox(value: _isPaid, onChanged: (v) => setState(() => _isPaid = v!)),
                      const Text('Mark as Paid'),
                    ]),
                  ]),
                ],
              ),
            ),
          ),

          // Bottom total + save bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.1))],
            ),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount', style: TextStyle(color: Colors.grey)),
                  Text('₹${_total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              )),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Sale'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_partyName.text.isEmpty) {
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
      final sale = SaleModel(
        id: const Uuid().v4(),
        invoiceNo: _invoiceNo,
        partyName: _partyName.text.trim(),
        partyPhone: _partyPhone.text.isEmpty ? null : _partyPhone.text.trim(),
        items: _rows.where((r) => r.item != null).map((r) => SaleItem(
          itemId: r.item!.id,
          itemName: r.item!.name,
          qty: double.tryParse(r.qtyController.text) ?? 0,
          unit: r.unitController.text,
          pricePerUnit: double.tryParse(r.priceController.text) ?? 0,
        )).toList(),
        paymentType: _paymentType,
        isPaid: _isPaid,
      );
      await svc.addSale(sale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

class _SaleItemRow {
  ItemModel? item;
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  final unitController = TextEditingController();
}