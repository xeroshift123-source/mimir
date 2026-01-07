import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js;

/// Web Clipboard API: navigator.clipboard.write([new ClipboardItem({...})])
/// - HTTPS(secure context)에서만 동작
/// - 사용자 제스처(onPressed 등) 안에서 호출되어야 함
Future<bool> copyPngImageToClipboardImpl(Uint8List pngBytes) async {
  try {
    // navigator.clipboard 지원 여부
    final clipboard = js.getProperty(html.window.navigator, 'clipboard');
    if (clipboard == null) return false;

    // ClipboardItem 생성자 지원 여부
    final clipboardItemCtor = js.getProperty(html.window, 'ClipboardItem');
    if (clipboardItemCtor == null) return false;

    final blob = html.Blob(<dynamic>[pngBytes], 'image/png');

    // new ClipboardItem({ 'image/png': blob })
    final data = js.jsify(<String, dynamic>{'image/png': blob});
    final item = js.callConstructor(clipboardItemCtor, <dynamic>[data]);

    // navigator.clipboard.write([item])  // Promise 반환
    await js.promiseToFuture(js.callMethod(clipboard, 'write', <dynamic>[
      <dynamic>[item]
    ]));

    return true;
  } catch (_) {
    // 권한/브라우저 정책/사용자 제스처 조건 실패 등
    return false;
  }
}
