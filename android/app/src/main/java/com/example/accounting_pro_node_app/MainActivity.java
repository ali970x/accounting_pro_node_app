package com.example.accounting_pro_node_app;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.File;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String UPDATE_CHANNEL = "daftr/update";
    private static final String SHARE_CHANNEL = "daftr/share";
    private static final String OVERLAY_CHANNEL = "daftr/overlay";
    private static final String SMART_CLIPBOARD_ACTION = "com.example.accounting_pro_node_app.SMART_IMPORT_CLIPBOARD";
    private MethodChannel shareChannel;
    private String pendingSharedText = "";
    private boolean pendingOpenClipboard = false;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        pendingSharedText = readSharedText(getIntent());
        pendingOpenClipboard = isSmartClipboardIntent(getIntent());
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), UPDATE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("installApk".equals(call.method)) {
                        String path = call.argument("path");
                        installApk(path == null ? "" : path, result);
                    } else {
                        result.notImplemented();
                    }
                });
        shareChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SHARE_CHANNEL);
        shareChannel.setMethodCallHandler((call, result) -> {
            if ("getInitialSharedText".equals(call.method)) {
                result.success(pendingSharedText);
                pendingSharedText = "";
            } else if ("getInitialOpenClipboard".equals(call.method)) {
                result.success(pendingOpenClipboard);
                pendingOpenClipboard = false;
            } else {
                result.notImplemented();
            }
        });
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), OVERLAY_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("hasPermission".equals(call.method)) {
                        result.success(canDrawOverlay());
                    } else if ("requestPermission".equals(call.method)) {
                        Intent intent = new Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:" + getPackageName())
                        );
                        startActivity(intent);
                        result.success(true);
                    } else if ("start".equals(call.method)) {
                        if (!canDrawOverlay()) {
                            result.success(false);
                            return;
                        }
                        startService(new Intent(this, SmartBubbleService.class));
                        result.success(true);
                    } else if ("stop".equals(call.method)) {
                        stopService(new Intent(this, SmartBubbleService.class));
                        result.success(true);
                    } else if ("isRunning".equals(call.method)) {
                        result.success(SmartBubbleService.isRunning());
                    } else {
                        result.notImplemented();
                    }
                });
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        String text = readSharedText(intent);
        if (isSmartClipboardIntent(intent)) {
            if (shareChannel == null) {
                pendingOpenClipboard = true;
            } else {
                shareChannel.invokeMethod("openSmartImportClipboard", true);
            }
            return;
        }
        if (text.isEmpty()) return;
        if (shareChannel == null) {
            pendingSharedText = text;
            return;
        }
        shareChannel.invokeMethod("sharedText", text);
    }

    private String readSharedText(Intent intent) {
        if (intent == null || intent.getAction() == null) return "";
        String action = intent.getAction();
        CharSequence value = null;
        if (Intent.ACTION_SEND.equals(action)) {
            value = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        } else if (Intent.ACTION_PROCESS_TEXT.equals(action)) {
            value = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT);
        }
        return value == null ? "" : value.toString();
    }

    private boolean isSmartClipboardIntent(Intent intent) {
        return intent != null && SMART_CLIPBOARD_ACTION.equals(intent.getAction());
    }

    private boolean canDrawOverlay() {
        return android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M || Settings.canDrawOverlays(this);
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
