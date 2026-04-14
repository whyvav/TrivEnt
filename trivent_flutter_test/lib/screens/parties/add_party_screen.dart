import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/party_model.dart';
import '../../services/firestore_service.dart';

class AddPartyScreen extends StatefulWidget {
  final PartyModel? party;  // pass existing party to edit
  const AddPartyScreen({super.key, this.party});
  @override State<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final svc = FirestoreService();
  late TextEditingController _name, _firm, _phone, _email,
      _gstin, _billing, _shipping;
  String _gstType = 'consumer';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.party;
    _name = TextEditingController(text: p?.name ?? '');
    _firm = TextEditingController(text: p?.firm ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _gstin = TextEditingController(text: p?.gstin ?? '');
    _billing = TextEditingController(text: p?.billingAddress ?? '');
    _shipping = TextEditingController(text: p?.shippingAddress ?? '');
    _gstType = p?.gstType ?? 'consumer';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.party != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Party' : 'Add Party')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextFormField(controller: _name,
                decoration: const InputDecoration(labelText: 'Party Name *'),
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _firm,
                decoration: const InputDecoration(labelText: 'Firm / Company Name')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _gstin,
                  decoration: const InputDecoration(labelText: 'GSTIN'))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _gstType,
                decoration: const InputDecoration(labelText: 'GST Type'),
                items: const [
                  DropdownMenuItem(value: 'registered', child: Text('Registered')),
                  DropdownMenuItem(value: 'unregistered', child: Text('Unregistered')),
                  DropdownMenuItem(value: 'consumer', child: Text('Consumer')),
                ],
                onChanged: (v) => setState(() => _gstType = v!),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _billing,
                decoration: const InputDecoration(labelText: 'Billing Address'),
                maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _shipping,
                decoration: const InputDecoration(labelText: 'Shipping Address (if different)'),
                maxLines: 2),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Update Party' : 'Save Party'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final party = PartyModel(
        id: widget.party?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        firm: _firm.text.isEmpty ? null : _firm.text.trim(),
        phone: _phone.text.isEmpty ? null : _phone.text.trim(),
        email: _email.text.isEmpty ? null : _email.text.trim(),
        gstin: _gstin.text.isEmpty ? null : _gstin.text.trim(),
        billingAddress: _billing.text.isEmpty ? null : _billing.text.trim(),
        shippingAddress: _shipping.text.isEmpty ? null : _shipping.text.trim(),
        gstType: _gstType,
        createdAt: widget.party?.createdAt,
      );
      await svc.saveParty(party);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}