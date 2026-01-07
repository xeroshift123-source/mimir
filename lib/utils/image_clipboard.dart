import 'dart:typed_data';

abstract class ImageClipboard {
  Future<void> copyImage(Uint8List bytes);
}

ImageClipboard getImageClipboard() {
  throw UnsupportedError('Platform not supported');
}
