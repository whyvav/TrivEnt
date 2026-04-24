import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../sales/add_sale_screen.dart';
import '../purchases/add_purchase_screen.dart';
import 'add_party_screen.dart';

class PartyDetailScreen extends StatelessWidget {
  final PartyModel party;
  const PartyDetailScreen({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(party.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => AddPartyScreen(party: party))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Party info
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  radius: 28,
                  child: Text(party.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(party.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (party.firm != null && party.firm!.isNotEmpty)
                    Text(party.firm!, style: TextStyle(color: Colors.grey.shade600)),
                  if (party.phone != null)
                    Text(party.phone!, style: TextStyle(color: Colors.grey.shade600)),
                ])),
              ]),
              const Divider(height: 24),
              Wrap(spacing: 20, runSpacing: 8, children: [
                if (party.email != null) _DetailItem(Icons.email_outlined, party.email!),
                if (party.gstin != null)
                  _DetailItem(Icons.business_outlined, 'GSTIN: ${party.gstin}'),
                _DetailItem(Icons.category_outlined,
                    'GST Type: ${party.gstType}'),
                if (party.billingAddress != null)
                  _DetailItem(Icons.location_on_outlined, party.billingAddress!),
              ]),
            ]),
          )),
          const SizedBox(height: 12),

          // Balance summary
          FutureBuilder<Map<String, double>>(
            future: svc.getPartyBalance(party.id),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox(height: 60,
                  child: Center(child: CircularProgressIndicator()));
              final b = snap.data!;
              final netBalance = b['netBalance']!;
              return Card(
                color: netBalance > 0.01
                    ? AppTheme.receivable.withValues(alpha: 0.05)
                    : netBalance < -0.01
                        ? AppTheme.payable.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Net Balance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        netBalance > 0.01
                            ? '${cf.format(netBalance)} to receive'
                            : netBalance < -0.01
                                ? '${cf.format(netBalance.abs())} to pay'
                                : 'Settled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: netBalance > 0.01
                              ? AppTheme.receivable
                              : netBalance < -0.01
                                  ? AppTheme.payable
                                  : Colors.grey,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _BalanceBox('Receivable',
                          cf.format(b['receivable']!), AppTheme.receivable)),
                      const SizedBox(width: 8),
                      Expanded(child: _BalanceBox('Received',
                          cf.format(b['received']!), Colors.green.shade700)),
                      const SizedBox(width: 8),
                      Expanded(child: _BalanceBox('Payable',
                          cf.format(b['payable']!), AppTheme.payable)),
                      const SizedBox(width: 8),
                      Expanded(child: _BalanceBox('Paid',
                          cf.format(b['paid']!), Colors.orange.shade700)),
                    ]),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Quick actions
          Row(children: [
            Expanded(child: _ActionBtn(Icons.add_shopping_cart, 'New Sale',
                AppTheme.primary, () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddSaleScreen(prefilledParty: party))))),
            const SizedBox(width: 8),
            Expanded(child: _ActionBtn(Icons.shopping_basket_outlined, 'New Purchase',
                AppTheme.payable, () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddPurchaseScreen(prefilledParty: party))))),
            const SizedBox(width: 8),
            Expanded(child: _ActionBtn(Icons.send_outlined, 'Reminder', Colors.orange,
                () => _sendReminder(context, svc, cf))),
          ]),
          const SizedBox(height: 16),

          // Transactions
          const Text('Transactions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: svc.getPartyTransactions(party.id),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final txs = snap.data!;
              if (txs.isEmpty) {
                return Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No transactions with ${party.name} yet.',
                      style: const TextStyle(color: Colors.grey)),
                ));
              }
              return Card(
                child: Column(
                  children: txs.map((tx) {
                    final isSale = tx['type'] == 'Sale';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isSale
                              ? AppTheme.receivable.withValues(alpha: 0.1)
                              : AppTheme.payable.withValues(alpha: 0.1),
                          child: Icon(isSale ? Icons.receipt_long : Icons.shopping_basket,
                              size: 14,
                              color: isSale ? AppTheme.receivable : AppTheme.payable),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx['refNo'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(df.format(tx['date'] as DateTime),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(cf.format(tx['amount']),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if ((tx['balance'] as double) > 0.01)
                            Text('Due: ${cf.format(tx['balance'])}',
                                style: const TextStyle(
                                    color: AppTheme.payable, fontSize: 11))
                          else
                            const Text('Paid',
                                style: TextStyle(
                                    color: AppTheme.receivable, fontSize: 11)),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _sendReminder(BuildContext context, FirestoreService svc,
      NumberFormat cf) async {
    final messenger = ScaffoldMessenger.of(context);
    final balance = await svc.getPartyBalance(party.id);
    final due = balance['receivable']! - balance['received']!;
    if (due <= 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No outstanding balance for this party.')));
      return;
    }
    final message = Uri.encodeComponent(
      'Dear ${party.name},\n\n'
      'This is a friendly reminder that you have an outstanding balance of '
      '${cf.format(due)} with us.\n\n'
      'Please arrange for payment at your earliest convenience.\n\n'
      'Thank you.',
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text('WhatsApp reminder ready for ${cf.format(due)}'),
        action: SnackBarAction(
          label: 'Copy Message',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: Uri.decodeComponent(message)));
            messenger.showSnackBar(
                const SnackBar(content: Text('Message copied to clipboard!')));
          },
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailItem(this.icon, this.text);
  @override Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _BalanceBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceBox(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9, color: color)),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}