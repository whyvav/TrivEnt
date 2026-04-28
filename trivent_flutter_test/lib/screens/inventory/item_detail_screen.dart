import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/item_model.dart';
import '../../models/stock_transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'add_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final ItemModel item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy, hh:mm a');
    final unitPrice = item.category == 'product' ? item.salePrice : item.purchasePrice;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(
                    builder: (_) => AddItemScreen(
                        defaultCategory: item.category, existing: item))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () async {
              final ok = await showDialog<bool>(
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
              if (ok == true) {
                await svc.deleteItem(item.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdjustStock(context, svc),
        icon: const Icon(Icons.tune),
        label: const Text('Adjust Stock'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Item info card
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (item.itemCode != null)
                    Text('Code: ${item.itemCode}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.category == 'product'
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : item.category == 'raw_material'
                            ? AppTheme.accent.withValues(alpha: 0.1)
                            : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.category == 'product' ? 'Product' : item.category == 'raw_material' ? 'Raw Material' : 'Other',
                    style: TextStyle(
                      color: item.category == 'product' ? AppTheme.primary : item.category == 'raw_material' ? AppTheme.accent : Colors.purple,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
              const Divider(height: 24),
              _Grid([
                _InfoCell('Stock', '${item.stockQty} ${item.primaryUnit}',
                    color: item.stockQty <= item.minStockAlert && item.minStockAlert > 0
                        ? AppTheme.payable : AppTheme.receivable),
                _InfoCell('${item.category == 'product' ? 'Sale' : 'Purchase'} Price',
                    cf.format(unitPrice)),
                _InfoCell('Stock Value', cf.format(item.stockQty * unitPrice),
                    bold: true),
                _InfoCell('Tax', '${item.taxPercent}%'),
                if (item.secondaryUnit != null)
                  _InfoCell('Unit Conv.',
                      '1 ${item.primaryUnit} = ${item.conversionFactor} ${item.secondaryUnit}'),
                if (item.minStockAlert > 0)
                  _InfoCell('Min Stock', '${item.minStockAlert} ${item.primaryUnit}'),
                if (item.hsn != null) _InfoCell('HSN', item.hsn!),
                if (item.itemLocation != null) _InfoCell('Location', item.itemLocation!),
                if (item.stockAsOfDate != null)
                  _InfoCell('Stock As Of', DateFormat('dd MMM yyyy').format(item.stockAsOfDate!)),
                if (item.stockAtPrice > 0)
                  _InfoCell('Avg. Buy Price', cf.format(item.stockAtPrice)),
              ]),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const Divider(height: 16),
                Align(alignment: Alignment.centerLeft,
                    child: Text(item.description!,
                        style: const TextStyle(color: Colors.grey, fontSize: 12))),
              ],
            ]),
          )),
          const SizedBox(height: 16),

          // Stock Transactions
          const Text('Stock Transactions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          StreamBuilder<List<StockTransactionModel>>(
            stream: svc.streamStockTransactions(item.id),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading transactions: ${snap.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final txList = snap.data ?? [];
              if (txList.isEmpty) {
                return Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    const Text('No transactions recorded yet.',
                        style: TextStyle(color: Colors.grey)),
                  ]),
                ));
              }
              return Card(
                child: Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                    child: Row(children: const [
                      Expanded(flex: 3, child: Text('Transaction',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Expanded(flex: 2, child: Text('Qty',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Expanded(flex: 2, child: Text('Value (₹)',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ]),
                  ),
                  ...txList.map((tx) {
                    final isIn = tx.quantity > 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                      child: Row(children: [
                        Expanded(flex: 3, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx.type,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                            Text(df.format(tx.date),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                            if (tx.referenceNo != null)
                              Text('Ref: ${tx.referenceNo}',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                            if (tx.notes != null)
                              Text(tx.notes!,
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                          ],
                        )),
                        Expanded(flex: 2, child: Text(
                          '${isIn ? '+' : ''}${tx.quantity.toStringAsFixed(2)} ${item.primaryUnit}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: isIn ? AppTheme.receivable : AppTheme.payable,
                              fontWeight: FontWeight.w500, fontSize: 12),
                        )),
                        Expanded(flex: 2, child: Text(
                          cf.format(tx.value.abs()),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        )),
                      ]),
                    );
                  }).toList(),
                ]),
              );
            },
          ),
          const SizedBox(height: 80), // Space for FAB
        ]),
      ),
    );
  }

  Future<void> _showAdjustStock(BuildContext context, FirestoreService svc) async {
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: item.stockAtPrice.toString());
    final notesCtrl = TextEditingController();
    DateTime adjDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Adjust Stock',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(
                controller: qtyCtrl,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: '+100 or -50',
                  helperText: 'Use negative to reduce',
                  suffixText: item.primaryUnit,
                ),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                    labelText: 'Price / Unit ₹', prefixText: '₹'),
                keyboardType: TextInputType.number,
              )),
            ]),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: adjDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) setS(() => adjDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Adjustment Date'),
                child: Text(DateFormat('dd MMM yyyy').format(adjDate)),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Adjustment Details (optional)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final qty = double.tryParse(qtyCtrl.text);
                  if (qty == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid quantity')));
                    return;
                  }
                  try {
                    await svc.adjustStock(
                      itemId: item.id, itemName: item.name,
                      quantityChange: qty,
                      pricePerUnit: double.tryParse(priceCtrl.text) ?? 0,
                      date: adjDate,
                      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stock adjusted!'),
                            backgroundColor: Colors.green));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Add / Reduce Stock'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<_InfoCell> cells;
  const _Grid(this.cells);
  @override Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: cells.map((c) => SizedBox(
      width: 140,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(c.value, style: TextStyle(
            fontSize: 13, fontWeight: c.bold ? FontWeight.bold : FontWeight.w500,
            color: c.color)),
      ]),
    )).toList(),
  );
}

class _InfoCell {
  final String label, value;
  final Color color;
  final bool bold;
  const _InfoCell(this.label, this.value,
      {this.color = Colors.black87, this.bold = false});
}