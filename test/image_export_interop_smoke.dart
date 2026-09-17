// Standalone browser smoke test: compile with dart compile js and load after
// web/image_export.js on localhost. Does not use Flutter's web test server.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' show allowInterop;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:mimir/utils/image_export_web.dart';

Future<void> main() async {
  try {
    var writes = 0;
    var inButtonHandler = false;
    Object? pendingBlob;
    final clipboard = js_util.newObject<Object>();
    js_util.setProperty(clipboard, 'write', allowInterop((Object items) {
      if (!inButtonHandler) throw StateError('Lost original button gesture');
      writes++;
      final item = js_util.getProperty<Object>(items, 0);
      // Use the browser's real ClipboardItem and its Promise<Blob> handling.
      pendingBlob = js_util.callMethod<Object>(item, 'getType', ['image/png']);
      return pendingBlob!;
    }));
    js_util.callMethod<Object>(
      js_util.getProperty<Object>(js_util.globalThis, 'Object'),
      'defineProperty',
      [
        html.window.navigator,
        'clipboard',
        js_util.jsify({'value': clipboard})
      ],
    );

    final capture = Completer<Uint8List>();
    inButtonHandler = true;
    final copied = copyPng(capture.future, 'license.png');
    inButtonHandler = false;
    if (writes != 1) throw StateError('write() waited for PNG capture');
    capture.complete(Uint8List.fromList([137, 80, 78, 71]));
    if (!await copied) throw StateError('Unexpected download fallback');
    final blob = await js_util.promiseToFuture<html.Blob>(pendingBlob!);
    if (blob.type != 'image/png' || blob.size != 4) {
      throw StateError('Dart bytes were not delivered as a PNG Blob');
    }

    // Capture failures must reach Dart even if write() started successfully.
    final failedCapture = Completer<Uint8List>();
    inButtonHandler = true;
    final failure = copyPng(failedCapture.future, 'broken.png');
    inButtonHandler = false;
    failedCapture.completeError(StateError('capture failed'));
    var rejected = false;
    try {
      await failure;
    } catch (error) {
      rejected = error.toString().contains('capture failed');
    }
    if (!rejected) throw StateError('Capture error was lost across JS interop');
    html.document.body!.dataset['testResult'] = 'passed';
    html.document.body!.text = 'Dart/JS clipboard Promise interop passed';
  } catch (error, stack) {
    html.document.body!.dataset['testResult'] = 'failed';
    html.document.body!.text = '$error\n$stack';
  }
}
