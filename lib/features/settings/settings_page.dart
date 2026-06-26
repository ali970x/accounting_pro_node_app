import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/money.dart";
import "../../widgets/modern_card.dart";
import "../../widgets/page_header.dart";

class SettingsPage extends StatefulWidget {
  final ApiClient api;
  const SettingsPage({super.key, required this.api});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _rateController = TextEditingController();
  String? _selectedLang;
  ThemeMode? _selectedTheme;
  String? _selectedAccent;
  bool _rateSet = false;

  static const _accents = [
    _Accent("#0F766E", "Emerald"),
    _Accent("#2563EB", "Blue"),
    _Accent("#7C3AED", "Violet"),
    _Accent("#B45309", "Gold"),
    _Accent("#DC2626", "Red"),
    _Accent("#111827", "Graphite"),
  ];

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;

    _selectedLang ??= c.languageCode;
    _selectedTheme ??= c.themeMode;
    _selectedAccent ??= c.accentColor;
    if (!_rateSet) {
      _rateController.text = number(c.exchangeRate);
      _rateSet = true;
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        PageHeader(title: c.t("settings")),
        const SizedBox(height: 14),
        ModernCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleRow(Icons.language_rounded, c.t("language")),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: "en", label: Text(c.t("english"))),
                  ButtonSegment(value: "ar", label: Text(c.t("arabic"))),
                ],
                selected: {_selectedLang ?? "en"},
                onSelectionChanged: (value) =>
                    setState(() => _selectedLang = value.first),
              ),
              const SizedBox(height: 22),
              _titleRow(Icons.contrast_rounded, c.t("theme")),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _themeChip(
                    ThemeMode.light,
                    c.t("light"),
                    Icons.light_mode_rounded,
                  ),
                  _themeChip(
                    ThemeMode.dark,
                    c.t("dark"),
                    Icons.dark_mode_rounded,
                  ),
                  _themeChip(
                    ThemeMode.system,
                    c.t("system"),
                    Icons.devices_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _titleRow(
                Icons.palette_rounded,
                isAr
                    ? "\u0644\u0648\u0646 \u0627\u0644\u062a\u0637\u0628\u064a\u0642"
                    : "App color",
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final accent in _accents) _accentChip(accent)],
              ),
              const SizedBox(height: 22),
              _titleRow(Icons.currency_exchange_rounded, c.t("exchangeRate")),
              const SizedBox(height: 10),
              TextField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                onEditingComplete: _normalizeRateInput,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  suffixText: "LBP",
                  hintText: "90,000",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      final parsedRate = _parseNumber(
                        _rateController.text,
                        fallback: 90000,
                      );
                      await c.saveSettings(
                        lang: _selectedLang!,
                        theme: _selectedTheme!,
                        accent: _selectedAccent!,
                        rate: parsedRate.toDouble(),
                      );
                      _rateController.text = number(parsedRate);
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(c.t("save"))));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(c.t("save")),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _normalizeRateInput() {
    final c = AppScope.of(context);
    final parsed = _parseNumber(_rateController.text, fallback: c.exchangeRate);
    _rateController.text = number(parsed);
    FocusScope.of(context).unfocus();
  }

  Widget _themeChip(ThemeMode mode, String label, IconData icon) {
    final selected = _selectedTheme == mode;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => setState(() => _selectedTheme = mode),
    );
  }

  Widget _accentChip(_Accent accent) {
    final color = _colorFromHex(accent.hex);
    final selected = _selectedAccent == accent.hex;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedAccent = accent.hex),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.18),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                accent.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ],
    );
  }

  num _parseNumber(String value, {required num fallback}) {
    return parseNumberInput(value, fallback: fallback.toDouble());
  }

  Color _colorFromHex(String value) {
    var clean = value.replaceAll("#", "").trim();
    if (clean.length == 6) clean = "FF$clean";
    return Color(int.tryParse(clean, radix: 16) ?? 0xFF0F766E);
  }
}

class _Accent {
  final String hex;
  final String name;
  const _Accent(this.hex, this.name);
}
