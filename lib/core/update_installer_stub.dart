typedef UpdateProgress = void Function(double? progress);

class UpdateInstaller {
  static bool get canInstallInApp => false;

  static Future<void> downloadAndInstallApk({
    required String url,
    required String filename,
    UpdateProgress? onProgress,
  }) {
    throw UnsupportedError("In-app APK installation is only available on Android.");
  }
}
