import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/party_model.dart';
import '../../theme.dart';
import 'add_party_screen.dart';
import 'party_detail_screen.dart';

class PartiesScreen extends StatelessWidget {
  const PartiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Parties')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPartyScreen())),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Party'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PartyModel>>(
        stream: svc.streamParties(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final parties = snap.data ?? [];
          if (parties.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No parties yet. Add customers and suppliers.'),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: parties.length,
            itemBuilder: (ctx, i) {
              final p = parties[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => PartyDetailScreen(party: p))),
                  leading: _PartyAvatar(
                    party: p,
                    onOpen: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PartyDetailScreen(party: p))),
                    onEdit: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddPartyScreen(party: p))),
                    onDelete: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Party?'),
                          content: Text('Delete "${p.name}"?'),
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
                      if (ok == true) await svc.deleteParty(p.id);
                    },
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    if (p.firm != null && p.firm!.isNotEmpty) p.firm!,
                    if (p.phone != null) p.phone!,
                  ].join(' • ')),
                  trailing: _PartyBalanceBadge(partyId: p.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PartyAvatar extends StatelessWidget {
  final PartyModel party;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _PartyAvatar({
    required this.party,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (val) async {
        if (val == 'open') {
          onOpen();
        } else if (val == 'edit') {
          onEdit();
        } else if (val == 'delete') {
          await onDelete();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'open',
          child: Row(children: [
            Icon(Icons.open_in_new, size: 16),
            SizedBox(width: 8),
            Text('Open'),
          ]),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      tooltip: '',
      child: CircleAvatar(
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: Text(
          party.name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
      ),
    );
  }
}

class _PartyBalanceBadge extends StatelessWidget {
  final String partyId;
  const _PartyBalanceBadge({required this.partyId});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return FutureBuilder<Map<String, double>>(
      future: svc.getPartyBalance(partyId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 56,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }
        final b = snap.data!;
        final net = b['netBalance']!;
        final hasAnyTxn =
            (b['receivable']! + b['received']! + b['payable']! + b['paid']!) > 0;

        if (!hasAnyTxn) {
          return const Text(
            'no txn',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          );
        }
        if (net.abs() <= 0.01) {
          return const Text(
            'settled up',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          );
        }

        final isOwesYou = net > 0;
        final color = isOwesYou ? AppTheme.receivable : AppTheme.payable;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isOwesYou ? 'owes you' : 'you owe',
              style: TextStyle(fontSize: 9, color: color),
            ),
            Text(
              cf.format(net.abs()),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        );
      },
    );
  }
}
