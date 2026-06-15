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
      season: "SEASON 37",
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
      season: "SEASON 37",
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
      season: "SEASON 37",
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
      season: "SEASON 37",
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
      season: "SEASON 37",
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
    SharedDeck(
      id: "shared_1781525157863",
      authorName: "MIMIR",
      title: "(예상)아레블X, 미란다-나유타X IN 3% 덱",
      description:
          "1덱은 이번 솔레에서 대다수가 고정으로 사용할 듯 해요 국룰 덱이라 보면 됨\n\n2덱은 머신건 덱이고 라피 자리는 벨벳, 풍레이 등으로 변경 가능\n\n3덱은 깡체급 샷건덱인데 이번 솔레에서 샷건덱이 어떤 모습을 보여주느냐에 따라 다른 덱이 쓰일 수도 있음\n\n4덱은 나유타 벨벳 덱이고 헬름, 클디젤로 나유타 몰아주는 조합\n\n5덱은 수화 짬덱\n\n솔린->볼륨으로 바꾸고\n\n마나를 다른 비우코 딜러 쓰는 것도 가능은 할 듯",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:05:57.863"),
      squadsNikkeIds: [
        [
          'anis_star',
          'mast_romantic_maid',
          'scarlet_black_shadow',
          'liberalio',
          'anchor_innocent_maid'
        ],
        ['little_mermaid', 'crown', 'asuka_wille', 'rapi_red_hood', 'privaty'],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'dolla'
        ],
        ['moran', 'nayuta', 'helm', 'diesel_winter_sweets', 'velvet'],
        [
          'miranda',
          'mint',
          'snow_white_heavy_arms',
          'mana',
          'soline_frost_ticket'
        ],
      ],
    ),
    SharedDeck(
      id: "shared_1781525547707",
      authorName: "MIMIR",
      title: "(예상)무난한 in10% 노노에게리",
      description:
          "- in10%를 노리는 무난한 덱입니다\n- 노노에게리 지휘관들을 위한 덱\n- 일단 미란다는 보류\n- 아블랙은 3% 각이 보이지 않으면 패스\n\n1파티\n- 마앵 흑리 아니스, 다 아시는 그 덱\n\n2파티\n- 풍스카가 없기에 라피 채용\n- 헬름으로 버충\n\n3파티\n- 미란다 대신 벨벳 채용\n- 벨벳이 속저까지 전담\n\n4파티\n- 힘이 많이 빠지는 샷건덱\n- 생존 가능 여부 확인 필요\n- 볼륨으로 쿨감 및 속저\n\n5파티\n- 네온과 민프덱\n- 마나로 속저 및 네온 차속 버프",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:12:27.708"),
      squadsNikkeIds: [
        [
          'mast_romantic_maid',
          'scarlet_black_shadow',
          'liberalio',
          'anis_star',
          'anchor_innocent_maid'
        ],
        ['crown', 'rapi_red_hood', 'helm', 'little_mermaid', 'privaty'],
        [
          'nayuta',
          'moran',
          'snow_white_heavy_arms',
          'diesel_winter_sweets',
          'velvet'
        ],
        [
          'arcana_fortune_mate',
          'tove',
          'dorothy_serendipity',
          'volume',
          'drake'
        ],
        ['liter', 'neon_vision_eye', 'mana', 'mint', 'prika'],
      ],
    ),
    SharedDeck(
      id: "shared_1781525920740",
      authorName: "MIMIR",
      title: "(예상)in200 지향 솔레덱",
      description:
          "- 목표% : in200 끝자락 (퀸 솔레 0.19%) 이지만!\n흑리덱/풍게리덱/나유타덱 쳐보고 안 될 것 같으면 포기하려고 벨벳이랑 아블랙 스작 171 777로 놔둔 상태\n\n- 1덱 : 정석 아마앵흑리, 패턴에 따라 선후버 정도만 변경 \n(뮤지엄 모더 기준 100.8억)\n\n- 2덱 : 풍압 그녀석들. 풍레이 작이 어느정도 돼 있어서 채용 \n(뮤지엄 모더 기준 74.7억)\n\n- 3덱 : 울라리 때처럼 라민프 조합에 우코딜러 아레블 + 버충 요원 겸 체급 딜러 각설이 채용\n각설 선버 굴린느 게 더 셌음 \n(뮤지엄 모더 기준 46.5억)\n\n- 4덱 : 애미나유타 대신 벨벳 쓰는 차댐증 강화 조합\n애니힐리오가 코어가 있던데, 만약 상시 코어라면 나유타 자체 고점이 더 높은 애미나유타로도 변경 가능 \n(뮤지엄 모더 기준 47.8억)\n\n- 5덱 : 짬덱 샷건덱, 속저용 도라\n(뮤지엄 모더 기준 34.3억)\n\n3,5덱 경우에 민프에 네온, 샷건덱 대신 애미+각설클디젤 덱 굴려봤는데 모앵이에선 각설민프+샷건 조합이 더 강했음",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:18:40.740"),
      squadsNikkeIds: [
        [
          'anis_star',
          'mast_romantic_maid',
          'anchor_innocent_maid',
          'scarlet_black_shadow',
          'liberalio'
        ],
        [
          'little_mermaid',
          'crown',
          'asuka_wille',
          'rei_tentative_name',
          'privaty'
        ],
        ['moran', 'nayuta', 'helm', 'diesel_winter_sweets', 'velvet'],
        [
          'rapi_red_hood',
          'mint',
          'snow_white_heavy_arms',
          'ark_ranger_black',
          'prika'
        ],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'dolla'
        ],
      ],
    ),
    SharedDeck(
      id: "shared_1781526267588",
      authorName: "MIMIR",
      title: "(예상)풍게리X 미란다-나유타O 아블O 10퍼 언저리덱",
      description:
          "- 1덱 이견의 여지없는 이번 풍압 솔레 1덱\n(뮤지엄 모더 기준 75.4억)\n\n- 세이렌덱 아무도 안 쓸 것 같은 나만의 덱1 \n풍게리도 클루드도 없는 상태에서 라피를 1버로 돌린다면?이라는 발상에서 시작한 세이렌 몰빵덱\n크라운 버프를 그나마 조금이라도 맛있게 먹으며 세이렌에게 머신건 시너지를 주는 미하라 \n머신건들 무탄을 위한 애프바\n세이렌에게 조금의 받뎀증과 머신건 시너지를 줄 수 있는 닌델\n후술하겠지만 마나도 수쿠라도 쓸 수 없는 상황에서 루주를 미란다-나유타덱에 넘겨준 순간\n저지를 위해 벨벳을 5덱에 쓸 수 밖에 없기 때문에 나온 고육책\n(뮤지엄 모더 기준 36.0억)\n\n3덱 미란다-나유타 덱\n미란다-나유타덱에선 현재 이 구성이 정석인듯?\n(뮤지엄 모더 기준 32.8억)\n\n4덱 민프덱\n덱 구성상 버충이 부족한데 이 와중에 리타마저 써버리면 13버조차 못 박고 12버에서 끝나는 경우가 있어 고심끝에 라피 1버 활용\n민프를 그래도 맛있게 먹는 네온과 접대 딜러 아블 투입\n(뮤지엄 모더 기준 27.5억)\n\n5덱 짬덱 아무도 안 쓸 것 같은 나만의 덱2 \n마나완전 깡통에 수쿠라는 당연히 없고 루주마저 팔려나가 블랑을 쓸 수 없어 저지요원이 없는 상황\n눈물을 머금고 벨벳을 5덱으로 팔아넘기고 그나마 차지뎀 버프라도 먹을 수 있게 각설 + 신데를 짬덱에 투입\n추가로 각설 체급을 조금이라도 뒷받침하기위해 2버 바이드 투입 어차피 마땅한게 없기도 하고..\n(뮤지엄 모더 기준 27.1억)",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:24:27.588"),
      squadsNikkeIds: [
        [
          'anis_star',
          'mast_romantic_maid',
          'scarlet_black_shadow',
          'liberalio',
          'anchor_innocent_maid'
        ],
        [
          'little_mermaid',
          'crown',
          'mihara_bonding_chain',
          'privaty',
          'delta_ninja_thief'
        ],
        ['miranda', 'helm', 'nayuta', 'rouge', 'diesel_winter_sweets'],
        [
          'rapi_red_hood',
          'mint',
          'ark_ranger_black',
          'neon_vision_eye',
          'prika'
        ],
        [
          'moran',
          'ade_agent_bunny',
          'snow_white_heavy_arms',
          'cinderella',
          'velvet'
        ],
      ],
    ),
    SharedDeck(
      id: "shared_1781526738319",
      authorName: "MIMIR",
      title: "(예상)풍게리 아블 둘 다 쓰는덱 초안",
      description:
          "1~3번덱 까지는 사실 다들 비슷비슷하게 쓰시는 느낌이라 거의 고정시킨다고 생각중이고\n만약 풍레이자리에 라피를 넣는다면 5번덱 라피자리에 리타가 들어가겠지만 \n저는 풍레이에 모듈을 이미 써버렸기 때문에 이 악물고 쓸 예정..\n여기서 남은 짬덱 두 개를 골라야하는데 \n일단은 애란다덱 + 아블마나 짬덱을 쓸 생각이고 \n만약 애란다덱 블랑 혼자서 저지가 빡세면 \n\n4덱 - 미란다 블랑 스화 루주 아블\n5덱 - 라피 민트 네온 마나 프리카\n요런식으로 바꿀 생각도 하고있긴한데 딜이 어떻게 나올지 ㅋㅋㅋㅋㅋ\n샷건덱을 안쓰고 후보에 넣어놓은 이유는 \n1.힐 없이 완주가 되는가? + 2.딜이 과연 얼마나 나올것인가? 에 대한 고민이 좀 컸음\n저번 퀸때 샷건덱 딜 개쳐망한게 생각이 나서 ㅠㅠㅠㅠㅠ\n물론 애니힐리오가 어떻게 나올진 아직 아무도 모르기에 샷건덱이 만약 딜이 나오고 완주가 된다면\n4,5,샷건덱 셋 다 비교해보고 높은걸 쓸 생각!",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:32:18.319"),
      squadsNikkeIds: [
        [
          'anis_star',
          'mast_romantic_maid',
          'scarlet_black_shadow',
          'liberalio',
          'anchor_innocent_maid'
        ],
        [
          'little_mermaid',
          'crown',
          'asuka_wille',
          'rei_tentative_name',
          'privaty'
        ],
        ['moran', 'nayuta', 'helm', 'diesel_winter_sweets', 'velvet'],
        ['miranda', 'blanc', 'snow_white_heavy_arms', 'rouge', 'ada'],
        ['rapi_red_hood', 'mint', 'ark_ranger_black', 'mana', 'prika'],
      ],
    ),
    SharedDeck(
      id: "shared_1781527665890",
      authorName: "MIMIR",
      title: "(예상)미란다 아예 안쓰는 애니힐리오 덱 in3%",
      description:
          "목표는 한섭 기준 3%.\n풍스카는 가능하지만 풍레이는 무리가 있다 판단을 했고 아크레인저를 넣어서 세팅을 해봤습니다.\n저도 미란다 나유타 연계는 안 됩니다.\n미란다 자체를 포기하는 걸로 하고 세팅을 해봤습니다.\n\n1덱은 풍게리덱.\n저는 풍레이를 안 키우는 대신 풍스카랑 라피를 넣고 세이렌의 버충을 믿고 치는 셈이죠\n대신 크라운 프바를 동시에 쓰기 때문에 풍스카와 라피 버스트 턴마다 확인해주고\n여유롭다면 세이렌잡고 집중 사격을 해주면 됩니다.\n\n2덱은 흑리덱.\n아마 제일 강한 덱이겠죠. 버충을 케어 해주면 컨하는데는 제일 무난한 덱이 될 예정입니다.\n앵리 선버를 하는 것과 메흑 선버 어디가 더 나을 지 한번 비교해보시는 것도 좋을 거 같네요.\n\n3덱은 나유타덱\n미란다를 대신해 목단과 나유타로 안정감을 챙기고 벨벳을 넣어서 나유타를 조금 더 강하게 해봤습니다.\n모자랄 딜을 고려해 파츠 솔레를 감안해서 제일 잘 부수는 네온\n그리고 비우코 내에서 파츠에 강하고 받뎀증이나 디버프를 적게 받는 클디젤로 딜을 커버했어요\n\n4덱은 샷건덱\n버쿨감과 속저를 도라를 대신 집어넣고 넣는 덱.\n노힐이기 때문에 컨트롤이 제법 필요하다는 점이 존재합니다.\n\n5덱에는 민프에 각설\n여기에 속저용으로 아레블이 들어갔습니다.\n근본적인 기본 딜은 아마 각설이 압도할 예정이고 파츠도 아마 알아서 부수겠죠\n아레블이 이번 솔레에서 어느 정도인지 미지수지만 \n적어도 생존을 완전 보장하고 안정감 있게 완주할 수 있는 덱이라는 건 확신할 수 있습니다.",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:47:45.890"),
      squadsNikkeIds: [
        ['crown', 'little_mermaid', 'asuka_wille', 'rapi_red_hood', 'privaty'],
        [
          'mast_romantic_maid',
          'anis_star',
          'scarlet_black_shadow',
          'liberalio',
          'anchor_innocent_maid'
        ],
        [
          'moran',
          'nayuta',
          'neon_vision_eye',
          'diesel_winter_sweets',
          'velvet'
        ],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'dolla'
        ],
        ['prika', 'mint', 'snow_white_heavy_arms', 'rouge', 'ark_ranger_black'],
      ],
    ),
    SharedDeck(
      id: "shared_1781527914507",
      authorName: "MIMIR",
      title: "in3% 목표 풍레이x 덱",
      description:
          "솔레 뮤지엄 모더니아 기준\n1덱 - 97.9억\n2덱 - 61.3억\n3덱 - 45.4억\n4덱 - 42억\n5덱 - 33.3억",
      season: "SEASON 38",
      upvotes: 0,
      downvotes: 0,
      createdAt: DateTime.parse("2026-06-15T21:51:54.507"),
      squadsNikkeIds: [
        [
          'anis_star',
          'mast_romantic_maid',
          'scarlet_black_shadow',
          'anchor_innocent_maid',
          'liberalio'
        ],
        ['little_mermaid', 'crown', 'asuka_wille', 'privaty', 'velvet'],
        [
          'miranda',
          'nayuta',
          'helm',
          'diesel_winter_sweets',
          'soline_frost_ticket'
        ],
        [
          'rapi_red_hood',
          'mint',
          'snow_white_heavy_arms',
          'ark_ranger_black',
          'prika'
        ],
        [
          'tove',
          'arcana_fortune_mate',
          'dorothy_serendipity',
          'drake',
          'dolla'
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
