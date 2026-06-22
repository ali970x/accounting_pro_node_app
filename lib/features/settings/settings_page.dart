import "package:flutter/material.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../widgets/modern_card.dart";

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
  bool _rateSet = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);

    _selectedLang ??= c.languageCode;
    _selectedTheme ??= c.themeMode;
    if (!_rateSet) {
      _rateController.text = c.exchangeRate.toStringAsFixed(0);
      _rateSet = true;
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(c.t("settings"), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
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
                onSelectionChanged: (value) => setState(() => _selectedLang = value.first),
              ),
              const SizedBox(height: 22),
              _titleRow(Icons.contrast_rounded, c.t("theme")),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.light, label: Text(c.t("light")), icon: const Icon(Icons.light_mode_rounded)),
                  ButtonSegment(value: ThemeMode.dark, label: Text(c.t("dark")), icon: const Icon(Icons.dark_mode_rounded)),
                  ButtonSegment(value: ThemeMode.system, label: Text(c.t("system")), icon: const Icon(Icons.devices_rounded)),
                ],
                selected: {_selectedTheme ?? ThemeMode.light},
                onSelectionChanged: (value) => setState(() => _selectedTheme = value.first),
              ),
              const SizedBox(height: 22),
              _titleRow(Icons.currency_exchange_rounded, c.t("exchangeRate")),
              const SizedBox(height: 10),
              TextField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  suffixText: "LBP",
                  hintText: "90000",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await c.saveSettings(
                        lang: _selectedLang!,
                        theme: _selectedTheme!,
                        rate: double.tryParse(_rateController.text) ?? 90000,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.t("save"))));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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

  Widget _titleRow(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}
