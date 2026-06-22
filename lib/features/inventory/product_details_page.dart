import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/product.dart";
import "../../models/contact.dart";
import "../../widgets/modern_card.dart";
import "product_form_dialog.dart";

class ProductDetailsPage extends StatefulWidget {
  final ApiClient api;
  final String productId;

  const ProductDetailsPage({
    super.key,
    required this.api,
    required this.productId,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  bool _loading = true;
  String? _error;
  Product? _product;
  List<ContactModel> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.get("/products/${widget.productId}"),
        widget.api.get("/contacts"),
      ]);

      final data = results[0];
      _product = Product.fromJson(Map<String, dynamic>.from(data as Map));

      final cData = results[1];
      _suppliers = (cData as List)
          .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.type == "supplier")
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteProduct() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
        content: Text(AppScope.of(context).isArabic ? "هل أنت متأكد من حذف هذا المنتج؟" : "Delete this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppScope.of(context).t("cancel"))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppScope.of(context).t("delete"))),
        ],
      ),
    );
    if (ok != true) return;

    await widget.api.delete("/products/${widget.productId}");
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addVariant() async {
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const ProductFormDialog(variantOnly: true));
    if (body == null) return;
    try {
      await widget.api.post("/products/${widget.productId}/variants", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _adjustStock(dynamic p) async {
    final isVariant = p is ProductVariant;
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    final qty = TextEditingController();
    final note = TextEditingController();
    final invoiceNo = TextEditingController();
    final unitCost = TextEditingController(text: p.purchasePrice.toStringAsFixed(2));
    String? supplierId;
    String paymentStatus = "paid";

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final addedQty = double.tryParse(qty.text.trim()) ?? 0;
          final totalAfter = p.quantity + addedQty;

          return AlertDialog(
          title: Text(isAr ? "توريد كمية" : "Add Stock"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr ? "الكمية المضافة" : "Quantity to add",
                    helperText: "${isAr ? "الرصيد بعد التوريد" : "Stock after"}: ${totalAfter.toStringAsFixed(0)}",
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: supplierId,
                  decoration: InputDecoration(labelText: isAr ? "المورد" : "Supplier"),
                  items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setDialogState(() => supplierId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: unitCost, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isAr ? "سعر الشراء" : "Unit Cost"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: invoiceNo, decoration: InputDecoration(labelText: isAr ? "رقم الفاتورة" : "Invoice No."))),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentStatus,
                  decoration: InputDecoration(labelText: isAr ? "حالة الدفع" : "Payment Status"),
                  items: [
                    DropdownMenuItem(value: "paid", child: Text(isAr ? "مدفوع" : "Paid")),
                    DropdownMenuItem(value: "debt", child: Text(isAr ? "دين على المورد" : "Supplier Debt")),
                  ],
                  onChanged: (v) => setDialogState(() => paymentStatus = v ?? "paid"),
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: InputDecoration(labelText: isAr ? "ملاحظة" : "Note")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t("cancel"))),
            FilledButton(
              onPressed: () {
                final parsedQty = double.tryParse(qty.text.trim()) ?? 0;
                if (parsedQty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isAr ? "اكتب كمية صحيحة" : "Enter a valid quantity")),
                  );
                  return;
                }
                if (supplierId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isAr ? "اختر المورد أولاً" : "Select a supplier first")),
                  );
                  return;
                }

                Navigator.pop(ctx, {
                  "newQuantity": p.quantity + parsedQty,
                  "reason": note.text.trim(),
                  "supplierId": supplierId,
                  "unitCost": double.tryParse(unitCost.text.trim()) ?? 0,
                  "paymentStatus": paymentStatus,
                  "invoiceNo": invoiceNo.text.trim(),
                });
              },
              child: Text(c.t("save")),
            ),
          ],
        );
        },
      ),
    );

    qty.dispose();
    note.dispose();
    invoiceNo.dispose();
    unitCost.dispose();

    if (result == null) return;

    try {
      final path = isVariant
          ? "/products/${widget.productId}/variants/${p.id}/stock"
          : "/products/${widget.productId}/stock";
      await widget.api.post(path, result);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.t("productDetails")),
        actions: [
          IconButton(onPressed: _deleteProduct, icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent)),
        ],
      ),
      floatingActionButton: _product?.hasVariants == true
          ? FloatingActionButton.extended(onPressed: _addVariant, icon: const Icon(Icons.add_rounded), label: Text(c.t("addVariant")))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _product == null
                  ? Center(child: Text(c.t("empty")))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          ModernCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Hero(
                                    tag: "prod_${_product!.id}",
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(Icons.inventory_2_rounded, size: 60, color: theme.colorScheme.primary.withOpacity(0.5)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _detailRow(c.t("productName"), _product!.name, theme, isBold: true),
                                _detailRow(c.isArabic ? "التصنيف" : "Category", _product!.category, theme),
                                _detailRow(c.isArabic ? "التصنيف الفرعي" : "Subcategory", _product!.subcategory, theme),
                                _detailRow(c.t("sku"), _product!.sku.isEmpty ? "-" : _product!.sku, theme),
                                if (!_product!.hasVariants) ...[
                                  _detailRow(c.t("purchasePrice"), money(_product!.purchasePrice, _product!.currency), theme),
                                  _detailRow(c.t("sellingPrice"), money(_product!.sellingPrice, _product!.currency), theme, valueColor: theme.colorScheme.primary),
                                  _detailRow(c.t("quantity"), "${_product!.quantity.toStringAsFixed(0)} ${_product!.unit}", theme),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _adjustStock(_product!),
                                      icon: const Icon(Icons.inventory_rounded),
                                      label: Text(c.isArabic ? "توريد كمية" : "Add Stock"),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_product!.hasVariants) ...[
                            const SizedBox(height: 24),
                            Text(c.t("variants"), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            if (_product!.variants.isEmpty)
                              ModernCard(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(c.t("empty")))))
                            else
                              ..._product!.variants.map((v) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ModernCard(
                                      onTap: () => _adjustStock(v),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: theme.colorScheme.surfaceVariant,
                                            child: const Icon(Icons.category_rounded, size: 20),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text("${c.t("sellingPrice")}: ${money(v.sellingPrice, v.currency)}", style: theme.textTheme.bodySmall),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text("${v.quantity.toStringAsFixed(0)} ${v.unit}", style: const TextStyle(fontWeight: FontWeight.w900)),
                                              if (v.isLowStock)
                                                Text(c.t("lowStock"), style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20),
                                        ],
                                      ),
                                    ),
                                  )),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
