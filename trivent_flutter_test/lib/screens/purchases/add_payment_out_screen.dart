import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/payment_out_model.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class AddPaymentOutScreen extends StatefulWidget {
  final PaymentOutModel? existing;
  final PartyModel? prefilledParty;
  final double? prefilledAmount;
  const AddPaymentOutScreen({super.key, this.existing, this.prefilledParty, this.prefilledAmount});

  @override
  State<AddPaymentOutScreen> createState() => _AddPaymentOutScreenState();
}

class _AddPaymentOutScreenState extends State<AddPaymentOutScreen> {
  final _svc = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  PartyModel? _selectedParty;
  final _partyNameCtrl = TextEditingController();
  final _partyPhoneCtrl = TextEditingController();
  final _partyFirmCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _paymentRefCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _paymentType = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existing!;
      _partyNameCtrl.text = p.partyName;
      _partyPhoneCtrl.text = p.partyPhone ?? '';
      _partyFirmCtrl.text = p.partyFirm ?? '';
      _amountCtrl.text = p.amount.toStringAsFixed(2);
      _paymentType = p.paymentType;
      _paymentRefCtrl.text = p.paymentRef ?? '';
      _notesCtrl.text = p.notes ?? '';
      _selectedDate = p.date;
    } else {
      if (widget.prefilledParty != null) {
        final party = widget.prefilledParty!;
        _partyNameCtrl.text = party.name;
        _partyPhoneCtrl.text = party.phone ?? '';
        _partyFirmCtrl.text = party.firm ?? '';
        _selectedParty = party;
      }
      if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
        _amountCtrl.text = widget.prefilledAmount!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _partyNameCtrl.dispose();
    _partyPhoneCtrl.dispose();
    _partyFirmCtrl.dispose();
    _amountCtrl.dispose();
    _paymentRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final partyId = _selectedParty?.id ??
          await _svc.upsertPartyFromSale(
            name: _partyNameCtrl.text.trim(),
            firm: _partyFirmCtrl.text.trim().isEmpty ? null : _partyFirmCtrl.text.trim(),
            phone: _partyPhoneCtrl.text.trim().isEmpty ? null : _partyPhoneCtrl.text.trim(),
          );

      final paymentNo = _isEditing
          ? widget.existing!.paymentNo
          : await _svc.nextPaymentOutNo(_selectedDate);

      final model = PaymentOutModel(
        id: _isEditing ? widget.existing!.id : const Uuid().v4(),
        paymentNo: paymentNo,
        partyId: partyId,
        partyName: _partyNameCtrl.text.trim(),
        partyFirm: _partyFirmCtrl.text.trim().isEmpty ? null : _partyFirmCtrl.text.trim(),
        partyPhone: _partyPhoneCtrl.text.trim().isEmpty ? null : _partyPhoneCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text),
        paymentType: _paymentType,
        paymentRef: _paymentRefCtrl.text.trim().isEmpty ? null : _paymentRefCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        date: _selectedDate,
      );

      if (_isEditing) {
        await _svc.updatePaymentOut(model);
      } else {
        await _svc.addPaymentOut(model);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Payment' : 'New Payment Out'),
      ),
      body: Form(
        key: _formKey,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Party ──────────────────────────────────────
                Text('Supplier / Party Details',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    StreamBuilder<List<PartyModel>>(
                      stream: _svc.streamParties(),
                      builder: (ctx, snap) {
                        final parties = snap.data ?? [];
                        return Autocomplete<PartyModel>(
                          displayStringForOption: (p) => p.displayName,
                          optionsBuilder: (tv) {
                            if (tv.text.isEmpty) return parties;
                            return parties.where((p) =>
                                p.name.toLowerCase().contains(tv.text.toLowerCase()) ||
                                (p.firm?.toLowerCase().contains(tv.text.toLowerCase()) ?? false));
                          },
                          onSelected: (p) => setState(() {
                            _selectedParty = p;
                            _partyNameCtrl.text = p.name;
                            _partyPhoneCtrl.text = p.phone ?? '';
                            _partyFirmCtrl.text = p.firm ?? '';
                          }),
                          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                            if (_partyNameCtrl.text.isNotEmpty && ctrl.text.isEmpty) {
                              ctrl.text = _partyNameCtrl.text;
                            }
                            return TextFormField(
                              controller: ctrl,
                              focusNode: focusNode,
                              decoration: const InputDecoration(labelText: 'Party Name *'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                              onChanged: (v) {
                                _partyNameCtrl.text = v;
                                if (_selectedParty != null && _selectedParty!.name != v) {
                                  _selectedParty = null;
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _partyPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _partyFirmCtrl,
                        decoration: const InputDecoration(labelText: 'Firm / Company'),
                      )),
                    ]),
                  ]),
                )),

                const SizedBox(height: 16),

                // ── Payment Details ─────────────────────────────
                Text('Payment Details',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [

                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid *',
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _selectedDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date'),
                        child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _paymentType,
                      decoration: const InputDecoration(labelText: 'Payment Mode'),
                      items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _paymentType = v!),
                    ),
                    const SizedBox(height: 10),

                    if (_paymentType != 'Cash') ...[
                      TextFormField(
                        controller: _paymentRefCtrl,
                        decoration: InputDecoration(
                          labelText: _paymentType == 'Cheque'
                              ? 'Cheque No.'
                              : 'Transaction / Reference No.',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 2,
                    ),
                  ]),
                )),
              ]),
            ),
          ),

          // ── Save button ─────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.payable,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : (_isEditing ? 'Update' : 'Save Payment')),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
