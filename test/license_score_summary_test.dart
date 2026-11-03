import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/services/nikke_score_service.dart';
import 'package:mimir/widgets/license_score_summary.dart';
import 'package:mimir/utils/capture_png.dart';

Map<String, dynamic> savedScore(double score) => {
      'status': 'complete',
      'score': score,
      'damage': 100,
      'calcVersion': 'c80',
      'sampleCount': 20,
    };

void main() {
  test('license selects both saved elements and omits failed and absent scores',
      () {
    final saved = StoredNikkeScores.fromJson({
      'status': 'complete',
      'results': {
        '5129:fire': savedScore(123.45),
        '5129:iron': savedScore(67.89),
        '5155:wind': {'status': 'error'},
      }
    });
    final scores = savedLicenseScores(saved, 5129);
    expect(scores.map((s) => s.elementName), ['작열', '철갑']);
    expect(scores.map((s) => s.score), [123.45, 67.89]);
    expect(savedLicenseScores(saved, 5155), isEmpty);
    expect(savedLicenseScores(saved, 1019), isEmpty);
    saved.results['5129:iron'] = savedScore(double.nan);
    expect(savedLicenseScores(saved, 5129).length, 1);
  });

  testWidgets('license score labels are part of the captured PNG',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(
      key: key,
      child: const SizedBox(
          width: 398,
          child: LicenseScoreSummary(
            scores: [LicenseScore('작열', 123.45), LicenseScore('철갑', 67.89)],
            textColor: Colors.black,
            scoreColor: Colors.orange,
          )),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('작열 123.45점'), findsOneWidget);
    expect(find.text('철갑 67.89점'), findsOneWidget);
    final capture = capturePng(key);
    await tester.pump();
    await tester.runAsync(() async {
      expect((await capture).take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(
        home: LicenseScoreSummary(
            scores: [], textColor: Colors.black, scoreColor: Colors.orange)));
    expect(find.text('미미르 스코어'), findsNothing);
  });
}
