import "package:flutter/material.dart";
import "../../core/app_controller.dart";
import "../../models/product.dart";

class ProductFormDialog extends StatefulWidget {
  final bool variantOnly;
  final List<Product> existingProducts;
  const ProductFormDialog({super.key, this.variantOnly = false, this.existingProducts = const []});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  static const _newValue = "__new__";

  final category = TextEditingController(text: "General");
  final subcategory = TextEditingController(text: "General");
  final name = TextEditingController();
  final sku = TextEditingController();
  final purchase = TextEditingController(text: "0");
  final selling = TextEditingController(text: "0");
  final minStock = TextEditingController(text: "0");
  final customUnit = TextEditingController();

  String? selectedCategory;
  String? selectedSubcategory;
  String currency = "LBP";
  String unit = "Piece";
  bool hasVariants = false;
  bool isOtherUnit = false;

  List<String> get categories {
    final rows = widget.existingProducts.map((p) => p.category.trim()).where((x) => x.isNotEmpty).toSet().toList();
    rows.sort();
    return rows;
  }

  List<String> get subcategories {
    final cat = selectedCategory == _newValue ? category.text.trim() : selectedCategory;
    final rows = widget.existingProducts
        .where((p) => cat == null || cat.isEmpty || p.category == cat)
        .map((p) => p.subcategory.trim())
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    rows.sort();
    return rows;
  }

  @override
  void initState() {
    super.initState();
    selectedCategory = categories.isEmpty ? _newValue : categories.first;
    category.text = selectedCategory == _newValue ? "\u0628\u0637\u0627\u0637\u0627" : selectedCategory!;
    final subs = subcategories;
    selectedSubcategory = subs.isEmpty ? _newValue : subs.first;
    subcategory.text = selectedSubcategory == _newValue ? "\u0628\u0637\u0627\u0637\u0627 \u062d\u0644\u0648\u0629" : selectedSubcategory!;
    if (widget.existingProducts.isEmpty && !widget.variantOnly) {
      name.text = "\u0641\u0626\u0629 \u0623\u0648\u0644\u0649";
    }
  }

