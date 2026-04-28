import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/item_model.dart';
import '../../theme.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final svc = FirestoreService();
  String _searchQuery = '';
  int _sortColumn = 0; // 0=name, 1=stock, 2=price, 3=value
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Products'), Tab(text: 'Raw Materials'), Tab(text: 'Other')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final cat = _tab.index == 0 ? 'product' : _tab.index == 1 ? 'raw_material' : 'other';
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddItemScreen(defaultCategory: cat)));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or item code...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ItemList(category: 'product', svc: svc,
                    search: _searchQuery, sortCol: _sortColumn,
                    sortAsc: _sortAsc,
                    onSort: (col) => setState(() {
                      if (_sortColumn == col) _sortAsc = !_sortAsc;
                      else { _sortColumn = col; _sortAsc = true; }
                    })),
                _ItemList(category: 'raw_material', svc: svc,
                    search: _searchQuery, sortCol: _sortColumn,
                    sortAsc: _sortAsc,
                    onSort: (col) => setState(() {
                      if (_sortColumn == col) _sortAsc = !_sortAsc;
                      else { _sortColumn = col; _sortAsc = true; }
                    })),
                _ItemList(category: 'other', svc: svc,
                    search: _searchQuery, sortCol: _sortColumn,
                    sortAsc: _sortAsc,
                    onSort: (col) => setState(() {
                      if (_sortColumn == col) _sortAsc = !_sortAsc;
                      else { _sortColumn = col; _sortAsc = true; }
                    })),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final String category;
  final FirestoreService svc;
  final String search;
  final int sortCol;
  final bool sortAsc;
  final void Function(int) onSort;
  const _ItemList({required this.category, required this.svc,
      required this.search, required this.sortCol,
      required this.sortAsc, required this.onSort});

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return StreamBuilder<List<ItemModel>>(
      stream: svc.streamItems(category: category),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var items = snap.data ?? [];

        // Filter
        if (search.isNotEmpty) {
          items = items.where((i) =>
            i.name.toLowerCase().contains(search) ||
            (i.itemCode?.toLowerCase().contains(search) ?? false)).toList();
        }

        // Sort
        items.sort((a, b) {
          final aPrice = category == 'product' ? a.salePrice : a.purchasePrice;
          final bPrice = category == 'product' ? b.salePrice : b.purchasePrice;
          dynamic aVal, bVal;
          switch (sortCol) {
            case 0: aVal = a.name.toLowerCase(); bVal = b.name.toLowerCase(); break;
            case 1: aVal = a.stockQty; bVal = b.stockQty; break;
            case 2: aVal = aPrice; bVal = bPrice; break;
            case 3: aVal = a.stockQty * aPrice; bVal = b.stockQty * bPrice; break;
          }
          final cmp = (aVal as Comparable).compareTo(bVal);
          return sortAsc ? cmp : -cmp;
        });

        if (items.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(search.isNotEmpty ? 'No items match your search.' : 'No items yet.',
                style: TextStyle(color: Colors.grey.shade500)),
          ]));
        }

        final grandTotal = items.fold<double>(0, (s, i) {
          final price = category == 'product' ? i.salePrice : i.purchasePrice;
          return s + (i.stockQty * price);
        });

        Widget sortIcon(int col) => Icon(
          sortCol == col
              ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
              : Icons.unfold_more,
          size: 14,
          color: sortCol == col ? AppTheme.primary : Colors.grey,
        );

        return Column(children: [
          // Column headers
          Container(
            color: AppTheme.primary.withOpacity(0.07),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: GestureDetector(onTap: () => onSort(0),
                child: Row(children: [
                  const Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  sortIcon(0),
                ]))),
              Expanded(flex: 2, child: GestureDetector(onTap: () => onSort(1),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  sortIcon(1),
                ]))),
              Expanded(flex: 2, child: GestureDetector(onTap: () => onSort(2),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  sortIcon(2),
                ]))),
              Expanded(flex: 2, child: GestureDetector(onTap: () => onSort(3),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  sortIcon(3),
                ]))),
              const SizedBox(width: 36),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final price = category == 'product' ? item.salePrice : item.purchasePrice;
                final value = item.stockQty * price;
                final isLow = item.minStockAlert > 0 && item.stockQty <= item.minStockAlert;
                return InkWell(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                      color: isLow ? Colors.red.shade50 : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          if (item.itemCode != null)
                            Text(item.itemCode!,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                          if (isLow)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: AppTheme.payable,
                                  borderRadius: BorderRadius.circular(3)),
                              child: const Text('LOW STOCK',
                                  style: TextStyle(color: Colors.white, fontSize: 8)),
                            ),
                        ],
                      )),
                      Expanded(flex: 2, child: Text(
                        '${item.stockQty.toStringAsFixed(item.stockQty.truncateToDouble() == item.stockQty ? 0 : 2)} ${item.primaryUnit}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: isLow ? AppTheme.payable : Colors.black87, fontSize: 12),
                      )),
                      Expanded(flex: 2, child: Text(cf.format(price),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.black54, fontSize: 12))),
                      Expanded(flex: 2, child: Text(cf.format(value),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      SizedBox(width: 36,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16),
                          onSelected: (val) {
                            if (val == 'detail') {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'detail',
                                child: Row(children: [
                                  Icon(Icons.open_in_new, size: 15),
                                  SizedBox(width: 8),
                                  Text('Details')])),
                          ],
                        )),
                    ]),
                  ),
                );
              },
            ),
          ),
          // Footer: total stock value — centered to avoid FAB overlap
          Container(
            color: AppTheme.primary.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            child: Text(
              'Stock Value:  ${cf.format(grandTotal)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 15),
            ),
          ),
        ]);
      },
    );
  }
}