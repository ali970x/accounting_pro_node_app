import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/contact.dart";
import "../../widgets/modern_card.dart";

class DebtsPage extends StatefulWidget {
  final ApiClient api;
  const DebtsPage({super.key, required this.api});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _debts = [];
  List<ContactModel> _contacts = [];

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
        widget.api.get("/debts"),
        widget.api.get("/contacts"),
      ]);

      final res = results[0];
      _debts = (res as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final cData = results[1];
      _contacts = (cData as List)
          .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.type == "supplier" || c.type == "customer")
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addOrEdit({Map<String, dynamic>? debt}) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DebtDialog(debt: debt, contacts: _contacts),
    );
    if (body == null) return;

    try {
      if (debt == null) {
        await widget.api.post("/debts", body);
      } else {
        await widget.api.put("/debts/${debt["_id"]}", body);
      }
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addPayment(Map<String, dynamic> debt) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PaymentDialog(currency: (debt["currency"] ?? "LBP").toString()),
    );
    if (body == null) return;

    try {
      await widget.api.post("/debts/${debt["_id"]}/payments", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showLedger(Map<String, dynamic> debt) async {
    final contactId = (debt["contact"] ?? "").toString();
    final name = (debt["personName"] ?? "").toString();
    final rows = _debts.where((d) {
      final dContact = (d["contact"] ?? "").toString();
      if (contactId.isNotEmpty && dContact == contactId) return true;
      return (d["personName"] ?? "").toString() == name;
    }).toList();

    await showDialog<void>(
      context: context,
      builder: (_) => _LedgerDialog(
        name: name,
        debts: rows,
        onPay: (row) async {
          Navigator.pop(context);
          await _addPayment(row);
        },
        onEdit: (row) async {
          Navigator.pop(context);
          await _addOrEdit(debt: row);
        },
        onDelete: (row) async {
          Navigator.pop(context);
          await _delete(row);
        },
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> debt) async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 44),
        content: Text(_label(c.isArabic, "Delete this debt?", "\u062d\u0630\u0641 \u0647\u0630\u0627 \u0627\u0644\u062f\u064a\u0646\u061f")),
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
      await widget.api.delete("/debts/${debt["_id"]}");
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
    final receivable = _moneyByCurrency("receivable");
    final payable = _moneyByCurrency("payable");
    final grouped = _groupDebts();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(child: Text(c.t("debts"), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
              FilledButton.icon(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: Text(_label(isAr, "New", "\u062c\u062f\u064a\u062f")),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _summaryCard(_label(isAr, "For us", "\u0644\u0646\u0627"), receivable, Icons.call_received_rounded, Colors.green)),
              const SizedBox(width: 10),
              Expanded(child: _summaryCard(_label(isAr, "On us", "\u0639\u0644\u064a\u0646\u0627"), payable, Icons.call_made_rounded, Colors.red)),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            ModernCard(child: Text(_error!))
          else if (_debts.isEmpty)
            ModernCard(child: Text(c.t("empty")))
          else
            ...grouped.values.map((rows) => _contactDebtItem(rows, isAr)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupDebts() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final debt in _debts) {
      final contactId = (debt["contact"] ?? "").toString();
      final name = (debt["personName"] ?? "").toString();
      final key = contactId.isNotEmpty ? contactId : name;
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]);
      grouped[key]!.add(debt);
    }
    return grouped;
  }

  String _moneyByCurrency(String type) {
    final totals = <String, double>{};
    for (final debt in _debts.where((d) => (d["type"] ?? "").toString() == type)) {
      final currency = (debt["currency"] ?? "LBP").toString();
      totals[currency] = (totals[currency] ?? 0) + _num(debt["remainingAmount"]);
    }
    if (totals.isEmpty) return "${money(0, "LBP")}\n${money(0, "USD")}";
    return "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}";
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
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
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactDebtItem(List<Map<String, dynamic>> rows, bool isAr) {
    final first = rows.first;
    final type = (first["type"] ?? "").toString();
    final color = type == "receivable" ? Colors.green : Colors.red;
    final name = (first["personName"] ?? "").toString();
    final openCount = rows.where((d) => (d["status"] ?? "").toString() != "paid").length;
    final totals = _totalsFor(rows);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        onTap: () => _showLedger(first),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(type == "receivable" ? Icons.person_rounded : Icons.store_rounded, color: color),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text("${type == "receivable" ? _label(isAr, "Customer", "\u0632\u0628\u0648\u0646") : _label(isAr, "Supplier", "\u0645\u0648\u0631\u062f")} • ${rows.length} ${_label(isAr, "invoices", "\u0641\u0648\u0627\u062a\u064a\u0631")} • $openCount ${_label(isAr, "open", "\u0645\u0641\u062a\u0648\u062d")}"),
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_formatTotals(totals), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
              IconButton(
                tooltip: _label(isAr, "Open ledger", "\u0641\u062a\u062d \u0627\u0644\u062c\u0631\u062f\u0629"),
                onPressed: () => _showLedger(first),
                icon: const Icon(Icons.receipt_long_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debtItem(Map<String, dynamic> debt, bool isAr) {
    final type = (debt["type"] ?? "").toString();
    final color = type == "receivable" ? Colors.green : Colors.red;
    final remaining = _num(debt["remainingAmount"]);
    final currency = (debt["currency"] ?? "LBP").toString();
    final status = (debt["status"] ?? "-").toString();
    final note = (debt["note"] ?? "").toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        onTap: () => _showLedger(debt),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(type == "receivable" ? Icons.call_received : Icons.call_made)),
          title: Text((debt["personName"] ?? "").toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(note.isEmpty ? status : "$status\n$note"),
          trailing: Wrap(
            spacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(money(remaining, currency), style: TextStyle(fontWeight: FontWeight.w900, color: color)),
              IconButton(
                tooltip: _label(isAr, "Payment", "\u062f\u0641\u0639\u0629"),
                onPressed: () => _addPayment(debt),
                icon: const Icon(Icons.payments_rounded),
              ),
              IconButton(
                tooltip: _label(isAr, "Edit", "\u062a\u0639\u062f\u064a\u0644"),
                onPressed: () => _addOrEdit(debt: debt),
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                tooltip: _label(isAr, "Delete", "\u062d\u0630\u0641"),
                onPressed: () => _delete(debt),
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

  Map<String, double> _totalsFor(List<Map<String, dynamic>> rows) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final row in rows) {
      final currency = (row["currency"] ?? "LBP").toString() == "USD" ? "USD" : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _num(row["remainingAmount"]);
    }
    return totals;
  }

  String _formatTotals(Map<String, double> totals) {
    return "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}";
  }
}

class _DebtDialog extends StatefulWidget {
  final Map<String, dynamic>? debt;
  final List<ContactModel> contacts;
  const _DebtDialog({this.debt, required this.contacts});

  @override
  State<_DebtDialog> createState() => _DebtDialogState();
}

class _DebtDialogState extends State<_DebtDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _contactId;
  String _type = "receivable";
  String _currency = "LBP";

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    if (debt == null) return;
    _amount.text = _numText(debt["originalAmount"]);
    _note.text = (debt["note"] ?? "").toString();
    _contactId = (debt["contact"] ?? "").toString().isEmpty ? null : (debt["contact"] ?? "").toString();
    _type = (debt["type"] ?? "receivable").toString();
    _currency = (debt["currency"] ?? "LBP").toString();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return AlertDialog(
      title: Text(widget.debt == null ? _label(isAr, "New Debt", "\u062f\u064a\u0646 \u062c\u062f\u064a\u062f") : _label(isAr, "Edit Debt", "\u062a\u0639\u062f\u064a\u0644 \u062f\u064a\u0646")),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _contactId,
              decoration: InputDecoration(labelText: _label(isAr, "Contact", "\u062c\u0647\u0629 \u0627\u0644\u0627\u062a\u0635\u0627\u0644")),
              items: widget.contacts
                  .map((contact) => DropdownMenuItem(
                        value: contact.id,
                        child: Text("${contact.name} - ${contact.type == "supplier" ? _label(isAr, "Supplier", "\u0645\u0648\u0631\u062f") : _label(isAr, "Customer", "\u0632\u0628\u0648\u0646")}"),
                      ))
                  .toList(),
              onChanged: (v) {
                final contact = _firstContactWhere((c) => c.id == v);
                setState(() {
                  _contactId = v;
                  if (contact != null) {
                    _type = contact.type == "supplier" ? "payable" : "receivable";
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(labelText: _label(isAr, "Type", "\u0627\u0644\u0646\u0648\u0639")),
              items: [
                DropdownMenuItem(value: "receivable", child: Text(_label(isAr, "Receivable", "\u0644\u0646\u0627"))),
                DropdownMenuItem(value: "payable", child: Text(_label(isAr, "Payable", "\u0639\u0644\u064a\u0646\u0627"))),
              ],
              onChanged: null,
            ),
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
            TextField(controller: _note, decoration: InputDecoration(labelText: _label(isAr, "Note", "\u0645\u0644\u0627\u062d\u0638\u0629"))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel"))),
        FilledButton(
          onPressed: () {
            final contact = _firstContactWhere((c) => c.id == _contactId);
            if (contact == null) return;
            Navigator.pop(context, {
              "contact": contact.id,
              "personName": contact.name,
              "type": _type,
              "originalAmount": double.tryParse(_amount.text) ?? 0,
              "currency": _currency,
              "note": _note.text.trim(),
            });
          },
          child: Text(c.t("save")),
        ),
      ],
    );
  }

  ContactModel? _firstContactWhere(bool Function(ContactModel) test) {
    for (final contact in widget.contacts) {
      if (test(contact)) return contact;
    }
    return null;
  }

  String _numText(dynamic value) {
    if (value is num) return value.toString();
    return value?.toString() ?? "";
  }
}

class _LedgerDialog extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> debts;
  final Future<void> Function(Map<String, dynamic>) onPay;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const _LedgerDialog({
    required this.name,
    required this.debts,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppScope.of(context).isArabic;
    final totals = _totalsFor(debts);

    return AlertDialog(
      title: Text(name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${_label(isAr, "Remaining", "\u0627\u0644\u0645\u062a\u0628\u0642\u064a")}:\n${_formatTotals(totals)}", style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final debt in debts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(money(_num(debt["remainingAmount"]), (debt["currency"] ?? "LBP").toString())),
                  subtitle: Text((debt["note"] ?? debt["status"] ?? "").toString()),
                  trailing: Wrap(
                    children: [
                      IconButton(onPressed: () => onPay(debt), icon: const Icon(Icons.payments_rounded)),
                      IconButton(onPressed: () => onEdit(debt), icon: const Icon(Icons.edit_rounded)),
                      IconButton(onPressed: () => onDelete(debt), icon: const Icon(Icons.delete_outline_rounded)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_label(isAr, "Close", "\u0625\u063a\u0644\u0627\u0642"))),
      ],
    );
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, double> _totalsFor(List<Map<String, dynamic>> rows) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final row in rows) {
      final currency = (row["currency"] ?? "LBP").toString() == "USD" ? "USD" : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _num(row["remainingAmount"]);
    }
    return totals;
  }

  String _formatTotals(Map<String, double> totals) {
    return "${money(totals["LBP"] ?? 0, "LBP")}\n${money(totals["USD"] ?? 0, "USD")}";
  }
}

class _PaymentDialog extends StatefulWidget {
  final String currency;
  const _PaymentDialog({required this.currency});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _currency;

  @override
  void initState() {
    super.initState();
    _currency = widget.currency == "USD" ? "USD" : "LBP";
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return AlertDialog(
      title: Text(_label(isAr, "Add Payment", "\u0625\u0636\u0627\u0641\u0629 \u062f\u0641\u0639\u0629")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _label(isAr, "Amount", "\u0627\u0644\u0645\u0628\u0644\u063a"))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: InputDecoration(labelText: c.t("currency")),
            items: const [
              DropdownMenuItem(value: "LBP", child: Text("LBP")),
              DropdownMenuItem(value: "USD", child: Text("USD")),
            ],
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: InputDecoration(labelText: _label(isAr, "Note", "\u0645\u0644\u0627\u062d\u0638\u0629"))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel"))),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              "amount": double.tryParse(_amount.text) ?? 0,
              "currency": _currency,
              "note": _note.text.trim(),
            });
          },
          child: Text(c.t("save")),
        ),
      ],
    );
  }
}

String _label(bool isAr, String en, String ar) => isAr ? ar : en;
