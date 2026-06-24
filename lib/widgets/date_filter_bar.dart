import "package:flutter/material.dart";

enum DateFilterPreset { today, week, month, custom }

class DateFilterValue {
  final DateFilterPreset preset;
  final DateTimeRange? customRange;

  const DateFilterValue({required this.preset, this.customRange});

  DateTimeRange range(DateTime now) {
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return switch (preset) {
      DateFilterPreset.today => DateTimeRange(start: DateTime(now.year, now.month, now.day), end: end),
      DateFilterPreset.week => DateTimeRange(start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)), end: end),
      DateFilterPreset.month => DateTimeRange(start: DateTime(now.year, now.month, 1), end: end),
      DateFilterPreset.custom => customRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: end),
    };
  }

  bool includes(DateTime? value) {
    if (value == null) return false;
    final selected = range(DateTime.now());
    final date = value.toLocal();
    return !date.isBefore(selected.start) && !date.isAfter(selected.end);
  }
}

class DateFilterBar extends StatelessWidget {
  final bool isArabic;
  final DateFilterValue value;
  final ValueChanged<DateFilterValue> onChanged;

  const DateFilterBar({
    super.key,
    required this.isArabic,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(context, DateFilterPreset.today, isArabic ? "\u064a\u0648\u0645" : "Day"),
        _chip(context, DateFilterPreset.week, isArabic ? "\u0623\u0633\u0628\u0648\u0639" : "Week"),
        _chip(context, DateFilterPreset.month, isArabic ? "\u0634\u0647\u0631" : "Month"),
        _chip(context, DateFilterPreset.custom, isArabic ? "\u062a\u0627\u0631\u064a\u062e \u0645\u062e\u0635\u0635" : "Custom date"),
      ],
    );
  }

  Widget _chip(BuildContext context, DateFilterPreset preset, String label) {
    final selected = value.preset == preset;
    final customText = preset == DateFilterPreset.custom && value.customRange != null
        ? "$label: ${_short(value.customRange!.start)} - ${_short(value.customRange!.end)}"
        : label;

    return ChoiceChip(
      selected: selected,
      label: Text(customText),
      avatar: Icon(_icon(preset), size: 18),
      onSelected: (_) async {
        if (preset != DateFilterPreset.custom) {
          onChanged(DateFilterValue(preset: preset));
          return;
        }

        final now = DateTime.now();
        final current = value.customRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 1),
          initialDateRange: current,
        );
        if (picked != null) {
          onChanged(DateFilterValue(preset: DateFilterPreset.custom, customRange: DateTimeRange(start: _startOfDay(picked.start), end: _endOfDay(picked.end))));
        }
      },
    );
  }

  IconData _icon(DateFilterPreset preset) {
    return switch (preset) {
      DateFilterPreset.today => Icons.today_rounded,
      DateFilterPreset.week => Icons.view_week_rounded,
      DateFilterPreset.month => Icons.calendar_month_rounded,
      DateFilterPreset.custom => Icons.date_range_rounded,
    };
  }

  String _short(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
  }

  DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) => DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}
