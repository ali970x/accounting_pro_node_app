import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../core/smart_import_inbox.dart";
import "../../models/contact.dart";
import "../../models/product.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class SmartImportPage extends StatefulWidget {
  final ApiClient api;

  const SmartImportPage({super.key, required this.api});

  @override
  State<SmartImportPage> createState() => _SmartImportPageState();
}

class _SmartImportPageState extends State<SmartImportPage> {
  final _script = TextEditingController();
  bool _loading = true;
  bool _analyzing = false;
  bool _executing = false;
  String? _error;
  List<ContactModel> _contacts = [];
  List<Product> _products = [];
  _SmartPlan? _plan;
  final List<String> _results = [];
  String _lastAutoAnalyzed = "";

  @override
  void initState() {
    super.initState();
    SmartImportInbox.text.addListener(_useInboxText);
    _loadReferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useInboxText());
  }

  @override
  void dispose() {
    SmartImportInbox.text.removeListener(_useInboxText);
    _script.dispose();
    super.dispose();
  }

  void _useInboxText() {
    final incoming = SmartImportInbox.text.value;
    if (!mounted || incoming == null || incoming.trim().isEmpty) return;
    if (_script.text == incoming) return;
    setState(() {
      _script.text = incoming;
      _plan = null;
      _results.clear();
      _error = null;
    });
    _queueAutoAnalyze(incoming);
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait([
        widget.api.get("/contacts"),
        widget.api.get("/products"),
      ]);
      _contacts = (data[0] as List)
          .map(
            (e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      _products = (data[1] as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _loading = false);
      if (_script.text.trim().isNotEmpty) _queueAutoAnalyze(_script.text);
    }
  }

  void _queueAutoAnalyze(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned == _lastAutoAnalyzed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _analyzing) return;
      if (_script.text.trim() != cleaned) return;
      _lastAutoAnalyzed = cleaned;
      _analyze();
    });
  }

  Future<void> _analyze() async {
    final isAr = AppScope.of(context).isArabic;
    setState(() {
      _analyzing = true;
      _error = null;
      _plan = null;
      _results.clear();
    });
    try {
      final json = _extractJson(_script.text);
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw FormatException(
          _label(
            isAr,
            "Script must be a JSON object.",
            "السكريبت لازم يكون JSON object.",
          ),
        );
      }
      final plan = _SmartPlan.fromJson(
        Map<String, dynamic>.from(decoded),
        contacts: _contacts,
        products: _products,
        isAr: isAr,
      );
      setState(() => _plan = plan);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _analyzing = false);
  }

  Future<void> _execute() async {
    final isAr = AppScope.of(context).isArabic;
    final plan = _plan;
    if (plan == null || plan.hasBlockingErrors) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_label(isAr, "Execute script?", "تنفيذ السكريبت؟")),
        content: Text(
          _label(
            isAr,
            "The app will save these actions into your real database. Continue?",
            "التطبيق رح يحفظ هيدي العمليات بقاعدة البيانات الفعلية. نكمل؟",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_label(isAr, "Cancel", "إلغاء")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_label(isAr, "Execute", "تنفيذ")),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _executing = true;
      _error = null;
      _results.clear();
    });

    try {
      for (var i = 0; i < plan.actions.length; i++) {
        final action = plan.actions[i];
        await _executeAction(action, isAr);
        _results.add("${i + 1}. ${action.title(isAr)}");
        if (mounted) setState(() {});
      }
      await _loadReferences();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_label(isAr, "Script executed.", "تم تنفيذ السكريبت.")),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }

    if (mounted) setState(() => _executing = false);
  }

  Future<void> _executeAction(_SmartAction action, bool isAr) async {
    switch (action.type) {
      case "create_contact":
        final role = _roleFromAction(action, fallback: "customer");
        await _ensureContact(
          action.stringValue("name"),
          role,
          action: action,
          forceCreate: true,
        );
        return;
      case "create_product":
        await _ensureProduct(
          action.stringValue("name"),
          action: action,
          forceCreate: true,
        );
        return;
      case "create_expense":
        await widget.api.post("/expenses", {
          "title": action.stringValue(
            "title",
            fallback: action.stringValue("name", fallback: "Expense"),
          ),
          "amount": action.numberValue("amount"),
          "currency": action.currency,
          "category": action.stringValue("category", fallback: "General"),
          "date": action.stringValue("date"),
          "note": action.stringValue("note"),
        });
        return;
      case "create_debt":
        final role = _roleFromAction(action, fallback: "customer");
        final contact = await _ensureContact(
          action.contactName,
          role,
          action: action,
        );
        await widget.api.post("/debts", {
          "contact": contact.id,
          "personName": contact.name,
          "type": role == "supplier" ? "payable" : "receivable",
          "originalAmount": action.numberValue("amount"),
          "currency": action.currency,
          "dueDate": action.stringValue("dueDate"),
          "note": action.stringValue("note"),
        });
        return;
      case "receive_stock":
        final supplier = await _ensureContact(
          action.contactName,
          "supplier",
          action: action,
        );
        await widget.api.post("/products/stock/bulk", {
          "supplierId": supplier.id,
          "paymentStatus": action.paymentStatus,
          "invoiceNo": action.stringValue("invoiceNo"),
          "reason": action.stringValue("note", fallback: "Smart import"),
          "items": [
            for (final item in action.items)
              await _stockItemBody(item, createIfMissing: true),
          ],
        });
        return;
      case "create_sale":
        final customerName = action.contactName;
        ContactModel? contact;
        if (customerName.isNotEmpty) {
          contact = await _ensureContact(
            customerName,
            "customer",
            action: action,
          );
        }
        await widget.api.post("/sales", {
          "customerName": contact?.name ?? customerName,
          "contact": contact?.id,
          "paymentStatus": action.paymentStatus,
          "paymentMethod": action.paymentStatus == "debt"
              ? "debt"
              : action.stringValue("paymentMethod", fallback: "cash"),
          "discount": action.numberValue("discount"),
          "debtPaymentAmount": action.numberValue("debtPaymentAmount"),
          "debtPaymentCurrency": action.stringValue(
            "debtPaymentCurrency",
            fallback: "LBP",
          ),
          "note": action.stringValue("note"),
          "items": [for (final item in action.items) await _saleItemBody(item)],
        });
        return;
      case "mark_damaged":
        await widget.api.post("/products/damage/bulk", {
          "invoiceNo": action.stringValue("invoiceNo"),
          "reason": action.stringValue("note", fallback: "Smart import"),
          "items": [
            for (final item in action.items)
              await _stockItemBody(item, createIfMissing: false),
          ],
        });
        return;
      default:
        throw Exception(
          _label(
            isAr,
            "Unsupported action: ${action.type}",
            "عملية غير مدعومة: ${action.type}",
          ),
        );
    }
  }

  Future<ContactModel> _ensureContact(
    String name,
    String role, {
    required _SmartAction action,
    bool forceCreate = false,
  }) async {
    final normalized = _norm(name);
    if (normalized.isEmpty) throw Exception("Contact name is required.");
    if (!forceCreate) {
      final existing = _contacts.where(
        (c) => c.type == role && _norm(c.name) == normalized,
      );
      if (existing.isNotEmpty) return existing.first;
    }
    final created = await widget.api.post("/contacts", {
      "name": name,
      "phone": action.stringValue("phone"),
      "email": action.stringValue("email"),
      "address": action.stringValue("address"),
      "type": role,
      "note": action.stringValue("note"),
    });
    final contact = ContactModel.fromJson(
      Map<String, dynamic>.from(created as Map),
    );
    _contacts = [..._contacts, contact];
    return contact;
  }

  Future<Product> _ensureProduct(
    String name, {
    required _SmartAction action,
    bool forceCreate = false,
  }) async {
    final normalized = _norm(name);
    if (normalized.isEmpty) throw Exception("Product name is required.");
    if (!forceCreate) {
      final existing = _products.where((p) => _norm(p.name) == normalized);
      if (existing.isNotEmpty) return existing.first;
    }
    final created = await widget.api.post("/products", {
      "name": name,
      "category": action.stringValue("category", fallback: "General"),
      "subcategory": "General",
      "sku": action.stringValue("sku"),
      "purchasePrice": action.numberValue(
        "purchasePrice",
        fallback: action.numberValue("unitCost"),
      ),
      "purchaseCurrency": action.currency,
      "sellingPrice": action.numberValue(
        "sellingPrice",
        fallback: action.numberValue("unitPrice"),
      ),
      "quantity": action.numberValue("quantity"),
      "weight": action.numberValue("weight"),
      "minStock": action.numberValue("minStock"),
      "currency": action.currency,
      "unit": action.stringValue("unit", fallback: "Kilogram"),
    });
    final product = Product.fromJson(Map<String, dynamic>.from(created as Map));
    _products = [..._products, product];
    return product;
  }

  Future<Map<String, dynamic>> _stockItemBody(
    _SmartItem item, {
    required bool createIfMissing,
  }) async {
    final product = createIfMissing
        ? await _ensureProduct(item.productName, action: item.asAction())
        : _findProduct(item.productName);
    if (product == null) {
      throw Exception("Product not found: ${item.productName}");
    }
    return {
      "productId": product.id,
      "quantity": item.quantity,
      "packageCount": item.packageCount,
      "weight": item.weight,
      "unitCost": item.unitCost,
      "currency": item.currency,
      "reason": item.note,
    };
  }

  Future<Map<String, dynamic>> _saleItemBody(_SmartItem item) async {
    final product = _findProduct(item.productName);
    if (product == null) {
      throw Exception("Product not found: ${item.productName}");
    }
    return {
      "productId": product.id,
      "quantity": item.quantity,
      "packageCount": item.packageCount,
      "weight": item.weight,
      "unitPrice": item.unitPrice > 0 ? item.unitPrice : product.sellingPrice,
    };
  }

  Product? _findProduct(String name) {
    final normalized = _norm(name);
    for (final product in _products) {
      if (_norm(product.name) == normalized) return product;
    }
    return null;
  }

  Future<void> _copyAiGuide() async {
    await Clipboard.setData(ClipboardData(text: _aiGuide));
    if (!mounted) return;
    final isAr = AppScope.of(context).isArabic;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(
            isAr,
            "AI instructions copied.",
            "تم نسخ تعليمات الذكاء الاصطناعي.",
          ),
        ),
      ),
    );
  }

  void _insertExample() {
    _script.text = const JsonEncoder.withIndent("  ").convert(_exampleScript);
    setState(() => _plan = null);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppScope.of(context).isArabic;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: _label(isAr, "Smart Import", "الاستيراد الذكي"),
          actions: [
            OutlinedButton.icon(
              onPressed: _copyAiGuide,
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: Text(_label(isAr, "Copy AI guide", "نسخ تعليمات AI")),
            ),
            OutlinedButton.icon(
              onPressed: _insertExample,
              icon: const Icon(Icons.code_rounded, size: 18),
              label: Text(_label(isAr, "Example", "مثال")),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const LinearProgressIndicator()
        else if (_error != null)
          _MessageBox(text: _error!, color: scheme.error),
        const SizedBox(height: 10),
        ModernCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label(isAr, "Paste AI script", "الصق سكريبت الذكاء الاصطناعي"),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _label(
                  isAr,
                  "Paste JSON generated by ChatGPT or any AI. The app will preview every action before saving.",
                  "الصق JSON جاي من ChatGPT أو أي AI. التطبيق رح يعرض كل عملية قبل الحفظ.",
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _script,
                minLines: 12,
                maxLines: 20,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: "{\n  \"actions\": []\n}",
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: scheme.surface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _analyzing || _loading ? null : _analyze,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.manage_search_rounded),
                    label: Text(_label(isAr, "Analyze", "تحليل")),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        _plan == null || _plan!.hasBlockingErrors || _executing
                        ? null
                        : _execute,
                    icon: _executing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_label(isAr, "Confirm and save", "تأكيد وحفظ")),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_plan != null) _PlanPreview(plan: _plan!, isAr: isAr),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 14),
          ModernCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(isAr, "Executed", "تم التنفيذ"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in _results) Text(line),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _GuideCard(isAr: isAr),
      ],
    );
  }
}

