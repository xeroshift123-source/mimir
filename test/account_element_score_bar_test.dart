import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/services/nikke_score_service.dart';
import 'package:mimir/widgets/account_element_score_bar.dart';
import 'package:mimir/utils/ranking_color.dart';

void main() {
  testWidgets('element sums show score, mean, sample and shared ranking color',
      (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
        width: 164,
        child: AccountElementScoreBar(
            isDark: dark,
            statistic: ElementScoreStatistic.fromJson({
              'key': 'fire',
              'name': '작열',
              'score': 2106.03,
              'average': 1566.77,
              'sampleCount': 1913,
              'topPercent': 27.8,
            })),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('2106.03점'), findsOneWidget);
      expect(find.text('평균 1566.77점'), findsOneWidget);
      expect(find.text('표본 1913명'), findsOneWidget);
      expect(find.text('상위 27.8%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(.722, .00001));
      expect(bar.color, rankingColor(72.2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'missing score and small population never display an invented rank',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 164,
      child: AccountElementScoreBar(
          isDark: false,
          statistic: ElementScoreStatistic.fromJson({
            'key': 'wind',
            'name': '풍압',
            'score': null,
            'average': null,
            'sampleCount': 3,
            'topPercent': null,
          })),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('비교 불가'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .color,
        Colors.grey);
    expect(tester.takeException(), isNull);
  });
}
