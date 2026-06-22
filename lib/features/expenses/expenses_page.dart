import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../widgets/modern_card.dart";

class ExpensesPage extends StatefulWidget {
  final ApiClient api;
  const ExpensesPage({super.key, required this.api});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];

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
      final res = await widget.api.get("/expenses");
      _expenses = (res as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addOrEdit({Map<String, dynamic>? expense}) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ExpenseDialog(
        expense: expense,
        expenseNames: _expenseNames(),
        categories: _expenseCategories(),
      ),
    );
    if (body == null) return;

    try {
      if (expense == null) {
        await widget.api.post("/expenses", body);
      } else {
        await widget.api.put("/expenses/${expense["_id"]}", body);
      }
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(Map<String, dynamic> expense) async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 46),
        content: Text(_label(c.isArabic, "Delete this expense?", "\u062d\u0630\u0641 \u0647\u0630\u0627 \u0627\u0644\u0645\u0635\u0631\u0648\u0641\u061f")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(c.t("cancel"))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(c.t("delete")),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.delete("/expenses/${expense["_id"]}");
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
    final isAr = c.isArabic;
    final totalUsd = _expenses.where((e) => (e["currency"] ?? "USD") == "USD").fold(0.0, (sum, e) => sum + _num(e["amount"]));
    final totalLbp = _expenses.where((e) => (e["currency"] ?? "USD") == "LBP").fold(0.0, (sum, e) => sum + _num(e["amount"]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(child: Text(c.t("expenses"), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
              FilledButton.icon(onPressed: () => _addOrEdit(), icon: const Icon(Icons.add), label: Text(_label(isAr, "New Expense", "\u0645\u0635\u0631\u0648\u0641 \u062c\u062f\u064a\u062f"))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _totalCard("USD", money(totalUsd, "USD"), Icons.attach_money, Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: _totalCard("LBP", money(totalLbp, "LBP"), Icons.payments, Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            ModernCard(child: Text(_error!))
          else if (_expenses.isEmpty)
            ModernCard(child: Text(c.t("empty")))
          else
            ..._expenses.map((expense) => _expenseItem(expense, isAr)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _totalCard(String title, String value, IconData icon, Color color) {
    return ModernCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseItem(Map<String, dynamic> expense, bool isAr) {
    final amount = _num(expense["amount"]);
    final currency = (expense["currency"] ?? "USD").toString();
    final rawDate = (expense["date"] ?? "").toString();
    final shortDate = rawDate.isEmpty ? "" : rawDate.substring(0, rawDate.length < 10 ? rawDate.length : 10);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.receipt_rounded)),
          title: Text((expense["title"] ?? "").toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text("${expense["category"] ?? "General"}${shortDate.isEmpty ? "" : "\n$shortDate"}"),
          trailing: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(money(amount, currency), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
              IconButton(
                tooltip: _label(isAr, "Edit", "\u062a\u0639\u062f\u064a\u0644"),
                onPressed: () => _addOrEdit(expense: expense),
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                tooltip: _label(isAr, "Delete", "\u062d\u0630\u0641"),
                onPressed: () => _delete(expense),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<String> _expenseNames() {
    final rows = _expenses.map((e) => (e["title"] ?? "").toString().trim()).where((x) => x.isNotEmpty).toSet().toList();
    rows.sort();
    return rows;
  }

  List<String> _expenseCategories() {
    final rows = _expenses.map((e) => (e["category"] ?? "General").toString().trim()).where((x) => x.isNotEmpty).toSet().toList();
    rows.sort();
    return rows.isEmpty ? ["General"] : rows;
  }
}

class _ExpenseDialog extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final List<String> expenseNames;
  final List<String> categories;
  const _ExpenseDialog({this.expense, required this.expenseNames, required this.categories});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  static const _newValue = "__new__";
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController(text: "General");
  final _note = TextEditingController();
  String? _selectedTitle;
  String? _selectedCategory;
  String _currency = "USD";

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _selectedTitle = widget.expenseNames.isEmpty ? _newValue : widget.expenseNames.first;
    _selectedCategory = widget.categories.isEmpty ? _newValue : widget.categories.first;
    if (_selectedTitle != _newValue) _title.text = _selectedTitle!;
    if (_selectedCategory != _newValue) _category.text = _selectedCategory!;
    if (e == null) return;
    _title.text = (e["title"] ?? "").toString();
    _amount.text = _numText(e["amount"]);
    _category.text = (e["category"] ?? "General").toString();
    _note.text = (e["note"] ?? "").toString();
    _currency = (e["currency"] ?? "USD").toString();
    _selectedTitle = widget.expenseNames.contains(_title.text) ? _title.text : _newValue;
    _selectedCategory = widget.categories.contains(_category.text) ? _category.text : _newValue;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return AlertDialog(
      title: Text(widget.expense == null ? _label(isAr, "New Expense", "\u0645\u0635\u0631\u0648\u0641 \u062c\u062f\u064a\u062f") : _label(isAr, "Edit Expense", "\u062a\u0639\u062f\u064a\u0644 \u0645\u0635\u0631\u0648\u0641")),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTitle,
              decoration: InputDecoration(labelText: _label(isAr, "Expense", "\u0627\u0644\u0645\u0635\u0631\u0648\u0641")),
              items: [
                ...widget.expenseNames.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                DropdownMenuItem(value: _newValue, child: Text(_label(isAr, "New expense", "\u0645\u0635\u0631\u0648\u0641 \u062c\u062f\u064a\u062f"))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedTitle = v ?? _newValue;
                  if (_selectedTitle == _newValue) {
                    _title.clear();
                  } else {
                    _title.text = _selectedTitle!;
                  }
                });
              },
            ),
            if (_selectedTitle == _newValue) ...[
              const SizedBox(height: 12),
              TextField(controller: _title, decoration: InputDecoration(labelText: _label(isAr, "Expense name", "\u0627\u0633\u0645 \u0627\u0644\u0645\u0635\u0631\u0648\u0641"))),
            ],
            const SizedBox(height: 12),
            TextField(controller: _amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _label(isAr, "Amount", "\u0627\u0644\u0645\u0628\u0644\u063a"))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: InputDecoration(labelText: c.t("currency")),
              items: const [
                DropdownMenuItem(value: "USD", child: Text("USD")),
                DropdownMenuItem(value: "LBP", child: Text("LBP")),
              ],
              onChanged: (v) => setState(() => _currency = v ?? _currency),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(labelText: _label(isAr, "Category", "\u0627\u0644\u0641\u0626\u0629")),
              items: [
                ...widget.categories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                DropdownMenuItem(value: _newValue, child: Text(_label(isAr, "New category", "\u0641\u0626\u0629 \u062c\u062f\u064a\u062f\u0629"))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedCategory = v ?? _newValue;
                  if (_selectedCategory == _newValue) {
                    _category.clear();
                  } else {
                    _category.text = _selectedCategory!;
                  }
                });
              },
            ),
            if (_selectedCategory == _newValue) ...[
              const SizedBox(height: 12),
              TextField(controller: _category, decoration: InputDecoration(labelText: _label(isAr, "Category name", "\u0627\u0633\u0645 \u0627\u0644\u0641\u0626\u0629"))),
            ],
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: InputDecoration(labelText: _label(isAr, "Note", "\u0645\u0644\u0627\u062d\u0638\u0629"))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel"))),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              "title": _title.text.trim(),
              "amount": double.tryParse(_amount.text) ?? 0,
              "currency": _currency,
              "category": _category.text.trim().isEmpty ? "General" : _category.text.trim(),
              "note": _note.text.trim(),
            });
          },
          child: Text(c.t("save")),
        ),
      ],
    );
  }

  String _numText(dynamic value) {
    if (value is num) return value.toString();
    return value?.toString() ?? "";
  }
}

String _label(bool isAr, String en, String ar) => isAr ? ar : en;
