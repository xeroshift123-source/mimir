// lib/utils/image_export.dart
import 'dart:typed_data';

import 'image_export_stub.dart'
    if (dart.library.html) 'image_export_web.dart'
    if (dart.library.io) 'image_export_io.dart' as impl;

/// 웹: 다운로드 / 앱&데스크탑: 공유(또는 저장) 로 동작하게 통합
Future<void> exportPng(Uint8List bytes, String filename) {
  return impl.exportPng(bytes, filename);
}
