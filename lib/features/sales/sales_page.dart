import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
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
  final _manualCustomerPhone = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _totalPrice = TextEditingController();

  bool _isManualCustomer = false;
  _SaleProductChoice? _activeChoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _manualCustomerName.dispose();
    _manualCustomerPhone.dispose();
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

  Future<void> _createSale() async {
    if (_activeChoice == null) return _showError("Select product");
    final q = double.tryParse(_quantity.text) ?? 0;
    final price = double.tryParse(_unitPrice.text) ?? 0;
    if (q <= 0) return _showError("Invalid quantity");

    final selectedCustomer = _firstCustomerWhere((x) => x.id == _selectedCustomerId);
    String custName = _isManualCustomer ? (_manualCustomerName.text.isEmpty ? "Walk-in" : _manualCustomerName.text) : (selectedCustomer?.name ?? "Walk-in");

    try {
      await widget.api.post("/sales", {
        "customerName": custName,
        if (!_isManualCustomer && _selectedCustomerId != null) "contact": _selectedCustomerId,
        "items": [
          {
            "productId": _activeChoice!.productId,
            if (_activeChoice!.variantId != null) "variantId": _activeChoice!.variantId,
            "quantity": q,
            "unitPrice": price,
          }
        ],
      });
      _resetForm();
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _resetForm() {
    _manualCustomerName.clear();
    _manualCustomerPhone.clear();
    _quantity.clear();
    _unitPrice.clear();
    _totalPrice.clear();
    _selectedProductId = null;
    _selectedCustomerId = null;
    _activeChoice = null;
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
                Row(
                  children: [
                    Expanded(
                      child: _isManualCustomer
                          ? TextField(controller: _manualCustomerName, decoration: InputDecoration(labelText: isAr ? "اسم الزبون" : "Customer Name"))
                          : DropdownButtonFormField<String>(
                              value: _selectedCustomerId,
                              decoration: InputDecoration(labelText: c.t("customerName")),
                              items: _customers.map((cust) => DropdownMenuItem(value: cust.id, child: Text(cust.name))).toList(),
                              onChanged: (v) => setState(() => _selectedCustomerId = v),
                            ),
                    ),
                    IconButton(onPressed: () => setState(() => _isManualCustomer = !_isManualCustomer), icon: Icon(_isManualCustomer ? Icons.list_alt_rounded : Icons.edit_note_rounded)),
                  ],
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
                        decoration: InputDecoration(labelText: isAr ? "سعر الحبة" : "Unit Price"),
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
          Text(c.t("recentSales"), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (_loading) const Center(child: CircularProgressIndicator()) else if (_error != null) ModernCard(child: Text(_error!)) else if (_sales.isEmpty) ModernCard(child: Text(c.t("empty"))) else ..._sales.map((s) => _saleItem(s)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _saleItem(Sale s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        onTap: () async {
          final c = AppScope.of(context);
          final raw = await widget.api.get("/invoice-template");
          final template = InvoiceTemplateModel.fromJson(Map<String, dynamic>.from(raw as Map));
          await PdfService.printInvoice(languageCode: c.languageCode, sale: s, template: template);
        },
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(s.customerName),
          trailing: Text(money(s.total, s.currency), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 16)),
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
          ));
        }
      } else {
        rows.add(_SaleProductChoice(
          id: product.id,
          productId: product.id,
          variantId: null,
          label: "${product.name} (${product.quantity.toStringAsFixed(0)} ${product.unit})",
          sellingPrice: product.sellingPrice,
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
}

class _SaleProductChoice {
  final String id;
  final String productId;
  final String? variantId;
  final String label;
  final double sellingPrice;

  const _SaleProductChoice({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.label,
    required this.sellingPrice,
  });
}
