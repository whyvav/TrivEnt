import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Text('Profit & Loss', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: svc.getDashboardStats(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final s = snap.data!;
              return Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _PnLRow('Total Sales', s['totalSales'] ?? 0, cf, isPositive: true),
                  _PnLRow('Monthly Expenses', s['monthlyExpenses'] ?? 0, cf, isPositive: false),
                  const Divider(),
                  _PnLRow('Monthly Profit', s['monthlyProfit'] ?? 0, cf,
                      isPositive: (s['monthlyProfit'] ?? 0) >= 0, bold: true),
                ]),
              ));
            },
          ),

          const SizedBox(height: 24),
          Text('Stock Summary', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: svc.streamItems(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final items = snap.data!;
              final products = items.where((i) => i.category == 'product').toList();
              final materials = items.where((i) => i.category == 'raw_material').toList();
              final productValue = products.fold(0.0, (s, i) => s + i.stockQty * i.salePrice);
              final materialValue = materials.fold(0.0, (s, i) => s + i.stockQty * i.purchasePrice);
              return Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _PnLRow('Finished Goods Value', productValue, cf, isPositive: true),
                  _PnLRow('Raw Materials Value', materialValue, cf, isPositive: false),
                  const Divider(),
                  _PnLRow('Total Inventory Value', productValue + materialValue, cf,
                      isPositive: true, bold: true),
                ]),
              ));
            },
          ),

          const SizedBox(height: 24),
          Text('Expense Breakdown', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: svc.streamExpenses(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final expenses = snap.data!;
              final byCategory = <String, double>{};
              for (final e in expenses) {
                byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
              }
              return Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: byCategory.entries
                      .map((e) => _PnLRow(e.key, e.value, cf, isPositive: false))
                      .toList(),
                ),
              ));
            },
          ),
        ]),
      ),
    );
  }
}

class _PnLRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat cf;
  final bool isPositive;
  final bool bold;
  const _PnLRow(this.label, this.value, this.cf, {required this.isPositive, this.bold = false});

  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(cf.format(value), style: TextStyle(
        color: isPositive ? AppTheme.receivable : AppTheme.payable,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
    ]),
  );
}