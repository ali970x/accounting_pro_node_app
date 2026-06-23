import "package:flutter/material.dart";
import "../../core/app_controller.dart";
import "../../core/api_client.dart";
import "../../core/session_store.dart";
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
  bool isLogin = true;
  bool loading = false;
  String? error;

  final name = TextEditingController(text: "Aya");
  final email = TextEditingController(text: "aya@test.com");
  final password = TextEditingController(text: "123456");

  @override
  void dispose() {
    name.dispose();
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
      final path = isLogin ? "/auth/login" : "/auth/register";
      final body = {
        if (!isLogin) "name": name.text.trim(),
        "email": email.text.trim(),
        "password": password.text.trim(),
      };

      final data = await widget.api.post(path, body);
      final user = Map<String, dynamic>.from(data["user"] as Map);

      await widget.sessionStore.saveSession(
        token: data["token"].toString(),
        name: (user["name"] ?? "").toString(),
        email: (user["email"] ?? "").toString(),
      );

      if (!mounted) return;
      await AppScope.of(context).loadSettings();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(api: widget.api, sessionStore: widget.sessionStore)),
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
      body: Center(
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(22),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.account_balance_wallet_rounded, size: 42, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 18),
                  Text(c.t("app"), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  if (!isLogin) ...[
                    TextField(controller: name, decoration: InputDecoration(labelText: c.t("name"), prefixIcon: const Icon(Icons.person))),
                    const SizedBox(height: 12),
                  ],
                  TextField(controller: email, decoration: InputDecoration(labelText: c.t("email"), prefixIcon: const Icon(Icons.email))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: c.t("password"), prefixIcon: const Icon(Icons.lock))),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : submit,
                      child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isLogin ? c.t("login") : c.t("register")),
                    ),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? c.t("register") : c.t("login")),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
