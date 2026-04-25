import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/purchase_model.dart';
import '../../theme.dart';
import 'add_purchase_screen.dart';
import 'purchase_detail_screen.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPurchaseScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PurchaseModel>>(
        stream: svc.streamPurchases(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final purchases = snap.data ?? [];
          if (purchases.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No purchases yet. Tap + to add your first bill.'),
            ]));
          }
          final total = purchases.fold(0.0, (s, p) => s + p.totalAmount);
          final paid = purchases.fold(0.0, (s, p) => s + p.amountPaid);
          return Column(children: [
            Container(
              color: AppTheme.primary,
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat('Total Bills', cf.format(total), Colors.white),
                _Stat('Paid', cf.format(paid), Colors.greenAccent.shade100),
                _Stat('Outstanding', cf.format(total - paid), Colors.orangeAccent),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: purchases.length,
                itemBuilder: (ctx, i) {
                  final p = purchases[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: p))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: p.isPaid
                                ? AppTheme.receivable.withOpacity(0.1)
                                : AppTheme.payable.withOpacity(0.1),
                            child: Icon(p.isPaid ? Icons.check : Icons.pending,
                                color: p.isPaid ? AppTheme.receivable : AppTheme.payable,
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.partyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${p.billNo}  •  ${df.format(p.date)}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(cf.format(p.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (p.balanceDue > 0.01)
                              Text('Due: ${cf.format(p.balanceDue)}',
                                  style: const TextStyle(color: AppTheme.payable, fontSize: 11))
                            else
                              const Text('Paid',
                                  style: TextStyle(color: AppTheme.receivable, fontSize: 11)),
                          ]),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AddPurchaseScreen(existing: p)));
                              } else if (val == 'delete') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Purchase?'),
                                    content: Text('Delete ${p.billNo}? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (ok == true) await svc.deletePurchase(p.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Row(children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8), Text('Edit')])),
                              PopupMenuItem(value: 'delete', child: Row(children: [
                                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
  ]);
}
