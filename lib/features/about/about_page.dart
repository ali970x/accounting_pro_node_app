import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/api_client.dart";
import "../../core/app_controller.dart";
import "../../core/app_version.dart";
import "../../core/phone_text.dart";
import "../../core/text_download.dart";
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
    final notes = _releaseNotes;

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
                    child: _infoRow(_label(isAr, "Contact", "\u0644\u0644\u062a\u0648\u0627\u0635\u0644"), phone, Icons.phone_rounded, const Color(0xFF00A6A6), isPhone: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _developerCard(),
            const SizedBox(height: 16),
            _feedbackCard(isAr),
            const SizedBox(height: 16),
            _updatesCard(isAr, version, notes),
          ],
        ],
      ),
    );
  }

  Widget _developerCard() {
    final theme = Theme.of(context);
    const developerPhone = "+96176652276";
    const developerMail = "alimjdandash@gmail.com";
    return ModernCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF5B5FEF)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.code_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("About the Developer", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    Text("Ali Dandash", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Web Apps / Mobile Apps / Accounting Systems / Dashboards / Desktop Applications",
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            "Works with almost any modern technology depending on the project needs.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(
            "This accounting system was designed and developed from scratch to help businesses manage their finances faster, smarter, and more professionally.",
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.45),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onLongPress: () => _openWhatsapp(developerPhone),
            child: _infoRow("WhatsApp", developerPhone, Icons.chat_rounded, const Color(0xFF00A884), isPhone: true),
          ),
          const Divider(height: 24),
          GestureDetector(
            onLongPress: () => _copyText(developerMail),
            child: _infoRow("Email", developerMail, Icons.mail_rounded, const Color(0xFF5B5FEF)),
          ),
        ],
      ),
    );
  }

  Widget _feedbackCard(bool isAr) {
    final theme = Theme.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF00A6A6).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.feedback_rounded, color: Color(0xFF008B8B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isAr ? "رأيك واقتراحاتك" : "Feedback & Suggestions", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text(
                  isAr ? "اكتب ملاحظة أو فكرة جديدة لتصل مباشرة إلى المطور." : "Send a note or feature idea directly to the developer.",
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _openFeedbackDialog,
            tooltip: isAr ? "إرسال رأي" : "Send feedback",
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value, IconData icon, Color iconColor, {bool isPhone = false}) {
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
        isPhone
            ? PhoneText(value, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: iconColor))
            : Text(value, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: iconColor)),
      ],
    );
  }

  Widget _updatesCard(bool isAr, String version, List<Map<String, dynamic>> notes) {
    final latest = notes.isEmpty ? null : notes.first;
    final latestChanges = latest == null ? const <dynamic>[] : (latest["changes"] is List ? latest["changes"] as List : const <dynamic>[]);

    return ModernCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_alt_rounded, color: Color(0xFF5B5FEF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _label(isAr, "Updates", "\u0627\u0644\u062a\u062d\u062f\u064a\u062b\u0627\u062a"),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _label(isAr, "Current version", "\u0627\u0644\u0625\u0635\u062f\u0627\u0631 \u0627\u0644\u062d\u0627\u0644\u064a") + ": $version",
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (latest != null) ...[
            const SizedBox(height: 8),
            Text(
              "${_label(isAr, "Latest changes", "\u0622\u062e\u0631 \u0627\u0644\u062a\u0639\u062f\u064a\u0644\u0627\u062a")} (${latest["version"] ?? version})",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            for (final change in latestChanges.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("- ${change.toString()}", style: const TextStyle(height: 1.25)),
              ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _checkForUpdate,
                icon: const Icon(Icons.update_rounded),
                label: Text(_label(isAr, "Check for update", "\u0641\u062d\u0635 \u0627\u0644\u062a\u062d\u062f\u064a\u062b")),
              ),
              OutlinedButton.icon(
                onPressed: () => _downloadUpdatesTxt(version),
                icon: const Icon(Icons.description_rounded),
                label: Text(_label(isAr, "Download TXT", "\u062a\u0646\u0632\u064a\u0644 TXT")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _releaseNotes {
    final raw = _data["releaseNotes"];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [
      {
        "version": AppVersion.display,
        "date": "2026-06-23",
        "changes": ["About page update history and check for update."]
      }
    ];
  }

  String _updatesText(String version) {
    final buffer = StringBuffer()
      ..writeln("Accounting Pro")
      ..writeln("Current version: $version")
      ..writeln("Generated: ${DateTime.now().toString().substring(0, 16)}")
      ..writeln("");

    for (final note in _releaseNotes) {
      buffer.writeln("Version ${note["version"] ?? ""} - ${note["date"] ?? ""}");
      final changes = note["changes"];
      if (changes is List) {
        for (final change in changes) {
          buffer.writeln("- ${change.toString()}");
        }
      }
      buffer.writeln("");
    }
    return buffer.toString();
  }

  Future<void> _downloadUpdatesTxt(String version) async {
    final isAr = AppScope.of(context).isArabic;
    final text = _updatesText(version);
    final filename = "accounting-pro-updates-v$version.txt";
    final downloaded = await downloadTextFile(filename: filename, content: text);
    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(downloaded ? _label(isAr, "TXT file downloaded.", "\u062a\u0645 \u062a\u0646\u0632\u064a\u0644 \u0645\u0644\u0641 TXT.") : _label(isAr, "TXT copied to clipboard.", "\u062a\u0645 \u0646\u0633\u062e \u0645\u0644\u0641 TXT \u0644\u0644\u062d\u0627\u0641\u0638\u0629.")),
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    final isAr = AppScope.of(context).isArabic;
    try {
      final res = await widget.api.get("/about");
      final data = Map<String, dynamic>.from(res as Map);
      if (mounted) setState(() => _data = data);

      final latest = (data["latestVersion"] ?? data["version"] ?? AppVersion.display).toString();
      final updateUrl = (data["updateUrl"] ?? "").toString();
      if (!_isNewerVersion(latest, AppVersion.display)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_label(isAr, "You already have the latest version.", "\u0639\u0646\u062f\u0643 \u0622\u062e\u0631 \u0625\u0635\u062f\u0627\u0631."))),
        );
        return;
      }

      if (!mounted) return;
      final download = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_label(isAr, "Update available", "\u064a\u0648\u062c\u062f \u062a\u062d\u062f\u064a\u062b")),
          content: Text(_label(isAr, "Version $latest is available. Download it now?", "\u0627\u0644\u0625\u0635\u062f\u0627\u0631 $latest \u0645\u062a\u0627\u062d. \u0628\u062f\u0643 \u062a\u062d\u0645\u0644\u0647 \u0647\u0644\u0623\u061f")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_label(isAr, "Cancel", "\u0625\u0644\u063a\u0627\u0621"))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_label(isAr, "Download", "\u062a\u062d\u0645\u064a\u0644"))),
          ],
        ),
      );
      if (download == true) await _downloadUpdate(updateUrl, latest);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _downloadUpdate(String updateUrl, String version) async {
    final isAr = AppScope.of(context).isArabic;
    if (updateUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_label(isAr, "No download link is configured.", "\u0644\u0627 \u064a\u0648\u062c\u062f \u0631\u0627\u0628\u0637 \u062a\u062d\u0645\u064a\u0644 \u0645\u0636\u0628\u0648\u0637."))),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 14),
            Expanded(child: Text(_label(isAr, "Downloading update...", "\u062c\u0627\u0631\u064a \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u062d\u062f\u064a\u062b..."))),
          ],
        ),
      ),
    );
    try {
      final uri = Uri.parse(updateUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_label(isAr, "Ready to install", "\u062c\u0627\u0647\u0632 \u0644\u0644\u062a\u062b\u0628\u064a\u062a")),
        content: Text(_label(isAr, "When the download finishes, open the downloaded file and install version $version.", "\u0628\u0633 \u064a\u062e\u0644\u0635 \u0627\u0644\u062a\u062d\u0645\u064a\u0644\u060c \u0627\u0641\u062a\u062d \u0627\u0644\u0645\u0644\u0641 \u0648\u062b\u0628\u062a \u0627\u0644\u0625\u0635\u062f\u0627\u0631 $version.")),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(_label(isAr, "OK", "\u062a\u0645"))),
        ],
      ),
    );
  }

  bool _isNewerVersion(String remote, String local) {
    final r = remote.split(".").map((x) => int.tryParse(x) ?? 0).toList();
    final l = local.split(".").map((x) => int.tryParse(x) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  Future<void> _openFeedbackDialog() async {
    final isAr = AppScope.of(context).isArabic;
    final name = TextEditingController();
    final message = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? "إرسال رأي أو اقتراح" : "Send Feedback"),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: InputDecoration(labelText: isAr ? "اسمك اختياري" : "Your name (optional)")),
              const SizedBox(height: 12),
              TextField(
                controller: message,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(labelText: isAr ? "رأيك أو اقتراحك" : "Feedback or suggestion"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? "إلغاء" : "Cancel")),
          FilledButton(
            onPressed: () {
              final text = message.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, {"name": name.text.trim(), "message": text});
            },
            child: Text(isAr ? "إرسال" : "Send"),
          ),
        ],
      ),
    );
    name.dispose();
    message.dispose();
    if (result == null) return;

    final sender = result["name"]?.trim().isEmpty == false ? result["name"]!.trim() : "Accounting Pro user";
    final body = "Sender: $sender\nVersion: ${AppVersion.display}\n\n${result["message"] ?? ""}";
    final uri = Uri(
      scheme: "mailto",
      path: "alimjdandash@gmail.com",
      queryParameters: {
        "subject": "Accounting Pro Feedback",
        "body": body,
      },
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: "alimjdandash@gmail.com\n\n$body"));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? "تعذر فتح البريد. تم نسخ الرسالة والإيميل." : "Could not open email. Message and email copied.")),
      );
    }
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

  Future<void> _copyText(String value) async {
    final isAr = AppScope.of(context).isArabic;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_label(isAr, "Copied.", "\u062a\u0645 \u0627\u0644\u0646\u0633\u062e."))),
    );
  }

  String _label(bool isAr, String en, String ar) => isAr ? ar : en;
}
