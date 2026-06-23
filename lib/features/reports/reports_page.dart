import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../widgets/modern_card.dart";

class ReportsPage extends StatefulWidget {
  final ApiClient api;
  const ReportsPage({super.key, required this.api});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _lowStock = [];

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
      final res = await widget.api.get("/reports/summary");
      final low = await widget.api.get("/reports/low-stock");
      _data = Map<String, dynamic>.from(res as Map);
      _lowStock = (low as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(child: Text(c.t("reports"), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
              IconButton.filledTonal(
                onPressed: _resetProfits,
                tooltip: _label(isAr, "Reset profits", "\u062a\u0635\u0641\u064a\u0631 \u0627\u0644\u0623\u0631\u0628\u0627\u062d"),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            ModernCard(child: Text(_error!))
          else ...[
            _sectionTitle(_label(isAr, "Financial Snapshot", "\u0644\u0645\u062d\u0629 \u0645\u0627\u0644\u064a\u0629")),
            const SizedBox(height: 12),
            _metricGrid([
              _Metric(_label(isAr, "Sales", "\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a"), _moneyBreakdown(_data["salesByCurrency"]), Icons.trending_up, Colors.blue),
              _Metric(_label(isAr, "Expenses", "\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641"), _moneyBreakdown(_data["expensesByCurrency"]), Icons.receipt_long, Colors.red),
              _Metric(
                _label(isAr, "Net Profit", "\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d"),
                _moneyBreakdown(_data["netProfitByCurrency"]),
                Icons.account_balance_wallet,
                Colors.green,
                onLongPress: () => _showActualProfit(isAr),
              ),
              _Metric(_label(isAr, "Avg. Invoice", "\u0645\u0639\u062f\u0644 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629"), money(_num(_data["averageTicket"]), "USD"), Icons.analytics, Colors.indigo),
            ]),
            const SizedBox(height: 22),
            _sectionTitle(_label(isAr, "Operations", "\u0627\u0644\u062a\u0634\u063a\u064a\u0644")),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _rowItem(_label(isAr, "Invoices Count", "\u0639\u062f\u062f \u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631"), _num(_data["salesCount"]).toStringAsFixed(0), Icons.receipt),
                  const Divider(),
                  _rowItem(_label(isAr, "Products Count", "\u0639\u062f\u062f \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a"), _num(_data["productsCount"]).toStringAsFixed(0), Icons.inventory_2),
                  const Divider(),
                  _rowItem(_label(isAr, "Current Stock Value", "\u0642\u064a\u0645\u0629 \u0627\u0644\u0645\u062e\u0632\u0648\u0646"), money(_num(_data["inventoryValue"]), "USD"), Icons.warehouse),
                  const Divider(),
                  _rowItem(_label(isAr, "Low Stock Items", "\u0645\u062e\u0632\u0648\u0646 \u0645\u0646\u062e\u0641\u0636"), _num(_data["lowStockCount"]).toStringAsFixed(0), Icons.warning_amber, color: Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(_label(isAr, "Debts", "\u0627\u0644\u062f\u064a\u0648\u0646")),
            const SizedBox(height: 12),
            _metricGrid([
              _Metric(_label(isAr, "Receivable", "\u0644\u0646\u0627"), _moneyBreakdown(_data["receivableByCurrency"]), Icons.call_received, Colors.green),
              _Metric(_label(isAr, "Payable", "\u0639\u0644\u064a\u0646\u0627"), _moneyBreakdown(_data["payableByCurrency"]), Icons.call_made, Colors.red),
            ]),
            const SizedBox(height: 22),
            _sectionTitle(_label(isAr, "Low Stock Watch", "\u0645\u0631\u0627\u0642\u0628\u0629 \u0627\u0644\u0645\u062e\u0632\u0648\u0646")),
            const SizedBox(height: 12),
            if (_lowStock.isEmpty)
              ModernCard(child: Text(_label(isAr, "No low stock items.", "\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u062e\u0632\u0648\u0646 \u0645\u0646\u062e\u0641\u0636.")))
            else
              ModernCard(
                child: Column(
                  children: _lowStockChildren(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));

  Widget _metricGrid(List<_Metric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final width = isWide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics) SizedBox(width: metrics.length == 2 && isWide ? (constraints.maxWidth - 12) / 2 : width, child: _statCard(metric)),
          ],
        );
      },
    );
  }

  Widget _statCard(_Metric metric) {
    return GestureDetector(
      onLongPress: metric.onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: metric.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: metric.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: metric.color),
            const SizedBox(height: 12),
            Text(metric.value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.25, color: metric.color)),
            Text(metric.title, style: TextStyle(fontSize: 12, color: metric.color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Future<void> _showActualProfit(bool isAr) async {
    final net = _currencyMap(_data["netProfitByCurrency"]);
    final receivable = _currencyMap(_data["receivableByCurrency"]);
    final payable = _currencyMap(_data["payableByCurrency"]);
    final actual = {
      "LBP": (net["LBP"] ?? 0) - (receivable["LBP"] ?? 0) - (payable["LBP"] ?? 0),
      "USD": (net["USD"] ?? 0) - (receivable["USD"] ?? 0) - (payable["USD"] ?? 0),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_label(isAr, "Actual Profit", "\u0627\u0644\u0631\u0628\u062d \u0627\u0644\u0641\u0639\u0644\u064a")),
        content: Text(
          "${_label(isAr, "Net profit", "\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d")}:\n${_moneyBreakdown(net)}\n\n"
          "${_label(isAr, "Debts", "\u0627\u0644\u062f\u064a\u0648\u0646")}:\n${_moneyBreakdown({"LBP": (receivable["LBP"] ?? 0) + (payable["LBP"] ?? 0), "USD": (receivable["USD"] ?? 0) + (payable["USD"] ?? 0)})}\n\n"
          "${_label(isAr, "Actual profit", "\u0627\u0644\u0631\u0628\u062d \u0627\u0644\u0641\u0639\u0644\u064a")}:\n${_moneyBreakdown(actual)}",
          style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_label(isAr, "Close", "\u0625\u063a\u0644\u0627\u0642"))),
        ],
      ),
    );
  }

