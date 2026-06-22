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
          Text(c.t("reports"), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            ModernCard(child: Text(_error!))
          else ...[
            _sectionTitle(_label(isAr, "Financial Snapshot", "\u0644\u0645\u062d\u0629 \u0645\u0627\u0644\u064a\u0629")),
            const SizedBox(height: 12),
            _metricGrid([
              _Metric(_label(isAr, "Sales", "\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a"), money(_num(_data["totalSales"]), "USD"), Icons.trending_up, Colors.blue),
              _Metric(_label(isAr, "Expenses", "\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641"), money(_num(_data["totalExpenses"]), "USD"), Icons.receipt_long, Colors.red),
              _Metric(_label(isAr, "Net Profit", "\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d"), money(_num(_data["totalProfit"]), "USD"), Icons.account_balance_wallet, Colors.green),
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
              _Metric(_label(isAr, "Receivable", "\u0644\u0646\u0627"), money(_num(_data["receivableTotal"]), "USD"), Icons.call_received, Colors.green),
              _Metric(_label(isAr, "Payable", "\u0639\u0644\u064a\u0646\u0627"), money(_num(_data["payableTotal"]), "USD"), Icons.call_made, Colors.red),
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
    return Container(
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
          Text(metric.value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: metric.color)),
          Text(metric.title, style: TextStyle(fontSize: 12, color: metric.color.withOpacity(0.8))),
        ],
      ),
    );
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
}

class _Metric {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.title, this.value, this.icon, this.color);
}

String _label(bool isAr, String en, String ar) => isAr ? ar : en;
