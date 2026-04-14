import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'package:trivent_flutter_test/screens/inventory/inventory_screen.dart';
import 'package:trivent_flutter_test/screens/inventory/add_item_screen.dart';
import 'package:trivent_flutter_test/screens/sales/add_sale_screen.dart';
import 'package:trivent_flutter_test/screens/manufacturing/manufacture_screen.dart';
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
                Text('Triveni Enterprises',
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

                // Quick actions — WORKING NOW
                Text('Quick Actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _QuickActionButton(
                    label: 'New Sale',
                    icon: Icons.add_shopping_cart,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddSaleScreen())),
                  ),
                  _QuickActionButton(
                    label: 'Add Item',
                    icon: Icons.add_box_outlined,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddItemScreen())),
                  ),
                  _QuickActionButton(
                    label: 'Manufacture',
                    icon: Icons.precision_manufacturing,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ManufactureScreen())),
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
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _LegendDot(AppTheme.receivable, 'Sales'),
                            const SizedBox(width: 16),
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
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.check_circle, color: AppTheme.receivable),
                          title: const Text('All stocks adequate'),
                        ),
                      );
                    }
                    return Column(
                      children: low
                          .map((item) => Card(
                                color: Colors.red.shade50,
                                child: ListTile(
                                  leading: Icon(Icons.warning_amber, color: AppTheme.payable),
                                  title: Text(item.name),
                                  subtitle: Text('${item.stockQty} ${item.unit} remaining'),
                                  trailing: Text('Min: ${item.minStockAlert}',
                                      style: TextStyle(color: AppTheme.payable)),
                                ),
                              ))
                          .toList(),
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
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
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