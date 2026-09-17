// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js' show allowInterop;
import 'dart:js_util' as js_util;

Future<T> _export<T>(String action, Object image, String filename) {
  final exporter = js_util.getProperty<Object>(
    js_util.globalThis,
    'mimirImageExport',
  );
  final safeName = filename.endsWith('.png') ? filename : '$filename.png';
  return js_util.promiseToFuture<T>(
    js_util.callMethod<Object>(exporter, action, [image, safeName]),
  );
}

Future<void> exportPng(Uint8List bytes, String filename) =>
    _export<void>('save', html.Blob([bytes], 'image/png'), filename);

Future<bool> copyPng(FutureOr<Uint8List> bytes, String filename) {
  // Construct a native JS Promise without awaiting the capture. _export calls
  // clipboard.write synchronously, preserving the original button gesture.
  final promise = js_util.callConstructor<Object>(
    js_util.getProperty<Object>(js_util.globalThis, 'Promise'),
    [
      allowInterop((Object resolve, Object reject) {
        Future<Uint8List>.value(bytes).then<void>((png) {
          js_util.callMethod<void>(resolve, 'call', [
            null,
            html.Blob([png], 'image/png')
          ]);
        }).catchError((Object error, StackTrace stack) {
          final jsError = js_util.callConstructor<Object>(
            js_util.getProperty<Object>(js_util.globalThis, 'Error'),
            [error.toString()],
          );
          js_util.callMethod<void>(reject, 'call', [null, jsError]);
        });
      })
    ],
  );
  return _export<bool>('copy', promise, filename);
}
