import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/product.dart";
import "../../widgets/modern_card.dart";

class DamagedGoodsPage extends StatefulWidget {
  final ApiClient api;
  const DamagedGoodsPage({super.key, required this.api});

  @override
  State<DamagedGoodsPage> createState() => _DamagedGoodsPageState();
}

class _DamagedGoodsPageState extends State<DamagedGoodsPage> {
  bool _loading = true;
  bool _resetting = false;
  String? _error;
  List<Product> _products = [];
  List<_DamageMovement> _movements = [];
  final List<_DamageDraftItem> _damageItems = [];

  final _productSearch = TextEditingController();
  final _productFocus = FocusNode();
  final _quantity = TextEditingController();
  final _weight = TextEditingController();
  final _unitCost = TextEditingController();
  final _reason = TextEditingController();

  String _categoryFilter = "";
  String _currency = "LBP";
  _DamageChoice? _activeChoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _productSearch.dispose();
    _productFocus.dispose();
    _quantity.dispose();
    _weight.dispose();
    _unitCost.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.get("/products"),
        widget.api.get("/products/damaged"),
      ]);

      _products = (results[0] as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _movements = (results[1] as List)
          .map(
            (e) =>
                _DamageMovement.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _recordDamage() async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    if (_damageItems.isEmpty &&
        _activeChoice != null &&
        _quantity.text.trim().isNotEmpty) {
      if (!_addDamageItem()) return;
    }
    if (_damageItems.isEmpty) {
      return _showError(
        isAr ? "أضف صنف واحد على الأقل" : "Add at least one item",
      );
    }

    try {
      await widget.api.post("/products/damage/bulk", {
        "reason": _reason.text.trim(),
        "items": _damageItems.map((item) => item.toBody()).toList(),
      });

      _quantity.clear();
      _weight.clear();
      _reason.clear();
      _productSearch.clear();
      _unitCost.clear();
      _activeChoice = null;
      _damageItems.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? "تم تسجيل البضاعة التالفة" : "Damaged stock was recorded",
          ),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  bool _addDamageItem() {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final choice = _activeChoice;
    if (choice == null) {
      _showError(
        isAr ? "اختار البضاعة من القائمة أولاً" : "Choose an item first",
      );
      return false;
    }

    final quantity = parseNumberInput(_quantity.text);
    final weight = _decimalInput(_weight.text);
    final unitCost = parseNumberInput(_unitCost.text);
    if (quantity <= 0) {
      _showError(isAr ? "اكتب كمية صحيحة" : "Enter a valid quantity");
      return false;
    }
    if (unitCost < 0) {
      _showError(isAr ? "سعر الخسارة غير صحيح" : "Invalid loss cost");
      return false;
    }
    if (weight < 0) {
      _showError(isAr ? "الوزن غير صحيح" : "Invalid weight");
      return false;
    }

    final index = _damageItems.indexWhere((item) => item.id == choice.id);
    final currentQty = index == -1 ? 0.0 : _damageItems[index].quantity;
    final nextQty = currentQty + quantity;
    if (nextQty > choice.quantity) {
      _showError(
        isAr
            ? "الكمية أكبر من الموجود بالمخزون"
            : "Quantity is greater than available stock",
      );
      return false;
    }

    setState(() {
      if (index == -1) {
        _damageItems.add(
          _DamageDraftItem.fromChoice(
            choice,
            quantity: quantity,
            weight: weight,
            unitCost: unitCost,
            currency: _currency,
            reason: _reason.text.trim(),
          ),
        );
      } else {
        _damageItems[index] = _damageItems[index].copyWith(
          quantity: nextQty,
          weight: _damageItems[index].weight + weight,
          unitCost: unitCost,
          currency: _currency,
          reason: _reason.text.trim(),
        );
      }
      _productSearch.clear();
      _quantity.clear();
      _weight.clear();
      _unitCost.clear();
      _activeChoice = null;
    });
    return true;
  }

  Future<void> _resetDamagedData() async {
    final isAr = AppScope.of(context).isArabic;
    if (_movements.isEmpty || _resetting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "تصفير سجل التالف؟" : "Reset damaged data?"),
        content: Text(
          isAr
              ? "سيتم حذف سجل البضاعة التالفة وإرجاع الكميات إلى المخزون."
              : "Damaged goods history will be cleared and quantities will be restored to inventory.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? "إلغاء" : "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? "تصفير" : "Reset"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _resetting = true);
    try {
      await widget.api.delete("/products/damaged");
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? "تم تصفير التالف وإرجاع الكميات للمخزون"
                : "Damaged data reset and stock restored",
          ),
        ),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _selectChoice(_DamageChoice choice) {
    setState(() {
      _activeChoice = choice;
      _productSearch.text = choice.label;
      _unitCost.text = choice.purchasePrice.toStringAsFixed(2);
      _currency = choice.purchaseCurrency;
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final theme = Theme.of(context);
    final totals = _totalsByCurrency();
    final damagedQty = _movements.fold<double>(
      0,
      (sum, row) => sum + row.quantity,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.red,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? "البضاعة التالفة" : "Damaged Goods",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      isAr
                          ? "انقل من المخزون واحسب خسارة التالف مباشرة"
                          : "Move stock into damage and track the loss",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _movements.isEmpty || _resetting
                    ? null
                    : _resetDamagedData,
                tooltip: isAr ? "تصفير التالف" : "Reset damaged data",
                icon: _resetting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            ModernCard(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else ...[
            _summaryGrid(isAr, totals, damagedQty),
            const SizedBox(height: 16),
            _damageForm(isAr),
            const SizedBox(height: 18),
            _movementList(isAr),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _summaryGrid(
    bool isAr,
    Map<String, double> totals,
    double damagedQty,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final width = isWide
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _summaryCard(
                isAr ? "خسارة التالف" : "Damage loss",
                "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}",
                Icons.money_off_rounded,
                Colors.red,
              ),
            ),
            SizedBox(
              width: width,
              child: _summaryCard(
                isAr ? "الكمية التالفة" : "Damaged qty",
                number(damagedQty),
                Icons.inventory_rounded,
                Colors.deepOrange,
              ),
            ),
            SizedBox(
              width: width,
              child: _summaryCard(
                isAr ? "عدد الحركات" : "Movements",
                number(_movements.length),
                Icons.history_rounded,
                Colors.indigo,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.25,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _damageForm(bool isAr) {
    final choices = _filteredChoices();
    final categories = _categoryOptions();
    final active = _activeChoice;

    return ModernCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? "نقل بضاعة إلى التالف" : "Move Item to Damaged",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _responsiveFields([
            DropdownButtonFormField<String>(
              value: _categoryFilter,
              decoration: InputDecoration(
                labelText: isAr ? "الصنف" : "Category",
                prefixIcon: const Icon(Icons.folder_rounded),
              ),
              items: [
                DropdownMenuItem(
                  value: "",
                  child: Text(isAr ? "اختر الصنف" : "Choose category"),
                ),
                ...categories.map(
                  (x) => DropdownMenuItem(value: x, child: Text(x)),
                ),
              ],
              onChanged: (value) => setState(() {
                _categoryFilter = value ?? "";
                _productSearch.clear();
                _clearActiveIfHidden();
              }),
            ),
          ]),
          const SizedBox(height: 12),
          RawAutocomplete<_DamageChoice>(
            textEditingController: _productSearch,
            focusNode: _productFocus,
            displayStringForOption: (choice) => choice.label,
            optionsBuilder: (value) {
              if (_categoryFilter.isEmpty)
                return const Iterable<_DamageChoice>.empty();
              final q = value.text.trim().toLowerCase();
              final filtered = choices
                  .where((choice) {
                    if (q.isEmpty) return true;
                    return choice.searchText.contains(q);
                  })
                  .take(10);
              return filtered;
            },
            onSelected: _selectChoice,
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: isAr ? "ابحث عن المنتج" : "Search product",
                      prefixIcon: const Icon(Icons.manage_search_rounded),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                controller.clear();
                                setState(() => _activeChoice = null);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) {
                      final selected = _activeChoice;
                      if (selected != null && selected.label != value) {
                        setState(() => _activeChoice = null);
                      }
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
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                      maxWidth: 620,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final choice = options.elementAt(index);
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_rounded),
                          ),
                          title: Text(
                            choice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(choice.category),
                          trailing: Text(
                            "${number(choice.quantity)} ${choice.unit}",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          onTap: () => onSelected(choice),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          if (active != null) ...[
            const SizedBox(height: 8),
            Text(
              isAr
                  ? "المتوفر: ${number(active.quantity)} ${active.unit} | سعر الشراء: ${money(active.purchasePrice, active.purchaseCurrency)}"
                  : "Available: ${number(active.quantity)} ${active.unit} | Cost: ${money(active.purchasePrice, active.purchaseCurrency)}",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _responsiveFields([
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isAr ? "الكمية التالفة" : "Damaged quantity",
                prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
              ),
            ),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: isAr ? "الوزن" : "Weight",
                prefixIcon: const Icon(Icons.scale_rounded),
              ),
            ),
            TextField(
              controller: _unitCost,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isAr ? "خسارة الوحدة" : "Loss per unit",
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _responsiveFields([
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: InputDecoration(
                labelText: isAr ? "عملة الخسارة" : "Loss currency",
              ),
              items: const [
                DropdownMenuItem(value: "LBP", child: Text("LBP")),
                DropdownMenuItem(value: "USD", child: Text("USD")),
              ],
              onChanged: (value) => setState(() => _currency = value ?? "LBP"),
            ),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: isAr ? "سبب التلف" : "Damage reason",
                prefixIcon: const Icon(Icons.note_alt_rounded),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addDamageItem,
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(isAr ? "إضافة للسلة" : "Add item"),
            ),
          ),
          const SizedBox(height: 12),
          _damageDraftCard(isAr),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _recordDamage,
              icon: const Icon(Icons.report_problem_rounded),
              label: Text(
                _damageItems.isEmpty
                    ? (isAr ? "تسجيل التالف" : "Record Damaged Stock")
                    : "${isAr ? "تسجيل التالف" : "Record Damaged Stock"} (${number(_damageItems.length)})",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _damageDraftCard(bool isAr) {
    if (_damageItems.isEmpty) {
      return ModernCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.report_problem_rounded, color: Colors.deepOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr
                    ? "أضف كل العناصر التالفة ثم سجلها مرة واحدة."
                    : "Add all damaged items, then record them once.",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final item in _damageItems) {
      totals[item.currency] = (totals[item.currency] ?? 0) + item.total;
    }

    return ModernCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_rounded,
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr ? "سلة التالف" : "Damaged items",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                "${money(totals["LBP"] ?? 0, "LBP")} / ${money(totals["USD"] ?? 0, "USD")}",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Divider(height: 18),
          for (var i = 0; i < _damageItems.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _damageItems[i].label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                [
                  "${number(_damageItems[i].quantity)} ${_damageItems[i].unit} x ${money(_damageItems[i].unitCost, _damageItems[i].currency)}",
                  if (_damageItems[i].weight > 0)
                    "${isAr ? "وزن" : "Weight"}: ${numberDecimal(_damageItems[i].weight)} ${isAr ? "كغ" : "kg"}",
                ].join(" | "),
              ),
              trailing: IconButton(
                tooltip: isAr ? "حذف" : "Remove",
                onPressed: () => setState(() => _damageItems.removeAt(i)),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
        ],
      ),
    );
  }

  Widget _movementList(bool isAr) {
    if (_movements.isEmpty) {
      return ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            isAr
                ? "لا يوجد بضاعة تالفة مسجلة بعد."
                : "No damaged goods recorded yet.",
          ),
        ),
      );
    }

    return ModernCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
        title: Text(
          isAr ? "سجل التالف" : "Damage history",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          isAr ? "${_movements.length} حركة" : "${_movements.length} movements",
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          ..._movements
              .take(25)
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.35),
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.red,
                    ),
                    title: Text(
                      row.productName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      "${_formatDate(row.createdAt)}\n${row.reason.isEmpty ? (isAr ? "بدون ملاحظة" : "No note") : row.reason}",
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          number(row.quantity),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (row.weight > 0)
                          Text(
                            "${numberDecimal(row.weight)} ${isAr ? "كغ" : "kg"}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Text(
                          money(row.totalCost, row.currency),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  List<_DamageChoice> _choices() {
    final rows = <_DamageChoice>[];
    for (final product in _products) {
      if (product.hasVariants) {
        for (final variant in product.variants) {
          if (variant.quantity <= 0) continue;
          rows.add(
            _DamageChoice(
              id: "${product.id}:${variant.id}",
              productId: product.id,
              variantId: variant.id,
              category: product.category,
              label: "${product.name} - ${variant.name}",
              quantity: variant.quantity,
              weight: variant.weight,
              unit: variant.unit,
              purchasePrice: variant.purchasePrice,
              purchaseCurrency: variant.purchaseCurrency,
            ),
          );
        }
      } else {
        if (product.quantity <= 0) continue;
        rows.add(
          _DamageChoice(
            id: product.id,
            productId: product.id,
            variantId: null,
            category: product.category,
            label: product.name,
            quantity: product.quantity,
            weight: product.weight,
            unit: product.unit,
            purchasePrice: product.purchasePrice,
            purchaseCurrency: product.purchaseCurrency,
          ),
        );
      }
    }
    rows.sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  List<_DamageChoice> _filteredChoices() {
    if (_categoryFilter.isEmpty) return [];
    return _choices().where((choice) {
      if (choice.category != _categoryFilter) return false;
      return true;
    }).toList();
  }

  List<String> _categoryOptions() {
    final rows = _choices()
        .map((choice) => choice.category)
        .where((x) => x.trim().isNotEmpty)
        .toSet()
        .toList();
    rows.sort();
    return rows;
  }

  void _clearActiveIfHidden() {
    final selected = _activeChoice;
    if (selected == null) return;
    final visible = _filteredChoices().any(
      (choice) => choice.id == selected.id,
    );
    if (!visible) {
      _activeChoice = null;
      _productSearch.clear();
      _unitCost.clear();
    }
  }

  Map<String, double> _totalsByCurrency() {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final row in _movements) {
      final key = row.currency == "USD" ? "USD" : "LBP";
      totals[key] = (totals[key] ?? 0) + row.totalCost;
    }
    return totals;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
    return date.toString().substring(0, 16);
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

  double _decimalInput(String value) => parseNumberInput(value);
}

class _DamageChoice {
  final String id;
  final String productId;
  final String? variantId;
  final String category;
  final String label;
  final double quantity;
  final double weight;
  final String unit;
  final double purchasePrice;
  final String purchaseCurrency;

  const _DamageChoice({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.category,
    required this.label,
    required this.quantity,
    required this.weight,
    required this.unit,
    required this.purchasePrice,
    required this.purchaseCurrency,
  });

  String get searchText => "$label $category".toLowerCase();
}

class _DamageDraftItem {
  final String id;
  final String productId;
  final String? variantId;
  final String label;
  final double quantity;
  final double weight;
  final String unit;
  final double unitCost;
  final String currency;
  final String reason;

  const _DamageDraftItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.label,
    required this.quantity,
    required this.weight,
    required this.unit,
    required this.unitCost,
    required this.currency,
    required this.reason,
  });

  factory _DamageDraftItem.fromChoice(
    _DamageChoice choice, {
    required double quantity,
    required double weight,
    required double unitCost,
    required String currency,
    required String reason,
  }) {
    return _DamageDraftItem(
      id: choice.id,
      productId: choice.productId,
      variantId: choice.variantId,
      label: choice.label,
      quantity: quantity,
      weight: weight,
      unit: choice.unit,
      unitCost: unitCost,
      currency: currency,
      reason: reason,
    );
  }

  double get total => quantity * unitCost;

  _DamageDraftItem copyWith({
    double? quantity,
    double? weight,
    double? unitCost,
    String? currency,
    String? reason,
  }) {
    return _DamageDraftItem(
      id: id,
      productId: productId,
      variantId: variantId,
      label: label,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      unit: unit,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toBody() {
    return {
      "productId": productId,
      if (variantId != null) "variantId": variantId,
      "quantity": quantity,
      "weight": weight,
      "unitCost": unitCost,
      "currency": currency,
      "reason": reason,
    };
  }
}

class _DamageMovement {
  final String id;
  final String productName;
  final double quantity;
  final double weight;
  final double unitCost;
  final double totalCost;
  final String currency;
  final String reason;
  final DateTime? createdAt;

  const _DamageMovement({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.weight,
    required this.unitCost,
    required this.totalCost,
    required this.currency,
    required this.reason,
    required this.createdAt,
  });

  factory _DamageMovement.fromJson(Map<String, dynamic> json) {
    return _DamageMovement(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      productName: (json["productName"] ?? "").toString(),
      quantity: (_num(json["difference"])).abs(),
      weight: _num(json["weight"]),
      unitCost: _num(json["unitCost"]),
      totalCost: _num(json["totalCost"]),
      currency: (json["currency"] ?? "LBP").toString(),
      reason: (json["reason"] ?? "").toString(),
      createdAt: DateTime.tryParse((json["createdAt"] ?? "").toString()),
    );
  }
}

double _num(dynamic value) {
  return numFromDynamic(value);
}
