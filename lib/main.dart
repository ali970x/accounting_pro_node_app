import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";
import "core/api_client.dart";
import "core/session_store.dart";
import "core/app_controller.dart";
import "firebase_options.dart";
import "features/auth/login_page.dart";
import "features/home/home_page.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final sessionStore = SessionStore();
  final api = ApiClient(sessionStore);
  final controller = AppController(api: api, sessionStore: sessionStore);

  final isLoggedIn = await sessionStore.isLoggedIn();
  if (isLoggedIn) {
    await controller.loadSettings();
  }

  runApp(AccountingProApp(
    api: api,
    sessionStore: sessionStore,
    controller: controller,
    isLoggedIn: isLoggedIn,
  ));
}

class AccountingProApp extends StatelessWidget {
  final ApiClient api;
  final SessionStore sessionStore;
  final AppController controller;
  final bool isLoggedIn;

  const AccountingProApp({
    super.key,
    required this.api,
    required this.sessionStore,
    required this.controller,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            title: "Accounting Pro",
            debugShowCheckedModeBanner: false,
            themeMode: controller.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF5B5FEF),
                brightness: Brightness.light,
                primary: const Color(0xFF5B5FEF),
                secondary: const Color(0xFF00A6A6),
                tertiary: const Color(0xFFFFB020),
                surface: Colors.white,
              ),
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF4F7FB),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: Color(0xFFF4F7FB),
                foregroundColor: Color(0xFF111827),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B5FEF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFFFB020),
                foregroundColor: Color(0xFF1F2937),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF5B5FEF), width: 1.5)),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7C83FF),
                brightness: Brightness.dark,
                primary: const Color(0xFF9EA3FF),
                secondary: const Color(0xFF20D0C4),
                tertiary: const Color(0xFFFFC15A),
              ),
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF10131A),
              appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Color(0xFF10131A)),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(width: 1.5)),
              ),
            ),
            builder: (context, child) {
              return Directionality(
                textDirection: controller.isArabic ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox(),
              );
            },
            home: isLoggedIn
                ? HomePage(api: api, sessionStore: sessionStore)
                : LoginPage(api: api, sessionStore: sessionStore),
          );
        },
      ),
    );
  }
}
