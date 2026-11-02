import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimir/services/nikke_score_service.dart';

void main() {
  test('profile read loads all saved scores in one read-only request',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, '/getNikkeScores');
      expect(jsonDecode(request.body), {'openId': 'account'});
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'status': 'complete',
              'results': {
                '5129:fire': {
                  'status': 'complete',
                  'score': 101.5,
                  'damage': 2030000000,
                  'calcVersion': 'old-version',
                  'sampleCount': 0,
                  'team': ['saved party member']
                },
                '5129:iron': {
                  'status': 'complete',
                  'score': 50,
                  'damage': 1000000000,
                  'calcVersion': 'old-version',
                  'sampleCount': 0
                },
              }
            }
          }),
          200);
    });
    final snapshot = await NikkeScoreService.loadStoredScores(
        openId: 'account', client: client, readToken: () async => 'test');
    for (var i = 0; i < 4; i++) {
      expect(snapshot.resultFor('5129:fire').score, 101.5);
      expect(snapshot.resultFor('5129:fire').teamNames, ['saved party member']);
      expect(snapshot.resultFor('5129:iron').score, 50);
    }
    expect(calls, 1);
  });

  test('missing or failed saved scores never initiate fallback calculation',
      () async {
    for (final state in ['not_saved', 'running', 'partial']) {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/getNikkeScores');
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'status': state,
                'results': state == 'partial'
                    ? {
                        '5129:fire': {
                          'status': 'error',
                          'error': 'Stored failure'
                        }
                      }
                    : {}
              }
            }),
            200);
      });
      final snapshot = await NikkeScoreService.loadStoredScores(
          openId: 'account', client: client, readToken: () async => 'test');
      expect(() => snapshot.resultFor('5129:fire'),
          throwsA(isA<NikkeScoreException>()));
      expect(calls, 1);
    }
  });
}
