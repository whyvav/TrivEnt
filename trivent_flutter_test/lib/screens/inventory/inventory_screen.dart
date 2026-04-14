import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../theme.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart';

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
        onPressed: () {
          // Pass the current tab so the form defaults to correct category
          final category = _tabController.index == 0 ? 'product' : 'raw_material';
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddItemScreen(defaultCategory: category)));
        },
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
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
              Text('No ${category == 'product' ? 'products' : 'raw materials'} yet.',
                  style: TextStyle(color: Colors.grey.shade500)),
            ]),
          );
        }

        // Grand total
        final grandTotal = items.fold<double>(0, (s, i) {
          final price = category == 'product' ? i.salePrice : i.purchasePrice;
          return s + (i.stockQty * price);
        });

        return Column(
          children: [
            // Table header
            Container(
              color: AppTheme.primary.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Value', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final unitPrice = category == 'product' ? item.salePrice : item.purchasePrice;
                  final stockValue = item.stockQty * unitPrice;
                  final isLow = item.minStockAlert > 0 && item.stockQty <= item.minStockAlert;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                      color: isLow ? Colors.red.shade50 : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (isLow)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: AppTheme.payable, borderRadius: BorderRadius.circular(3)),
                              child: const Text('LOW STOCK',
                                  style: TextStyle(color: Colors.white, fontSize: 9)),
                            ),
                        ]),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${item.stockQty} ${item.unit}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: isLow ? AppTheme.payable : Colors.black87)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(cf.format(unitPrice),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.black54)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(cf.format(stockValue),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 48,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (val) async {
                            if (val == 'edit') {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => EditItemScreen(item: item)));
                            } else if (val == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Item?'),
                                  content: Text('Delete "${item.name}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) await svc.deleteItem(item.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Row(children: [
                              Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit')])),
                            PopupMenuItem(value: 'delete', child: Row(children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                          ],
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
            // Grand total footer
            Container(
              color: AppTheme.primary.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Expanded(flex: 3, child: Text('Total Stock Value',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                const Spacer(flex: 4),
                Expanded(
                  flex: 2,
                  child: Text(cf.format(grandTotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 15)),
                ),
                const SizedBox(width: 48),
              ]),
            ),
          ],
        );
      },
    );
  }
}