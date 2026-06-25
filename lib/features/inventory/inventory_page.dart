import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/contact.dart";
import "../../models/product.dart";
import "../../widgets/modern_card.dart";
import "product_details_page.dart";
import "product_form_dialog.dart";

class InventoryPage extends StatefulWidget {
  final ApiClient api;
  const InventoryPage({super.key, required this.api});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _loading = true;
  String? _error;
  List<Product> _products = [];
  List<ContactModel> _suppliers = [];
  List<Map<String, dynamic>> _debts = [];
  final _searchController = TextEditingController();
  final Set<String> _closedCategories = {};
  final Set<String> _closedSubcategories = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.get("/products"),
        widget.api.get("/contacts"),
        widget.api.get("/debts"),
      ]);
      _products = (results[0] as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      _suppliers = (results[1] as List)
          .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((contact) => contact.type == "supplier")
          .toList();
      _debts = (results[2] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addProduct() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ProductFormDialog(existingProducts: _products),
    );
    if (result == null) return;

    try {
      await widget.api.post("/products", result);
      await _loadProducts();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openProduct(Product p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsPage(api: widget.api, productId: p.id)),
    );
    await _loadProducts();
  }

  Future<void> _openBulkSupply() async {
    final isAr = AppScope.of(context).isArabic;
    if (_products.isEmpty) return _showError(isAr ? "لا يوجد منتجات للتوريد" : "No products available");
    if (_suppliers.isEmpty) return _showError(isAr ? "أضف مورد أولاً من صفحة الأسماء" : "Add a supplier first");

    final result = await showDialog<_BulkSupplyResult>(
      context: context,
      builder: (_) => _BulkSupplyDialog(products: _products, suppliers: _suppliers, debts: _debts),
    );
    if (result == null) return;

    try {
      await widget.api.post("/products/stock/bulk", result.toBody());
      Map<String, dynamic>? paymentInfo;
      if (result.debtPaymentAmount > 0) {
        final raw = await widget.api.post("/debts/contact/${result.supplier.id}/payments", {
          "type": "payable",
          "amount": result.debtPaymentAmount,
          "currency": result.debtPaymentCurrency,
          "note": "Payment on purchase invoice: ${result.invoiceNo}",
        });
        if (raw is Map) paymentInfo = Map<String, dynamic>.from(raw);
      }
      await _loadProducts();
      if (!mounted) return;
      await _showBulkSupplyInvoice(result, paymentInfo: paymentInfo);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showBulkSupplyInvoice(_BulkSupplyResult result, {Map<String, dynamic>? paymentInfo}) async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final totals = result.totalsByCurrency();
    final before = result.debtTotalsBefore;
    final after = _mapTotals(paymentInfo?["after"]) ?? result.estimatedDebtAfter();
    final lines = <String>[
      isAr ? "فاتورة توريد" : "Stock purchase invoice",
      "${isAr ? "المورد" : "Supplier"}: ${result.supplier.name}",
      if (result.invoiceNo.isNotEmpty) "${isAr ? "رقم الفاتورة" : "Invoice"}: ${result.invoiceNo}",
      "${isAr ? "الحالة" : "Status"}: ${result.isDebt ? (isAr ? "دين" : "Debt") : (isAr ? "مدفوع" : "Paid")}",
      "${isAr ? "طريقة الدفع" : "Payment method"}: ${result.isDebt ? (isAr ? "دين" : "Debt") : (isAr ? "مدفوع" : "Paid")}",
      if (result.debtPaymentAmount > 0) "${isAr ? "دفع من الدين" : "Debt payment"}: ${money(result.debtPaymentAmount, result.debtPaymentCurrency)}",
      "",
      for (final item in result.items)
        "- ${item.label}: ${number(item.quantity)} ${item.unit} x ${money(item.unitCost, item.currency)} = ${money(item.total, item.currency)}",
      "",
      "${isAr ? "الإجمالي باللبناني" : "Total LBP"}: ${money(totals["LBP"] ?? 0, "LBP")}",
      "${isAr ? "الإجمالي بالدولار" : "Total USD"}: ${money(totals["USD"] ?? 0, "USD")}",
      "${isAr ? "رصيد سابق" : "Previous balance"}: ${money(before["LBP"] ?? 0, "LBP")} / ${money(before["USD"] ?? 0, "USD")}",
      "${isAr ? "رصيد نهائي" : "Final balance"}: ${money(after["LBP"] ?? 0, "LBP")} / ${money(after["USD"] ?? 0, "USD")}",
    ];
    final message = lines.join("\n");
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "تم توريد البضاعة" : "Stock received"),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t("cancel"))),
          OutlinedButton.icon(
            onPressed: () async => Clipboard.setData(ClipboardData(text: message)),
            icon: const Icon(Icons.copy_rounded),
            label: Text(isAr ? "نسخ" : "Copy"),
          ),
          FilledButton.icon(
            onPressed: result.supplier.phone.trim().isEmpty ? null : () => _shareSupplyWhatsapp(result.supplier, message),
            icon: const Icon(Icons.send_rounded),
            label: Text(isAr ? "واتساب" : "WhatsApp"),
          ),
        ],
      ),
    );
  }

  Map<String, double>? _mapTotals(dynamic raw) {
    if (raw is! Map) return null;
    return {
      "LBP": _numValue(raw["LBP"]),
      "USD": _numValue(raw["USD"]),
    };
  }

  Future<void> _shareSupplyWhatsapp(ContactModel supplier, String message) async {
    final digits = supplier.fullPhone.replaceAll(RegExp(r"[^0-9]"), "");
    final uri = Uri.parse("https://wa.me/$digits?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: message));
      _showError("Could not open WhatsApp. Invoice copied.");
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _showInventorySnapshot() async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final now = DateTime.now();
    final invoiceNo = "INV-STOCK-${now.millisecondsSinceEpoch.toString().substring(5)}";
    var totalQuantity = 0.0;
    final totals = {"LBP": 0.0, "USD": 0.0};
    final lines = <String>[
      isAr ? "فاتورة جردة عامة للمخزون" : "Full Inventory Invoice",
      "${isAr ? "رقم الفاتورة" : "Invoice No."}: $invoiceNo",
      "${isAr ? "التاريخ" : "Date"}: ${now.toString().substring(0, 16)}",
      "${isAr ? "النظام" : "System"}: daftr",
      "",
      "----------------------------------------",
    ];

    final grouped = _groupProducts(_products);
    for (final category in grouped.entries) {
      lines.add("${isAr ? "التصنيف" : "Category"}: ${category.key}");
      for (final subcategory in category.value.entries) {
        lines.add("  ${isAr ? "التصنيف الفرعي" : "Subcategory"}: ${subcategory.key}");
        for (final product in subcategory.value) {
          if (product.hasVariants) {
            for (final variant in product.variants) {
              final value = variant.quantity * variant.sellingPrice;
              totalQuantity += variant.quantity;
              totals[variant.currency] = (totals[variant.currency] ?? 0) + value;
              lines.add("    - ${product.name} / ${variant.name}");
              lines.add("      ${isAr ? "الكمية" : "Qty"}: ${number(variant.quantity)} ${variant.unit} | ${isAr ? "سعر البيع" : "Price"}: ${money(variant.sellingPrice, variant.currency)} | ${isAr ? "القيمة" : "Value"}: ${money(value, variant.currency)}");
            }
          } else {
            final value = product.quantity * product.sellingPrice;
            totalQuantity += product.quantity;
            totals[product.currency] = (totals[product.currency] ?? 0) + value;
            lines.add("    - ${product.name}");
            lines.add("      ${isAr ? "الكمية" : "Qty"}: ${number(product.quantity)} ${product.unit} | ${isAr ? "سعر البيع" : "Price"}: ${money(product.sellingPrice, product.currency)} | ${isAr ? "القيمة" : "Value"}: ${money(value, product.currency)}");
          }
        }
      }
      lines.add("");
    }
    lines.add("----------------------------------------");
    lines.add("${isAr ? "إجمالي الكمية" : "Total quantity"}: ${number(totalQuantity)}");
    lines.add("${isAr ? "إجمالي القيمة باللبناني" : "Total value LBP"}: ${money(totals["LBP"] ?? 0, "LBP")}");
    lines.add("${isAr ? "إجمالي القيمة بالدولار" : "Total value USD"}: ${money(totals["USD"] ?? 0, "USD")}");

    final message = lines.join("\n");
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "فاتورة جردة عامة" : "Inventory Invoice"),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(message)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t("cancel"))),
          OutlinedButton.icon(
            onPressed: () async => Clipboard.setData(ClipboardData(text: message)),
            icon: const Icon(Icons.copy_rounded),
            label: Text(isAr ? "نسخ" : "Copy"),
          ),
          FilledButton.icon(
            onPressed: () => _shareInventorySnapshot(message),
            icon: const Icon(Icons.send_rounded),
            label: Text(isAr ? "مشاركة" : "Share"),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInventorySnapshot(String message) async {
    final uri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: message));
      _showError("Could not open sharing app. Inventory copied.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final theme = Theme.of(context);
    final filtered = _filteredProducts();
    final grouped = _groupProducts(filtered);
    final totalQualities = filtered.fold<int>(0, (sum, p) => sum + (p.hasVariants ? p.variants.length : 1));
    final totalQuantity = filtered.fold<double>(0, (sum, p) {
      if (p.hasVariants) return sum + p.variants.fold<double>(0, (inner, v) => inner + v.quantity);
      return sum + p.quantity;
    });
    final lowStockCount = filtered.where((p) => p.isLowStock || p.variants.any((v) => v.isLowStock)).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add_box_rounded),
        label: Text(isAr ? "إضافة صنف" : "Add Item"),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.warehouse_rounded, color: theme.colorScheme.primary, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isAr ? "المخزون" : "Inventory", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                              Text(
                                isAr ? "تصنيف > تصنيف فرعي > نوعية صنف" : "Category > Subcategory > Item quality",
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _products.isEmpty ? null : _openBulkSupply,
                          tooltip: isAr ? "توريد جماعي" : "Bulk receiving",
                          icon: const Icon(Icons.add_business_rounded),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _products.isEmpty ? null : _showInventorySnapshot,
                          tooltip: isAr ? "جردة عامة" : "Inventory Snapshot",
                          icon: const Icon(Icons.ios_share_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _metricCard(isAr ? "النوعيات" : "Qualities", totalQualities.toString(), Icons.category_rounded, theme.colorScheme.primary)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricCard(isAr ? "الكمية" : "Quantity", number(totalQuantity), Icons.inventory_2_rounded, Colors.teal)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricCard(isAr ? "منخفض" : "Low", lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: isAr ? "بحث بالتصنيف، النوعية، أو الكود..." : "Search category, quality, or SKU...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ModernCard(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: _emptyState(isAr, theme),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      return _categoryBlock(entry.key, entry.value);
                    },
                    childCount: grouped.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<Product> _filteredProducts() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.subcategory.toLowerCase().contains(q) ||
          p.variants.any((v) => v.name.toLowerCase().contains(q));
    }).toList();
  }

  Map<String, Map<String, List<Product>>> _groupProducts(List<Product> products) {
    final grouped = <String, Map<String, List<Product>>>{};
    for (final product in products) {
      final category = product.category.trim().isEmpty ? "General" : product.category.trim();
      final subcategory = product.subcategory.trim().isEmpty ? "General" : product.subcategory.trim();
      grouped.putIfAbsent(category, () => <String, List<Product>>{});
      grouped[category]!.putIfAbsent(subcategory, () => <Product>[]);
      grouped[category]![subcategory]!.add(product);
    }
    return grouped;
  }

  Widget _categoryBlock(String category, Map<String, List<Product>> subcategories) {
    final theme = Theme.of(context);
    final count = subcategories.values.fold<int>(0, (sum, rows) => sum + rows.length);
    final isClosed = _closedCategories.contains(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ModernCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() {
                if (isClosed) {
                  _closedCategories.remove(category);
                } else {
                  _closedCategories.add(category);
                }
              }),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(isClosed ? Icons.folder_rounded : Icons.folder_open_rounded, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(category, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  _countPill("$count"),
                  const SizedBox(width: 6),
                  Icon(isClosed ? Icons.expand_more_rounded : Icons.expand_less_rounded),
                ],
              ),
            ),
            if (!isClosed) ...[
              const SizedBox(height: 12),
              ...subcategories.entries.map((entry) => _subcategoryBlock(category, entry.key, entry.value)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subcategoryBlock(String category, String subcategory, List<Product> products) {
    final theme = Theme.of(context);
    final c = AppScope.of(context);
    final key = "$category/$subcategory";
    final isClosed = _closedSubcategories.contains(key);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              if (isClosed) {
                _closedSubcategories.remove(key);
              } else {
                _closedSubcategories.add(key);
              }
            }),
            child: Row(
              children: [
                Icon(isClosed ? Icons.chevron_right_rounded : Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(subcategory, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                Text("${products.length}", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (!isClosed) ...[
            const SizedBox(height: 8),
            ...products.map((p) => _qualityRow(p, c)),
          ],
        ],
      ),
    );
  }

  Widget _qualityRow(Product p, AppController c) {
    final theme = Theme.of(context);
    final qty = p.hasVariants ? p.variants.fold<double>(0, (sum, v) => sum + v.quantity) : p.quantity;
    final low = p.isLowStock || p.variants.any((v) => v.isLowStock);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openProduct(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: low ? Colors.orange.withOpacity(0.12) : theme.colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2_rounded, color: low ? Colors.orange : theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      p.hasVariants ? "${p.variants.length} ${c.t("variants")}" : "${c.t("sellingPrice")}: ${money(p.sellingPrice, p.currency)}",
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${number(qty)} ${p.unit}", style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (low) Text(c.t("lowStock"), style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _countPill(String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(value, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
    );
  }

  Widget _emptyState(bool isAr, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warehouse_outlined, size: 70, color: theme.colorScheme.primary.withOpacity(0.35)),
            const SizedBox(height: 14),
            Text(isAr ? "لا يوجد أصناف بعد" : "No items yet", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              isAr ? "ابدأ بإضافة بطاطا > بطاطا حلوة > فئة أولى" : "Start with Potato > Sweet potato > Grade one",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add_rounded), label: Text(isAr ? "إضافة أول صنف" : "Add First Item")),
          ],
        ),
      ),
    );
  }
}

