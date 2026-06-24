import "package:intl/intl.dart";

String number(num value, {int decimals = 0}) {
  final fraction = decimals > 0 ? List.filled(decimals, "0").join() : "";
  final pattern = decimals > 0 ? "#,##0.$fraction" : "#,##0";
  return NumberFormat(pattern, "en_US").format(value);
}

String money(num value, String currency) {
  final usd = NumberFormat("#,##0.00", "en_US");
  final lbp = NumberFormat("#,##0", "en_US");
  if (currency == "USD") return "\$${usd.format(value)}";
  return "${lbp.format(value)} LBP";
}
