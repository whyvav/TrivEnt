import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../models/bom_model.dart';
import '../../theme.dart';
import '../inventory/add_item_screen.dart';
import 'add_bom_screen.dart';

class ManufactureScreen extends StatefulWidget {
  const ManufactureScreen({super.key});
  @override State<ManufactureScreen> createState() => _ManufactureScreenState();
}

class _ManufactureScreenState extends State<ManufactureScreen> {
  final svc = FirestoreService();
  ItemModel? _selectedProduct;
  BomModel? _selectedBom;
  bool _bomLoading = false;
  bool _bomChecked = false;
  final _qtyController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manufacture')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product to Manufacture',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            StreamBuilder<List<ItemModel>>(
              stream: svc.streamItems(category: 'product'),
              builder: (ctx, snap) {
                final products = (snap.data ?? [])
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                return InkWell(
                  onTap: () => _showProductPicker(context, products),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Product',
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      _selectedProduct != null
                          ? '${_selectedProduct!.name}  (Stock: ${_selectedProduct!.stockQty} ${_selectedProduct!.primaryUnit})'
                          : 'Select product',
                      style: TextStyle(
                        color: _selectedProduct != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // BoM section — shown immediately after a product is picked
            if (_selectedProduct != null) ...[
              if (_bomLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_bomChecked && _selectedBom == null)
                _NoBomCard(
                  product: _selectedProduct!,
                  onAdd: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => AddBomScreen(
                                initialProductId: _selectedProduct!.id)));
                    if (_selectedProduct != null && mounted) _loadBom(_selectedProduct!);
                  },
                )
              else if (_selectedBom != null)
                _BomDetailCard(
                  bom: _selectedBom!,
                  onEdit: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => AddBomScreen(existing: _selectedBom)));
                    if (_selectedProduct != null && mounted) _loadBom(_selectedProduct!);
                  },
                ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _qtyController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Manufacture',
                suffixText: 'units',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of Manufacture',
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 32),

            const Text('Production History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _ProductionHistory(svc: svc),
          ],
        ),
      ),
    );
  }

  void _showProductPicker(BuildContext context, List<ItemModel> products) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select Product'),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.add, color: AppTheme.primary, size: 20),
                ),
                title: const Text('New Product',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Add a new product to inventory'),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AddItemScreen(defaultCategory: 'product')));
                },
              ),
              if (products.isNotEmpty) const Divider(height: 1),
              ...products.map((p) => ListTile(
                title: Text(p.name),
                subtitle: Text('Stock: ${p.stockQty} ${p.primaryUnit}'),
                selected: _selectedProduct?.id == p.id,
                selectedTileColor: AppTheme.primary.withValues(alpha: 0.06),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  if (_selectedProduct?.id != p.id) {
                    setState(() {
                      _selectedProduct = p;
                      _selectedBom = null;
                      _bomChecked = false;
                    });
                    _loadBom(p);
                  }
                },
              )),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No products found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _loadBom(ItemModel product) async {
    setState(() {
      _bomLoading = true;
      _bomChecked = false;
    });
    final bom = await svc.getBomForProduct(product.id);
    if (mounted) {
      setState(() {
        _selectedBom = bom;
        _bomLoading = false;
        _bomChecked = true;
      });
    }
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
      final bom = _selectedBom ?? await svc.getBomForProduct(_selectedProduct!.id);
      if (bom == null) throw Exception('No BoM defined for ${_selectedProduct!.name}');

      await svc.manufacture(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        qty: qty,
        bom: bom,
        salePrice: _selectedProduct!.salePrice,
        date: _selectedDate,
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
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedProduct = null;
                    _selectedBom = null;
                    _bomChecked = false;
                    _qtyController.clear();
                    _selectedDate = DateTime.now();
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)));
      }
    } finally {
      setState(() => _loading = false);
    }
  }
}

// ── Production History ────────────────────────────────────────────

class _ProductionHistory extends StatelessWidget {
  final FirestoreService svc;
  const _ProductionHistory({required this.svc});

