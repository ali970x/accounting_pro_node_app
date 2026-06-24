import "package:flutter/material.dart";
import "api_client.dart";
import "session_store.dart";
import "app_text.dart";

class AppController extends ChangeNotifier {
  final ApiClient api;
  final SessionStore sessionStore;

  String languageCode = "en";
  ThemeMode themeMode = ThemeMode.light;
  double exchangeRate = 90000;
  String accentColor = "#0F766E";

  AppController({
    required this.api,
    required this.sessionStore,
  });

  String t(String key) => AppText.get(languageCode, key);

  bool get isArabic => languageCode == "ar";

  Future<void> loadSettings() async {
    try {
      final data = await api.get("/settings");
      languageCode = (data["languageCode"] ?? "en").toString();
      final theme = (data["themeMode"] ?? "light").toString();
      themeMode = switch (theme) {
        "dark" => ThemeMode.dark,
        "system" => ThemeMode.system,
        _ => ThemeMode.light,
      };
      final rate = data["exchangeRate"];
      exchangeRate = rate is num ? rate.toDouble() : double.tryParse("$rate") ?? 90000;
      accentColor = (data["accentColor"] ?? "#0F766E").toString();
      notifyListeners();
    } catch (_) {}
  }

  Color get accent => _colorFromHex(accentColor);

  Future<void> saveSettings({
    required String lang,
    required ThemeMode theme,
    required double rate,
    required String accent,
  }) async {
    languageCode = lang;
    themeMode = theme;
    exchangeRate = rate;
    accentColor = accent;
    notifyListeners();

    await api.put("/settings", {
      "languageCode": lang,
      "themeMode": theme.name,
      "accentColor": accent,
      "exchangeRate": rate,
    });
  }

  Color _colorFromHex(String value) {
    var clean = value.replaceAll("#", "").trim();
    if (clean.length == 6) clean = "FF$clean";
    final parsed = int.tryParse(clean, radix: 16);
    return Color(parsed ?? 0xFF0F766E);
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null || scope.notifier == null) {
      throw FlutterError("AppScope not found");
    }
    return scope.notifier!;
  }
}
