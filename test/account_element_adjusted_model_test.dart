import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/nikke_statistics.dart';

void main() {
  test('Old caches retain raw values and have no fabricated adjusted score',
      () {
    final value = AccountElementDamageStatistic.fromJson({
      'key': 'Water',
      'myTotalPercent': 80,
      'averageTotalPercent': 40,
      'topPercent': 25,
    });
    expect(value.myTotalPercent, 80);
    expect(value.topPercent, 25);
    expect(value.adjustedScore, isNull);
    expect(value.adjustedTopPercent, isNull);
  });
  test('Adjusted fields remain independent of the raw badge ranking', () {
    final value = AccountElementDamageStatistic.fromJson({
      'topPercent': 35.2,
      'adjustedScore': 141.17,
      'adjustedAverage': 70.58,
      'adjustedTopPercent': 3.7,
    });
    expect(value.topPercent, 35.2);
    expect(value.adjustedScore, 141.17);
    expect(value.adjustedAverage, 70.58);
    expect(value.adjustedTopPercent, 3.7);
  });
}
