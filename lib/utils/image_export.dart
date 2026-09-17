// lib/utils/image_export.dart
import 'dart:async';
import 'dart:typed_data';

import 'image_export_stub.dart'
    if (dart.library.html) 'image_export_web.dart'
    if (dart.library.io) 'image_export_io.dart' as impl;

/// 웹: 직접 다운로드 / 앱: 공유.
Future<void> exportPng(Uint8List bytes, String filename) {
  return impl.exportPng(bytes, filename);
}

/// 캡처 Future를 그대로 전달하면 웹에서 사용자 입력 권한이 있는 동안
/// 복사를 시작하고 PNG 생성은 나중에 완료한다. 실제 복사 여부를 반환한다.
Future<bool> copyPng(FutureOr<Uint8List> bytes, String filename) {
  return impl.copyPng(bytes, filename);
}
