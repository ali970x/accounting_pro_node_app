import "package:daftr/widgets/date_filter_bar.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  final now = DateTime(2026, 7, 4, 14, 30);

  test("week includes today and the previous six days", () {
    const filter = DateFilterValue(preset: DateFilterPreset.week);

    expect(filter.includes(DateTime(2026, 7, 4, 10), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 6, 28, 23, 59), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 6, 27, 23, 59), now: now), isFalse);
  });

  test("month includes the current week and day", () {
    const filter = DateFilterValue(preset: DateFilterPreset.month);

    expect(filter.includes(DateTime(2026, 7, 1), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 7, 4, 23, 59), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 6, 30, 23, 59), now: now), isFalse);
  });

  test("custom range includes all days between start and end", () {
    final filter = DateFilterValue(
      preset: DateFilterPreset.custom,
      customRange: DateTimeRange(
        start: DateTime(2026, 6, 20, 14),
        end: DateTime(2026, 6, 22, 9),
      ),
    );

    expect(filter.includes(DateTime(2026, 6, 20), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 6, 21, 12), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 6, 22, 23, 59), now: now), isTrue);
    expect(filter.includes(DateTime(2026, 6, 23), now: now), isFalse);
  });
}
