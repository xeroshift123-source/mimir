// lib/utils/image_export.dart
import 'dart:typed_data';

import 'image_export_stub.dart'
    if (dart.library.html) 'image_export_web.dart'
    if (dart.library.io) 'image_export_io.dart' as impl;

/// 웹: 다운로드 / 앱&데스크탑: 공유(또는 저장) 로 동작하게 통합
Future<void> exportPng(Uint8List bytes, String filename) {
  return impl.exportPng(bytes, filename);
}

/// 이미지 클립보드를 지원하면 복사하고, 미지원 환경에서는 저장/공유로
/// 전환한다. 실제 복사 여부를 반환한다.
Future<bool> copyPng(Uint8List bytes, String filename) {
  return impl.copyPng(bytes, filename);
}
