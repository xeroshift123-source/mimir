import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/shared_deck.dart';

void main() {
  test('공유 덱의 스쿼드 설명과 레이드 정보를 직렬화한다', () {
    final deck = SharedDeck(
      id: 'deck-id',
      authorUid: 'user-id',
      authorName: '지휘관',
      title: '테스트 덱',
      description: '전체 설명',
      season: 'SEASON 40',
      raidType: 'solo',
      bossName: '보스',
      weaknessElement: '전격',
      squadNames: const ['1번덱'],
      squadWeaknessElements: const ['전격'],
      squadDescriptions: const ['버스트 순서 설명'],
      squadsNikkeIds: const [
        ['liter', 'crown', 'rapi', 'helm', 'modernia'],
      ],
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime(2026, 9, 3),
    );

    final json = deck.toJson();
    final restored = SharedDeck.fromJson(json);

    expect(restored.authorUid, 'user-id');
    expect(restored.squadDescriptions, ['버스트 순서 설명']);
    expect(restored.squadWeaknessElements, ['전격']);
    expect(restored.squadsNikkeIds.single.length, 5);
    expect(json['squadsNikkeIds'], [
      {
        'nikkeIds': ['liter', 'crown', 'rapi', 'helm', 'modernia'],
      },
    ]);
    expect(restored.createdAt, DateTime(2026, 9, 3));
  });

  test('이전 형식의 공유 덱도 기본값으로 읽는다', () {
    final restored = SharedDeck.fromJson({
      'id': 'legacy',
      'authorName': 'MIMIR',
      'title': '기존 덱',
      'description': '',
      'season': 'SEASON 37',
      'squadsNikkeIds': const [
        ['liter'],
      ],
      'upvotes': 1,
      'downvotes': 0,
      'createdAt': '2026-09-03T00:00:00.000',
    });

    expect(restored.raidType, 'solo');
    expect(restored.squadDescriptions, isEmpty);
    expect(restored.squadNames, isEmpty);
  });
}
