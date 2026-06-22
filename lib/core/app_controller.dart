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
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveSettings({
    required String lang,
    required ThemeMode theme,
    required double rate,
  }) async {
    languageCode = lang;
    themeMode = theme;
    exchangeRate = rate;
    notifyListeners();

    await api.put("/settings", {
      "languageCode": lang,
      "themeMode": theme.name,
      "exchangeRate": rate,
    });
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
