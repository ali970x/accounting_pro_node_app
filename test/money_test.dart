import "package:daftr/core/money.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parseNumberInput keeps decimal weights from common separators", () {
    expect(parseNumberInput("10.5"), 10.5);
    expect(parseNumberInput("10,5"), 10.5);
    expect(parseNumberInput("١٠٫٥"), 10.5);
    expect(parseNumberInput("١٠٬٥"), 10.5);
  });

  test("numberDecimal does not round a half kilo to the next whole number", () {
    expect(numberDecimal(10.5), "10.5");
    expect(numberDecimal(10.55), "10.55");
    expect(numberDecimal(1000.5), "1,000.5");
  });
}
