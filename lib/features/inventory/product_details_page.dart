import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/contact.dart";
import "../../models/product.dart";
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
      _product = Product.fromJson(Map<String, dynamic>.from(results[0] as Map));
      _suppliers = (results[1] as List)
          .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.type == "supplier")
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteProduct() async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
        content: Text(c.isArabic ? "\u0647\u0644 \u0623\u0646\u062a \u0645\u062a\u0623\u0643\u062f \u0645\u0646 \u062d\u0630\u0641 \u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u062a\u062c\u061f" : "Delete this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(c.t("cancel"))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(c.t("delete"))),
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

  Future<void> _editProduct() async {
    final product = _product;
    if (product == null) return;
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ProductFormDialog(product: product, existingProducts: [product]),
    );
    if (body == null) return;
    try {
      await widget.api.put("/products/${widget.productId}", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editVariant(ProductVariant variant) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ProductFormDialog(variantOnly: true, variant: variant),
    );
    if (body == null) return;
    try {
      await widget.api.put("/products/${widget.productId}/variants/${variant.id}", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addStock(dynamic item) async {
    final isVariant = item is ProductVariant;
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final qty = TextEditingController();
    final unitCost = TextEditingController(text: item.purchasePrice.toStringAsFixed(2));
    final invoiceNo = TextEditingController();
    final note = TextEditingController();
    String? supplierId;
    String purchaseCurrency = item.purchaseCurrency;
    bool registerDebt = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final addedQty = double.tryParse(qty.text.trim()) ?? 0;
          final totalAfter = item.quantity + addedQty;
          return AlertDialog(
            title: Text(isAr ? "\u062a\u0648\u0631\u064a\u062f \u0643\u0645\u064a\u0629" : "Add Stock"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: supplierId,
                    decoration: InputDecoration(labelText: isAr ? "\u0627\u0633\u0645 \u0627\u0644\u0645\u0648\u0631\u062f" : "Supplier name"),
                    items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (v) => setDialogState(() => supplierId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qty,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isAr ? "\u0627\u0644\u0643\u0645\u064a\u0629 \u0627\u0644\u0645\u0636\u0627\u0641\u0629" : "Quantity to add",
                      helperText: "${isAr ? "\u0627\u0644\u0631\u0635\u064a\u062f \u0628\u0639\u062f \u0627\u0644\u062a\u0648\u0631\u064a\u062f" : "Stock after"}: ${totalAfter.toStringAsFixed(0)}",
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: unitCost, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isAr ? "\u0633\u0639\u0631 \u0627\u0644\u0634\u0631\u0627\u0621" : "Unit cost"))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: purchaseCurrency,
                          decoration: InputDecoration(labelText: isAr ? "\u0627\u0644\u0639\u0645\u0644\u0629" : "Currency"),
                          items: const [
                            DropdownMenuItem(value: "LBP", child: Text("LBP")),
                            DropdownMenuItem(value: "USD", child: Text("USD")),
                          ],
                          onChanged: (v) => setDialogState(() => purchaseCurrency = v ?? "LBP"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: invoiceNo, decoration: InputDecoration(labelText: isAr ? "\u0631\u0642\u0645 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629" : "Invoice no.")),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: registerDebt,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAr ? "\u062a\u0633\u062c\u064a\u0644 \u0643\u062f\u064a\u0646 \u0639\u0644\u0649 \u0627\u0644\u0645\u0648\u0631\u062f" : "Register as supplier debt"),
                    onChanged: (v) => setDialogState(() => registerDebt = v ?? false),
                  ),
                  TextField(controller: note, decoration: InputDecoration(labelText: isAr ? "\u0645\u0644\u0627\u062d\u0638\u0629" : "Note")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t("cancel"))),
              FilledButton(
                onPressed: () {
                  final parsedQty = double.tryParse(qty.text.trim()) ?? 0;
                  if (supplierId == null) return _showError(isAr ? "\u0627\u062e\u062a\u0631 \u0627\u0644\u0645\u0648\u0631\u062f \u0623\u0648\u0644\u0627\u064b" : "Select a supplier first");
                  if (parsedQty <= 0) return _showError(isAr ? "\u0627\u0643\u062a\u0628 \u0643\u0645\u064a\u0629 \u0635\u062d\u064a\u062d\u0629" : "Enter a valid quantity");
                  Navigator.pop(ctx, {
                    "newQuantity": item.quantity + parsedQty,
                    "reason": note.text.trim(),
                    "supplierId": supplierId,
                    "unitCost": double.tryParse(unitCost.text.trim()) ?? 0,
                    "currency": purchaseCurrency,
                    "paymentStatus": registerDebt ? "debt" : "paid",
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

    final addedQuantity = double.tryParse(qty.text.trim()) ?? 0;
    final cost = double.tryParse(unitCost.text.trim()) ?? 0;
    qty.dispose();
    unitCost.dispose();
    invoiceNo.dispose();
    note.dispose();
    if (result == null) return;

    try {
      final path = isVariant ? "/products/${widget.productId}/variants/${item.id}/stock" : "/products/${widget.productId}/stock";
      await widget.api.post(path, result);
      final supplier = _supplierById((result["supplierId"] ?? "").toString());
      await _load();
      if (!mounted) return;
      await _showSupplyInvoice(
        itemName: item.name,
        quantity: addedQuantity,
        unitCost: cost,
        currency: (result["currency"] ?? "LBP").toString(),
        invoiceNo: (result["invoiceNo"] ?? "").toString(),
        isDebt: result["paymentStatus"] == "debt",
        supplier: supplier,
      );
    } catch (e) {
      _showError(e);
    }
  }

  ContactModel? _supplierById(String id) {
    for (final supplier in _suppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  Future<void> _showSupplyInvoice({
    required String itemName,
    required double quantity,
    required double unitCost,
    required String currency,
    required String invoiceNo,
    required bool isDebt,
    required ContactModel? supplier,
  }) async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final rate = c.exchangeRate <= 0 ? 90000 : c.exchangeRate;
    final total = quantity * unitCost;
    final totalUsd = currency == "USD" ? total : total / rate;
    final totalLbp = currency == "LBP" ? total : total * rate;
    final message = [
      isAr ? "\u0641\u0627\u062a\u0648\u0631\u0629 \u062a\u0648\u0631\u064a\u062f" : "Stock purchase invoice",
      "${isAr ? "\u0627\u0644\u0645\u0648\u0631\u062f" : "Supplier"}: ${supplier?.name ?? "-"}",
      "${isAr ? "\u0627\u0644\u0635\u0646\u0641" : "Item"}: $itemName",
      "${isAr ? "\u0627\u0644\u0643\u0645\u064a\u0629" : "Quantity"}: ${quantity.toStringAsFixed(0)}",
      "${isAr ? "\u0633\u0639\u0631 \u0627\u0644\u0634\u0631\u0627\u0621" : "Unit cost"}: ${money(unitCost, currency)}",
      "${isAr ? "\u0627\u0644\u0645\u062c\u0645\u0648\u0639 \u0628\u0627\u0644\u062f\u0648\u0644\u0627\u0631" : "Total USD"}: ${money(totalUsd, "USD")}",
      "${isAr ? "\u0627\u0644\u0645\u062c\u0645\u0648\u0639 \u0628\u0627\u0644\u0644\u0628\u0646\u0627\u0646\u064a" : "Total LBP"}: ${money(totalLbp, "LBP")}",
      "${isAr ? "\u0627\u0644\u062d\u0627\u0644\u0629" : "Status"}: ${isDebt ? (isAr ? "\u062f\u064a\u0646" : "Debt") : (isAr ? "\u0645\u062f\u0641\u0648\u0639" : "Paid")}",
      if (invoiceNo.isNotEmpty) "${isAr ? "\u0631\u0642\u0645 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629" : "Invoice"}: $invoiceNo",
    ].join("\n");

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "\u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u062a\u0648\u0631\u064a\u062f" : "Purchase Invoice"),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t("cancel"))),
          OutlinedButton.icon(
            onPressed: () async => Clipboard.setData(ClipboardData(text: message)),
            icon: const Icon(Icons.copy_rounded),
            label: Text(isAr ? "\u0646\u0633\u062e" : "Copy"),
          ),
          FilledButton.icon(
            onPressed: supplier == null || supplier.phone.trim().isEmpty ? null : () => _shareSupplierWhatsapp(supplier, message),
            icon: const Icon(Icons.send_rounded),
            label: Text(isAr ? "\u0648\u0627\u062a\u0633\u0627\u0628" : "WhatsApp"),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSupplierWhatsapp(ContactModel supplier, String message) async {
    final digits = supplier.fullPhone.replaceAll(RegExp(r"[^0-9]"), "");
    final uri = Uri.parse("https://wa.me/$digits?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: message));
      _showError("Could not open WhatsApp. Invoice copied.");
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
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
          IconButton(onPressed: _editProduct, icon: const Icon(Icons.edit_rounded)),
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
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
                                    child: Icon(Icons.inventory_2_rounded, size: 58, color: theme.colorScheme.primary),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _detailRow(c.isArabic ? "\u0646\u0648\u0639\u064a\u0629 \u0627\u0644\u0635\u0646\u0641" : "Item Quality", _product!.name, theme, isBold: true),
                                _detailRow(c.isArabic ? "\u0627\u0644\u062a\u0635\u0646\u064a\u0641" : "Category", _product!.category, theme),
                                _detailRow(c.isArabic ? "\u0627\u0644\u062a\u0635\u0646\u064a\u0641 \u0627\u0644\u0641\u0631\u0639\u064a" : "Subcategory", _product!.subcategory, theme),
                                _detailRow(c.t("sku"), _product!.sku.isEmpty ? "-" : _product!.sku, theme),
                                if (!_product!.hasVariants) ...[
                                  _detailRow(c.t("purchasePrice"), money(_product!.purchasePrice, _product!.purchaseCurrency), theme),
                                  _detailRow(c.t("sellingPrice"), money(_product!.sellingPrice, _product!.currency), theme, valueColor: theme.colorScheme.primary),
                                  _detailRow(c.t("quantity"), "${_product!.quantity.toStringAsFixed(0)} ${_product!.unit}", theme),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _addStock(_product!),
                                      icon: const Icon(Icons.local_shipping_rounded),
                                      label: Text(c.isArabic ? "\u062a\u0648\u0631\u064a\u062f \u0643\u0645\u064a\u0629" : "Add Stock"),
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
                                      onTap: () => _addStock(v),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(radius: 24, backgroundColor: theme.colorScheme.surfaceVariant, child: const Icon(Icons.category_rounded, size: 20)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text("${c.t("sellingPrice")}: ${money(v.sellingPrice, v.currency)}", style: theme.textTheme.bodySmall),
                                                Text("${c.t("purchasePrice")}: ${money(v.purchasePrice, v.purchaseCurrency)}", style: theme.textTheme.bodySmall),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: c.isArabic ? "\u062a\u0639\u062f\u064a\u0644" : "Edit",
                                            onPressed: () => _editVariant(v),
                                            icon: const Icon(Icons.edit_rounded),
                                          ),
                                          Text("${v.quantity.toStringAsFixed(0)} ${v.unit}", style: const TextStyle(fontWeight: FontWeight.w900)),
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
