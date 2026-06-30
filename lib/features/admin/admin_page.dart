import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/money.dart";
import "../../core/session_store.dart";
import "../auth/login_page.dart";
import "../../widgets/modern_card.dart";

class AdminPage extends StatefulWidget {
  final ApiClient api;
  final SessionStore sessionStore;

  const AdminPage({super.key, required this.api, required this.sessionStore});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _selectedId;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _rows = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _error = null;
    }

    try {
      final data = Map<String, dynamic>.from(
        await widget.api.get("/admin/users") as Map,
      );
      _summary = _map(data["summary"]);
      _rows = _list(data["users"]).map((e) => _map(e)).toList();
      if (_rows.isNotEmpty) {
        final selectedStillExists = _rows.any(
          (row) => _user(row)["id"] == _selectedId,
        );
        _selectedId = selectedStillExists
            ? _selectedId
            : _user(_rows.first)["id"]?.toString();
      } else {
        _selectedId = null;
      }
    } catch (e) {
      _error = e.toString();
    }

    if (mounted && showLoading) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    await widget.sessionStore.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoginPage(api: widget.api, sessionStore: widget.sessionStore),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleRows {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((row) {
      final user = _user(row);
      final name = (user["name"] ?? "").toString().toLowerCase();
      final email = (user["email"] ?? "").toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Map<String, dynamic>? get _selectedRow {
    if (_selectedId == null) return null;
    for (final row in _rows) {
      if (_user(row)["id"]?.toString() == _selectedId) return row;
    }
    return _rows.isEmpty ? null : _rows.first;
  }

  Future<void> _openUserDialog({Map<String, dynamic>? row}) async {
    final editing = row != null;
    final user = editing ? _user(row) : <String, dynamic>{};
    final name = TextEditingController(text: (user["name"] ?? "").toString());
    final email = TextEditingController(text: (user["email"] ?? "").toString());
    final password = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing ? "Edit user" : "Create user"),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: editing ? "New password (optional)" : "Password",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final cleanName = name.text.trim();
              final cleanEmail = email.text.trim();
              final cleanPassword = password.text.trim();
              if (cleanName.isEmpty ||
                  cleanEmail.isEmpty ||
                  (!editing && cleanPassword.length < 6))
                return;
              Navigator.pop(ctx, {
                "name": cleanName,
                "email": cleanEmail,
                "password": cleanPassword,
              });
            },
            child: Text(editing ? "Save" : "Create"),
          ),
        ],
      ),
    );

    name.dispose();
    email.dispose();
    password.dispose();
    if (result == null) return;

    await _runAction(() async {
      if (editing) {
        await widget.api.put("/admin/users/${user["id"]}", {
          "name": result["name"],
          "email": result["email"],
          if ((result["password"] ?? "").isNotEmpty)
            "password": result["password"],
        });
      } else {
        await widget.api.post("/admin/users", result);
      }
      await _load(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(editing ? "User updated." : "User created.")),
      );
    });
  }

  Future<void> _setStatus(Map<String, dynamic> row, bool isActive) async {
    final user = _user(row);
    String reason = "";
    if (!isActive) {
      final reasonController = TextEditingController(text: "Blocked by admin");
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Block user"),
          content: TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: "Reason"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
              child: const Text("Block"),
            ),
          ],
        ),
      );
      reasonController.dispose();
      if (result == null) return;
      reason = result.isEmpty ? "Blocked by admin" : result;
    }

    await _runAction(() async {
      final raw = await widget.api.put("/admin/users/${user["id"]}/status", {
        "isActive": isActive,
        "reason": reason,
      });
      final response = Map<String, dynamic>.from(raw as Map);
      await _load();
      if (!mounted) return;
      final sent = response["emailSent"] == true;
      final message = isActive
          ? sent
                ? "User activated and email sent."
                : "User activated. SMTP is not configured, so email was not sent."
          : sent
          ? "User blocked and reason email sent."
          : "User blocked. SMTP is not configured, so reason email was not sent.";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _deleteUser(Map<String, dynamic> row) async {
    final user = _user(row);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete user"),
        content: Text(
          "This will permanently delete ${user["name"] ?? "this user"} and all related products, sales, expenses, debts, contacts, records, and feedback. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete permanently"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _runAction(() async {
      await widget.api.delete("/admin/users/${user["id"]}");
      _selectedId = null;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User and related data deleted.")),
      );
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                "assets/brand/daftr_logo.jpeg",
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text("daftr Admin", overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _working ? null : _load,
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _working ? null : _logout,
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [
                    Color(0xFF10131A),
                    Color(0xFF12231F),
                    Color(0xFF151B2D),
                  ]
                : const [
                    Color(0xFFF4F7FB),
                    Color(0xFFEAFBF8),
                    Color(0xFFEFF6FF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: ModernCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 420, child: _usersPanel()),
                          const SizedBox(width: 16),
                          Expanded(child: _detailsPanel()),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _usersPanel(shrink: true),
                      const SizedBox(height: 14),
                      _detailsPanel(shrink: true),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _working ? null : () => _openUserDialog(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text("Create user"),
      ),
    );
  }

  Widget _usersPanel({bool shrink = false}) {
    final visibleRows = _visibleRows;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryWrap(),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: "Search users",
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visibleRows.isEmpty
              ? const Center(child: Text("No users found."))
              : ListView.separated(
                  itemCount: visibleRows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _userTile(visibleRows[index]),
                ),
        ),
      ],
    );

    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: shrink ? SizedBox(height: 620, child: content) : content,
    );
  }

  Widget _summaryWrap() {
    final total = _num(_summary["totalUsers"]);
    final active = _num(_summary["activeUsers"]);
    final blocked = _num(_summary["blockedUsers"]);
    final admins = _num(_summary["admins"]);
    final feedback = _num(_summary["pendingFeedback"]);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chipStat(
          "Users",
          number(total),
          Icons.people_alt_rounded,
          const Color(0xFF0F766E),
        ),
        _chipStat(
          "Active",
          number(active),
          Icons.verified_user_rounded,
          const Color(0xFF2563EB),
        ),
        _chipStat(
          "Blocked",
          number(blocked),
          Icons.block_rounded,
          const Color(0xFFDC2626),
        ),
        _chipStat(
          "Admins",
          number(admins),
          Icons.admin_panel_settings_rounded,
          const Color(0xFF7C3AED),
        ),
        _chipStat(
          "New reviews",
          number(feedback),
          Icons.rate_review_rounded,
          const Color(0xFFB45309),
        ),
      ],
    );
  }

  Widget _chipStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> row) {
    final user = _user(row);
    final stats = _stats(row);
    final counts = _map(stats["counts"]);
    final selected = user["id"]?.toString() == _selectedId;
    final active = user["isActive"] != false;
    final isAdmin = user["role"] == "admin";
    final color = active ? const Color(0xFF0F766E) : const Color(0xFFDC2626);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedId = user["id"]?.toString()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.14),
                  child: Icon(
                    isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.person_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user["name"] ?? "User").toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        (user["email"] ?? "").toString(),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _statusPill(active ? "Active" : "Blocked", color),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tinyMetric("Products", counts["products"]),
                _tinyMetric("Sales", counts["sales"]),
                _tinyMetric("Debts", counts["openDebts"]),
                _tinyMetric("Contacts", counts["contacts"]),
                _tinyMetric("Reviews", counts["feedback"]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsPanel({bool shrink = false}) {
    final row = _selectedRow;
    if (row == null) {
      return const ModernCard(
        child: Center(child: Text("Create a user to see admin details.")),
      );
    }

    final content = SingleChildScrollView(child: _userDetails(row));

    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: shrink ? SizedBox(height: 760, child: content) : content,
    );
  }

  Widget _userDetails(Map<String, dynamic> row) {
    final user = _user(row);
    final stats = _stats(row);
    final counts = _map(stats["counts"]);
    final totals = _map(stats["totals"]);
    final sales = _map(totals["sales"]);
    final expenses = _map(totals["expenses"]);
    final openDebts = _map(totals["openDebts"]);
    final receivable = _map(openDebts["receivable"]);
    final payable = _map(openDebts["payable"]);
    final latest = _map(stats["latest"]);
    final active = user["isActive"] != false;
    final isAdmin = user["role"] == "admin";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.12),
              child: Icon(
                isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (user["name"] ?? "User").toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    (user["email"] ?? "").toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statusPill(
                        active ? "Active" : "Blocked",
                        active
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFDC2626),
                      ),
                      _statusPill(
                        (user["role"] ?? "owner").toString(),
                        const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _working ? null : () => _openUserDialog(row: row),
              icon: const Icon(Icons.edit_rounded),
              label: const Text("Edit"),
            ),
            if (!isAdmin)
              FilledButton.icon(
                onPressed: _working ? null : () => _setStatus(row, !active),
                icon: Icon(
                  active ? Icons.block_rounded : Icons.verified_user_rounded,
                ),
                label: Text(active ? "Block" : "Activate"),
              ),
            if (!isAdmin)
              OutlinedButton.icon(
                onPressed: _working ? null : () => _deleteUser(row),
                icon: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
                label: const Text("Delete user"),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricBox(
              "Products",
              counts["products"],
              Icons.inventory_2_rounded,
              const Color(0xFF0F766E),
            ),
            _metricBox(
              "Stock qty",
              stats["stockQuantity"],
              Icons.warehouse_rounded,
              const Color(0xFF2563EB),
            ),
            _metricBox(
              "Sales",
              counts["sales"],
              Icons.point_of_sale_rounded,
              const Color(0xFF7C3AED),
            ),
            _metricBox(
              "Expenses",
              counts["expenses"],
              Icons.payments_rounded,
              const Color(0xFFB45309),
            ),
            _metricBox(
              "Open debts",
              counts["openDebts"],
              Icons.account_balance_rounded,
              const Color(0xFFDC2626),
            ),
            _metricBox(
              "Low stock",
              counts["lowStock"],
              Icons.warning_amber_rounded,
              const Color(0xFFEA580C),
            ),
            _metricBox(
              "Reviews",
              counts["feedback"],
              Icons.rate_review_rounded,
              const Color(0xFFB45309),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle("Financial overview"),
        _moneyLine("Sales", sales),
        _moneyLine("Expenses", expenses),
        _moneyLine("Receivable debts", receivable),
        _moneyLine("Payable debts", payable),
        const Divider(height: 26),
        _metaLine("Created", _date(user["createdAt"])),
        _metaLine("Last login", _date(user["lastLoginAt"])),
        if (!active)
          _metaLine("Block reason", (user["blockedReason"] ?? "").toString()),
        const SizedBox(height: 18),
        _sectionTitle("Latest data"),
        _latestList(
          "Sales invoices",
          _list(latest["sales"]),
          (item) =>
              "${item["invoiceNo"] ?? ""} - ${item["customerName"] ?? ""}",
          (item) => money(
            _num(item["total"]),
            (item["currency"] ?? "LBP").toString(),
          ),
        ),
        _latestList(
          "Expenses",
          _list(latest["expenses"]),
          (item) => "${item["title"] ?? ""} - ${item["category"] ?? ""}",
          (item) => money(
            _num(item["amount"]),
            (item["currency"] ?? "LBP").toString(),
          ),
        ),
        _latestList(
          "Debts",
          _list(latest["debts"]),
          (item) => "${item["personName"] ?? ""} - ${item["status"] ?? ""}",
          (item) => money(
            _num(item["remainingAmount"]),
            (item["currency"] ?? "LBP").toString(),
          ),
        ),
        _latestList(
          "Products",
          _list(latest["products"]),
          (item) => "${item["category"] ?? ""}",
          (item) => "${item["name"] ?? ""}",
        ),
        _latestList(
          "Damaged goods",
          _list(latest["damages"]),
          (item) => "${item["productName"] ?? ""}",
          (item) => "Qty ${number(_num(item["difference"]).abs())}",
        ),
        _latestList(
          "Reviews",
          _list(latest["feedback"]),
          (item) =>
              "${item["name"] ?? "User"} - ${number(_num(item["rating"]))}/5",
          (item) => "${item["message"] ?? ""}",
        ),
      ],
    );
  }

  Widget _metricBox(String label, dynamic value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            number(_num(value)),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latestList(
    String title,
    List<dynamic> rows,
    String Function(Map<String, dynamic>) leading,
    String Function(Map<String, dynamic>) trailing,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text("No data.", style: Theme.of(context).textTheme.bodySmall)
          else
            for (final raw in rows.take(6))
              Builder(
                builder: (_) {
                  final item = _map(raw);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            leading(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          flex: 2,
                          child: Text(
                            trailing(item),
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _moneyLine(String label, Map<String, dynamic> totals) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            "${money(_num(totals["LBP"]), "LBP")} | ${money(_num(totals["USD"]), "USD")}",
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tinyMetric(String label, dynamic value) {
    return Text(
      "$label ${number(_num(value))}",
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Map<String, dynamic> _user(Map<String, dynamic> row) => _map(row["user"]);
  Map<String, dynamic> _stats(Map<String, dynamic> row) => _map(row["stats"]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<dynamic> _list(dynamic value) => value is List ? value : const [];

  num _num(dynamic value) {
    if (value is num) return value;
    return numFromDynamic(value);
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? "");
    if (parsed == null) return "-";
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, "0");
    final m = local.month.toString().padLeft(2, "0");
    final d = local.day.toString().padLeft(2, "0");
    final h = local.hour.toString().padLeft(2, "0");
    final min = local.minute.toString().padLeft(2, "0");
    return "$y-$m-$d $h:$min";
  }
}
