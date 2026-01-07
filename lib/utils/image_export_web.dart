// lib/utils/image_export_web.dart
import 'dart:typed_data';
import 'dart:html' as html;

Future<void> exportPng(Uint8List bytes, String filename) async {
  final safeName = filename.endsWith('.png') ? filename : '$filename.png';
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = safeName
    ..style.display = 'none';

  html.document.body?.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}
