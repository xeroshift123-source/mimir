import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../models/shared_deck.dart';

class SharedDeckService {
  SharedDeckService()
      : _decks = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'mimirdb',
        ).collection('shared_decks');

  final CollectionReference<Map<String, dynamic>> _decks;
  static const _functionsBaseUrl =
      'https://us-central1-nikke-mimir.cloudfunctions.net';

  Stream<List<SharedDeck>> watchDecks() {
    return _decks
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            return SharedDeck.fromJson({
              ...document.data(),
              'id': document.id,
            });
          }).toList(),
        );
  }

  Future<SharedDeck> createDeck(SharedDeck deck) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || deck.authorUid != user.uid) {
      throw StateError('로그인 정보를 확인할 수 없습니다.');
    }

    final document = _decks.doc();
    final data = deck.toJson()
      ..remove('id')
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await document.set(data);
    return deck.copyWith(id: document.id);
  }

  Future<SharedDeck> updateDeck(SharedDeck deck) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || deck.authorUid != user.uid || deck.id.isEmpty) {
      throw StateError('게시글 수정 권한을 확인할 수 없습니다.');
    }
    final data = deck.toJson()
      ..remove('id')
      ..remove('createdAt')
      ..remove('upvotes')
      ..remove('downvotes')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _decks.doc(deck.id).update(data);
    return deck;
  }

  Future<SharedDeckVoteResult> vote(String deckId, int value) async {
    if (value != -1 && value != 1) {
      throw ArgumentError.value(value, 'value', '추천 값은 1 또는 -1이어야 합니다.');
    }
    final result = await _postFunction(
      'voteSharedDeck',
      {'deckId': deckId, 'value': value},
    );
    return SharedDeckVoteResult(
      vote: (result['vote'] as num?)?.toInt() ?? 0,
      upvotes: (result['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (result['downvotes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> deleteDeck(String deckId) async {
    await _postFunction('deleteSharedDeck', {'deckId': deckId});
  }

  Future<Map<String, dynamic>> _postFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('로그인 인증 토큰을 발급할 수 없습니다.');
    }

    final response = await http.post(
      Uri.parse('$_functionsBaseUrl/$functionName'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw StateError('서버 응답 형식이 올바르지 않습니다.');
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200 || result['success'] != true) {
      throw StateError(result['error']?.toString() ?? '요청을 처리하지 못했습니다.');
    }
    return result;
  }
}

class SharedDeckVoteResult {
  const SharedDeckVoteResult({
    required this.vote,
    required this.upvotes,
    required this.downvotes,
  });

  final int vote;
  final int upvotes;
  final int downvotes;
}
