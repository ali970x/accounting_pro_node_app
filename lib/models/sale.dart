class SaleItem {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;
  final String currency;

  const SaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.currency,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productName: (json["productName"] ?? "").toString(),
      quantity: _num(json["quantity"]),
      unitPrice: _num(json["unitPrice"]),
      total: _num(json["total"]),
      currency: (json["currency"] ?? "LBP").toString(),
    );
  }
}

class Sale {
  final String id;
  final String invoiceNo;
  final String customerName;
  final String contactId;
  final double total;
  final String currency;
  final String paymentStatus;
  final String paymentMethod;
  final double debtPaymentAmount;
  final String debtPaymentCurrency;
  final double debtBalanceBeforeLbp;
  final double debtBalanceBeforeUsd;
  final double debtBalanceAfterLbp;
  final double debtBalanceAfterUsd;
  final String note;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.customerName,
    required this.contactId,
    required this.total,
    required this.currency,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.debtPaymentAmount,
    required this.debtPaymentCurrency,
    required this.debtBalanceBeforeLbp,
    required this.debtBalanceBeforeUsd,
    required this.debtBalanceAfterLbp,
    required this.debtBalanceAfterUsd,
    required this.note,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final raw = json["items"];
    return Sale(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      invoiceNo: (json["invoiceNo"] ?? "").toString(),
      customerName: (json["customerName"] ?? "").toString(),
      contactId: _id(json["contact"]),
      total: _num(json["total"]),
      currency: (json["currency"] ?? "LBP").toString(),
      paymentStatus: (json["paymentStatus"] ?? "paid").toString(),
      paymentMethod: (json["paymentMethod"] ?? (json["paymentStatus"] == "debt" ? "debt" : "cash")).toString(),
      debtPaymentAmount: _num(json["debtPaymentAmount"]),
      debtPaymentCurrency: (json["debtPaymentCurrency"] ?? "LBP").toString(),
      debtBalanceBeforeLbp: _num(json["debtBalanceBeforeLbp"]),
      debtBalanceBeforeUsd: _num(json["debtBalanceBeforeUsd"]),
      debtBalanceAfterLbp: _num(json["debtBalanceAfterLbp"]),
      debtBalanceAfterUsd: _num(json["debtBalanceAfterUsd"]),
      note: (json["note"] ?? "").toString(),
      items: raw is List ? raw.map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map))).toList() : [],
    );
  }
}

String _id(dynamic value) {
  if (value is Map) return (value["_id"] ?? value["id"] ?? "").toString();
  return (value ?? "").toString();
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
