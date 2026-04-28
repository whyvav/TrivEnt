import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/bom_model.dart';
import '../../theme.dart';

class ManufactureDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;
  const ManufactureDetailScreen({super.key, required this.record});

  @override
  State<ManufactureDetailScreen> createState() => _ManufactureDetailScreenState();
}

class _ManufactureDetailScreenState extends State<ManufactureDetailScreen> {
  final _svc = FirestoreService();
  BomModel? _bom;
  bool _bomLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBom();
  }

  Future<void> _loadBom() async {
    final snapshot = widget.record['bomSnapshot'] as Map<String, dynamic>?;
    if (snapshot != null) {
      setState(() {
        _bom = BomModel(
          id: '',
          productId: widget.record['productId'] as String? ?? '',
          productName: widget.record['productName'] as String? ?? '',
          materials: (snapshot['materials'] as List? ?? [])
              .map((m) => BomMaterial.fromMap(m as Map<String, dynamic>))
              .toList(),
          otherCosts: (snapshot['otherCosts'] as List? ?? [])
              .map((c) => BomOtherCost.fromMap(c as Map<String, dynamic>))
              .toList(),
        );
        _bomLoading = false;
      });
      return;
    }

    final productId = widget.record['productId'] as String? ?? '';
    if (productId.isNotEmpty) {
      final bom = await _svc.getBomForProduct(productId);
      if (mounted) setState(() { _bom = bom; _bomLoading = false; });
    } else {
      if (mounted) setState(() => _bomLoading = false);
    }
  }

  String _fmtQty(double q) =>
      q.truncateToDouble() == q ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    final id = widget.record['id'] as String? ?? '';
    final name = widget.record['productName'] as String? ?? '';
    final qty = (widget.record['qty'] as num?)?.toDouble() ?? 0;
    final costPerUnit = (widget.record['costPerUnit'] as num?)?.toDouble() ?? 0;
    final totalCost = (widget.record['totalCost'] as num?)?.toDouble() ?? 0;
    final salePrice = (widget.record['salePrice'] as num?)?.toDouble() ?? 0;
    final totalValue = (widget.record['totalValue'] as num?)?.toDouble() ?? 0;
    final date = widget.record['date'] != null
        ? DateTime.tryParse(widget.record['date'] as String)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Production: $name'),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit_date',
                child: Row(children: [
                  Icon(Icons.edit_calendar_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Edit Date'),
                ]),
              ),
              const PopupMenuItem(
                value: 'edit_qty',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Edit Quantity'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit_date') {
                _editDate(id, date ?? DateTime.now());
              } else if (value == 'edit_qty') {
                _editQty(id, qty, salePrice, costPerUnit);
              } else if (value == 'delete') {
                _confirmDelete(id, name, qty);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.precision_manufacturing, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (date != null)
                            Text(df.format(date),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      )),
                    ]),
                    const Divider(height: 24),
                    _SummaryRow('Quantity Manufactured', '${_fmtQty(qty)} units', bold: true),
                    const SizedBox(height: 6),
                    _SummaryRow('Sale Price / unit', cf.format(salePrice)),
                    const SizedBox(height: 6),
                    _SummaryRow('Total Value', cf.format(totalValue),
                        valueColor: AppTheme.receivable, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Cost Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            if (_bomLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_bom == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    const Text('No Bill of Materials found.',
                        style: TextStyle(color: Colors.grey)),
                  ]),
                ),
              )
            else ...[
              // Materials card
              if (_bom!.materials.isNotEmpty) ...[
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Raw Materials',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                                fontSize: 13)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(children: [
                          Expanded(flex: 4, child: Text('Material',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 2, child: Text('Used',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 2, child: Text('Rate',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 3, child: Text('Amount',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ]),
                      ),
                      const Divider(height: 1),
                      ..._bom!.materials.map((m) {
                        final used = m.qtyPerUnit * qty;
                        final amount = m.pricePerUnit * used;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(children: [
                            Expanded(flex: 4, child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.materialName, style: const TextStyle(fontSize: 13)),
                                Text('${_fmtQty(m.qtyPerUnit)} ${m.unit}/unit',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            )),
                            Expanded(flex: 2, child: Text(
                              _fmtQty(used),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            )),
                            Expanded(flex: 2, child: Text(
                              '₹${m.pricePerUnit.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            )),
                            Expanded(flex: 3, child: Text(
                              cf.format(amount),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            )),
                          ]),
                        );
                      }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Materials subtotal',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                    fontSize: 12)),
                            Text(cf.format(_bom!.totalMaterialCost * qty),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Other costs card
              if (_bom!.otherCosts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Other Costs',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                                fontSize: 13)),
                      ),
                      const Divider(height: 1),
                      ..._bom!.otherCosts.map((c) {
                        final total = c.costPerUnit * qty;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(children: [
                            Expanded(flex: 5, child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.type, style: const TextStyle(fontSize: 13)),
                                Text('₹${c.costPerUnit.toStringAsFixed(2)} / ${c.unit}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            )),
                            Expanded(flex: 4, child: Text(
                              cf.format(total),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            )),
                          ]),
                        );
                      }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Other costs subtotal',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                    fontSize: 12)),
                            Text(cf.format(_bom!.totalOtherCost * qty),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Grand total
              Card(
                color: AppTheme.primary.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Manufacturing Cost',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${costPerUnit.toStringAsFixed(2)} / unit',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                      Text(
                        cf.format(totalCost),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.payable),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editDate(String id, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      try {
        await _svc.updateManufactureDate(id, picked);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Date updated')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _editQty(
      String id, double currentQty, double salePrice, double costPerUnit) async {
    final controller = TextEditingController(text: _fmtQty(currentQty));
    final productName = widget.record['productName'] as String? ?? '';
    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(productName, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'New Quantity',
              suffixText: 'units',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stock for product and raw materials will be adjusted automatically.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text) ?? 0;
              if (v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newQty != null && newQty != currentQty && mounted) {
      try {
        await _svc.updateManufactureQty(
          recordId: id,
          oldQty: currentQty,
          newQty: newQty,
          salePrice: salePrice,
          costPerUnit: costPerUnit,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quantity updated and stocks adjusted')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5)));
        }
      }
    }
  }

  void _confirmDelete(String id, String name, double qty) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Production Record?'),
        content: Text(
          'This will reverse all stock changes for '
          '${_fmtQty(qty)} units of $name.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _svc.deleteManufactureRecord(id);
                if (mounted) Navigator.pop(context, true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5)));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
