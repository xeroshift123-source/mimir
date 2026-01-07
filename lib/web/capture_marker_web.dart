// lib/web/capture_marker_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui' as ui;

void registerCaptureMarkerView(String viewType, String elementId) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div = html.DivElement()
      ..id = elementId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'transparent';
    return div;
  });
}
