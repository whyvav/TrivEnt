import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/bom_model.dart';
import '../../theme.dart';
import 'add_bom_screen.dart';

class BomScreen extends StatelessWidget {
  const BomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Bill of Materials')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddBomScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New BoM'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<BomModel>>(
        stream: svc.streamBoms(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final boms = snap.data ?? [];
          if (boms.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No BoM defined. Tap + to create a recipe.'),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: boms.length,
            itemBuilder: (ctx, i) {
              final bom = boms[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: const Icon(Icons.view_in_ar, color: AppTheme.primary),
                    ),
                    title: Text(bom.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Cost/unit: ₹${bom.totalCostPerUnit.toStringAsFixed(2)}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => AddBomScreen(existing: bom))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20,
                            color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete BoM?'),
                              content: Text(
                                  'Delete BoM for "${bom.productName}"?'),
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
                          if (ok == true) await svc.deleteBom(bom.id);
                        },
                      ),
                    ]),
                  ),
                  // Expandable details
                  ExpansionTile(
                    title: const Text('View Recipe',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bom.materials.isNotEmpty) ...[
                              const Text('Materials:',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              ...bom.materials.map((m) => ListTile(dense: true,
                                title: Text(m.materialName),
                                subtitle: Text(
                                    '${m.qtyPerUnit} ${m.unit} @ ₹${m.pricePerUnit}/${m.unit}'),
                                trailing: Text(
                                    '₹${m.costPerUnit.toStringAsFixed(2)}'))),
                            ],
                            if (bom.otherCosts.isNotEmpty) ...[
                              const Divider(),
                              const Text('Other Costs:',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              ...bom.otherCosts.map((c) => ListTile(dense: true,
                                title: Text(c.type),
                                trailing: Text(
                                    '₹${c.costPerUnit.toStringAsFixed(2)}/${c.unit}'))),
                            ],
                            const Divider(),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                              const Text('Total Cost/unit:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('₹${bom.totalCostPerUnit.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}