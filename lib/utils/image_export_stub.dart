// lib/utils/image_export_stub.dart
import 'dart:async';
import 'dart:typed_data';

Future<void> exportPng(Uint8List bytes, String filename) {
  throw UnsupportedError('This platform is not supported for image export.');
}

Future<bool> copyPng(FutureOr<Uint8List> bytes, String filename) {
  throw UnsupportedError('This platform is not supported for image copy.');
}
