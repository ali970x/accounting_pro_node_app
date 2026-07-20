import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../core/phone_text.dart";
import "../../core/pdf/pdf_service.dart";
import "../../models/contact.dart";
import "../../models/invoice_template.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class ContactsPage extends StatefulWidget {
  final ApiClient api;

  const ContactsPage({super.key, required this.api});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _loading = true;
  String? _error;
  List<ContactModel> _contacts = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
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
      final data = await widget.api.get("/contacts");
      _contacts = (data as List)
          .map(
            (e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  List<ContactModel> _filtered(String type) {
    final q = _search.text.trim().toLowerCase();
    return _contacts.where((c) {
      final matchType = c.type == type;
      final matchSearch =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.address.toLowerCase().contains(q) ||
          c
              .customerKindLabel(AppScope.of(context).isArabic)
              .toLowerCase()
              .contains(q);
      return matchType && matchSearch;
    }).toList();
  }

  Future<void> _addOrEdit({ContactModel? contact, required String type}) async {
    final body = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ContactDialog",
      pageBuilder: (context, _, __) =>
          ContactDialog(contact: contact, type: type),
    );

    if (body == null) return;

    try {
      if (contact == null) {
        await widget.api.post("/contacts", body);
      } else {
        await widget.api.put("/contacts/${contact.id}", body);
      }
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

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Builder(
          builder: (context) {
            final tab = DefaultTabController.of(context).index;
            final type = tab == 0 ? "supplier" : "customer";
            return FloatingActionButton.extended(
              onPressed: () => _addOrEdit(type: type),
              icon: const Icon(Icons.person_add_rounded),
              label: Text(
                c.isArabic
                    ? (type == "supplier" ? "إضافة مورد" : "إضافة زبون")
                    : "Add",
              ),
            );
          },
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(title: c.t("contacts")),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: c.isArabic
                          ? "بحث بالاسم أو الرقم..."
                          : "Search...",
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModernCard(
                    padding: const EdgeInsets.all(6),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: theme.colorScheme.onPrimary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      tabs: [
                        Tab(text: c.isArabic ? "الموردين" : "Suppliers"),
                        Tab(text: c.isArabic ? "الزباين" : "Customers"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      children: [
                        _ContactListView(
                          contacts: _filtered("supplier"),
                          onEdit: (m) =>
                              _addOrEdit(contact: m, type: "supplier"),
                          onDelete: (m) => _delete(m),
                          onMovement: _showMovementStatement,
                          onLedger: _showFinancialLedger,
                        ),
                        _ContactListView(
                          contacts: _filtered("customer"),
                          onEdit: (m) =>
                              _addOrEdit(contact: m, type: "customer"),
                          onDelete: (m) => _delete(m),
                          onMovement: _showMovementStatement,
                          onLedger: _showFinancialLedger,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMovementStatement(ContactModel contact) async {
    try {
      final raw = await widget.api.get("/records/stock-movements");
      final rows = (raw as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) {
            final contactId = contact.type == "supplier"
                ? (row["supplier"] ?? "").toString()
                : (row["customer"] ?? "").toString();
            final name = contact.type == "supplier"
                ? (row["supplierName"] ?? "").toString()
                : (row["customerName"] ?? "").toString();
            final type = (row["type"] ?? "").toString();
            final matchType = contact.type == "supplier"
                ? type == "purchase"
                : (type == "sale" || type == "return");
            return matchType &&
                (contactId == contact.id || name == contact.name);
          })
          .toList();

      final rawTemplate = await widget.api.get("/invoice-template");
      final template = InvoiceTemplateModel.fromJson(
        Map<String, dynamic>.from(rawTemplate as Map),
      );
      if (!mounted) return;
      await _showGoodsInvoiceOptions(
        contact: contact,
        movements: rows,
        template: template,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showGoodsInvoiceOptions({
    required ContactModel contact,
    required List<Map<String, dynamic>> movements,
    required InvoiceTemplateModel template,
  }) async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? "فاتورة باسم ${contact.name}" : "Invoice for ${contact.name}",
        ),
        content: Text(
          isAr
              ? "اختار كيف بدك تستخدم الفاتورة."
              : "Choose what to do with this invoice.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? "إغلاق" : "Close"),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final languageCode = c.languageCode;
              Navigator.pop(ctx);
              await _runGoodsInvoiceAction(
                () => PdfService.printGoodsMovementInvoice(
                  languageCode: languageCode,
                  contactName: contact.name,
                  contactType: contact.type,
                  movements: movements,
                  template: template,
                ),
              );
            },
            icon: const Icon(Icons.print_rounded),
            label: Text(isAr ? "طباعة" : "Print"),
          ),
          FilledButton.icon(
            onPressed: () async {
              final languageCode = c.languageCode;
              Navigator.pop(ctx);
              await _runGoodsInvoiceAction(
                () => PdfService.shareGoodsMovementInvoice(
                  languageCode: languageCode,
                  contactName: contact.name,
                  contactType: contact.type,
                  movements: movements,
                  template: template,
                ),
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: Text(isAr ? "مشاركة" : "Share"),
          ),
        ],
      ),
    );
  }

  Future<void> _runGoodsInvoiceAction(Future<void> Function() action) async {
    final isAr = AppScope.of(context).isArabic;
    var loadingOpen = false;

    if (mounted) {
      loadingOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isAr ? "جاري تجهيز الفاتورة..." : "Preparing invoice...",
                ),
              ),
            ],
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    Object? failure;
    try {
      await action().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      failure = isAr
          ? "تجهيز الفاتورة أخذ وقت طويل. جرّب مشاركة PDF أو قلّل الفترة المعروضة."
          : "Preparing the invoice took too long. Try sharing PDF or narrowing the period.";
    } catch (e) {
      failure = e;
    } finally {
      if (mounted && loadingOpen) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }

    if (failure != null && mounted) {
      _showError(failure);
    }
  }

  Future<void> _showFinancialLedger(ContactModel contact) async {
    final isAr = AppScope.of(context).isArabic;
    try {
      final raw = await widget.api.get("/debts");
      final rows = (raw as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) {
            final contactId = (row["contact"] ?? "").toString();
            final name = (row["personName"] ?? "").toString();
            return contactId == contact.id || name == contact.name;
          })
          .toList();

      final message = _ledgerMessage(contact, rows, isAr);
      if (!mounted) return;
      await _showShareDialog(
        title: isAr
            ? "\u0627\u0644\u062c\u0631\u062f\u0629 \u0627\u0644\u0645\u0627\u0644\u064a\u0629"
            : "Financial Ledger",
        message: message,
        contact: contact,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showShareDialog({
    required String title,
    required String message,
    required ContactModel contact,
  }) async {
    final isAr = AppScope.of(context).isArabic;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(message)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? "\u0625\u063a\u0644\u0627\u0642" : "Close"),
          ),
          OutlinedButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: message)),
            icon: const Icon(Icons.copy_rounded),
            label: Text(isAr ? "\u0646\u0633\u062e" : "Copy"),
          ),
          FilledButton.icon(
            onPressed: contact.phone.trim().isEmpty
                ? null
                : () => _shareWhatsapp(contact, message),
            icon: const Icon(Icons.send_rounded),
            label: Text(
              isAr ? "\u0648\u0627\u062a\u0633\u0627\u0628" : "WhatsApp",
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareWhatsapp(ContactModel contact, String message) async {
    final digits = contact.fullPhone.replaceAll(RegExp(r"[^0-9]"), "");
    final uri = Uri.parse(
      "https://wa.me/$digits?text=${Uri.encodeComponent(message)}",
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: message));
      _showError("Could not open WhatsApp. Text copied.");
    }
  }

  String _ledgerMessage(
    ContactModel contact,
    List<Map<String, dynamic>> debts,
    bool isAr,
  ) {
    final totals = _debtTotals(debts);
    final lines = <String>[
      isAr
          ? "\u062c\u0631\u062f\u0629 \u0645\u0627\u0644\u064a\u0629"
          : "Financial Ledger",
      "${isAr ? "\u0627\u0644\u0627\u0633\u0645" : "Name"}: ${contact.name}",
      "${isAr ? "\u0627\u0644\u062a\u0627\u0631\u064a\u062e" : "Date"}: ${DateTime.now().toString().substring(0, 16)}",
      "",
      "${isAr ? "\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631" : "Invoices total"}: ${money(totals["originalLBP"] ?? 0, "LBP")} / ${money(totals["originalUSD"] ?? 0, "USD")}",
      "${isAr ? "\u0627\u0644\u0645\u062f\u0641\u0648\u0639" : "Paid"}: ${money(totals["paidLBP"] ?? 0, "LBP")} / ${money(totals["paidUSD"] ?? 0, "USD")}",
      "${isAr ? "\u0627\u0644\u0628\u0627\u0642\u064a" : "Remaining"}: ${money(totals["remainingLBP"] ?? 0, "LBP")} / ${money(totals["remainingUSD"] ?? 0, "USD")}",
      "",
    ];
    if (debts.isEmpty) {
      lines.add(
        isAr
            ? "\u0644\u0627 \u064a\u0648\u062c\u062f \u062f\u064a\u0648\u0646 \u0623\u0648 \u062f\u0641\u0639\u0627\u062a \u0645\u0633\u062c\u0644\u0629."
            : "No debts or payments recorded.",
      );
      return lines.join("\n");
    }
    for (final debt in debts) {
      final currency = (debt["currency"] ?? "LBP").toString();
      lines.add(
        "- ${_shortDate(debt["createdAt"])} | ${(debt["note"] ?? "").toString()}",
      );
      lines.add(
        "  ${isAr ? "\u0642\u064a\u0645\u0629 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629" : "Invoice"}: ${money(_num(debt["originalAmount"]), currency)}",
      );
      lines.add(
        "  ${isAr ? "\u0627\u0644\u0648\u0627\u0635\u0644" : "Received/Paid"}: ${money(_num(debt["paidAmount"]), currency)}",
      );
      lines.add(
        "  ${isAr ? "\u0627\u0644\u0628\u0627\u0642\u064a" : "Remaining"}: ${money(_num(debt["remainingAmount"]), currency)}",
      );
      final payments = debt["payments"];
      if (payments is List && payments.isNotEmpty) {
        for (final p in payments.whereType<Map>()) {
          final payment = Map<String, dynamic>.from(p);
          final pc = (payment["currency"] ?? currency).toString();
          lines.add(
            "    ${isAr ? "\u062f\u0641\u0639\u0629" : "Payment"} ${_shortDate(payment["date"])}: ${money(_num(payment["amount"]), pc)} ${(payment["note"] ?? "").toString()}",
          );
        }
      }
    }
    return lines.join("\n");
  }

  Map<String, double> _debtTotals(List<Map<String, dynamic>> debts) {
    final totals = {
      "originalLBP": 0.0,
      "originalUSD": 0.0,
      "paidLBP": 0.0,
      "paidUSD": 0.0,
      "remainingLBP": 0.0,
      "remainingUSD": 0.0,
    };
    for (final debt in debts) {
      final suffix = (debt["currency"] ?? "LBP").toString() == "USD"
          ? "USD"
          : "LBP";
      totals["original$suffix"] =
          (totals["original$suffix"] ?? 0) + _num(debt["originalAmount"]);
      totals["paid$suffix"] =
          (totals["paid$suffix"] ?? 0) + _num(debt["paidAmount"]);
      totals["remaining$suffix"] =
          (totals["remaining$suffix"] ?? 0) + _num(debt["remainingAmount"]);
    }
    return totals;
  }

  String _shortDate(dynamic raw) {
    final text = (raw ?? "").toString();
    if (text.isEmpty) return "-";
    return text
        .substring(0, text.length < 16 ? text.length : 16)
        .replaceFirst("T", " ");
  }

  double _num(dynamic value) {
    return numFromDynamic(value);
  }

  Future<void> _delete(ContactModel contact) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 48,
        ),
        content: Text(
          AppScope.of(context).isArabic
              ? "هل أنت متأكد من حذف هذا الاسم؟"
              : "Delete this contact?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppScope.of(context).t("cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppScope.of(context).t("delete")),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.delete("/contacts/${contact.id}");
      await _load();
    } catch (e) {
      _showError(e);
    }
  }
}

