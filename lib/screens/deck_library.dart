import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mimir/models/enums.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/shared_deck.dart';
import 'package:mimir/models/achievement_badge.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/login.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'package:mimir/widgets/auth_account_button.dart';
import 'package:mimir/widgets/nikke_card.dart';
import 'package:mimir/data/raid_data.dart';
import 'package:mimir/models/raid_info.dart';
import 'package:mimir/screens/deck_builder.dart';
import 'package:mimir/screens/union_deck_builder.dart';
import 'package:mimir/screens/deck_publish.dart';
import 'package:mimir/services/shared_deck_service.dart';
import 'package:mimir/services/achievement_service.dart';
import 'package:mimir/data/achievement_badges.dart';
import 'package:mimir/widgets/achievement_badge_showcase.dart';
import 'package:mimir/utils/deck_code_utils.dart';

class DeckLibraryScreen extends StatefulWidget {
  static const routeName = '/deck-library';

  const DeckLibraryScreen({super.key});

  @override
  State<DeckLibraryScreen> createState() => _DeckLibraryScreenState();
}

class _DeckLibraryScreenState extends State<DeckLibraryScreen> {
  // --- 필터링 상태 ---
  final List<String?> _includeIds = List.filled(5, null);
  final List<String?> _excludeIds = List.filled(5, null);

  String? _selectedNikkeId; // 현재 선택된 캐릭터 (덱 빌더와 동일한 배치 로직)

  String _searchQuery = '';
  final Set<BurstType> _burstFilters = {};
  final Set<ElementType> _elementFilters = {};
  final Set<WeaponType> _weaponFilters = {};
  final Set<Company> _companyFilters = {};
  bool _filterExpanded = false;

  // --- 정렬 상태 ---
  bool _sortByLatest = true; // true = 최신순, false = 추천순

  // --- 레이드 시즌 상태 ---
  RaidInfo? _selectedSeason;
  bool _readRouteArguments = false;

  // --- 목록 상태 ---
  List<SharedDeck> _allDecks = [];
  final Set<String> _expandedDeckIds = {};
  final SharedDeckService _sharedDeckService = SharedDeckService();
  final AchievementService _achievementService = AchievementService();
  StreamSubscription<List<SharedDeck>>? _deckSubscription;

  // --- 투표 기록 추적 (로컬 세션 중복 방지) ---
  final Map<String, int> _userVotes =
      {}; // deckId -> 1 (upvote) or -1 (downvote)
  final Set<String> _votingDeckIds = {};

  @override
  void initState() {
    super.initState();
    _deckSubscription = _sharedDeckService.watchDecks().listen(
      (publishedDecks) {
        if (!mounted) return;
        setState(() => _allDecks = publishedDecks);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('공유 덱 목록을 불러오지 못했습니다: $error');
      },
    );
  }

