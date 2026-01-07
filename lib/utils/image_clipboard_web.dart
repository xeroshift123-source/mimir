// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js_util' as js_util;

import 'image_clipboard.dart';

class WebImageClipboard implements ImageClipboard {
  @override
  Future<void> copyImage(Uint8List bytes) async {
    // 1) PNG -> Blob
    final blob = html.Blob([bytes], 'image/png');

    // 2) window.ClipboardItem 생성 (JS로)
    final clipboardItemCtor = js_util.getProperty(html.window, 'ClipboardItem');
    if (clipboardItemCtor == null) {
      throw UnsupportedError('이 브라우저는 ClipboardItem을 지원하지 않습니다.');
    }

    final item = js_util.callConstructor(
      clipboardItemCtor,
      [
        js_util.jsify({'image/png': blob}),
      ],
    );

    // 3) navigator.clipboard.write([item])
    final clipboard = html.window.navigator.clipboard;
    if (clipboard == null) {
      throw UnsupportedError('navigator.clipboard를 사용할 수 없습니다(HTTPS/권한 필요).');
    }

    await js_util.promiseToFuture(
      js_util.callMethod(clipboard, 'write', [
        [item]
      ]),
    );
  }
}

ImageClipboard getImageClipboard() => WebImageClipboard();
