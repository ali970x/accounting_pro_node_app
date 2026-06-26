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

double parseNumberInput(String value, {double fallback = 0}) {
  var clean = _normalizeNumericText(
    value,
  ).replaceAll(RegExp(r"\s+"), "").replaceAll(RegExp(r"[^0-9,.\-]"), "");

  if (clean.isEmpty || clean == "-") return fallback;

  final isNegative = clean.startsWith("-");
  clean = clean.replaceAll("-", "");
  if (clean.isEmpty) return fallback;

  final commaIndex = clean.lastIndexOf(",");
  final dotIndex = clean.lastIndexOf(".");
  late String normalized;

  if (commaIndex >= 0 && dotIndex >= 0) {
    final decimalSeparator = commaIndex > dotIndex ? "," : ".";
    final groupingSeparator = decimalSeparator == "," ? "." : ",";
    normalized = clean.replaceAll(groupingSeparator, "");
    if (decimalSeparator == ",") normalized = normalized.replaceAll(",", ".");
  } else if (commaIndex >= 0) {
    normalized = _normalizeSingleSeparator(clean, ",");
  } else if (dotIndex >= 0) {
    normalized = _normalizeSingleSeparator(clean, ".");
  } else {
    normalized = clean;
  }

  if (isNegative) normalized = "-$normalized";
  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed;
}

double numFromDynamic(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value == null) return fallback;
  return parseNumberInput(value.toString(), fallback: fallback);
}

String _normalizeSingleSeparator(String text, String separator) {
  final parts = text.split(separator);
  if (parts.length <= 1) return text;

  if (parts.length > 2) {
    if (_looksLikeGroupedNumber(parts)) return parts.join();
    final last = parts.removeLast();
    return "${parts.join()}.$last";
  }

  final whole = parts[0];
  final tail = parts[1];
  if (tail.isEmpty) return whole;
  if (tail.length == 3 && whole.isNotEmpty) return whole + tail;
  if (tail.length <= 2) return "$whole.$tail";
  return whole + tail;
}

bool _looksLikeGroupedNumber(List<String> parts) {
  if (parts.length < 2 || parts.first.isEmpty || parts.first.length > 3) {
    return false;
  }
  for (final part in parts.skip(1)) {
    if (part.length != 3) return false;
  }
  return true;
}

String _normalizeNumericText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune == 0x066B) {
      buffer.write(".");
    } else if (rune == 0x066C) {
      buffer.write(",");
    } else if (rune == 0x2212 || rune == 0x2013 || rune == 0x2014) {
      buffer.write("-");
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
