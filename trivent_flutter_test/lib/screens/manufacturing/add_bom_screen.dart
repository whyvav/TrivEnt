import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/bom_model.dart';
import '../../models/item_model.dart';
import '../../services/firestore_service.dart';

class AddBomScreen extends StatefulWidget {
  final BomModel? existing;
  const AddBomScreen({super.key, this.existing});
  @override State<AddBomScreen> createState() => _AddBomScreenState();
}

class _AddBomScreenState extends State<AddBomScreen> {
  final svc = FirestoreService();
  ItemModel? _selectedProduct;
  String? _pendingProductId;
  final List<_MaterialRow> _materialRows = [];
  final List<_CostRow> _costRows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _populateFromExisting();
  }

  void _populateFromExisting() {
    final e = widget.existing!;
    _pendingProductId = e.productId;
    _materialRows.addAll(e.materials.map((m) => _MaterialRow(
      materialId: m.materialId,
      qty: m.qtyPerUnit.toString(),
      price: m.pricePerUnit.toString(),
      unit: m.unit,
    )));
    _costRows.addAll(e.otherCosts.map((c) => _CostRow(
      type: c.type,
      cost: c.costPerUnit.toString(),
      unit: c.unit,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Bill of Materials' : 'Create Bill of Materials')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product selector
            const Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            StreamBuilder<List<ItemModel>>(
              stream: svc.streamItems(category: 'product'),
              builder: (ctx, snap) {
                final products = snap.data ?? [];
                if (_pendingProductId != null && _selectedProduct == null) {
                  final matches = products.where((p) => p.id == _pendingProductId);
                  if (matches.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() { _selectedProduct = matches.first; _pendingProductId = null; });
                    });
                  }
                }
                return DropdownButtonFormField<ItemModel>(
                  initialValue: _selectedProduct,
                  hint: const Text('Select product'),
                  decoration: const InputDecoration(labelText: 'Product to manufacture'),
                  items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (v) => setState(() => _selectedProduct = v),
                );
              },
            ),
            const SizedBox(height: 24),

            // Raw materials section
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Raw Materials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () => setState(() => _materialRows.add(_MaterialRow())),
              ),
            ]),
            ...List.generate(_materialRows.length, (i) {
              final row = _materialRows[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    StreamBuilder<List<ItemModel>>(
                      stream: svc.streamItems(category: 'raw_material'),
                      builder: (ctx, snap) {
                        final mats = snap.data ?? [];
                        if (row.materialId != null && row.material == null) {
                          final matches = mats.where((m) => m.id == row.materialId);
                          if (matches.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() { row.material = matches.first; row.materialId = null; });
                            });
                          }
                        }
                        return DropdownButtonFormField<ItemModel>(
                          initialValue: row.material,
                          hint: const Text('Select material'),
                          decoration: const InputDecoration(labelText: 'Raw Material'),
                          items: mats.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
                          onChanged: (v) => setState(() {
                            row.material = v;
                            row.priceController.text = v?.purchasePrice.toString() ?? '';
                            row.unitController.text = v?.primaryUnit ?? '';
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: row.qtyController,
                        decoration: const InputDecoration(labelText: 'Qty per unit'),
                        keyboardType: TextInputType.number,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: row.unitController,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: row.priceController,
                        decoration: const InputDecoration(labelText: 'Price/unit ₹'),
                        keyboardType: TextInputType.number,
                      )),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => _materialRows.removeAt(i)),
                      ),
                    ]),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Other costs section
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Other Costs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () => setState(() => _costRows.add(_CostRow())),
              ),
            ]),
            ...List.generate(_costRows.length, (i) {
              final row = _costRows[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: row.type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: ['Labor', 'Electricity', 'Fuel', 'Other']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => row.type = v!),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(
                      controller: row.costController,
                      decoration: const InputDecoration(labelText: 'Cost/unit ₹'),
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(
                      controller: row.unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    )),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _costRows.removeAt(i)),
                    ),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Update BoM' : 'Save BoM'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')));
      return;
    }
    setState(() => _saving = true);
    try {
      final bom = BomModel(
        id: widget.existing?.id ?? const Uuid().v4(),
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        materials: _materialRows
            .where((r) => r.material != null)
            .map((r) => BomMaterial(
                  materialId: r.material!.id,
                  materialName: r.material!.name,
                  qtyPerUnit: double.tryParse(r.qtyController.text) ?? 0,
                  unit: r.unitController.text,
                  pricePerUnit: double.tryParse(r.priceController.text) ?? 0,
                ))
            .toList(),
        otherCosts: _costRows.map((r) => BomOtherCost(
              type: r.type,
              costPerUnit: double.tryParse(r.costController.text) ?? 0,
              unit: r.unitController.text,
            )).toList(),
        createdAt: widget.existing?.createdAt,
      );
      await svc.saveBom(bom);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing == null ? 'BoM saved!' : 'BoM updated!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

class _MaterialRow {
  ItemModel? material;
  String? materialId;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final TextEditingController unitController;

  _MaterialRow({this.materialId, String qty = '', String price = '', String unit = ''})
      : qtyController = TextEditingController(text: qty),
        priceController = TextEditingController(text: price),
        unitController = TextEditingController(text: unit);
}

class _CostRow {
  String type;
  final TextEditingController costController;
  final TextEditingController unitController;

  _CostRow({this.type = 'Labor', String cost = '', String unit = 'per 1000 bricks'})
      : costController = TextEditingController(text: cost),
        unitController = TextEditingController(text: unit);
}
