import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "package:flutter/services.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../core/phone_text.dart";
import "../../core/pdf/pdf_service.dart";
import "../../models/invoice_template.dart";
import "../../models/product.dart";
import "../../models/sale.dart";
import "../../models/contact.dart";
import "../../widgets/modern_card.dart";
import "../contacts/contacts_page.dart";

class SalesPage extends StatefulWidget {
  final ApiClient api;
  const SalesPage({super.key, required this.api});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  bool _loading = true;
  String? _error;
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<ContactModel> _customers = [];

  String? _selectedProductId;
  String? _selectedCustomerId;
  final _manualCustomerName = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _totalPrice = TextEditingController();

  bool _registerDebt = false;
  bool _showAllSales = false;
  _SaleProductChoice? _activeChoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _manualCustomerName.dispose();
    _customerFocusNode.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _totalPrice.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait([
        widget.api.get("/products"),
        widget.api.get("/sales"),
        widget.api.get("/contacts"),
      ]);

      final pData = data[0];
      _products = (pData as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      final sData = data[1];
      _sales = (sData as List).map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      final cData = data[2];
      _customers = (cData as List)
          .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.type == "customer")
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onProductSelected(String? id) {
    final choice = _firstSaleChoiceWhere((x) => x.id == id);
    setState(() {
      _selectedProductId = id;
      _activeChoice = choice;
      if (choice != null) {
        _unitPrice.text = choice.sellingPrice.toStringAsFixed(2);
        _updateTotal();
      }
    });
  }

  void _updateTotal() {
    final q = double.tryParse(_quantity.text) ?? 0;
    final p = double.tryParse(_unitPrice.text) ?? 0;
    _totalPrice.text = (q * p).toStringAsFixed(2);
  }

  void _updateUnitPrice() {
    final q = double.tryParse(_quantity.text) ?? 1;
    final t = double.tryParse(_totalPrice.text) ?? 0;
    if (q > 0) {
      _unitPrice.text = (t / q).toStringAsFixed(2);
    }
  }

