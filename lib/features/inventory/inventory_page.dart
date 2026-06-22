import "package:flutter/material.dart";
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

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final theme = Theme.of(context);

    final filtered = _filteredProducts();
    final grouped = _groupProducts(filtered);
    final lowStockCount = filtered.where((p) => p.isLowStock || p.variants.any((v) => v.isLowStock)).length;
    final totalItems = filtered.fold<int>(0, (sum, p) => sum + (p.hasVariants ? p.variants.length : 1));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add_box_rounded),
        label: Text(isAr ? "\u0625\u0636\u0627\u0641\u0629 \u0635\u0646\u0641" : "Add Item"),
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
                    Text(
                      isAr ? "\u0627\u0644\u0645\u062e\u0632\u0648\u0646" : "Inventory",
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr ? "\u062a\u0635\u0646\u064a\u0641\u0627\u062a\u060c \u062a\u0635\u0646\u064a\u0641\u0627\u062a \u0641\u0631\u0639\u064a\u0629\u060c \u0648\u0623\u0635\u0646\u0627\u0641 \u0645\u0639 \u062a\u0648\u0631\u064a\u062f \u0645\u0646 \u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646" : "Categories, subcategories, items, and supplier stock intake",
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _metricCard(isAr ? "\u0627\u0644\u0623\u0635\u0646\u0627\u0641" : "Items", totalItems.toString(), Icons.inventory_2_rounded, theme.colorScheme.primary)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricCard(isAr ? "\u0645\u0646\u062e\u0641\u0636" : "Low", lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: isAr ? "\u0628\u062d\u062b \u0628\u0627\u0644\u0635\u0646\u0641\u060c \u0627\u0644\u062a\u0635\u0646\u064a\u0641\u060c \u0623\u0648 \u0627\u0644\u0643\u0648\u062f..." : "Search item, category, or SKU...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(c.t("empty"), style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    grouped.entries.map((categoryEntry) => _categorySection(categoryEntry.key, categoryEntry.value)).toList(),
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
          p.subcategory.toLowerCase().contains(q);
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

  Widget _categorySection(String category, Map<String, List<Product>> subcategories) {
    final theme = Theme.of(context);
    final count = subcategories.values.fold<int>(0, (sum, rows) => sum + rows.length);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ModernCard(
        padding: const EdgeInsets.all(14),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.folder_rounded, color: theme.colorScheme.onPrimaryContainer),
            ),
            title: Text(category, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text("$count"),
            children: subcategories.entries.map((entry) => _subcategorySection(entry.key, entry.value)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _subcategorySection(String subcategory, List<Product> products) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subdirectory_arrow_right_rounded, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(subcategory, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Text("(${products.length})", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ...products.map(_productRow),
        ],
      ),
    );
  }

  Widget _productRow(Product p) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final qty = p.hasVariants ? "${p.variants.length} ${c.t("variants")}" : "${p.quantity.toStringAsFixed(0)} ${p.unit}";
    final low = p.isLowStock || p.variants.any((v) => v.isLowStock);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openProduct(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Icon(p.hasVariants ? Icons.category_rounded : Icons.inventory_2_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text("${c.t("sku")}: ${p.sku.isEmpty ? "-" : p.sku}", style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(qty, style: const TextStyle(fontWeight: FontWeight.w900)),
                if (!p.hasVariants) Text(money(p.sellingPrice, p.currency), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                if (low) Text(c.t("lowStock"), style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
