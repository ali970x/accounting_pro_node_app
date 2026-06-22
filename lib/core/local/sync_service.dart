import "../api_client.dart";
import "local_store.dart";

class SyncResult {
  final bool success;
  final String message;
  final int products;
  final int sales;
  final int expenses;
  final int debts;
  final int contacts;
  final String? serverTime;

  const SyncResult({
    required this.success,
    required this.message,
    required this.products,
    required this.sales,
    required this.expenses,
    required this.debts,
    required this.contacts,
    required this.serverTime,
  });
}

class SyncService {
  final ApiClient api;
  final LocalStore store;

  SyncService({
    required this.api,
    required this.store,
  });

  Future<SyncResult> pull({bool fullRefresh = false}) async {
    if (fullRefresh) {
      await store.clearLastSyncAt();
    }

    final lastSyncAt = await store.getLastSyncAt();

    final path = lastSyncAt == null || lastSyncAt.isEmpty
        ? "/sync/pull"
        : "/sync/pull?since=${Uri.encodeComponent(lastSyncAt)}";

    final data = await api.get(path);

    final remoteProducts = _list(data["products"]);
    final remoteSales = _list(data["sales"]);
    final remoteExpenses = _list(data["expenses"]);
    final remoteDebts = _list(data["debts"]);
    final remoteContacts = _list(data["contacts"]);

    final localProducts = await store.getList(LocalStore.productsKey);
    final localSales = await store.getList(LocalStore.salesKey);
    final localExpenses = await store.getList(LocalStore.expensesKey);
    final localDebts = await store.getList(LocalStore.debtsKey);
    final localContacts = await store.getList(LocalStore.contactsKey);

    await store.saveList(
      LocalStore.productsKey,
      store.mergeById(local: localProducts, remote: remoteProducts),
    );

    await store.saveList(
      LocalStore.salesKey,
      store.mergeById(local: localSales, remote: remoteSales),
    );

    await store.saveList(
      LocalStore.expensesKey,
      store.mergeById(local: localExpenses, remote: remoteExpenses),
    );

    await store.saveList(
      LocalStore.debtsKey,
      store.mergeById(local: localDebts, remote: remoteDebts),
    );

    await store.saveList(
      LocalStore.contactsKey,
      store.mergeById(local: localContacts, remote: remoteContacts),
    );

    final settings = data["settings"];
    if (settings is Map) {
      await store.saveMap(LocalStore.settingsKey, Map<String, dynamic>.from(settings));
    }

    final invoiceTemplate = data["invoiceTemplate"];
    if (invoiceTemplate is Map) {
      await store.saveMap(
        LocalStore.invoiceTemplateKey,
        Map<String, dynamic>.from(invoiceTemplate),
      );
    }

    final serverTime = data["serverTime"]?.toString();

    if (serverTime != null && serverTime.isNotEmpty) {
      await store.saveLastSyncAt(serverTime);
    }

    return SyncResult(
      success: true,
      message: "Pull completed",
      products: remoteProducts.length,
      sales: remoteSales.length,
      expenses: remoteExpenses.length,
      debts: remoteDebts.length,
      contacts: remoteContacts.length,
      serverTime: serverTime,
    );
  }

  Future<SyncResult> push() async {
    final products = await store.getList(LocalStore.pendingProductsKey);
    final sales = await store.getList(LocalStore.pendingSalesKey);
    final expenses = await store.getList(LocalStore.pendingExpensesKey);
    final debts = await store.getList(LocalStore.pendingDebtsKey);
    final contacts = await store.getList(LocalStore.pendingContactsKey);

    final pendingTotal =
        products.length + sales.length + expenses.length + debts.length + contacts.length;

    if (pendingTotal == 0) {
      return const SyncResult(
        success: true,
        message: "No pending changes",
        products: 0,
        sales: 0,
        expenses: 0,
        debts: 0,
        contacts: 0,
        serverTime: null,
      );
    }

    final data = await api.post("/sync/push", {
      "products": products,
      "sales": sales,
      "expenses": expenses,
      "debts": debts,
      "contacts": contacts,
    });

    await store.clearPending();

    final serverTime = data["serverTime"]?.toString();

    if (serverTime != null && serverTime.isNotEmpty) {
      await store.saveLastSyncAt(serverTime);
    }

    await pull();

    return SyncResult(
      success: true,
      message: "Push completed",
      products: products.length,
      sales: sales.length,
      expenses: expenses.length,
      debts: debts.length,
      contacts: contacts.length,
      serverTime: serverTime,
    );
  }

  Future<SyncResult> syncNow() async {
    await push();
    return pull();
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
