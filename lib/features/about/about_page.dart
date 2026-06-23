import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/app_version.dart";
import "../../widgets/modern_card.dart";

class AboutPage extends StatefulWidget {
  final ApiClient api;
  const AboutPage({super.key, required this.api});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const contactPhone = "+96176652276";
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.api.get("/about");
      _data = Map<String, dynamic>.from(res as Map);
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final isAr = c.isArabic;
    final theme = Theme.of(context);
    final name = (_data["name"] ?? c.t("app")).toString();
    final version = (_data["version"] ?? AppVersion.display).toString();
    final phone = (_data["contactPhone"] ?? contactPhone).toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(c.t("about"), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            ModernCard(child: Text(_error!))
          else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B5FEF), Color(0xFF00A6A6), Color(0xFFFFB020)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.24),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text(name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(
                    isAr
                        ? "\u0625\u062f\u0627\u0631\u0629 \u0645\u0628\u064a\u0639\u0627\u062a\u060c \u0645\u062e\u0632\u0648\u0646\u060c \u062f\u064a\u0648\u0646\u060c \u0645\u0635\u0627\u0631\u064a\u0641 \u0648\u062a\u0642\u0627\u0631\u064a\u0631."
                        : "Sales, inventory, debts, expenses, and reports.",
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.92), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _infoRow(_label(isAr, "Version", "\u0627\u0644\u0625\u0635\u062f\u0627\u0631"), version, Icons.verified_rounded, const Color(0xFF5B5FEF)),
                  const Divider(height: 28),
                  GestureDetector(
                    onLongPress: () => _openWhatsapp(phone),
                    child: _infoRow(_label(isAr, "Contact", "\u0644\u0644\u062a\u0648\u0627\u0635\u0644"), phone, Icons.phone_rounded, const Color(0xFF00A6A6)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value, IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        Text(value, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: iconColor)),
      ],
    );
  }

  Future<void> _openWhatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r"[^0-9]"), "");
    final full = digits.startsWith("961") ? digits : "961$digits";
    final uri = Uri.parse("https://wa.me/$full");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp.")));
    }
  }

  String _label(bool isAr, String en, String ar) => isAr ? ar : en;
}
