import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:4000',
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Production App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xfff6f8fb),
      ),
      home: const StartupPage(),
    );
  }
}

class ApiResult {
  final bool ok;
  final int statusCode;
  final String message;
  final dynamic data;

  ApiResult({
    required this.ok,
    required this.statusCode,
    required this.message,
    this.data,
  });
}

class ApiService {
  static Uri url(String path) {
    return Uri.parse('$apiBaseUrl$path');
  }

  static Map<String, String> headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static ApiResult parseResponse(http.Response response) {
    dynamic decodedBody;

    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = response.body;
    }

    String message = 'Request completed';

    if (decodedBody is Map && decodedBody['message'] != null) {
      message = decodedBody['message'].toString();
    } else if (response.body.isNotEmpty) {
      message = response.body;
    }

    return ApiResult(
      ok: response.statusCode >= 200 && response.statusCode < 300,
      statusCode: response.statusCode,
      message: message,
      data: decodedBody,
    );
  }

  static Future<ApiResult> get(String path, {String? token}) async {
    try {
      final response = await http.get(
        url(path),
        headers: headers(token: token),
      );

      return parseResponse(response);
    } catch (error) {
      return ApiResult(
        ok: false,
        statusCode: 0,
        message: 'Cannot connect to API: $error',
      );
    }
  }

  static Future<ApiResult> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final response = await http.post(
        url(path),
        headers: headers(token: token),
        body: jsonEncode(body),
      );

      return parseResponse(response);
    } catch (error) {
      return ApiResult(
        ok: false,
        statusCode: 0,
        message: 'Cannot connect to API: $error',
      );
    }
  }
}

class AuthSession {
  static const String tokenKey = 'auth_token';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';

  static Future<void> save({
    required String token,
    required String userName,
    required String userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(userNameKey, userName);
    await prefs.setString(userEmailKey, userEmail);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userNameKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userNameKey);
    await prefs.remove(userEmailKey);
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    final token = await AuthSession.getToken();

    if (token == null || token.isEmpty) {
      goToAuth();
      return;
    }

    final result = await ApiService.get('/api/me', token: token);

    if (!mounted) return;

    if (result.ok && result.data is Map && result.data['user'] is Map) {
      final user = result.data['user'] as Map;
      final name = user['name']?.toString() ?? 'User';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(userName: name),
        ),
      );
    } else {
      await AuthSession.clear();
      goToAuth();
    }
  }

  void goToAuth() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool isLoading = false;
  String message = '';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> checkApi() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    final result = await ApiService.get('/health');

    setState(() {
      isLoading = false;
      message = result.ok ? 'API is working: ${result.message}' : result.message;
    });
  }

  Future<void> submit() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!isLogin && name.isEmpty) {
      setState(() => message = 'Name is required');
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      setState(() => message = 'Email and password are required');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    final endpoint = isLogin ? '/api/auth/login' : '/api/auth/register';

    final result = await ApiService.post(endpoint, {
      if (!isLogin) 'name': name,
      'email': email,
      'password': password,
    });

    setState(() {
      isLoading = false;
      message = result.message;
    });

    if (!result.ok) return;

    if (result.data is! Map) {
      setState(() => message = 'Invalid API response');
      return;
    }

    final data = result.data as Map;
    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      setState(() => message = 'Token missing from API response');
      return;
    }

    final user = data['user'];

    String userName = email;
    String userEmail = email;

    if (user is Map) {
      userName = user['name']?.toString() ?? email;
      userEmail = user['email']?.toString() ?? email;
    }

    await AuthSession.save(
      token: token,
      userName: userName,
      userEmail: userEmail,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(userName: userName),
      ),
    );
  }

  void continueDemo() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardPage(userName: 'Demo User'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 25,
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 54,
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                Text(
                  isLogin ? 'Login' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'API: $apiBaseUrl',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                if (!isLogin)
                  AppTextField(
                    controller: nameController,
                    label: 'Name',
                    icon: Icons.person_outline,
                  ),
                if (!isLogin) const SizedBox(height: 14),
                AppTextField(
                  controller: emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: isLoading ? null : submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isLogin ? 'Login' : 'Register'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            isLogin = !isLogin;
                            message = '';
                          });
                        },
                  child: Text(
                    isLogin
                        ? 'Need an account? Register'
                        : 'Already have an account? Login',
                  ),
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : checkApi,
                        icon: const Icon(Icons.cloud_done_outlined),
                        label: const Text('Check API'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : continueDemo,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Demo'),
                      ),
                    ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String userName;

  const DashboardPage({
    super.key,
    required this.userName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  String message = '';
  List<dynamic> users = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    final token = await AuthSession.getToken();

    if (token == null || token.isEmpty) {
      setState(() {
        isLoading = false;
        message = 'No token found. Please login.';
      });
      return;
    }

    final result = await ApiService.get('/api/users', token: token);

    if (!mounted) return;

    if (result.ok && result.data is Map && result.data['users'] is List) {
      setState(() {
        users = result.data['users'] as List;
        isLoading = false;
      });
    } else {
      setState(() {
        message = result.message;
        isLoading = false;
      });
    }
  }

  Future<void> logout() async {
    await AuthSession.clear();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_DashboardCardData> cards = [
      _DashboardCardData(
        title: 'Users',
        value: users.length.toString(),
        icon: Icons.people_outline,
      ),
      _DashboardCardData(
        title: 'Database',
        value: 'PostgreSQL',
        icon: Icons.storage_outlined,
      ),
      _DashboardCardData(
        title: 'API',
        value: 'Express',
        icon: Icons.api_outlined,
      ),
      _DashboardCardData(
        title: 'Auth',
        value: 'JWT',
        icon: Icons.verified_user_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: fetchUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.userName}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Token is saved locally. Protected API routes are working.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              itemCount: cards.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 140,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final card = cards[index];

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        color: Colors.black.withOpacity(0.06),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(card.icon, size: 34, color: Colors.blue),
                      const Spacer(),
                      Text(
                        card.value,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.title,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Registered Users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : message.isNotEmpty
                      ? Center(child: Text(message))
                      : users.isEmpty
                          ? const Center(child: Text('No users yet'))
                          : ListView.separated(
                              itemCount: users.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = users[index];

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline),
                                    ),
                                    title: Text(
                                      user['name']?.toString() ?? 'No name',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      user['email']?.toString() ?? 'No email',
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCardData {
  final String title;
  final String value;
  final IconData icon;

  _DashboardCardData({
    required this.title,
    required this.value,
    required this.icon,
  });
}
