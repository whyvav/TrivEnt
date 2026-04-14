import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<Map<String, double>>(
        future: svc.getDashboardStats(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snap.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  'Triveni Enterprises',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                Row(children: [
                  Expanded(child: _SummaryCard(
                    title: 'Total Sales',
                    amount: currencyFmt.format(stats['totalSales'] ?? 0),
                    icon: Icons.trending_up,
                    color: AppTheme.primary,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    title: 'Received',
                    amount: currencyFmt.format(stats['totalReceived'] ?? 0),
                    icon: Icons.check_circle_outline,
                    color: AppTheme.receivable,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    title: 'Balance',
                    amount: currencyFmt.format(stats['totalBalance'] ?? 0),
                    icon: Icons.hourglass_empty,
                    color: AppTheme.payable,
                  )),
                ]),

                const SizedBox(height: 24),

                // Quick Actions
                Text('Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _QuickActionButton(label: 'Add Sale', icon: Icons.add_shopping_cart, onTap: () {}),
                  _QuickActionButton(label: 'Add Item', icon: Icons.add_box_outlined, onTap: () {}),
                  _QuickActionButton(label: 'Manufacture', icon: Icons.precision_manufacturing, onTap: () {}),
                ]),

                const SizedBox(height: 24),

                // Low Stock Alert
                Text('Low Stock Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: svc.streamItems(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final lowStock = snap.data!.where((i) =>
                        i.minStockAlert > 0 && i.stockQty <= i.minStockAlert).toList();
                    if (lowStock.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Icon(Icons.check_circle, color: AppTheme.receivable),
                            const SizedBox(width: 8),
                            const Text('All stocks are adequate'),
                          ]),
                        ),
                      );
                    }
                    return Column(
                      children: lowStock.map((item) => Card(
                        color: Colors.red.shade50,
                        child: ListTile(
                          leading: Icon(Icons.warning_amber, color: AppTheme.payable),
                          title: Text(item.name),
                          subtitle: Text('Stock: ${item.stockQty} ${item.unit}'),
                          trailing: Text('Min: ${item.minStockAlert}',
                              style: TextStyle(color: AppTheme.payable)),
                        ),
                      )).toList(),
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
}

class _SummaryCard extends StatelessWidget {
  final String title, amount;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.title, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ]),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
          Text(label, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}