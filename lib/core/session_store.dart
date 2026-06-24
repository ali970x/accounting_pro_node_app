import "package:shared_preferences/shared_preferences.dart";

class SessionStore {
  static const _tokenKey = "auth_token";
  static const _nameKey = "user_name";
  static const _emailKey = "user_email";
  static const _roleKey = "user_role";

  Future<void> saveSession({
    required String token,
    required String name,
    required String email,
    required String role,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, token);
    await p.setString(_nameKey, name);
    await p.setString(_emailKey, email);
    await p.setString(_roleKey, role);
  }

  Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString(_tokenKey);
  Future<String?> getName() async => (await SharedPreferences.getInstance()).getString(_nameKey);
  Future<String?> getEmail() async => (await SharedPreferences.getInstance()).getString(_emailKey);
  Future<String?> getRole() async => (await SharedPreferences.getInstance()).getString(_roleKey);
  Future<bool> isAdmin() async => (await getRole()) == "admin";

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_nameKey);
    await p.remove(_emailKey);
    await p.remove(_roleKey);
  }
}
