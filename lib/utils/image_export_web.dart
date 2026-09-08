// ignore_for_file: avoid_web_libraries_in_flutter
// lib/utils/image_export_web.dart
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<void> exportPng(Uint8List bytes, String filename) async {
  final safeName = filename.endsWith('.png') ? filename : '$filename.png';
  final navigator = html.window.navigator;
  final isMobile = RegExp(r'Android|iPhone|iPad|iPod', caseSensitive: false)
      .hasMatch(navigator.userAgent);

  // 모바일 웹에서는 download 속성보다 OS 공유 시트가 안정적이다.
  // 공유 시트에서 사진/파일 저장을 선택할 수 있다.
  if (isMobile && js_util.hasProperty(navigator, 'share')) {
    final file = html.File([bytes], safeName, {'type': 'image/png'});
    final shareData = js_util.newObject<Object>();
    js_util.setProperty(shareData, 'files', js_util.jsify([file]));
    js_util.setProperty(shareData, 'title', safeName);
    try {
      final canShare = !js_util.hasProperty(navigator, 'canShare') ||
          js_util.callMethod<bool>(navigator, 'canShare', [shareData]);
      if (canShare) {
        final promise =
            js_util.callMethod<Object>(navigator, 'share', [shareData]);
        await js_util.promiseToFuture<void>(promise);
        return;
      }
    } catch (_) {
      // 공유 API가 거부되면 아래의 Blob 다운로드로 한 번 더 시도한다.
    }
  }

  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = safeName
    ..style.display = 'none';

  html.document.body?.children.add(a);
  a.click();
  // 모바일 브라우저는 클릭 직후 Blob URL을 해제하면 다운로드가
  // 시작되기 전에 대상이 사라질 수 있다.
  await Future<void>.delayed(const Duration(seconds: 1));
  a.remove();
  html.Url.revokeObjectUrl(url);
}

Future<bool> copyPng(Uint8List bytes, String filename) async {
  try {
    final navigator = html.window.navigator;
    final clipboard = js_util.getProperty<Object?>(navigator, 'clipboard');
    final clipboardItem =
        js_util.getProperty<Object?>(js_util.globalThis, 'ClipboardItem');
    if (clipboard == null || clipboardItem == null) {
      throw UnsupportedError('Image clipboard is unavailable.');
    }

    final blob = html.Blob([bytes], 'image/png');
    final data = js_util.newObject<Object>();
    js_util.setProperty(data, 'image/png', blob);
    final item = js_util.callConstructor<Object>(clipboardItem, [data]);
    final promise = js_util.callMethod<Object>(clipboard, 'write', [
      js_util.jsify([item]),
    ]);
    await js_util.promiseToFuture<void>(promise);
    return true;
  } catch (_) {
    await exportPng(bytes, filename);
    return false;
  }
}
