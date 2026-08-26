import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/nikke.dart';
import '../models/recap_card.dart';
import '../utils/blabla_map.dart';

class RecapService {
  static const _normalCampaign48Stage36Id = 6048044;

  static const _skillCosts = <int, _SkillCost>{
    2: _SkillCost(blue: 8),
    3: _SkillCost(blue: 10),
    4: _SkillCost(blue: 26),
    5: _SkillCost(blue: 42, purple: 60, attribute: 10),
    6: _SkillCost(blue: 126, purple: 90, attribute: 15),
    7: _SkillCost(blue: 168, purple: 120, attribute: 30),
    8: _SkillCost(blue: 210, purple: 150, yellow: 90, attribute: 70),
    9: _SkillCost(blue: 231, purple: 165, yellow: 105, attribute: 100),
    10: _SkillCost(blue: 273, purple: 190, yellow: 120, attribute: 135),
  };

  static List<RecapCardData> build({
    required Map<String, dynamic> profile,
    required Map<int, Nikke> nikkesByCode,
    required String accountSeed,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final chars = _maps(profile['characters']);
    final ownedCount = _asInt(profile['ownedNikkesCount']) ?? chars.length;
    final cards = <RecapCardData>[];

    final joinedAt = _asDateTime(
      profile['joinedAt'] ?? profile['createdAt'] ?? profile['created_at'],
    );
    if (joinedAt != null) {
      final joinedDay = DateTime(joinedAt.year, joinedAt.month, joinedAt.day);
      final currentDay = DateTime(today.year, today.month, today.day);
      final days = currentDay.difference(joinedDay).inDays.clamp(0, 999999);
      cards.add(RecapCardData(
        order: 1,
        eyebrow: 'OUR FIRST ENCOUNTER',
        title: '라피와 처음 만난 지\n${_number(days)}일이 지났어요',
        imageAsset: _asset(nikkesByCode, 'rapi'),
        colors: const [Color(0xFFD51F2A), Color(0xFF09090B)],
        textColor: Colors.white,
        accentColor: const Color(0xFFFFC3C7),
        details: ['가입일 ${DateFormat('yyyy.MM.dd').format(joinedDay)}'],
      ));
    }

    if (_isFinalNormalCampaign(profile['normalCampaign'])) {
      cards.add(RecapCardData(
        order: 2,
        eyebrow: 'STORY COMPLETE',
        title: '니케의 모든 이야기를\n완료했어요',
        imageAsset: _asset(nikkesByCode, 'rapi_red_hood'),
        colors: const [Color(0xFFEF3340), Color(0xFF08080A)],
        textColor: Colors.white,
        accentColor: const Color(0xFFFFC4C7),
        details: ['NORMAL 48-36'],
      ));
    }

    cards.add(RecapCardData(
      order: 3,
      eyebrow: 'TOGETHER WITH NIKKE',
      title: '${_number(ownedCount)}명의 니케들과\n함께했어요',
      imageAsset: _asset(nikkesByCode, 'privaty'),
      colors: const [Color(0xFF20C6AD), Color(0xFF087D82)],
      textColor: Colors.white,
      accentColor: const Color(0xFFB8FFF1),
    ));

    final maxCoreNikkes = chars
        .where((c) =>
            _asInt(c['core']) == 7 &&
            nikkesByCode[_asInt(c['name_code'])] != null)
        .toList();
    final maxCoreCount = chars.where((c) => _asInt(c['core']) == 7).length;
    final maxCoreCharacter = _stablePick(
      maxCoreNikkes,
      '$accountSeed:max-core',
    );
    final maxCoreNikke = maxCoreCharacter == null
        ? null
        : nikkesByCode[_asInt(maxCoreCharacter['name_code'])];
    cards.add(RecapCardData(
      order: 4,
      eyebrow: 'MAXIMUM POTENTIAL',
      title: '그중 ${_number(maxCoreCount)}명의 니케의\n잠재력을 끝까지 폭발시켰어요',
      imageAsset: maxCoreNikke?.imageUrl,
      colors: const [Color(0xFF111216), Color(0xFF111216), Color(0xFFD01D32)],
      textColor: Colors.white,
      accentColor: const Color(0xFFFF5364),
      details: ['풀코강한 니케들의 수'],
    ));

    final chips = _calculateChips(chars, nikkesByCode);
    cards.add(RecapCardData(
      order: 5,
      eyebrow: 'SKILL INVESTMENT',
      title: '총 ${_number(chips.total)}개의\n스킬 칩을 사용했어요',
      imageAsset: _asset(nikkesByCode, 'crown'),
      colors: const [Color(0xFFFFFCED), Color(0xFFEADDBE)],
      textColor: const Color(0xFF201D18),
      accentColor: const Color(0xFF9B751E),
      details: [
        '스킬 칩 · 파랑 ${_number(chips.skillBlue)} · 보라 ${_number(chips.skillPurple)} · 노랑 ${_number(chips.skillYellow)}',
        '버스트 칩 · 파랑 ${_number(chips.burstBlue)} · 보라 ${_number(chips.burstPurple)} · 노랑 ${_number(chips.burstYellow)}',
        '속성 칩 · ${_number(chips.attribute)}',
      ],
    ));

    final topElement = chips.attributeByElement.entries.toList()
      ..sort((a, b) {
        final value = b.value.compareTo(a.value);
        return value != 0 ? value : a.key.index.compareTo(b.key.index);
      });
    final element =
        topElement.isEmpty ? ElementType.Fire : topElement.first.key;
    final elementChips = topElement.isEmpty ? 0 : topElement.first.value;
    final elementTheme = _elementTheme(element);
    final topElementCharacter = chars
        .where((char) =>
            nikkesByCode[_asInt(char['name_code'])]?.element == element)
        .fold<Map<String, dynamic>?>(null, (best, char) {
      if (best == null) return char;
      final combat = _asInt(char['combat']) ?? 0;
      final bestCombat = _asInt(best['combat']) ?? 0;
      if (combat != bestCombat) return combat > bestCombat ? char : best;
      return (_asInt(char['name_code']) ?? 0) < (_asInt(best['name_code']) ?? 0)
          ? char
          : best;
    });
    final topElementNikke = topElementCharacter == null
        ? null
        : nikkesByCode[_asInt(topElementCharacter['name_code'])];
    cards.add(RecapCardData(
      order: 6,
      eyebrow: 'ELEMENT SPECIALIST',
      title: '${_elementName(element)} 속성에\n가장 많은 투자를 하셨군요!',
      imageAsset: topElementNikke?.imageUrl,
      colors: elementTheme.colors,
      textColor: Colors.white,
      accentColor: elementTheme.accent,
      details: ['속성 칩 ${_number(elementChips)}개'],
    ));

    final overloadCount = chars.fold<int>(
      0,
      (sum, c) => sum + _equipment(c).where(_isOverloaded).length,
    );
    cards.add(RecapCardData(
      order: 7,
      eyebrow: 'OVERLOAD',
      title: '${_number(overloadCount)}개의\n오버로드 장비를 만들었어요',
      imageAsset: _asset(nikkesByCode, 'centi'),
      colors: const [Color(0xFFFF9D00), Color(0xFFFF5A22), Color(0xFFB91224)],
      textColor: Colors.white,
      accentColor: const Color(0xFFFFE29A),
    ));

    final favoriteItemCount =
        chars.where((c) => c['favoriteItem'] != null).length;
    cards.add(RecapCardData(
      order: 8,
      eyebrow: 'PRECIOUS GIFT',
      title: '니케들에게 ${_number(favoriteItemCount)}개의\n인형을 선물했어요',
      imageAsset: _asset(nikkesByCode, 'maxwell'),
      colors: const [Color(0xFF1756A9), Color(0xFF12213D), Color(0xFF080C15)],
      textColor: Colors.white,
      accentColor: const Color(0xFFFFD33D),
    ));

    final masterpieceShoeOwners = chars.where((char) {
      return _equipment(char).any((equipment) {
        return equipment['slot']?.toString() == 'leg' &&
            _isOverloaded(equipment) &&
            _asInt(equipment['level']) == 5;
      });
    }).toList();
    final masterpieceShoes = masterpieceShoeOwners.fold<int>(
      0,
      (sum, char) =>
          sum +
          _equipment(char).where((equipment) {
            return equipment['slot']?.toString() == 'leg' &&
                _isOverloaded(equipment) &&
                _asInt(equipment['level']) == 5;
          }).length,
    );
    if (masterpieceShoes > 0) {
      final shoeOwner = _stablePick(
        masterpieceShoeOwners
            .where((char) => nikkesByCode[_asInt(char['name_code'])] != null)
            .toList(),
        '$accountSeed:masterpiece-shoes',
      );
      final shoeOwnerNikke = shoeOwner == null
          ? null
          : nikkesByCode[_asInt(shoeOwner['name_code'])];
      cards.add(RecapCardData(
        order: 9,
        eyebrow: 'MASTERPIECE SHOES',
        title: '+5 강화 명품 신발을\n${_number(masterpieceShoes)}개나 가지고 있어요',
        imageAsset: shoeOwnerNikke?.imageUrl,
        colors: const [Color(0xFFF6F6F8), Color(0xFFBBBCC4), Color(0xFF111218)],
        textColor: const Color(0xFF111218),
        accentColor: const Color(0xFFCE2448),
        details: ['+5강화한 신발의 갯수'],
      ));
    }

    final costumeCount = _asInt(profile['costumeCount']) ?? 0;
    cards.add(RecapCardData(
      order: 10,
      eyebrow: 'FASHION COLLECTION',
      title: '니케들의 코스튬을\n${_number(costumeCount)}개나 가지고 있어요',
      imageAsset: _asset(nikkesByCode, 'rupee'),
      colors: const [Color(0xFFFFC928), Color(0xFFEF8E00), Color(0xFF17130A)],
      textColor: Colors.white,
      accentColor: const Color(0xFFFFF0A6),
    ));

    final strongest = _strongest(chars, nikkesByCode);
    if (strongest != null) {
      cards.add(RecapCardData(
        order: 11,
        eyebrow: 'THE STRONGEST NIKKE',
        title: '가장 강력한 니케는…\n${strongest.nikke.name}',
        imageAsset: strongest.nikke.imageUrl,
        colors: _dynamicColors(strongest.nikke.element),
        textColor: Colors.white,
        accentColor: const Color(0xFFFFE17A),
        details: ['우월 코드 + 공격력 ${strongest.score.toStringAsFixed(2)}%'],
      ));
    }

    final attacker = _consoleLevel(profile, 1101);
    final defender = _consoleLevel(profile, 1102);
    final firepowerDifference = attacker - defender;
    if (firepowerDifference > 0) {
      cards.add(RecapCardData(
        order: 12,
        eyebrow: 'FIREPOWER!',
        title: '화력을 방어보다\n${_number(firepowerDifference)}만큼 더 사랑해요',
        imageAsset: _asset(nikkesByCode, 'neon_vision_eye'),
        colors: const [Color(0xFF070A11), Color(0xFF093E83), Color(0xFF088DDF)],
        textColor: Colors.white,
        accentColor: const Color(0xFF75DCFF),
        details: [
          '화력형 콘솔 레벨 $attacker, 방어형 콘솔 레벨 $defender',
        ],
      ));
    }

    final soulmates = chars.where((c) {
      return (_asInt(c['bondLevel']) ?? 0) >= 30 &&
          _equipment(c)
                  .where(_isOverloaded)
                  .map((e) => e['slot'])
                  .toSet()
                  .length >=
              4 &&
          nikkesByCode[_asInt(c['name_code'])] != null;
    }).toList();
    if (soulmates.isNotEmpty) {
      cards.add(const RecapCardData(
        order: 13,
        eyebrow: 'ONE LAST STORY',
        title: '당신의 천생연분 니케는…',
        colors: [Color(0xFF11162D), Color(0xFF4B237B), Color(0xFF120D22)],
        textColor: Colors.white,
        accentColor: Color(0xFFD8B4FF),
      ));
      soulmates.sort((a, b) =>
          (_asInt(a['name_code']) ?? 0).compareTo(_asInt(b['name_code']) ?? 0));
      final selected =
          soulmates[_stableIndex('$accountSeed:soulmate', soulmates.length)];
      final nikke = nikkesByCode[_asInt(selected['name_code'])]!;
      cards.add(RecapCardData(
        order: 14,
        eyebrow: 'DESTINED PARTNER',
        title: nikke.name,
        imageAsset: nikke.imageUrl,
        colors: const [Color(0xFF6D1231), Color(0xFF2A101E), Color(0xFFD4A84F)],
        textColor: Colors.white,
        accentColor: const Color(0xFFFFE6A0),
      ));
    }

    return cards;
  }

  static _ChipTotals _calculateChips(
    List<Map<String, dynamic>> chars,
    Map<int, Nikke> nikkesByCode,
  ) {
    var skillBlue = 0;
    var skillPurple = 0;
    var skillYellow = 0;
    var burstBlue = 0;
    var burstPurple = 0;
    var burstYellow = 0;
    var attribute = 0;
    final byElement = <ElementType, int>{};
    for (final char in chars) {
      final skills = char['skills'] is Map
          ? Map<String, dynamic>.from(char['skills'] as Map)
          : const <String, dynamic>{};
      final nikke = nikkesByCode[_asInt(char['name_code'])];
      for (final entry in const [
        ('skill1', false),
        ('skill2', false),
        ('burst', true)
      ]) {
        final level = (_asInt(skills[entry.$1]) ?? 1).clamp(1, 10);
        for (var target = 2; target <= level; target++) {
          final cost = _skillCosts[target]!;
          if (entry.$2) {
            burstBlue += cost.blue;
            burstPurple += cost.purple;
            burstYellow += cost.yellow;
          } else {
            skillBlue += cost.blue;
            skillPurple += cost.purple;
            skillYellow += cost.yellow;
          }
          final elementCost = cost.attribute * (entry.$2 ? 2 : 1);
          attribute += elementCost;
          if (nikke != null) {
            byElement.update(nikke.element, (value) => value + elementCost,
                ifAbsent: () => elementCost);
          }
        }
      }
    }
    return _ChipTotals(
      skillBlue: skillBlue,
      skillPurple: skillPurple,
      skillYellow: skillYellow,
      burstBlue: burstBlue,
      burstPurple: burstPurple,
      burstYellow: burstYellow,
      attribute: attribute,
      attributeByElement: byElement,
    );
  }

  static _Strongest? _strongest(
    List<Map<String, dynamic>> chars,
    Map<int, Nikke> nikkesByCode,
  ) {
    _Strongest? best;
    for (final char in chars) {
      final nikke = nikkesByCode[_asInt(char['name_code'])];
      if (nikke == null) continue;
      var score = 0.0;
      for (final equipment in _equipment(char)) {
        final options = equipment['overloadOptions'];
        if (options is! List) continue;
        for (final rawOption in options) {
          final option = _asInt(rawOption) ?? 0;
          final name = BlablaMap.getOptionName(option);
          if (name.contains('우월코드') ||
              name.contains('우월 코드') ||
              name.contains('공격력')) {
            score += BlablaMap.getOptionPercent(option);
          }
        }
      }
      final combat = _asInt(char['combat']) ?? 0;
      if (best == null ||
          score > best.score ||
          (score == best.score && combat > best.combat)) {
        best = _Strongest(nikke, score, combat);
      }
    }
    return best;
  }

  static bool _isOverloaded(Map<String, dynamic> equipment) {
    if ((_asInt(equipment['tier']) ?? 0) >= 10) return true;
    final options = equipment['overloadOptions'];
    return options is List && options.any((value) => (_asInt(value) ?? 0) != 0);
  }

  static List<Map<String, dynamic>> _equipment(Map<String, dynamic> char) =>
      _maps(char['equipment']);

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static int _consoleLevel(Map<String, dynamic> profile, int tid) {
    for (final item in _maps(profile['recycleRoom'])) {
      if (_asInt(item['tid']) == tid) return _asInt(item['lv']) ?? 0;
    }
    return 0;
  }

  static String? _asset(Map<int, Nikke> nikkes, String id) {
    for (final nikke in nikkes.values) {
      if (nikke.id == id) return nikke.imageUrl;
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value == null) return null;
    try {
      final converted = (value as dynamic).toDate();
      if (converted is DateTime) return converted.toLocal();
    } catch (_) {}
    if (value is Map) {
      final seconds = _asInt(value['seconds'] ?? value['_seconds']);
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
      }
    }
    final raw = value.toString().trim();
    if (RegExp(r'^\d{8}$').hasMatch(raw)) {
      final year = int.parse(raw.substring(0, 4));
      final month = int.parse(raw.substring(4, 6));
      final day = int.parse(raw.substring(6, 8));
      if (year >= 2000 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    final numeric = _asInt(value);
    if (numeric != null && numeric > 1000000000) {
      var milliseconds = numeric;
      while (milliseconds > 9999999999999) {
        milliseconds ~/= 1000;
      }
      if (milliseconds < 100000000000) milliseconds *= 1000;
      try {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
      } catch (_) {
        return null;
      }
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  static bool _isFinalNormalCampaign(dynamic value) {
    if (_asInt(value) == _normalCampaign48Stage36Id) return true;
    if (value is String) {
      final normalized = value
          .toUpperCase()
          .replaceAll('NORMAL', '')
          .replaceAll('STAGE', '')
          .replaceAll('BOSS', '')
          .trim();
      return normalized == '48-36';
    }
    if (value is Map) {
      final chapter = _asInt(value['chapter'] ?? value['chapter_id']);
      final stage = _asInt(value['stage'] ?? value['stage_id']);
      if (chapter == 48 && stage == 36) return true;
      if (_asInt(value['id']) == _normalCampaign48Stage36Id) return true;
    }
    return false;
  }

  static String _number(num value) => NumberFormat('#,###').format(value);

  static int _stableIndex(String seed, int length) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash % length;
  }

  static Map<String, dynamic>? _stablePick(
    List<Map<String, dynamic>> candidates,
    String seed,
  ) {
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) =>
        (_asInt(a['name_code']) ?? 0).compareTo(_asInt(b['name_code']) ?? 0));
    return candidates[_stableIndex(seed, candidates.length)];
  }

  static String _elementName(ElementType value) => switch (value) {
        ElementType.Fire => '작열',
        ElementType.Water => '수냉',
        ElementType.Wind => '풍압',
        ElementType.Electric => '전격',
        ElementType.Iron => '철갑',
      };

  static _ElementTheme _elementTheme(ElementType value) => switch (value) {
        ElementType.Fire => const _ElementTheme(
            [Color(0xFFD62D20), Color(0xFF4A0B12)], Color(0xFFFFB09E)),
        ElementType.Water => const _ElementTheme(
            [Color(0xFF007EA8), Color(0xFF062A54)], Color(0xFF8DEBFF)),
        ElementType.Wind => const _ElementTheme(
            [Color(0xFF1FAE91), Color(0xFF123D52)], Color(0xFFB8FFE7)),
        ElementType.Electric => const _ElementTheme(
            [Color(0xFF7048D7), Color(0xFF21134C)], Color(0xFFD6C4FF)),
        ElementType.Iron => const _ElementTheme(
            [Color(0xFF9B7A42), Color(0xFF30343B)], Color(0xFFFFDEA0)),
      };

  static List<Color> _dynamicColors(ElementType element) {
    final theme = _elementTheme(element);
    return [theme.colors.first, const Color(0xFF11131A), theme.colors.last];
  }
}

class _SkillCost {
  const _SkillCost(
      {this.blue = 0, this.purple = 0, this.yellow = 0, this.attribute = 0});
  final int blue;
  final int purple;
  final int yellow;
  final int attribute;
}

class _ChipTotals {
  const _ChipTotals({
    required this.skillBlue,
    required this.skillPurple,
    required this.skillYellow,
    required this.burstBlue,
    required this.burstPurple,
    required this.burstYellow,
    required this.attribute,
    required this.attributeByElement,
  });
  final int skillBlue;
  final int skillPurple;
  final int skillYellow;
  final int burstBlue;
  final int burstPurple;
  final int burstYellow;
  final int attribute;
  final Map<ElementType, int> attributeByElement;
  int get total =>
      skillBlue +
      skillPurple +
      skillYellow +
      burstBlue +
      burstPurple +
      burstYellow +
      attribute;
}

class _Strongest {
  const _Strongest(this.nikke, this.score, this.combat);
  final Nikke nikke;
  final double score;
  final int combat;
}

class _ElementTheme {
  const _ElementTheme(this.colors, this.accent);
  final List<Color> colors;
  final Color accent;
}
