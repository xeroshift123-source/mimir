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

  test('18개 규칙을 계산하고 스킬 칩을 색상별로 누적한다', () {
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
                'overloadOptions': [7000515, 7000815, 7000715],
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

    expect(cards.map((card) => card.order), containsAll([1, 2, 10, 15, 18]));
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
    expect(cards.firstWhere((card) => card.order == 7).title, contains('수냉에서'));
    expect(cards.firstWhere((card) => card.order == 7).details,
        ['우월코드 데미지 증가 총합 116.64%']);
    expect(
        cards.firstWhere((card) => card.order == 8).title, startsWith('4개의'));
    expect(cards.firstWhere((card) => card.order == 9).title, contains('1개의'));
    expect(
        cards.firstWhere((card) => card.order == 10).details, ['+5강화한 신발의 갯수']);
    expect(cards.firstWhere((card) => card.order == 10).imageAsset,
        waterNikke.imageUrl);
    expect(cards.firstWhere((card) => card.order == 12).details,
        ['우월코드 + 공격력이 제일 높은 니케']);
    expect(cards.firstWhere((card) => card.order == 15).details,
        ['화력형 콘솔 레벨 20, 방어형 콘솔 레벨 15']);
    expect(
        cards.firstWhere((card) => card.order == 16).title, contains('테스트 니케'));
    expect(cards.firstWhere((card) => card.order == 16).imageAsset,
        waterNikke.imageUrl);
    expect(
      cards.firstWhere((card) => card.order == 17).title,
      '왠지 당신에게 어울릴거 같은\n천생연분 니케를 찾아봤어요!',
    );
    expect(cards.firstWhere((card) => card.order == 17).details, isEmpty);
    expect(
      cards.firstWhere((card) => card.order == 18).title,
      '당신의 천생연분 니케는...\n테스트 니케',
    );
    expect(cards.firstWhere((card) => card.order == 18).details, isEmpty);
  });

  test('조건을 만족하지 않는 완료·신발·화력·최강·천생연분 카드는 건너뛴다', () {
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
    expect(cards.map((card) => card.order), isNot(contains(7)));
    expect(cards.map((card) => card.order), isNot(contains(10)));
    expect(cards.map((card) => card.order), isNot(contains(13)));
    expect(cards.map((card) => card.order), isNot(contains(14)));
    expect(cards.map((card) => card.order), isNot(contains(15)));
    expect(cards.map((card) => card.order), isNot(contains(16)));
    expect(cards.map((card) => card.order), isNot(contains(17)));
    expect(cards.map((card) => card.order), isNot(contains(18)));
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

  test('우월코드 옵션을 속성별로 합산하고 해당 속성의 최고 니케를 표시한다', () {
    final fire = _nikke(3001, 'fire_test', '작열 테스트', ElementType.Fire);
    final waterTop = _nikke(3002, 'water_top', '수냉 대표', ElementType.Water);
    final waterSecond =
        _nikke(3003, 'water_second', '수냉 보조', ElementType.Water);

    final cards = RecapService.build(
      profile: {
        'characters': [
          _superiorCodeCharacter(3001, [15]),
          _superiorCodeCharacter(3002, [10]),
          _superiorCodeCharacter(3003, [9]),
        ],
      },
      nikkesByCode: {3001: fire, 3002: waterTop, 3003: waterSecond},
      accountSeed: 'superior-code-element',
    );

    final card = cards.firstWhere((card) => card.order == 7);
    expect(
      card.title,
      '우월코드 데미지 증가 옵션은\n수냉에서 제일 높았어요!',
    );
    expect(card.details, ['우월코드 데미지 증가 총합 42.90%']);
    expect(card.imageAsset, waterTop.imageUrl);
  });

  test('에반게리온 니케를 3돌파하면 해당 목록과 이미지를 표시한다', () {
    final asuka = _nikke(2001, 'asuka', '아스카', ElementType.Fire);
    final reiEva = _nikke(2002, 'rei(eva)', '레이', ElementType.Iron);
    final asukaWille =
        _nikke(2003, 'asuka_wille', '아스카 : WILLE', ElementType.Fire);
    final tentativeRei = _nikke(
      2004,
      'rei_tentative_name',
      '레이 (가칭)',
      ElementType.Iron,
    );
    final evangelionNikkes = <int, Nikke>{
      2001: asuka,
      2002: reiEva,
      2003: asukaWille,
      2004: tentativeRei,
    };

    final cards = RecapService.build(
      profile: {
        'characters': [
          {'name_code': 2001, 'grade': 3},
          {'name_code': 2002, 'grade': 3},
          {'name_code': 2003, 'grade': 2},
          {'name_code': 2004, 'grade': 0},
        ],
      },
      nikkesByCode: evangelionNikkes,
      accountSeed: 'evangelion-love',
    );

    final card = cards.firstWhere((card) => card.order == 13);
    expect(card.title, '에반게리온을\n정말 사랑해요!');
    expect(card.details, ['아스카, 레이의 풀 돌파 보유']);
    expect(card.imageAsset, anyOf(asuka.imageUrl, reiEva.imageUrl));

    final noFullLimitCards = RecapService.build(
      profile: {
        'characters': [
          {'name_code': 2001, 'grade': 2},
          {'name_code': 2002, 'grade': 2},
        ],
      },
      nikkesByCode: evangelionNikkes,
      accountSeed: 'evangelion-no-full-limit',
    );
    expect(noFullLimitCards.map((card) => card.order), isNot(contains(13)));
  });

  test('크로우가 1코어 이상이면 화력 카드 앞에 크로우단 카드를 표시한다', () {
    final crow = _nikke(1004, 'crow', '크로우', ElementType.Fire);
    final crowNikkes = <int, Nikke>{1004: crow};

    final cards = RecapService.build(
      profile: {
        'recycleRoom': [
          {'tid': 1101, 'lv': 2},
          {'tid': 1102, 'lv': 1},
        ],
        'characters': [
          {'name_code': 1004, 'core': 3},
        ],
      },
      nikkesByCode: crowNikkes,
      accountSeed: 'crow-devotee',
    );

    final crowCard = cards.firstWhere((card) => card.order == 14);
    expect(crowCard.title, '크로우단...\n이셨군요...? 세상에...');
    expect(crowCard.details, ['크로우의 코어강화 +3']);
    expect(crowCard.imageAsset, crow.imageUrl);
    expect(cards.firstWhere((card) => card.order == 15).eyebrow, 'FIREPOWER!');

    final noCoreCards = RecapService.build(
      profile: {
        'characters': [
          {'name_code': 1004, 'core': 0},
        ],
      },
      nikkesByCode: crowNikkes,
      accountSeed: 'crow-no-core',
    );
    expect(noCoreCards.map((card) => card.order), isNot(contains(14)));
  });

  test('최강 니케는 11줄·평균 10레벨 경계를 적용하고 인원에 맞게 표시한다', () {
    final singleCards = RecapService.build(
      profile: {
        'characters': [
          _ultimateCharacter(1001, optionLevel: 9, optionCount: 12),
          _ultimateCharacter(1002, optionLevel: 10, optionCount: 11),
        ],
      },
      nikkesByCode: nikkes,
      accountSeed: 'ultimate-single',
    );
    final single = singleCards.firstWhere((card) => card.order == 16);
    expect(single.title, '최강의 니케 테스트 니케를 보유 중이에요');
    expect(single.imageAsset, waterNikke.imageUrl);

    final multipleCards = RecapService.build(
      profile: {
        'characters': [
          _ultimateCharacter(1001, optionLevel: 10, optionCount: 11),
          _ultimateCharacter(1002, optionLevel: 15, optionCount: 12),
        ],
      },
      nikkesByCode: nikkes,
      accountSeed: 'ultimate-multiple',
    );
    final multiple = multipleCards.firstWhere((card) => card.order == 16);
    expect(multiple.title, '최강의 니케를\n2명 보유 중이에요');
    expect(
      multiple.imageAsset,
      anyOf(rapi.imageUrl, waterNikke.imageUrl),
    );

    final scarlet = _nikke(1003, 'scarlet', '홍련', ElementType.Electric);
    final consonantCards = RecapService.build(
      profile: {
        'characters': [
          _ultimateCharacter(1003, optionLevel: 10, optionCount: 11),
        ],
      },
      nikkesByCode: {1003: scarlet},
      accountSeed: 'ultimate-consonant',
    );
    expect(
      consonantCards.firstWhere((card) => card.order == 16).title,
      '최강의 니케 홍련을 보유 중이에요',
    );
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

Map<String, dynamic> _ultimateCharacter(
  int code, {
  required int optionLevel,
  required int optionCount,
}) {
  var remainingOptions = optionCount;
  final equipment = <Map<String, dynamic>>[];
  for (final slot in ['head', 'torso', 'arm', 'leg']) {
    final slotOptionCount = remainingOptions >= 3 ? 3 : remainingOptions;
    equipment.add({
      'slot': slot,
      'tier': 10,
      'level': 5,
      'overloadOptions': [
        for (var index = 0; index < slotOptionCount; index++)
          7000500 + optionLevel,
      ],
    });
    remainingOptions -= slotOptionCount;
  }
  return {
    'name_code': code,
    'core': 7,
    'skills': {'skill1': 10, 'skill2': 10, 'burst': 10},
    'equipment': equipment,
  };
}

Map<String, dynamic> _superiorCodeCharacter(int code, List<int> levels) {
  return {
    'name_code': code,
    'equipment': [
      {
        'slot': 'head',
        'overloadOptions': levels.map((level) => 7000500 + level).toList(),
      },
    ],
  };
}