class _BulkSupplyDialog extends StatefulWidget {
  final List<Product> products;
  final List<ContactModel> suppliers;
  final List<Map<String, dynamic>> debts;

  const _BulkSupplyDialog({required this.products, required this.suppliers, required this.debts});

  @override
  State<_BulkSupplyDialog> createState() => _BulkSupplyDialogState();
}

class _BulkSupplyDialogState extends State<_BulkSupplyDialog> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _quantity = TextEditingController();
  final _unitCost = TextEditingController();
  final _invoiceNo = TextEditingController();
  final _reason = TextEditingController();
  final _debtPayment = TextEditingController();
  final List<_SupplyDraftItem> _items = [];

  String? _supplierId;
  String _category = "";
  String _subcategory = "";
  String _currency = "LBP";
  String _debtPaymentCurrency = "LBP";
  bool _registerDebt = false;
  _SupplyChoice? _activeChoice;

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _quantity.dispose();
    _unitCost.dispose();
    _invoiceNo.dispose();
    _reason.dispose();
    _debtPayment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final categories = _categoryOptions();
    final subcategories = _subcategoryOptions();
    final choices = _filteredChoices();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      title: Text(isAr ? "توريد جماعي" : "Bulk receiving"),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _supplierId,
                decoration: InputDecoration(labelText: isAr ? "المورد" : "Supplier", prefixIcon: const Icon(Icons.local_shipping_rounded)),
                items: widget.suppliers.map((supplier) => DropdownMenuItem(value: supplier.id, child: Text(supplier.name))).toList(),
                onChanged: (value) => setState(() => _supplierId = value),
              ),
              const SizedBox(height: 12),
              _responsiveFields([
                TextField(controller: _invoiceNo, decoration: InputDecoration(labelText: isAr ? "رقم الفاتورة" : "Invoice no.")),
                TextField(controller: _reason, decoration: InputDecoration(labelText: isAr ? "ملاحظة" : "Note")),
              ]),
              CheckboxListTile(
                value: _registerDebt,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(isAr ? "تسجيل كدين على المورد" : "Register as supplier debt"),
                onChanged: (value) => setState(() => _registerDebt = value ?? false),
              ),
              _supplierDebtPanel(isAr),
              const Divider(height: 24),
              _responsiveFields([
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(labelText: isAr ? "الصنف" : "Category"),
                  items: [
                    DropdownMenuItem(value: "", child: Text(isAr ? "اختر الصنف" : "Choose category")),
                    ...categories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                  ],
                  onChanged: (value) => setState(() {
                    _category = value ?? "";
                    _subcategory = "";
                    _clearChoice();
                  }),
                ),
                DropdownButtonFormField<String>(
                  value: _subcategory,
                  decoration: InputDecoration(labelText: isAr ? "الصنف الفرعي" : "Subcategory"),
                  items: [
                    DropdownMenuItem(value: "", child: Text(isAr ? "اختر الصنف الفرعي" : "Choose subcategory")),
                    ...subcategories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                  ],
                  onChanged: (value) => setState(() {
                    _subcategory = value ?? "";
                    _clearChoice();
                  }),
                ),
              ]),
              const SizedBox(height: 12),
              RawAutocomplete<_SupplyChoice>(
                textEditingController: _search,
                focusNode: _focus,
                displayStringForOption: (choice) => choice.label,
                optionsBuilder: (value) {
                  if (_category.isEmpty || _subcategory.isEmpty) return const Iterable<_SupplyChoice>.empty();
                  final q = value.text.trim().toLowerCase();
                  return choices.where((choice) => q.isEmpty || choice.searchText.contains(q)).take(10);
                },
                onSelected: _selectChoice,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: isAr ? "ابحث عن المنتج أو النوعية" : "Search item or quality",
                      prefixIcon: const Icon(Icons.manage_search_rounded),
                    ),
                    onChanged: (value) {
                      final selected = _activeChoice;
                      if (selected != null && selected.label != value) setState(() => _activeChoice = null);
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300, maxWidth: 620),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final choice = options.elementAt(index);
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.inventory_2_rounded)),
                              title: Text(choice.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text("${choice.category} > ${choice.subcategory}"),
                              trailing: Text("${number(choice.currentQuantity)} ${choice.unit}", style: const TextStyle(fontWeight: FontWeight.w900)),
                              onTap: () => onSelected(choice),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _responsiveFields([
                TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isAr ? "الكمية" : "Quantity"),
                ),
                TextField(
                  controller: _unitCost,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isAr ? "سعر الشراء" : "Unit cost"),
                ),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: InputDecoration(labelText: isAr ? "العملة" : "Currency"),
                  items: const [
                    DropdownMenuItem(value: "LBP", child: Text("LBP")),
                    DropdownMenuItem(value: "USD", child: Text("USD")),
                  ],
                  onChanged: (value) => setState(() => _currency = value ?? "LBP"),
                ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(isAr ? "إضافة للسلة" : "Add item"),
                ),
              ),
              const SizedBox(height: 12),
              _draftCard(isAr),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel"))),
        FilledButton(onPressed: _save, child: Text(c.t("save"))),
      ],
    );
  }

  void _selectChoice(_SupplyChoice choice) {
    setState(() {
      _activeChoice = choice;
      _search.text = choice.label;
      _unitCost.text = choice.purchasePrice.toStringAsFixed(2);
      _currency = choice.purchaseCurrency;
    });
  }

  void _addItem() {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final choice = _activeChoice;
    if (choice == null) return _showError(isAr ? "اختار المنتج أولاً" : "Choose an item first");
    final quantity = _numInput(_quantity.text);
    final unitCost = _numInput(_unitCost.text);
    if (quantity <= 0) return _showError(isAr ? "اكتب كمية صحيحة" : "Enter a valid quantity");
    if (unitCost < 0) return _showError(isAr ? "سعر الشراء غير صحيح" : "Invalid unit cost");

    final index = _items.indexWhere((item) => item.id == choice.id);
    setState(() {
      if (index == -1) {
        _items.add(_SupplyDraftItem.fromChoice(choice, quantity: quantity, unitCost: unitCost, currency: _currency));
      } else {
        _items[index] = _items[index].copyWith(quantity: _items[index].quantity + quantity, unitCost: unitCost, currency: _currency);
      }
      _clearChoice();
    });
  }

  void _save() {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final supplier = _supplierById(_supplierId);
    if (supplier == null) return _showError(isAr ? "اختار المورد أولاً" : "Select a supplier first");
    if (_items.isEmpty) return _showError(isAr ? "أضف صنف واحد على الأقل" : "Add at least one item");

    Navigator.pop(
      context,
      _BulkSupplyResult(
        supplier: supplier,
        items: List.of(_items),
        invoiceNo: _invoiceNo.text.trim(),
        reason: _reason.text.trim(),
        isDebt: _registerDebt,
        debtTotalsBefore: _supplierDebtTotals(_supplierId),
        debtPaymentAmount: _numInput(_debtPayment.text),
        debtPaymentCurrency: _debtPaymentCurrency,
      ),
    );
  }

  Widget _supplierDebtPanel(bool isAr) {
    final supplier = _supplierById(_supplierId);
    final totals = _supplierDebtTotals(_supplierId);
    final hasDebt = (totals["LBP"] ?? 0) > 0 || (totals["USD"] ?? 0) > 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier == null ? (isAr ? "اختار مورد لعرض دينه" : "Select supplier to show debt") : "${isAr ? "دين" : "Debt"} ${supplier.name}",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            "${isAr ? "المتبقي" : "Remaining"}: ${money(totals["LBP"] ?? 0, "LBP")} / ${money(totals["USD"] ?? 0, "USD")}",
            style: TextStyle(fontWeight: FontWeight.w800, color: hasDebt ? Colors.red.shade700 : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _responsiveFields([
            TextField(
              controller: _debtPayment,
              enabled: supplier != null,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: isAr ? "دفعة من دين المورد" : "Supplier debt payment"),
            ),
            DropdownButtonFormField<String>(
              value: _debtPaymentCurrency,
              decoration: InputDecoration(labelText: isAr ? "عملة الدفعة" : "Payment currency"),
              items: const [
                DropdownMenuItem(value: "LBP", child: Text("LBP")),
                DropdownMenuItem(value: "USD", child: Text("USD")),
              ],
              onChanged: supplier == null ? null : (value) => setState(() => _debtPaymentCurrency = value ?? "LBP"),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _draftCard(bool isAr) {
    if (_items.isEmpty) {
      return Text(isAr ? "السلة فارغة." : "No items added yet.", style: const TextStyle(fontWeight: FontWeight.w700));
    }
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final item in _items) {
      totals[item.currency] = (totals[item.currency] ?? 0) + item.total;
    }
    return ModernCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_items[i].label, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text("${number(_items[i].quantity)} ${_items[i].unit} x ${money(_items[i].unitCost, _items[i].currency)}"),
              trailing: IconButton(onPressed: () => setState(() => _items.removeAt(i)), icon: const Icon(Icons.close_rounded)),
            ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text(isAr ? "الإجمالي" : "Total", style: const TextStyle(fontWeight: FontWeight.w900))),
              Text("${money(totals["LBP"] ?? 0, "LBP")} / ${money(totals["USD"] ?? 0, "USD")}", style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  void _clearChoice() {
    _activeChoice = null;
    _search.clear();
    _quantity.clear();
    _unitCost.clear();
  }

  ContactModel? _supplierById(String? id) {
    for (final supplier in widget.suppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  Map<String, double> _supplierDebtTotals(String? supplierId) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    if (supplierId == null || supplierId.isEmpty) return totals;
    for (final debt in widget.debts) {
      if ((debt["type"] ?? "").toString() != "payable") continue;
      if ((debt["status"] ?? "").toString() == "paid") continue;
      if (_debtContactId(debt) != supplierId) continue;
      final currency = (debt["currency"] ?? "LBP").toString() == "USD" ? "USD" : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _numValue(debt["remainingAmount"]);
    }
    return totals;
  }

  String _debtContactId(Map<String, dynamic> debt) {
    final raw = debt["contact"];
    if (raw is Map) return (raw["_id"] ?? raw["id"] ?? "").toString();
    return (raw ?? "").toString();
  }

  List<_SupplyChoice> _choices() {
    final rows = <_SupplyChoice>[];
    for (final product in widget.products) {
      if (product.hasVariants) {
        for (final variant in product.variants) {
          rows.add(_SupplyChoice(
            id: "${product.id}:${variant.id}",
            productId: product.id,
            variantId: variant.id,
            category: product.category,
            subcategory: product.subcategory,
            label: "${product.name} - ${variant.name}",
            currentQuantity: variant.quantity,
            purchasePrice: variant.purchasePrice,
            purchaseCurrency: variant.purchaseCurrency,
            unit: variant.unit,
          ));
        }
      } else {
        rows.add(_SupplyChoice(
          id: product.id,
          productId: product.id,
          variantId: null,
          category: product.category,
          subcategory: product.subcategory,
          label: product.name,
          currentQuantity: product.quantity,
          purchasePrice: product.purchasePrice,
          purchaseCurrency: product.purchaseCurrency,
          unit: product.unit,
        ));
      }
    }
    rows.sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  List<_SupplyChoice> _filteredChoices() {
    return _choices().where((choice) => choice.category == _category && choice.subcategory == _subcategory).toList();
  }

  List<String> _categoryOptions() {
    final rows = _choices().map((choice) => choice.category).where((x) => x.trim().isNotEmpty).toSet().toList();
    rows.sort();
    return rows;
  }

  List<String> _subcategoryOptions() {
    final rows = _choices().where((choice) => _category.isNotEmpty && choice.category == _category).map((choice) => choice.subcategory).where((x) => x.trim().isNotEmpty).toSet().toList();
    rows.sort();
    return rows;
  }

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SupplyChoice {
  final String id;
  final String productId;
  final String? variantId;
  final String category;
  final String subcategory;
  final String label;
  final double currentQuantity;
  final double purchasePrice;
  final String purchaseCurrency;
  final String unit;

  const _SupplyChoice({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.category,
    required this.subcategory,
    required this.label,
    required this.currentQuantity,
    required this.purchasePrice,
    required this.purchaseCurrency,
    required this.unit,
  });

  String get searchText => "$label $category $subcategory".toLowerCase();
}

class _SupplyDraftItem {
  final String id;
  final String productId;
  final String? variantId;
  final String label;
  final double quantity;
  final double unitCost;
  final String currency;
  final String unit;

  const _SupplyDraftItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.label,
    required this.quantity,
    required this.unitCost,
    required this.currency,
    required this.unit,
  });

  factory _SupplyDraftItem.fromChoice(_SupplyChoice choice, {required double quantity, required double unitCost, required String currency}) {
    return _SupplyDraftItem(
      id: choice.id,
      productId: choice.productId,
      variantId: choice.variantId,
      label: choice.label,
      quantity: quantity,
      unitCost: unitCost,
      currency: currency,
      unit: choice.unit,
    );
  }

  double get total => quantity * unitCost;

  _SupplyDraftItem copyWith({double? quantity, double? unitCost, String? currency}) {
    return _SupplyDraftItem(
      id: id,
      productId: productId,
      variantId: variantId,
      label: label,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
      unit: unit,
    );
  }

  Map<String, dynamic> toBody() {
    return {
      "productId": productId,
      if (variantId != null) "variantId": variantId,
      "quantity": quantity,
      "unitCost": unitCost,
      "currency": currency,
    };
  }
}

class _BulkSupplyResult {
  final ContactModel supplier;
  final List<_SupplyDraftItem> items;
  final String invoiceNo;
  final String reason;
  final bool isDebt;
  final Map<String, double> debtTotalsBefore;
  final double debtPaymentAmount;
  final String debtPaymentCurrency;

  const _BulkSupplyResult({
    required this.supplier,
    required this.items,
    required this.invoiceNo,
    required this.reason,
    required this.isDebt,
    required this.debtTotalsBefore,
    required this.debtPaymentAmount,
    required this.debtPaymentCurrency,
  });

  Map<String, dynamic> toBody() {
    return {
      "supplierId": supplier.id,
      "paymentStatus": isDebt ? "debt" : "paid",
      "invoiceNo": invoiceNo,
      "reason": reason,
      "items": items.map((item) => item.toBody()).toList(),
    };
  }

  Map<String, double> totalsByCurrency() {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final item in items) {
      totals[item.currency] = (totals[item.currency] ?? 0) + item.total;
    }
    return totals;
  }

  Map<String, double> estimatedDebtAfter() {
    final totals = Map<String, double>.from(debtTotalsBefore);
    if (isDebt) {
      final purchaseTotals = totalsByCurrency();
      totals["LBP"] = (totals["LBP"] ?? 0) + (purchaseTotals["LBP"] ?? 0);
      totals["USD"] = (totals["USD"] ?? 0) + (purchaseTotals["USD"] ?? 0);
    }
    totals[debtPaymentCurrency] = ((totals[debtPaymentCurrency] ?? 0) - debtPaymentAmount).clamp(0, double.infinity).toDouble();
    return totals;
  }
}

double _numInput(String value) => double.tryParse(value.replaceAll(",", "").trim()) ?? 0;

double _numValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
