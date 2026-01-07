import 'dart:typed_data';
import 'image_clipboard.dart';

class StubImageClipboard implements ImageClipboard {
  @override
  Future<void> copyImage(Uint8List bytes) async {
    throw UnsupportedError('Clipboard image copy is only supported on Web');
  }
}

ImageClipboard getImageClipboard() => StubImageClipboard();
