import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/sale_model.dart';
import '../../theme.dart';
import 'add_sale_screen.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final dateFmt = DateFormat('dd MMM yyyy');
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No sales yet. Add your first sale!'),
              ]),
            );
          }

          // Summary header
          final totalSales = sales.fold(0.0, (s, sale) => s + sale.totalAmount);
          final received = sales.where((s) => s.isPaid).fold(0.0, (s, sale) => s + sale.totalAmount);

          return Column(
            children: [
              // Summary bar
              Container(
                color: AppTheme.primary,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip('Total', currencyFmt.format(totalSales), Colors.white),
                    _StatChip('Received', currencyFmt.format(received), Colors.greenAccent),
                    _StatChip('Balance', currencyFmt.format(totalSales - received), Colors.orangeAccent),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sales.length,
                  itemBuilder: (ctx, i) {
                    final sale = sales[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sale.isPaid
                              ? AppTheme.receivable.withOpacity(0.1)
                              : AppTheme.payable.withOpacity(0.1),
                          child: Icon(
                            sale.isPaid ? Icons.check : Icons.pending,
                            color: sale.isPaid ? AppTheme.receivable : AppTheme.payable,
                          ),
                        ),
                        title: Text(sale.partyName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${sale.invoiceNo}  •  ${dateFmt.format(sale.date)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(currencyFmt.format(sale.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sale.isPaid ? AppTheme.receivable : AppTheme.payable,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(sale.isPaid ? 'PAID' : sale.paymentType,
                                  style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _StatChip(this.label, this.value, this.valueColor);
  @override Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
    ]);
  }
}