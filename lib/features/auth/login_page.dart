import "package:flutter/material.dart";
import "../../core/app_controller.dart";
import "../../core/api_client.dart";
import "../../core/session_store.dart";
import "../admin/admin_page.dart";
import "../home/home_page.dart";

class LoginPage extends StatefulWidget {
  final ApiClient api;
  final SessionStore sessionStore;

  const LoginPage({
    super.key,
    required this.api,
    required this.sessionStore,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool loading = false;
  String? error;

  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await widget.api.post("/auth/login", {
        "email": email.text.trim(),
        "password": password.text.trim(),
      });
      final user = Map<String, dynamic>.from(data["user"] as Map);
      final role = (user["role"] ?? "owner").toString();

      await widget.sessionStore.saveSession(
        token: data["token"].toString(),
        name: (user["name"] ?? "").toString(),
        email: (user["email"] ?? "").toString(),
        role: role,
      );

      if (!mounted) return;
      await AppScope.of(context).loadSettings();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == "admin" ? AdminPage(api: widget.api, sessionStore: widget.sessionStore) : HomePage(api: widget.api, sessionStore: widget.sessionStore),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final logoHeight = compact ? 132.0 : 168.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(18, compact ? 14 : 28, 18, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - (compact ? 28 : 52)),
                child: Center(
                  child: SizedBox(
                    width: 430,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 20 : 26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                "assets/brand/daftr_logo.jpeg",
                                height: logoHeight,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => CircleAvatar(
                                  radius: 48,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Icon(Icons.account_balance_wallet_rounded, size: 48, color: theme.colorScheme.primary),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 12 : 18),
                            Text(c.t("app"), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0)),
                            SizedBox(height: compact ? 14 : 18),
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(labelText: c.t("email"), prefixIcon: const Icon(Icons.email)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: password,
                              obscureText: true,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(labelText: c.t("password"), prefixIcon: const Icon(Icons.lock)),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(error!, style: TextStyle(color: theme.colorScheme.error), softWrap: true),
                              ),
                            ],
                            SizedBox(height: compact ? 14 : 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: loading ? null : submit,
                                child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(c.t("login")),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
