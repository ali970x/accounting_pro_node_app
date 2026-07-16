import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "../../core/api_client.dart";
import "../../core/session_store.dart";
import "../../core/app_controller.dart";
import "../../core/local/local_store.dart";
import "../../core/local/sync_service.dart";
import "../../core/smart_import_inbox.dart";
import "../auth/login_page.dart";
import "../damaged/damaged_goods_page.dart";
import "../inventory/inventory_page.dart";
import "../sales/sales_page.dart";
import "../invoice_template/invoice_template_page.dart";
import "../reports/reports_page.dart";
import "../records/records_page.dart";
import "../smart_import/smart_import_page.dart";
import "../contacts/contacts_page.dart";
import "../debts/debts_page.dart";
import "../expenses/expenses_page.dart";
import "../settings/settings_page.dart";
import "../about/about_page.dart";
import "../help/help_page.dart";

class HomePage extends StatefulWidget {
  final ApiClient api;
  final SessionStore sessionStore;

  const HomePage({super.key, required this.api, required this.sessionStore});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selected = 0;

  @override
  void initState() {
    super.initState();
    SmartImportInbox.text.addListener(_openSmartImportInbox);
    SmartImportInbox.clipboardRequests.addListener(_handleClipboardRequest);
    Future.microtask(() {
      if (!mounted) return;
      AppScope.of(context).loadSettings();
      _autoSync();
    });
  }

  @override
  void dispose() {
    SmartImportInbox.text.removeListener(_openSmartImportInbox);
    SmartImportInbox.clipboardRequests.removeListener(_handleClipboardRequest);
    super.dispose();
  }

  void _openSmartImportInbox() {
    if (!mounted || SmartImportInbox.text.value == null) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Smart Import is coming soon on web.")),
      );
      return;
    }
    setState(() => selected = 6);
  }

  void _handleClipboardRequest() {
    _pasteClipboardToSmartImport();
  }

  Future<void> _pasteClipboardToSmartImport() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? "").trim();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Clipboard is empty.")));
      return;
    }
    SmartImportInbox.put(text);
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Smart Import is coming soon on web.")),
      );
      return;
    }
    if (mounted) setState(() => selected = 6);
  }

  Future<void> _autoSync() async {
    try {
      await SyncService(api: widget.api, store: LocalStore()).syncNow();
    } catch (_) {
      // Silent background sync keeps the app usable when the network is unavailable.
    }
  }

  Future<void> logout() async {
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

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);

    final labels = [
      c.t("inventory"),
      c.t("damagedGoods"),
      c.t("sales"),
      c.t("invoiceTemplate"),
      c.t("reports"),
      c.t("records"),
      c.t("smartImport"),
      c.t("expenses"),
      c.t("debts"),
      c.t("contacts"),
      c.isArabic ? "دليل الاستخدام" : "User Guide",
      c.t("about"),
      c.t("settings"),
    ];

    final icons = const [
      Icons.inventory_2,
      Icons.report_problem_rounded,
      Icons.point_of_sale,
      Icons.receipt_long,
      Icons.analytics,
      Icons.history,
      Icons.auto_awesome_rounded,
      Icons.payments,
      Icons.account_balance,
      Icons.people_alt,
      Icons.help_outline_rounded,
      Icons.info,
      Icons.settings,
    ];

    final wide = MediaQuery.of(context).size.width >= 950;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(labels[selected]),
        actions: [
          IconButton(
            onPressed: logout,
            tooltip: c.t("logout"),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: labels.length,
                  itemBuilder: (_, i) => ListTile(
                    selected: selected == i,
                    leading: Icon(icons[i]),
                    title: Text(labels[i]),
                    onTap: () {
                      setState(() => selected = i);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 250,
                backgroundColor: Colors.transparent,
                selectedIconTheme: IconThemeData(
                  color: theme.colorScheme.onPrimary,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
                indicatorColor: theme.colorScheme.primary,
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: [
                  for (int i = 0; i < labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? const [
                          Color(0xFF10131A),
                          Color(0xFF151B2D),
                          Color(0xFF102622),
                        ]
                      : const [
                          Color(0xFFF4F7FB),
                          Color(0xFFEFF6FF),
                          Color(0xFFEAFBF8),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: _pageFor(selected),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: theme.colorScheme.surface,
              indicatorColor: theme.colorScheme.primaryContainer,
              selectedIndex: _bottomSelectedIndex(),
              onDestinationSelected: (i) =>
                  setState(() => selected = _pageIndexForBottom(i)),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2),
                  label: c.t("inventory"),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.report_problem_rounded),
                  label: c.t("damagedGoods"),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.point_of_sale),
                  label: c.t("sales"),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.analytics),
                  label: c.t("reports"),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz),
                  label: c.t("records"),
                ),
              ],
            ),
    );
  }

  Widget _pageFor(int index) {
    return switch (index) {
      0 => InventoryPage(api: widget.api),
      1 => DamagedGoodsPage(api: widget.api),
      2 => SalesPage(api: widget.api),
      3 => InvoiceTemplatePage(api: widget.api),
      4 => ReportsPage(
        api: widget.api,
        onOpenExpenses: () => setState(() => selected = 7),
        onOpenRecords: () => setState(() => selected = 5),
        onOpenDamages: () => setState(() => selected = 1),
      ),
      5 => RecordsPage(api: widget.api),
      6 =>
        kIsWeb
            ? const _SmartImportLockedPage()
            : SmartImportPage(api: widget.api),
      7 => ExpensesPage(api: widget.api),
      8 => DebtsPage(api: widget.api),
      9 => ContactsPage(api: widget.api),
      10 => const HelpPage(),
      11 => AboutPage(api: widget.api),
      _ => SettingsPage(api: widget.api),
    };
  }

  int _bottomSelectedIndex() {
    return switch (selected) {
      0 => 0,
      1 => 1,
      2 => 2,
      4 => 3,
      _ => 4,
    };
  }

  int _pageIndexForBottom(int index) {
    return switch (index) {
      0 => 0,
      1 => 1,
      2 => 2,
      3 => 4,
      _ => 5,
    };
  }
}

class _SmartImportLockedPage extends StatelessWidget {
  const _SmartImportLockedPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? scheme.surfaceContainerLow
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 36,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Smart Import",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Coming soon on web",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "This feature is locked here for now. Use the mobile app for Smart Import while the web version is being finished.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
