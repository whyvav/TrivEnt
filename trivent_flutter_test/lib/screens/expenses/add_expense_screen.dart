import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../services/firestore_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final svc = FirestoreService();
  String _category = 'Misc';
  String _paymentType = 'Cash';
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _partyName = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseModel.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _description,
                decoration: const InputDecoration(labelText: 'Description *'),
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount ₹ *', prefixText: '₹'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _paymentType,
                decoration: const InputDecoration(labelText: 'Payment Type'),
                items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _paymentType = v!),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _partyName,
                decoration: const InputDecoration(labelText: 'Paid To (optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Expense'),
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
      await svc.addExpense(ExpenseModel(
        id: const Uuid().v4(),
        category: _category,
        description: _description.text.trim(),
        amount: double.tryParse(_amount.text) ?? 0,
        paymentType: _paymentType,
        partyName: _partyName.text.isEmpty ? null : _partyName.text.trim(),
        notes: _notes.text.isEmpty ? null : _notes.text.trim(),
      ));
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