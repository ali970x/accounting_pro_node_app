import "package:flutter/foundation.dart";

class AppConfig {
  static const String _configuredBaseUrl = String.fromEnvironment("API_BASE_URL");
  static const String _productionBaseUrl = "https://accounting-pro-server.onrender.com/api";

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kReleaseMode) return _productionBaseUrl;
    if (kIsWeb) return "http://localhost:5000/api";
    if (defaultTargetPlatform == TargetPlatform.android) return _productionBaseUrl;
    return "http://localhost:5000/api";
  }
}
