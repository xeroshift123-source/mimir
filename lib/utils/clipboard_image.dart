import 'dart:typed_data';

import 'clipboard_image_stub.dart'
    if (dart.library.html) 'clipboard_image_web.dart';

/// PNG 바이트를 "이미지"로 클립보드에 복사.
/// 성공하면 true, 실패하면 false.
Future<bool> copyPngImageToClipboard(Uint8List pngBytes) {
  return copyPngImageToClipboardImpl(pngBytes);
}
