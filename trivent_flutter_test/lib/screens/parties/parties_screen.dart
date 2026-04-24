import 'package:flutter/material.dart';
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
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(p.name[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    if (p.firm != null && p.firm!.isNotEmpty) p.firm!,
                    if (p.phone != null) p.phone!,
                  ].join(' • ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddPartyScreen(party: p)));
                      } else if (val == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Party?'),
                            content: Text('Delete "${p.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (ok == true) await svc.deleteParty(p.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}