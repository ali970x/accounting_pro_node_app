import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../models/app_record.dart";
import "../../widgets/date_filter_bar.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class RecordsPage extends StatefulWidget {
  final ApiClient api;
  const RecordsPage({super.key, required this.api});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool loading = true;
  String? error;
  List<AppRecord> movements = [];
  DateFilterValue _dateFilter = const DateFilterValue(preset: DateFilterPreset.month);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final m = await widget.api.get("/records/stock-movements");
      movements = (m as List).map((e) => AppRecord.fromMovement(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final filteredMovements = movements.where((r) => _dateFilter.includes(r.createdAt)).toList();
    final customerRows = filteredMovements.where((r) => r.type == "sale" || r.type == "return").toList();
    final supplierRows = filteredMovements.where((r) => r.type == "purchase").toList();

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(title: isAr ? "\u0627\u0644\u0633\u062c\u0644\u0627\u062a" : "Records"),
            const SizedBox(height: 12),
            DateFilterBar(
              isArabic: isAr,
              value: _dateFilter,
              onChanged: (value) => setState(() => _dateFilter = value),
            ),
            const SizedBox(height: 12),
            ModernCard(
              padding: const EdgeInsets.all(8),
              child: TabBar(
                tabs: [
                  Tab(icon: const Icon(Icons.people_alt_rounded), text: isAr ? "\u0627\u0644\u0632\u0628\u0627\u0626\u0646" : "Customers"),
                  Tab(icon: const Icon(Icons.local_shipping_rounded), text: isAr ? "\u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646" : "Suppliers"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!))
                      : TabBarView(
                          children: [
                            RefreshIndicator(onRefresh: load, child: _recordsList(customerRows, _customerTile)),
                            RefreshIndicator(onRefresh: load, child: _recordsList(supplierRows, _supplierTile)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsList(List<AppRecord> rows, Widget Function(AppRecord) builder) {
    final c = AppScope.of(context);
    if (rows.isEmpty) {
      return ListView(children: [ModernCard(child: Text(c.t("empty")))]);
    }

    return ListView(
      children: rows.map((x) => Padding(padding: const EdgeInsets.only(bottom: 10), child: builder(x))).toList(),
    );
  }

  Widget _customerTile(AppRecord row) {
    final isAr = AppScope.of(context).isArabic;
    final isReturn = row.type == "return";
    final color = isReturn ? Colors.orange : Colors.blue;
    final qty = number(row.difference.abs());
    final customer = row.customerName.isEmpty ? _label(isAr, "Walk-in", "\u0632\u0628\u0648\u0646 \u0645\u0628\u0627\u0634\u0631") : row.customerName;
    final details = <String>[
      "${_label(isAr, "Customer", "\u0627\u0644\u0632\u0628\u0648\u0646")}: $customer",
      "${_label(isAr, "Quantity", "\u0627\u0644\u0643\u0645\u064a\u0629")}: $qty",
      if (row.packageCount > 0) "${_label(isAr, "Packages", "\u0627\u0644\u0637\u0631\u0648\u062f")}: ${number(row.packageCount)}",
      if (row.weight > 0) "${_label(isAr, "Weight", "\u0627\u0644\u0648\u0632\u0646")}: ${number(row.weight)} ${_label(isAr, "kg", "\u0643\u063a")}",
      if (row.totalCost > 0) "${_label(isAr, "Total", "\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a")}: ${money(row.totalCost, row.currency)}",
      if (row.paymentStatus == "paid") _label(isAr, "Paid", "\u0645\u062f\u0641\u0648\u0639"),
      if (row.paymentStatus == "debt") _label(isAr, "Customer debt", "\u062f\u064a\u0646 \u0639\u0644\u0649 \u0627\u0644\u0632\u0628\u0648\u0646"),
      if (row.invoiceNo.isNotEmpty) "${_label(isAr, "Invoice", "\u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629")}: ${row.invoiceNo}",
    ];

    return ModernCard(
      child: ListTile(
        leading: Icon(isReturn ? Icons.keyboard_return_rounded : Icons.point_of_sale_rounded, color: color),
        title: Text(row.productName, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text("${_formatTime(row.createdAt)}\n${details.join("\n")}"),
        trailing: Icon(isReturn ? Icons.north_west_rounded : Icons.south_east_rounded, color: color),
      ),
    );
  }

  Widget _supplierTile(AppRecord row) {
    final isAr = AppScope.of(context).isArabic;
    final details = <String>[
      "${_label(isAr, "Quantity", "\u0627\u0644\u0643\u0645\u064a\u0629")}: ${number(row.difference)}",
      if (row.packageCount > 0) "${_label(isAr, "Packages", "\u0627\u0644\u0637\u0631\u0648\u062f")}: ${number(row.packageCount)}",
      if (row.weight > 0) "${_label(isAr, "Weight", "\u0627\u0644\u0648\u0632\u0646")}: ${number(row.weight)} ${_label(isAr, "kg", "\u0643\u063a")}",
      if (row.supplierName.isNotEmpty) "${_label(isAr, "Supplier", "\u0627\u0644\u0645\u0648\u0631\u062f")}: ${row.supplierName}",
      if (row.totalCost > 0) "${_label(isAr, "Total", "\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a")}: ${money(row.totalCost, row.currency)}",
      if (row.paymentStatus == "paid") _label(isAr, "Paid", "\u0645\u062f\u0641\u0648\u0639"),
      if (row.paymentStatus == "debt") _label(isAr, "Supplier debt", "\u062f\u064a\u0646 \u0639\u0644\u0649 \u0627\u0644\u0645\u0648\u0631\u062f"),
      if (row.invoiceNo.isNotEmpty) "${_label(isAr, "Invoice", "\u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629")}: ${row.invoiceNo}",
      if (row.reason.isNotEmpty) row.reason,
    ];

    return ModernCard(
      child: ListTile(
        leading: const Icon(Icons.local_shipping_rounded, color: Colors.green),
        title: Text(row.productName, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text("${_formatTime(row.createdAt)}\n${details.join("\n")}"),
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return "-";
    final y = value.year.toString().padLeft(4, "0");
    final m = value.month.toString().padLeft(2, "0");
    final d = value.day.toString().padLeft(2, "0");
    final h = value.hour.toString().padLeft(2, "0");
    final min = value.minute.toString().padLeft(2, "0");
    return "$y-$m-$d $h:$min";
  }

  String _label(bool isAr, String en, String ar) => isAr ? ar : en;
}
