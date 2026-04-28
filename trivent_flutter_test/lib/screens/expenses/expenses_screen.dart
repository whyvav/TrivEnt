import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/expense_model.dart';
import '../../theme.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  // Extract "Product Name" from "Manufacturing: Product Name × qty — type"
  static String _batchProductName(List<ExpenseModel> expenses) {
    for (final e in expenses) {
      const prefix = 'Manufacturing: ';
      if (e.description.startsWith(prefix)) {
        final rest = e.description.substring(prefix.length);
        final xIdx = rest.indexOf(' × ');
        if (xIdx > 0) return rest.substring(0, xIdx);
      }
    }
    return 'Batch';
  }

  // Extract "qty" from the description
  static String? _batchQty(List<ExpenseModel> expenses) {
    for (final e in expenses) {
      final xIdx = e.description.indexOf(' × ');
      final dashIdx = e.description.indexOf(' — ');
      if (xIdx >= 0 && dashIdx > xIdx) {
        return e.description.substring(xIdx + 3, dashIdx);
      }
    }
    return null;
  }

  // Extract cost label ("Labor", "Materials Used", etc.) from description suffix
  static String _costLabel(ExpenseModel e) {
    if (e.isCogs) return 'Materials Used';
    final idx = e.description.lastIndexOf(' — ');
    if (idx >= 0) return e.description.substring(idx + 3);
    return e.category;
  }

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

          // Summary totals
          final byCategory = <String, double>{};
          double cashTotal = 0;
          double cogsTotal = 0;
          for (final e in expenses) {
            byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
            if (e.isCogs) {
              cogsTotal += e.amount;
            } else {
              cashTotal += e.amount;
            }
          }

          // Group manufacturing expenses by production batch (referenceId)
          final Map<String, List<ExpenseModel>> mfgGroups = {};
          final List<ExpenseModel> individualExpenses = [];
          for (final e in expenses) {
            if (e.source == 'manufacturing' && e.referenceId != null) {
              mfgGroups.putIfAbsent(e.referenceId!, () => []).add(e);
            } else {
              individualExpenses.add(e);
            }
          }

          // Build unified display list sorted by date descending
          final List<_DisplayItem> items = [];
          for (final entry in mfgGroups.entries) {
            final batchExpenses = entry.value;
            items.add(_BatchItem(
              referenceId: entry.key,
              expenses: batchExpenses,
              total: batchExpenses.fold(0.0, (s, e) => s + e.amount),
              date: batchExpenses.first.date,
            ));
          }
          for (final e in individualExpenses) {
            items.add(_SingleItem(e));
          }
          items.sort((a, b) => b.date.compareTo(a.date));

          return Column(children: [
            // Summary chips
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip('Cash Total', cf.format(cashTotal), Colors.grey.shade700),
                  if (cogsTotal > 0)
                    _CategoryChip('Materials (COGS)', cf.format(cogsTotal),
                        Colors.brown.shade400),
                  ...byCategory.entries
                      .where((e) => e.key != 'Raw Materials (COGS)')
                      .map((e) => _CategoryChip(e.key, cf.format(e.value), AppTheme.payable)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];

                  // ── Manufacturing batch group card ──────────────────
                  if (item is _BatchItem) {
                    final productName = _batchProductName(item.expenses);
                    final qty = _batchQty(item.expenses);
                    final cogsItem = item.expenses.firstWhere(
                        (e) => e.isCogs, orElse: () => item.expenses.first);
                    final otherItems = item.expenses.where((e) => !e.isCogs).toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: Colors.deepPurple.shade50,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.deepPurple.shade100,
                          child: Icon(
                            Icons.precision_manufacturing_outlined,
                            size: 18,
                            color: Colors.deepPurple.shade600,
                          ),
                        ),
                        title: Row(children: [
                          Expanded(
                            child: Text(productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          _BatchBadge(qty: qty),
                        ]),
                        subtitle: Text(df.format(item.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(cf.format(item.total),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.deepPurple.shade700)),
                            Text('tap to expand',
                                style: TextStyle(
                                    fontSize: 9, color: Colors.grey.shade500)),
                          ],
                        ),
                        childrenPadding: EdgeInsets.zero,
                        children: [
                          const Divider(height: 1),
                          // COGS line
                          if (item.expenses.any((e) => e.isCogs))
                            _BatchLineItem(
                              label: _costLabel(cogsItem),
                              amount: cogsItem.amount,
                              color: Colors.brown.shade600,
                              cf: cf,
                            ),
                          // Other cost lines
                          ...otherItems.map((e) => _BatchLineItem(
                                label: _costLabel(e),
                                amount: e.amount,
                                color: Colors.deepPurple.shade700,
                                cf: cf,
                              )),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  }

                  // ── Individual expense card ─────────────────────────
                  final e = (item as _SingleItem).expense;
                  final isAuto = e.isAutoGenerated;
                  final isWage = e.source == 'wages';
                  final avatarColor = isWage ? Colors.blue.shade600 : AppTheme.payable;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: avatarColor.withValues(alpha: 0.12),
                        child: Text(e.category[0],
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: avatarColor)),
                      ),
                      title: Row(children: [
                        Expanded(
                          child: Text(e.description,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (isAuto) ...[
                          const SizedBox(width: 6),
                          _AutoBadge(isWage: isWage),
                        ],
                      ]),
                      subtitle: Text([
                        e.category,
                        df.format(e.date),
                        if (e.paymentType.isNotEmpty) e.paymentType,
                      ].join('  •  ')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cf.format(e.amount),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: avatarColor)),
                        if (!isAuto)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Expense?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete',
                                            style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok == true) await svc.deleteExpense(e.id);
                            },
                          )
                        else
                          const SizedBox(width: 40),
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

// ── Display item types ────────────────────────────────────────────────

abstract class _DisplayItem {
  DateTime get date;
}

class _BatchItem extends _DisplayItem {
  final String referenceId;
  final List<ExpenseModel> expenses;
  final double total;
  @override final DateTime date;
  _BatchItem({
    required this.referenceId,
    required this.expenses,
    required this.total,
    required this.date,
  });
}

class _SingleItem extends _DisplayItem {
  final ExpenseModel expense;
  _SingleItem(this.expense);
  @override DateTime get date => expense.date;
}

// ── Batch expansion line item ─────────────────────────────────────────

class _BatchLineItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat cf;
  const _BatchLineItem(
      {required this.label,
      required this.amount,
      required this.color,
      required this.cf});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Text(cf.format(amount),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// ── Batch qty badge ───────────────────────────────────────────────────

class _BatchBadge extends StatelessWidget {
  final String? qty;
  const _BatchBadge({this.qty});

  @override
  Widget build(BuildContext context) {
    if (qty == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('× $qty',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700)),
    );
  }
}

// ── Auto-generated badge (wages only now) ────────────────────────────

class _AutoBadge extends StatelessWidget {
  final bool isWage;
  const _AutoBadge({required this.isWage});

  @override
  Widget build(BuildContext context) {
    final color = isWage ? Colors.blue.shade600 : AppTheme.primary;
    final label = isWage ? 'WAGE' : 'AUTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CategoryChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 8, top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}
