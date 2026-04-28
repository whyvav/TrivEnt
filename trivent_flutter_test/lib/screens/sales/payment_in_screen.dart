import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/payment_in_model.dart';
import '../../theme.dart';
import 'add_payment_in_screen.dart';
import 'payment_in_detail_screen.dart';

class PaymentInScreen extends StatelessWidget {
  const PaymentInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Payment In')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPaymentInScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Receipt'),
        backgroundColor: AppTheme.receivable,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PaymentInModel>>(
        stream: svc.streamPaymentIns(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snap.data ?? [];
          if (payments.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.move_to_inbox_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No payment receipts yet. Tap + to record one.'),
              ]),
            );
          }
          final total = payments.fold(0.0, (s, p) => s + p.amount);
          return Column(children: [
            Container(
              color: AppTheme.receivable,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Received',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(cf.format(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: payments.length,
                itemBuilder: (ctx, i) {
                  final p = payments[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => PaymentInDetailScreen(payment: p))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.receivable.withValues(alpha: 0.1),
                            child: const Icon(Icons.move_to_inbox,
                                color: AppTheme.receivable, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.partyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${p.receiptNo}  •  ${df.format(p.date)}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              if (p.paymentType != 'Cash')
                                Text(p.paymentType,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(cf.format(p.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.receivable)),
                            const Text('Received',
                                style: TextStyle(color: AppTheme.receivable, fontSize: 11)),
                          ]),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AddPaymentInScreen(existing: p)));
                              } else if (val == 'delete') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Receipt?'),
                                    content: Text('Delete ${p.receiptNo}? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (ok == true) await svc.deletePaymentIn(p.id);
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
