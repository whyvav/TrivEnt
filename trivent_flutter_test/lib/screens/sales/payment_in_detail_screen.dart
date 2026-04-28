import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment_in_model.dart';
import '../../services/pdf_service.dart';
import '../../theme.dart';
import 'add_payment_in_screen.dart';

class PaymentInDetailScreen extends StatelessWidget {
  final PaymentInModel payment;
  const PaymentInDetailScreen({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');
    final pdf = PdfService();

    return Scaffold(
      appBar: AppBar(
        title: Text(payment.receiptNo),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => AddPaymentInScreen(existing: payment))),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () async {
              final bytes = await pdf.buildPaymentInReceipt(payment);
              await pdf.printBytes(bytes);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () async {
              final bytes = await pdf.buildPaymentInReceipt(payment);
              await pdf.shareAsPdf(bytes, '${payment.receiptNo.replaceAll('/', '-')}.pdf');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('PAYMENT RECEIPT',
                      style: TextStyle(
                          color: AppTheme.receivable,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(payment.receiptNo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(df.format(payment.date),
                      style: TextStyle(color: Colors.grey.shade600)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.receivable,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('RECEIVED',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
              const Divider(height: 24),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Received From',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(payment.partyName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (payment.partyFirm != null && payment.partyFirm!.isNotEmpty)
                    Text(payment.partyFirm!, style: const TextStyle(fontSize: 12)),
                  if (payment.partyPhone != null)
                    Text(payment.partyPhone!, style: const TextStyle(fontSize: 12)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _KV('Mode', payment.paymentType),
                  if (payment.paymentRef != null && payment.paymentRef!.isNotEmpty)
                    _KV('Ref.', payment.paymentRef!),
                ])),
              ]),
            ]),
          )),
          const SizedBox(height: 12),

          // Amount card
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Amount Received',
                  style: TextStyle(fontSize: 15, color: Colors.grey)),
              Text(cf.format(payment.amount),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.receivable)),
            ]),
          )),

          if (payment.notes != null && payment.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.notes_outlined, color: Colors.grey.shade400, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(payment.notes!,
                    style: TextStyle(color: Colors.grey.shade700))),
              ]),
            )),
          ],
          const SizedBox(height: 16),

          // Action buttons
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final bytes = await pdf.buildPaymentInReceipt(payment);
                await pdf.printBytes(bytes);
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                final bytes = await pdf.buildPaymentInReceipt(payment);
                await pdf.shareAsPdf(
                    bytes, '${payment.receiptNo.replaceAll('/', '-')}.pdf');
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
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('$k: ', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
        ]),
      );
}