class _PlanPreview extends StatelessWidget {
  final _SmartPlan plan;
  final bool isAr;

  const _PlanPreview({required this.plan, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label(isAr, "Preview", "المعاينة"),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _label(
              isAr,
              "${plan.actions.length} actions ready. Review warnings before saving.",
              "${plan.actions.length} عملية جاهزة. راجع التنبيهات قبل الحفظ.",
            ),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < plan.actions.length; i++)
            _ActionTile(index: i + 1, action: plan.actions[i], isAr: isAr),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final int index;
  final _SmartAction action;
  final bool isAr;

  const _ActionTile({
    required this.index,
    required this.action,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = action.messages.any((m) => m.isError);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError ? scheme.error : scheme.outlineVariant,
        ),
        color: hasError
            ? scheme.errorContainer.withValues(alpha: 0.22)
            : scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$index. ${action.title(isAr)}",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(action.summary(isAr)),
          if (action.messages.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final message in action.messages)
              Text(
                "${message.isError ? "!" : "-"} ${message.text}",
                style: TextStyle(
                  color: message.isError ? scheme.error : scheme.tertiary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final bool isAr;

  const _GuideCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label(isAr, "How to use it with AI", "كيف تستعملها مع AI"),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _label(
              isAr,
              "Copy the AI guide, give it to ChatGPT with your voice/list/photo text, then paste the returned JSON here.",
              "انسخ تعليمات AI، أعطها لـ ChatGPT مع الكلام أو اللائحة أو نص الصورة، وبعدها الصق JSON هون.",
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String text;
  final Color color;

  const _MessageBox({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

class _SmartPlan {
  final List<_SmartAction> actions;

  const _SmartPlan({required this.actions});

  bool get hasBlockingErrors =>
      actions.any((a) => a.messages.any((m) => m.isError));

  factory _SmartPlan.fromJson(
    Map<String, dynamic> json, {
    required List<ContactModel> contacts,
    required List<Product> products,
    required bool isAr,
  }) {
    final raw = json["actions"];
    if (raw is! List || raw.isEmpty) {
      throw FormatException(
        _label(
          isAr,
          "actions must be a non-empty array.",
          "actions لازم تكون لائحة غير فارغة.",
        ),
      );
    }
    final actions = raw
        .whereType<Map>()
        .map((e) => _SmartAction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    for (final action in actions) {
      action.validate(contacts: contacts, products: products, isAr: isAr);
    }
    return _SmartPlan(actions: actions);
  }
}

class _SmartAction {
  final String type;
  final Map<String, dynamic> data;
  final List<_ActionMessage> messages = [];

  _SmartAction({required this.type, required this.data});

  factory _SmartAction.fromJson(Map<String, dynamic> json) {
    return _SmartAction(
      type: (json["type"] ?? json["action"] ?? "").toString(),
      data: json,
    );
  }

  List<_SmartItem> get items {
    final raw = data["items"];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => _SmartItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  String get contactName => stringValue(
    "contactName",
    fallback: stringValue(
      "customerName",
      fallback: stringValue("supplierName"),
    ),
  );

  String get currency =>
      stringValue("currency", fallback: "LBP") == "USD" ? "USD" : "LBP";

  String get paymentStatus =>
      stringValue("paymentStatus", fallback: "paid") == "debt"
      ? "debt"
      : "paid";

  String stringValue(String key, {String fallback = ""}) =>
      (data[key] ?? fallback).toString().trim();

  double numberValue(String key, {double fallback = 0}) {
    if (!data.containsKey(key)) return fallback;
    return numFromDynamic(data[key], fallback: fallback);
  }

  void validate({
    required List<ContactModel> contacts,
    required List<Product> products,
    required bool isAr,
  }) {
    messages.clear();
    const supported = {
      "create_contact",
      "create_product",
      "create_expense",
      "create_debt",
      "receive_stock",
      "create_sale",
      "mark_damaged",
    };
    if (!supported.contains(type)) {
      messages.add(const _ActionMessage("Unsupported action type.", true));
      return;
    }
    if ((type == "create_contact" || type == "create_product") &&
        stringValue("name").isEmpty) {
      messages.add(const _ActionMessage("name is required.", true));
    }
    if (type == "create_expense" && numberValue("amount") <= 0) {
      messages.add(const _ActionMessage("Expense amount is required.", true));
    }
    if (type == "create_debt") {
      if (contactName.isEmpty) {
        messages.add(const _ActionMessage("Contact name is required.", true));
      }
      if (numberValue("amount") <= 0) {
        messages.add(const _ActionMessage("Debt amount is required.", true));
      }
    }
    if (["receive_stock", "create_sale", "mark_damaged"].contains(type) &&
        items.isEmpty) {
      messages.add(const _ActionMessage("items are required.", true));
    }
    if (type == "receive_stock" && contactName.isEmpty) {
      messages.add(const _ActionMessage("Supplier name is required.", true));
    }
    if (type == "create_sale" &&
        paymentStatus == "debt" &&
        contactName.isEmpty) {
      messages.add(const _ActionMessage("Debt sale needs customerName.", true));
    }
    for (final item in items) {
      if (item.productName.isEmpty) {
        messages.add(
          const _ActionMessage("Every item needs productName.", true),
        );
      }
      if (item.quantity <= 0) {
        messages.add(
          const _ActionMessage("Every item needs quantity > 0.", true),
        );
      }
      final exists = products.any(
        (p) => _norm(p.name) == _norm(item.productName),
      );
      if (!exists && type != "receive_stock") {
        messages.add(
          _ActionMessage("Product not found: ${item.productName}", true),
        );
      }
      if (!exists && type == "receive_stock") {
        messages.add(
          _ActionMessage(
            "Will create product if missing: ${item.productName}",
            false,
          ),
        );
      }
    }
    if (["create_debt", "create_sale", "receive_stock"].contains(type) &&
        contactName.isNotEmpty) {
      final role = _roleFromAction(
        this,
        fallback: type == "receive_stock" ? "supplier" : "customer",
      );
      final exists = contacts.any(
        (c) => c.type == role && _norm(c.name) == _norm(contactName),
      );
      if (!exists) {
        messages.add(
          _ActionMessage("Will create contact if missing: $contactName", false),
        );
      }
    }
  }

  String title(bool isAr) {
    switch (type) {
      case "create_contact":
        return _label(isAr, "Create contact", "إضافة اسم");
      case "create_product":
        return _label(isAr, "Create product", "إضافة منتج");
      case "create_expense":
        return _label(isAr, "Create expense", "إضافة مصروف");
      case "create_debt":
        return _label(isAr, "Create debt", "إضافة دين");
      case "receive_stock":
        return _label(isAr, "Receive stock", "توريد بضاعة");
      case "create_sale":
        return _label(isAr, "Create sale invoice", "إنشاء فاتورة مبيع");
      case "mark_damaged":
        return _label(isAr, "Mark damaged goods", "تسجيل بضاعة تالفة");
      default:
        return type;
    }
  }

  String summary(bool isAr) {
    if (type == "create_contact") return stringValue("name");
    if (type == "create_product") return stringValue("name");
    if (type == "create_expense") {
      return "${stringValue("title")} - ${money(numberValue("amount"), currency)}";
    }
    if (type == "create_debt") {
      return "$contactName - ${money(numberValue("amount"), currency)}";
    }
    if (["receive_stock", "create_sale", "mark_damaged"].contains(type)) {
      return "$contactName - ${items.length} ${_label(isAr, "items", "أصناف")}";
    }
    return "";
  }
}

class _SmartItem {
  final Map<String, dynamic> data;

  const _SmartItem(this.data);

  factory _SmartItem.fromJson(Map<String, dynamic> json) => _SmartItem(json);

  String get productName =>
      (data["productName"] ?? data["name"] ?? "").toString().trim();
  String get currency =>
      (data["currency"] ?? "LBP").toString() == "USD" ? "USD" : "LBP";
  String get note => (data["note"] ?? data["reason"] ?? "").toString();
  double get quantity => numFromDynamic(data["quantity"], fallback: 0);
  double get packageCount => numFromDynamic(data["packageCount"], fallback: 0);
  double get weight => numFromDynamic(data["weight"], fallback: 0);
  double get unitCost =>
      numFromDynamic(data["unitCost"] ?? data["purchasePrice"], fallback: 0);
  double get unitPrice =>
      numFromDynamic(data["unitPrice"] ?? data["sellingPrice"], fallback: 0);

  _SmartAction asAction() => _SmartAction(
    type: "create_product",
    data: {
      "name": productName,
      "category": data["category"] ?? "General",
      "purchasePrice": unitCost,
      "sellingPrice": unitPrice > 0 ? unitPrice : unitCost,
      "currency": currency,
      "unit": data["unit"] ?? "Kilogram",
    },
  );
}

class _ActionMessage {
  final String text;
  final bool isError;

  const _ActionMessage(this.text, this.isError);
}

String _extractJson(String input) {
  final trimmed = input.trim();
  final fence = RegExp(
    r"```(?:json)?\s*([\s\S]*?)```",
    caseSensitive: false,
  ).firstMatch(trimmed);
  final raw = fence?.group(1)?.trim() ?? trimmed;
  final start = raw.indexOf("{");
  final end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) {
    throw const FormatException("No JSON object found.");
  }
  return raw.substring(start, end + 1);
}

String _roleFromAction(_SmartAction action, {required String fallback}) {
  final role = action.stringValue(
    "role",
    fallback: action.stringValue("contactType", fallback: fallback),
  );
  if (["supplier", "vendor", "payable"].contains(role)) {
    return "supplier";
  }
  return "customer";
}

String _norm(String value) => value.trim().toLowerCase();

String _label(bool isAr, String en, String ar) => en;

const _exampleScript = {
  "version": 1,
  "actions": [
    {
      "type": "create_contact",
      "role": "customer",
      "name": "Ali Customer",
      "phone": "+96170000000",
    },
    {
      "type": "create_expense",
      "title": "Transport",
      "amount": 250000,
      "currency": "LBP",
      "category": "Delivery",
    },
    {
      "type": "receive_stock",
      "supplierName": "Hassan Supplier",
      "paymentStatus": "debt",
      "items": [
        {
          "productName": "Tomato",
          "quantity": 10,
          "weight": 10.5,
          "unitCost": 50000,
          "currency": "LBP",
          "category": "Vegetables",
        },
      ],
    },
  ],
};

const _aiGuide = """
You are generating a safe daftr Smart Import script.
Return JSON only. Do not return prose.

Schema:
{
  "version": 1,
  "actions": [
    {
      "type": "create_contact",
      "role": "customer | supplier",
      "name": "required",
      "phone": "",
      "email": "",
      "address": "",
      "note": ""
    },
    {
      "type": "create_product",
      "name": "required",
      "category": "General",
      "purchasePrice": 0,
      "sellingPrice": 0,
      "quantity": 0,
      "weight": 0,
      "currency": "LBP | USD",
      "unit": "Kilogram | Piece | Box | Bag"
    },
    {
      "type": "create_expense",
      "title": "required",
      "amount": 0,
      "currency": "LBP | USD",
      "category": "General",
      "date": "YYYY-MM-DD",
      "note": ""
    },
    {
      "type": "create_debt",
      "role": "customer | supplier",
      "contactName": "required",
      "amount": 0,
      "currency": "LBP | USD",
      "note": ""
    },
    {
      "type": "receive_stock",
      "supplierName": "required",
      "paymentStatus": "paid | debt",
      "invoiceNo": "",
      "items": [
        {
          "productName": "required",
          "category": "General",
          "quantity": 0,
          "packageCount": 0,
          "weight": 0,
          "unitCost": 0,
          "currency": "LBP | USD",
          "note": ""
        }
      ]
    },
    {
      "type": "create_sale",
      "customerName": "required when paymentStatus is debt",
      "paymentStatus": "paid | debt",
      "paymentMethod": "cash | bank | card | transfer | other",
      "discount": 0,
      "debtPaymentAmount": 0,
      "debtPaymentCurrency": "LBP | USD",
      "items": [
        {
          "productName": "must already exist",
          "quantity": 0,
          "packageCount": 0,
          "weight": 0,
          "unitPrice": 0
        }
      ]
    },
    {
      "type": "mark_damaged",
      "invoiceNo": "",
      "note": "",
      "items": [
        {
          "productName": "must already exist",
          "quantity": 0,
          "weight": 0,
          "unitCost": 0,
          "currency": "LBP | USD",
          "note": ""
        }
      ]
    }
  ]
}

Rules:
- Use numbers without commas.
- Use LBP by default unless the user clearly says dollars.
- If user says "اشتريت" from a supplier, use receive_stock.
- If user says "بعت" or "فاتورة مبيع", use create_sale.
- If user says someone owes me, use create_debt with role customer.
- If I owe a supplier, use create_debt with role supplier.
- If text is unclear, do not guess important amounts; return no action or add note.
""";