  @override
  void dispose() {
    _deckSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readRouteArguments) return;
    _readRouteArguments = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is SharedDeck) {
      for (final raid in raidHistory) {
        if (raid.seasonName == argument.season) {
          _selectedSeason = raid;
          break;
        }
      }
      _expandedDeckIds.add(argument.id);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _toggleBurstFilter(BurstType type) {
    setState(() {
      if (_burstFilters.contains(type)) {
        _burstFilters.remove(type);
      } else {
        _burstFilters.add(type);
      }
    });
  }

  void _toggleElementFilter(ElementType type) {
    setState(() {
      if (_elementFilters.contains(type)) {
        _elementFilters.remove(type);
      } else {
        _elementFilters.add(type);
      }
    });
  }

  Future<void> _showAuthorBadges(
    SharedDeck deck,
    BuildContext anchorContext,
  ) async {
    final uid = deck.authorUid;
    if (uid == null || uid.isEmpty) return;

    final renderObject = anchorContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final anchorRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;

    final future = _achievementService.getPublicShowcase(uid);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '전시 뱃지 닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, __) => _AuthorBadgePopover(
        anchorRect: anchorRect,
        child: FutureBuilder<AchievementBadgeState>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return SizedBox(
                height: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    const Text('전시 뱃지를 불러오지 못했습니다.'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              );
            }

            final state = snapshot.data!;
            final nikkesByCode = <int, Nikke>{
              for (final nikke in context.read<NikkeProvider>().nikkeList)
                if (nikke.blablaNameCode != null) nikke.blablaNameCode!: nikke,
            };
            final dynamicBadges = state.unlocks.values
                .where((unlock) => unlock.id.startsWith('ultimate_'))
                .map((unlock) => buildUltimateBadge(unlock, nikkesByCode))
                .whereType<AchievementBadgeDefinition>();

            return PublicAchievementBadgeShowcase(
              authorName: deck.authorName,
              badges: [...staticAchievementBadges, ...dynamicBadges],
              unlocks: state.unlocks,
              displayedBadgeIds: state.displayedBadgeIds,
            );
          },
        ),
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
  }

  void _toggleWeaponFilter(WeaponType type) {
    setState(() {
      if (_weaponFilters.contains(type)) {
        _weaponFilters.remove(type);
      } else {
        _weaponFilters.add(type);
      }
    });
  }

  void _toggleCompanyFilter(Company type) {
    setState(() {
      if (_companyFilters.contains(type)) {
        _companyFilters.remove(type);
      } else {
        _companyFilters.add(type);
      }
    });
  }

  // 슬롯 탭할 때 배치/비우기 (선택된 캐릭터가 있으면 해당 슬롯에 배치, 없으면 슬롯 비우기)
  void _onSlotTap(bool isInclude, int index) {
    setState(() {
      if (_selectedNikkeId != null) {
        final nikkeList = context.read<NikkeProvider>().nikkeList;
        final target = nikkeList.firstWhere((n) => n.id == _selectedNikkeId);

        // 중복 배치 자동 제거 (포함/제외 전체 슬롯에서 같은 캐릭터 비우기)
        for (int i = 0; i < 5; i++) {
          if (_includeIds[i] == target.id) _includeIds[i] = null;
          if (_excludeIds[i] == target.id) _excludeIds[i] = null;
        }

        // 선택된 슬롯에 캐릭터 장착
        if (isInclude) {
          _includeIds[index] = target.id;
        } else {
          _excludeIds[index] = target.id;
        }

        // 배치 완료 후 선택 해제
        _selectedNikkeId = null;
      } else {
        // 선택된 캐릭터가 없으므로 해당 슬롯 비우기
        if (isInclude) {
          _includeIds[index] = null;
        } else {
          _excludeIds[index] = null;
        }
      }
    });
  }

  // 슬롯 비우기 단독 메소드
  void _clearSlot(bool isInclude, int index) {
    setState(() {
      if (isInclude) {
        _includeIds[index] = null;
      } else {
        _excludeIds[index] = null;
      }
    });
  }

  // 캐릭터 그리드에서 니케 탭했을 때 선택 상태 토글
  void _onGridNikkeTap(Nikke nikke) {
    setState(() {
      if (_selectedNikkeId == nikke.id) {
        _selectedNikkeId = null; // 이미 선택되어 있으면 선택 해제
      } else {
        _selectedNikkeId = nikke.id; // 선택 등록
      }
    });
  }

  // 로컬 투표 액션 시뮬레이션
  Future<void> _vote(String deckId, int value) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text("추천/비추천 투표는 로그인이 필요합니다!"),
            ],
          ),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: "로그인",
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, LoginScreen.routeName);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final deckIdx = _allDecks.indexWhere((deck) => deck.id == deckId);
    if (deckIdx == -1 || _votingDeckIds.contains(deckId)) return;
    final deck = _allDecks[deckIdx];
    if (deck.authorUid != null) {
      setState(() => _votingDeckIds.add(deckId));
      try {
        final result = await _sharedDeckService.vote(deckId, value);
        if (!mounted) return;
        setState(() {
          deck.upvotes = result.upvotes;
          deck.downvotes = result.downvotes;
          if (result.vote == 0) {
            _userVotes.remove(deckId);
          } else {
            _userVotes[deckId] = result.vote;
          }
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추천을 처리하지 못했습니다.')),
        );
      } finally {
        if (mounted) setState(() => _votingDeckIds.remove(deckId));
      }
      return;
    }

    setState(() {
      final existingVote = _userVotes[deckId];

      if (existingVote == value) {
        // 투표 취소
        _userVotes.remove(deckId);
        if (value == 1) {
          _allDecks[deckIdx].upvotes -= 1;
        } else {
          _allDecks[deckIdx].downvotes -= 1;
        }
      } else {
        // 신규 투표 또는 투표 변경
        if (existingVote != null) {
          // 기존 투표 반대 효과 제거
          if (existingVote == 1) {
            _allDecks[deckIdx].upvotes -= 1;
          } else {
            _allDecks[deckIdx].downvotes -= 1;
          }
        }
        _userVotes[deckId] = value;
        if (value == 1) {
          _allDecks[deckIdx].upvotes += 1;
        } else {
          _allDecks[deckIdx].downvotes += 1;
        }
      }
    });
  }

  Future<void> _deleteDeck(SharedDeck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('공유 덱 삭제'),
        content: Text('「${deck.title}」 게시글을 삭제할까요?\n삭제한 게시글은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _sharedDeckService.deleteDeck(deck.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 덱 게시글을 삭제했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글을 삭제하지 못했습니다.')),
      );
    }
  }

  Future<void> _copyDeckCode(
    SharedDeck deck,
    Map<String, Nikke> nikkeMap,
  ) async {
    final squads = deck.squadsNikkeIds
        .map<List<Object?>>(
          (squad) => List<Object?>.generate(5, (index) {
            if (index >= squad.length) return null;
            final nikkeId = squad[index];
            if (nikkeId == null) return null;
            return nikkeMap[nikkeId]?.blablaNameCode ?? nikkeId;
          }),
        )
        .toList();
    final isUnion = deck.raidType == 'union' || squads.length == 3;
    final elements = isUnion
        ? (deck.squadWeaknessElements.isNotEmpty
            ? deck.squadWeaknessElements
            : deck.squadNames)
        : null;
    final code = DeckCodeUtils.encodeDeck(
      type: isUnion ? 'union' : 'solo',
      squads: squads,
      elements: elements,
    );

    if (code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('덱 코드를 생성하지 못했습니다.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('덱 코드를 클립보드에 복사했습니다.')),
    );
  }

  Future<void> _editDeck(
    SharedDeck deck,
    Map<String, Nikke> nikkeMap,
  ) async {
    final squadNames = List<String>.generate(
      deck.squadsNikkeIds.length,
      (index) => index < deck.squadNames.length &&
              deck.squadNames[index].trim().isNotEmpty
          ? deck.squadNames[index]
          : '${index + 1}번덱',
    );
    final weaknesses = List<String>.generate(
      deck.squadsNikkeIds.length,
      (index) => index < deck.squadWeaknessElements.length
          ? deck.squadWeaknessElements[index]
          : deck.weaknessElement ?? '전격',
    );
    final previews = List<Widget>.generate(deck.squadsNikkeIds.length, (index) {
      final slots = deck.squadsNikkeIds[index]
          .map((id) => id == null ? null : nikkeMap[id])
          .toList();
      return _LibraryShareSquadPanel(
        title: squadNames[index],
        isActive: false,
        surfaceMode: true,
        slots: slots,
        weaknessElement: weaknesses[index],
      );
    });

    final updated = await Navigator.of(context).push<SharedDeck>(
      MaterialPageRoute(
        builder: (_) => DeckPublishScreen(
          squadPreviews: previews,
          squadsNikkeIds: deck.squadsNikkeIds,
          squadNames: squadNames,
          squadWeaknessElements: weaknesses,
          season: deck.season,
          raidType: deck.raidType,
          bossName: deck.bossName,
          weaknessElement: deck.weaknessElement,
          initialDeck: deck,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공유 덱 게시글을 수정했습니다.')),
    );
  }

  // --- 핵심 필터 연산 ---
  List<SharedDeck> _getFilteredDecks() {
    final includeSet = _includeIds.whereType<String>().toSet();
    final excludeSet = _excludeIds.whereType<String>().toSet();

    List<SharedDeck> results = _allDecks.where((deck) {
      // 1. 제외 조건 검사: 덱의 어떤 슬롯에도 제외 대상 니케가 포함되어 있으면 안 됨
      final allIdsInDeck =
          deck.squadsNikkeIds.expand((s) => s).whereType<String>().toSet();
      if (allIdsInDeck.any((id) => excludeSet.contains(id))) {
        return false;
      }

      // 2. 포함 조건 검사: 포함 대상 니케들이 모두 덱의 25인 구성에 포함되어 있어야 함
      if (includeSet.isNotEmpty) {
        for (final id in includeSet) {
          if (!allIdsInDeck.contains(id)) {
            return false;
          }
        }
      }

      // 3. 레이드 시즌 필터 검사
      if (_selectedSeason != null &&
          deck.season != _selectedSeason!.seasonName) {
        return false;
      }

      return true;
    }).toList();

    // 정렬 규칙 매칭
    if (AuthProvider.showLoginFeatures && !_sortByLatest) {
      results.sort((a, b) => b.score.compareTo(a.score));
    } else {
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return results;
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}분 전";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}시간 전";
    } else if (diff.inDays < 30) {
      return "${diff.inDays}일 전";
    } else {
      return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}";
    }
  }

  String _getElementEnumName(String? koreanName) {
    switch (koreanName) {
      case '철갑':
        return 'Iron';
      case '수냉':
        return 'Water';
      case '전격':
        return 'Electric';
      case '작열':
        return 'Fire';
      case '풍압':
        return 'Wind';
      default:
        return 'Water';
    }
  }

  Widget _buildSeasonHeader(bool isDark) {
    final raids = raidHistory;

    if (_selectedSeason == null && raids.isNotEmpty) {
      _selectedSeason = raids.lastWhere((raid) => raid.type == RaidType.solo);
    }

    if (_selectedSeason == null) return const SizedBox.shrink();

    final currentRaid = _selectedSeason!;

    final title = currentRaid.type == RaidType.solo
        ? "${currentRaid.bossName ?? ''} 공략 덱"
        : '유니온 레이드 공유 덱';
    final subtitle = currentRaid.type == RaidType.solo
        ? "${currentRaid.weakness ?? '-'} 약점 · 시즌 공략 모음"
        : '보스별 추천 조합을 확인해 보세요';

    final raidSummary = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(isDark ? 0.16 : 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: currentRaid.weakness != null
              ? Image.asset(
                  "assets/icons/elements/icon-elements-${_getElementEnumName(currentRaid.weakness)}.webp",
                  width: 22,
                  height: 22,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.bolt_rounded, size: 21),
                )
              : const Icon(Icons.groups_2_outlined,
                  color: Colors.orange, size: 21),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final seasonDropdown = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27292E) : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? const Color(0xFF383B43) : const Color(0xFFE5E7EB),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RaidInfo>(
          value: currentRaid,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: Colors.orange),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF30333A),
          ),
          dropdownColor: isDark ? const Color(0xFF27292E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          onChanged: (RaidInfo? val) {
            if (val != null) {
              setState(() => _selectedSeason = val);
            }
          },
          items: raids.map((raid) {
            return DropdownMenuItem<RaidInfo>(
              value: raid,
              child: Text(
                raid.type == RaidType.solo
                    ? "${raid.seasonName.replaceAll('SEASON ', '시즌 ')} · ${raid.bossName ?? ''}"
                    : '${raid.seasonName} · 유니온',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30333A) : const Color(0xFFE4E7EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final seasonChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
            ),
            child: Text(
              currentRaid.seasonName,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.redAccent,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: seasonChip),
                const SizedBox(height: 12),
                raidSummary,
                const SizedBox(height: 13),
                seasonDropdown,
              ],
            );
          }

          return Row(
            children: [
              seasonChip,
              const SizedBox(width: 15),
              Expanded(child: raidSummary),
              const SizedBox(width: 18),
              SizedBox(width: 230, child: seasonDropdown),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nikkeList = context.watch<NikkeProvider>().nikkeList;
    final nikkeMap = {for (final n in nikkeList) n.id: n};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 제외/포함 필터링을 거친 덱 목록 산출
    final filteredDecks = _getFilteredDecks();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF101216) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "덱 라이브러리",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "BETA",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: const [
          AuthAccountButton(),
        ],
        backgroundColor: Colors.orange,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFA000), Color(0xFFFF8A00)],
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(activeRoute: '/deck-library'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1540,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                _buildSeasonHeader(isDark),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 900;

                      if (isMobile) {
                        return _buildMobileLayout(
                            nikkeList, nikkeMap, filteredDecks, isDark);
                      } else {
                        return _buildDesktopLayout(
                            nikkeList, nikkeMap, filteredDecks, isDark);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📱 모바일 스택 레이아웃
  Widget _buildMobileLayout(
    List<Nikke> nikkeList,
    Map<String, Nikke> nikkeMap,
    List<SharedDeck> filteredDecks,
    bool isDark,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 모바일 필터 카드 (접고 펼치기 가능하도록 구현하여 활용성 증대)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: isDark ? const Color(0xFF1B1D21) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF30333A)
                      : const Color(0xFFE4E7EC),
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: Colors.orange),
                ),
                title: const Text(
                  "덱 필터",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '포함·제외 니케와 조건을 설정하세요',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                initiallyExpanded: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        _buildFilterHeader(nikkeMap, isDark),
                        const SizedBox(height: 12),
                        _buildCharacterGridSelector(nikkeList, isDark),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSortBar(isDark, filteredDecks.length),
          const SizedBox(height: 12),
          _buildDeckList(
            filteredDecks,
            nikkeMap,
            isDark,
            shrinkWrap: true,
          ),
        ],
      ),
    );
  }

  // 💻 데스크톱 사이드 바이 사이드 레이아웃
  Widget _buildDesktopLayout(
    List<Nikke> nikkeList,
    Map<String, Nikke> nikkeMap,
    List<SharedDeck> filteredDecks,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측 필터 패널 (고정폭)
        SizedBox(
          width: 500,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1D21) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF30333A) : const Color(0xFFE4E7EC),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          size: 18, color: Colors.orange),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '덱 필터',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '원하는 니케와 조건으로 빠르게 찾아보세요',
                            style:
                                TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 26),
                _buildFilterHeader(nikkeMap, isDark),
                const Divider(height: 24),
                Expanded(
                  child: _buildCharacterGridSelector(nikkeList, isDark),
                ),
              ],
            ),
          ),
        ),

        // 우측 결과 덱 목록 (페이징/아코디언)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSortBar(isDark, filteredDecks.length),
                const SizedBox(height: 14),
                Expanded(
                  child: _buildDeckList(filteredDecks, nikkeMap, isDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 공통 서브 컴포넌트들 ---

  // 1. 포함/제외 필터 헤더 (50x50 소형 초상화 매칭)
  Widget _buildFilterHeader(Map<String, Nikke> nikkeMap, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 포함 니케 행
        Row(
          children: [
            const Text(
              "포함 니케:",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    final id = _includeIds[index];
                    return _buildCompactSlot(nikkeMap[id], true, index, isDark);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 제외 니케 행
        Row(
          children: [
            const Text(
              "제외 니케:",
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    final id = _excludeIds[index];
                    return _buildCompactSlot(
                        nikkeMap[id], false, index, isDark);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 포함/제외 콤팩트 프로필 아바타 슬롯 (50x50)
  Widget _buildCompactSlot(
      Nikke? nikke, bool isInclude, int index, bool isDark) {
    final bool hasSelection = _selectedNikkeId != null;
    final borderColor = hasSelection
        ? (isInclude ? Colors.blue.shade400 : Colors.red.shade400)
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () => _onSlotTap(isInclude, index),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: hasSelection ? 1.8 : 1.2,
                ),
                color: isDark ? const Color(0xFF2D2A26) : Colors.grey.shade200,
              ),
              child: ClipOval(
                child: nikke != null
                    ? Image.asset(nikke.imageUrl, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: hasSelection
                                ? (isInclude
                                    ? Colors.blue.shade300
                                    : Colors.red.shade300)
                                : (isDark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade500),
                          ),
                        ),
                      ),
              ),
            ),
            if (nikke != null)
              Positioned(
                top: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () => _clearSlot(isInclude, index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 2. 니케 검색 및 다이내믹 그리드 선택 패널 (좌측)
  Widget _buildCharacterGridSelector(List<Nikke> nikkeList, bool isDark) {
    // SSR -> SR -> R 및 이름순 정렬 적용
    List<Nikke> sortedList = List<Nikke>.from(nikkeList);
    sortedList.sort((a, b) {
      final rankDiff = a.rank.sortValue.compareTo(b.rank.sortValue);
      if (rankDiff != 0) return rankDiff;
      return a.name.compareTo(b.name);
    });

    // 텍스트, 버스트, 속성, 무기, 기업 필터 연계 적용
    final filteredGrid = sortedList.where((n) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameHit = n.name.toLowerCase().contains(q);
        final abilityHit = n.ability.any((a) => a.toLowerCase().contains(q));
        if (!nameHit && !abilityHit) return false;
      }
      if (_burstFilters.isNotEmpty && !_burstFilters.contains(n.burst)) {
        return false;
      }
      if (_elementFilters.isNotEmpty && !_elementFilters.contains(n.element)) {
        return false;
      }
      if (_weaponFilters.isNotEmpty && !_weaponFilters.contains(n.weaponType)) {
        return false;
      }
      if (_companyFilters.isNotEmpty && !_companyFilters.contains(n.company)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 검색 필드
        TextField(
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: "니케 이름 또는 스킬 키워드 검색",
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2822) : Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 버스트 타입 토글 + 필터 열기 버튼
        Row(
          children: [
            const Text("버스트: ",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            _buildToggleTag(
              label: 'I',
              selected: _burstFilters.contains(BurstType.burst1),
              onTap: () => _toggleBurstFilter(BurstType.burst1),
            ),
            const SizedBox(width: 4),
            _buildToggleTag(
              label: 'II',
              selected: _burstFilters.contains(BurstType.burst2),
              onTap: () => _toggleBurstFilter(BurstType.burst2),
            ),
            const SizedBox(width: 4),
            _buildToggleTag(
              label: 'III',
              selected: _burstFilters.contains(BurstType.burst3),
              onTap: () => _toggleBurstFilter(BurstType.burst3),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _filterExpanded = !_filterExpanded;
                });
              },
              icon: Icon(
                _filterExpanded ? Icons.filter_list_off : Icons.filter_list,
                size: 16,
                color: Colors.orange,
              ),
              label: Text(
                '필터',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight:
                      _filterExpanded ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),

        // 상세 필터 확장 패널 (속성, 무기, 기업)
        AnimatedSize(
          curve: Curves.easeInOut,
          duration: const Duration(milliseconds: 200),
          child: _filterExpanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSubFilterRow('속성', ElementType.values, (type) {
                        final label = switch (type) {
                          ElementType.Fire => '작열',
                          ElementType.Water => '수냉',
                          ElementType.Wind => '풍압',
                          ElementType.Electric => '전격',
                          ElementType.Iron => '철갑',
                        };
                        return _buildToggleTag(
                          label: label,
                          selected: _elementFilters.contains(type),
                          onTap: () => _toggleElementFilter(type),
                        );
                      }),
                      const SizedBox(height: 6),
                      _buildSubFilterRow('무기', WeaponType.values, (type) {
                        return _buildToggleTag(
                          label: type.name,
                          selected: _weaponFilters.contains(type),
                          onTap: () => _toggleWeaponFilter(type),
                        );
                      }),
                      const SizedBox(height: 6),
                      _buildSubFilterRow('기업', Company.values, (type) {
                        final label = switch (type) {
                          Company.Elysion => '엘리시온',
                          Company.Missilis => '미실리스',
                          Company.Tetra => '테트라',
                          Company.Pilgrim => '필그림',
                          Company.Abnormal => '어브노멀',
                        };
                        return _buildToggleTag(
                          label: label,
                          selected: _companyFilters.contains(type),
                          onTap: () => _toggleCompanyFilter(type),
                        );
                      }),
                      const Divider(height: 16),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),

        // 그리드 리스트 (NikkeCard를 사용하여 일관성 부여)
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredGrid.length,
            itemBuilder: (context, index) {
              final nikke = filteredGrid[index];

              // 포함/제외 배치 상태 매칭
              int? assignedIdx;
              String? assignedName;

              final int incIdx = _includeIds.indexOf(nikke.id);
              final int excIdx = _excludeIds.indexOf(nikke.id);

              if (incIdx != -1) {
                assignedIdx = incIdx;
                assignedName = '포함 ${incIdx + 1}';
              } else if (excIdx != -1) {
                assignedIdx = excIdx + 5;
                assignedName = '제외 ${excIdx + 1}';
              }

              final bool isSelected = _selectedNikkeId == nikke.id;
              final bool isDimmed =
                  _selectedNikkeId != null && _selectedNikkeId != nikke.id;

              return NikkeCard(
                nikke: nikke,
                onTap: () {
                  if (assignedIdx != null) return; // 이미 슬롯에 장착된 것은 락 (빌더 동일)
                  _onGridNikkeTap(nikke);
                },
                isSelected: isSelected,
                isDimmed: isDimmed || (assignedIdx != null),
                assignedSquadIndex: assignedIdx,
                assignedSquadName: assignedName,
                showAssignedOverlay: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTag(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? Colors.orange : Colors.grey.shade800,
          border: Border.all(
            color: selected ? Colors.white70 : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSubFilterRow<T>(
      String category, List<T> items, Widget Function(T) builder) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 38,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "$category:",
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items.map(builder).toList(),
          ),
        ),
      ],
    );
  }

  // 3. 정렬 바
  Widget _buildSortBar(bool isDark, int deckCount) {
    Widget sortButton(String label, bool selected, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? Colors.orange.withOpacity(0.18) : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected && !isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 7,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? Colors.orange.shade700
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 4,
          height: 21,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          "공유 빌드",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF292C32) : const Color(0xFFE9ECF1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$deckCount',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ),
        const Spacer(),
        if (AuthProvider.showLoginFeatures)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1D21) : const Color(0xFFE9ECF1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF30333A) : const Color(0xFFE1E4E9),
              ),
            ),
            child: Row(
              children: [
                sortButton(
                  '최신순',
                  _sortByLatest,
                  () => setState(() => _sortByLatest = true),
                ),
                sortButton(
                  '추천순',
                  !_sortByLatest,
                  () => setState(() => _sortByLatest = false),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 4. 덱 아코디언 목록 렌더링
  Widget _buildDeckList(
    List<SharedDeck> decks,
    Map<String, Nikke> nikkeMap,
    bool isDark, {
    bool shrinkWrap = false,
  }) {
    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 48,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "조건에 매칭되는 덱 조합이 없습니다.",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        final bool isExpanded = _expandedDeckIds.contains(deck.id);
        final canManage = deck.authorUid != null &&
            deck.authorUid == context.watch<AuthProvider>().userId;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          surfaceTintColor: Colors.transparent,
          color: isExpanded
              ? (isDark ? const Color(0xFF1D1D1B) : const Color(0xFFFFFCF8))
              : (isDark ? const Color(0xFF1B1D21) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isExpanded
                  ? Colors.orange.withOpacity(isDark ? 0.38 : 0.28)
                  : (isDark
                      ? const Color(0xFF30333A)
                      : const Color(0xFFE4E7EC)),
            ),
          ),
          child: Column(
            children: [
              // 접혀있을 때 보이는 헤더
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDeckIds.remove(deck.id);
                    } else {
                      _expandedDeckIds.add(deck.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: -0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '작성자: ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                if (deck.authorUid?.isNotEmpty == true)
                                  Builder(
                                    builder: (anchorContext) => Tooltip(
                                      message: '전시 뱃지 보기',
                                      child: InkWell(
                                        onTap: () => _showAuthorBadges(
                                          deck,
                                          anchorContext,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                            vertical: 1,
                                          ),
                                          child: Text(
                                            deck.authorName,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark
                                                  ? Colors.lightBlue.shade300
                                                  : Colors.blue.shade700,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: isDark
                                                  ? Colors.lightBlue.shade300
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    deck.authorName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                if (AuthProvider.showLoginFeatures)
                                  Text(
                                    ' • ${_formatDateTime(deck.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 추천 수 뱃지
                      if (AuthProvider.showLoginFeatures)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward_rounded,
                                  color: Colors.orange, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                "${deck.score}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF292C32)
                              : const Color(0xFFF1F3F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isExpanded
                              ? Colors.orange
                              : (isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // 펼쳐진 상태 아코디언 콘텐츠
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 18,
                        color: isDark
                            ? const Color(0xFF30333A)
                            : const Color(0xFFE9E2DA),
                      ),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF202228)
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 5개 스쿼드 목록 그리기
                            _buildFiveSquadsSummaryPanel(
                              deck,
                              nikkeMap,
                              isDark,
                            ),
                            if (deck.description.trim().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF181A1F)
                                      : const Color(0xFFECEFF3),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF343842)
                                        : const Color(0xFFDCE1E7),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade600,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '전체 덱 설명',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      deck.description,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 하단 액션바
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _copyDeckCode(deck, nikkeMap),
                              icon: const Icon(
                                Icons.code_rounded,
                                size: 17,
                              ),
                              label: const Text('덱 코드 복사'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.lightBlue.shade200
                                    : Colors.blue.shade700,
                                backgroundColor: isDark
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.06),
                                side: BorderSide(
                                  color: Colors.blue.withOpacity(
                                    isDark ? 0.38 : 0.25,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final isUnion = deck.raidType == 'union' ||
                                    deck.squadsNikkeIds.length == 3;
                                if (isUnion) {
                                  Navigator.pushNamed(
                                    context,
                                    UnionDeckBuilderScreen.routeName,
                                    arguments: deck,
                                  );
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    DeckBuilderScreen.routeName,
                                    arguments: deck,
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              label: const Text('덱 빌더로 복사'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade800,
                                backgroundColor:
                                    Colors.orange.withOpacity(0.08),
                                side: BorderSide(
                                  color: Colors.orange.withOpacity(0.35),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (canManage)
                              _buildActionIconButton(
                                onTap: () => _editDeck(deck, nikkeMap),
                                tooltip: '게시글 수정',
                                icon: Icons.edit_rounded,
                                color: Colors.orange.shade700,
                              ),
                            if (canManage)
                              _buildActionIconButton(
                                onTap: () => _deleteDeck(deck),
                                tooltip: '게시글 삭제',
                                icon: Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                              ),
                            if (AuthProvider.showLoginFeatures) ...[
                              _buildVoteButton(
                                deck,
                                1,
                                Icons.keyboard_arrow_up_rounded,
                                Colors.orange,
                              ),
                              _buildVoteButton(
                                deck,
                                -1,
                                Icons.keyboard_arrow_down_rounded,
                                Colors.blue,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOut,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionIconButton({
    required VoidCallback onTap,
    required String tooltip,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(isDark ? 0.16 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton(
      SharedDeck deck, int voteVal, IconData icon, Color color) {
    final bool active = _userVotes[deck.id] == voteVal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;
    return Tooltip(
      message: voteVal == 1 ? '추천' : '비추천',
      child: Material(
        color: active
            ? color.withOpacity(isDark ? 0.2 : 0.12)
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: active
                ? color.withOpacity(0.75)
                : inactiveColor.withOpacity(0.28),
          ),
        ),
        child: InkWell(
          onTap: () => _vote(deck.id, voteVal),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(
              icon,
              color: active ? color : inactiveColor,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  // 5개 스쿼드 목록 그리기 - 덱 빌더 미리보기 팝업 UI와 100% 일치
  Widget _buildFiveSquadsSummaryPanel(
      SharedDeck deck, Map<String, Nikke> nikkeMap, bool isDark) {
    final descriptionColor =
        isDark ? const Color(0xFF181A1F) : const Color(0xFFECEFF3);
    final descriptionBorderColor =
        isDark ? const Color(0xFF343842) : const Color(0xFFDCE1E7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(deck.squadsNikkeIds.length, (index) {
        final squadIds = deck.squadsNikkeIds[index];
        final slots =
            squadIds.map((id) => id != null ? nikkeMap[id] : null).toList();
        final title = index < deck.squadNames.length &&
                deck.squadNames[index].trim().isNotEmpty
            ? deck.squadNames[index]
            : '${index + 1}번덱';
        final weakness = index < deck.squadWeaknessElements.length
            ? deck.squadWeaknessElements[index]
            : deck.weaknessElement ?? '전격';
        final description = index < deck.squadDescriptions.length
            ? deck.squadDescriptions[index].trim()
            : '';
        final raidKeywords = _resolveRaidKeywords(deck, title);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.center,
              child: SizedBox(
                width: 760,
                child: _LibraryShareSquadPanel(
                  title: title,
                  isActive: false,
                  surfaceMode: true,
                  slots: slots,
                  weaknessElement: weakness,
                  raidKeywords: raidKeywords,
                  borderRadius: BorderRadius.zero,
                  showBorder: false,
                ),
              ),
            ),
            if (description.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: descriptionColor,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: descriptionBorderColor),
                ),
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ),
          ],
        );
      }),
    );
  }

  List<String> _resolveRaidKeywords(SharedDeck deck, String squadName) {
    RaidInfo? matchedRaid;
    for (final raid in raidHistory) {
      if (raid.seasonName == deck.season) {
        matchedRaid = raid;
        break;
      }
    }

    if (matchedRaid == null) return const [];
    if (matchedRaid.type == RaidType.solo) {
      return matchedRaid.keyword ?? const [];
    }

    for (final boss in matchedRaid.unionBosses ?? const <UnionBossInfo>[]) {
      if (boss.name == squadName) return boss.keyword ?? const [];
    }
    return const [];
  }
}

class _AuthorBadgePopover extends StatelessWidget {
  const _AuthorBadgePopover({required this.anchorRect, required this.child});

  final Rect anchorRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.dialogBackgroundColor;

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(470.0, constraints.maxWidth - 24);
          final left = (anchorRect.center.dx - width / 2)
              .clamp(12.0, constraints.maxWidth - width - 12);
          final arrowX = (anchorRect.center.dx - left).clamp(22.0, width - 22);
          final showBelow = anchorRect.bottom + 270 <= constraints.maxHeight ||
              anchorRect.top < 270;

          final bubble = SizedBox(
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: showBelow ? 9 : 0,
                    bottom: showBelow ? 0 : 9,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.2),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x30000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
                Positioned(
                  left: arrowX - 11,
                  top: showBelow ? 0 : null,
                  bottom: showBelow ? null : 0,
                  child: CustomPaint(
                    size: const Size(22, 10),
                    painter: _PopoverArrowPainter(
                      color: surface,
                      pointsUp: showBelow,
                    ),
                  ),
                ),
              ],
            ),
          );

          return Stack(
            children: [
              Positioned(
                left: left,
                top: showBelow ? anchorRect.bottom + 5 : null,
                bottom: showBelow
                    ? null
                    : constraints.maxHeight - anchorRect.top + 5,
                child: bubble,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PopoverArrowPainter extends CustomPainter {
  const _PopoverArrowPainter({required this.color, required this.pointsUp});

  final Color color;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PopoverArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsUp != pointsUp;
}

// 🔽 덱 빌더 미리보기 UI 구성요소 이식 (이름 충돌 방지를 위해 접두사 추가)

class _LibraryShareSquadPanel extends StatelessWidget {
  final String title;
  final bool isActive;
  final List<Nikke?> slots;
  final String weaknessElement;
  final List<String> raidKeywords;
  final bool surfaceMode;
  final BorderRadius borderRadius;
  final bool showBorder;

  const _LibraryShareSquadPanel({
    required this.title,
    required this.isActive,
    required this.slots,
    required this.weaknessElement,
    this.raidKeywords = const [],
    this.surfaceMode = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.showBorder = true,
  });

  Widget _buildBadge({
    required String text,
    required bool isActive,
    required Color themeColor,
    required Color textColor,
  }) {
    if (isActive) {
      final effectiveTextColor =
          surfaceMode ? Color.lerp(themeColor, Colors.black, 0.28)! : textColor;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(surfaceMode ? 0.16 : 0.12),
          border: Border.all(
            color: themeColor.withOpacity(surfaceMode ? 0.65 : 0.8),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: effectiveTextColor,
          ),
        ),
      );
    } else {
      final inactiveColor =
          surfaceMode ? const Color(0xFF8A8A8A) : Colors.white;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: inactiveColor.withOpacity(0.01),
          border:
              Border.all(color: inactiveColor.withOpacity(0.16), width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: inactiveColor.withOpacity(0.7),
          ),
        ),
      );
    }
  }

  Widget _buildDynamicBadge(String text) {
    const goldColor = Color(0xFFFFA000);
    final backgroundColor =
        surfaceMode ? const Color(0xFFFFF3D6) : goldColor.withOpacity(0.12);
    final borderColor =
        surfaceMode ? const Color(0xFFE59A00) : goldColor.withOpacity(0.8);
    final textColor =
        surfaceMode ? const Color(0xFF9A5700) : const Color(0xFFFFC107);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildGradientBadge(String text) {
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4A5FF),
            Color(0xFF80FFEA),
            Color(0xFFB185DB),
            Color(0xFFFF9CEE),
            Color(0xFF8A2BE2),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: BoxDecoration(
          color:
              surfaceMode ? const Color(0xFFFFFBFF) : const Color(0xFF11141B),
          borderRadius: BorderRadius.circular(4.8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: surfaceMode ? const Color(0xFF6F2A8E) : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeNikkes = slots.whereType<Nikke>().toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        surfaceMode && !isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final outlineColor = surfaceMode
        ? (isDark ? Colors.white24 : Colors.black12)
        : const Color(0xFF1E2330);

    // 1. 고정 키워드 로직
    final Map<String, ElementType> elementKoreanToEnum = {
      '철갑': ElementType.Iron,
      '수냉': ElementType.Water,
      '전격': ElementType.Electric,
      '작열': ElementType.Fire,
      '풍압': ElementType.Wind,
    };
    final targetEnum =
        elementKoreanToEnum[weaknessElement] ?? ElementType.Electric;
    final bool hasWeaknessMatch =
        activeNikkes.any((n) => n.element == targetEnum);
    final bool hasCooldownReduction =
        activeNikkes.any((n) => n.ability.contains("버스트 쿨타임 감소"));

    // 2. 동적 키워드 로직
    final List<String> specialTags = [];
    final List<String> dynamicTags = [];

    void addTag({
      required bool isRaidKeyword,
      required bool hasAny,
      required bool meetsGeneralRule,
      required String label,
    }) {
      if (isRaidKeyword && hasAny) {
        specialTags.add(label);
      } else if (meetsGeneralRule) {
        dynamicTags.add(label);
      }
    }

    bool includesEither(String fullName, String shortName) =>
        raidKeywords.contains(fullName) || raidKeywords.contains(shortName);

    final coreCount =
        activeNikkes.where((n) => n.ability.contains("코어데미지증가")).length;
    addTag(
      isRaidKeyword: raidKeywords.contains("코어"),
      hasAny: coreCount > 0,
      meetsGeneralRule: false,
      label: "코어",
    );

    final partsCount =
        activeNikkes.where((n) => n.ability.contains("파츠")).length;
    addTag(
      isRaidKeyword: raidKeywords.contains("파츠"),
      hasAny: partsCount > 0,
      meetsGeneralRule: partsCount >= 2,
      label: "파츠",
    );

    final healCount = activeNikkes.where((n) => n.ability.contains("힐")).length;
    addTag(
      isRaidKeyword: raidKeywords.contains("힐"),
      hasAny: healCount > 0,
      meetsGeneralRule: healCount > 0,
      label: "힐",
    );

    final hasTove = activeNikkes.any((n) => n.name == "토브");
    addTag(
      isRaidKeyword: raidKeywords.contains("샷건"),
      hasAny: hasTove,
      meetsGeneralRule: hasTove,
      label: "샷건",
    );

    void addAbilityTag(String ability, String label) {
      final count =
          activeNikkes.where((n) => n.ability.contains(ability)).length;
      addTag(
        isRaidKeyword: includesEither(ability, label),
        hasAny: count > 0,
        meetsGeneralRule: count >= 2,
        label: label,
      );
    }

    addAbilityTag("방어력무시데미지", "방무뎀");
    addAbilityTag("관통데미지", "관통뎀");
    addAbilityTag("지속데미지", "지속딜");
    addAbilityTag("받는데미지증가", "받뎀증");
    addAbilityTag("분배데미지", "분배뎀");

    final reloadCount =
        activeNikkes.where((n) => n.ability.contains("재장전속도증가")).length;
    addTag(
      isRaidKeyword: includesEither("재장전속도증가", "재장전"),
      hasAny: reloadCount > 0,
      meetsGeneralRule: reloadCount > 0,
      label: "재장전",
    );

    final explosionCount =
        activeNikkes.where((n) => n.ability.contains("폭발데미지")).length;
    final rlCount =
        activeNikkes.where((n) => n.weaponType == WeaponType.RL).length;
    addTag(
      isRaidKeyword: includesEither("폭발데미지", "폭발뎀"),
      hasAny: explosionCount > 0,
      meetsGeneralRule:
          explosionCount >= 2 || (explosionCount >= 1 && rlCount >= 1),
      label: "폭발뎀",
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceMode
            ? (isDark ? const Color(0xFF202228) : const Color(0xFFF7F8FA))
            : const Color(0xFF11141B),
        border: showBorder ? Border.all(color: outlineColor, width: 1) : null,
        borderRadius: borderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF19AFF4),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: foregroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildBadge(
                        text: "속성저지",
                        isActive: hasWeaknessMatch,
                        themeColor: const Color(0xFF4CAF50),
                        textColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildBadge(
                        text: "버쿨감",
                        isActive: hasCooldownReduction,
                        themeColor: const Color(0xFF4CAF50),
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  height: 0.8,
                  color: foregroundColor.withOpacity(0.12),
                ),
                const SizedBox(height: 5),
                if (specialTags.isNotEmpty || dynamicTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...specialTags.map(_buildGradientBadge),
                      ...dynamicTags.map(_buildDynamicBadge),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _LibraryVerticalDottedLine(
            height: 140,
            color: foregroundColor.withOpacity(0.18),
            dashHeight: 3,
            gap: 3,
            strokeWidth: 1,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: List.generate(slots.length, (i) {
                final nikke = slots[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _LibraryShareSlotThumb(
                      nikke: nikke,
                      displayIndex: i + 1,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryShareSlotThumb extends StatelessWidget {
  final Nikke? nikke;
  final int displayIndex;
  const _LibraryShareSlotThumb(
      {required this.nikke, required this.displayIndex});

  @override
  Widget build(BuildContext context) {
    if (nikke == null) {
      return AspectRatio(
        aspectRatio: 0.75,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12),
            color: Colors.white.withOpacity(0.02),
          ),
          alignment: Alignment.center,
          child: Text(
            '$displayIndex',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return NikkeCard(
      nikke: nikke!,
      onTap: null,
      isSelected: false,
      isDimmed: false,
      assignedSquadIndex: null,
      showAssignedOverlay: false,
    );
  }
}

class _LibraryVerticalDottedLine extends StatelessWidget {
  final double height;
  final Color color;
  final double dashHeight;
  final double strokeWidth;
  final double gap;

  const _LibraryVerticalDottedLine({
    this.height = double.infinity,
    this.color = Colors.white24,
    this.dashHeight = 3,
    this.strokeWidth = 1,
    this.gap = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(strokeWidth, height),
      painter: _LibraryDottedLinePainter(
        color: color,
        dashHeight: dashHeight,
        strokeWidth: strokeWidth,
        gap: gap,
      ),
    );
  }
}

class _LibraryDottedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double strokeWidth;
  final double gap;

  _LibraryDottedLinePainter({
    required this.color,
    required this.dashHeight,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, math.min(startY + dashHeight, size.height)),
        paint,
      );
      startY += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
