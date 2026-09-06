import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/enums.dart';
import 'package:mimir/models/nikke.dart';

Nikke _nikke(String id, String element) => Nikke.fromJson({
      'id': id,
      'name': id,
      'imageUrl': 'assets/nikke/$id.webp',
      'burst': '3',
      'element': element,
      'weaponType': 'SG',
      'company': 'Tetra',
      'coolTime': 40,
      'type': 'ATK',
      'ability': <String>[],
      'rank': 'SSR',
    });

void main() {
  test('슈가는 철갑과 수냉 속성 필터에서 모두 검색된다', () {
    final sugar = _nikke('sugar', 'Iron');

    expect(sugar.matchesElementFilters({ElementType.Iron}), isTrue);
    expect(sugar.matchesElementFilters({ElementType.Water}), isTrue);
    expect(sugar.matchesElementFilters({ElementType.Fire}), isFalse);
  });

  test('라피 레드 후드는 작열과 철갑 속성 필터에서 모두 검색된다', () {
    final rapi = _nikke('rapi_red_hood', 'Fire');

    expect(rapi.matchesElementFilters({ElementType.Fire}), isTrue);
    expect(rapi.matchesElementFilters({ElementType.Iron}), isTrue);
    expect(rapi.matchesElementFilters({ElementType.Water}), isFalse);
  });
}
