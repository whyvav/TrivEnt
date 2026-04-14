import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../theme.dart';

class ManufactureScreen extends StatefulWidget {
  const ManufactureScreen({super.key});
  @override State<ManufactureScreen> createState() => _ManufactureScreenState();
}

class _ManufactureScreenState extends State<ManufactureScreen> {
  final svc = FirestoreService();
  ItemModel? _selectedProduct;
  final _qtyController = TextEditingController();
  bool _loading = false;
  String? _previewText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manufacture')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: AppTheme.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text(
                    'Select a product and quantity. The system will automatically '
                    'deduct raw materials using the BoM and add finished goods to inventory.',
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Product to Manufacture',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            StreamBuilder<List<ItemModel>>(
              stream: svc.streamItems(category: 'product'),
              builder: (ctx, snap) {
                final products = snap.data ?? [];
                return DropdownButtonFormField<ItemModel>(
                  value: _selectedProduct,
                  hint: const Text('Select product'),
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: products.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (Stock: ${p.stockQty} ${p.unit})'),
                  )).toList(),
                  onChanged: (v) async {
                    setState(() { _selectedProduct = v; _previewText = null; });
                    if (v != null) _loadBomPreview(v);
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _qtyController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Manufacture',
                suffixText: 'units',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_selectedProduct != null) _loadBomPreview(_selectedProduct!);
              },
            ),
            const SizedBox(height: 16),

            // BoM preview
            if (_previewText != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Production Preview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_previewText!, style: const TextStyle(fontFamily: 'monospace')),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _manufacture,
                icon: _loading
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.precision_manufacturing),
                label: Text(_loading ? 'Processing...' : 'Start Manufacturing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBomPreview(ItemModel product) async {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) { setState(() => _previewText = null); return; }

    final bom = await svc.getBomForProduct(product.id);
    if (bom == null) {
      setState(() => _previewText = 'No BoM found for ${product.name}.\nCreate one in the BoM tab first.');
      return;
    }

    final sb = StringBuffer();
    sb.writeln('Product: ${product.name} × $qty units\n');
    sb.writeln('Materials to deduct:');
    for (final m in bom.materials) {
      sb.writeln('  - ${m.materialName}: ${(m.qtyPerUnit * qty).toStringAsFixed(2)} ${m.unit}');
    }
    sb.writeln('\nEstimated cost: ₹${(bom.totalCostPerUnit * qty).toStringAsFixed(2)}');
    setState(() => _previewText = sb.toString());
  }

  Future<void> _manufacture() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')));
      return;
    }
    final qty = double.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')));
      return;
    }

    setState(() => _loading = true);
    try {
      final bom = await svc.getBomForProduct(_selectedProduct!.id);
      if (bom == null) throw Exception('No BoM defined for ${_selectedProduct!.name}');

      await svc.manufacture(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        qty: qty,
        bom: bom,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success!'),
            ]),
            content: Text(
              'Manufactured ${qty.toStringAsFixed(0)} units of ${_selectedProduct!.name}.\n'
              'Raw materials deducted and finished goods added to inventory.',
            ),
            actions: [TextButton(
              onPressed: () { Navigator.pop(context); setState(() { _selectedProduct = null; _qtyController.clear(); _previewText = null; }); },
              child: const Text('OK'),
            )],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
      }
    } finally {
      setState(() => _loading = false);
    }
  }
}