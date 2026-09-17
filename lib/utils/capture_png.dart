import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Capture after painting, bounding memory use for long deck previews.
Future<Uint8List> capturePng(GlobalKey key) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary || boundary.size.isEmpty) {
    throw StateError('이미지 미리보기가 준비되지 않았습니다. 다시 시도해 주세요.');
  }
  final size = boundary.size;
  final ratio = math.min(
      2.0,
      math.min(
        4096 / math.max(size.width, size.height),
        math.sqrt(4000000 / (size.width * size.height)),
      ));
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG 이미지를 만들지 못했습니다.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
