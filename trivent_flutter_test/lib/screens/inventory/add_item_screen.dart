import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/item_model.dart';
import '../../models/unit_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../models/stock_transaction_model.dart';

class AddItemScreen extends StatefulWidget {
  final String defaultCategory;
  final ItemModel? existing;
  const AddItemScreen({super.key, this.defaultCategory = 'product', this.existing});
  @override State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final svc = FirestoreService();

  late String _category;
  final _name = TextEditingController();
  final _itemCode = TextEditingController();
  final _description = TextEditingController();
  final _hsn = TextEditingController();

  UnitModel? _primaryUnit;
  UnitModel? _secondaryUnit;
  final _conversionFactor = TextEditingController();

  final _salePrice = TextEditingController();
  bool _salePriceWithTax = false;
  final _purchasePrice = TextEditingController();
  bool _purchasePriceWithTax = false;
  double _taxPercent = 0;

  final _openingStock = TextEditingController();
  final _minStock = TextEditingController();
  DateTime _stockAsOfDate = DateTime.now();
  final _stockAtPrice = TextEditingController();
  final _itemLocation = TextEditingController();

  List<UnitModel> _allUnits = [];
  bool _saving = false;
  bool _loadingUnits = true;

  final _taxOptions = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _category = widget.defaultCategory;
    _loadUnits();
    if (widget.existing != null) _populateFromExisting();
  }

  void _populateFromExisting() {
    final e = widget.existing!;
    _name.text = e.name;
    _itemCode.text = e.itemCode ?? '';
    _description.text = e.description ?? '';
    _hsn.text = e.hsn ?? '';
    _category = e.category;
    _salePrice.text = e.salePrice.toString();
    _salePriceWithTax = e.salePriceWithTax;
    _purchasePrice.text = e.purchasePrice.toString();
    _purchasePriceWithTax = e.purchasePriceWithTax;
    _taxPercent = e.taxPercent;
    _openingStock.text = e.stockQty.toString();
    _minStock.text = e.minStockAlert.toString();
    _stockAsOfDate = e.stockAsOfDate ?? DateTime.now();
    _stockAtPrice.text = e.stockAtPrice.toString();
    _itemLocation.text = e.itemLocation ?? '';
    if (e.conversionFactor != null) {
      _conversionFactor.text = e.conversionFactor.toString();
    }
  }

  Future<void> _loadUnits() async {
    final units = await svc.getAllUnits();
    setState(() {
      _allUnits = units;
      _loadingUnits = false;
      if (widget.existing != null) {
        _primaryUnit = units.firstWhere(
          (u) => u.shortName == widget.existing!.primaryUnit ||
                 u.id == widget.existing!.primaryUnit,
          orElse: () => units.first,
        );
        if (widget.existing!.secondaryUnit != null) {
          _secondaryUnit = units.firstWhere(
            (u) => u.shortName == widget.existing!.secondaryUnit ||
                   u.id == widget.existing!.secondaryUnit,
            orElse: () => units.first,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Item' : 'Add Item')),
      body: _loadingUnits
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionHeader('Category'),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      ChoiceChip(label: const Text('Product'),
                          selected: _category == 'product',
                          onSelected: (_) => setState(() => _category = 'product'),
                          selectedColor: AppTheme.primary.withOpacity(0.2)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('Raw Material'),
                          selected: _category == 'raw_material',
                          onSelected: (_) => setState(() => _category = 'raw_material'),
                          selectedColor: AppTheme.accent.withOpacity(0.2)),
                    ]),
                  )),
                  const SizedBox(height: 16),

                  _sectionHeader('Item Details'),
                  TextFormField(controller: _name,
                      decoration: const InputDecoration(labelText: 'Item Name *'),
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _itemCode,
                        decoration: const InputDecoration(labelText: 'Item Code'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _hsn,
                        decoration: const InputDecoration(labelText: 'HSN Code'))),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(controller: _description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2),
                  const SizedBox(height: 16),

                  _sectionHeader('Units'),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _UnitDropdown(
                      label: 'Primary Unit *',
                      value: _primaryUnit,
                      units: _allUnits,
                      onChanged: (u) => setState(() { _primaryUnit = u; _secondaryUnit = null; }),
                      onAddNew: _addNewUnit,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _UnitDropdown(
                      label: 'Secondary Unit (optional)',
                      value: _secondaryUnit,
                      units: _primaryUnit != null
                          ? _allUnits.where((u) => u.id != _primaryUnit!.id).toList()
                          : [],
                      enabled: _primaryUnit != null,
                      onChanged: (u) => setState(() => _secondaryUnit = u),
                      onAddNew: _addNewUnit,
                    )),
                  ]),
                  if (_secondaryUnit != null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _conversionFactor,
                      decoration: InputDecoration(
                        labelText:
                            '1 ${_primaryUnit?.shortName ?? ''} = ? ${_secondaryUnit?.shortName ?? ''}',
                        hintText: 'e.g. 33 (if 1 bag = 33 kg)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 16),

                  _sectionHeader('Pricing'),
                  Row(children: [
                    Expanded(child: _PriceField(
                      controller: _salePrice,
                      label: 'Sale Price',
                      withTax: _salePriceWithTax,
                      onWithTaxChanged: (v) => setState(() => _salePriceWithTax = v),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _PriceField(
                      controller: _purchasePrice,
                      label: 'Purchase Price',
                      withTax: _purchasePriceWithTax,
                      onWithTaxChanged: (v) => setState(() => _purchasePriceWithTax = v),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Text('Tax: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    ..._taxOptions.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$t%', style: const TextStyle(fontSize: 12)),
                        selected: _taxPercent == t,
                        onSelected: (_) => setState(() => _taxPercent = t),
                        selectedColor: AppTheme.primary.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )).toList(),
                  ]),
                  const SizedBox(height: 16),

                  _sectionHeader('Stock Details'),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _openingStock,
                        decoration: const InputDecoration(labelText: 'Opening Stock Qty'),
                        keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _minStock,
                        decoration: const InputDecoration(labelText: 'Min Stock Alert'),
                        keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _stockAsOfDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _stockAsOfDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'As of Date'),
                        child: Text(DateFormat('dd MMM yyyy').format(_stockAsOfDate)),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _stockAtPrice,
                        decoration: const InputDecoration(
                            labelText: 'At Price / Unit (₹)', prefixText: '₹'),
                        keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(controller: _itemLocation,
                      decoration: const InputDecoration(
                          labelText: 'Item Location', hintText: 'e.g. Warehouse A, Shelf 3')),
                  const SizedBox(height: 24),

                  SizedBox(width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEditing ? 'Update Item' : 'Save Item'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Future<void> _addNewUnit() async {
    String fullName = '', shortName = '';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Custom Unit'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Full Name (e.g. Kilogram)'),
            onChanged: (v) => fullName = v,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: 'Short Name (e.g. kg)'),
            onChanged: (v) => shortName = v,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (fullName.isEmpty || shortName.isEmpty) return;
              final unit = await svc.addCustomUnit(fullName, shortName);
              Navigator.pop(context);
              if (unit == null) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unit name already exists!')));
              } else {
                await _loadUnits();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_primaryUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a primary unit')));
      return;
    }
    setState(() => _saving = true);
    try {
      final item = ItemModel(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        primaryUnit: _primaryUnit!.shortName,
        secondaryUnit: _secondaryUnit?.shortName,
        conversionFactor: _secondaryUnit != null
            ? double.tryParse(_conversionFactor.text)
            : null,
        itemCode: _itemCode.text.isEmpty ? null : _itemCode.text.trim(),
        description: _description.text.isEmpty ? null : _description.text.trim(),
        hsn: _hsn.text.isEmpty ? null : _hsn.text.trim(),
        salePrice: double.tryParse(_salePrice.text) ?? 0,
        salePriceWithTax: _salePriceWithTax,
        purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
        purchasePriceWithTax: _purchasePriceWithTax,
        taxPercent: _taxPercent,
        stockQty: double.tryParse(_openingStock.text) ?? 0,
        minStockAlert: double.tryParse(_minStock.text) ?? 0,
        stockAsOfDate: _stockAsOfDate,
        stockAtPrice: double.tryParse(_stockAtPrice.text) ?? 0,
        itemLocation: _itemLocation.text.isEmpty ? null : _itemLocation.text.trim(),
        createdAt: widget.existing?.createdAt,
      );
      if (widget.existing == null) {
        await svc.saveItem(item);
        // Log opening stock transaction
        if (item.stockQty > 0) {
          await svc.logStockTx(StockTransactionModel(
            id: 'opening_${item.id}',
            itemId: item.id, itemName: item.name,
            type: 'Opening Stock', quantity: item.stockQty,
            pricePerUnit: item.stockAtPrice, date: item.stockAsOfDate ?? DateTime.now(),
            notes: 'Opening stock on creation',
          ));
        }
      } else {
        final oldQty = widget.existing!.stockQty;
        await svc.updateItem(item);
        if ((item.stockQty - oldQty).abs() > 0.001) {
          await svc.logStockTx(StockTransactionModel(
            id: 'edit_${item.id}_${DateTime.now().millisecondsSinceEpoch}',
            itemId: item.id, itemName: item.name,
            type: 'Adjusted', quantity: item.stockQty - oldQty,
            pricePerUnit: item.stockAtPrice, date: _stockAsOfDate,
            notes: 'Stock updated via item edit',
          ));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.existing == null ? 'Item saved!' : 'Updated!'),
                backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: Colors.grey.shade600, letterSpacing: 0.5)),
  );
}