  @override
  void dispose() {
    category.dispose();
    subcategory.dispose();
    name.dispose();
    sku.dispose();
    purchase.dispose();
    selling.dispose();
    minStock.dispose();
    customUnit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return AlertDialog(
      title: Text(widget.variantOnly ? c.t("addVariant") : c.t("addProduct")),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const CircleAvatar(radius: 42, child: Icon(Icons.inventory_2_rounded, size: 36)),
              const SizedBox(height: 16),
              if (!widget.variantOnly) ...[
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: isAr ? "\u0627\u0644\u062a\u0635\u0646\u064a\u0641" : "Category", prefixIcon: const Icon(Icons.folder_rounded)),
                  items: [
                    ...categories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                    DropdownMenuItem(value: _newValue, child: Text(isAr ? "\u062a\u0635\u0646\u064a\u0641 \u062c\u062f\u064a\u062f" : "New category")),
                  ],
                  onChanged: (v) {
                    setState(() {
                      selectedCategory = v ?? _newValue;
                      if (selectedCategory == _newValue) {
                        category.clear();
                        selectedSubcategory = _newValue;
                        subcategory.clear();
                      } else {
                        category.text = selectedCategory!;
                        final subs = subcategories;
                        selectedSubcategory = subs.isEmpty ? _newValue : subs.first;
                        subcategory.text = selectedSubcategory == _newValue ? "" : selectedSubcategory!;
                      }
                    });
                  },
                ),
                if (selectedCategory == _newValue) ...[
                  const SizedBox(height: 10),
                  TextField(controller: category, decoration: InputDecoration(labelText: isAr ? "\u0627\u0633\u0645 \u0627\u0644\u062a\u0635\u0646\u064a\u0641" : "Category name", prefixIcon: const Icon(Icons.edit_rounded))),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedSubcategory,
                  decoration: InputDecoration(labelText: isAr ? "\u0627\u0644\u062a\u0635\u0646\u064a\u0641 \u0627\u0644\u0641\u0631\u0639\u064a" : "Subcategory", prefixIcon: const Icon(Icons.folder_copy_rounded)),
                  items: [
                    ...subcategories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                    DropdownMenuItem(value: _newValue, child: Text(isAr ? "\u062a\u0635\u0646\u064a\u0641 \u0641\u0631\u0639\u064a \u062c\u062f\u064a\u062f" : "New subcategory")),
                  ],
                  onChanged: (v) {
                    setState(() {
                      selectedSubcategory = v ?? _newValue;
                      if (selectedSubcategory == _newValue) {
                        subcategory.clear();
                      } else {
                        subcategory.text = selectedSubcategory!;
                      }
                    });
                  },
                ),
                if (selectedSubcategory == _newValue) ...[
                  const SizedBox(height: 10),
                  TextField(controller: subcategory, decoration: InputDecoration(labelText: isAr ? "\u0627\u0633\u0645 \u0627\u0644\u062a\u0635\u0646\u064a\u0641 \u0627\u0644\u0641\u0631\u0639\u064a" : "Subcategory name", prefixIcon: const Icon(Icons.edit_note_rounded))),
                ],
                const SizedBox(height: 10),
              ],
              TextField(controller: name, decoration: InputDecoration(labelText: widget.variantOnly ? c.t("productName") : (isAr ? "\u0646\u0648\u0639\u064a\u0629 \u0627\u0644\u0635\u0646\u0641" : "Item Quality"), prefixIcon: const Icon(Icons.shopping_basket))),
              const SizedBox(height: 10),
              TextField(controller: sku, decoration: InputDecoration(labelText: c.t("sku"), prefixIcon: const Icon(Icons.qr_code))),
              if (!widget.variantOnly)
                SwitchListTile(
                  value: hasVariants,
                  title: Text(c.t("variants")),
                  onChanged: (v) => setState(() => hasVariants = v),
                ),
              if (!hasVariants || widget.variantOnly) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: purchase, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: c.t("purchasePrice")))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: selling, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: c.t("sellingPrice")))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: minStock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: c.t("minStock"))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: InputDecoration(labelText: c.t("currency")),
                  items: const [DropdownMenuItem(value: "USD", child: Text("USD")), DropdownMenuItem(value: "LBP", child: Text("LBP"))],
                  onChanged: (v) => setState(() => currency = v ?? "LBP"),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: InputDecoration(labelText: c.t("unit")),
                  items: [
                    DropdownMenuItem(value: "Piece", child: Text(c.t("piece"))),
                    DropdownMenuItem(value: "Bag", child: Text(c.t("bag"))),
                    DropdownMenuItem(value: "Kilogram", child: Text(c.t("kilogram"))),
                    DropdownMenuItem(value: "Box", child: Text(c.t("box"))),
                    DropdownMenuItem(value: "Other", child: Text(isAr ? "\u0623\u062e\u0631\u0649" : "Other")),
                  ],
                  onChanged: (v) => setState(() {
                    unit = v ?? "Piece";
                    isOtherUnit = unit == "Other";
                  }),
                ),
                if (isOtherUnit) ...[
                  const SizedBox(height: 10),
                  TextField(controller: customUnit, decoration: InputDecoration(labelText: isAr ? "\u0627\u0633\u0645 \u0627\u0644\u0648\u062d\u062f\u0629 \u0627\u0644\u062c\u062f\u064a\u062f\u0629" : "New Unit Name")),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel"))),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(context, {
              "category": category.text.trim().isEmpty ? "General" : category.text.trim(),
              "subcategory": subcategory.text.trim().isEmpty ? "General" : subcategory.text.trim(),
              "name": name.text.trim(),
              "sku": sku.text.trim(),
              "imageUrl": "",
              "hasVariants": widget.variantOnly ? false : hasVariants,
              "purchasePrice": double.tryParse(purchase.text.trim()) ?? 0,
              "purchaseCurrency": currency,
              "sellingPrice": double.tryParse(selling.text.trim()) ?? 0,
              "quantity": 0,
              "minStock": double.tryParse(minStock.text.trim()) ?? 0,
              "currency": currency,
              "unit": isOtherUnit ? customUnit.text.trim() : unit,
            });
          },
          child: Text(c.t("save")),
        ),
      ],
    );
  }
}
