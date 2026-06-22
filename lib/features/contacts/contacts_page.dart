import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../models/contact.dart";
import "../../widgets/modern_card.dart";

class ContactsPage extends StatefulWidget {
  final ApiClient api;

  const ContactsPage({
    super.key,
    required this.api,
  });

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _loading = true;
  String? _error;
  List<ContactModel> _contacts = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.api.get("/contacts");
      _contacts = (data as List)
          .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  List<ContactModel> _filtered(String type) {
    final q = _search.text.trim().toLowerCase();
    return _contacts.where((c) {
      final matchType = c.type == type;
      final matchSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.address.toLowerCase().contains(q);
      return matchType && matchSearch;
    }).toList();
  }

  Future<void> _addOrEdit({ContactModel? contact, required String type}) async {
    final body = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ContactDialog",
      pageBuilder: (context, _, __) => ContactDialog(contact: contact, type: type),
    );

    if (body == null) return;

    try {
      if (contact == null) {
        await widget.api.post("/contacts", body);
      } else {
        await widget.api.put("/contacts/${contact.id}", body);
      }
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
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Builder(
          builder: (context) {
            final tab = DefaultTabController.of(context).index;
            final type = tab == 0 ? "supplier" : "customer";
            return FloatingActionButton.extended(
              onPressed: () => _addOrEdit(type: type),
              icon: const Icon(Icons.person_add_rounded),
              label: Text(c.isArabic ? (type == "supplier" ? "إضافة مورد" : "إضافة زبون") : "Add"),
            );
          },
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.t("contacts"),
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: c.isArabic ? "بحث بالاسم أو الرقم..." : "Search...",
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModernCard(
                    padding: const EdgeInsets.all(6),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: theme.colorScheme.onPrimary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      tabs: [
                        Tab(text: c.isArabic ? "الموردين" : "Suppliers"),
                        Tab(text: c.isArabic ? "الزباين" : "Customers"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          children: [
                            _ContactListView(
                              contacts: _filtered("supplier"),
                              onEdit: (m) => _addOrEdit(contact: m, type: "supplier"),
                              onDelete: (m) => _delete(m),
                            ),
                            _ContactListView(
                              contacts: _filtered("customer"),
                              onEdit: (m) => _addOrEdit(contact: m, type: "customer"),
                              onDelete: (m) => _delete(m),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(ContactModel contact) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
        content: Text(AppScope.of(context).isArabic ? "هل أنت متأكد من حذف هذا الاسم؟" : "Delete this contact?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppScope.of(context).t("cancel"))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppScope.of(context).t("delete"))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.delete("/contacts/${contact.id}");
      await _load();
    } catch (e) {
      _showError(e);
    }
  }
}

class _ContactListView extends StatelessWidget {
  final List<ContactModel> contacts;
  final Function(ContactModel) onEdit;
  final Function(ContactModel) onDelete;

  const _ContactListView({
    required this.contacts,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(AppScope.of(context).t("empty"), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: contacts.length,
      itemBuilder: (_, i) {
        final m = contacts[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            onTap: () => onEdit(m),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(m.type == "supplier" ? Icons.local_shipping_rounded : Icons.person_rounded),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(m.fullPhone, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      if (m.address.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(m.address, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onDelete(m),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ContactDialog extends StatefulWidget {
  final ContactModel? contact;
  final String type;

  const ContactDialog({
    super.key,
    required this.contact,
    required this.type,
  });

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<ContactDialog> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController note;
  String countryCode = "+961";

  @override
  void initState() {
    super.initState();
    final x = widget.contact;
    name = TextEditingController(text: x?.name ?? "");
    phone = TextEditingController(text: x?.phone ?? "");
    address = TextEditingController(text: x?.address ?? "");
    note = TextEditingController(text: x?.note ?? "");
    countryCode = x?.countryCode ?? "+961";
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.contact == null
                    ? (isAr ? (widget.type == "supplier" ? "إضافة مورد جديد" : "إضافة زبون جديد") : "Add Contact")
                    : (isAr ? "تعديل البيانات" : "Edit Contact"),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 45,
                child: Icon(widget.type == "supplier" ? Icons.local_shipping_rounded : Icons.person_rounded, size: 34),
              ),
              const SizedBox(height: 16),
              _field(isAr ? "الاسم" : "Name", name, icon: Icons.person_rounded),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: countryCode,
                      decoration: _inputDeco(isAr ? "الرمز" : "Code"),
                      items: ["+961", "+966", "+971", "+965", "+962", "+20"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => countryCode = v ?? "+961"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _field(isAr ? "رقم الهاتف" : "Phone", phone, icon: Icons.phone_rounded, type: TextInputType.phone)),
                ],
              ),
              const SizedBox(height: 12),
              _field(isAr ? "العنوان" : "Address", address, icon: Icons.location_on_rounded),
              const SizedBox(height: 12),
              _field(isAr ? "ملاحظة" : "Note", note, icon: Icons.notes_rounded, lines: 3),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel")))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (name.text.trim().isEmpty) return;
                        Navigator.pop(context, {
                          "name": name.text.trim(),
                          "phone": phone.text.trim(),
                          "countryCode": countryCode,
                          "imageUrl": "",
                          "address": address.text.trim(),
                          "note": note.text.trim(),
                          "type": widget.type,
                        });
                      },
                      child: Text(c.t("save")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _field(String label, TextEditingController controller, {IconData? icon, int lines = 1, TextInputType? type}) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: type,
      decoration: _inputDeco(label, icon: icon),
      onChanged: (_) {},
    );
  }
}

