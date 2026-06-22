import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:google_sign_in/google_sign_in.dart";
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
  bool googleLoading = false;
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

      await _openHome();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      googleLoading = true;
      error = null;
    });

    try {
      final credential = kIsWeb ? await _googleWeb() : await _googleNative();
      final user = credential.user;

      if (user == null) {
        throw ApiException("Google sign-in did not return a user.");
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw ApiException("Google token was not returned.");
      }

      final data = await widget.api.post("/auth/google", {
        "idToken": idToken,
      });
      final backendUser = Map<String, dynamic>.from(data["user"] as Map);

      await widget.sessionStore.saveSession(
        token: data["token"].toString(),
        name: (backendUser["name"] ?? user.displayName ?? "Google User").toString(),
        email: (backendUser["email"] ?? user.email ?? "").toString(),
      );

      await _openHome();
    } catch (e) {
      await _safeGoogleSignOut();
      if (mounted) setState(() => error = _googleErrorMessage(e));
    }

    if (mounted) setState(() => googleLoading = false);
  }

  Future<UserCredential> _googleWeb() {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({
        "prompt": "select_account",
      });

    return FirebaseAuth.instance.signInWithPopup(provider);
  }

  Future<UserCredential> _googleNative() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw ApiException("Google sign-in was cancelled.");
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
  }

  Future<void> _openHome() async {
    if (!mounted) return;
    await AppScope.of(context).loadSettings();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(api: widget.api, sessionStore: widget.sessionStore)),
    );
  }

  String _googleErrorMessage(Object error) {
    final text = error.toString();

    if (text.contains("popup-closed-by-user") || text.contains("cancelled")) {
      return "Google sign-in was cancelled.";
    }
    if (text.contains("popup-blocked")) {
      return "Popup was blocked. Allow popups and try again.";
    }
    if (text.contains("unauthorized-domain")) {
      return "This domain is not allowed in Firebase Authentication.";
    }
    if (text.contains("Failed to fetch") || text.contains("SocketException") || text.contains("network")) {
      return "Cannot reach the server. Make sure the server is running and the device is on the same Wi-Fi.";
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final busy = loading || googleLoading;

    return Scaffold(
      body: Center(
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(22),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 42, child: Icon(Icons.account_balance_wallet_rounded, size: 42)),
                  const SizedBox(height: 18),
                  Text(c.t("app"), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
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
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isLogin ? c.t("login") : c.t("register")),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : signInWithGoogle,
                      icon: googleLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                      label: const Text("Sign in with Google"),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => isLogin = !isLogin),
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
