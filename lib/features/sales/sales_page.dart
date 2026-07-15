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
import "../../widgets/date_filter_bar.dart";
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

  String? _selectedCustomerId;
  String _productCategoryFilter = "";
  final _productSearch = TextEditingController();
  final _productFocusNode = FocusNode();
  final _manualCustomerName = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _quantity = TextEditingController();
  final _weight = TextEditingController();
  final _unitPrice = TextEditingController();
  final _totalPrice = TextEditingController();
  final _debtPayment = TextEditingController();
  final List<_SaleDraftItem> _saleItems = [];

  bool _registerDebt = false;
  bool _showAllSales = false;
  String _paymentMethod = "cash";
  String _debtPaymentCurrency = "LBP";
  DateFilterValue _dateFilter = const DateFilterValue(
    preset: DateFilterPreset.month,
  );
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
    _weight.dispose();
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
      _products = (pData as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final sData = data[1];
      _sales = (sData as List)
          .map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final cData = data[2];
      _customers = (cData as List)
          .map(
            (e) => ContactModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((c) => c.type == "customer")
          .toList();

      _debts = (data[3] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onProductSelected(String? id) {
    final choice = _firstSaleChoiceWhere((x) => x.id == id);
    setState(() {
      _activeChoice = choice;
      if (choice != null) {
        _productSearch.text = choice.label;
        _unitPrice.text = choice.sellingPrice.toStringAsFixed(2);
        _updateTotal();
      }
    });
  }

  void _updateTotal() {
    final q = parseNumberInput(_quantity.text);
    final w = parseNumberInput(_weight.text);
    final p = parseNumberInput(_unitPrice.text);
    _totalPrice.text = (_billableAmount(quantity: q, weight: w) * p)
        .toStringAsFixed(2);
  }

  void _updateUnitPrice() {
    final q = parseNumberInput(_quantity.text, fallback: 1);
    final w = parseNumberInput(_weight.text);
    final t = parseNumberInput(_totalPrice.text);
    final billable = _billableAmount(quantity: q, weight: w);
    if (billable > 0) {
      _unitPrice.text = (t / billable).toStringAsFixed(2);
    }
  }

  double _billableAmount({required double quantity, required double weight}) {
    return weight > 0 ? weight : quantity;
  }

  Future<void> _createNewContact() async {
    final body = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ContactDialog",
      pageBuilder: (context, _, __) =>
          const ContactDialog(contact: null, type: "customer"),
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
        title: Text(isAr ? "إلغاء الفاتورة؟" : "Cancel invoice?"),
        content: Text(
          isAr
              ? "سيتم إرجاع الكمية إلى المخزون وحذف دين الفاتورة إن وجد."
              : "Stock will be restored and related invoice debt will be removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? "إلغاء" : "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? "إلغاء الفاتورة" : "Cancel invoice"),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? "إلغاء" : "Cancel"),
          ),
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
    if (_saleItems.isEmpty &&
        _activeChoice != null &&
        _quantity.text.trim().isNotEmpty) {
      if (!_addCurrentItemToInvoice()) return;
    }
    if (_saleItems.isEmpty) return _showError("Add at least one item");
    final isAr = AppScope.of(context).isArabic;

    final selectedCustomer = _firstCustomerWhere(
      (x) => x.id == _selectedCustomerId,
    );
    final typedCustomer = _manualCustomerName.text.trim();
    final selectedMatchesText =
        selectedCustomer != null && selectedCustomer.name == typedCustomer;
    final custName = typedCustomer.isEmpty
        ? (selectedCustomer?.name ?? "Walk-in")
        : typedCustomer;
    if (_registerDebt &&
        !(selectedMatchesText && _selectedCustomerId != null)) {
      return _showError(
        isAr
            ? "اختار الزبون من القائمة قبل تسجيل الدين"
            : "Select the customer from the list before registering debt",
      );
    }
    final debtPayment = _shouldShowCustomerDebtPanel()
        ? _parseInput(_debtPayment.text)
        : 0.0;
    if (debtPayment > 0 &&
        !(selectedMatchesText && _selectedCustomerId != null)) {
      return _showError(
        isAr
            ? "اختار الزبون من القائمة قبل تسجيل دفعة من الدين"
            : "Select the customer before recording a debt payment",
      );
    }

    try {
      final created = await widget.api.post("/sales", {
        "customerName": custName,
        if (selectedMatchesText && _selectedCustomerId != null)
          "contact": _selectedCustomerId,
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
    _weight.clear();
    _unitPrice.clear();
    _totalPrice.clear();
    _productSearch.clear();
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
    final weight = _decimalInput(_weight.text);
    final unitPrice = _parseInput(_unitPrice.text);
    if (quantity <= 0) {
      _showError(isAr ? "اكتب كمية صحيحة" : "Enter a valid quantity");
      return false;
    }
    if (unitPrice < 0) {
      _showError(isAr ? "السعر غير صحيح" : "Invalid price");
      return false;
    }
    if (weight < 0) {
      _showError(isAr ? "الوزن غير صحيح" : "Invalid weight");
      return false;
    }
    if (_saleItems.isNotEmpty && _saleItems.first.currency != choice.currency) {
      _showError(
        isAr
            ? "لا يمكن خلط عملتين بنفس فاتورة المبيع"
            : "Sales invoice items must use one currency",
      );
      return false;
    }

    final index = _saleItems.indexWhere((item) => item.id == choice.id);
    final currentQty = index == -1 ? 0.0 : _saleItems[index].quantity;
    final nextQty = currentQty + quantity;
    if (nextQty > choice.quantity) {
      _showError(
        isAr
            ? "الكمية أكبر من المتوفر بالمخزون"
            : "Quantity is greater than available stock",
      );
      return false;
    }

    setState(() {
      if (index == -1) {
        _saleItems.add(
          _SaleDraftItem.fromChoice(
            choice,
            quantity: quantity,
            weight: weight,
            unitPrice: unitPrice,
          ),
        );
      } else {
        _saleItems[index] = _saleItems[index].copyWith(
          quantity: nextQty,
          weight: _saleItems[index].weight + weight,
          unitPrice: unitPrice,
        );
      }
      _clearProductEntry();
    });
    return true;
  }

  void _clearProductEntry() {
    _quantity.clear();
    _weight.clear();
    _unitPrice.clear();
    _totalPrice.clear();
    _productSearch.clear();
    _activeChoice = null;
  }

  double _parseInput(String value) => parseNumberInput(value);

  double _decimalInput(String value) => parseNumberInput(value);

  double _saleItemsTotal() =>
      _saleItems.fold<double>(0, (sum, item) => sum + item.total);

  List<Sale> _filteredSales() {
    return _sales
        .where((sale) => _dateFilter.includes(sale.createdAt))
        .toList();
  }

  Map<String, double> _salesTotals(List<Sale> sales) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    for (final sale in sales) {
      final currency = sale.currency == "USD" ? "USD" : "LBP";
      totals[currency] = (totals[currency] ?? 0) + sale.total;
    }
    return totals;
  }

  Map<String, double> _customerDebtTotals(String? contactId) {
    final totals = {"LBP": 0.0, "USD": 0.0};
    if (contactId == null || contactId.isEmpty) return totals;
    for (final debt in _debts) {
      if ((debt["type"] ?? "").toString() != "receivable") continue;
      if ((debt["status"] ?? "").toString() == "paid") continue;
      if (_debtContactId(debt) != contactId) continue;
      final currency = (debt["currency"] ?? "LBP").toString() == "USD"
          ? "USD"
          : "LBP";
      totals[currency] =
          (totals[currency] ?? 0) + _parseDebtNumber(debt["remainingAmount"]);
    }
    return totals;
  }

  bool _shouldShowCustomerDebtPanel() {
    final totals = _customerDebtTotals(_selectedCustomerId);
    return (totals["LBP"] ?? 0) > 0 || (totals["USD"] ?? 0) > 0;
  }

  String _debtContactId(Map<String, dynamic> debt) {
    final raw = debt["contact"];
    if (raw is Map) return (raw["_id"] ?? raw["id"] ?? "").toString();
    return (raw ?? "").toString();
  }

  double _parseDebtNumber(dynamic value) {
    return numFromDynamic(value);
  }

  Future<void> _showSaleSharePrompt(Sale sale, {bool created = true}) async {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final message = _saleMessage(sale, isAr);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          created
              ? (isAr ? "تم إنشاء الفاتورة" : "Invoice created")
              : (isAr ? "مشاركة الفاتورة" : "Share invoice"),
        ),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? "إغلاق" : "Close"),
          ),
          OutlinedButton.icon(
            onPressed: () async =>
                Clipboard.setData(ClipboardData(text: message)),
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
    final invoiceDebt = sale.invoiceDebtAmount > 0
        ? money(sale.invoiceDebtAmount, sale.currency)
        : (isAr ? "مدفوع" : "Paid");
    final lines = <String>[
      isAr ? "فاتورة مبيع" : "Sales Invoice",
      "${isAr ? "رقم الفاتورة" : "Invoice"}: ${sale.invoiceNo}",
      "${isAr ? "الزبون" : "Customer"}: ${sale.customerName}",
      "${isAr ? "المجموع" : "Total"}: ${money(sale.total, sale.currency)}",
      "${isAr ? "الحالة" : "Status"}: ${sale.paymentStatus == "debt" ? (isAr ? "دين" : "Debt") : (isAr ? "مدفوع" : "Paid")}",
      "${isAr ? "طريقة الدفع" : "Payment method"}: ${_paymentMethodLabel(sale.paymentMethod, isAr)}",
      if (sale.debtPaymentAmount > 0)
        "${isAr ? "دفع من الدين" : "Debt payment"}: ${money(sale.debtPaymentAmount, sale.debtPaymentCurrency)}",
      "${isAr ? "الرصيد السابق" : "Previous balance"}: ${_moneyPair(sale.debtBalanceBeforeLbp, sale.debtBalanceBeforeUsd)}",
      if (sale.debtPaymentAmount > 0)
        "${isAr ? "باقي الدين السابق" : "Previous debt remaining"}: ${_moneyPair(sale.debtPreviousAfterPaymentLbp, sale.debtPreviousAfterPaymentUsd)}",
      "${isAr ? "رصيد هذه الفاتورة" : "This invoice balance"}: $invoiceDebt",
      "${isAr ? "إجمالي الدين بعد الفاتورة" : "Total debt after invoice"}: ${_moneyPair(sale.debtBalanceAfterLbp, sale.debtBalanceAfterUsd)}",
      "",
    ];
    for (final item in sale.items) {
      lines.add(
        "- ${item.productName}: ${numberDecimal(item.quantity)}"
        "${item.weight > 0 ? " | ${isAr ? "وزن" : "Weight"}: ${numberDecimal(item.weight)} ${isAr ? "كغ" : "kg"}" : ""}"
        " x ${money(item.unitPrice, item.currency)} = ${money(item.total, item.currency)}",
      );
    }
    return lines.join("\n");
  }

  String _moneyPair(num lbp, num usd) {
    final parts = <String>[];
    if (lbp != 0) parts.add(money(lbp, "LBP"));
    if (usd != 0) parts.add(money(usd, "USD"));
    return parts.isEmpty ? money(0, "LBP") : parts.join(" / ");
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
    final template = InvoiceTemplateModel.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
    await PdfService.printInvoice(
      languageCode: c.languageCode,
      sale: sale,
      template: template,
    );
  }

  Future<void> _shareSalePdf(Sale sale) async {
    final c = AppScope.of(context);
    final raw = await widget.api.get("/invoice-template");
    final template = InvoiceTemplateModel.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
    await PdfService.shareInvoice(
      languageCode: c.languageCode,
      sale: sale,
      template: template,
    );
  }

  void _showError(Object e) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(e.toString())));

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final visibleSales = _filteredSales();

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
                    Text(
                      c.t("newSale"),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _createNewContact,
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(isAr ? "زبون جديد" : "New Customer"),
                    ),
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
                    return _customers
                        .where((customer) {
                          return customer.name.toLowerCase().contains(q) ||
                              customer.phone.contains(q);
                        })
                        .take(8);
                  },
                  onSelected: (customer) {
                    setState(() {
                      _selectedCustomerId = customer.id;
                      _manualCustomerName.text = customer.name;
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: c.t("customerName"),
                            prefixIcon: const Icon(Icons.person_search_rounded),
                          ),
                          onChanged: (value) {
                            final selected = _firstCustomerWhere(
                              (x) => x.id == _selectedCustomerId,
                            );
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
                          constraints: const BoxConstraints(
                            maxHeight: 260,
                            maxWidth: 520,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final customer = options.elementAt(index);
                              return ListTile(
                                leading: const Icon(Icons.person_rounded),
                                title: Text(customer.name),
                                subtitle: customer.phone.isEmpty
                                    ? null
                                    : PhoneText(customer.fullPhone),
                                onTap: () => onSelected(customer),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_shouldShowCustomerDebtPanel()) ...[
                  const SizedBox(height: 16),
                  _customerDebtPanel(isAr),
                ],
                const SizedBox(height: 16),
                _productPicker(isAr),
                const SizedBox(height: 16),
                _responsiveFields([
                  TextField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: c.t("quantity")),
                    onChanged: (_) => _updateTotal(),
                  ),
                  TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _updateTotal(),
                    decoration: InputDecoration(
                      labelText: isAr ? "الوزن" : "Weight",
                    ),
                  ),
                  TextField(
                    controller: _unitPrice,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _unitPriceLabel(isAr),
                    ),
                    onChanged: (_) => _updateTotal(),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _totalPrice,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.blue,
                  ),
                  decoration: InputDecoration(
                    labelText: isAr
                        ? "إجمالي المبلغ المطلوب"
                        : "Total Amount to Pay",
                    prefixIcon: const Icon(
                      Icons.payments_rounded,
                      color: Colors.blue,
                    ),
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
                  title: Text(
                    isAr
                        ? "تسجيل الفاتورة كدين على الزبون"
                        : "Register invoice as customer debt",
                  ),
                  subtitle: Text(
                    isAr
                        ? "الافتراضي مدفوع، فعّلها فقط إذا بقي المبلغ دين"
                        : "Default is paid. Enable only when this remains unpaid.",
                  ),
                  onChanged: (v) => setState(() {
                    _registerDebt = v ?? false;
                    _paymentMethod = _registerDebt ? "debt" : "cash";
                  }),
                ),
                DropdownButtonFormField<String>(
                  value: _registerDebt ? "debt" : _paymentMethod,
                  decoration: InputDecoration(
                    labelText: isAr ? "طريقة الدفع" : "Payment method",
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: "cash",
                      child: Text(isAr ? "نقداً" : "Cash"),
                    ),
                    DropdownMenuItem(
                      value: "bank",
                      child: Text(isAr ? "تحويل بنكي" : "Bank"),
                    ),
                    DropdownMenuItem(
                      value: "card",
                      child: Text(isAr ? "بطاقة" : "Card"),
                    ),
                    DropdownMenuItem(
                      value: "transfer",
                      child: Text(isAr ? "تحويل" : "Transfer"),
                    ),
                    DropdownMenuItem(
                      value: "other",
                      child: Text(isAr ? "أخرى" : "Other"),
                    ),
                    DropdownMenuItem(
                      value: "debt",
                      child: Text(isAr ? "دين" : "Debt"),
                    ),
                  ],
                  onChanged: _registerDebt
                      ? null
                      : (value) =>
                            setState(() => _paymentMethod = value ?? "cash"),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _createSale,
                    icon: const Icon(Icons.point_of_sale),
                    label: Text(
                      _saleItems.isEmpty
                          ? c.t("createSale")
                          : "${c.t("createSale")} (${number(_saleItems.length)})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _salesReportCard(isAr, visibleSales),
          const SizedBox(height: 14),
          _invoiceListCard(isAr, visibleSales),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _customerDebtPanel(bool isAr) {
    final theme = Theme.of(context);
    final selected = _firstCustomerWhere(
      (customer) => customer.id == _selectedCustomerId,
    );
    final totals = _customerDebtTotals(_selectedCustomerId);
    final hasDebt = (totals["LBP"] ?? 0) > 0 || (totals["USD"] ?? 0) > 0;
    if (selected == null || !hasDebt) return const SizedBox.shrink();

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
              Icon(
                Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr ? "ديون ${selected.name}" : "${selected.name} debts",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${isAr ? "المتبقي" : "Remaining"}: ${money(totals["LBP"] ?? 0, "LBP")} / ${money(totals["USD"] ?? 0, "USD")}",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 10),
          _responsiveFields([
            TextField(
              controller: _debtPayment,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isAr ? "دفعة من الدين" : "Debt payment",
              ),
            ),
            DropdownButtonFormField<String>(
              value: _debtPaymentCurrency,
              decoration: InputDecoration(
                labelText: isAr ? "عملة الدفعة" : "Payment currency",
              ),
              items: const [
                DropdownMenuItem(value: "LBP", child: Text("LBP")),
                DropdownMenuItem(value: "USD", child: Text("USD")),
              ],
              onChanged: (value) =>
                  setState(() => _debtPaymentCurrency = value ?? "LBP"),
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
                isAr
                    ? "أضف أكثر من صنف قبل إنشاء الفاتورة."
                    : "Add one or more items before creating the invoice.",
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
              Expanded(
                child: Text(
                  isAr ? "عناصر الفاتورة" : "Invoice items",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                money(_saleItemsTotal(), currency),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          for (var i = 0; i < _saleItems.length; i++) ...[
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _saleItems[i].label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                [
                  "${numberDecimal(_saleItems[i].quantity)} ${_saleItems[i].unit}${_saleItems[i].weight > 0 ? "" : " x ${money(_saleItems[i].unitPrice, _saleItems[i].currency)}"}",
                  if (_saleItems[i].weight > 0)
                    _draftWeightText(_saleItems[i], isAr),
                ].join(" | "),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(_saleItems[i].total, _saleItems[i].currency),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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

  String _draftWeightText(_SaleDraftItem item, bool isAr) {
    return "${isAr ? "وزن" : "Weight"}: ${numberDecimal(item.weight)} ${isAr ? "كغ" : "kg"} x ${money(item.unitPrice, item.currency)}";
  }

  Widget _salesReportCard(bool isAr, List<Sale> visibleSales) {
    final totals = _salesTotals(visibleSales);
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.query_stats_rounded)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? "تقرير المبيعات" : "Sales report",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DateFilterBar(
            isArabic: isAr,
            value: _dateFilter,
            onChanged: (value) => setState(() {
              _dateFilter = value;
              _showAllSales = false;
            }),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _salesReportTile(
                      icon: Icons.receipt_long_rounded,
                      label: isAr ? "عدد الفواتير" : "Invoices",
                      value: number(visibleSales.length),
                      color: Colors.indigo,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _salesReportTile(
                      icon: Icons.payments_rounded,
                      label: isAr ? "المبيع بالليرة" : "LBP sales",
                      value: money(totals["LBP"] ?? 0, "LBP"),
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _salesReportTile(
                      icon: Icons.attach_money_rounded,
                      label: isAr ? "المبيع بالدولار" : "USD sales",
                      value: money(totals["USD"] ?? 0, "USD"),
                      color: Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _salesReportTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceListCard(bool isAr, List<Sale> visibleSales) {
    final shownSales = _showAllSales
        ? visibleSales
        : visibleSales.take(5).toList();
    final hasMore = visibleSales.length > 5;

    return ModernCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_rounded)),
        title: Text(
          isAr ? "آخر الفواتير" : "Latest invoices",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          isAr
              ? "${visibleSales.length} فاتورة ضمن الفترة"
              : "${visibleSales.length} invoices in period",
        ),
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
          else if (visibleSales.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                isAr
                    ? "لا يوجد فواتير ضمن الفترة المحددة"
                    : "No invoices in the selected period",
              ),
            )
          else ...[
            Row(
              children: [
                if (hasMore)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllSales = !_showAllSales),
                    icon: Icon(
                      _showAllSales
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                    ),
                    label: Text(
                      _showAllSales
                          ? (isAr ? "عرض آخر 5" : "Show latest 5")
                          : (isAr ? "عرض الكل" : "Show all"),
                    ),
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
    final active = _activeChoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _responsiveFields([
          DropdownButtonFormField<String>(
            value: _productCategoryFilter,
            decoration: InputDecoration(
              labelText: isAr ? "الصنف" : "Category",
              prefixIcon: const Icon(Icons.folder_rounded),
            ),
            items: [
              DropdownMenuItem(
                value: "",
                child: Text(isAr ? "اختر الصنف" : "Choose category"),
              ),
              ...categories.map(
                (x) => DropdownMenuItem(value: x, child: Text(x)),
              ),
            ],
            onChanged: (value) => setState(() {
              _productCategoryFilter = value ?? "";
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
            if (_productCategoryFilter.isEmpty)
              return const Iterable<_SaleProductChoice>.empty();
            final q = value.text.trim().toLowerCase();
            return choices
                .where((choice) {
                  if (q.isEmpty) return true;
                  return choice.searchText.contains(q);
                })
                .take(10);
          },
          onSelected: (choice) => _onProductSelected(choice.id),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: isAr ? "ابحث عن المنتج" : "Search product",
                prefixIcon: const Icon(Icons.manage_search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          controller.clear();
                          setState(() {
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
                  constraints: const BoxConstraints(
                    maxHeight: 320,
                    maxWidth: 640,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final choice = options.elementAt(index);
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_rounded),
                        ),
                        title: Text(
                          choice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(choice.category),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${number(choice.quantity)} ${choice.unit}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              money(choice.sellingPrice, choice.currency),
                              style: const TextStyle(fontSize: 12),
                            ),
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
        if (_productCategoryFilter.isNotEmpty && active == null) ...[
          const SizedBox(height: 8),
          _quickProductChoices(choices, isAr),
        ],
        if (active != null) ...[
          const SizedBox(height: 8),
          Text(
            isAr
                ? "المتوفر: ${number(active.quantity)} ${active.unit} | السعر: ${money(active.sellingPrice, active.currency)}"
                : "Available: ${number(active.quantity)} ${active.unit} | Price: ${money(active.sellingPrice, active.currency)}",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickProductChoices(List<_SaleProductChoice> choices, bool isAr) {
    final shown = choices.take(8).toList();
    if (shown.isEmpty) {
      return Text(
        isAr
            ? "لا يوجد منتجات ضمن هذا الصنف."
            : "No products in this category.",
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: shown.map((choice) {
        return ActionChip(
          avatar: const Icon(Icons.inventory_2_rounded, size: 18),
          label: Text(choice.label, overflow: TextOverflow.ellipsis),
          onPressed: () => _onProductSelected(choice.id),
        );
      }).toList(),
    );
  }

  Widget _saleItem(Sale s) {
    final isAr = AppScope.of(context).isArabic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(
            s.invoiceNo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "${s.customerName}\n${_formatTime(s.createdAt)}${s.paymentStatus == "debt" ? (isAr ? "\nدين" : "\nDebt") : ""}",
          ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                      fontSize: 15,
                    ),
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
                    PopupMenuItem(
                      value: "print",
                      child: Text(isAr ? "طباعة الفاتورة" : "Print invoice"),
                    ),
                    PopupMenuItem(
                      value: "share",
                      child: Text(isAr ? "مشاركة PDF" : "Share PDF"),
                    ),
                    PopupMenuItem(
                      value: "edit",
                      child: Text(isAr ? "تعديل" : "Edit"),
                    ),
                    PopupMenuItem(
                      value: "delete",
                      child: Text(isAr ? "إلغاء فاتورة" : "Cancel invoice"),
                    ),
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

  String _formatTime(DateTime? value) {
    if (value == null) return "-";
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, "0");
    final m = local.month.toString().padLeft(2, "0");
    final d = local.day.toString().padLeft(2, "0");
    final h = local.hour.toString().padLeft(2, "0");
    final min = local.minute.toString().padLeft(2, "0");
    return "$y-$m-$d $h:$min";
  }

  List<_SaleProductChoice> _saleChoices() {
    final rows = <_SaleProductChoice>[];
    for (final product in _products) {
      if (product.hasVariants) {
        for (final variant in product.variants) {
          if (variant.quantity <= 0) continue;
          rows.add(
            _SaleProductChoice(
              id: "${product.id}:${variant.id}",
              productId: product.id,
              variantId: variant.id,
              category: product.category,
              label: "${product.name} - ${variant.name}",
              quantity: variant.quantity,
              sellingPrice: variant.sellingPrice,
              currency: variant.currency,
              unit: variant.unit,
            ),
          );
        }
      } else {
        if (product.quantity <= 0) continue;
        rows.add(
          _SaleProductChoice(
            id: product.id,
            productId: product.id,
            variantId: null,
            category: product.category,
            label: product.name,
            quantity: product.quantity,
            sellingPrice: product.sellingPrice,
            currency: product.currency,
            unit: product.unit,
          ),
        );
      }
    }
    rows.sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  List<_SaleProductChoice> _filteredSaleChoices() {
    if (_productCategoryFilter.isEmpty) return [];
    return _saleChoices().where((choice) {
      if (choice.category != _productCategoryFilter) return false;
      return true;
    }).toList();
  }

  List<String> _productCategoryOptions() {
    final rows = _saleChoices()
        .map((choice) => choice.category)
        .where((x) => x.trim().isNotEmpty)
        .toSet()
        .toList();
    rows.sort();
    return rows;
  }

  void _clearSelectedProductIfHidden() {
    final selected = _activeChoice;
    if (selected == null) return;
    final visible = _filteredSaleChoices().any(
      (choice) => choice.id == selected.id,
    );
    if (!visible) {
      _activeChoice = null;
      _productSearch.clear();
      _unitPrice.clear();
      _totalPrice.clear();
    }
  }

  _SaleProductChoice? _firstSaleChoiceWhere(
    bool Function(_SaleProductChoice) test,
  ) {
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
  final double weight;
  final double unitPrice;
  final String currency;
  final String unit;

  const _SaleDraftItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.label,
    required this.quantity,
    required this.weight,
    required this.unitPrice,
    required this.currency,
    required this.unit,
  });

  factory _SaleDraftItem.fromChoice(
    _SaleProductChoice choice, {
    required double quantity,
    required double weight,
    required double unitPrice,
  }) {
    return _SaleDraftItem(
      id: choice.id,
      productId: choice.productId,
      variantId: choice.variantId,
      label: choice.label,
      quantity: quantity,
      weight: weight,
      unitPrice: unitPrice,
      currency: choice.currency,
      unit: choice.unit,
    );
  }

  double get billableAmount => weight > 0 ? weight : quantity;

  double get total => billableAmount * unitPrice;

  _SaleDraftItem copyWith({
    double? quantity,
    double? weight,
    double? unitPrice,
  }) {
    return _SaleDraftItem(
      id: id,
      productId: productId,
      variantId: variantId,
      label: label,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
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
      "weight": weight,
      "unitPrice": unitPrice,
    };
  }
}

class _SaleProductChoice {
  final String id;
  final String productId;
  final String? variantId;
  final String category;
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
    required this.label,
    required this.quantity,
    required this.sellingPrice,
    required this.currency,
    required this.unit,
  });

  String get searchText => "$label $category".toLowerCase();
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
    final validContactId =
        widget.customers.any((customer) => customer.id == _contactId)
        ? _contactId
        : null;

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
                decoration: InputDecoration(
                  labelText: isAr ? "اختيار الزبون" : "Customer",
                ),
                items: widget.customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer.id,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                customer.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (customer.phone.trim().isNotEmpty)
                              PhoneText(
                                customer.fullPhone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  final selected = _firstCustomerWhere(
                    (customer) => customer.id == value,
                  );
                  setState(() {
                    _contactId = value;
                    if (selected != null) _customerName.text = selected.name;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerName,
                decoration: InputDecoration(
                  labelText: isAr
                      ? "اسم الزبون على الفاتورة"
                      : "Invoice customer name",
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _registerDebt,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(isAr ? "تسجيلها كدين" : "Register as debt"),
                subtitle: Text(
                  isAr
                      ? "الدين يحتاج زبون محفوظ من قائمة الأسماء"
                      : "Debt invoices need a saved customer contact",
                ),
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
                decoration: InputDecoration(
                  labelText: isAr ? "ملاحظة" : "Note",
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(c.t("cancel")),
        ),
        FilledButton(onPressed: _save, child: Text(c.t("save"))),
      ],
    );
  }

  void _save() {
    final isAr = AppScope.of(context).isArabic;
    final selected = _firstCustomerWhere(
      (customer) => customer.id == _contactId,
    );
    if (_registerDebt && selected == null) {
      setState(
        () => _error = isAr
            ? "اختار زبون محفوظ قبل تسجيلها كدين"
            : "Select a saved customer before registering debt",
      );
      return;
    }

    final name = _customerName.text.trim().isEmpty
        ? (selected?.name ?? widget.sale.customerName)
        : _customerName.text.trim();
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
