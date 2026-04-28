import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/worker_model.dart';
import '../../models/labor_earning_model.dart';
import '../../models/wage_payment_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'add_worker_screen.dart';

class WorkerDetailScreen extends StatefulWidget {
  final WorkerModel worker;
  const WorkerDetailScreen({super.key, required this.worker});
  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final svc = FirestoreService();
  List<LaborEarningModel> _earnings = [];
  List<WagePaymentModel> _payments = [];
  StreamSubscription? _earnSub, _paymentSub;

  // Track current worker (may be updated after edit)
  late WorkerModel _worker;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _earnSub = svc.streamLaborEarnings(_worker.id).listen(
        (data) => setState(() => _earnings = data));
    _paymentSub = svc.streamWagePayments(_worker.id).listen(
        (data) => setState(() => _payments = data));
  }

  @override
  void dispose() {
    _earnSub?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }

  double get _totalEarned => _earnings.fold(0, (s, e) => s + e.amount);
  double get _totalPaid   => _payments.fold(0, (s, p) => s + p.amount);
  double get _outstanding => _totalEarned - _totalPaid;

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final outstanding = _outstanding;

    // Build merged history sorted by date desc
    final history = <_HistoryEntry>[
      ..._earnings.map((e) => _HistoryEntry.fromEarning(e)),
      ..._payments.map((p) => _HistoryEntry.fromPayment(p)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(_worker.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit worker',
            onPressed: () async {
              final nav = Navigator.of(context);
              await nav.push(MaterialPageRoute(
                  builder: (_) => AddWorkerScreen(existing: _worker)));
              if (mounted) nav.pop();
            },
          ),
        ],
      ),
      floatingActionButton: outstanding > 0.01
          ? FloatingActionButton.extended(
              onPressed: () => _showPayDialog(context, outstanding),
              icon: const Icon(Icons.payments_outlined),
              label: Text('Pay  ${cf.format(outstanding)}'),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Balance summary ──────────────────────────────────
          _BalanceCard(
            earned: _totalEarned,
            paid: _totalPaid,
            outstanding: outstanding,
          ),
          const SizedBox(height: 16),

          // ── Worker info ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(Icons.badge_outlined, 'Role', _worker.role),
                  _InfoRow(
                    _worker.isContractor
                        ? Icons.precision_manufacturing_outlined
                        : Icons.calendar_today_outlined,
                    'Type',
                    _worker.isContractor ? 'Contractor' : 'Daily Wage Worker',
                  ),
                  if (_worker.rateLabel.isNotEmpty)
                    _InfoRow(Icons.currency_rupee, 'Rate', _worker.rateLabel),
                  if (_worker.isContractor &&
                      _worker.linkedProductName != null)
                    _InfoRow(Icons.inventory_2_outlined, 'Product',
                        _worker.linkedProductName!),
                  if (_worker.phone != null)
                    _InfoRow(Icons.phone_outlined, 'Phone', _worker.phone!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Log Work section (daily wage only) ───────────────
          if (_worker.isDailyWage) ...[
            _LogWorkCard(worker: _worker, svc: svc),
            const SizedBox(height: 16),
          ],

          // ── Contractor info note ─────────────────────────────
          if (_worker.isContractor) ...[
            Card(
              color: AppTheme.primary.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.primary.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _worker.linkedProductName != null
                          ? 'Earnings are auto-logged each time a '
                              '${_worker.linkedProductName} manufacturing batch runs.'
                          : 'Link a product in Edit to auto-log earnings on each manufacturing batch.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary.withValues(alpha: 0.8)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Activity history ─────────────────────────────────
          Text('Activity',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (history.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('No activity yet.',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: history.map((h) => _HistoryTile(
                  entry: h,
                  onDeletePayment: h.isPayment
                      ? () => _deletePayment(h.id)
                      : null,
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showPayDialog(BuildContext context, double outstanding) {
    showDialog(
      context: context,
      builder: (_) => _PayWagesDialog(
        worker: _worker,
        outstanding: outstanding,
        onPay: (amount, type, ref, notes) async {
          await svc.payWages(
            workerId: _worker.id,
            workerName: _worker.name,
            isContractor: _worker.isContractor,
            amount: amount,
            paymentType: type,
            paymentRef: ref.isEmpty ? null : ref,
            notes: notes.isEmpty ? null : notes,
          );
        },
      ),
    );
  }

  Future<void> _deletePayment(String paymentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Payment?'),
        content: const Text('This removes this wage payment record.'),
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
    if (ok != true || !mounted) return;
    try {
      await svc.deleteWagePayment(paymentId);
      // For daily-wage workers, delete the linked expense entry.
      // For contractors no expense is created (labor already in mfg BoM);
      // deleting a non-existent Firestore doc is a safe no-op.
      if (!_worker.isContractor) {
        await svc.deleteExpense('wages_$paymentId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ── Log Work Card ─────────────────────────────────────────────────────

class _LogWorkCard extends StatefulWidget {
  final WorkerModel worker;
  final FirestoreService svc;
  const _LogWorkCard({required this.worker, required this.svc});
  @override
  State<_LogWorkCard> createState() => _LogWorkCardState();
}

class _LogWorkCardState extends State<_LogWorkCard> {
  DateTime _date = DateTime.now();
  bool _saving = false;

  Future<void> _log(double days) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final rate = widget.worker.dailyWage ?? 0;
      final id = const Uuid().v4();
      final df = DateFormat('dd MMM yyyy');
      await widget.svc.addLaborEarning(LaborEarningModel(
        id: id,
        workerId: widget.worker.id,
        workerName: widget.worker.name,
        date: _date,
        amount: rate * days,
        qty: days,
        unit: 'day',
        source: 'attendance',
        notes: '${days == 0.5 ? "½" : days.toStringAsFixed(0)} day — ${df.format(_date)}',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${days == 0.5 ? "½" : "1"} day logged for ${df.format(_date)}'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Log Work',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              child: Text(df.format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.exposure_minus_1, size: 18),
                label: const Text('½ Day'),
                onPressed: _saving ? null : () => _log(0.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 18),
                label: const Text('+1 Day'),
                onPressed: _saving ? null : () => _log(1),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Pay Wages Dialog ──────────────────────────────────────────────────

class _PayWagesDialog extends StatefulWidget {
  final WorkerModel worker;
  final double outstanding;
  final Future<void> Function(double, String, String, String) onPay;
  const _PayWagesDialog({
    required this.worker,
    required this.outstanding,
    required this.onPay,
  });
  @override
  State<_PayWagesDialog> createState() => _PayWagesDialogState();
}

class _PayWagesDialogState extends State<_PayWagesDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentType = 'Cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.outstanding.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose(); _refCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return AlertDialog(
      title: Text('Pay Wages — ${widget.worker.name}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Outstanding: ${cf.format(widget.outstanding)}',
              style: const TextStyle(color: AppTheme.payable,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount ₹',
              prefixText: '₹',
              border: OutlineInputBorder(),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _paymentType,
            decoration: const InputDecoration(
                labelText: 'Payment Type', border: OutlineInputBorder()),
            items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => _paymentType = v!,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference / Cheque No. (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _pay,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Pay'),
        ),
      ],
    );
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onPay(amount, _paymentType, _refCtrl.text, _notesCtrl.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ── History entry ─────────────────────────────────────────────────────

class _HistoryEntry {
  final String id;
  final DateTime date;
  final bool isPayment;
  final double amount;
  final String title;
  final String subtitle;

  const _HistoryEntry({
    required this.id,
    required this.date,
    required this.isPayment,
    required this.amount,
    required this.title,
    required this.subtitle,
  });

  factory _HistoryEntry.fromEarning(LaborEarningModel e) {
    final df = DateFormat('dd MMM yyyy');
    final qtyStr = e.qty == e.qty.truncateToDouble()
        ? e.qty.toStringAsFixed(0)
        : e.qty.toStringAsFixed(1);
    final title = e.source == 'manufacturing'
        ? 'Manufacturing batch'
        : '$qtyStr ${e.unit}${e.qty != 1 ? 's' : ''} worked';
    return _HistoryEntry(
      id: e.id,
      date: e.date,
      isPayment: false,
      amount: e.amount,
      title: title,
      subtitle: df.format(e.date),
    );
  }

  factory _HistoryEntry.fromPayment(WagePaymentModel p) {
    final df = DateFormat('dd MMM yyyy');
    return _HistoryEntry(
      id: p.id,
      date: p.date,
      isPayment: true,
      amount: p.amount,
      title: 'Wages paid',
      subtitle: '${df.format(p.date)}  •  ${p.paymentType}',
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryEntry entry;
  final VoidCallback? onDeletePayment;
  const _HistoryTile({required this.entry, this.onDeletePayment});

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final color = entry.isPayment ? Colors.blue.shade700 : Colors.green.shade700;
    final icon = entry.isPayment
        ? Icons.arrow_upward_rounded
        : entry.title.contains('Manufacturing')
            ? Icons.precision_manufacturing_outlined
            : Icons.work_outline;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(entry.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(entry.subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          (entry.isPayment ? '−' : '+') + cf.format(entry.amount),
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
        if (entry.isPayment && onDeletePayment != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onDeletePayment,
          ),
      ]),
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double earned, paid, outstanding;
  const _BalanceCard(
      {required this.earned, required this.paid, required this.outstanding});

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final outColor = outstanding > 0.01 ? AppTheme.payable : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _Stat('Total Earned', cf.format(earned), Colors.green.shade700),
          const VerticalDivider(width: 32),
          _Stat('Total Paid', cf.format(paid), Colors.blue.shade700),
          const VerticalDivider(width: 32),
          _Stat(
            outstanding > 0.01 ? 'Outstanding' : 'Settled',
            cf.format(outstanding.abs()),
            outColor,
            bold: true,
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Stat(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w600,
                  color: color),
              textAlign: TextAlign.center),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
}
