import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/utils/capture_png.dart';

void main() {
  testWidgets('captures painted content as a nonblank PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child: RepaintBoundary(
        key: key,
        child: const SizedBox(
            width: 120, height: 80, child: ColoredBox(color: Colors.red)),
      )),
    ));
    final capture = capturePng(key);
    await tester.pump();
    await tester.runAsync(() async {
      final bytes = await capture;
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 240);
      expect(image.height, 160);
      final rgba = await image.toByteData();
      expect(rgba!.buffer.asUint8List().take(4), [244, 67, 54, 255]);
      image.dispose();
      codec.dispose();
    });
  });

  testWidgets('missing capture target produces a visible error',
      (tester) async {
    final result = expectLater(capturePng(GlobalKey()), throwsStateError);
    await tester.pump();
    await result;
  });
}
