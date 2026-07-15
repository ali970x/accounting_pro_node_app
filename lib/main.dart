import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "core/api_client.dart";
import "core/app_controller.dart";
import "core/session_store.dart";
import "core/smart_import_inbox.dart";
import "features/admin/admin_page.dart";
import "features/auth/login_page.dart";
import "features/home/home_page.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaftrApp());
}

class DaftrApp extends StatefulWidget {
  const DaftrApp({super.key});

  @override
  State<DaftrApp> createState() => _DaftrAppState();
}

class _DaftrAppState extends State<DaftrApp> {
  late final SessionStore _sessionStore;
  late final ApiClient _api;
  late final AppController _controller;
  static const _shareChannel = MethodChannel("daftr/share");

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore();
    _api = ApiClient(_sessionStore);
    _controller = AppController(api: _api, sessionStore: _sessionStore);
    Future.microtask(_controller.loadSettings);
    _setupShareChannel();
  }

  Future<void> _setupShareChannel() async {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == "sharedText") {
        SmartImportInbox.put((call.arguments ?? "").toString());
      }
    });
    try {
      final initial = await _shareChannel.invokeMethod<String>(
        "getInitialSharedText",
      );
      if (initial != null) SmartImportInbox.put(initial);
    } catch (_) {
      // Sharing integration is Android-only; other platforms can ignore it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "daftr",
            themeMode: _controller.themeMode,
            theme: _theme(_controller, Brightness.light),
            darkTheme: _theme(_controller, Brightness.dark),
            home: _StartupPage(api: _api, sessionStore: _sessionStore),
          );
        },
      ),
    );
  }

  ThemeData _theme(AppController controller, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: controller.accent,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101418)
          : const Color(0xFFF5F7FB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF101418)
            : const Color(0xFFF5F7FB),
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withOpacity(0.24)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

class _StartupPage extends StatefulWidget {
  final ApiClient api;
  final SessionStore sessionStore;

  const _StartupPage({required this.api, required this.sessionStore});

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
  String? _status;

  @override
  void initState() {
    super.initState();
    Future.microtask(_openInitialPage);
  }

  Future<void> _openInitialPage() async {
    final isLoggedIn = await widget.sessionStore.isLoggedIn();
    if (!isLoggedIn) {
      _replace(LoginPage(api: widget.api, sessionStore: widget.sessionStore));
      return;
    }

    try {
      final data = await widget.api.get("/auth/me");
      final user = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final token = await widget.sessionStore.getToken();
      final storedName = await widget.sessionStore.getName();
      final storedEmail = await widget.sessionStore.getEmail();
      final storedRole = await widget.sessionStore.getRole();
      if (token != null && token.isNotEmpty) {
        await widget.sessionStore.saveSession(
          token: token,
          name: (user["name"] ?? storedName ?? "").toString(),
          email: (user["email"] ?? storedEmail ?? "").toString(),
          role: (user["role"] ?? storedRole ?? "owner").toString(),
        );
      }

      if (!mounted) return;
      final role = (user["role"] ?? storedRole ?? "owner").toString();
      _replace(
        role == "admin"
            ? AdminPage(api: widget.api, sessionStore: widget.sessionStore)
            : HomePage(api: widget.api, sessionStore: widget.sessionStore),
      );
    } catch (_) {
      await widget.sessionStore.clear();
      if (!mounted) return;
      setState(() => _status = "Login again to continue.");
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _replace(LoginPage(api: widget.api, sessionStore: widget.sessionStore));
    }
  }

  void _replace(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    "assets/brand/daftr_logo.jpeg",
                    width: 190,
                    height: 190,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 104,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "daftr",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 14),
                Text(
                  _status ?? "Preparing daftr...",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