class _ContactListView extends StatelessWidget {
  final List<ContactModel> contacts;
  final Function(ContactModel) onEdit;
  final Function(ContactModel) onDelete;
  final Function(ContactModel) onMovement;
  final Function(ContactModel) onLedger;

  const _ContactListView({
    required this.contacts,
    required this.onEdit,
    required this.onDelete,
    required this.onMovement,
    required this.onLedger,
  });

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              AppScope.of(context).t("empty"),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: contacts.length,
      itemBuilder: (_, i) {
        final m = contacts[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            onTap: () => onEdit(m),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    m.type == "supplier"
                        ? Icons.local_shipping_rounded
                        : Icons.person_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (m.type == "customer") ...[
                        _kindChip(context, m),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          PhoneText(
                            m.fullPhone,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (m.address.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                m.address,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == "movement") onMovement(m);
                    if (value == "ledger") onLedger(m);
                    if (value == "edit") onEdit(m);
                    if (value == "delete") onDelete(m);
                  },
                  itemBuilder: (context) {
                    final isAr = AppScope.of(context).isArabic;
                    return [
                      PopupMenuItem(
                        value: "movement",
                        child: Text(
                          isAr
                              ? "\u062d\u0631\u0643\u0629 \u0648\u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u0636\u0627\u0639\u0629"
                              : "Goods movement invoice",
                        ),
                      ),
                      PopupMenuItem(
                        value: "ledger",
                        child: Text(
                          isAr
                              ? "\u062c\u0631\u062f\u0629 \u0645\u0627\u0644\u064a\u0629"
                              : "Financial ledger",
                        ),
                      ),
                      PopupMenuItem(
                        value: "edit",
                        child: Text(
                          isAr ? "\u062a\u0639\u062f\u064a\u0644" : "Edit",
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Text(isAr ? "\u062d\u0630\u0641" : "Delete"),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kindChip(BuildContext context, ContactModel contact) {
    final isWholesale = contact.customerKind == "wholesale";
    final color = isWholesale ? Colors.indigo : Colors.teal;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Text(
          contact.customerKindLabel(AppScope.of(context).isArabic),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class ContactDialog extends StatefulWidget {
  final ContactModel? contact;
  final String type;

  const ContactDialog({super.key, required this.contact, required this.type});

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<ContactDialog> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController note;
  String countryCode = "+961";
  String customerKind = "retail";

  @override
  void initState() {
    super.initState();
    final x = widget.contact;
    name = TextEditingController(text: x?.name ?? "");
    phone = TextEditingController(text: x?.phone ?? "");
    address = TextEditingController(text: x?.address ?? "");
    note = TextEditingController(text: x?.note ?? "");
    countryCode = x?.countryCode ?? "+961";
    customerKind = x?.customerKind ?? "retail";
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.contact == null
                    ? (isAr
                          ? (widget.type == "supplier"
                                ? "إضافة مورد جديد"
                                : "إضافة زبون جديد")
                          : "Add Contact")
                    : (isAr ? "تعديل البيانات" : "Edit Contact"),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 45,
                child: Icon(
                  widget.type == "supplier"
                      ? Icons.local_shipping_rounded
                      : Icons.person_rounded,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.type == "customer") ...[
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: "retail",
                      icon: const Icon(Icons.person_rounded),
                      label: Text(isAr ? "زبون عادي" : "Retail"),
                    ),
                    ButtonSegment(
                      value: "wholesale",
                      icon: const Icon(Icons.groups_rounded),
                      label: Text(isAr ? "عميل جملة" : "Wholesale"),
                    ),
                  ],
                  selected: {customerKind},
                  onSelectionChanged: (value) =>
                      setState(() => customerKind = value.first),
                ),
                const SizedBox(height: 16),
              ],
              _field(isAr ? "الاسم" : "Name", name, icon: Icons.person_rounded),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: countryCode,
                      decoration: _inputDeco(isAr ? "الرمز" : "Code"),
                      items: ["+961", "+966", "+971", "+965", "+962", "+20"]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => countryCode = v ?? "+961"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      isAr ? "رقم الهاتف" : "Phone",
                      phone,
                      icon: Icons.phone_rounded,
                      type: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                isAr ? "العنوان" : "Address",
                address,
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 12),
              _field(
                isAr ? "ملاحظة" : "Note",
                note,
                icon: Icons.notes_rounded,
                lines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(c.t("cancel")),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (name.text.trim().isEmpty) return;
                        Navigator.pop(context, {
                          "name": name.text.trim(),
                          "phone": phone.text.trim(),
                          "countryCode": countryCode,
                          "imageUrl": "",
                          "address": address.text.trim(),
                          "note": note.text.trim(),
                          "type": widget.type,
                          "customerKind": widget.type == "customer"
                              ? customerKind
                              : "retail",
                        });
                      },
                      child: Text(c.t("save")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    IconData? icon,
    int lines = 1,
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: type,
      decoration: _inputDeco(label, icon: icon),
      onChanged: (_) {},
    );
  }
}
