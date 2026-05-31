import '../models/shared_deck.dart';
import 'local_file_saver.dart';

class MockDeckRepository {
  static final List<SharedDeck> _decks = [
    SharedDeck(
      id: "deck_1",
      authorName: "MIMIR",
      title: "05.31기준 일본서버 1위덱 (종합 557억+)",
      description: "일섭1위덱.\n"
          "• 1번 스쿼드: 62.8억.\n"
          "• 2번 스쿼드: 107.1억.\n"
          "• 3번 스쿼드: 125.3억.\n"
          "• 4번 스쿼드: 160.7억.\n"
          "• 5번 스쿼드: 101.3억.\n",
      upvotes: 24,
      downvotes: 1,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      squadsNikkeIds: [
        [
          'rapi_red_hood',
          'nayuta',
          'quency_escape_queen',
          'guilotine_winter_slayer',
          'red_hood'
        ],
        [
          'anis_star',
          'bready',
          'anchor_innocent_maid',
          'mast_romantic_maid',
          'diesel_winter_sweets'
        ],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'soline_frost_ticket'
        ],
        ['zwei', 'mint', 'snow_white_heavy_arms', 'privaty', 'little_mermaid'],
        [
          'liter',
          'crown',
          'helm',
          'ludmilla_winter_owner',
          'elegg_boom_and_shock'
        ],
      ],
    ),
    SharedDeck(
      id: "deck_2",
      authorName: "MIMIR",
      title: "05.31기준 한국서버 1위덱 (종합 552억+)",
      description: "일섭1위덱.\n"
          "• 1번 스쿼드: 163.3억.\n"
          "• 2번 스쿼드: 121.4억.\n"
          "• 3번 스쿼드: 113.1억.\n"
          "• 4번 스쿼드: 61.8억.\n"
          "• 5번 스쿼드: 93.0억.\n",
      upvotes: 16,
      downvotes: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      squadsNikkeIds: [
        [
          'zwei',
          'mint',
          'snow_white_heavy_arms',
          'privaty',
          'little_mermaid',
        ],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'soline_frost_ticket'
        ],
        [
          'anis_star',
          'bready',
          'anchor_innocent_maid',
          'mast_romantic_maid',
          'guilotine_winter_slayer'
        ],
        [
          'rapi_red_hood',
          'nayuta',
          'quency_escape_queen',
          'red_hood',
          'mihara_bonding_chain',
        ],
        [
          'liter',
          'helm',
          'ludmilla_winter_owner',
          'elegg_boom_and_shock',
          'crown',
        ],
      ],
    ),
    SharedDeck(
      id: "deck_3",
      authorName: "MIMIR",
      title: "클루드, 민트 + 프리카 없는 덱 (339억)",
      description: "한정 수냉 딜러인 클루드를 획득하지 못해 조합에 어려움을 겪는 유저들을 위한 덱입니다.\n",
      upvotes: 12,
      downvotes: 2,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      squadsNikkeIds: [
        [
          'crown',
          'liter',
          'rapi_red_hood',
          'helm',
          'elegg_boom_and_shock',
        ],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'soline_frost_ticket'
        ],
        [
          'miranda',
          'nayuta',
          'snow_white_heavy_arms',
          'privaty',
          'little_mermaid',
        ],
        [
          'anis_star',
          'mast_romantic_maid',
          'neon_vision_eye',
          'liberalio',
          'anchor_innocent_maid',
        ],
        [
          'moran',
          'grave',
          'cinderella',
          'red_hood',
          'quency_escape_queen',
        ],
      ],
    ),
    SharedDeck(
      id: "shared_1780234522118",
      authorName: "MIMIR",
      title: "한정캐 하나도 없는 덱 (고뇨)",
      description: "민트, 프리카 없을 경우에 리타, 바니에이드 넣어서 노힐덱으로 진행합니다.",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-05-31T22:35:22.118"),
      squadsNikkeIds: [
        [
          'quency_escape_queen',
          'rouge',
          'cinderella',
          'blanc',
          'mihara_bonding_chain'
        ],
        [
          'moran',
          'mast_romantic_maid',
          'alice',
          'bready',
          'anchor_innocent_maid'
        ],
        ['anis_star', 'prika', 'mint', 'red_hood', 'neon_vision_eye'],
        [
          'miranda',
          'nayuta',
          'snow_white_heavy_arms',
          'privaty',
          'd_killer_wife'
        ],
        [
          'little_mermaid',
          'crown',
          'rapi_red_hood',
          'helm',
          'elegg_boom_and_shock'
        ],
      ],
    ),
    SharedDeck(
      id: "shared_1780234848632",
      authorName: "MIMIR",
      title: "정석조합덱",
      description:
          "빵순이에 클디젤 붙이고 앵커 톡톡이\n경우에 따라 2덱에 크라운 붙이고 1덱에 나유타 붙이는게 쌜 수 있습니다.",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-05-31T22:40:48.632"),
      squadsNikkeIds: [
        [
          'liter',
          'crown',
          'helm',
          'ludmilla_winter_owner',
          'elegg_boom_and_shock'
        ],
        [
          'miranda',
          'nayuta',
          'snow_white_heavy_arms',
          'privaty',
          'little_mermaid'
        ],
        [
          'anis_star',
          'mast_romantic_maid',
          'bready',
          'diesel_winter_sweets',
          'anchor_innocent_maid'
        ],
        ['rapi_red_hood', 'liberalio', 'prika', 'neon_vision_eye', 'mint'],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'soline_frost_ticket'
        ],
      ],
    ),
  ];

  static List<SharedDeck> getAllDecks() {
    return List.from(_decks);
  }

  static void addDeck(SharedDeck deck) {
    _decks.insert(0, deck);
    saveDeckToLocalFile(deck);
  }

  static void voteDeck(String deckId, int voteValue) {
    final idx = _decks.indexWhere((d) => d.id == deckId);
    if (idx != -1) {
      if (voteValue == 1) {
        _decks[idx].upvotes += 1;
      } else if (voteValue == -1) {
        _decks[idx].downvotes += 1;
      }
    }
  }
}
