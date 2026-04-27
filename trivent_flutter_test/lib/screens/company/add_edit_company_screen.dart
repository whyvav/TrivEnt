import 'package:flutter/material.dart';
import '../../models/company_model.dart';
import '../../services/company_service.dart';

class AddEditCompanyScreen extends StatefulWidget {
  final CompanyModel? company; // null → add, non-null → edit

  const AddEditCompanyScreen({super.key, this.company});

  @override
  State<AddEditCompanyScreen> createState() => _AddEditCompanyScreenState();
}

class _AddEditCompanyScreenState extends State<AddEditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _gst;
  bool _saving = false;

  bool get _isEditing => widget.company != null;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _name    = TextEditingController(text: c?.name ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _phone   = TextEditingController(text: c?.phone ?? '');
    _gst     = TextEditingController(text: c?.gstNumber ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _gst.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await CompanyService.instance.updateCompany(
          widget.company!.copyWith(
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            gstNumber: _gst.text.trim(),
          ),
        );
      } else {
        await CompanyService.instance.addCompany(
          name: _name.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          gstNumber: _gst.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Company' : 'Add Company'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'e.g. Triveni Enterprises',
                  prefixIcon: Icon(Icons.business),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Full address printed on invoices',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'e.g. +91 99185 13605',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gst,
                decoration: const InputDecoration(
                  labelText: 'GSTIN',
                  hintText: 'e.g. 09BUWPS2265Q2ZA',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Create Company'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
