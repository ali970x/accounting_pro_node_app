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
  final double total;
  final String currency;
  final String paymentStatus;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.customerName,
    required this.total,
    required this.currency,
    required this.paymentStatus,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final raw = json["items"];
    return Sale(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      invoiceNo: (json["invoiceNo"] ?? "").toString(),
      customerName: (json["customerName"] ?? "").toString(),
      total: _num(json["total"]),
      currency: (json["currency"] ?? "LBP").toString(),
      paymentStatus: (json["paymentStatus"] ?? "paid").toString(),
      items: raw is List ? raw.map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map))).toList() : [],
    );
  }
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
