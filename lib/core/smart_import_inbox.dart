import "package:flutter/foundation.dart";

class SmartImportInbox {
  SmartImportInbox._();

  static final ValueNotifier<String?> text = ValueNotifier<String?>(null);
  static final ValueNotifier<int> clipboardRequests = ValueNotifier<int>(0);

  static void put(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    text.value = cleaned;
  }

  static void requestClipboardPaste() {
    clipboardRequests.value++;
  }
}
