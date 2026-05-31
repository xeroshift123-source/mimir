import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/models/enums.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/shared_deck.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/login.dart';
import 'package:mimir/repository/mock_deck_repository.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'package:mimir/widgets/nikke_card.dart';

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

  // --- 목록 상태 ---
  List<SharedDeck> _allDecks = [];
  final Set<String> _expandedDeckIds = {};
  
  // --- 투표 기록 추적 (로컬 세션 중복 방지) ---
  final Map<String, int> _userVotes = {}; // deckId -> 1 (upvote) or -1 (downvote)

  @override
  void initState() {
    super.initState();
    _allDecks = MockDeckRepository.getAllDecks();
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
  void _vote(String deckId, int value) {
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

    setState(() {
      final existingVote = _userVotes[deckId];
      final deckIdx = _allDecks.indexWhere((d) => d.id == deckId);
      if (deckIdx == -1) return;

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



  // --- 핵심 필터 연산 ---
  List<SharedDeck> _getFilteredDecks() {
    final includeSet = _includeIds.whereType<String>().toSet();
    final excludeSet = _excludeIds.whereType<String>().toSet();

    List<SharedDeck> results = _allDecks.where((deck) {
      // 1. 제외 조건 검사: 덱의 어떤 슬롯에도 제외 대상 니케가 포함되어 있으면 안 됨
      final allIdsInDeck = deck.squadsNikkeIds.expand((s) => s).whereType<String>().toSet();
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

  Widget _buildSeasonHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              border: Border.all(color: Colors.red.withOpacity(0.7), width: 1.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "SEASON 37",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            "assets/icons/elements/icon-elements-Water.webp",
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "보스: 울트라 (수냉 약점)",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: "SEASON 37",
                icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                onChanged: (val) {},
                items: const [
                  DropdownMenuItem(
                    value: "SEASON 37",
                    child: Text("시즌 37 - 울트라"),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "공유 덱 라이브러리",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
        actions: [
          if (AuthProvider.showLoginFeatures)
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isLoggedIn) {
                  return Tooltip(
                    message: '${auth.nickname} (계정 설정)',
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, LoginScreen.routeName);
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.orangeAccent],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.orange,
                              child: Text(
                                (auth.nickname != null && auth.nickname!.isNotEmpty)
                                    ? auth.nickname!.substring(0, 1).toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, LoginScreen.routeName);
                      },
                      icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        "로그인",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  );
                }
              },
            ),
        ],
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      drawer: const AppDrawer(activeRoute: '/deck-library'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1600,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                _buildSeasonHeader(isDark),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 900;
                      
                      if (isMobile) {
                        return _buildMobileLayout(nikkeList, nikkeMap, filteredDecks, isDark);
                      } else {
                        return _buildDesktopLayout(nikkeList, nikkeMap, filteredDecks, isDark);
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
              elevation: 1,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: const Text(
                  "필터 및 검색 패널 접기 / 펼치기",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
          _buildSortBar(isDark),
          const SizedBox(height: 12),
          _buildDeckList(filteredDecks, nikkeMap, isDark),
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
          width: 580,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
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
            padding: const EdgeInsets.only(left: 20.0, bottom: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSortBar(isDark),
                const SizedBox(height: 16),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
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
                    return _buildCompactSlot(nikkeMap[id], false, index, isDark);
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
  Widget _buildCompactSlot(Nikke? nikke, bool isInclude, int index, bool isDark) {
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
                                ? (isInclude ? Colors.blue.shade300 : Colors.red.shade300)
                                : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            const Text("버스트: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                  fontWeight: _filterExpanded ? FontWeight.bold : FontWeight.normal,
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
              final bool isDimmed = _selectedNikkeId != null && _selectedNikkeId != nikke.id;

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

  Widget _buildToggleTag({required String label, required bool selected, required VoidCallback onTap}) {
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

  Widget _buildSubFilterRow<T>(String category, List<T> items, Widget Function(T) builder) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 38,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "$category:",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
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
  Widget _buildSortBar(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "공유 빌드 리스트",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        if (AuthProvider.showLoginFeatures)
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _sortByLatest = true),
                child: Text(
                  "최신순",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _sortByLatest ? FontWeight.bold : FontWeight.normal,
                    color: _sortByLatest ? Colors.orange : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _sortByLatest = false),
                child: Text(
                  "추천순",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !_sortByLatest ? FontWeight.bold : FontWeight.normal,
                    color: !_sortByLatest ? Colors.orange : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 4. 덱 아코디언 목록 렌더링
  Widget _buildDeckList(List<SharedDeck> decks, Map<String, Nikke> nikkeMap, bool isDark) {
    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 48, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "조건에 매칭되는 덱 조합이 없습니다.",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        final bool isExpanded = _expandedDeckIds.contains(deck.id);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "작성자: ${deck.authorName}${AuthProvider.showLoginFeatures ? ' • ${_formatDateTime(deck.createdAt)}' : ''}",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 추천 수 뱃지
                      if (AuthProvider.showLoginFeatures)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_drop_up, color: Colors.orange, size: 18),
                              const SizedBox(width: 4),
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
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      )
                    ],
                  ),
                ),
              ),
              
              // 펼쳐진 상태 아코디언 콘텐츠
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 16),
                      // 5개 스쿼드 목록 그리기
                      _buildFiveSquadsSummaryPanel(deck, nikkeMap, isDark),
                      const SizedBox(height: 12),
                      
                      // 설명란
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262421) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                        ),
                        child: Text(
                          deck.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 하단 액션바 (투표만 제공하며 우측 정렬)
                      if (AuthProvider.showLoginFeatures)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildVoteButton(deck, 1, Icons.arrow_drop_up, Colors.orange),
                            const SizedBox(width: 8),
                            _buildVoteButton(deck, -1, Icons.arrow_drop_down, Colors.blue),
                          ],
                        ),
                    ],
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOut,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoteButton(SharedDeck deck, int voteVal, IconData icon, Color color) {
    final bool active = _userVotes[deck.id] == voteVal;
    return InkWell(
      onTap: () => _vote(deck.id, voteVal),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.grey.shade400, width: 1.2),
        ),
        child: Icon(icon, color: active ? color : Colors.grey.shade500, size: 16),
      ),
    );
  }

  // 5개 스쿼드 목록 그리기 - 덱 빌더 미리보기 팝업 UI와 100% 일치
  Widget _buildFiveSquadsSummaryPanel(SharedDeck deck, Map<String, Nikke> nikkeMap, bool isDark) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Container(
        width: 760,
        color: const Color(0xFF090A0F),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...List.generate(5, (index) {
              final squadIds = deck.squadsNikkeIds[index];
              final List<Nikke?> slots = squadIds.map((id) => id != null ? nikkeMap[id] : null).toList();
              
              return Padding(
                padding: EdgeInsets.only(bottom: index == 4 ? 0 : 8),
                child: _LibraryShareSquadPanel(
                  title: '${index + 1}번덱',
                  isActive: false,
                  slots: slots,
                  weaknessElement: '수냉', // 솔레 시즌37 보스 울트라 약점속성 연동
                ),
              );
            }),
            const SizedBox(height: 10),
            const Text(
              'Made with MIMIR',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔽 덱 빌더 미리보기 UI 구성요소 이식 (이름 충돌 방지를 위해 접두사 추가)

class _LibraryShareSquadPanel extends StatelessWidget {
  final String title;
  final bool isActive;
  final List<Nikke?> slots;
  final String weaknessElement;

  const _LibraryShareSquadPanel({
    required this.title,
    required this.isActive,
    required this.slots,
    required this.weaknessElement,
  });

  Widget _buildBadge({
    required String text,
    required bool isActive,
    required Color themeColor,
    required Color textColor,
  }) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.12),
          border: Border.all(color: themeColor.withOpacity(0.8), width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      );
    }
  }

  Widget _buildDynamicBadge(String text) {
    const goldColor = Color(0xFFFFA000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: goldColor.withOpacity(0.12),
        border: Border.all(color: goldColor.withOpacity(0.8), width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFC107),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeNikkes = slots.whereType<Nikke>().toList();

    // 1. 고정 키워드 로직
    final Map<String, ElementType> elementKoreanToEnum = {
      '철갑': ElementType.Iron,
      '수냉': ElementType.Water,
      '전격': ElementType.Electric,
      '작열': ElementType.Fire,
      '풍압': ElementType.Wind,
    };
    final targetEnum = elementKoreanToEnum[weaknessElement] ?? ElementType.Electric;
    final bool hasWeaknessMatch = activeNikkes.any((n) => n.element == targetEnum);
    final bool hasCooldownReduction = activeNikkes.any((n) => n.ability.contains("버스트 쿨타임 감소"));

    // 2. 동적 키워드 로직
    final List<String> dynamicTags = [];
    if (activeNikkes.any((n) => n.ability.contains("힐"))) {
      dynamicTags.add("힐");
    }
    if (activeNikkes.any((n) => n.name == "토브")) {
      dynamicTags.add("샷건");
    }
    if (activeNikkes.where((n) => n.ability.contains("방어력무시데미지")).length >= 2) {
      dynamicTags.add("방무뎀");
    }
    if (activeNikkes.where((n) => n.ability.contains("관통데미지")).length >= 2) {
      dynamicTags.add("관통뎀");
    }
    if (activeNikkes.where((n) => n.ability.contains("받는데미지증가")).length >= 2) {
      dynamicTags.add("받뎀증");
    }
    if (activeNikkes.where((n) => n.ability.contains("분배데미지")).length >= 2) {
      dynamicTags.add("분배뎀");
    }
    if (activeNikkes.any((n) => n.ability.contains("재장전속도증가"))) {
      dynamicTags.add("재장전");
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF11141B),
        border: Border.all(color: const Color(0xFF1E2330), width: 1),
        borderRadius: BorderRadius.circular(6),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
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
                  color: Colors.white.withOpacity(0.06),
                ),
                const SizedBox(height: 5),
                if (dynamicTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: dynamicTags.map((tag) {
                      return _buildDynamicBadge(tag);
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _LibraryVerticalDottedLine(
            height: 140,
            color: Colors.white12,
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
  const _LibraryShareSlotThumb({required this.nikke, required this.displayIndex});

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
