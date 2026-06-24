import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;

typedef UpdateProgress = void Function(double? progress);

class UpdateInstaller {
  static const _channel = MethodChannel("daftr/update");

  static bool get canInstallInApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> downloadAndInstallApk({
    required String url,
    required String filename,
    UpdateProgress? onProgress,
  }) async {
    if (!canInstallInApp) {
      throw UnsupportedError("In-app APK installation is only available on Android.");
    }

    final uri = Uri.parse(url);
    final safeFilename = _safeFilename(filename).endsWith(".apk") ? _safeFilename(filename) : "${_safeFilename(filename)}.apk";
    final file = File("${Directory.systemTemp.path}${Platform.pathSeparator}$safeFilename");
    if (await file.exists()) await file.delete();

    final client = http.Client();
    try {
      final request = http.Request("GET", uri)..followRedirects = true;
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException("Download failed with status ${response.statusCode}", uri: uri);
      }

      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength;
      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (total != null && total > 0) {
            onProgress?.call(((received / total).clamp(0.0, 1.0) as num).toDouble());
          } else {
            onProgress?.call(null);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _channel.invokeMethod<bool>("installApk", {"path": file.path});
    } finally {
      client.close();
    }
  }

  static String _safeFilename(String value) {
    final clean = value.trim().replaceAll(RegExp(r"[^A-Za-z0-9._-]+"), "_");
    return clean.isEmpty ? "Daftr.apk" : clean;
  }
}
