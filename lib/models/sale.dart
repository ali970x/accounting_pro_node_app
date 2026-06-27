import "../core/money.dart";

class SaleItem {
  final String productName;
  final double quantity;
  final double packageCount;
  final double weight;
  final double unitPrice;
  final double total;
  final String currency;

  const SaleItem({
    required this.productName,
    required this.quantity,
    required this.packageCount,
    required this.weight,
    required this.unitPrice,
    required this.total,
    required this.currency,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productName: (json["productName"] ?? "").toString(),
      quantity: _num(json["quantity"]),
      packageCount: _num(json["packageCount"]),
      weight: _num(json["weight"]),
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
  final double debtPreviousAfterPaymentLbp;
  final double debtPreviousAfterPaymentUsd;
  final double debtBalanceAfterLbp;
  final double debtBalanceAfterUsd;
  final String note;
  final List<SaleItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    required this.debtPreviousAfterPaymentLbp,
    required this.debtPreviousAfterPaymentUsd,
    required this.debtBalanceAfterLbp,
    required this.debtBalanceAfterUsd,
    required this.note,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final raw = json["items"];
    final total = _num(json["total"]);
    final currency = (json["currency"] ?? "LBP").toString();
    final paymentStatus = (json["paymentStatus"] ?? "paid").toString();
    final afterLbp = _num(json["debtBalanceAfterLbp"]);
    final afterUsd = _num(json["debtBalanceAfterUsd"]);
    final invoiceDebtLbp = paymentStatus == "debt" && currency != "USD"
        ? total
        : 0.0;
    final invoiceDebtUsd = paymentStatus == "debt" && currency == "USD"
        ? total
        : 0.0;
    return Sale(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      invoiceNo: (json["invoiceNo"] ?? "").toString(),
      customerName: (json["customerName"] ?? "").toString(),
      contactId: _id(json["contact"]),
      total: total,
      currency: currency,
      paymentStatus: paymentStatus,
      paymentMethod:
          (json["paymentMethod"] ??
                  (json["paymentStatus"] == "debt" ? "debt" : "cash"))
              .toString(),
      debtPaymentAmount: _num(json["debtPaymentAmount"]),
      debtPaymentCurrency: (json["debtPaymentCurrency"] ?? "LBP").toString(),
      debtBalanceBeforeLbp: _num(json["debtBalanceBeforeLbp"]),
      debtBalanceBeforeUsd: _num(json["debtBalanceBeforeUsd"]),
      debtPreviousAfterPaymentLbp:
          json.containsKey("debtPreviousAfterPaymentLbp")
          ? _num(json["debtPreviousAfterPaymentLbp"])
          : (afterLbp - invoiceDebtLbp).clamp(0, double.infinity).toDouble(),
      debtPreviousAfterPaymentUsd:
          json.containsKey("debtPreviousAfterPaymentUsd")
          ? _num(json["debtPreviousAfterPaymentUsd"])
          : (afterUsd - invoiceDebtUsd).clamp(0, double.infinity).toDouble(),
      debtBalanceAfterLbp: afterLbp,
      debtBalanceAfterUsd: afterUsd,
      note: (json["note"] ?? "").toString(),
      items: raw is List
          ? raw
                .map(
                  (e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : [],
      createdAt: _date(json["createdAt"]),
      updatedAt: _date(json["updatedAt"]),
    );
  }
}

String _id(dynamic value) {
  if (value is Map) return (value["_id"] ?? value["id"] ?? "").toString();
  return (value ?? "").toString();
}

double _num(dynamic value) => numFromDynamic(value);

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
