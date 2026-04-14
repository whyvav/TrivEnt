import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/purchase_model.dart';
import '../../theme.dart';
import 'add_purchase_screen.dart';

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
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No purchases yet.'),
              ]),
            );
          }
          final total = purchases.fold(0.0, (s, p) => s + p.totalAmount);
          final paid = purchases.fold(0.0, (s, p) => s + p.amountPaid);
          return Column(children: [
            Container(
              color: AppTheme.payable.withOpacity(0.1),
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat('Total Bills', cf.format(total), Colors.black87),
                _Stat('Paid', cf.format(paid), AppTheme.receivable),
                _Stat('Outstanding', cf.format(total - paid), AppTheme.payable),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: purchases.length,
                itemBuilder: (ctx, i) {
                  final p = purchases[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p.isPaid
                            ? AppTheme.receivable.withOpacity(0.1)
                            : AppTheme.payable.withOpacity(0.1),
                        child: Icon(p.isPaid ? Icons.check : Icons.pending,
                            color: p.isPaid ? AppTheme.receivable : AppTheme.payable),
                      ),
                      title: Text(p.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p.billNo}  •  ${df.format(p.date)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(cf.format(p.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (!p.isPaid)
                            Text('Due: ${cf.format(p.balanceDue)}',
                                style: const TextStyle(color: AppTheme.payable, fontSize: 11)),
                        ],
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
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
  ]);
}