import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/sale_model.dart';
import '../../theme.dart';
import 'add_sale_screen.dart';
import 'sale_detail_screen.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddSaleScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SaleModel>>(
        stream: svc.streamSales(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sales = snap.data ?? [];
          if (sales.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No sales yet. Tap + to add your first invoice.'),
            ]));
          }
          final total = sales.fold(0.0, (s, e) => s + e.totalAmount);
          final received = sales.fold(0.0, (s, e) => s + e.amountPaid);
          return Column(children: [
            Container(
              color: AppTheme.primary,
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat('Total', cf.format(total), Colors.white),
                _Stat('Received', cf.format(received), Colors.greenAccent.shade100),
                _Stat('Balance', cf.format(total - received), Colors.orangeAccent),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sales.length,
                itemBuilder: (ctx, i) {
                  final s = sales[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: s))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: s.isPaid
                                ? AppTheme.receivable.withOpacity(0.1)
                                : AppTheme.payable.withOpacity(0.1),
                            child: Icon(s.isPaid ? Icons.check : Icons.pending,
                                color: s.isPaid ? AppTheme.receivable : AppTheme.payable,
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.partyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${s.invoiceNo}  •  ${df.format(s.date)}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(cf.format(s.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (s.balanceDue > 0.01)
                              Text('Due: ${cf.format(s.balanceDue)}',
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
                                    builder: (_) => AddSaleScreen(existing: s)));
                              } else if (val == 'delete') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Sale?'),
                                    content: Text('Delete ${s.invoiceNo}? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (ok == true) await svc.deleteSale(s.id);
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