  Future<void> _resetProfits() async {
    final isAr = AppScope.of(context).isArabic;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_label(isAr, "Reset profits?", "\u062a\u0635\u0641\u064a\u0631 \u0627\u0644\u0623\u0631\u0628\u0627\u062d\u061f")),
        content: Text(_label(
          isAr,
          "Reports will calculate profit from this moment forward. Old invoices stay saved.",
          "\u0633\u064a\u062a\u0645 \u062d\u0633\u0627\u0628 \u0627\u0644\u0631\u0628\u062d \u0645\u0646 \u0647\u0630\u0647 \u0627\u0644\u0644\u062d\u0638\u0629 \u0648\u0645\u0627 \u0628\u0639\u062f\u0647\u0627. \u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631 \u0627\u0644\u0642\u062f\u064a\u0645\u0629 \u062a\u0628\u0642\u0649 \u0645\u062d\u0641\u0648\u0638\u0629.",
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_label(isAr, "Cancel", "\u0625\u0644\u063a\u0627\u0621"))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_label(isAr, "Reset", "\u062a\u0635\u0641\u064a\u0631"))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.post("/reports/reset-profits", {});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _rowItem(String title, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _lowStockRow(Map<String, dynamic> row) {
    final quantity = _num(row["quantity"]);
    final minStock = _num(row["minStock"]);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.warning_amber_rounded)),
      title: Text((row["name"] ?? "").toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text("${quantity.toStringAsFixed(0)} / ${minStock.toStringAsFixed(0)} ${(row["unit"] ?? "").toString()}"),
    );
  }

  List<Widget> _lowStockChildren() {
    final shown = _lowStock.length > 8 ? 8 : _lowStock.length;
    final children = <Widget>[];
    for (var i = 0; i < shown; i++) {
      children.add(_lowStockRow(_lowStock[i]));
      if (i != shown - 1) children.add(const Divider());
    }
    return children;
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _moneyBreakdown(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final lbp = _num(map["LBP"]);
    final usd = _num(map["USD"]);
    return "${money(lbp, "LBP")}\n${money(usd, "USD")}";
  }

  Map<String, double> _currencyMap(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return {"LBP": _num(map["LBP"]), "USD": _num(map["USD"])};
  }
}

class _Metric {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onLongPress;

  const _Metric(this.title, this.value, this.icon, this.color, {this.onLongPress});
}

String _label(bool isAr, String en, String ar) => isAr ? ar : en;
