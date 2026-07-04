import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/contact.dart";
import "../../widgets/date_filter_bar.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class DebtsPage extends StatefulWidget {
  final ApiClient api;
  const DebtsPage({super.key, required this.api});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _debts = [];
  List<ContactModel> _contacts = [];
  final _search = TextEditingController();
  DateFilterValue _dateFilter = const DateFilterValue(
    preset: DateFilterPreset.month,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.get("/debts"),
        widget.api.get("/contacts"),
      ]);

      final res = results[0];
      _debts = (res as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final cData = results[1];
      _contacts = (cData as List)
          .map(
            (e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((c) => c.type == "supplier" || c.type == "customer")
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addOrEdit({Map<String, dynamic>? debt}) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DebtDialog(debt: debt, contacts: _contacts),
    );
    if (body == null) return;

    try {
      if (debt == null) {
        await widget.api.post("/debts", body);
      } else {
        await widget.api.put("/debts/${debt["_id"]}", body);
      }
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addPayment(Map<String, dynamic> debt) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _PaymentDialog(currency: (debt["currency"] ?? "LBP").toString()),
    );
    if (body == null) return;

    try {
      await widget.api.post("/debts/${debt["_id"]}/payments", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showLedger(
    Map<String, dynamic> debt, {
    List<Map<String, dynamic>>? rowsOverride,
  }) async {
    final contactId = _contactIdForDebt(debt);
    final name = (debt["personName"] ?? "").toString();
    final source = rowsOverride ?? _filteredDebts();
    var rows = source.where((d) {
      final dContact = _contactIdForDebt(d);
      if (contactId.isNotEmpty && dContact == contactId) return true;
      return (d["personName"] ?? "").toString() == name;
    }).toList();
    if (rows.isEmpty) rows = [debt];

    await showDialog<void>(
      context: context,
      builder: (_) => _LedgerDialog(
        name: name,
        debts: rows,
        onPay: (row) async {
          Navigator.pop(context);
          await _addPayment(row);
        },
        onEdit: (row) async {
          Navigator.pop(context);
          await _addOrEdit(debt: row);
        },
        onDelete: (row) async {
          Navigator.pop(context);
          await _delete(row);
        },
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> debt) async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 44,
        ),
        content: Text(
          _label(
            c.isArabic,
            "Delete this debt?",
            "\u062d\u0630\u0641 \u0647\u0630\u0627 \u0627\u0644\u062f\u064a\u0646\u061f",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(c.t("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(c.t("delete")),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.delete("/debts/${debt["_id"]}");
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _showDebtPeopleInvoice() async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final options = await _pickDebtPeopleInvoiceOptions(isAr);
    if (options == null) return;

    final invoice = _DebtPeopleInvoiceData.fromDebts(_debts, options);
    final message = invoice.toMessage(isAr);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(invoice.title(isAr)),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(message)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _label(isAr, "Close", "\u0625\u063a\u0644\u0627\u0642"),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _label(
                      isAr,
                      "Copied.",
                      "\u062a\u0645 \u0627\u0644\u0646\u0633\u062e.",
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(_label(isAr, "Copy", "\u0646\u0633\u062e")),
          ),
          OutlinedButton.icon(
            onPressed: () => _printDebtPeopleInvoice(invoice, isAr),
            icon: const Icon(Icons.print_rounded),
            label: Text(
              _label(isAr, "Print", "\u0637\u0628\u0627\u0639\u0629"),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _shareDebtPeopleInvoice(invoice, isAr),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(
              _label(
                isAr,
                "Share PDF",
                "\u0645\u0634\u0627\u0631\u0643\u0629 PDF",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<_DebtPeopleInvoiceOptions?> _pickDebtPeopleInvoiceOptions(bool isAr) {
    var type = _DebtPeopleInvoiceType.customers;
    var sort = _DebtPeopleInvoiceSort.highestDebt;
    return showDialog<_DebtPeopleInvoiceOptions>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            _label(
              isAr,
              "Debt invoice options",
              "\u062e\u064a\u0627\u0631\u0627\u062a \u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u062f\u064a\u0648\u0646",
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_DebtPeopleInvoiceType>(
                segments: [
                  ButtonSegment(
                    value: _DebtPeopleInvoiceType.customers,
                    icon: const Icon(Icons.people_alt_rounded),
                    label: Text(
                      _label(
                        isAr,
                        "Customers",
                        "\u0627\u0644\u0632\u0628\u0627\u0626\u0646",
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: _DebtPeopleInvoiceType.suppliers,
                    icon: const Icon(Icons.store_rounded),
                    label: Text(
                      _label(
                        isAr,
                        "Suppliers",
                        "\u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646",
                      ),
                    ),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (value) =>
                    setDialogState(() => type = value.first),
              ),
              const SizedBox(height: 14),
              SegmentedButton<_DebtPeopleInvoiceSort>(
                segments: [
                  ButtonSegment(
                    value: _DebtPeopleInvoiceSort.highestDebt,
                    icon: const Icon(Icons.trending_up_rounded),
                    label: Text(
                      _label(
                        isAr,
                        "Highest debt",
                        "\u0627\u0644\u0623\u0643\u062b\u0631 \u062f\u064a\u0646\u0627\u064b",
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: _DebtPeopleInvoiceSort.date,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      _label(
                        isAr,
                        "By date",
                        "\u062d\u0633\u0628 \u0627\u0644\u062a\u0627\u0631\u064a\u062e",
                      ),
                    ),
                  ),
                ],
                selected: {sort},
                onSelectionChanged: (value) =>
                    setDialogState(() => sort = value.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                _label(isAr, "Cancel", "\u0625\u0644\u063a\u0627\u0621"),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                ctx,
                _DebtPeopleInvoiceOptions(type: type, sort: sort),
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(
                _label(
                  isAr,
                  "Create invoice",
                  "\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printDebtPeopleInvoice(
    _DebtPeopleInvoiceData invoice,
    bool isAr,
  ) async {
    final bytes = await _debtPeopleInvoicePdfBytes(invoice, isAr);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareDebtPeopleInvoice(
    _DebtPeopleInvoiceData invoice,
    bool isAr,
  ) async {
    final bytes = await _debtPeopleInvoicePdfBytes(invoice, isAr);
    await Printing.sharePdf(bytes: bytes, filename: invoice.fileName);
  }

  Future<Uint8List> _debtPeopleInvoicePdfBytes(
    _DebtPeopleInvoiceData invoice,
    bool isAr,
  ) async {
    final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pdfText(
                  invoice.title(isAr),
                  isAr,
                  size: 18,
                  bold: true,
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                _pdfText(
                  "${_label(isAr, "Generated", "\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629")}: ${_shortDateTime(invoice.generatedAt)}",
                  isAr,
                  size: 9,
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 12),
                _pdfTable(
                  [
                    _label(isAr, "Type", "\u0627\u0644\u0646\u0648\u0639"),
                    _label(isAr, "Sort", "\u0627\u0644\u0641\u0631\u0632"),
                    _label(
                      isAr,
                      "People",
                      "\u0639\u062f\u062f \u0627\u0644\u0623\u0634\u062e\u0627\u0635",
                    ),
                    _label(
                      isAr,
                      "Total",
                      "\u0627\u0644\u0645\u062c\u0645\u0648\u0639",
                    ),
                  ],
                  [
                    [
                      invoice.typeLabel(isAr),
                      invoice.sortLabel(isAr),
                      number(invoice.parties.length),
                      invoice.totalRemaining.format(),
                    ],
                  ],
                  isAr,
                ),
                pw.SizedBox(height: 12),
                _pdfTable(
                  [
                    "#",
                    _label(isAr, "Name", "\u0627\u0644\u0627\u0633\u0645"),
                    _label(
                      isAr,
                      "Remaining",
                      "\u0627\u0644\u0645\u062a\u0628\u0642\u064a",
                    ),
                    _label(
                      isAr,
                      "Invoices",
                      "\u0641\u0648\u0627\u062a\u064a\u0631",
                    ),
                    _label(
                      isAr,
                      "Last date",
                      "\u0622\u062e\u0631 \u062a\u0627\u0631\u064a\u062e",
                    ),
                  ],
                  [
                    for (var i = 0; i < invoice.parties.length; i++)
                      [
                        number(i + 1),
                        invoice.parties[i].name,
                        invoice.parties[i].remaining.format(),
                        number(invoice.parties[i].debtCount),
                        invoice.parties[i].lastDateText,
                      ],
                  ],
                  isAr,
                ),
                if (invoice.parties.isEmpty) ...[
                  pw.SizedBox(height: 12),
                  _pdfText(
                    _label(
                      isAr,
                      "No open debts for this selection.",
                      "\u0644\u0627 \u064a\u0648\u062c\u062f \u062f\u064a\u0648\u0646 \u0645\u0641\u062a\u0648\u062d\u0629 \u0644\u0647\u0630\u0627 \u0627\u0644\u062e\u064a\u0627\u0631.",
                    ),
                    isAr,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _showDebtMasterReport() async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final report = _DebtReportData.fromDebts(_debts);
    final message = report.toMessage(isAr);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _label(
            isAr,
            "Total debt report",
            "\u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u062f\u064a\u0646 \u0627\u0644\u0643\u0644\u064a",
          ),
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(message)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _label(isAr, "Close", "\u0625\u063a\u0644\u0627\u0642"),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _label(
                      isAr,
                      "Copied.",
                      "\u062a\u0645 \u0627\u0644\u0646\u0633\u062e.",
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(_label(isAr, "Copy", "\u0646\u0633\u062e")),
          ),
          OutlinedButton.icon(
            onPressed: () => _printDebtReport(report, isAr),
            icon: const Icon(Icons.print_rounded),
            label: Text(
              _label(isAr, "Print", "\u0637\u0628\u0627\u0639\u0629"),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _shareDebtReport(report, isAr),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(
              _label(
                isAr,
                "Share PDF",
                "\u0645\u0634\u0627\u0631\u0643\u0629 PDF",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printDebtReport(_DebtReportData report, bool isAr) async {
    final bytes = await _debtReportPdfBytes(report, isAr);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareDebtReport(_DebtReportData report, bool isAr) async {
    final bytes = await _debtReportPdfBytes(report, isAr);
    await Printing.sharePdf(bytes: bytes, filename: "daftr-debt-report.pdf");
  }

  Future<Uint8List> _debtReportPdfBytes(
    _DebtReportData report,
    bool isAr,
  ) async {
    final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pdfText(
                  _label(
                    isAr,
                    "daftr - Total debt report",
                    "daftr - \u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u062f\u064a\u0646 \u0627\u0644\u0643\u0644\u064a",
                  ),
                  isAr,
                  size: 18,
                  bold: true,
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                _pdfText(
                  "${_label(isAr, "Generated", "\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u062a\u0642\u0631\u064a\u0631")}: ${_shortDateTime(DateTime.now())}",
                  isAr,
                  size: 9,
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 14),
                _pdfSummaryCards(report, isAr),
                pw.SizedBox(height: 12),
                _pdfSection(
                  _label(
                    isAr,
                    "Who owes us the most",
                    "\u0623\u0643\u062b\u0631 \u0627\u0644\u0632\u0628\u0627\u0626\u0646 \u062f\u064a\u0646\u0627\u064b \u0644\u0646\u0627",
                  ),
                  _partyRows(report.topReceivable, isAr),
                  isAr,
                ),
                _pdfSection(
                  _label(
                    isAr,
                    "Suppliers we owe the most",
                    "\u0623\u0643\u062b\u0631 \u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646 \u062f\u064a\u0646\u0627\u064b \u0639\u0644\u064a\u0646\u0627",
                  ),
                  _partyRows(report.topPayable, isAr),
                  isAr,
                ),
                _pdfSection(
                  _label(
                    isAr,
                    "Days with the most new debt",
                    "\u0627\u0644\u0623\u064a\u0627\u0645 \u0627\u0644\u0623\u0643\u062b\u0631 \u062a\u0633\u062c\u064a\u0644\u0627\u064b \u0644\u0644\u062f\u064a\u0648\u0646",
                  ),
                  _dayRows(report.topDebtDays, isAr),
                  isAr,
                ),
                _pdfSection(
                  _label(
                    isAr,
                    "Strongest payment days",
                    "\u0623\u064a\u0627\u0645 \u0627\u0644\u062f\u0641\u0639 \u0627\u0644\u0623\u0642\u0648\u0649",
                  ),
                  _dayRows(report.topPaymentDays, isAr),
                  isAr,
                ),
                _pdfSection(
                  _label(
                    isAr,
                    "Largest open debts",
                    "\u0623\u0643\u0628\u0631 \u0627\u0644\u062f\u064a\u0648\u0646 \u0627\u0644\u0645\u0641\u062a\u0648\u062d\u0629",
                  ),
                  _singleDebtRows(report.largestOpenDebts, isAr),
                  isAr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfSummaryCards(_DebtReportData report, bool isAr) {
    final rows = [
      [
        _label(
          isAr,
          "Remaining for us",
          "\u0627\u0644\u0645\u062a\u0628\u0642\u064a \u0644\u0646\u0627",
        ),
        report.remainingReceivable.format(),
      ],
      [
        _label(
          isAr,
          "Remaining on us",
          "\u0627\u0644\u0645\u062a\u0628\u0642\u064a \u0639\u0644\u064a\u0646\u0627",
        ),
        report.remainingPayable.format(),
      ],
      [
        _label(
          isAr,
          "Collected / paid",
          "\u0627\u0644\u0645\u062f\u0641\u0648\u0639",
        ),
        report.paidTotal.format(),
      ],
      [
        _label(
          isAr,
          "Open invoices",
          "\u0641\u0648\u0627\u062a\u064a\u0631 \u0645\u0641\u062a\u0648\u062d\u0629",
        ),
        number(report.openCount),
      ],
    ];
    return _pdfTable(
      [
        _label(isAr, "Metric", "\u0627\u0644\u0628\u0646\u062f"),
        _label(isAr, "Value", "\u0627\u0644\u0642\u064a\u0645\u0629"),
      ],
      rows,
      isAr,
    );
  }

  pw.Widget _pdfSection(String title, List<List<String>> rows, bool isAr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 12),
        _pdfText(title, isAr, size: 12, bold: true),
        pw.SizedBox(height: 5),
        rows.isEmpty
            ? _pdfText(
                _label(
                  isAr,
                  "No data.",
                  "\u0644\u0627 \u064a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a.",
                ),
                isAr,
                size: 9,
              )
            : _pdfTable(rows.first, rows.skip(1).toList(), isAr),
      ],
    );
  }

  pw.Widget _pdfTable(
    List<String> headers,
    List<List<String>> data,
    bool isAr,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map((cell) => _pdfCell(cell, isAr, bold: true))
              .toList(),
        ),
        ...data.map(
          (row) => pw.TableRow(
            children: row.map((cell) => _pdfCell(cell, isAr)).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfCell(String text, bool isAr, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: _pdfText(text, isAr, size: 8, bold: bold),
    );
  }

  pw.Widget _pdfText(
    String text,
    bool isAr, {
    double size = 10,
    bool bold = false,
    pw.TextAlign? align,
  }) {
    return pw.Text(
      text,
      textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: align ?? (isAr ? pw.TextAlign.right : pw.TextAlign.left),
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  List<List<String>> _partyRows(List<_DebtPartyStat> rows, bool isAr) {
    return [
      [
        "#",
        _label(isAr, "Name", "\u0627\u0644\u0627\u0633\u0645"),
        _label(isAr, "Remaining", "\u0627\u0644\u0645\u062a\u0628\u0642\u064a"),
        _label(isAr, "Invoices", "\u0641\u0648\u0627\u062a\u064a\u0631"),
      ],
      for (var i = 0; i < rows.take(10).length; i++)
        [
          number(i + 1),
          rows[i].name,
          rows[i].remaining.format(),
          number(rows[i].debtCount),
        ],
    ];
  }

  List<List<String>> _dayRows(List<_DebtDayStat> rows, bool isAr) {
    return [
      [
        "#",
        _label(isAr, "Day", "\u0627\u0644\u064a\u0648\u0645"),
        _label(isAr, "Total", "\u0627\u0644\u0645\u062c\u0645\u0648\u0639"),
        _label(isAr, "Count", "\u0627\u0644\u0639\u062f\u062f"),
      ],
      for (var i = 0; i < rows.take(10).length; i++)
        [
          number(i + 1),
          rows[i].date,
          rows[i].totals.format(),
          number(rows[i].count),
        ],
    ];
  }

  List<List<String>> _singleDebtRows(List<_DebtSingleStat> rows, bool isAr) {
    return [
      [
        "#",
        _label(isAr, "Name", "\u0627\u0644\u0627\u0633\u0645"),
        _label(isAr, "Remaining", "\u0627\u0644\u0645\u062a\u0628\u0642\u064a"),
        _label(isAr, "Date", "\u0627\u0644\u062a\u0627\u0631\u064a\u062e"),
      ],
      for (var i = 0; i < rows.take(10).length; i++)
        [number(i + 1), rows[i].name, rows[i].remaining.format(), rows[i].date],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final visibleDebts = _filteredDebts();
    final receivable = _moneyByCurrency("receivable", visibleDebts);
    final payable = _moneyByCurrency("payable", visibleDebts);
    final grouped = _groupDebts(visibleDebts);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          PageHeader(
            title: c.t("debts"),
            actions: [
              FilledButton.icon(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: Text(_label(isAr, "New", "\u062c\u062f\u064a\u062f")),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _debts.isEmpty ? null : _showDebtPeopleInvoice,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text(
                  _label(
                    isAr,
                    "Debt invoice",
                    "\u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u0645\u062a\u062f\u064a\u0646\u064a\u0646",
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _debts.isEmpty ? null : _showDebtMasterReport,
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: Text(
                  _label(
                    isAr,
                    "Total debt report",
                    "\u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u062f\u064a\u0646 \u0627\u0644\u0643\u0644\u064a",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DateFilterBar(
            isArabic: isAr,
            value: _dateFilter,
            onChanged: (value) => setState(() => _dateFilter = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: _label(
                isAr,
                "Search by name or phone",
                "\u0628\u062d\u062b \u0628\u0627\u0644\u0627\u0633\u0645 \u0623\u0648 \u0627\u0644\u0631\u0642\u0645",
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _summaryGrid(isAr, receivable, payable),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            ModernCard(child: Text(_error!))
          else if (visibleDebts.isEmpty)
            ModernCard(child: Text(c.t("empty")))
          else
            ...grouped.values.map((rows) => _contactDebtItem(rows, isAr)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredDebts() {
    final query = _search.text.trim().toLowerCase();
    final queryDigits = _search.text.replaceAll(RegExp(r"[^0-9+]"), "");
    return _debts.where((debt) {
      if (!_debtMatchesDateFilter(debt)) return false;
      if (query.isEmpty && queryDigits.isEmpty) return true;
      final contact = _contactForDebt(debt);
      final text = [
        (debt["personName"] ?? "").toString(),
        contact?.name ?? "",
        contact?.phone ?? "",
        contact?.fullPhone ?? "",
      ].join(" ").toLowerCase();
      final digits = text.replaceAll(RegExp(r"[^0-9+]"), "");
      return text.contains(query) ||
          (queryDigits.isNotEmpty && digits.contains(queryDigits));
    }).toList();
  }

  bool _debtMatchesDateFilter(Map<String, dynamic> debt) {
    final dates = <DateTime?>[
      _dateFrom(debt["createdAt"]),
      _dateFrom(debt["updatedAt"]),
    ];
    final payments = debt["payments"];
    if (payments is List) {
      for (final row in payments.whereType<Map>()) {
        dates.add(_dateFrom(row["date"]));
        dates.add(_dateFrom(row["createdAt"]));
        dates.add(_dateFrom(row["updatedAt"]));
      }
    }
    return dates.any((date) => _dateFilter.includes(date));
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is DateTime) return value;
    final text = (value ?? "").toString();
    if (text.trim().isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _contactIdForDebt(Map<String, dynamic> debt) {
    final raw = debt["contact"];
    if (raw is Map) return (raw["_id"] ?? raw["id"] ?? "").toString();
    return (raw ?? "").toString();
  }

  ContactModel? _contactForDebt(Map<String, dynamic> debt) {
    final id = _contactIdForDebt(debt);
    final name = (debt["personName"] ?? "").toString();
    for (final contact in _contacts) {
      if (id.isNotEmpty && contact.id == id) return contact;
      if (name.isNotEmpty && contact.name == name) return contact;
    }
    return null;
  }

  Map<String, List<Map<String, dynamic>>> _groupDebts(
    List<Map<String, dynamic>> debts,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final debt in debts) {
      final contactId = _contactIdForDebt(debt);
      final name = (debt["personName"] ?? "").toString();
      final key = contactId.isNotEmpty ? contactId : name;
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]);
      grouped[key]!.add(debt);
    }
    return grouped;
  }

  String _moneyByCurrency(String type, List<Map<String, dynamic>> debts) {
    final totals = <String, double>{};
    for (final debt in debts.where(
      (d) => (d["type"] ?? "").toString() == type,
    )) {
      final currency = (debt["currency"] ?? "LBP").toString();
      totals[currency] =
          (totals[currency] ?? 0) + _num(debt["remainingAmount"]);
    }
    if (totals.isEmpty) return "${money(0, "LBP")}\n${money(0, "USD")}";
    return "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}";
  }

  Widget _summaryGrid(bool isAr, String receivable, String payable) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _summaryCard(
                _label(isAr, "For us", "\u0644\u0646\u0627"),
                receivable,
                Icons.call_received_rounded,
                Colors.green,
              ),
            ),
            SizedBox(
              width: width,
              child: _summaryCard(
                _label(isAr, "On us", "\u0639\u0644\u064a\u0646\u0627"),
                payable,
                Icons.call_made_rounded,
                Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final values = value
        .split("\n")
        .where((line) => line.trim().isNotEmpty)
        .toList();
    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final line in values)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactDebtItem(List<Map<String, dynamic>> rows, bool isAr) {
    final first = rows.first;
    final type = (first["type"] ?? "").toString();
    final color = type == "receivable" ? Colors.green : Colors.red;
    final name = (first["personName"] ?? "").toString();
    final openCount = rows
        .where((d) => (d["status"] ?? "").toString() != "paid")
        .length;
    final totals = _totalsFor(rows);
    final role = type == "receivable"
        ? _label(isAr, "Customer", "\u0632\u0628\u0648\u0646")
        : _label(isAr, "Supplier", "\u0645\u0648\u0631\u062f");

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        onTap: () => _showLedger(first, rowsOverride: rows),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    type == "receivable"
                        ? Icons.person_rounded
                        : Icons.store_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? "-" : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "$role - ${number(rows.length)} ${_label(isAr, "invoices", "\u0641\u0648\u0627\u062a\u064a\u0631")} - ${number(openCount)} ${_label(isAr, "open", "\u0645\u0641\u062a\u0648\u062d")}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _label(
                    isAr,
                    "Open ledger",
                    "\u0641\u062a\u062d \u0627\u0644\u062c\u0631\u062f\u0629",
                  ),
                  onPressed: () => _showLedger(first, rowsOverride: rows),
                  icon: const Icon(Icons.receipt_long_rounded),
                ),
              ],
            ),
            const Divider(height: 18),
            _amountStrip(totals, color),
          ],
        ),
      ),
    );
  }

  Widget _amountStrip(Map<String, double> totals, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _amountPill(money(totals["LBP"] ?? 0, "LBP"), color),
        _amountPill(money(totals["USD"] ?? 0, "USD"), color),
      ],
    );
  }

  Widget _amountPill(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }

  Widget _debtItem(Map<String, dynamic> debt, bool isAr) {
    final type = (debt["type"] ?? "").toString();
    final color = type == "receivable" ? Colors.green : Colors.red;
    final remaining = _num(debt["remainingAmount"]);
    final currency = (debt["currency"] ?? "LBP").toString();
    final status = (debt["status"] ?? "-").toString();
    final note = (debt["note"] ?? "").toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        onTap: () => _showLedger(debt),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    type == "receivable"
                        ? Icons.call_received
                        : Icons.call_made,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (debt["personName"] ?? "").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (status.isNotEmpty || note.isNotEmpty)
                        Text(
                          note.isEmpty ? status : "$status - $note",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  money(remaining, currency),
                  style: TextStyle(fontWeight: FontWeight.w900, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addPayment(debt),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: Text(
                    _label(isAr, "Payment", "\u062f\u0641\u0639\u0629"),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addOrEdit(debt: debt),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(
                    _label(isAr, "Edit", "\u062a\u0639\u062f\u064a\u0644"),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _delete(debt),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(_label(isAr, "Delete", "\u062d\u0630\u0641")),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _num(dynamic value) {
    return numFromDynamic(value);
  }

  Map<String, double> _totalsFor(List<Map<String, dynamic>> rows) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final row in rows) {
      final currency = (row["currency"] ?? "LBP").toString() == "USD"
          ? "USD"
          : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _num(row["remainingAmount"]);
    }
    return totals;
  }

  String _formatTotals(Map<String, double> totals) {
    return "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}";
  }
}

class _DebtReportData {
  final int totalCount;
  final int openCount;
  final int partialCount;
  final int paidCount;
  final int paymentCount;
  final _MoneyTotals originalReceivable;
  final _MoneyTotals originalPayable;
  final _MoneyTotals remainingReceivable;
  final _MoneyTotals remainingPayable;
  final _MoneyTotals paidTotal;
  final List<_DebtPartyStat> topReceivable;
  final List<_DebtPartyStat> topPayable;
  final List<_DebtDayStat> topDebtDays;
  final List<_DebtDayStat> topPaymentDays;
  final List<_DebtSingleStat> largestOpenDebts;

  const _DebtReportData({
    required this.totalCount,
    required this.openCount,
    required this.partialCount,
    required this.paidCount,
    required this.paymentCount,
    required this.originalReceivable,
    required this.originalPayable,
    required this.remainingReceivable,
    required this.remainingPayable,
    required this.paidTotal,
    required this.topReceivable,
    required this.topPayable,
    required this.topDebtDays,
    required this.topPaymentDays,
    required this.largestOpenDebts,
  });

  factory _DebtReportData.fromDebts(List<Map<String, dynamic>> debts) {
    var openCount = 0;
    var partialCount = 0;
    var paidCount = 0;
    var paymentCount = 0;
    final originalReceivable = _MoneyTotals();
    final originalPayable = _MoneyTotals();
    final remainingReceivable = _MoneyTotals();
    final remainingPayable = _MoneyTotals();
    final paidTotal = _MoneyTotals();
    final parties = <String, _DebtPartyStat>{};
    final debtDays = <String, _DebtDayStat>{};
    final paymentDays = <String, _DebtDayStat>{};
    final largest = <_DebtSingleStat>[];

    for (final debt in debts) {
      final type = (debt["type"] ?? "receivable").toString();
      final status = (debt["status"] ?? "open").toString();
      final currency = (debt["currency"] ?? "LBP").toString() == "USD"
          ? "USD"
          : "LBP";
      final name = (debt["personName"] ?? "-").toString().trim().isEmpty
          ? "-"
          : (debt["personName"] ?? "-").toString();
      final original = numFromDynamic(debt["originalAmount"]);
      final remaining = numFromDynamic(debt["remainingAmount"]);
      final paid = numFromDynamic(debt["paidAmount"]);

      if (status == "paid") {
        paidCount++;
      } else if (status == "partial") {
        partialCount++;
      } else {
        openCount++;
      }

      final originalTotals = type == "payable"
          ? originalPayable
          : originalReceivable;
      final remainingTotals = type == "payable"
          ? remainingPayable
          : remainingReceivable;
      originalTotals.add(original, currency);
      remainingTotals.add(remaining, currency);
      paidTotal.add(paid, currency);

      final partyKey = "$type:${_contactIdForReport(debt)}:$name";
      final party = parties.putIfAbsent(
        partyKey,
        () => _DebtPartyStat(name: name, type: type),
      );
      party.add(
        original: original,
        remaining: remaining,
        paid: paid,
        currency: currency,
        status: status,
      );

      final created = _dateFromReport(debt["createdAt"]);
      if (created != null) {
        final key = _dayKey(created);
        final day = debtDays.putIfAbsent(key, () => _DebtDayStat(date: key));
        day.add(original, currency);
      }

      if (remaining > 0) {
        largest.add(
          _DebtSingleStat(
            name: name,
            type: type,
            date: created == null ? "-" : _shortDate(created),
            remaining: _MoneyTotals()..add(remaining, currency),
          ),
        );
      }

      final payments = debt["payments"];
      if (payments is List) {
        for (final payment in payments.whereType<Map>()) {
          final amount = numFromDynamic(payment["amount"]);
          final paymentCurrency =
              (payment["currency"] ?? currency).toString() == "USD"
              ? "USD"
              : "LBP";
          final paidAt =
              _dateFromReport(payment["date"]) ??
              _dateFromReport(payment["createdAt"]) ??
              _dateFromReport(payment["updatedAt"]);
          if (paidAt == null || amount <= 0) continue;
          paymentCount++;
          final key = _dayKey(paidAt);
          final day = paymentDays.putIfAbsent(
            key,
            () => _DebtDayStat(date: key),
          );
          day.add(amount, paymentCurrency);
        }
      }
    }

    final receivableParties =
        parties.values
            .where((p) => p.type != "payable" && !p.remaining.isZero)
            .toList()
          ..sort((a, b) => b.remaining.score.compareTo(a.remaining.score));
    final payableParties =
        parties.values
            .where((p) => p.type == "payable" && !p.remaining.isZero)
            .toList()
          ..sort((a, b) => b.remaining.score.compareTo(a.remaining.score));
    final sortedDebtDays = debtDays.values.toList()
      ..sort((a, b) {
        final scoreCompare = b.totals.score.compareTo(a.totals.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.count.compareTo(a.count);
      });
    final sortedPaymentDays = paymentDays.values.toList()
      ..sort((a, b) {
        final scoreCompare = b.totals.score.compareTo(a.totals.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.count.compareTo(a.count);
      });
    largest.sort((a, b) => b.remaining.score.compareTo(a.remaining.score));

    return _DebtReportData(
      totalCount: debts.length,
      openCount: openCount,
      partialCount: partialCount,
      paidCount: paidCount,
      paymentCount: paymentCount,
      originalReceivable: originalReceivable,
      originalPayable: originalPayable,
      remainingReceivable: remainingReceivable,
      remainingPayable: remainingPayable,
      paidTotal: paidTotal,
      topReceivable: receivableParties,
      topPayable: payableParties,
      topDebtDays: sortedDebtDays,
      topPaymentDays: sortedPaymentDays,
      largestOpenDebts: largest,
    );
  }

  String toMessage(bool isAr) {
    final lines = <String>[
      _label(isAr, "daftr - Total debt report", "daftr - تقرير الدين الكلي"),
      "${_label(isAr, "Generated", "تاريخ التقرير")}: ${_shortDateTime(DateTime.now())}",
      "",
      _label(isAr, "Summary", "الملخص"),
      "------------------------------",
      "${_label(isAr, "Total debt invoices", "عدد فواتير الدين")}: ${number(totalCount)}",
      "${_label(isAr, "Open", "مفتوح")}: ${number(openCount)} | ${_label(isAr, "Partial", "جزئي")}: ${number(partialCount)} | ${_label(isAr, "Paid", "مدفوع")}: ${number(paidCount)}",
      "${_label(isAr, "Remaining for us", "المتبقي لنا")}: ${remainingReceivable.format()}",
      "${_label(isAr, "Remaining on us", "المتبقي علينا")}: ${remainingPayable.format()}",
      "${_label(isAr, "Original for us", "أصل الدين لنا")}: ${originalReceivable.format()}",
      "${_label(isAr, "Original on us", "أصل الدين علينا")}: ${originalPayable.format()}",
      "${_label(isAr, "Collected / paid", "المدفوع")}: ${paidTotal.format()}",
      "${_label(isAr, "Payment records", "عدد الدفعات")}: ${number(paymentCount)}",
      "",
    ];

    _appendPartySection(
      lines,
      isAr,
      _label(isAr, "Who owes us the most", "أكثر الزبائن ديناً لنا"),
      topReceivable,
    );
    _appendPartySection(
      lines,
      isAr,
      _label(isAr, "Suppliers we owe the most", "أكثر الموردين ديناً علينا"),
      topPayable,
    );
    _appendDaySection(
      lines,
      isAr,
      _label(
        isAr,
        "Days with the most new debt",
        "الأيام الأكثر تسجيلاً للديون",
      ),
      topDebtDays,
    );
    _appendDaySection(
      lines,
      isAr,
      _label(isAr, "Strongest payment days", "أيام الدفع الأقوى"),
      topPaymentDays,
    );
    _appendLargestSection(
      lines,
      isAr,
      _label(isAr, "Largest open debts", "أكبر الديون المفتوحة"),
      largestOpenDebts,
    );
    lines.add("");
    lines.add(
      _label(
        isAr,
        "Ranking uses both currencies separately for display and an internal approximate score only for ordering.",
        "الترتيب يعرض اللبناني والدولار بشكل منفصل ويستخدم تقديراً داخلياً فقط لترتيب النتائج المختلطة.",
      ),
    );
    return lines.join("\n");
  }

  void _appendPartySection(
    List<String> lines,
    bool isAr,
    String title,
    List<_DebtPartyStat> rows,
  ) {
    lines.add(title);
    lines.add("------------------------------");
    if (rows.isEmpty) {
      lines.add(_label(isAr, "No open debt.", "لا يوجد دين مفتوح."));
      lines.add("");
      return;
    }
    for (var i = 0; i < rows.take(10).length; i++) {
      final row = rows[i];
      lines.add(
        "${number(i + 1)}. ${row.name} - ${row.remaining.format()} (${number(row.debtCount)} ${_label(isAr, "invoices", "فواتير")})",
      );
    }
    lines.add("");
  }

  void _appendDaySection(
    List<String> lines,
    bool isAr,
    String title,
    List<_DebtDayStat> rows,
  ) {
    lines.add(title);
    lines.add("------------------------------");
    if (rows.isEmpty) {
      lines.add(_label(isAr, "No data.", "لا يوجد بيانات."));
      lines.add("");
      return;
    }
    for (var i = 0; i < rows.take(10).length; i++) {
      final row = rows[i];
      lines.add(
        "${number(i + 1)}. ${row.date} - ${row.totals.format()} (${number(row.count)} ${_label(isAr, "records", "حركات")})",
      );
    }
    lines.add("");
  }

  void _appendLargestSection(
    List<String> lines,
    bool isAr,
    String title,
    List<_DebtSingleStat> rows,
  ) {
    lines.add(title);
    lines.add("------------------------------");
    if (rows.isEmpty) {
      lines.add(_label(isAr, "No open debt.", "لا يوجد دين مفتوح."));
      lines.add("");
      return;
    }
    for (var i = 0; i < rows.take(10).length; i++) {
      final row = rows[i];
      lines.add(
        "${number(i + 1)}. ${row.name} - ${row.remaining.format()} - ${row.date}",
      );
    }
    lines.add("");
  }
}

class _MoneyTotals {
  static const double _rankingRate = 90000;
  double lbp = 0;
  double usd = 0;

  bool get isZero => lbp == 0 && usd == 0;

  double get score => lbp + (usd * _rankingRate);

  void add(num amount, String currency) {
    final value = amount.toDouble();
    if (currency == "USD") {
      usd += value;
    } else {
      lbp += value;
    }
  }

  String format() {
    final parts = <String>[];
    if (lbp != 0) parts.add(money(lbp, "LBP"));
    if (usd != 0) parts.add(money(usd, "USD"));
    return parts.isEmpty ? money(0, "LBP") : parts.join(" / ");
  }
}

class _DebtPartyStat {
  final String name;
  final String type;
  final _MoneyTotals original = _MoneyTotals();
  final _MoneyTotals remaining = _MoneyTotals();
  final _MoneyTotals paid = _MoneyTotals();
  int debtCount = 0;
  int openCount = 0;

  _DebtPartyStat({required this.name, required this.type});

  void add({
    required num original,
    required num remaining,
    required num paid,
    required String currency,
    required String status,
  }) {
    debtCount++;
    if (status != "paid") openCount++;
    this.original.add(original, currency);
    this.remaining.add(remaining, currency);
    this.paid.add(paid, currency);
  }
}

class _DebtDayStat {
  final String date;
  final _MoneyTotals totals = _MoneyTotals();
  int count = 0;

  _DebtDayStat({required this.date});

  void add(num amount, String currency) {
    count++;
    totals.add(amount, currency);
  }
}

class _DebtSingleStat {
  final String name;
  final String type;
  final String date;
  final _MoneyTotals remaining;

  const _DebtSingleStat({
    required this.name,
    required this.type,
    required this.date,
    required this.remaining,
  });
}

enum _DebtPeopleInvoiceType { customers, suppliers }

enum _DebtPeopleInvoiceSort { highestDebt, date }

class _DebtPeopleInvoiceOptions {
  final _DebtPeopleInvoiceType type;
  final _DebtPeopleInvoiceSort sort;

  const _DebtPeopleInvoiceOptions({required this.type, required this.sort});
}

class _DebtPeopleInvoiceData {
  final _DebtPeopleInvoiceOptions options;
  final List<_DebtPeopleInvoiceParty> parties;
  final _MoneyTotals totalRemaining;
  final DateTime generatedAt;

  const _DebtPeopleInvoiceData({
    required this.options,
    required this.parties,
    required this.totalRemaining,
    required this.generatedAt,
  });

  factory _DebtPeopleInvoiceData.fromDebts(
    List<Map<String, dynamic>> debts,
    _DebtPeopleInvoiceOptions options,
  ) {
    final wantedType = options.type == _DebtPeopleInvoiceType.suppliers
        ? "payable"
        : "receivable";
    final grouped = <String, _DebtPeopleInvoiceParty>{};
    final total = _MoneyTotals();

    for (final debt in debts) {
      final type = (debt["type"] ?? "receivable").toString();
      if (type != wantedType) continue;
      final status = (debt["status"] ?? "open").toString();
      final remaining = numFromDynamic(debt["remainingAmount"]);
      if (status == "paid" || remaining <= 0) continue;

      final currency = (debt["currency"] ?? "LBP").toString() == "USD"
          ? "USD"
          : "LBP";
      final fallbackName = options.type == _DebtPeopleInvoiceType.suppliers
          ? "Supplier"
          : "Customer";
      final rawName = (debt["personName"] ?? "").toString().trim();
      final name = rawName.isEmpty ? fallbackName : rawName;
      final key = "$type:${_contactIdForReport(debt)}:$name";
      final party = grouped.putIfAbsent(
        key,
        () => _DebtPeopleInvoiceParty(name: name),
      );

      party.add(debt, remaining: remaining, currency: currency);
      total.add(remaining, currency);
    }

    final parties = grouped.values.toList();
    if (options.sort == _DebtPeopleInvoiceSort.date) {
      parties.sort((a, b) {
        final aTime = a.lastDate?.millisecondsSinceEpoch ?? 0;
        final bTime = b.lastDate?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    } else {
      parties.sort((a, b) => b.remaining.score.compareTo(a.remaining.score));
    }

    return _DebtPeopleInvoiceData(
      options: options,
      parties: parties,
      totalRemaining: total,
      generatedAt: DateTime.now(),
    );
  }

  String title(bool isAr) {
    if (options.type == _DebtPeopleInvoiceType.suppliers) {
      return _label(isAr, "Supplier debt invoice", "فاتورة ديون الموردين");
    }
    return _label(isAr, "Customer debt invoice", "فاتورة ديون الزبائن");
  }

  String typeLabel(bool isAr) {
    if (options.type == _DebtPeopleInvoiceType.suppliers) {
      return _label(isAr, "Suppliers", "الموردين");
    }
    return _label(isAr, "Customers", "الزبائن");
  }

  String sortLabel(bool isAr) {
    if (options.sort == _DebtPeopleInvoiceSort.date) {
      return _label(isAr, "By latest date", "حسب آخر تاريخ");
    }
    return _label(isAr, "By highest debt", "حسب الأكثر ديناً");
  }

  String get fileName => options.type == _DebtPeopleInvoiceType.suppliers
      ? "daftr-supplier-debts.pdf"
      : "daftr-customer-debts.pdf";

  String toMessage(bool isAr) {
    final lines = <String>[
      title(isAr),
      "${_label(isAr, "Generated", "تاريخ الفاتورة")}: ${_shortDateTime(generatedAt)}",
      "${_label(isAr, "Type", "النوع")}: ${typeLabel(isAr)}",
      "${_label(isAr, "Sort", "الفرز")}: ${sortLabel(isAr)}",
      "${_label(isAr, "People", "عدد الأشخاص")}: ${number(parties.length)}",
      "${_label(isAr, "Total remaining", "إجمالي المتبقي")}: ${totalRemaining.format()}",
      "------------------------------",
    ];

    if (parties.isEmpty) {
      lines.add(
        _label(
          isAr,
          "No open debts for this selection.",
          "لا يوجد ديون مفتوحة لهذا الخيار.",
        ),
      );
      return lines.join("\n");
    }

    for (var i = 0; i < parties.length; i++) {
      final party = parties[i];
      lines.add(
        "${number(i + 1)}. ${party.name} | ${party.remaining.format()} | ${number(party.debtCount)} ${_label(isAr, "invoices", "فواتير")} | ${_label(isAr, "Last", "آخر")}: ${party.lastDateText}",
      );
    }
    return lines.join("\n");
  }
}

class _DebtPeopleInvoiceParty {
  final String name;
  final _MoneyTotals remaining = _MoneyTotals();
  int debtCount = 0;
  DateTime? lastDate;

  _DebtPeopleInvoiceParty({required this.name});

  void add(
    Map<String, dynamic> debt, {
    required num remaining,
    required String currency,
  }) {
    debtCount++;
    this.remaining.add(remaining, currency);
    _captureDate(_dateFromReport(debt["updatedAt"]));
    _captureDate(_dateFromReport(debt["createdAt"]));

    final payments = debt["payments"];
    if (payments is List) {
      for (final payment in payments.whereType<Map>()) {
        _captureDate(_dateFromReport(payment["date"]));
        _captureDate(_dateFromReport(payment["updatedAt"]));
        _captureDate(_dateFromReport(payment["createdAt"]));
      }
    }
  }

  String get lastDateText => lastDate == null ? "-" : _shortDate(lastDate!);

  void _captureDate(DateTime? value) {
    if (value == null) return;
    if (lastDate == null || value.isAfter(lastDate!)) {
      lastDate = value;
    }
  }
}

class _DebtDialog extends StatefulWidget {
  final Map<String, dynamic>? debt;
  final List<ContactModel> contacts;
  const _DebtDialog({this.debt, required this.contacts});

  @override
  State<_DebtDialog> createState() => _DebtDialogState();
}

class _DebtDialogState extends State<_DebtDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _contactId;
  String _type = "receivable";
  String _currency = "LBP";

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    if (debt == null) return;
    _amount.text = _numText(debt["originalAmount"]);
    _note.text = (debt["note"] ?? "").toString();
    _contactId = (debt["contact"] ?? "").toString().isEmpty
        ? null
        : (debt["contact"] ?? "").toString();
    _type = (debt["type"] ?? "receivable").toString();
    _currency = (debt["currency"] ?? "LBP").toString();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return AlertDialog(
      title: Text(
        widget.debt == null
            ? _label(
                isAr,
                "New Debt",
                "\u062f\u064a\u0646 \u062c\u062f\u064a\u062f",
              )
            : _label(
                isAr,
                "Edit Debt",
                "\u062a\u0639\u062f\u064a\u0644 \u062f\u064a\u0646",
              ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _contactId,
              decoration: InputDecoration(
                labelText: _label(
                  isAr,
                  "Contact",
                  "\u062c\u0647\u0629 \u0627\u0644\u0627\u062a\u0635\u0627\u0644",
                ),
              ),
              items: widget.contacts
                  .map(
                    (contact) => DropdownMenuItem(
                      value: contact.id,
                      child: Text(
                        "${contact.name} - ${contact.type == "supplier" ? _label(isAr, "Supplier", "\u0645\u0648\u0631\u062f") : _label(isAr, "Customer", "\u0632\u0628\u0648\u0646")}",
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final contact = _firstContactWhere((c) => c.id == v);
                setState(() {
                  _contactId = v;
                  if (contact != null) {
                    _type = contact.type == "supplier"
                        ? "payable"
                        : "receivable";
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                labelText: _label(
                  isAr,
                  "Type",
                  "\u0627\u0644\u0646\u0648\u0639",
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: "receivable",
                  child: Text(_label(isAr, "Receivable", "\u0644\u0646\u0627")),
                ),
                DropdownMenuItem(
                  value: "payable",
                  child: Text(
                    _label(isAr, "Payable", "\u0639\u0644\u064a\u0646\u0627"),
                  ),
                ),
              ],
              onChanged: null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _label(
                  isAr,
                  "Amount",
                  "\u0627\u0644\u0645\u0628\u0644\u063a",
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: InputDecoration(labelText: c.t("currency")),
              items: const [
                DropdownMenuItem(value: "USD", child: Text("USD")),
                DropdownMenuItem(value: "LBP", child: Text("LBP")),
              ],
              onChanged: (v) => setState(() => _currency = v ?? _currency),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: _label(
                  isAr,
                  "Note",
                  "\u0645\u0644\u0627\u062d\u0638\u0629",
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(c.t("cancel")),
        ),
        FilledButton(
          onPressed: () {
            final contact = _firstContactWhere((c) => c.id == _contactId);
            if (contact == null) return;
            Navigator.pop(context, {
              "contact": contact.id,
              "personName": contact.name,
              "type": _type,
              "originalAmount": parseNumberInput(_amount.text),
              "currency": _currency,
              "note": _note.text.trim(),
            });
          },
          child: Text(c.t("save")),
        ),
      ],
    );
  }

  ContactModel? _firstContactWhere(bool Function(ContactModel) test) {
    for (final contact in widget.contacts) {
      if (test(contact)) return contact;
    }
    return null;
  }

  String _numText(dynamic value) {
    if (value is num) return value.toString();
    return value?.toString() ?? "";
  }
}

class _LedgerDialog extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> debts;
  final Future<void> Function(Map<String, dynamic>) onPay;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const _LedgerDialog({
    required this.name,
    required this.debts,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppScope.of(context).isArabic;
    final totals = _totalsFor(debts);

    return AlertDialog(
      title: Text(name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_label(isAr, "Remaining", "\u0627\u0644\u0645\u062a\u0628\u0642\u064a")}:\n${_formatTotals(totals)}",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final debt in debts) _ledgerDebtRow(context, debt, isAr),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_label(isAr, "Close", "\u0625\u063a\u0644\u0627\u0642")),
        ),
      ],
    );
  }

  Widget _ledgerDebtRow(
    BuildContext context,
    Map<String, dynamic> debt,
    bool isAr,
  ) {
    final currency = (debt["currency"] ?? "LBP").toString();
    final status = (debt["status"] ?? "").toString();
    final note = (debt["note"] ?? "").toString();
    final color = (debt["type"] ?? "").toString() == "receivable"
        ? Colors.green
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            money(_num(debt["remainingAmount"]), currency),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 16,
            ),
          ),
          if (status.isNotEmpty || note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note.isEmpty ? status : "$status - $note",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => onPay(debt),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: Text(_label(isAr, "Pay", "\u062f\u0641\u0639")),
              ),
              OutlinedButton.icon(
                onPressed: () => onEdit(debt),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(
                  _label(isAr, "Edit", "\u062a\u0639\u062f\u064a\u0644"),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => onDelete(debt),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(_label(isAr, "Delete", "\u062d\u0630\u0641")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _num(dynamic value) {
    return numFromDynamic(value);
  }

  Map<String, double> _totalsFor(List<Map<String, dynamic>> rows) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final row in rows) {
      final currency = (row["currency"] ?? "LBP").toString() == "USD"
          ? "USD"
          : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _num(row["remainingAmount"]);
    }
    return totals;
  }

  String _formatTotals(Map<String, double> totals) {
    return "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}";
  }
}

class _PaymentDialog extends StatefulWidget {
  final String currency;
  const _PaymentDialog({required this.currency});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _currency;

  @override
  void initState() {
    super.initState();
    _currency = widget.currency == "USD" ? "USD" : "LBP";
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return AlertDialog(
      title: Text(
        _label(
          isAr,
          "Add Payment",
          "\u0625\u0636\u0627\u0641\u0629 \u062f\u0641\u0639\u0629",
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _label(
                isAr,
                "Amount",
                "\u0627\u0644\u0645\u0628\u0644\u063a",
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: InputDecoration(labelText: c.t("currency")),
            items: const [
              DropdownMenuItem(value: "LBP", child: Text("LBP")),
              DropdownMenuItem(value: "USD", child: Text("USD")),
            ],
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: _label(
                isAr,
                "Note",
                "\u0645\u0644\u0627\u062d\u0638\u0629",
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(c.t("cancel")),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              "amount": parseNumberInput(_amount.text),
              "currency": _currency,
              "note": _note.text.trim(),
            });
          },
          child: Text(c.t("save")),
        ),
      ],
    );
  }
}

String _label(bool isAr, String en, String ar) => isAr ? ar : en;

DateTime? _dateFromReport(dynamic value) {
  if (value is DateTime) return value;
  final text = (value ?? "").toString();
  if (text.trim().isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

String _contactIdForReport(Map<String, dynamic> debt) {
  final raw = debt["contact"];
  if (raw is Map) return (raw["_id"] ?? raw["id"] ?? "").toString();
  return (raw ?? "").toString();
}

String _dayKey(DateTime value) {
  final local = value.toLocal();
  return _shortDate(local);
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, "0");
  final m = local.month.toString().padLeft(2, "0");
  final d = local.day.toString().padLeft(2, "0");
  return "$y-$m-$d";
}

String _shortDateTime(DateTime value) {
  final local = value.toLocal();
  final h = local.hour.toString().padLeft(2, "0");
  final min = local.minute.toString().padLeft(2, "0");
  return "${_shortDate(local)} $h:$min";
}
