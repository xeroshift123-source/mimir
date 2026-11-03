import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/services/nikke_score_service.dart';
import 'package:mimir/widgets/nikke_damage_card.dart';
import 'package:mimir/utils/ranking_color.dart';

NikkeScoreResult result(
        {double score = 101.5, double? top = 12.3, int count = 100}) =>
    NikkeScoreResult(
        score: score,
        damage: 2030000000,
        calcVersion: 'c80',
        sampleCount: count,
        topPercent: top,
        generatedAt: DateTime(2026, 11, 2));

Widget app(Future<NikkeScoreResult> Function() evaluate,
        {String id = 'account',
        String revision = 'v1',
        int nameCode = 5129,
        String? weakness,
        double width = 320,
        bool dark = false}) =>
    MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: width,
                    child: NikkeDamageCard(
                        openId: id,
                        nameCode: nameCode,
                        weakness: weakness,
                        profileRevision: revision,
                        evaluate: evaluate)))));

void main() {
  test('registered parties and response validation', () {
    for (final code in [
      5129,
      5161,
      5105,
      5124,
      5175,
      5145,
      5138,
      5159,
      5156,
      5170,
      5169,
      5176
    ]) {
      expect(NikkeScoreService.supports(code), isTrue);
    }
    expect(NikkeScoreService.supports(5002), isTrue);
    expect(NikkeScoreService.supports(5185), isTrue);
    expect(NikkeScoreService.supports(1019), isFalse);
    expect(NikkeScoreService.supports(5155), isTrue);
    expect(NikkeScoreService.supports(5137), isTrue);
    expect(NikkeScoreService.supports(5045), isTrue);
    expect(NikkeScoreService.profilesFor(5129).map((p) => p.weakness),
        ['fire', 'iron']);
    expect(NikkeScoreService.profilesFor(5002).map((p) => p.weakness),
        ['iron', 'water']);
    expect(() => NikkeScoreResult.fromJson({'score': double.nan}),
        throwsFormatException);
  });

  testWidgets(
      'Marian is supported and element switches cannot reuse old results',
      (tester) async {
    await tester.pumpWidget(
        app(() async => result(), nameCode: 5185, weakness: 'fire'));
    await tester.pumpAndSettle();
    expect(find.text('미미르 스코어'), findsOneWidget);
    expect(find.text('101.50점'), findsOneWidget);
    final pending = Completer<NikkeScoreResult>();
    await tester.pumpWidget(app(() => pending.future, weakness: 'fire'));
    await tester
        .pumpWidget(app(() async => result(score: 42), weakness: 'iron'));
    pending.complete(result(score: 999));
    await tester.pumpAndSettle();
    expect(find.text('미미르 스코어 · 철갑'), findsOneWidget);
    expect(find.text('42.00점'), findsOneWidget);
    expect(find.text('999.00점'), findsNothing);
  });

  testWidgets(
      'loads the saved result once and displays rank bar without a button',
      (tester) async {
    final pending = Completer<NikkeScoreResult>();
    var calls = 0;
    await tester.pumpWidget(app(() {
      calls++;
      return pending.future;
    }));
    expect(calls, 1);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('저장된 스코어 불러오는 중…'), findsOneWidget);
    await tester.pumpWidget(app(() {
      calls++;
      return pending.future;
    }));
    expect(calls, 1);
    pending.complete(result());
    await tester.pumpAndSettle();
    expect(find.text('101.50점'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .color,
        rankingColor(100 - 12.3));
    expect(find.text('상위 12.3%'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(find.textContaining('대상은 내 육성'), findsNothing);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('대상은 내 육성'));
    expect(tooltip.message, contains('연구실은 사용자 기준'));
    tester.state<TooltipState>(find.byType(Tooltip)).ensureTooltipVisible();
    await tester.pumpAndSettle();
    expect(find.text(tooltip.message!), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(.877, .00001));
    expect(find.text('다시 측정'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'account and source changes invalidate results and ignore old responses',
      (tester) async {
    final pending = Completer<NikkeScoreResult>();
    await tester.pumpWidget(app(() => pending.future));
    await tester.pumpWidget(app(() async => result(score: 42), id: 'two'));
    pending.complete(result(score: 999));
    await tester.pumpAndSettle();
    expect(find.text('999.00점'), findsNothing);
    expect(find.text('42.00점'), findsOneWidget);
    await tester
        .pumpWidget(app(() async => result(), id: 'two', revision: 'v2'));
    await tester.pumpAndSettle();
    expect(find.text('42.00점'), findsNothing);
    expect(find.text('101.50점'), findsOneWidget);
  });

  testWidgets(
      'missing population never invents a percentile, including in dark mode',
      (tester) async {
    await tester
        .pumpWidget(app(() async => result(top: null, count: 3), dark: true));
    await tester.pumpAndSettle();
    expect(find.text('순위 집계 중'), findsOneWidget);
    expect(find.text('101.50점'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed saved-score read suggests resync without a button',
      (tester) async {
    await tester.pumpWidget(app(() async => throw const NikkeScoreException(
        '계산 서버가 혼잡합니다.',
        retryAfterSeconds: 2)));
    await tester.pumpAndSettle();
    expect(find.text('계산 서버가 혼잡합니다.'), findsOneWidget);
    expect(find.text('프로필을 다시 동기화하면 자동으로 재측정합니다.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('0.00점'), findsNothing);
  });

  testWidgets('completion after card disposal is ignored', (tester) async {
    final pending = Completer<NikkeScoreResult>();
    await tester.pumpWidget(app(() => pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.complete(result());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
