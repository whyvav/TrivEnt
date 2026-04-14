import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/expense_model.dart';
import '../../theme.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM');

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: svc.streamExpenses(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snap.data ?? [];
          if (expenses.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No expenses recorded.'),
              ]),
            );
          }

          // Category totals
          final byCategory = <String, double>{};
          for (final e in expenses) {
            byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
          }
          final grandTotal = expenses.fold(0.0, (s, e) => s + e.amount);

          return Column(children: [
            // Category summary chips
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip('All', cf.format(grandTotal), Colors.grey.shade700),
                  ...byCategory.entries.map((e) =>
                      _CategoryChip(e.key, cf.format(e.value), AppTheme.payable)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: expenses.length,
                itemBuilder: (ctx, i) {
                  final e = expenses[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.payable.withOpacity(0.1),
                        child: Text(e.category[0],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: AppTheme.payable)),
                      ),
                      title: Text(e.description,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${e.category}  •  ${df.format(e.date)}  •  ${e.paymentType}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cf.format(e.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: AppTheme.payable)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Expense?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (ok == true) await svc.deleteExpense(e.id);
                          },
                        ),
                      ]),
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

class _CategoryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CategoryChip(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8, top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 10, color: color)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}