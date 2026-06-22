String money(num value, String currency) {
  if (currency == "USD") return "\$${value.toStringAsFixed(2)}";
  return "${value.toStringAsFixed(0)} LBP";
}