// ── Helper widgets ──────────────────────────────────────────────

class _UnitDropdown extends StatelessWidget {
  final String label;
  final UnitModel? value;
  final List<UnitModel> units;
  final bool enabled;
  final void Function(UnitModel?) onChanged;
  final VoidCallback onAddNew;
  const _UnitDropdown({required this.label, required this.value,
      required this.units, this.enabled = true,
      required this.onChanged, required this.onAddNew});

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label,
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200))),
        child: Text('Select primary first',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      );
    }
    return DropdownButtonFormField<UnitModel?>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<UnitModel?>(
          value: null,
          child: Row(children: [
            Icon(Icons.add_circle_outline, size: 16, color: AppTheme.primary),
            SizedBox(width: 6),
            Text('+ Add new unit', style: TextStyle(color: AppTheme.primary)),
          ]),
        ),
        ...units.map((u) => DropdownMenuItem<UnitModel?>(
          value: u,
          child: Text(u.display, overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (v) {
        if (v == null) {
          onAddNew();
        } else {
          onChanged(v);
        }
      },
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool withTax;
  final void Function(bool) onWithTaxChanged;
  const _PriceField({required this.controller, required this.label,
      required this.withTax, required this.onWithTaxChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: '$label (₹)', prefixText: '₹'),
        keyboardType: TextInputType.number,
      ),
      Row(children: [
        const SizedBox(width: 4),
        Text('with tax', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(width: 4),
        Switch(
          value: withTax,
          onChanged: onWithTaxChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(withTax ? 'incl. tax' : 'excl. tax',
            style: TextStyle(fontSize: 11,
                color: withTax ? AppTheme.primary : Colors.grey.shade500)),
      ]),
    ]);
  }
}