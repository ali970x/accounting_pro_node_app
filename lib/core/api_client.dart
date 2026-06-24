import "dart:async";
import "dart:convert";
import "package:http/http.dart" as http;
import "app_config.dart";
import "session_store.dart";

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  final SessionStore sessionStore;
  static const _timeout = Duration(seconds: 25);

  ApiClient(this.sessionStore);

  Future<Map<String, String>> _headers() async {
    final token = await sessionStore.getToken();
    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  Uri _uri(String path) {
    final clean = path.startsWith("/") ? path : "/$path";
    return Uri.parse("${AppConfig.baseUrl}$clean");
  }

  Future<dynamic> get(String path) async {
    final r = await _send(() async => http.get(_uri(path), headers: await _headers()));
    return _handle(r);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await _send(() async => http.post(_uri(path), headers: await _headers(), body: jsonEncode(body)));
    return _handle(r);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final r = await _send(() async => http.put(_uri(path), headers: await _headers(), body: jsonEncode(body)));
    return _handle(r);
  }

  Future<dynamic> delete(String path) async {
    final r = await _send(() async => http.delete(_uri(path), headers: await _headers()));
    return _handle(r);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException("Connection timed out. Check that the server is running.");
    } on http.ClientException catch (e) {
      throw ApiException(_friendlyClientMessage(e.message));
    } on FormatException {
      throw ApiException("Could not connect to the server. Check your internet connection.");
    }
  }

  String _friendlyClientMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains("failed to fetch") ||
        lower.contains("xmlhttprequest") ||
        lower.contains("socket") ||
        lower.contains("connection") ||
        lower.contains("http://") ||
        lower.contains("https://")) {
      return "Could not connect to the server. Check your internet connection.";
    }
    return raw.replaceAll(RegExp(r"uri=https?:\/\/\S+", caseSensitive: false), "").trim();
  }

  dynamic _handle(http.Response r) {
    dynamic decoded;
    try {
      decoded = jsonDecode(r.body);
    } catch (_) {
      throw ApiException("Invalid server response.", r.statusCode);
    }

    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = decoded is Map && decoded["message"] != null ? decoded["message"].toString() : "Request failed.";
      throw ApiException(msg, r.statusCode);
    }

    if (decoded is Map && decoded.containsKey("data")) return decoded["data"];
    return decoded;
  }
}
