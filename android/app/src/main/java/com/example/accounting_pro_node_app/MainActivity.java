package com.example.accounting_pro_node_app;

import android.content.ActivityNotFoundException;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.File;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String UPDATE_CHANNEL = "daftr/update";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), UPDATE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("installApk".equals(call.method)) {
                        String path = call.argument("path");
                        installApk(path == null ? "" : path, result);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void installApk(String path, MethodChannel.Result result) {
        File apk = new File(path);
        if (!apk.exists() || apk.length() <= 0L) {
            result.error("APK_NOT_FOUND", "Downloaded update file was not found.", null);
            return;
        }

        try {
            String authority = getPackageName() + ".update_provider";
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(
                    FileProvider.getUriForFile(this, authority, apk),
                    "application/vnd.android.package-archive"
            );
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(intent);
            result.success(true);
        } catch (ActivityNotFoundException error) {
            result.error("INSTALLER_NOT_FOUND", "No installer app was found on this device.", null);
        } catch (Exception error) {
            result.error(
                    "INSTALL_FAILED",
                    error.getMessage() == null ? "Could not open the installer." : error.getMessage(),
                    null
            );
        }
    }
}
