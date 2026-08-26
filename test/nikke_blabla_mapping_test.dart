import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/nikke.dart';

void main() {
  test('Blabla name codes uniquely identify every local Nikke', () {
    final raw = jsonDecode(File('assets/nikkes.json').readAsStringSync())
        as List<dynamic>;
    final nikkes = raw
        .map((json) => Nikke.fromJson(json as Map<String, dynamic>))
        .toList();
    final byCode = <int, Nikke>{
      for (final nikke in nikkes)
        if (nikke.blablaNameCode case final code?) code: nikke,
    };

    expect(nikkes.where((nikke) => nikke.blablaNameCode == null), isEmpty);
    expect(byCode.length, nikkes.length);

    final originalSakura = byCode[1012];
    final evaSakura = byCode[3015];
    expect(originalSakura?.id, 'sakura');
    expect(evaSakura?.id, 'sakura(eva)');
    expect(originalSakura?.name, '사쿠라');
    expect(evaSakura?.name, '사쿠라');
    expect(identical(originalSakura, evaSakura), isFalse);
  });
}
