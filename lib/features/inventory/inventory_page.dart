import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
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
      final data = await widget.api.get("/products");
      _products = (data as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();
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
      "${isAr ? "النظام" : "System"}: Accounting Pro",
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
