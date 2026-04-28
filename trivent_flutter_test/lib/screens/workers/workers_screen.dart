import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/worker_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'add_worker_screen.dart';
import 'worker_detail_screen.dart';

class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(title: const Text('Workers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddWorkerScreen())),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Worker'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<WorkerModel>>(
        stream: svc.streamWorkers(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final workers = snap.data ?? [];
          if (workers.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.engineering_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No workers yet.'),
                    const SizedBox(height: 8),
                    Text(
                      'Add contractors (per-unit pay) or\ndaily wage workers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ]),
            );
          }

          final contractors =
              workers.where((w) => w.isContractor).toList();
          final dailyWorkers =
              workers.where((w) => w.isDailyWage).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              if (contractors.isNotEmpty) ...[
                const _SectionHeader(
                    icon: Icons.precision_manufacturing_outlined,
                    label: 'Contractors'),
                const SizedBox(height: 6),
                ...contractors.map((w) => _WorkerCard(
                    worker: w, svc: svc, cf: cf)),
                const SizedBox(height: 16),
              ],
              if (dailyWorkers.isNotEmpty) ...[
                const _SectionHeader(
                    icon: Icons.calendar_today_outlined,
                    label: 'Daily Wage Workers'),
                const SizedBox(height: 6),
                ...dailyWorkers.map((w) => _WorkerCard(
                    worker: w, svc: svc, cf: cf)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.grey.shade600)),
      ]);
}

class _WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  final FirestoreService svc;
  final NumberFormat cf;
  const _WorkerCard(
      {required this.worker, required this.svc, required this.cf});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => WorkerDetailScreen(worker: worker))),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Text(worker.name[0].toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ),
        title: Text(worker.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [worker.role, worker.rateLabel]
              .where((s) => s.isNotEmpty)
              .join('  •  '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _WorkerBalanceBadge(workerId: worker.id, svc: svc, cf: cf),
      ),
    );
  }
}

class _WorkerBalanceBadge extends StatelessWidget {
  final String workerId;
  final FirestoreService svc;
  final NumberFormat cf;
  const _WorkerBalanceBadge(
      {required this.workerId, required this.svc, required this.cf});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: svc.getWorkerBalance(workerId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 48,
            child: Center(
              child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5)),
            ),
          );
        }
        final outstanding = snap.data!['outstanding']!;
        if (outstanding <= 0.01) {
          return const Text('settled',
              style: TextStyle(fontSize: 10, color: Colors.grey));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('owed',
                style: TextStyle(fontSize: 9, color: AppTheme.payable)),
            Text(cf.format(outstanding),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.payable)),
          ],
        );
      },
    );
  }
}
