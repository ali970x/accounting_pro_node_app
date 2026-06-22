import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/session_store.dart";
import "../../core/app_controller.dart";
import "../auth/login_page.dart";
import "../inventory/inventory_page.dart";
import "../sales/sales_page.dart";
import "../invoice_template/invoice_template_page.dart";
import "../reports/reports_page.dart";
import "../records/records_page.dart";
import "../contacts/contacts_page.dart";
import "../debts/debts_page.dart";
import "../expenses/expenses_page.dart";
import "../sync/sync_page.dart";
import "../settings/settings_page.dart";
import "../about/about_page.dart";

class HomePage extends StatefulWidget {
  final ApiClient api;
  final SessionStore sessionStore;

  const HomePage({
    super.key,
    required this.api,
    required this.sessionStore,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selected = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      AppScope.of(context).loadSettings();
    });
  }

  Future<void> logout() async {
    await widget.sessionStore.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(api: widget.api, sessionStore: widget.sessionStore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);

    final labels = [
      c.t("inventory"),
      c.t("sales"),
      c.t("invoiceTemplate"),
      c.t("reports"),
      c.t("records"),
      c.isArabic ? "المزامنة" : "Sync",
      c.t("expenses"),
      c.t("debts"),
      c.t("contacts"),
      c.t("about"),
      c.t("settings"),
    ];

    final icons = const [
      Icons.inventory_2,
      Icons.point_of_sale,
      Icons.receipt_long,
      Icons.analytics,
      Icons.history,
      Icons.sync,
      Icons.payments,
      Icons.account_balance,
      Icons.people_alt,
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
                border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 250,
                backgroundColor: Colors.transparent,
                selectedIconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
                selectedLabelTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
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
                      ? const [Color(0xFF10131A), Color(0xFF151B2D), Color(0xFF102622)]
                      : const [Color(0xFFF4F7FB), Color(0xFFEFF6FF), Color(0xFFEAFBF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IndexedStack(
                index: selected,
                children: [
                  InventoryPage(api: widget.api),
                  SalesPage(api: widget.api),
                  InvoiceTemplatePage(api: widget.api),
                  ReportsPage(api: widget.api),
                  RecordsPage(api: widget.api),
                  SyncPage(api: widget.api),
                  ExpensesPage(api: widget.api),
                  DebtsPage(api: widget.api),
                  ContactsPage(api: widget.api),
                  AboutPage(api: widget.api),
                  SettingsPage(api: widget.api),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: theme.colorScheme.surface,
              indicatorColor: theme.colorScheme.primaryContainer,
              selectedIndex: selected > 4 ? 4 : selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: [
                NavigationDestination(icon: const Icon(Icons.inventory_2), label: c.t("inventory")),
                NavigationDestination(icon: const Icon(Icons.point_of_sale), label: c.t("sales")),
                NavigationDestination(icon: const Icon(Icons.receipt_long), label: c.t("invoiceTemplate")),
                NavigationDestination(icon: const Icon(Icons.analytics), label: c.t("reports")),
                NavigationDestination(icon: const Icon(Icons.more_horiz), label: c.t("records")),
              ],
            ),
    );
  }
}