  Future<void> _createNewContact() async {
    final body = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ContactDialog",
      pageBuilder: (context, _, __) => const ContactDialog(contact: null, type: "customer"),
    );
    if (body == null) return;
    try {
      await widget.api.post("/contacts", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editSale(Sale sale) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SaleEditDialog(sale: sale, customers: _customers),
    );
    if (body == null) return;
    try {
      await widget.api.put("/sales/${sale.id}", body);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    final isAr = AppScope.of(context).isArabic;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "حذف الفاتورة؟" : "Delete invoice?"),
        content: Text(isAr ? "سيتم إرجاع الكمية إلى المخزون وحذف دين الفاتورة إن وجد." : "Stock will be restored and related invoice debt will be removed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? "إلغاء" : "Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(isAr ? "حذف" : "Delete")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.delete("/sales/${sale.id}");
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteAllSales() async {
    final isAr = AppScope.of(context).isArabic;
    if (_sales.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "حذف كل الفواتير؟" : "Delete all invoices?"),
        content: Text(
          isAr
              ? "سيتم حذف كل فواتير المبيع، إرجاع كمياتها إلى المخزون، وحذف ديون الفواتير المرتبطة. لا تضغط حذف إلا إذا كنت متأكد."
              : "All sales invoices will be deleted, stock will be restored, and related invoice debts will be removed. Continue only if you are sure.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? "إلغاء" : "Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? "حذف الكل" : "Delete all"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.delete("/sales");
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createSale() async {
    if (_activeChoice == null) return _showError("Select product");
    final isAr = AppScope.of(context).isArabic;
    final q = double.tryParse(_quantity.text) ?? 0;
    final price = double.tryParse(_unitPrice.text) ?? 0;
    if (q <= 0) return _showError("Invalid quantity");

    final selectedCustomer = _firstCustomerWhere((x) => x.id == _selectedCustomerId);
    final typedCustomer = _manualCustomerName.text.trim();
    final selectedMatchesText = selectedCustomer != null && selectedCustomer.name == typedCustomer;
    final custName = typedCustomer.isEmpty ? (selectedCustomer?.name ?? "Walk-in") : typedCustomer;
    if (_registerDebt && !(selectedMatchesText && _selectedCustomerId != null)) {
      return _showError(isAr ? "اختار الزبون من القائمة قبل تسجيل الدين" : "Select the customer from the list before registering debt");
    }

    try {
      final created = await widget.api.post("/sales", {
        "customerName": custName,
        if (selectedMatchesText && _selectedCustomerId != null) "contact": _selectedCustomerId,
        "currency": _activeChoice!.currency,
        "paymentStatus": _registerDebt ? "debt" : "paid",
        "items": [
          {
            "productId": _activeChoice!.productId,
            if (_activeChoice!.variantId != null) "variantId": _activeChoice!.variantId,
            "quantity": q,
            "unitPrice": price,
          }
        ],
      });
      final sale = Sale.fromJson(Map<String, dynamic>.from(created as Map));
      _resetForm();
      await _load();
      if (!mounted) return;
      await _showSaleSharePrompt(sale);
    } catch (e) {
      _showError(e);
    }
  }

  void _resetForm() {
    _manualCustomerName.clear();
    _quantity.clear();
    _unitPrice.clear();
    _totalPrice.clear();
    _selectedProductId = null;
    _selectedCustomerId = null;
    _activeChoice = null;
    _registerDebt = false;
  }

  Future<void> _showSaleSharePrompt(Sale sale, {bool created = true}) async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final message = _saleMessage(sale, isAr);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(created ? (isAr ? "تم إنشاء الفاتورة" : "Invoice created") : (isAr ? "مشاركة الفاتورة" : "Share invoice")),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? "إغلاق" : "Close")),
          OutlinedButton.icon(
            onPressed: () async => Clipboard.setData(ClipboardData(text: message)),
            icon: const Icon(Icons.copy_rounded),
            label: Text(isAr ? "نسخ" : "Copy"),
          ),
          OutlinedButton.icon(
            onPressed: () => _printSale(sale),
            icon: const Icon(Icons.print_rounded),
            label: Text(isAr ? "طباعة" : "Print"),
          ),
          FilledButton.icon(
            onPressed: () => _shareSalePdf(sale),
            icon: const Icon(Icons.send_rounded),
            label: Text(isAr ? "مشاركة PDF" : "Share PDF"),
          ),
        ],
      ),
    );
  }

  String _saleMessage(Sale sale, bool isAr) {
    final lines = <String>[
      isAr ? "فاتورة مبيع" : "Sales Invoice",
      "${isAr ? "رقم الفاتورة" : "Invoice"}: ${sale.invoiceNo}",
      "${isAr ? "الزبون" : "Customer"}: ${sale.customerName}",
      "${isAr ? "المجموع" : "Total"}: ${money(sale.total, sale.currency)}",
      "${isAr ? "الحالة" : "Status"}: ${sale.paymentStatus == "debt" ? (isAr ? "دين" : "Debt") : (isAr ? "مدفوع" : "Paid")}",
      "",
    ];
    for (final item in sale.items) {
      lines.add("- ${item.productName}: ${item.quantity.toStringAsFixed(0)} x ${money(item.unitPrice, item.currency)} = ${money(item.total, item.currency)}");
    }
    return lines.join("\n");
  }

  Future<void> _printSale(Sale sale) async {
    final c = AppScope.of(context);
    final raw = await widget.api.get("/invoice-template");
    final template = InvoiceTemplateModel.fromJson(Map<String, dynamic>.from(raw as Map));
    await PdfService.printInvoice(languageCode: c.languageCode, sale: sale, template: template);
  }

  Future<void> _shareSalePdf(Sale sale) async {
    final c = AppScope.of(context);
    final raw = await widget.api.get("/invoice-template");
    final template = InvoiceTemplateModel.fromJson(Map<String, dynamic>.from(raw as Map));
    await PdfService.shareInvoice(languageCode: c.languageCode, sale: sale, template: template);
  }

  void _showError(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(c.t("sales"), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ModernCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.t("newSale"), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    TextButton.icon(onPressed: _createNewContact, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: Text(isAr ? "زبون جديد" : "New Customer")),
                  ],
                ),
                const SizedBox(height: 12),
                RawAutocomplete<ContactModel>(
                  textEditingController: _manualCustomerName,
                  focusNode: _customerFocusNode,
                  displayStringForOption: (customer) => customer.name,
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return _customers.take(8);
                    return _customers.where((customer) {
                      return customer.name.toLowerCase().contains(q) || customer.phone.contains(q);
                    }).take(8);
                  },
                  onSelected: (customer) {
                    setState(() {
                      _selectedCustomerId = customer.id;
                      _manualCustomerName.text = customer.name;
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: c.t("customerName"),
                        prefixIcon: const Icon(Icons.person_search_rounded),
                      ),
                      onChanged: (value) {
                        final selected = _firstCustomerWhere((x) => x.id == _selectedCustomerId);
                        if (selected != null && selected.name != value) {
                          setState(() => _selectedCustomerId = null);
                        }
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 520),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final customer = options.elementAt(index);
                              return ListTile(
                                leading: const Icon(Icons.person_rounded),
                                title: Text(customer.name),
                                subtitle: customer.phone.isEmpty ? null : PhoneText(customer.fullPhone),
                                onTap: () => onSelected(customer),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedProductId,
                  decoration: InputDecoration(labelText: c.t("selectProduct")),
                  items: _saleChoices().map((p) => DropdownMenuItem(value: p.id, child: Text(p.label))).toList(),
                  onChanged: _onProductSelected,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: c.t("quantity")),
                        onChanged: (_) => _updateTotal(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _unitPrice,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: _unitPriceLabel(isAr)),
                        onChanged: (_) => _updateTotal(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _totalPrice,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.blue),
                  decoration: InputDecoration(
                    labelText: isAr ? "إجمالي المبلغ المطلوب" : "Total Amount to Pay",
                    prefixIcon: const Icon(Icons.payments_rounded, color: Colors.blue),
                  ),
                  onChanged: (_) => _updateUnitPrice(),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _registerDebt,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(isAr ? "تسجيل الفاتورة كدين على الزبون" : "Register invoice as customer debt"),
                  subtitle: Text(isAr ? "الافتراضي مدفوع، فعّلها فقط إذا بقي المبلغ دين" : "Default is paid. Enable only when this remains unpaid."),
                  onChanged: (v) => setState(() => _registerDebt = v ?? false),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(onPressed: _createSale, icon: const Icon(Icons.point_of_sale), label: Text(c.t("createSale"), style: const TextStyle(fontWeight: FontWeight.bold))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _invoiceListCard(isAr),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _invoiceListCard(bool isAr) {
    final c = AppScope.of(context);
    final shownSales = _showAllSales ? _sales : _sales.take(5).toList();
    final hasMore = _sales.length > 5;

    return ModernCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_rounded)),
        title: Text(isAr ? "آخر الفواتير" : "Latest invoices", style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(isAr ? "${_sales.length} فاتورة محفوظة" : "${_sales.length} saved invoices"),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else if (_sales.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(c.t("empty")),
            )
          else ...[
            Row(
              children: [
                if (hasMore)
                  TextButton.icon(
                    onPressed: () => setState(() => _showAllSales = !_showAllSales),
                    icon: Icon(_showAllSales ? Icons.unfold_less_rounded : Icons.unfold_more_rounded),
                    label: Text(_showAllSales ? (isAr ? "عرض آخر 5" : "Show latest 5") : (isAr ? "عرض الكل" : "Show all")),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _deleteAllSales,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: Text(isAr ? "حذف الكل" : "Delete all"),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...shownSales.map((s) => _saleItem(s)),
          ],
        ],
      ),
    );
  }

  Widget _saleItem(Sale s) {
    final isAr = AppScope.of(context).isArabic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("${s.customerName}${s.paymentStatus == "debt" ? (isAr ? "\nدين" : "\nDebt") : ""}"),
          trailing: SizedBox(
            width: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    money(s.total, s.currency),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 15),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: isAr ? "خيارات الفاتورة" : "Invoice options",
                  onSelected: (value) {
                    if (value == "print") _printSale(s);
                    if (value == "share") _shareSalePdf(s);
                    if (value == "edit") _editSale(s);
                    if (value == "delete") _deleteSale(s);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: "print", child: Text(isAr ? "طباعة الفاتورة" : "Print invoice")),
                    PopupMenuItem(value: "share", child: Text(isAr ? "مشاركة PDF" : "Share PDF")),
                    PopupMenuItem(value: "edit", child: Text(isAr ? "تعديل" : "Edit")),
                    PopupMenuItem(value: "delete", child: Text(isAr ? "حذف" : "Delete")),
                  ],
                ),
              ],
            ),
          ),
          onLongPress: () => _editSale(s),
          onTap: () => _printSale(s),
        ),
      ),
    );
  }

  List<_SaleProductChoice> _saleChoices() {
    final rows = <_SaleProductChoice>[];
    for (final product in _products) {
      if (product.hasVariants) {
        for (final variant in product.variants) {
          rows.add(_SaleProductChoice(
            id: "${product.id}:${variant.id}",
            productId: product.id,
            variantId: variant.id,
            label: "${product.name} - ${variant.name} (${variant.quantity.toStringAsFixed(0)} ${variant.unit})",
            sellingPrice: variant.sellingPrice,
            currency: variant.currency,
            unit: variant.unit,
          ));
        }
      } else {
        rows.add(_SaleProductChoice(
          id: product.id,
          productId: product.id,
          variantId: null,
          label: "${product.name} (${product.quantity.toStringAsFixed(0)} ${product.unit})",
          sellingPrice: product.sellingPrice,
          currency: product.currency,
          unit: product.unit,
        ));
      }
    }
    return rows;
  }

  _SaleProductChoice? _firstSaleChoiceWhere(bool Function(_SaleProductChoice) test) {
    for (final choice in _saleChoices()) {
      if (test(choice)) return choice;
    }
    return null;
  }

  ContactModel? _firstCustomerWhere(bool Function(ContactModel) test) {
    for (final customer in _customers) {
      if (test(customer)) return customer;
    }
    return null;
  }

  String _unitPriceLabel(bool isAr) {
    final unit = _activeChoice?.unit ?? "";
    if (!isAr) return unit.isEmpty ? "Unit Price" : "Price per $unit";
    return "سعر ${_arabicUnit(unit)}";
  }

  String _arabicUnit(String unit) {
    switch (unit) {
      case "Bag":
        return "الكيس";
      case "Kilogram":
        return "الكيلو";
      case "Box":
        return "الصندوق";
      case "Piece":
        return "القطعة";
      default:
        return unit.trim().isEmpty ? "الوحدة" : unit;
    }
  }
}

