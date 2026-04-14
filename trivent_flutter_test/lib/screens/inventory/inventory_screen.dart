import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../theme.dart';
import 'add_item_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final svc = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Products'), Tab(text: 'Raw Materials')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddItemScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ItemList(category: 'product', svc: svc),
          _ItemList(category: 'raw_material', svc: svc),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final String category;
  final FirestoreService svc;
  const _ItemList({required this.category, required this.svc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemModel>>(
      stream: svc.streamItems(category: category),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No items yet. Tap + to add.',
                  style: TextStyle(color: Colors.grey.shade500)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final isLow = item.minStockAlert > 0 && item.stockQty <= item.minStockAlert;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLow
                      ? AppTheme.payable.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
                  child: Icon(
                    category == 'product' ? Icons.view_in_ar : Icons.category,
                    color: isLow ? AppTheme.payable : AppTheme.primary,
                  ),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Stock: ${item.stockQty} ${item.unit}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${item.salePrice}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.payable,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LOW', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                  ],
                ),
                onTap: () {
                  // Show item detail dialog
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(item.name),
                      content: Column(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailRow('Category', item.category),
                          _DetailRow('Unit', item.unit),
                          _DetailRow('Stock Qty', '${item.stockQty}'),
                          _DetailRow('Sale Price', '₹${item.salePrice}'),
                          _DetailRow('Purchase Price', '₹${item.purchasePrice}'),
                          _DetailRow('Min Stock Alert', '${item.minStockAlert}'),
                          if (item.hsn != null) _DetailRow('HSN', item.hsn!),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await svc.deleteItem(item.id);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 140, child: Text('$label:', style: const TextStyle(color: Colors.grey))),
        Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }
}