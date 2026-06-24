import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class ReportsPage extends StatefulWidget {
  final ApiClient api;
  final VoidCallback? onOpenExpenses;
  final VoidCallback? onOpenRecords;
  final VoidCallback? onOpenDamages;
  const ReportsPage({super.key, required this.api, this.onOpenExpenses, this.onOpenRecords, this.onOpenDamages});

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
          PageHeader(
            title: c.t("reports"),
            actions: [
              FilledButton.icon(
                onPressed: _resetProfits,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(_label(isAr, "Reset Profits", "\u062a\u0635\u0641\u064a\u0631 \u0627\u0644\u0623\u0631\u0628\u0627\u062d")),
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
              _Metric(_label(isAr, "Sales", "\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a"), _moneyBreakdown(_data["salesByCurrency"]), Icons.trending_up, Colors.blue, onLongPress: widget.onOpenRecords),
              _Metric(_label(isAr, "Expenses", "\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641"), _moneyBreakdown(_data["expensesByCurrency"]), Icons.receipt_long, Colors.red, onLongPress: widget.onOpenExpenses),
              _Metric(_label(isAr, "Damaged Goods", "\u0627\u0644\u0628\u0636\u0627\u0639\u0629 \u0627\u0644\u062a\u0627\u0644\u0641\u0629"), _moneyBreakdown(_data["damageLossByCurrency"]), Icons.report_problem_rounded, Colors.deepOrange, onLongPress: widget.onOpenDamages),
              _Metric(
                _label(isAr, "Net Profit", "\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d"),
                _moneyBreakdown(_data["netProfitByCurrency"]),
                Icons.account_balance_wallet,
                Colors.green,
                onLongPress: () => _showActualProfit(isAr),
              ),
              _Metric(_label(isAr, "Avg. Invoice", "\u0645\u0639\u062f\u0644 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629"), _moneyBreakdown(_data["averageTicketByCurrency"]), Icons.analytics, Colors.indigo, onLongPress: () => _showAverageProfit(isAr)),
            ]),
            const SizedBox(height: 22),
            _insightsSection(isAr),
            const SizedBox(height: 22),
            _sectionTitle(_label(isAr, "Operations", "\u0627\u0644\u062a\u0634\u063a\u064a\u0644")),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  _rowItem(_label(isAr, "Invoices Count", "\u0639\u062f\u062f \u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631"), number(_num(_data["salesCount"])), Icons.receipt),
                  const Divider(),
                  _rowItem(_label(isAr, "Products Count", "\u0639\u062f\u062f \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a"), number(_num(_data["productsCount"])), Icons.inventory_2),
                  const Divider(),
                  _rowItem(_label(isAr, "Current Stock Value", "\u0642\u064a\u0645\u0629 \u0627\u0644\u0645\u062e\u0632\u0648\u0646"), money(_num(_data["inventoryValue"]), "USD"), Icons.warehouse),
                  const Divider(),
                  _rowItem(_label(isAr, "Low Stock Items", "\u0645\u062e\u0632\u0648\u0646 \u0645\u0646\u062e\u0641\u0636"), number(_num(_data["lowStockCount"])), Icons.warning_amber, color: Colors.orange),
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

  Widget _insightsSection(bool isAr) {
    final insights = _map(_data["insights"]);
    final topCustomer = _map(insights["topCustomerPaid"]);
    final bestMonth = _map(insights["bestSalesMonth"]);
    final alert = _map(insights["expenseAlert"]);
    final comparison = _map(insights["monthComparison"]);
    final current = _map(comparison["current"]);
    final previous = _map(comparison["previous"]);
    final monthly = _list(insights["monthly"]).map((row) {
      final map = _map(row);
      return _MonthlyPoint(
        label: (map["label"] ?? "").toString(),
        sales: _num(map["salesEquivalentLbp"]),
        expenses: _num(map["expensesEquivalentLbp"]),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_label(isAr, "Business Insights", "\u0645\u0624\u0634\u0631\u0627\u062a \u0627\u0644\u0639\u0645\u0644")),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final width = isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _insightCard(
                    title: _label(isAr, "Top paying customer", "\u0623\u0643\u062b\u0631 \u0632\u0628\u0648\u0646 \u062f\u0641\u0639"),
                    value: topCustomer.isEmpty ? "-" : (topCustomer["name"] ?? "-").toString(),
                    subtitle: topCustomer.isEmpty ? _label(isAr, "No paid invoices yet", "\u0644\u0627 \u064a\u0648\u062c\u062f \u0641\u0648\u0627\u062a\u064a\u0631 \u0645\u062f\u0641\u0648\u0639\u0629 \u0628\u0639\u062f") : money(_num(topCustomer["totalEquivalentLbp"]), "LBP"),
                    icon: Icons.emoji_events_rounded,
                    color: Colors.amber.shade700,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _insightCard(
                    title: _label(isAr, "Best sales month", "\u0623\u0641\u0636\u0644 \u0634\u0647\u0631 \u0645\u0628\u064a\u0639\u0627\u062a"),
                    value: bestMonth.isEmpty ? "-" : (bestMonth["label"] ?? "-").toString(),
                    subtitle: bestMonth.isEmpty ? "-" : money(_num(bestMonth["salesEquivalentLbp"]), "LBP"),
                    icon: Icons.calendar_month_rounded,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _insightCard(
                    title: _label(isAr, "Expense alert", "\u062a\u0646\u0628\u064a\u0647 \u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641"),
                    value: alert["active"] == true ? _label(isAr, "Expenses increased", "\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641 \u0632\u0627\u062f\u062a") : _label(isAr, "Expenses stable", "\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641 \u0645\u0633\u062a\u0642\u0631\u0629"),
                    subtitle: "${_formatPercent(_num(alert["percentChange"]))} ${_label(isAr, "vs previous month", "\u0645\u0642\u0627\u0631\u0646\u0629 \u0628\u0627\u0644\u0634\u0647\u0631 \u0627\u0644\u0633\u0627\u0628\u0642")}",
                    icon: alert["active"] == true ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    color: alert["active"] == true ? Colors.red : Colors.green,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _insightCard(
                    title: _label(isAr, "Current vs previous month", "\u0645\u0642\u0627\u0631\u0646\u0629 \u0627\u0644\u0634\u0647\u0631 \u0627\u0644\u062d\u0627\u0644\u064a \u0648\u0627\u0644\u0633\u0627\u0628\u0642"),
                    value: "${current["label"] ?? "-"} / ${previous["label"] ?? "-"}",
                    subtitle: "${_label(isAr, "Sales", "\u0627\u0644\u0645\u0628\u064a\u0639")}: ${_formatPercent(_num(comparison["salesChangePercent"]))} | ${_label(isAr, "Profit", "\u0627\u0644\u0631\u0628\u062d")}: ${_formatPercent(_num(comparison["profitChangePercent"]))}",
                    icon: Icons.compare_arrows_rounded,
                    color: Colors.purple,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _monthlyChart(monthly, isAr),
      ],
    );
  }

  Widget _insightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlyChart(List<_MonthlyPoint> points, bool isAr) {
    final theme = Theme.of(context);
    final clean = points.where((point) => point.label.isNotEmpty).toList();
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _label(isAr, "Monthly Sales / Expenses Chart", "\u0631\u0633\u0645 \u0628\u064a\u0627\u0646\u064a \u0634\u0647\u0631\u064a \u0644\u0644\u0645\u0628\u064a\u0639 \u0648\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641"),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: clean.isEmpty
                ? Center(child: Text(_label(isAr, "No monthly data yet.", "\u0644\u0627 \u064a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a \u0634\u0647\u0631\u064a\u0629 \u0628\u0639\u062f.")))
                : CustomPaint(
                    painter: _MonthlyChartPainter(
                      points: clean,
                      salesColor: Colors.blue,
                      expensesColor: Colors.red,
                      axisColor: theme.colorScheme.outlineVariant,
                      labelColor: theme.colorScheme.onSurfaceVariant,
                      textDirection: Directionality.of(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              _legendDot(_label(isAr, "Sales", "\u0627\u0644\u0645\u0628\u064a\u0639"), Colors.blue),
              _legendDot(_label(isAr, "Expenses", "\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641"), Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _metricGrid(List<_Metric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredWidth = constraints.maxWidth >= 900 ? 260.0 : 210.0;
        final columns = (constraints.maxWidth / preferredWidth).floor().clamp(1, metrics.length);
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics) SizedBox(width: width, child: _statCard(metric)),
          ],
        );
      },
    );
  }

  Widget _statCard(_Metric metric) {
    final theme = Theme.of(context);
    final values = metric.value.split("\n").where((line) => line.trim().isNotEmpty).toList();
    return GestureDetector(
      onLongPress: metric.onLongPress,
      child: ModernCard(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: metric.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(metric.icon, color: metric.color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metric.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              for (final value in values)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: metric.color, height: 1.1),
                  ),
                ),
            ],
          ),
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

  Future<void> _showAverageProfit(bool isAr) async {
    final average = _currencyMap(_data["averageInvoiceProfitByCurrency"]);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_label(isAr, "Average Invoice Profit", "\u0645\u0639\u062f\u0644 \u0631\u0628\u062d \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629")),
        content: Text(
          "${_label(isAr, "Profit per invoice", "\u0631\u0628\u062d \u0643\u0644 \u0641\u0627\u062a\u0648\u0631\u0629")}:\n${_moneyBreakdown(average)}",
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
      subtitle: Text("${number(quantity)} / ${number(minStock)} ${(row["unit"] ?? "").toString()}"),
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

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic raw) {
    if (raw is List) return raw;
    return const [];
  }

  String _formatPercent(double value) {
    final sign = value > 0 ? "+" : "";
    return "$sign${value.toStringAsFixed(1)}%";
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

class _MonthlyPoint {
  final String label;
  final double sales;
  final double expenses;

  const _MonthlyPoint({
    required this.label,
    required this.sales,
    required this.expenses,
  });
}

class _MonthlyChartPainter extends CustomPainter {
  final List<_MonthlyPoint> points;
  final Color salesColor;
  final Color expensesColor;
  final Color axisColor;
  final Color labelColor;
  final TextDirection textDirection;

  const _MonthlyChartPainter({
    required this.points,
    required this.salesColor,
    required this.expensesColor,
    required this.axisColor,
    required this.labelColor,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points.fold<double>(0, (max, point) {
      final local = point.sales > point.expenses ? point.sales : point.expenses;
      return local > max ? local : max;
    });
    final chartHeight = size.height - 36;
    final chartTop = 8.0;
    final chartBottom = chartTop + chartHeight;
    final groupWidth = size.width / points.length;
    final barWidth = ((groupWidth * 0.24).clamp(8.0, 20.0) as num).toDouble();
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, chartBottom), Offset(size.width, chartBottom), axisPaint);
    for (var i = 1; i <= 3; i += 1) {
      final y = chartTop + chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint..color = axisColor.withOpacity(0.35));
    }

    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final center = groupWidth * index + groupWidth / 2;
      _drawBar(canvas, center - barWidth * 0.6, chartBottom, barWidth, _height(point.sales, maxValue, chartHeight), salesColor);
      _drawBar(canvas, center + barWidth * 0.6, chartBottom, barWidth, _height(point.expenses, maxValue, chartHeight), expensesColor);

      final label = point.label.split(" ").first;
      final painter = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w700)),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: groupWidth);
      painter.paint(canvas, Offset(center - painter.width / 2, chartBottom + 8));
    }
  }

  double _height(double value, double maxValue, double chartHeight) {
    if (maxValue <= 0) return 0;
    return ((value / maxValue * (chartHeight - 12)).clamp(0, chartHeight - 12) as num).toDouble();
  }

  void _drawBar(Canvas canvas, double centerX, double bottom, double width, double height, Color color) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - width / 2, bottom - height, width, height),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MonthlyChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.salesColor != salesColor ||
        oldDelegate.expensesColor != expensesColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.textDirection != textDirection;
  }
}

String _label(bool isAr, String en, String ar) => isAr ? ar : en;
