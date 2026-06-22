import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

class LocalStore {
  static const productsKey = "local_products";
  static const salesKey = "local_sales";
  static const expensesKey = "local_expenses";
  static const debtsKey = "local_debts";
  static const contactsKey = "local_contacts";
  static const settingsKey = "local_settings";
  static const invoiceTemplateKey = "local_invoice_template";

  static const pendingProductsKey = "pending_products";
  static const pendingSalesKey = "pending_sales";
  static const pendingExpensesKey = "pending_expenses";
  static const pendingDebtsKey = "pending_debts";
  static const pendingContactsKey = "pending_contacts";

  static const lastSyncAtKey = "last_sync_at";

  Future<List<Map<String, dynamic>>> getList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);

    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveList(String key, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(rows));
  }

  Future<Map<String, dynamic>> getMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw);

    if (decoded is! Map) return {};

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> saveMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<String?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastSyncAtKey);
  }

  Future<void> saveLastSyncAt(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastSyncAtKey, value);
  }

  Future<void> clearLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(lastSyncAtKey);
  }

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(productsKey);
    await prefs.remove(salesKey);
    await prefs.remove(expensesKey);
    await prefs.remove(debtsKey);
    await prefs.remove(contactsKey);
    await prefs.remove(settingsKey);
    await prefs.remove(invoiceTemplateKey);

    await prefs.remove(pendingProductsKey);
    await prefs.remove(pendingSalesKey);
    await prefs.remove(pendingExpensesKey);
    await prefs.remove(pendingDebtsKey);
    await prefs.remove(pendingContactsKey);

    await prefs.remove(lastSyncAtKey);
  }

  Future<void> queuePending(String key, Map<String, dynamic> row) async {
    final rows = await getList(key);
    rows.add(row);
    await saveList(key, rows);
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(pendingProductsKey);
    await prefs.remove(pendingSalesKey);
    await prefs.remove(pendingExpensesKey);
    await prefs.remove(pendingDebtsKey);
    await prefs.remove(pendingContactsKey);
  }

  Future<int> pendingCount() async {
    final products = await getList(pendingProductsKey);
    final sales = await getList(pendingSalesKey);
    final expenses = await getList(pendingExpensesKey);
    final debts = await getList(pendingDebtsKey);
    final contacts = await getList(pendingContactsKey);

    return products.length + sales.length + expenses.length + debts.length + contacts.length;
  }

  List<Map<String, dynamic>> mergeById({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
  }) {
    final map = <String, Map<String, dynamic>>{};

    for (final item in local) {
      final id = _itemKey(item);
      if (id.isNotEmpty) {
        map[id] = item;
      }
    }

    for (final item in remote) {
      final id = _itemKey(item);
      if (id.isEmpty) continue;

      if (item["isDeleted"] == true) {
        map.remove(id);
      } else {
        map[id] = item;
      }
    }

    final rows = map.values.toList();

    rows.sort((a, b) {
      final au = (a["updatedAt"] ?? a["createdAt"] ?? "").toString();
      final bu = (b["updatedAt"] ?? b["createdAt"] ?? "").toString();
      return bu.compareTo(au);
    });

    return rows;
  }

  String _itemKey(Map<String, dynamic> item) {
    final id = (item["_id"] ?? item["id"] ?? "").toString();
    if (id.isNotEmpty) return id;

    final clientId = (item["clientId"] ?? "").toString();
    if (clientId.isNotEmpty) return clientId;

    return "";
  }
}
