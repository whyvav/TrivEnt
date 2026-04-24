import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../services/pdf_service.dart';
import '../../theme.dart';
import 'add_sale_screen.dart';

class SaleDetailScreen extends StatelessWidget {
  final SaleModel sale;
  const SaleDetailScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');
    final pdf = PdfService();

    return Scaffold(
      appBar: AppBar(
        title: Text(sale.invoiceNo),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => AddSaleScreen(existing: sale))),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () async {
              final bytes = await pdf.buildSaleInvoice(sale);
              await pdf.printBytes(bytes);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () async {
              final bytes = await pdf.buildSaleInvoice(sale);
              await pdf.shareAsPdf(bytes, '${sale.invoiceNo.replaceAll('/', '-')}.pdf');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TAX INVOICE',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(sale.invoiceNo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(df.format(sale.date),
                      style: TextStyle(color: Colors.grey.shade600)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sale.isPaid ? AppTheme.receivable : AppTheme.payable,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(sale.isPaid ? 'PAID' : 'UNPAID',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
              const Divider(height: 24),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bill To', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(sale.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (sale.partyFirm != null && sale.partyFirm!.isNotEmpty)
                    Text(sale.partyFirm!, style: const TextStyle(fontSize: 12)),
                  if (sale.partyPhone != null)
                    Text(sale.partyPhone!, style: const TextStyle(fontSize: 12)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _KV('Payment', sale.paymentType),
                  if (sale.paymentRef != null) _KV('Ref.', sale.paymentRef!),
                  if (sale.dueDate != null) _KV('Due', df.format(sale.dueDate!)),
                ])),
              ]),
            ]),
          )),
          const SizedBox(height: 12),

          // Items
          Card(child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
              child: Row(children: const [
                Expanded(flex: 3, child: Text('Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text('Qty', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
            ),
            ...sale.items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              child: Row(children: [
                Expanded(flex: 3, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (item.discountPercent > 0 || item.taxPercent > 0)
                      Text(
                        [
                          if (item.discountPercent > 0) 'Disc: ${item.discountPercent}%',
                          if (item.taxPercent > 0) 'Tax: ${item.taxPercent}%',
                        ].join('  •  '),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                  ],
                )),
                Expanded(child: Text('${item.qty} ${item.unit}',
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                Expanded(flex: 2, child: Text(cf.format(item.priceExclTax),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Colors.black54))),
                Expanded(flex: 2, child: Text(cf.format(item.lineTotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              ]),
            )),
          ])),
          const SizedBox(height: 12),

          // Totals
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _TotalRow('Subtotal', cf.format(sale.subtotal)),
              if (sale.totalDiscount > 0)
                _TotalRow('Discount', '- ${cf.format(sale.totalDiscount)}',
                    color: Colors.orange),
              if (sale.totalTax > 0)
                _TotalRow('Tax', '+ ${cf.format(sale.totalTax)}'),
              const Divider(),
              _TotalRow('TOTAL', cf.format(sale.totalAmount), bold: true),
              _TotalRow('Amount Paid', cf.format(sale.amountPaid),
                  color: AppTheme.receivable),
              if (sale.balanceDue > 0.01)
                _TotalRow('Balance Due', cf.format(sale.balanceDue),
                    color: AppTheme.payable, bold: true),
            ]),
          )),

          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.notes_outlined, color: Colors.grey.shade400, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(sale.notes!,
                    style: TextStyle(color: Colors.grey.shade700))),
              ]),
            )),
          ],
          const SizedBox(height: 16),

          // Action buttons
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final bytes = await pdf.buildSaleInvoice(sale);
                await pdf.printBytes(bytes);
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                final bytes = await pdf.buildSaleInvoice(sale);
                await pdf.shareAsPdf(bytes, '${sale.invoiceNo.replaceAll('/', '-')}.pdf');
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share PDF'),
            )),
          ]),
        ]),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k, v;
  const _KV(this.k, this.v);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text('$k: ', style: const TextStyle(color: Colors.grey, fontSize: 11)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
    ]),
  );
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _TotalRow(this.label, this.value,
      {this.color = Colors.black87, this.bold = false});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      Text(value, style: TextStyle(color: color, fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    ]),
  );
}