import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/item_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class AddItemScreen extends StatefulWidget {
  final String defaultCategory;
  const AddItemScreen({super.key, this.defaultCategory = 'product'});
  @override State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final svc = FirestoreService();
  late String _category;
  String _unit = 'pieces';

  final _name = TextEditingController();
  final _salePrice = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _openingStock = TextEditingController();
  final _minStock = TextEditingController();
  final _hsn = TextEditingController();
  final _description = TextEditingController();
  double _taxPercent = 0;
  bool _saving = false;

  final _units = ['pieces', 'kg', 'tons', 'bags', 'liters', 'cubic meters', 'sq ft'];
  final _taxOptions = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _category = widget.defaultCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Item')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Category toggle
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Text('Category: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ChoiceChip(label: const Text('Product'), selected: _category == 'product',
                    onSelected: (_) => setState(() => _category = 'product'),
                    selectedColor: AppTheme.primary.withOpacity(0.2)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Raw Material'), selected: _category == 'raw_material',
                    onSelected: (_) => setState(() => _category = 'raw_material'),
                    selectedColor: AppTheme.accent.withOpacity(0.2)),
              ]),
            )),
            const SizedBox(height: 16),

            TextFormField(controller: _name,
                decoration: const InputDecoration(labelText: 'Item Name *'),
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _unit = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<double>(
                initialValue: _taxPercent,
                decoration: const InputDecoration(labelText: 'GST %'),
                items: _taxOptions.map((t) => DropdownMenuItem(value: t, child: Text('$t%'))).toList(),
                onChanged: (v) => setState(() => _taxPercent = v!),
              )),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: TextFormField(controller: _salePrice,
                  decoration: const InputDecoration(labelText: 'Sale Price (₹)', prefixText: '₹'),
                  keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _purchasePrice,
                  decoration: const InputDecoration(labelText: 'Purchase Price (₹)', prefixText: '₹'),
                  keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: TextFormField(controller: _openingStock,
                  decoration: const InputDecoration(labelText: 'Opening Stock'),
                  keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _minStock,
                  decoration: const InputDecoration(labelText: 'Min Stock Alert'),
                  keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: TextFormField(controller: _hsn,
                  decoration: const InputDecoration(labelText: 'HSN Code (optional)'))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _description,
                  decoration: const InputDecoration(labelText: 'Description (optional)'))),
            ]),
            const SizedBox(height: 24),

            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Item'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final item = ItemModel(
        id: const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        unit: _unit,
        taxPercent: _taxPercent,
        salePrice: double.tryParse(_salePrice.text) ?? 0,
        purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
        stockQty: double.tryParse(_openingStock.text) ?? 0,
        minStockAlert: double.tryParse(_minStock.text) ?? 0,
        hsn: _hsn.text.isEmpty ? null : _hsn.text.trim(),
        description: _description.text.isEmpty ? null : _description.text.trim(),
      );
      await svc.saveItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}