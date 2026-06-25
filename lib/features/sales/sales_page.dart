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
import "../../widgets/page_header.dart";
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
  List<Map<String, dynamic>> _debts = [];

  String? _selectedProductId;
  String? _selectedCustomerId;
  String _productCategoryFilter = "";
  String _productSubcategoryFilter = "";
  final _productSearch = TextEditingController();
  final _productFocusNode = FocusNode();
  final _manualCustomerName = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _totalPrice = TextEditingController();
  final _debtPayment = TextEditingController();
  final List<_SaleDraftItem> _saleItems = [];

  bool _registerDebt = false;
  bool _showAllSales = false;
  String _paymentMethod = "cash";
  String _debtPaymentCurrency = "LBP";
  _SaleProductChoice? _activeChoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _productSearch.dispose();
    _productFocusNode.dispose();
    _manualCustomerName.dispose();
    _customerFocusNode.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _totalPrice.dispose();
    _debtPayment.dispose();
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
        widget.api.get("/debts"),
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

      _debts = (data[3] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
        _productSearch.text = choice.label;
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
    if (_saleItems.isEmpty && _activeChoice != null && _quantity.text.trim().isNotEmpty) {
      if (!_addCurrentItemToInvoice()) return;
    }
    if (_saleItems.isEmpty) return _showError("Add at least one item");
    final isAr = AppScope.of(context).isArabic;

    final selectedCustomer = _firstCustomerWhere((x) => x.id == _selectedCustomerId);
    final typedCustomer = _manualCustomerName.text.trim();
    final selectedMatchesText = selectedCustomer != null && selectedCustomer.name == typedCustomer;
    final custName = typedCustomer.isEmpty ? (selectedCustomer?.name ?? "Walk-in") : typedCustomer;
    if (_registerDebt && !(selectedMatchesText && _selectedCustomerId != null)) {
      return _showError(isAr ? "اختار الزبون من القائمة قبل تسجيل الدين" : "Select the customer from the list before registering debt");
    }
    final debtPayment = _parseInput(_debtPayment.text);
    if (debtPayment > 0 && !(selectedMatchesText && _selectedCustomerId != null)) {
      return _showError(isAr ? "اختار الزبون من القائمة قبل تسجيل دفعة من الدين" : "Select the customer before recording a debt payment");
    }

    try {
      final created = await widget.api.post("/sales", {
        "customerName": custName,
        if (selectedMatchesText && _selectedCustomerId != null) "contact": _selectedCustomerId,
        "currency": _saleItems.first.currency,
        "paymentStatus": _registerDebt ? "debt" : "paid",
        "paymentMethod": _registerDebt ? "debt" : _paymentMethod,
        "debtPaymentAmount": debtPayment,
        "debtPaymentCurrency": _debtPaymentCurrency,
        "items": _saleItems.map((item) => item.toBody()).toList(),
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
    _productSearch.clear();
    _selectedProductId = null;
    _selectedCustomerId = null;
    _activeChoice = null;
    _saleItems.clear();
    _debtPayment.clear();
    _registerDebt = false;
    _paymentMethod = "cash";
    _debtPaymentCurrency = "LBP";
  }

  bool _addCurrentItemToInvoice() {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final choice = _activeChoice;
    if (choice == null) {
      _showError(isAr ? "اختار منتج أولاً" : "Select a product first");
      return false;
    }
    final quantity = _parseInput(_quantity.text);
    final unitPrice = _parseInput(_unitPrice.text);
    if (quantity <= 0) {
      _showError(isAr ? "اكتب كمية صحيحة" : "Enter a valid quantity");
      return false;
    }
    if (unitPrice < 0) {
      _showError(isAr ? "السعر غير صحيح" : "Invalid price");
      return false;
    }
    if (_saleItems.isNotEmpty && _saleItems.first.currency != choice.currency) {
      _showError(isAr ? "لا يمكن خلط عملتين بنفس فاتورة المبيع" : "Sales invoice items must use one currency");
      return false;
    }

    final index = _saleItems.indexWhere((item) => item.id == choice.id);
    final currentQty = index == -1 ? 0.0 : _saleItems[index].quantity;
    final nextQty = currentQty + quantity;
    if (nextQty > choice.quantity) {
      _showError(isAr ? "الكمية أكبر من المتوفر بالمخزون" : "Quantity is greater than available stock");
      return false;
    }

    setState(() {
      if (index == -1) {
        _saleItems.add(_SaleDraftItem.fromChoice(choice, quantity: quantity, unitPrice: unitPrice));
      } else {
        _saleItems[index] = _saleItems[index].copyWith(quantity: nextQty, unitPrice: unitPrice);
      }
      _clearProductEntry();
    });
    return true;
  }

  void _clearProductEntry() {
    _quantity.clear();
    _unitPrice.clear();
    _totalPrice.clear();
    _productSearch.clear();
    _selectedProductId = null;
    _activeChoice = null;
  }

  double _parseInput(String value) => double.tryParse(value.replaceAll(",", "").trim()) ?? 0;

  double _saleItemsTotal() => _saleItems.fold<double>(0, (sum, item) => sum + item.total);

  Map<String, double> _customerDebtTotals(String? contactId) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    if (contactId == null || contactId.isEmpty) return totals;
    for (final debt in _debts) {
      if ((debt["type"] ?? "").toString() != "receivable") continue;
      if ((debt["status"] ?? "").toString() == "paid") continue;
      if (_debtContactId(debt) != contactId) continue;
      final currency = (debt["currency"] ?? "LBP").toString() == "USD" ? "USD" : "LBP";
      totals[currency] = (totals[currency] ?? 0) + _parseDebtNumber(debt["remainingAmount"]);
    }
    return totals;
  }

  String _debtContactId(Map<String, dynamic> debt) {
    final raw = debt["contact"];
    if (raw is Map) return (raw["_id"] ?? raw["id"] ?? "").toString();
    return (raw ?? "").toString();
  }

  double _parseDebtNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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
      "${isAr ? "طريقة الدفع" : "Payment method"}: ${_paymentMethodLabel(sale.paymentMethod, isAr)}",
      if (sale.debtPaymentAmount > 0) "${isAr ? "دفع من الدين" : "Debt payment"}: ${money(sale.debtPaymentAmount, sale.debtPaymentCurrency)}",
      "${isAr ? "الرصيد السابق" : "Previous balance"}: ${money(sale.debtBalanceBeforeLbp, "LBP")} / ${money(sale.debtBalanceBeforeUsd, "USD")}",
      "${isAr ? "الرصيد النهائي" : "Final balance"}: ${money(sale.debtBalanceAfterLbp, "LBP")} / ${money(sale.debtBalanceAfterUsd, "USD")}",
      "",
    ];
    for (final item in sale.items) {
      lines.add("- ${item.productName}: ${number(item.quantity)} x ${money(item.unitPrice, item.currency)} = ${money(item.total, item.currency)}");
    }
    return lines.join("\n");
  }

  String _paymentMethodLabel(String value, bool isAr) {
    switch (value) {
      case "debt":
        return isAr ? "دين" : "Debt";
      case "bank":
        return isAr ? "تحويل بنكي" : "Bank";
      case "card":
        return isAr ? "بطاقة" : "Card";
      case "transfer":
        return isAr ? "تحويل" : "Transfer";
      case "other":
        return isAr ? "أخرى" : "Other";
      default:
        return isAr ? "نقداً" : "Cash";
    }
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
          PageHeader(title: c.t("sales")),
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
                _customerDebtPanel(isAr),
                const SizedBox(height: 16),
                _productPicker(isAr),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _addCurrentItemToInvoice,
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(isAr ? "إضافة للفاتورة" : "Add to invoice"),
                  ),
                ),
                const SizedBox(height: 12),
                _saleDraftCard(isAr),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _registerDebt,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(isAr ? "تسجيل الفاتورة كدين على الزبون" : "Register invoice as customer debt"),
                  subtitle: Text(isAr ? "الافتراضي مدفوع، فعّلها فقط إذا بقي المبلغ دين" : "Default is paid. Enable only when this remains unpaid."),
                  onChanged: (v) => setState(() {
                    _registerDebt = v ?? false;
                    _paymentMethod = _registerDebt ? "debt" : "cash";
                  }),
                ),
                DropdownButtonFormField<String>(
                  value: _registerDebt ? "debt" : _paymentMethod,
                  decoration: InputDecoration(labelText: isAr ? "طريقة الدفع" : "Payment method", prefixIcon: const Icon(Icons.payments_rounded)),
                  items: [
                    DropdownMenuItem(value: "cash", child: Text(isAr ? "نقداً" : "Cash")),
                    DropdownMenuItem(value: "bank", child: Text(isAr ? "تحويل بنكي" : "Bank")),
                    DropdownMenuItem(value: "card", child: Text(isAr ? "بطاقة" : "Card")),
                    DropdownMenuItem(value: "transfer", child: Text(isAr ? "تحويل" : "Transfer")),
                    DropdownMenuItem(value: "other", child: Text(isAr ? "أخرى" : "Other")),
                    DropdownMenuItem(value: "debt", child: Text(isAr ? "دين" : "Debt")),
                  ],
                  onChanged: _registerDebt ? null : (value) => setState(() => _paymentMethod = value ?? "cash"),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _createSale,
                    icon: const Icon(Icons.point_of_sale),
                    label: Text(
                      _saleItems.isEmpty ? c.t("createSale") : "${c.t("createSale")} (${number(_saleItems.length)})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
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

  Widget _customerDebtPanel(bool isAr) {
    final theme = Theme.of(context);
    final selected = _firstCustomerWhere((customer) => customer.id == _selectedCustomerId);
    final totals = _customerDebtTotals(_selectedCustomerId);
    final hasDebt = (totals["LBP"] ?? 0) > 0 || (totals["USD"] ?? 0) > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selected == null ? (isAr ? "اختار زبون محفوظ لعرض ديونه" : "Select a saved customer to show debts") : (isAr ? "ديون ${selected.name}" : "${selected.name} debts"),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? (isAr ? "دفعات الدين تحتاج زبون من صفحة الأسماء." : "Debt payments require a customer from Contacts.")
                : "${isAr ? "المتبقي" : "Remaining"}: ${money(totals["LBP"] ?? 0, "LBP")} / ${money(totals["USD"] ?? 0, "USD")}",
            style: TextStyle(fontWeight: FontWeight.w800, color: hasDebt ? Colors.red.shade700 : theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _responsiveFields([
            TextField(
              controller: _debtPayment,
              enabled: selected != null,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: isAr ? "دفعة من الدين" : "Debt payment"),
            ),
            DropdownButtonFormField<String>(
              value: _debtPaymentCurrency,
              decoration: InputDecoration(labelText: isAr ? "عملة الدفعة" : "Payment currency"),
              items: const [
                DropdownMenuItem(value: "LBP", child: Text("LBP")),
                DropdownMenuItem(value: "USD", child: Text("USD")),
              ],
              onChanged: selected == null ? null : (value) => setState(() => _debtPaymentCurrency = value ?? "LBP"),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _saleDraftCard(bool isAr) {
    final currency = _saleItems.isEmpty ? "LBP" : _saleItems.first.currency;
    if (_saleItems.isEmpty) {
      return ModernCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr ? "أضف أكثر من صنف قبل إنشاء الفاتورة." : "Add one or more items before creating the invoice.",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text(isAr ? "عناصر الفاتورة" : "Invoice items", style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(money(_saleItemsTotal(), currency), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue)),
            ],
          ),
          const Divider(height: 20),
          for (var i = 0; i < _saleItems.length; i++) ...[
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_saleItems[i].label, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text("${number(_saleItems[i].quantity)} ${_saleItems[i].unit} x ${money(_saleItems[i].unitPrice, _saleItems[i].currency)}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(money(_saleItems[i].total, _saleItems[i].currency), style: const TextStyle(fontWeight: FontWeight.w900)),
                  IconButton(
                    tooltip: isAr ? "حذف" : "Remove",
                    onPressed: () => setState(() => _saleItems.removeAt(i)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (i != _saleItems.length - 1) const Divider(height: 12),
          ],
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

  Widget _productPicker(bool isAr) {
    final choices = _filteredSaleChoices();
    final categories = _productCategoryOptions();
    final subcategories = _productSubcategoryOptions();
    final active = _activeChoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _responsiveFields([
          DropdownButtonFormField<String>(
                value: _productCategoryFilter,
                decoration: InputDecoration(labelText: isAr ? "الصنف" : "Category", prefixIcon: const Icon(Icons.folder_rounded)),
                items: [
                  DropdownMenuItem(value: "", child: Text(isAr ? "اختر الصنف" : "Choose category")),
                  ...categories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                ],
                onChanged: (value) => setState(() {
                  _productCategoryFilter = value ?? "";
                  _productSubcategoryFilter = "";
                  _productSearch.clear();
                  _clearSelectedProductIfHidden();
                }),
              ),
          DropdownButtonFormField<String>(
                value: _productSubcategoryFilter,
                decoration: InputDecoration(labelText: isAr ? "الصنف الفرعي" : "Subcategory", prefixIcon: const Icon(Icons.folder_copy_rounded)),
                items: [
                  DropdownMenuItem(value: "", child: Text(isAr ? "اختر الصنف الفرعي" : "Choose subcategory")),
                  ...subcategories.map((x) => DropdownMenuItem(value: x, child: Text(x))),
                ],
                onChanged: (value) => setState(() {
                  _productSubcategoryFilter = value ?? "";
                  _productSearch.clear();
                  _clearSelectedProductIfHidden();
                }),
              ),
        ]),
        const SizedBox(height: 12),
        RawAutocomplete<_SaleProductChoice>(
          textEditingController: _productSearch,
          focusNode: _productFocusNode,
          displayStringForOption: (choice) => choice.label,
          optionsBuilder: (value) {
            if (_productCategoryFilter.isEmpty || _productSubcategoryFilter.isEmpty) return const Iterable<_SaleProductChoice>.empty();
            final q = value.text.trim().toLowerCase();
            return choices.where((choice) {
              if (q.isEmpty) return true;
              return choice.searchText.contains(q);
            }).take(10);
          },
          onSelected: (choice) => _onProductSelected(choice.id),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: isAr ? "ابحث عن المنتج أو النوعية" : "Search product or quality",
                prefixIcon: const Icon(Icons.manage_search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          controller.clear();
                          setState(() {
                            _selectedProductId = null;
                            _activeChoice = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) {
                final selected = _activeChoice;
                if (selected != null && selected.label != value) {
                  setState(() {
                    _selectedProductId = null;
                    _activeChoice = null;
                  });
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320, maxWidth: 640),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final choice = options.elementAt(index);
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.inventory_2_rounded)),
                        title: Text(choice.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text("${choice.category} > ${choice.subcategory}"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${number(choice.quantity)} ${choice.unit}", style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text(money(choice.sellingPrice, choice.currency), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () => onSelected(choice),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (active != null) ...[
          const SizedBox(height: 8),
          Text(
            isAr
                ? "المتوفر: ${number(active.quantity)} ${active.unit} | السعر: ${money(active.sellingPrice, active.currency)}"
                : "Available: ${number(active.quantity)} ${active.unit} | Price: ${money(active.sellingPrice, active.currency)}",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ],
      ],
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
          if (variant.quantity <= 0) continue;
          rows.add(_SaleProductChoice(
            id: "${product.id}:${variant.id}",
            productId: product.id,
            variantId: variant.id,
            category: product.category,
            subcategory: product.subcategory,
            label: "${product.name} - ${variant.name}",
            quantity: variant.quantity,
            sellingPrice: variant.sellingPrice,
            currency: variant.currency,
            unit: variant.unit,
          ));
        }
      } else {
        if (product.quantity <= 0) continue;
        rows.add(_SaleProductChoice(
          id: product.id,
          productId: product.id,
          variantId: null,
          category: product.category,
          subcategory: product.subcategory,
          label: product.name,
          quantity: product.quantity,
          sellingPrice: product.sellingPrice,
          currency: product.currency,
          unit: product.unit,
        ));
      }
    }
    rows.sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  List<_SaleProductChoice> _filteredSaleChoices() {
    if (_productCategoryFilter.isEmpty || _productSubcategoryFilter.isEmpty) return [];
    return _saleChoices().where((choice) {
      if (choice.category != _productCategoryFilter) return false;
      if (choice.subcategory != _productSubcategoryFilter) return false;
      return true;
    }).toList();
  }

  List<String> _productCategoryOptions() {
    final rows = _saleChoices().map((choice) => choice.category).where((x) => x.trim().isNotEmpty).toSet().toList();
    rows.sort();
    return rows;
  }

  List<String> _productSubcategoryOptions() {
    final rows = _saleChoices()
        .where((choice) => _productCategoryFilter.isNotEmpty && choice.category == _productCategoryFilter)
        .map((choice) => choice.subcategory)
        .where((x) => x.trim().isNotEmpty)
        .toSet()
        .toList();
    rows.sort();
    return rows;
  }

  void _clearSelectedProductIfHidden() {
    final selected = _activeChoice;
    if (selected == null) return;
    final visible = _filteredSaleChoices().any((choice) => choice.id == selected.id);
    if (!visible) {
      _selectedProductId = null;
      _activeChoice = null;
      _productSearch.clear();
      _unitPrice.clear();
      _totalPrice.clear();
    }
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

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _SaleDraftItem {
  final String id;
  final String productId;
  final String? variantId;
  final String label;
  final double quantity;
  final double unitPrice;
  final String currency;
  final String unit;

  const _SaleDraftItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.currency,
    required this.unit,
  });

  factory _SaleDraftItem.fromChoice(_SaleProductChoice choice, {required double quantity, required double unitPrice}) {
    return _SaleDraftItem(
      id: choice.id,
      productId: choice.productId,
      variantId: choice.variantId,
      label: choice.label,
      quantity: quantity,
      unitPrice: unitPrice,
      currency: choice.currency,
      unit: choice.unit,
    );
  }

  double get total => quantity * unitPrice;

  _SaleDraftItem copyWith({double? quantity, double? unitPrice}) {
    return _SaleDraftItem(
      id: id,
      productId: productId,
      variantId: variantId,
      label: label,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency,
      unit: unit,
    );
  }

  Map<String, dynamic> toBody() {
    return {
      "productId": productId,
      if (variantId != null) "variantId": variantId,
      "quantity": quantity,
      "unitPrice": unitPrice,
    };
  }
}

class _SaleProductChoice {
  final String id;
  final String productId;
  final String? variantId;
  final String category;
  final String subcategory;
  final String label;
  final double quantity;
  final double sellingPrice;
  final String currency;
  final String unit;

  const _SaleProductChoice({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.category,
    required this.subcategory,
    required this.label,
    required this.quantity,
    required this.sellingPrice,
    required this.currency,
    required this.unit,
  });

  String get searchText => "$label $category $subcategory".toLowerCase();
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
