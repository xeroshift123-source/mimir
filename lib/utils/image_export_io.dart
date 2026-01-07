// lib/utils/image_export_io.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportPng(Uint8List bytes, String filename) async {
  final safeName = filename.endsWith('.png') ? filename : '$filename.png';

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png', name: safeName)],
    text: '덱 공유',
  );
}
