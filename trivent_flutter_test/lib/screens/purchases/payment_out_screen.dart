import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/payment_out_model.dart';
import '../../theme.dart';
import 'add_payment_out_screen.dart';
import 'payment_out_detail_screen.dart';

class PaymentOutScreen extends StatelessWidget {
  const PaymentOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Out')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPaymentOutScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Payment'),
        backgroundColor: AppTheme.payable,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PaymentOutModel>>(
        stream: svc.streamPaymentOuts(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snap.data ?? [];
          if (payments.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.outbox_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No payments made yet. Tap + to record one.'),
              ]),
            );
          }
          final total = payments.fold(0.0, (s, p) => s + p.amount);
          return Column(children: [
            Container(
              color: AppTheme.payable,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Paid Out',
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
                          MaterialPageRoute(builder: (_) => PaymentOutDetailScreen(payment: p))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.payable.withValues(alpha: 0.1),
                            child: const Icon(Icons.outbox,
                                color: AppTheme.payable, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.partyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${p.paymentNo}  •  ${df.format(p.date)}',
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
                                    color: AppTheme.payable)),
                            const Text('Paid',
                                style: TextStyle(color: AppTheme.payable, fontSize: 11)),
                          ]),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AddPaymentOutScreen(existing: p)));
                              } else if (val == 'delete') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Payment?'),
                                    content: Text('Delete ${p.paymentNo}? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (ok == true) await svc.deletePaymentOut(p.id);
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
