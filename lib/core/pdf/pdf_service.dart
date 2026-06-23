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

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
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
              _cell(i.quantity.toStringAsFixed(0), isArabic, false),
              _cell(money(i.unitPrice, i.currency), isArabic, false),
              _cell(money(i.total, i.currency), isArabic, false),
            ])),
      ],
    );
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
