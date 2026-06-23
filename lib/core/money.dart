import "package:intl/intl.dart";

String money(num value, String currency) {
  final usd = NumberFormat("#,##0.00", "en_US");
  final lbp = NumberFormat("#,##0", "en_US");
  if (currency == "USD") return "\$${usd.format(value)}";
  return "${lbp.format(value)} LBP";
}
