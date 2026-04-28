import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/worker_model.dart';
import '../../models/item_model.dart';
import '../../services/firestore_service.dart';

class AddWorkerScreen extends StatefulWidget {
  final WorkerModel? existing;
  const AddWorkerScreen({super.key, this.existing});
  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final svc = FirestoreService();

  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _role;
  late TextEditingController _dailyWage;
  late TextEditingController _ratePerUnit;

  String _type = 'daily_wage'; // 'daily_wage' | 'contractor'
  ItemModel? _linkedProduct;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _name      = TextEditingController(text: w?.name ?? '');
    _phone     = TextEditingController(text: w?.phone ?? '');
    _role      = TextEditingController(text: w?.role ?? '');
    _dailyWage = TextEditingController(
        text: w?.dailyWage != null ? w!.dailyWage!.toStringAsFixed(0) : '');
    _ratePerUnit = TextEditingController(
        text: w?.ratePerUnit != null ? w!.ratePerUnit!.toStringAsFixed(2) : '');
    _type = w?.type ?? 'daily_wage';
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _role.dispose();
    _dailyWage.dispose(); _ratePerUnit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Worker' : 'Add Worker')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _role,
                  decoration: const InputDecoration(
                      labelText: 'Role *',
                      hintText: 'e.g. Brick Contractor'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                )),
              ]),
              const SizedBox(height: 20),

              // Type toggle
              const Text('Worker Type',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'daily_wage',
                    label: Text('Daily Wage'),
                    icon: Icon(Icons.calendar_today, size: 16),
                  ),
                  ButtonSegment(
                    value: 'contractor',
                    label: Text('Contractor'),
                    icon: Icon(Icons.precision_manufacturing, size: 16),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),

              // Daily wage fields
              if (_type == 'daily_wage') ...[
                TextFormField(
                  controller: _dailyWage,
                  decoration: const InputDecoration(
                    labelText: 'Daily Wage Rate *',
                    prefixText: '₹',
                    suffixText: '/day',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (_type != 'daily_wage') return null;
                    if (v!.trim().isEmpty) return 'Required';
                    if ((double.tryParse(v) ?? -1) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
              ],

              // Contractor fields
              if (_type == 'contractor') ...[
                TextFormField(
                  controller: _ratePerUnit,
                  decoration: const InputDecoration(
                    labelText: 'Rate per Unit *',
                    prefixText: '₹',
                    suffixText: '/unit',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (_type != 'contractor') return null;
                    if (v!.trim().isEmpty) return 'Required';
                    if ((double.tryParse(v) ?? -1) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text('Linked Product (optional)',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                StreamBuilder<List<ItemModel>>(
                  stream: svc.streamItems(category: 'product'),
                  builder: (ctx, snap) {
                    final products = snap.data ?? [];
                    return InputDecorator(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        suffixIcon: _linkedProduct != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    setState(() => _linkedProduct = null),
                              )
                            : const Icon(Icons.arrow_drop_down),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ItemModel>(
                          isExpanded: true,
                          value: _linkedProduct,
                          hint: const Text('Select product this contractor makes'),
                          items: products
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.name),
                                  ))
                              .toList(),
                          onChanged: (p) =>
                              setState(() => _linkedProduct = p),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'When a manufacturing batch runs for the linked product, '
                  'earnings are auto-calculated.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEditing ? 'Update Worker' : 'Save Worker'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final worker = WorkerModel(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        role: _role.text.trim(),
        type: _type,
        dailyWage: _type == 'daily_wage'
            ? double.tryParse(_dailyWage.text)
            : null,
        ratePerUnit: _type == 'contractor'
            ? double.tryParse(_ratePerUnit.text)
            : null,
        linkedProductId: _type == 'contractor' ? _linkedProduct?.id : null,
        linkedProductName: _type == 'contractor' ? _linkedProduct?.name : null,
        isActive: widget.existing?.isActive ?? true,
        createdAt: widget.existing?.createdAt,
      );
      await svc.saveWorker(worker);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