class _SaleProductChoice {
  final String id;
  final String productId;
  final String? variantId;
  final String label;
  final double sellingPrice;
  final String currency;
  final String unit;

  const _SaleProductChoice({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.label,
    required this.sellingPrice,
    required this.currency,
    required this.unit,
  });
}

class _SaleEditDialog extends StatefulWidget {
  final Sale sale;
  final List<ContactModel> customers;

  const _SaleEditDialog({required this.sale, required this.customers});

  @override
  State<_SaleEditDialog> createState() => _SaleEditDialogState();
}

class _SaleEditDialogState extends State<_SaleEditDialog> {
  final _customerName = TextEditingController();
  final _note = TextEditingController();
  String? _contactId;
  bool _registerDebt = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _customerName.text = widget.sale.customerName;
    _note.text = widget.sale.note;
    _contactId = widget.sale.contactId.isEmpty ? null : widget.sale.contactId;
    _registerDebt = widget.sale.paymentStatus == "debt";
  }

  @override
  void dispose() {
    _customerName.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final validContactId = widget.customers.any((customer) => customer.id == _contactId) ? _contactId : null;

    return AlertDialog(
      title: Text(isAr ? "تعديل الفاتورة" : "Edit invoice"),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: validContactId,
                decoration: InputDecoration(labelText: isAr ? "اختيار الزبون" : "Customer"),
                items: widget.customers
                    .map((customer) => DropdownMenuItem(
                          value: customer.id,
                          child: Row(
                            children: [
                              Expanded(child: Text(customer.name, overflow: TextOverflow.ellipsis)),
                              if (customer.phone.trim().isNotEmpty) PhoneText(customer.fullPhone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  final selected = _firstCustomerWhere((customer) => customer.id == value);
                  setState(() {
                    _contactId = value;
                    if (selected != null) _customerName.text = selected.name;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerName,
                decoration: InputDecoration(labelText: isAr ? "اسم الزبون على الفاتورة" : "Invoice customer name"),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _registerDebt,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(isAr ? "تسجيلها كدين" : "Register as debt"),
                subtitle: Text(isAr ? "الدين يحتاج زبون محفوظ من قائمة الأسماء" : "Debt invoices need a saved customer contact"),
                onChanged: (value) => setState(() {
                  _registerDebt = value ?? false;
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(labelText: isAr ? "ملاحظة" : "Note"),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t("cancel"))),
        FilledButton(onPressed: _save, child: Text(c.t("save"))),
      ],
    );
  }

  void _save() {
    final isAr = AppScope.of(context).isArabic;
    final selected = _firstCustomerWhere((customer) => customer.id == _contactId);
    if (_registerDebt && selected == null) {
      setState(() => _error = isAr ? "اختار زبون محفوظ قبل تسجيلها كدين" : "Select a saved customer before registering debt");
      return;
    }

    final name = _customerName.text.trim().isEmpty ? (selected?.name ?? widget.sale.customerName) : _customerName.text.trim();
    Navigator.pop(context, {
      "customerName": name,
      if (_contactId != null && _contactId!.isNotEmpty) "contact": _contactId,
      "paymentStatus": _registerDebt ? "debt" : "paid",
      "note": _note.text.trim(),
    });
  }

  ContactModel? _firstCustomerWhere(bool Function(ContactModel) test) {
    for (final customer in widget.customers) {
      if (test(customer)) return customer;
    }
    return null;
  }
}
