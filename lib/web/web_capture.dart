// lib/web/web_capture.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js_util' as js_util;

Future<void> captureByElementId({
  required String elementId,
  required String fileName,
}) async {
  if (!kIsWeb) return;

  // window.captureElementById(elementId, fileName)
  await js_util.callMethod(
    js_util.globalThis,
    'captureElementById',
    [elementId, fileName],
  );
}
