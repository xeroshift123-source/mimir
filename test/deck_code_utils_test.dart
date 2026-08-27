import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/utils/deck_code_utils.dart';

void main() {
  group('DeckCodeUtils', () {
    test('encodes and decodes numeric Blabla name codes', () {
      final squads = <List<Object?>>[
        <Object?>[5013, 5114, null, 5103, 5077],
      ];

      final code = DeckCodeUtils.encodeDeck(type: 'solo', squads: squads);
      final decodedJson = jsonDecode(
        utf8.decode(base64Url.decode(code)),
      ) as Map<String, dynamic>;
      final decoded = DeckCodeUtils.decodeDeck(code);

      expect(decodedJson['squads'][0][0], 5013);
      expect(decoded?.type, 'solo');
      expect(decoded?.squads.first, <Object?>[5013, 5114, null, 5103, 5077]);
    });

    test('continues to decode legacy string ids', () {
      final legacyCode = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'type': 'solo',
            'squads': [
              ['red_hood', 'crown', null, null, null],
            ],
          }),
        ),
      );

      final decoded = DeckCodeUtils.decodeDeck(legacyCode);

      expect(
        decoded?.squads.first,
        <Object?>['red_hood', 'crown', null, null, null],
      );
    });
  });
}
