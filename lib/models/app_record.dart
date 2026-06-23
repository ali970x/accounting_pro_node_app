class AppRecord {
  final String id;
  final String type;
  final String message;
  final String productName;
  final double oldQuantity;
  final double newQuantity;
  final double difference;
  final String reason;
  final String customerName;
  final String supplierName;
  final double totalCost;
  final String currency;
  final String paymentStatus;
  final String invoiceNo;
  final DateTime? createdAt;

  const AppRecord({
    required this.id,
    required this.type,
    required this.message,
    required this.productName,
    required this.oldQuantity,
    required this.newQuantity,
    required this.difference,
    required this.reason,
    required this.customerName,
    required this.supplierName,
    required this.totalCost,
    required this.currency,
    required this.paymentStatus,
    required this.invoiceNo,
    required this.createdAt,
  });

  factory AppRecord.fromLog(Map<String, dynamic> json) {
    return AppRecord(
      id: (json["_id"] ?? "").toString(),
      type: (json["type"] ?? "").toString(),
      message: (json["message"] ?? "").toString(),
      productName: "",
      oldQuantity: 0,
      newQuantity: 0,
      difference: 0,
      reason: "",
      customerName: "",
      supplierName: "",
      totalCost: 0,
      currency: "LBP",
      paymentStatus: "",
      invoiceNo: "",
      createdAt: _date(json["createdAt"]),
    );
  }

  factory AppRecord.fromMovement(Map<String, dynamic> json) {
    return AppRecord(
      id: (json["_id"] ?? "").toString(),
      type: (json["type"] ?? "").toString(),
      message: "",
      productName: (json["productName"] ?? "").toString(),
      oldQuantity: _num(json["oldQuantity"]),
      newQuantity: _num(json["newQuantity"]),
      difference: _num(json["difference"]),
      reason: (json["reason"] ?? "").toString(),
      customerName: (json["customerName"] ?? "").toString(),
      supplierName: (json["supplierName"] ?? "").toString(),
      totalCost: _num(json["totalCost"]),
      currency: (json["currency"] ?? "LBP").toString(),
      paymentStatus: (json["paymentStatus"] ?? "").toString(),
      invoiceNo: (json["invoiceNo"] ?? "").toString(),
      createdAt: _date(json["createdAt"]),
    );
  }
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
