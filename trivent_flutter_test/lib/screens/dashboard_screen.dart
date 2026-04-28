import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import '../../services/company_service.dart';
import '../../models/sale_model.dart';
import '../../models/purchase_model.dart';
import '../../models/payment_in_model.dart';
import '../../models/payment_out_model.dart';
import 'package:trivent_flutter_test/screens/inventory/add_item_screen.dart';
import 'package:trivent_flutter_test/screens/sales/add_sale_screen.dart';
import 'package:trivent_flutter_test/screens/sales/sale_detail_screen.dart';
import 'package:trivent_flutter_test/screens/sales/payment_in_detail_screen.dart';
import 'package:trivent_flutter_test/screens/purchases/add_purchase_screen.dart';
import 'package:trivent_flutter_test/screens/purchases/purchase_detail_screen.dart';
import 'package:trivent_flutter_test/screens/purchases/payment_out_detail_screen.dart';
import 'package:trivent_flutter_test/screens/manufacturing/manufacture_screen.dart';
import 'package:trivent_flutter_test/screens/parties/add_party_screen.dart';


class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: svc.getDashboardStats(),
        builder: (context, snap) {
          final stats = snap.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    context.watch<CompanyService>().activeCompany?.name ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: AppTheme.primary)),
                Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 20),

                // Summary cards row
                LayoutBuilder(builder: (ctx, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  final cards = [
                    _SummaryCard('Total Sales', cf.format(stats['totalSales'] ?? 0),
                        Icons.trending_up, AppTheme.primary),
                    _SummaryCard('Received', cf.format(stats['totalReceived'] ?? 0),
                        Icons.check_circle_outline, AppTheme.receivable),
                    _SummaryCard('Balance Due', cf.format(stats['totalBalance'] ?? 0),
                        Icons.hourglass_empty, AppTheme.payable),
                    _SummaryCard('This Month Profit',
                        cf.format(stats['monthlyProfit'] ?? 0),
                        Icons.insights,
                        (stats['monthlyProfit'] ?? 0) >= 0
                            ? AppTheme.receivable
                            : AppTheme.payable),
                  ];
                  return isNarrow
                      ? GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.6,
                          children: cards,
                        )
                      : Row(
                          children: cards
                              .map((c) => Expanded(child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: c,
                                  )))
                              .toList(),
                        );
                }),

                const SizedBox(height: 24),

                // Quick actions
                Text('Quick Actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _QuickActionButton(
                    label: 'Sale',
                    icon: Icons.add_shopping_cart,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddSaleScreen())),
                  ),
                  _QuickActionButton(
                  label: 'Purchase',
                  icon: Icons.shopping_basket_outlined,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddPurchaseScreen())),
                  ),
                  _QuickActionButton(
                    label: 'Manufacture',
                    icon: Icons.precision_manufacturing,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ManufactureScreen())),
                  ),
                  _QuickActionButton(
                    label: 'Add Item',
                    icon: Icons.add_box_outlined,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddItemScreen())),
                  ),
                  _QuickActionButton(
                    label: 'Add Party',
                    icon: Icons.people_outline,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddPartyScreen())),
                  ),
                ]),

                const SizedBox(height: 24),

                // Monthly chart
                Text('This Month — Sales vs Expenses',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, List<double>>>(
                  future: svc.getMonthlyChartData(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()));
                    }
                    final sales = snap.data!['sales']!;
                    final expenses = snap.data!['expenses']!;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _LegendDot(AppTheme.receivable, 'Sales'),
                            SizedBox(width: 16),
                            _LegendDot(AppTheme.payable, 'Expenses'),
                          ]),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 160,
                            child: LineChart(LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 7,
                                    getTitlesWidget: (v, _) =>
                                        Text('${v.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                _lineBar(sales, AppTheme.receivable),
                                _lineBar(expenses, AppTheme.payable),
                              ],
                            )),
                          ),
                        ]),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Low stock
                Text('Low Stock Alerts',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: svc.streamItems(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final low = snap.data!
                        .where((i) => i.minStockAlert > 0 && i.stockQty <= i.minStockAlert)
                        .toList();
                    if (low.isEmpty) {
                      return const Card(
                        child: ListTile(
                          leading: Icon(Icons.check_circle, color: AppTheme.receivable),
                          title: Text('All stocks adequate'),
                        ),
                      );
                    }
                    return Column(
                      children: low
                          .map((item) => Card(
                                color: Colors.red.shade50,
                                child: ListTile(
                                  leading: const Icon(Icons.warning_amber, color: AppTheme.payable),
                                  title: Text(item.name),
                                  subtitle: Text('${item.stockQty} ${item.primaryUnit} remaining'),
                                  trailing: Text('Min: ${item.minStockAlert}',
                                      style: const TextStyle(color: AppTheme.payable)),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),
                Text('Recent Transactions',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: svc.getAllTransactions(limit: 30),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const SizedBox(height: 60,
                        child: Center(child: CircularProgressIndicator()));
                    final txs = snap.data!;
                    if (txs.isEmpty) return Card(child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: const Text('No transactions yet.', style: TextStyle(color: Colors.grey))));

                    return Card(
                      child: Column(
                        children: txs.map((tx) {
                          final type = tx['type'] as String;
                          final Color typeColor = switch (type) {
                            'Sale' || 'PaymentIn' => AppTheme.receivable,
                            'Expense' => Colors.orange,
                            _ => AppTheme.payable,
                          };
                          final String badge = switch (type) {
                            'Sale' => 'S',
                            'Purchase' => 'P',
                            'PaymentIn' => 'PI',
                            'PaymentOut' => 'PO',
                            _ => 'E',
                          };
                          final model = tx['model'];
                          return InkWell(
                            onTap: model == null ? null : () {
                              if (model is SaleModel) {
                                Navigator.push(ctx, MaterialPageRoute(
                                    builder: (_) => SaleDetailScreen(sale: model)));
                              } else if (model is PurchaseModel) {
                                Navigator.push(ctx, MaterialPageRoute(
                                    builder: (_) => PurchaseDetailScreen(purchase: model)));
                              } else if (model is PaymentInModel) {
                                Navigator.push(ctx, MaterialPageRoute(
                                    builder: (_) => PaymentInDetailScreen(payment: model)));
                              } else if (model is PaymentOutModel) {
                                Navigator.push(ctx, MaterialPageRoute(
                                    builder: (_) => PaymentOutDetailScreen(payment: model)));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                              child: Row(children: [
                                Container(
                                  width: 48,
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(badge,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: typeColor, fontSize: 12)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(tx['party'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    '${tx['ref']} · ${DateFormat('dd MMM').format(tx['date'] as DateTime)}',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                ])),
                                () {
                                  final cf0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
                                  final amt = tx['amount'] as double;
                                  if (type == 'Sale' || type == 'Purchase') {
                                    final isPaid = tx['isPaid'] as bool;
                                    final due = amt - (tx['paid'] as double);
                                    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text(cf0.format(amt),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: typeColor)),
                                      Text('Due: ${cf0.format(due)}',
                                          style: TextStyle(
                                              color: isPaid ? AppTheme.receivable : AppTheme.payable,
                                              fontSize: 11)),
                                    ]);
                                  } else {
                                    final bal = (tx['partyBalance'] as double?) ?? 0.0;
                                    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text(cf0.format(amt),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: typeColor)),
                                      Text('Bal: ${cf0.format(bal)}',
                                          style: TextStyle(
                                              color: bal > 0.01 ? AppTheme.payable : AppTheme.receivable,
                                              fontSize: 11)),
                                    ]);
                                  }
                                }(),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  LineChartBarData _lineBar(List<double> data, Color color) => LineChartBarData(
        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.08),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final String title, amount;
  final IconData icon;
  final Color color;
  const _SummaryCard(this.title, this.amount, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            const SizedBox(height: 2),
            Text(amount,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          ]),
        ),
      );
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}