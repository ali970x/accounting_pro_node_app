import "dart:typed_data";

import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "../../models/invoice_template.dart";
import "../../models/sale.dart";
import "../money.dart";

class PdfService {
  static PdfColor colorFromHex(String hex) {
    var h = hex.replaceAll("#", "");
    if (h.length != 6) h = "4F46E5";
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16) / 255,
      int.parse(h.substring(2, 4), radix: 16) / 255,
      int.parse(h.substring(4, 6), radix: 16) / 255,
    );
  }

  static Future<void> printInvoice({
    required String languageCode,
    required Sale sale,
    required InvoiceTemplateModel template,
  }) async {
    final bytes = await _invoiceBytes(languageCode: languageCode, sale: sale, template: template);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareInvoice({
    required String languageCode,
    required Sale sale,
    required InvoiceTemplateModel template,
  }) async {
    final bytes = await _invoiceBytes(languageCode: languageCode, sale: sale, template: template);
    await Printing.sharePdf(bytes: bytes, filename: "${sale.invoiceNo}.pdf");
  }

  static Future<Uint8List> _invoiceBytes({
    required String languageCode,
    required Sale sale,
    required InvoiceTemplateModel template,
  }) async {
    final isArabic = languageCode == "ar";
    final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      ),
    );
    final primary = colorFromHex(template.colorHex);

    pw.ImageProvider? logo;
    if (template.showLogo && template.logoUrl.trim().isNotEmpty) {
      try {
        logo = await networkImage(template.logoUrl.trim());
      } catch (_) {
        logo = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _header(template, primary, logo, isArabic),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(18),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _text(template.invoiceTitle, isArabic, size: 25, bold: true),
                        pw.SizedBox(height: 12),
                        _labelValue(isArabic ? "\u0631\u0642\u0645 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629" : "Invoice No.", sale.invoiceNo, isArabic),
                        _labelValue(isArabic ? "\u0641\u0627\u062a\u0648\u0631\u0629 \u0625\u0644\u0649" : "Bill To", sale.customerName, isArabic),
                        pw.SizedBox(height: 20),
                        _itemsTable(sale, isArabic),
                        pw.SizedBox(height: 22),
                        pw.Align(
                          alignment: isArabic ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                          child: _text("${isArabic ? "\u0627\u0644\u0645\u062c\u0645\u0648\u0639" : "Total"}: ${money(sale.total, sale.currency)}", isArabic, size: 18, bold: true),
                        ),
                        if (template.footerNote.isNotEmpty) ...[
                          pw.SizedBox(height: 18),
                          _text(template.footerNote, isArabic),
                        ],
                        if (template.terms.isNotEmpty) ...[
                          pw.SizedBox(height: 10),
                          _text(template.terms, isArabic, size: 10),
                        ],
                        if (template.showSignature) ...[
                          pw.SizedBox(height: 38),
                          pw.Align(
                            alignment: isArabic ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                            child: _text("____________________\n${isArabic ? "\u0627\u0644\u062a\u0648\u0642\u064a\u0639" : "Signature"}", isArabic, align: pw.TextAlign.center),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> printGoodsMovementInvoice({
    required String languageCode,
    required String contactName,
    required String contactType,
    required List<Map<String, dynamic>> movements,
    required InvoiceTemplateModel template,
  }) async {
    final bytes = await _goodsMovementInvoiceBytes(
      languageCode: languageCode,
      contactName: contactName,
      contactType: contactType,
      movements: movements,
      template: template,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareGoodsMovementInvoice({
    required String languageCode,
    required String contactName,
    required String contactType,
    required List<Map<String, dynamic>> movements,
    required InvoiceTemplateModel template,
  }) async {
    final bytes = await _goodsMovementInvoiceBytes(
      languageCode: languageCode,
      contactName: contactName,
      contactType: contactType,
      movements: movements,
      template: template,
    );
    await Printing.sharePdf(bytes: bytes, filename: "goods-movement-$contactName.pdf");
  }

  static Future<Uint8List> _goodsMovementInvoiceBytes({
    required String languageCode,
    required String contactName,
    required String contactType,
    required List<Map<String, dynamic>> movements,
    required InvoiceTemplateModel template,
  }) async {
    final isArabic = languageCode == "ar";
    final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      ),
    );
    final primary = colorFromHex(template.colorHex);

    pw.ImageProvider? logo;
    if (template.showLogo && template.logoUrl.trim().isNotEmpty) {
      try {
        logo = await networkImage(template.logoUrl.trim());
      } catch (_) {
        logo = null;
      }
    }

    final totals = _movementTotals(movements);
    final now = DateTime.now();
    final invoiceNo = "GM-${now.millisecondsSinceEpoch.toString().substring(5)}";
    final invoiceType = isArabic ? "فاتورة باسم $contactName" : "Invoice for $contactName";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _header(template, primary, logo, isArabic),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(18),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _text(invoiceType, isArabic, size: 25, bold: true),
                        pw.SizedBox(height: 12),
                        _labelValue(isArabic ? "رقم الفاتورة" : "Invoice No.", invoiceNo, isArabic),
                        _labelValue(isArabic ? "الاسم" : "Name", contactName, isArabic),
                        _labelValue(isArabic ? "النوع" : "Type", invoiceType, isArabic),
                        _labelValue(isArabic ? "صفة الشخص" : "Contact role", contactType == "supplier" ? (isArabic ? "مورد" : "Supplier") : (isArabic ? "زبون" : "Customer"), isArabic),
                        _labelValue(isArabic ? "التاريخ" : "Date", _dateText(now), isArabic),
                        pw.SizedBox(height: 20),
                        _movementItemsTable(movements, isArabic),
                        pw.SizedBox(height: 22),
                        pw.Align(
                          alignment: isArabic ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                          child: pw.Column(
                            crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                            children: [
                              _text("${isArabic ? "الإجمالي باللبناني" : "Total LBP"}: ${money(totals["LBP"] ?? 0, "LBP")}", isArabic, size: 16, bold: true),
                              _text("${isArabic ? "الإجمالي بالدولار" : "Total USD"}: ${money(totals["USD"] ?? 0, "USD")}", isArabic, size: 16, bold: true),
                            ],
                          ),
                        ),
                        if (template.footerNote.isNotEmpty) ...[
                          pw.SizedBox(height: 18),
                          _text(template.footerNote, isArabic),
                        ],
                        if (template.terms.isNotEmpty) ...[
                          pw.SizedBox(height: 10),
                          _text(template.terms, isArabic, size: 10),
                        ],
                        if (template.showSignature) ...[
                          pw.SizedBox(height: 38),
                          pw.Align(
                            alignment: isArabic ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                            child: _text("____________________\n${isArabic ? "التوقيع" : "Signature"}", isArabic, align: pw.TextAlign.center),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header(InvoiceTemplateModel template, PdfColor primary, pw.ImageProvider? logo, bool isArabic) {
    return pw.Container(
      width: double.infinity,
      color: primary,
      padding: const pw.EdgeInsets.all(18),
      child: pw.Row(
        children: [
          if (template.showLogo)
            pw.Container(
              width: 58,
              height: 58,
              color: PdfColors.white,
              child: logo == null ? _cargoLogo(primary) : pw.Image(logo, fit: pw.BoxFit.cover),
            ),
          if (template.showLogo) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
              children: [
                _text(template.businessName, isArabic, color: PdfColors.white, size: 22, bold: true),
                if (template.businessPhone.isNotEmpty) _text(template.businessPhone, isArabic, color: PdfColors.white),
                if (template.businessAddress.isNotEmpty) _text(template.businessAddress, isArabic, color: PdfColors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cargoLogo(PdfColor primary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(width: 25, height: 18, decoration: pw.BoxDecoration(color: primary, borderRadius: pw.BorderRadius.circular(2))),
              pw.Container(width: 12, height: 13, decoration: pw.BoxDecoration(color: const PdfColor(0.05, 0.45, 0.28), borderRadius: pw.BorderRadius.circular(2))),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 7, height: 7, decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 22),
              pw.Container(width: 7, height: 7, decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text("LB", style: pw.TextStyle(color: const PdfColor(0.75, 0.05, 0.08), fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(Sale sale, bool isArabic) {
    final headers = [
      isArabic ? "\u0627\u0644\u0645\u0646\u062a\u062c" : "Product",
      isArabic ? "\u0627\u0644\u0643\u0645\u064a\u0629" : "Qty",
      isArabic ? "\u0633\u0639\u0631 \u0627\u0644\u0648\u062d\u062f\u0629" : "Unit Price",
      isArabic ? "\u0627\u0644\u0645\u062c\u0645\u0648\u0639" : "Total",
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.6),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) => _cell(h, isArabic, true)).toList(),
        ),
        ...sale.items.map((i) => pw.TableRow(children: [
              _cell(i.productName, isArabic, false),
              _cell(number(i.quantity), isArabic, false),
              _cell(money(i.unitPrice, i.currency), isArabic, false),
              _cell(money(i.total, i.currency), isArabic, false),
            ])),
      ],
    );
  }

  static pw.Widget _movementItemsTable(List<Map<String, dynamic>> movements, bool isArabic) {
    final headers = [
      isArabic ? "التاريخ" : "Date",
      isArabic ? "الحركة" : "Movement",
      isArabic ? "البضاعة" : "Item",
      isArabic ? "الكمية" : "Qty",
      isArabic ? "الفاتورة" : "Invoice",
      isArabic ? "المبلغ" : "Amount",
    ];

    if (movements.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: _text(isArabic ? "لا يوجد حركة بضاعة بعد." : "No goods movement yet.", isArabic),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.25),
        1: pw.FlexColumnWidth(1.05),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(0.8),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.45),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) => _cell(h, isArabic, true)).toList(),
        ),
        ...movements.map((row) {
          final currency = (row["currency"] ?? "LBP").toString();
          final total = _num(row["totalCost"]);
          return pw.TableRow(children: [
            _cell(_shortDate(row["createdAt"]), isArabic, false),
            _cell(_movementTypeLabel((row["type"] ?? "").toString(), isArabic), isArabic, false),
            _cell((row["productName"] ?? "").toString(), isArabic, false),
            _cell(number(_num(row["difference"]).abs()), isArabic, false),
            _cell((row["invoiceNo"] ?? "").toString(), isArabic, false),
            _cell(total > 0 ? money(total, currency) : "-", isArabic, false),
          ]);
        }),
      ],
    );
  }

  static Map<String, double> _movementTotals(List<Map<String, dynamic>> movements) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final row in movements) {
      final currency = (row["currency"] ?? "LBP").toString() == "USD" ? "USD" : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _num(row["totalCost"]);
    }
    return totals;
  }

  static String _movementTypeLabel(String type, bool isArabic) {
    if (type == "purchase") return isArabic ? "توريد" : "Purchase";
    if (type == "return") return isArabic ? "مرتجع" : "Return";
    if (type == "adjustment") return isArabic ? "تعديل" : "Adjustment";
    return isArabic ? "مبيع" : "Sale";
  }

  static String _dateText(DateTime value) {
    final y = value.year.toString().padLeft(4, "0");
    final m = value.month.toString().padLeft(2, "0");
    final d = value.day.toString().padLeft(2, "0");
    final h = value.hour.toString().padLeft(2, "0");
    final min = value.minute.toString().padLeft(2, "0");
    return "$y-$m-$d $h:$min";
  }

  static String _shortDate(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? "").toString())?.toLocal();
    if (parsed != null) return _dateText(parsed);
    final text = (raw ?? "").toString();
    if (text.isEmpty) return "-";
    return text.substring(0, text.length < 16 ? text.length : 16).replaceFirst("T", " ");
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static pw.Widget _labelValue(String label, String value, bool isArabic) {
    return _text("$label: $value", isArabic);
  }

  static pw.Widget _cell(String text, bool isArabic, bool bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: _text(text, isArabic, bold: bold, align: isArabic ? pw.TextAlign.right : pw.TextAlign.left),
    );
  }

  static pw.Widget _text(
    String text,
    bool isArabic, {
    double? size,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign? align,
  }) {
    return pw.Text(
      text,
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: align ?? (isArabic ? pw.TextAlign.right : pw.TextAlign.left),
      style: pw.TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }
}
