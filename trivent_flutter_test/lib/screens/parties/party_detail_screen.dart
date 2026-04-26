import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../sales/add_sale_screen.dart';
import '../sales/add_payment_in_screen.dart';
import '../purchases/add_purchase_screen.dart';
import '../purchases/add_payment_out_screen.dart';
import 'add_party_screen.dart';

class PartyDetailScreen extends StatefulWidget {
  final PartyModel party;
  const PartyDetailScreen({super.key, required this.party});

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  final _svc = FirestoreService();
  final _cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _df = DateFormat('dd MMM yyyy');

  late Future<Map<String, double>> _balanceFuture;
  late Future<List<Map<String, dynamic>>> _txFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _balanceFuture = _svc.getPartyBalance(widget.party.id);
    _txFuture = _svc.getPartyTransactions(widget.party.id);
  }

  void _refresh() => setState(() => _loadData());

  @override
  Widget build(BuildContext context) {
    final party = widget.party;

    return Scaffold(
      appBar: AppBar(
        title: Text(party.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => AddPartyScreen(party: party))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Party?'),
                  content: Text('Delete "${party.name}"? This cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (ok == true) {
                await _svc.deleteParty(party.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Party info ──────────────────────────────────────────
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
                _DetailItem(Icons.category_outlined, 'GST Type: ${party.gstType}'),
                if (party.billingAddress != null)
                  _DetailItem(Icons.location_on_outlined, party.billingAddress!),
              ]),
            ]),
          )),
          const SizedBox(height: 12),

          // ── Balance + settle-up + quick actions ─────────────────
          FutureBuilder<Map<String, double>>(
            future: _balanceFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 60,
                    child: Center(child: CircularProgressIndicator()));
              }
              final b = snap.data!;
              final netBalance = b['netBalance']!;
              return Column(children: [

                // Balance summary card
                Card(
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
                              ? '${_cf.format(netBalance)} to receive'
                              : netBalance < -0.01
                                  ? '${_cf.format(netBalance.abs())} to pay'
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
                            _cf.format(b['receivable']!), AppTheme.receivable)),
                        const SizedBox(width: 8),
                        Expanded(child: _BalanceBox('Received',
                            _cf.format(b['received']!), Colors.green.shade700)),
                        const SizedBox(width: 8),
                        Expanded(child: _BalanceBox('Payable',
                            _cf.format(b['payable']!), AppTheme.payable)),
                        const SizedBox(width: 8),
                        Expanded(child: _BalanceBox('Paid',
                            _cf.format(b['paid']!), Colors.orange.shade700)),
                      ]),
                    ]),
                  ),
                ),

                // Settle-up button (shown only when balance is outstanding)
                if (netBalance.abs() > 0.01) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => netBalance > 0
                              ? AddPaymentInScreen(
                                  prefilledParty: party,
                                  prefilledAmount: netBalance)
                              : AddPaymentOutScreen(
                                  prefilledParty: party,
                                  prefilledAmount: netBalance.abs()),
                        ),
                      ).then((_) => _refresh()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: netBalance > 0
                            ? AppTheme.receivable
                            : AppTheme.payable,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(netBalance > 0
                          ? Icons.move_to_inbox_outlined
                          : Icons.outbox_outlined),
                      label: Text(netBalance > 0
                          ? 'Pay In  •  ${_cf.format(netBalance)}'
                          : 'Pay Out  •  ${_cf.format(netBalance.abs())}'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Quick actions
                Row(children: [
                  Expanded(child: _ActionBtn(Icons.add_shopping_cart, 'New Sale',
                      AppTheme.primary, () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => AddSaleScreen(prefilledParty: party)))
                          .then((_) => _refresh()))),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(Icons.shopping_basket_outlined, 'New Purchase',
                      AppTheme.payable, () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => AddPurchaseScreen(prefilledParty: party)))
                          .then((_) => _refresh()))),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(Icons.send_outlined, 'Reminder',
                      Colors.orange, () => _sendReminder(context))),
                ]),
              ]);
            },
          ),
          const SizedBox(height: 16),

          // ── Transactions ────────────────────────────────────────
          const Text('Transactions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _txFuture,
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
                    final type = tx['type'] as String;
                    final isGreen = type == 'Sale' || type == 'PaymentIn';
                    final color = isGreen ? AppTheme.receivable : AppTheme.payable;
                    final icon = switch (type) {
                      'Sale'       => Icons.receipt_long,
                      'Purchase'   => Icons.shopping_basket,
                      'PaymentIn'  => Icons.move_to_inbox,
                      'PaymentOut' => Icons.outbox,
                      _            => Icons.swap_horiz,
                    };
                    final statusLabel = switch (type) {
                      'PaymentIn'  => 'Received',
                      'PaymentOut' => 'Paid Out',
                      _            => 'Paid',
                    };
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(icon, size: 14, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx['refNo'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(_df.format(tx['date'] as DateTime),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_cf.format(tx['amount']),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if ((tx['balance'] as double) > 0.01)
                            Text('Due: ${_cf.format(tx['balance'])}',
                                style: const TextStyle(
                                    color: AppTheme.payable, fontSize: 11))
                          else
                            Text(statusLabel,
                                style: TextStyle(color: color, fontSize: 11)),
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

  Future<void> _sendReminder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final balance = await _svc.getPartyBalance(widget.party.id);
    final due = balance['receivable']! - balance['received']!;
    if (due <= 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No outstanding balance for this party.')));
      return;
    }
    final party = widget.party;
    final message = Uri.encodeComponent(
      'Dear ${party.name},\n\n'
      'This is a friendly reminder that you have an outstanding balance of '
      '${_cf.format(due)} with us.\n\n'
      'Please arrange for payment at your earliest convenience.\n\n'
      'Thank you.',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('WhatsApp reminder ready for ${_cf.format(due)}'),
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
  @override
  Widget build(BuildContext context) => Row(
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
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9, color: color)),
      Text(value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
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
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