  Future<void> _editDate(BuildContext context, String id, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      try {
        await svc.updateManufactureDate(id, picked);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _confirmDelete(BuildContext context, String id, String name, double qty) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Production Record?'),
        content: Text(
          'This will reverse all stock changes for '
          '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} units of $name.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await svc.deleteManufactureRecord(id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5)));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yy, hh:mm a');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: svc.streamProductions(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                const Text('No production runs yet.',
                    style: TextStyle(color: Colors.grey)),
              ]),
            ),
          );
        }
        return Card(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(children: [
                Expanded(flex: 4, child: Text('Product',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text('Qty',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 3, child: Text('Cost (₹)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 3, child: Text('Value (₹)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                SizedBox(width: 32),
              ]),
            ),
            ...records.map((r) {
              final id = r['id'] as String? ?? '';
              final name = r['productName'] as String? ?? '';
              final qty = (r['qty'] as num?)?.toDouble() ?? 0;
              final totalCost = (r['totalCost'] as num?)?.toDouble() ?? 0;
              final totalValue = (r['totalValue'] as num?)?.toDouble() ?? 0;
              final date = r['date'] != null
                  ? DateTime.tryParse(r['date'] as String)
                  : null;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.grey.shade100))),
                child: Row(children: [
                  Expanded(flex: 4, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 12)),
                      if (date != null)
                        Text(df.format(date),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 10)),
                    ],
                  )),
                  Expanded(flex: 2, child: Text(
                    qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  )),
                  Expanded(flex: 3, child: Text(
                    cf.format(totalCost),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.payable),
                  )),
                  Expanded(flex: 3, child: Text(
                    cf.format(totalValue),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.receivable,
                        fontWeight: FontWeight.w500),
                  )),
                  SizedBox(
                    width: 32,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_calendar_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Edit Date'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editDate(ctx, id, date ?? DateTime.now());
                        } else if (value == 'delete') {
                          _confirmDelete(ctx, id, name, qty);
                        }
                      },
                    ),
                  ),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

// ── No-BoM state card ─────────────────────────────────────────────

class _NoBomCard extends StatelessWidget {
  final ItemModel product;
  final VoidCallback onAdd;
  const _NoBomCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No Bill of Materials for "${product.name}"',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.orange.shade800),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'A BoM defines the raw materials and costs needed to manufacture this product. '
            'You cannot start manufacturing without one.',
            style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Create BoM for this product'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade400),
              ),
              onPressed: onAdd,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── BoM detail card ───────────────────────────────────────────────

class _BomDetailCard extends StatelessWidget {
  final BomModel bom;
  final VoidCallback onEdit;
  const _BomDetailCard({required this.bom, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.view_in_ar, color: AppTheme.primary),
          ),
          title: const Text('Bill of Materials',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            'Cost / unit:  ₹${bom.totalCostPerUnit.toStringAsFixed(2)}',
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
            tooltip: 'Edit BoM',
            onPressed: onEdit,
          ),
        ),
        ExpansionTile(
          title: const Text('View Recipe',
              style: TextStyle(fontSize: 13, color: AppTheme.primary)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (bom.materials.isNotEmpty) ...[
                  const Text('Materials:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...bom.materials.map((m) => ListTile(
                    dense: true,
                    title: Text(m.materialName),
                    subtitle: Text(
                        '${m.qtyPerUnit} ${m.unit}  @  ₹${m.pricePerUnit}/${m.unit}'),
                    trailing: Text('₹${m.costPerUnit.toStringAsFixed(2)}'),
                  )),
                ],
                if (bom.otherCosts.isNotEmpty) ...[
                  const Divider(),
                  const Text('Other Costs:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...bom.otherCosts.map((c) => ListTile(
                    dense: true,
                    title: Text(c.type),
                    trailing:
                        Text('₹${c.costPerUnit.toStringAsFixed(2)} / ${c.unit}'),
                  )),
                ],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Cost / unit:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '₹${bom.totalCostPerUnit.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}
