import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/sale_model.dart';
import '../models/purchase_model.dart';
import 'company_service.dart';

class PdfService {
  static final PdfService _i = PdfService._();
  factory PdfService() => _i;
  PdfService._();

  // ── Company details (read from active company) ───────────────
  String get _companyName    => CompanyService.instance.activeCompany?.name ?? '';
  String get _companyAddress => CompanyService.instance.activeCompany?.address ?? '';
  String get _companyPhone   => CompanyService.instance.activeCompany?.phone ?? '';
  String get _companyGST     => CompanyService.instance.activeCompany?.gstNumber ?? '';

  final cf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final df = DateFormat('dd/MM/yyyy');

  // ── SALE INVOICE ─────────────────────────────────────────────

  Future<pw.ThemeData> _theme() async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    return pw.ThemeData.withFont(base: base, bold: bold);
  }

  Future<Uint8List> buildSaleInvoice(SaleModel sale) async {
    final pdf = pw.Document();
    final theme = await _theme();
    pdf.addPage(pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _letterhead('TAX INVOICE'),
          pw.SizedBox(height: 8),
          _divider(),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Text(sale.partyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                if (sale.partyFirm != null && sale.partyFirm!.isNotEmpty)
                  pw.Text(sale.partyFirm!, style: const pw.TextStyle(fontSize: 10)),
                if (sale.partyPhone != null)
                  pw.Text('Ph: ${sale.partyPhone}', style: const pw.TextStyle(fontSize: 10)),
              ],
            )),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kv('Invoice No.', sale.invoiceNo),
                _kv('Date', df.format(sale.date)),
                if (sale.dueDate != null) _kv('Due Date', df.format(sale.dueDate!)),
                _kv('Payment', sale.paymentType),
              ],
            )),
          ]),
          pw.SizedBox(height: 12),
          _divider(),
          pw.SizedBox(height: 6),
          _itemsTable(sale.items.map((i) => _ItemRow(
            i.itemName, i.qty.toString(), i.unit,
            cf.format(i.priceExclTax),
            '${i.discountPercent}%', '${i.taxPercent}%',
            cf.format(i.lineTotal),
          )).toList()),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              _totalRow('Subtotal', cf.format(sale.subtotal)),
              if (sale.totalDiscount > 0) _totalRow('Discount', '- ${cf.format(sale.totalDiscount)}'),
              if (sale.totalTax > 0) _totalRow('Tax', '+ ${cf.format(sale.totalTax)}'),
              pw.SizedBox(height: 4),
              _totalRow('TOTAL', cf.format(sale.totalAmount), bold: true),
              pw.SizedBox(height: 2),
              _totalRow('Amount Paid', cf.format(sale.amountPaid)),
              if (sale.balanceDue > 0.01)
                _totalRow('Balance Due', cf.format(sale.balanceDue), color: PdfColors.red700),
            ]),
          ]),
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notes: ${sale.notes}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 16),
          _divider(),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Thank you for your business!',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.SizedBox(height: 28),
              pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
        ],
      ),
    ));
    return pdf.save();
  }

  // ── PURCHASE BILL ────────────────────────────────────────────

  Future<Uint8List> buildPurchaseBill(PurchaseModel purchase) async {
    final pdf = pw.Document();
    final theme = await _theme();
    pdf.addPage(pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _letterhead('PURCHASE BILL'),
          pw.SizedBox(height: 8),
          _divider(),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Supplier:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Text(purchase.partyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                if (purchase.partyFirm != null && purchase.partyFirm!.isNotEmpty)
                  pw.Text(purchase.partyFirm!, style: const pw.TextStyle(fontSize: 10)),
                if (purchase.partyPhone != null)
                  pw.Text('Ph: ${purchase.partyPhone}', style: const pw.TextStyle(fontSize: 10)),
              ],
            )),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kv('Bill No.', purchase.billNo),
                _kv('Date', df.format(purchase.date)),
                _kv('Payment', purchase.paymentType),
              ],
            )),
          ]),
          pw.SizedBox(height: 12),
          _divider(),
          pw.SizedBox(height: 6),
          _itemsTable(purchase.items.map((i) => _ItemRow(
            i.itemName, i.qty.toString(), i.unit,
            cf.format(i.priceExclTax),
            '${i.discountPercent}%', '${i.taxPercent}%',
            cf.format(i.lineTotal),
          )).toList()),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              _totalRow('Subtotal', cf.format(purchase.subtotal)),
              if (purchase.totalDiscount > 0) _totalRow('Discount', '- ${cf.format(purchase.totalDiscount)}'),
              if (purchase.totalTax > 0) _totalRow('Tax', '+ ${cf.format(purchase.totalTax)}'),
              pw.SizedBox(height: 4),
              _totalRow('TOTAL', cf.format(purchase.totalAmount), bold: true),
              _totalRow('Amount Paid', cf.format(purchase.amountPaid)),
              if (purchase.balanceDue > 0.01)
                _totalRow('Balance Due', cf.format(purchase.balanceDue), color: PdfColors.red700),
            ]),
          ]),
          if (purchase.notes != null && purchase.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notes: ${purchase.notes}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ],
      ),
    ));
    return pdf.save();
  }

  // ── Print & Share helpers ────────────────────────────────────

  Future<void> printBytes(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> shareAsPdf(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }

  // ── Private helpers ──────────────────────────────────────────

  pw.Widget _letterhead(String docType) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_companyName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900)),
          if (_companyAddress.isNotEmpty)
            pw.Text(_companyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          if (_companyPhone.isNotEmpty)
            pw.Text(_companyPhone, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          if (_companyGST.isNotEmpty)
            pw.Text('GSTIN: $_companyGST', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue900,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(docType,
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  pw.Widget _divider() =>
      pw.Divider(color: PdfColors.grey300, thickness: 0.5);

  pw.Widget _kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text('$k: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ]),
  );

  pw.Widget _itemsTable(List<_ItemRow> rows) {
    const cellStyle = pw.TextStyle(fontSize: 9);
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
        6: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: ['Item', 'Qty', 'Unit', 'Rate', 'Disc%', 'Tax%', 'Amount']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ))
              .toList(),
        ),
        ...rows.map((r) => pw.TableRow(children: [
          r.name, r.qty, r.unit, r.rate, r.disc, r.tax, r.amount
        ].map((v) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(v, style: cellStyle),
        )).toList())),
      ],
    );
  }

  pw.Widget _totalRow(String label, String value,
      {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(width: 100,
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          )),
        ]),
      );
}

class _ItemRow {
  final String name, qty, unit, rate, disc, tax, amount;
  const _ItemRow(this.name, this.qty, this.unit, this.rate, this.disc, this.tax, this.amount);
}