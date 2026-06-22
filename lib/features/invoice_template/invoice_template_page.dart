import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../models/invoice_template.dart";
import "../../widgets/modern_card.dart";

class InvoiceTemplatePage extends StatefulWidget {
  final ApiClient api;
  const InvoiceTemplatePage({super.key, required this.api});

  @override
  State<InvoiceTemplatePage> createState() => _InvoiceTemplatePageState();
}

class _InvoiceTemplatePageState extends State<InvoiceTemplatePage> {
  bool loading = true;
  String? error;

  final businessName = TextEditingController();
  final businessPhone = TextEditingController();
  final businessAddress = TextEditingController();
  final invoiceTitle = TextEditingController();
  final footerNote = TextEditingController();
  final terms = TextEditingController();
  final logoUrl = TextEditingController();

  String colorHex = "#4F46E5";
  bool showLogo = true;
  bool showSignature = true;

  @override
  void initState() {
    super.initState();
    load();
    for (final x in [businessName, businessPhone, businessAddress, invoiceTitle, footerNote, terms, logoUrl]) {
      x.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    businessName.dispose();
    businessPhone.dispose();
    businessAddress.dispose();
    invoiceTitle.dispose();
    footerNote.dispose();
    terms.dispose();
    logoUrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.get("/invoice-template");
      final t = InvoiceTemplateModel.fromJson(Map<String, dynamic>.from(data as Map));
      businessName.text = t.businessName;
      businessPhone.text = t.businessPhone;
      businessAddress.text = t.businessAddress;
      invoiceTitle.text = t.invoiceTitle;
      footerNote.text = t.footerNote;
      terms.text = t.terms;
      logoUrl.text = t.logoUrl;
      colorHex = t.colorHex;
      showLogo = t.showLogo;
      showSignature = t.showSignature;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    final c = AppScope.of(context);
    try {
      await widget.api.put("/invoice-template", current().toJson());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.t("save"))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  InvoiceTemplateModel current() {
    return InvoiceTemplateModel(
      businessName: businessName.text.trim().isEmpty ? "Accounting Pro" : businessName.text.trim(),
      businessPhone: businessPhone.text.trim(),
      businessAddress: businessAddress.text.trim(),
      invoiceTitle: invoiceTitle.text.trim().isEmpty ? "Sales Invoice" : invoiceTitle.text.trim(),
      footerNote: footerNote.text.trim(),
      terms: terms.text.trim(),
      logoUrl: logoUrl.text.trim(),
      colorHex: colorHex,
      showLogo: showLogo,
      showSignature: showSignature,
    );
  }

  Color colorFromHex(String hex) {
    var h = hex.replaceAll("#", "");
    if (h.length == 6) h = "FF$h";
    return Color(int.parse(h, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);

    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error!));

    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth > 950;

        final form = ModernCard(
          child: ListView(
            children: [
              Text(c.t("invoiceTemplate"), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              field(c.t("businessName"), businessName),
              field(c.t("businessPhone"), businessPhone),
              field(c.t("businessAddress"), businessAddress),
              field(c.t("invoiceTitle"), invoiceTitle),
              field(c.t("logoUrl"), logoUrl),
              field(c.t("footerNote"), footerNote, lines: 2),
              field(c.t("terms"), terms, lines: 3),
              DropdownButtonFormField<String>(
                value: colorHex,
                decoration: InputDecoration(labelText: c.t("color")),
                items: const [
                  DropdownMenuItem(value: "#4F46E5", child: Text("Blue")),
                  DropdownMenuItem(value: "#111827", child: Text("Black")),
                  DropdownMenuItem(value: "#059669", child: Text("Green")),
                  DropdownMenuItem(value: "#DC2626", child: Text("Red")),
                  DropdownMenuItem(value: "#B45309", child: Text("Gold")),
                ],
                onChanged: (v) => setState(() => colorHex = v ?? "#4F46E5"),
              ),
              SwitchListTile(value: showLogo, title: Text(c.t("showLogo")), onChanged: (v) => setState(() => showLogo = v)),
              SwitchListTile(value: showSignature, title: Text(c.t("showSignature")), onChanged: (v) => setState(() => showSignature = v)),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: Text(c.t("save"))),
            ],
          ),
        );

        final preview = InvoicePreview(template: current(), color: colorFromHex(colorHex));

        return Padding(
          padding: const EdgeInsets.all(18),
          child: wide
              ? Row(children: [Expanded(child: form), const SizedBox(width: 14), Expanded(child: preview)])
              : ListView(children: [SizedBox(height: 760, child: form), const SizedBox(height: 14), SizedBox(height: 760, child: preview)]),
        );
      },
    );
  }

  Widget field(String label, TextEditingController controller, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: controller, maxLines: lines, decoration: InputDecoration(labelText: label)),
    );
  }
}

class InvoicePreview extends StatelessWidget {
  final InvoiceTemplateModel template;
  final Color color;

  const InvoicePreview({super.key, required this.template, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);

    return ModernCard(
      child: ListView(
        children: [
          Text(c.t("preview"), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(
                    children: [
                      if (template.showLogo)
                        Container(
                          width: 64,
                          height: 64,
                          color: Colors.white24,
                          child: template.logoUrl.isEmpty ? const Icon(Icons.image, color: Colors.white) : Image.network(template.logoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white)),
                        ),
                      if (template.showLogo) const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(template.businessName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            if (template.businessPhone.isNotEmpty) Text(template.businessPhone, style: const TextStyle(color: Colors.white)),
                            if (template.businessAddress.isNotEmpty) Text(template.businessAddress, style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.invoiceTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text("${c.t("invoiceNo")}: INV-000001"),
                      Text("${c.t("billTo")}: Walk-in Customer"),
                      const SizedBox(height: 18),
                      Table(
                        border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
                        children: [
                          TableRow(children: [cell(c.t("productName"), true), cell(c.t("quantity"), true), cell(c.t("unitPrice"), true), cell("Total", true)]),
                          TableRow(children: [cell("Sample Product", false), cell("2", false), cell("\$10.00", false), cell("\$20.00", false)]),
                        ],
                      ),
                      if (template.footerNote.isNotEmpty) ...[const SizedBox(height: 14), Text(template.footerNote)],
                      if (template.terms.isNotEmpty) ...[const SizedBox(height: 10), Text(template.terms)],
                      if (template.showSignature) ...[const SizedBox(height: 30), Align(alignment: Alignment.centerRight, child: Text("__________________\n${c.t("signature")}", textAlign: TextAlign.center))],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget cell(String text, bool bold) {
    return Padding(padding: const EdgeInsets.all(8), child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)));
  }
}
