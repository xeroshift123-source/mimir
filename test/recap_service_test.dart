import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/enums.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/services/recap_service.dart';
import 'package:mimir/screens/recap_screen.dart';

void main() {
  final rapi = _nikke(1001, 'rapi', '라피', ElementType.Fire);
  final waterNikke = _nikke(1002, 'test_water', '테스트 니케', ElementType.Water);
  final nikkes = <int, Nikke>{1001: rapi, 1002: waterNikke};

  test('14개 규칙을 계산하고 스킬 칩을 색상별로 누적한다', () {
    final profile = {
      'joinedAt': 20260101,
      'normalCampaign': 6048044,
      'ownedNikkesCount': 2,
      'costumeCount': 12,
      'recycleRoom': [
        {'tid': 1101, 'lv': 20},
        {'tid': 1102, 'lv': 15},
      ],
      'characters': [
        {
          'name_code': 1002,
          'combat': 100000,
          'core': 7,
          'bondLevel': 40,
          'skills': {'skill1': 10, 'skill2': 10, 'burst': 10},
          'favoriteItem': {'tid': 1, 'level': 1},
          'equipment': [
            for (final slot in ['head', 'torso', 'arm', 'leg'])
              {
                'slot': slot,
                'tier': 10,
                'level': 5,
                'overloadOptions': [7000515, 7000815, 0],
              },
          ],
        },
      ],
    };

    final cards = RecapService.build(
      profile: profile,
      nikkesByCode: nikkes,
      accountSeed: 'commander-1',
      now: DateTime(2026, 1, 11),
    );

    expect(cards.map((card) => card.order), containsAll([1, 2, 9, 12, 14]));
    expect(cards.first.title, contains('10일'));
    expect(cards.firstWhere((card) => card.order == 4).title, contains('1명의'));
    expect(
        cards.firstWhere((card) => card.order == 4).details, ['풀코강한 니케들의 수']);
    expect(cards.firstWhere((card) => card.order == 4).imageAsset,
        waterNikke.imageUrl);
    expect(
      cards.firstWhere((card) => card.order == 5).details,
      [
        '스킬 칩 · 파랑 2,188 · 보라 1,550 · 노랑 630',
        '버스트 칩 · 파랑 1,094 · 보라 775 · 노랑 315',
        '속성 칩 · 1,440',
      ],
    );
    expect(cards.firstWhere((card) => card.order == 6).title, startsWith('수냉'));
    expect(cards.firstWhere((card) => card.order == 6).imageAsset,
        waterNikke.imageUrl);
    expect(
        cards.firstWhere((card) => card.order == 7).title, startsWith('4개의'));
    expect(cards.firstWhere((card) => card.order == 8).title, contains('1개의'));
    expect(
        cards.firstWhere((card) => card.order == 9).details, ['+5강화한 신발의 갯수']);
    expect(cards.firstWhere((card) => card.order == 9).imageAsset,
        waterNikke.imageUrl);
    expect(cards.firstWhere((card) => card.order == 12).details,
        ['화력형 콘솔 레벨 20, 방어형 콘솔 레벨 15']);
    expect(cards.firstWhere((card) => card.order == 13).details, isEmpty);
    expect(cards.firstWhere((card) => card.order == 14).title, '테스트 니케');
    expect(cards.firstWhere((card) => card.order == 14).details, isEmpty);
  });

  test('조건을 만족하지 않는 완료·신발·화력·천생연분 카드는 건너뛴다', () {
    final cards = RecapService.build(
      profile: {
        'joinedAt': '2026-01-01T00:00:00Z',
        'normalCampaign': '47-36',
        'recycleRoom': [
          {'tid': 1101, 'lv': 10},
          {'tid': 1102, 'lv': 10},
        ],
        'characters': [
          {
            'name_code': 1001,
            'bondLevel': 29,
            'skills': {'skill1': 1, 'skill2': 1, 'burst': 1},
            'equipment': const [],
          },
        ],
      },
      nikkesByCode: nikkes,
      accountSeed: 'commander-2',
      now: DateTime(2026, 1, 2),
    );

    expect(cards.map((card) => card.order), isNot(contains(2)));
    expect(cards.map((card) => card.order), isNot(contains(9)));
    expect(cards.map((card) => card.order), isNot(contains(12)));
    expect(cards.map((card) => card.order), isNot(contains(13)));
    expect(cards.map((card) => card.order), isNot(contains(14)));
  });

  test('이전 가입일 필드명과 유닉스 초 형식을 지원한다', () {
    final cards = RecapService.build(
      profile: {
        'created_at': 1731600000,
        'characters': const [],
      },
      nikkesByCode: nikkes,
      accountSeed: 'legacy-date',
      now: DateTime(2024, 11, 25),
    );

    expect(cards.first.order, 1);
    expect(cards.first.title, contains('10일'));
  });

  testWidgets('모든 카드가 모바일과 데스크톱에서 같은 비율로 표시된다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final featured = <String>[
      'rapi',
      'rapi_red_hood',
      'privaty',
      'drake',
      'crown',
      'little_mermaid',
      'centi',
      'maxwell',
      'cinderella',
      'rupee',
      'neon_vision_eye',
    ];
    final imageNikkes = <int, Nikke>{};
    for (var index = 0; index < featured.length; index++) {
      imageNikkes[index + 1] = _nikke(
        index + 1,
        featured[index],
        featured[index],
        ElementType.Water,
      );
    }
    final charCode = featured.length + 1;
    imageNikkes[charCode] = _nikke(
      charCode,
      'rapi',
      '라피',
      ElementType.Fire,
    );
    final cards = RecapService.build(
      profile: {
        'joinedAt': '2024-01-01T00:00:00Z',
        'normalCampaign': '48-36',
        'ownedNikkesCount': 183,
        'costumeCount': 43,
        'recycleRoom': [
          {'tid': 1101, 'lv': 138},
          {'tid': 1102, 'lv': 126},
        ],
        'characters': [
          {
            'name_code': charCode,
            'combat': 250000,
            'core': 7,
            'bondLevel': 40,
            'skills': {'skill1': 10, 'skill2': 10, 'burst': 10},
            'favoriteItem': {'tid': 1},
            'equipment': [
              for (final slot in ['head', 'torso', 'arm', 'leg'])
                {
                  'slot': slot,
                  'tier': 10,
                  'level': 5,
                  'overloadOptions': [7000515, 7000815, 0],
                },
            ],
          },
        ],
      },
      nikkesByCode: imageNikkes,
      accountSeed: 'layout-test',
      now: DateTime(2026, 8, 26),
    );

    for (final size in const [
      Size(320, 480),
      Size(480, 720),
      Size(720, 1080),
    ]) {
      tester.view.physicalSize = size;
      for (var index = 0; index < cards.length; index++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecapCardView(
                card: cards[index],
                current: index + 1,
                total: cards.length,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${size.width.toInt()}px · ${cards[index].order}번 카드',
        );
      }
    }
  });
}

Nikke _nikke(int code, String id, String name, ElementType element) {
  return Nikke(
    id: id,
    name: name,
    blablaNameCode: code,
    imageUrl: 'assets/nikke/$id.webp',
    burst: BurstType.burst3,
    element: element,
    weaponType: WeaponType.AR,
    company: Company.Elysion,
    coolTime: 40,
    type: 'ATK',
    ability: const [],
    rank: Rank.SSR,
  );
}
