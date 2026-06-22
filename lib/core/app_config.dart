import "package:flutter/foundation.dart";

class AppConfig {
  static const String _configuredBaseUrl = String.fromEnvironment("API_BASE_URL");
  static const String _productionBaseUrl = "https://accounting-pro-server.onrender.com/api";

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kReleaseMode) return _productionBaseUrl;
    if (kIsWeb) return "http://localhost:5000/api";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://192.168.10.103:5000/api";
    return "http://localhost:5000/api";
  }
}
