import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:universal_html/html.dart' as html;
import 'package:pasteboard/pasteboard.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/enums.dart';
import 'package:mimir/utils/blabla_map.dart';
import 'package:mimir/services/database_service.dart';
import 'package:mimir/utils/cp_calculator.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'deck_builder.dart';

class MyNikkeScreen extends StatefulWidget {
  const MyNikkeScreen({super.key});

  static const String routeName = '/my-nikkes';

  @override
  State<MyNikkeScreen> createState() => _MyNikkeScreenState();
}

class _MyNikkeScreenState extends State<MyNikkeScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  int _selectedCharIndex = 0;

  // 🔽 Search & Filter States
  String _searchQuery = '';
  final Set<BurstType> _burstFilters = {};
  final Set<ElementType> _elementFilters = {};
  final Set<WeaponType> _weaponFilters = {};
  final Set<Company> _companyFilters = {};
  bool _filterExpanded = false;
  bool _profileExpanded = true;
  bool _assumeCube15 = false;
  bool _showNicknameOnLicense = false;
  bool _sortByLevel40Cp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileData == null && _isLoading) {
      final openIdArg = ModalRoute.of(context)?.settings.arguments as String?;
      if (openIdArg != null && openIdArg.isNotEmpty) {
        // 💡 backend와 동일하게 base64 디코딩 및 NULL 바이트 제거
        String resolved = openIdArg.trim();
        final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
        if (base64Pattern.hasMatch(resolved) && resolved.length % 4 == 0) {
          try {
            resolved = utf8.decode(base64.decode(resolved));
          } catch (_) {}
        }
        resolved = resolved.replaceAll(RegExp(r'\x00'), '').trim();

        _loadProfile(resolved);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "올바른 지휘관 OpenID 정보가 제공되지 않았습니다.\n프로필 동기화 화면에서 먼저 동기화를 수행해 주세요.";
        });
      }
    }
  }

  Future<void> _loadProfile(String openId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dbService.getCommanderProfile(openId);
      if (data != null) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "데이터베이스에서 프로필 정보를 찾을 수 없습니다.\n블라블라링크 동기화를 다시 진행해 주세요.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "프로필 로드 중 오류가 발생했습니다: ${e.toString()}";
      });
    }
  }

  String _getOptionName(int id) {
    return BlablaMap.getOptionName(id);
  }

  String _getElementLabel(ElementType type) {
    return switch (type) {
      ElementType.Iron => '철갑',
      ElementType.Water => '수냉',
      ElementType.Electric => '전격',
      ElementType.Fire => '작열',
      ElementType.Wind => '풍압',
    };
  }

  String _getCompanyLabel(Company type) {
    return switch (type) {
      Company.Elysion => '엘리시온',
      Company.Missilis => '미실리스',
      Company.Tetra => '테트라',
      Company.Pilgrim => '필그림',
      Company.Abnormal => '어브노멀',
    };
  }

  String _getBurstLabel(BurstType type) {
    return switch (type) {
      BurstType.burst0 => '0',
      BurstType.burst1 => 'I',
      BurstType.burst2 => 'II',
      BurstType.burst3 => 'III',
    };
  }

  String _getWeaponLabel(WeaponType type) {
    return type.name;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0E12) : const Color(0xFFF5F5F7),
      drawer: const AppDrawer(activeRoute: '/my-nikkes'),
      appBar: AppBar(
        title: Text(
          _profileData != null
              ? "내 니케 데이터보기 (${_profileData!['nickname']})"
              : "내 니케 데이터보기",
          style:
              const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_profileData != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, DeckBuilderScreen.routeName);
                },
                icon: const Icon(Icons.style, color: Colors.white, size: 18),
                label: const Text(
                  "덱 구성 시작",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _errorMessage != null
              ? _buildErrorScreen(isDark)
              : _buildMainContent(isDark),
    );
  }

  Widget _buildErrorScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "지휘관 연동 실패",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/sync');
              },
              icon: const Icon(Icons.sync_rounded),
              label: const Text("프로필 동기화 화면으로"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    final characters = _profileData?['characters'] as List<dynamic>? ?? [];
    final localNikkes = context.watch<NikkeProvider>().nikkeList;

    // Cache local nikkes by name for quick lookup
    final Map<String, Nikke> nikkeNameMap = {
      for (final n in localNikkes) n.name: n
    };

    // Filter characters
    final filteredChars = characters.where((char) {
      final nameCode = char['name_code'] as int? ?? 0;
      final String mappedName = BlablaMap.characterNames[nameCode] ?? '';

      final localNikke = nikkeNameMap[mappedName];

      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameHit = mappedName.toLowerCase().contains(q);
        final abilityHit = localNikke != null &&
            localNikke.ability.any((a) => a.toLowerCase().contains(q));
        if (!nameHit && !abilityHit) {
          return false;
        }
      }

      if (localNikke == null) {
        return true; // Keep mapped if local not found, filters don't apply
      }

      // 2. Filters
      if (_burstFilters.isNotEmpty &&
          localNikke.burst != BurstType.burst0 &&
          !_burstFilters.contains(localNikke.burst)) {
        return false;
      }
      if (_elementFilters.isNotEmpty) {
        bool elementMatch = _elementFilters.contains(localNikke.element);
        if (localNikke.id == 'rapi_red_hood' &&
            _elementFilters.contains(ElementType.Iron)) {
          elementMatch = true;
        }
        if (!elementMatch) return false;
      }
      if (_weaponFilters.isNotEmpty &&
          !_weaponFilters.contains(localNikke.weaponType)) return false;
      if (_companyFilters.isNotEmpty &&
          !_companyFilters.contains(localNikke.company)) return false;

      return true;
    }).toList();

    if (_sortByLevel40Cp) {
      for (var char in filteredChars) {
        final nameCode = char['name_code'] as int? ?? 0;
        final String mappedName = BlablaMap.characterNames[nameCode] ?? '';
        final localNikke = nikkeNameMap[mappedName];
        final modifiableChar = _getCharWithConsoleLevels(char, localNikke);
        char['level40Cp'] = CpCalculator.calculateCp(modifiableChar, localNikke, targetLevel: 40, assumeCube15: _assumeCube15).toInt();
      }
      filteredChars.sort((a, b) {
        final cpA = a['level40Cp'] as int? ?? 0;
        final cpB = b['level40Cp'] as int? ?? 0;
        return cpB.compareTo(cpA);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 900;

        if (isWideScreen) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Side panel: Search + Nikke List
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildProfileSummaryBar(isDark),
                          _buildSearchAndFilters(isDark),
                          Expanded(
                            child: _buildNikkeList(
                                filteredChars, nikkeNameMap, isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right Side panel: Detail view
                  Expanded(
                    flex: 4,
                    child: filteredChars.isEmpty
                        ? const Center(child: Text("필터에 부합하는 니케가 없습니다."))
                        : _buildDetailPanel(
                            filteredChars[_selectedCharIndex.clamp(
                                0, filteredChars.length - 1)],
                            nikkeNameMap,
                            isDark),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Mobile responsive layout (grid only, tap opens details bottom sheet)
          return Column(
            children: [
              _buildProfileSummaryBar(isDark),
              _buildSearchAndFilters(isDark),
              Expanded(
                child:
                    _buildNikkeGrid(filteredChars, nikkeNameMap, isDark, true),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildProfileSummaryBar(bool isDark) {
    final nickname = _profileData?['nickname'] ?? '지휘관';
    final server = _profileData?['server'] ?? '한국';
    final union = _profileData?['union'] ?? '없음';
    final cp = _profileData?['combatPower'] ?? 0;
    final synchro = _profileData?['synchroLevel'] ?? 0;
    final level = _profileData?['commanderLevel'] ?? 0;
    final count = _profileData?['ownedNikkesCount'] ?? 0;
    final recycleRoom = _profileData?['recycleRoom'] as List<dynamic>? ?? [];
    final infraCoreLevel = _profileData?['infraCoreLevel'] as int? ?? 0;

    final formattedCP = NumberFormat('#,###').format(cp);

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF14151B) : Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _profileExpanded = !_profileExpanded;
              });
            },
            child: Row(
              children: [
                Icon(Icons.shield, color: Colors.orange.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$nickname (Lv.$level)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    server,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _profileExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ],
            ),
          ),
          if (_profileExpanded) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem("유니온", union, isDark),
                _buildSummaryItem("총 전투력", formattedCP, isDark),
                _buildSummaryItem("싱크로 레벨", "Lv.$synchro", isDark),
                _buildSummaryItem("보유 니케", "$count명", isDark),
              ],
            ),
            if (recycleRoom.isNotEmpty || infraCoreLevel > 0) ...[
              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              const SizedBox(height: 12),
              _buildRecycleRoomSection(recycleRoom, infraCoreLevel, isDark),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRecycleRoomSection(
      List<dynamic> recycleRoom, int infraCore, bool isDark) {
    int common = 0;
    int attacker = 0;
    int defender = 0;
    int supporter = 0;
    int elysion = 0;
    int missilis = 0;
    int tetra = 0;
    int pilgrim = 0;
    int abnormal = 0;

    for (final item in recycleRoom) {
      if (item is Map) {
        final tid = item['tid'] as int? ?? 0;
        final lv = item['lv'] as int? ?? 0;
        switch (tid) {
          case 1001:
            common = lv;
            break;
          case 1101:
            attacker = lv;
            break;
          case 1102:
            defender = lv;
            break;
          case 1103:
            supporter = lv;
            break;
          case 1201:
            elysion = lv;
            break;
          case 1202:
            missilis = lv;
            break;
          case 1203:
            tetra = lv;
            break;
          case 1204:
            pilgrim = lv;
            break;
          case 1205:
            abnormal = lv;
            break;
        }
      }
    }

    Widget badge(String label, int lv, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text("Lv.$lv",
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.science,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text("인프라 코어: Lv.$infraCore",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            const SizedBox(width: 12),
            Icon(Icons.memory,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text("리사이클 룸 (공용: Lv.$common)",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            badge("화력", attacker, Colors.lightGreen),
            badge("방어", defender, Colors.lightGreen),
            badge("지원", supporter, Colors.lightGreen),
            badge("엘리시온", elysion, Colors.red.shade900),
            badge("미실리스", missilis, Colors.red.shade900),
            badge("테트라", tetra, Colors.red.shade900),
            badge("필그림", pilgrim, Colors.red.shade900),
            badge("앱노멀", abnormal, Colors.red.shade900),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1A1A24) : Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _selectedCharIndex = 0;
                      });
                    },
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "니케 이름 검색...",
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400,
                          fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.orange, size: 18),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF121212) : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _filterExpanded ? Icons.filter_list_off : Icons.filter_list,
                  color: _filterExpanded || _hasActiveFilters()
                      ? Colors.orange
                      : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _filterExpanded = !_filterExpanded;
                  });
                },
              ),
            ],
          ),
          if (_filterExpanded) ...[
            const SizedBox(height: 8),
            _buildFilterRow<BurstType>(
              title: "버스트",
              items: BurstType.values,
              selected: _burstFilters,
              labelBuilder: _getBurstLabel,
              onToggle: (type) {
                setState(() {
                  if (_burstFilters.contains(type)) {
                    _burstFilters.remove(type);
                  } else {
                    _burstFilters.add(type);
                  }
                  _selectedCharIndex = 0;
                });
              },
            ),
            const SizedBox(height: 6),
            _buildFilterRow<ElementType>(
              title: "속성",
              items: ElementType.values,
              selected: _elementFilters,
              labelBuilder: _getElementLabel,
              onToggle: (type) {
                setState(() {
                  if (_elementFilters.contains(type)) {
                    _elementFilters.remove(type);
                  } else {
                    _elementFilters.add(type);
                  }
                  _selectedCharIndex = 0;
                });
              },
            ),
            const SizedBox(height: 6),
            _buildFilterRow<Company>(
              title: "기업",
              items: Company.values,
              selected: _companyFilters,
              labelBuilder: _getCompanyLabel,
              onToggle: (type) {
                setState(() {
                  if (_companyFilters.contains(type)) {
                    _companyFilters.remove(type);
                  } else {
                    _companyFilters.add(type);
                  }
                  _selectedCharIndex = 0;
                });
              },
            ),
            const SizedBox(height: 6),
            _buildFilterRow<WeaponType>(
              title: "무기",
              items: WeaponType.values,
              selected: _weaponFilters,
              labelBuilder: _getWeaponLabel,
              onToggle: (type) {
                setState(() {
                  if (_weaponFilters.contains(type)) {
                    _weaponFilters.remove(type);
                  } else {
                    _weaponFilters.add(type);
                  }
                  _selectedCharIndex = 0;
                });
              },
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "정렬",
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _sortByLevel40Cp = !_sortByLevel40Cp;
                            _selectedCharIndex = 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _sortByLevel40Cp ? Colors.orange : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _sortByLevel40Cp ? Colors.orange : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            "40레벨 투력",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _sortByLevel40Cp ? FontWeight.bold : FontWeight.normal,
                              color: _sortByLevel40Cp
                                  ? Colors.white
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade300
                                      : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _burstFilters.isNotEmpty ||
        _elementFilters.isNotEmpty ||
        _companyFilters.isNotEmpty ||
        _weaponFilters.isNotEmpty;
  }

  Widget _buildFilterRow<T>({
    required String title,
    required List<T> items,
    required Set<T> selected,
    required String Function(T) labelBuilder,
    required void Function(T) onToggle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items.map((item) {
              final isSel = selected.contains(item);
              return GestureDetector(
                onTap: () => onToggle(item),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.orange : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSel ? Colors.orange : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labelBuilder(item),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel
                          ? Colors.white
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade300
                              : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNikkeGrid(
    List<dynamic> filteredChars,
    Map<String, Nikke> nameMap,
    bool isDark,
    bool isMobile,
  ) {
    if (filteredChars.isEmpty) {
      return const Center(child: Text("동기화된 니케 목록이 비어 있습니다."));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 105,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio:
            0.75, // Aspect ratio of 0.75 exactly maps to 90x120 style cards
      ),
      itemCount: filteredChars.length,
      itemBuilder: (context, index) {
        final char = filteredChars[index];
        final nameCode = char['name_code'] as int? ?? 0;
        final String mappedName =
            BlablaMap.characterNames[nameCode] ?? '알 수 없음';
        final localNikke = nameMap[mappedName];

        final isSelected = !isMobile && _selectedCharIndex == index;
        final grade = char['grade'] as int? ?? 0;
        final core = char['core'] as int? ?? 0;
        final level = char['level'] as int? ?? 1;
        final combat = _sortByLevel40Cp
            ? (char['level40Cp'] as int? ?? 0)
            : (char['combat'] as int? ?? 0);

        return GestureDetector(
          onTap: () {
            if (isMobile) {
              _showMobileDetailsSheet(char, nameMap, isDark);
            } else {
              setState(() {
                _selectedCharIndex = index;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.orange : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // 1. Portrait background
                  Positioned.fill(
                    child: localNikke != null
                        ? Image.asset(
                            localNikke.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Colors.black26),
                          )
                        : const ColoredBox(color: Colors.black26),
                  ),

                  // 2. Element Badge (top left)
                  if (localNikke != null)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.6),
                        ),
                        child: Image.asset(
                          'assets/icons/elements/icon-elements-${localNikke.element.name}.webp',
                          width: 14,
                          height: 14,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 14, height: 14),
                        ),
                      ),
                    ),

                  // 3. Burst Badge (top right)
                  if (localNikke != null)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Image.asset(
                          'assets/icons/burst/icon-burst-${localNikke.burst == BurstType.burst0 ? 0 : localNikke.burst == BurstType.burst1 ? 1 : localNikke.burst == BurstType.burst2 ? 2 : 3}.webp',
                          width: 14,
                          height: 14,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 14, height: 14),
                        ),
                      ),
                    ),

                  // 4. Core Break Badge (red ribbon under element)
                  if (core > 0)
                    Positioned(
                      left: 4,
                      top: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "+$core",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // 5. Stars & Name overlay at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3, horizontal: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Stars representation (limit break level)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (starIdx) {
                              return Icon(
                                starIdx < grade
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: starIdx < grade
                                    ? Colors.amber
                                    : Colors.white30,
                                size: 10,
                              );
                            }),
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            mappedName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Lv.$level",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                              Text(
                                NumberFormat('#,###').format(combat),
                                style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMobileDetailsSheet(
      Map<String, dynamic> char, Map<String, Nikke> nameMap, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF14151B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return _buildDetailPanel(char, nameMap, isDark, scrollController: scrollController);
          },
        );
      },
    );
  }

  Widget _buildNikkeList(
    List<dynamic> filteredChars,
    Map<String, Nikke> nameMap,
    bool isDark,
  ) {
    if (filteredChars.isEmpty) {
      return const Center(child: Text("동기화된 니케 목록이 비어 있습니다."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredChars.length,
      itemBuilder: (context, index) {
        final char = filteredChars[index];
        final nameCode = char['name_code'] as int? ?? 0;
        final String mappedName =
            BlablaMap.characterNames[nameCode] ?? '알 수 없음';
        final localNikke = nameMap[mappedName];

        final isSelected = _selectedCharIndex == index;
        final grade = char['grade'] as int? ?? 0;
        final core = char['core'] as int? ?? 0;
        final level = char['level'] as int? ?? 1;
        final skills = char['skills'] as Map<String, dynamic>? ?? {};
        final skill1 = skills['skill1'] ?? 1;
        final skill2 = skills['skill2'] ?? 1;
        final burst = skills['burst'] ?? 1;
        final favItem = char['favoriteItem'] as Map<String, dynamic>?;
        final cube = char['harmonyCube'] as Map<String, dynamic>?;
        final equips = char['equipment'] as List<dynamic>? ?? [];

        final String starStr = '★' * grade + '☆' * (3 - grade);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCharIndex = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14151B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.orange
                    : (isDark ? Colors.grey.shade900 : Colors.grey.shade300),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPortraitBox(char, localNikke),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mappedName,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Lv.$level",
                              style: TextStyle(
                                fontSize: 14.5,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  starStr,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14.5,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                if (core > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      border: Border.all(
                                          color: Colors.redAccent, width: 1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "+$core",
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$skill1 / $skill2 / $burst",
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "스킬 레벨",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCollectionPill(favItem),
                            const SizedBox(height: 6),
                            _buildCubeBadge(cube),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: _buildEquipmentStatusSummary(equips, isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: _buildOverloadStatsSummary(equips, isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitBox(Map<String, dynamic> char, Nikke? localNikke) {
    final combat = _sortByLevel40Cp
        ? (char['level40Cp'] as int? ?? 0)
        : (char['combat'] as int? ?? 0);
    return Container(
      width: 84,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned.fill(
              child: localNikke != null
                  ? Image.asset(
                      localNikke.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Colors.black26),
                    )
                  : const ColoredBox(color: Colors.black26),
            ),
            if (localNikke != null)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: Image.asset(
                    'assets/icons/elements/icon-elements-${localNikke.element.name}.webp',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 14, height: 14),
                  ),
                ),
              ),
            if (localNikke != null)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Image.asset(
                    'assets/icons/burst/icon-burst-${localNikke.burst == BurstType.burst0 ? 0 : localNikke.burst == BurstType.burst1 ? 1 : localNikke.burst == BurstType.burst2 ? 2 : 3}.webp',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 14, height: 14),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  NumberFormat('#,###').format(combat),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionPill(Map<String, dynamic>? favItem) {
    if (favItem == null) {
      return const Text("-",
          style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    final int tid = favItem['tid'] as int? ?? 0;
    final int level = favItem['level'] as int? ?? 0;
    final bool isFavorite = tid >= 200000;

    if (isFavorite) {
      final increasedLevel = level + 1;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "♥$increasedLevel",
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.purple.shade700,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "SR$level",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildCubeBadge(Map<String, dynamic>? cube) {
    if (cube == null) {
      return const Text("-",
          style: TextStyle(color: Colors.grey, fontSize: 12));
    }
    final txt = _getShortCubeName(cube);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.tealAccent.shade700, width: 1),
        borderRadius: BorderRadius.circular(4),
        color: Colors.tealAccent.withOpacity(0.05),
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: Colors.tealAccent.shade400,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getShortCubeName(Map<String, dynamic>? cube) {
    if (cube == null) return '-';
    final int tid = cube['tid'] as int? ?? 0;
    final int level = cube['level'] as int? ?? 0;
    final String mappedName = BlablaMap.cubeNames[tid] ?? '큐브 ($tid)';
    return '$mappedName $level';
  }

  Widget _buildEquipmentStatusSummary(List<dynamic> equips, bool isDark) {
    final Map<String, dynamic> equipsBySlot = {
      for (final eq in equips) eq['slot'] as String: eq
    };

    Widget buildSlotText(String slot, String label) {
      final eq = equipsBySlot[slot];
      if (eq == null) {
        return Text(
          "$label -",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        );
      }
      final int tier = eq['tier'] as int? ?? 0;
      final int level = eq['level'] as int? ?? 0;
      Color textColor = Colors.grey;
      if (tier >= 10) {
        textColor = isDark ? Colors.pinkAccent.shade100 : Colors.pink.shade600;
      } else if (tier == 9) {
        textColor = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      }
      return Text(
        "$label +$level",
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSlotText('head', '머리'),
            const Text(" / ",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            buildSlotText('torso', '몸통'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSlotText('arm', '장갑'),
            const Text(" / ",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            buildSlotText('leg', '신발'),
          ],
        ),
      ],
    );
  }

  Widget _buildOverloadStatsSummary(List<dynamic> equips, bool isDark) {
    final Map<String, List<int>> groups = {};
    for (final eq in equips) {
      final options = eq['overloadOptions'] as List<dynamic>? ?? [];
      for (final optId in options) {
        final int id = optId as int? ?? 0;
        if (id == 0) continue; // Skip empty slots
        final String name = _getOptionName(id);
        groups.putIfAbsent(name, () => []).add(id);
      }
    }

    if (groups.isEmpty) {
      return const Text(
        "오버로드 없음",
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    final List<Map<String, dynamic>> summaryList = [];
    groups.forEach((name, ids) {
      double sumPercent = 0.0;
      int maxLevel = 0;
      for (final id in ids) {
        sumPercent += BlablaMap.getOptionPercent(id);
        final int lvl = id % 100;
        if (lvl > maxLevel) {
          maxLevel = lvl;
        }
      }
      summaryList.add({
        'name': name,
        'sumPercent': sumPercent,
        'maxLevel': maxLevel,
        'count': ids.length,
      });
    });

    summaryList.sort((a, b) {
      final int countCompare = b['count'].compareTo(a['count']);
      if (countCompare != 0) return countCompare;
      return b['sumPercent'].compareTo(a['sumPercent']);
    });

    final List<Map<String, dynamic>> top3 = summaryList.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: top3.map((info) {
        final String name = info['name'];
        final double sumPercent = info['sumPercent'];
        final int maxLevel = info['maxLevel'] as int? ?? 0;
        final bool isLevel15 = maxLevel == 15;
        final bool isHighLevel = maxLevel >= 12;

        // 1. Background color (matching in-game, independent of dark/light theme)
        final Color boxBgColor = isLevel15
            ? const Color(0xFF232323) // 최대레벨옵션일 경우 배경 (#232323)
            : const Color(0xFFEAEAEA); // 일반 오버로드 옵션 칸 배경 (#eaeaea)

        // 2. Option name text color (matching in-game, independent of dark/light theme)
        final Color labelColor = isLevel15
            ? const Color(0xFFFFFFFF) // 최대 레벨일 때는 흰색 글씨
            : const Color(0xFF333333); // 일반 레벨일 때는 어두운 회색 글씨

        // 3. Value color (matching in-game)
        final Color valueColor = isHighLevel
            ? const Color(0xFF049EE7) // 파란색 글씨 (#049ee7)
            : const Color(0xFF7F8C8D); // 일반 옵션 수치 색상 (회색)

        return Container(
          width: 150,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "+${sumPercent.toStringAsFixed(2)}%",
                style: TextStyle(
                  color: valueColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _getCharWithConsoleLevels(
      Map<String, dynamic> char, Nikke? localNikke) {
    final recycleRoom = _profileData?['recycleRoom'] as List<dynamic>? ?? [];
    int common = 0;
    int classConsole = 0;
    int companyConsole = 0;

    for (final item in recycleRoom) {
      if (item is Map) {
        final tid = item['tid'] as int? ?? 0;
        final lv = item['lv'] as int? ?? 0;

        if (tid == 1001) common = lv;

        if (localNikke != null) {
          if (localNikke.type == 'ATK' && tid == 1101) classConsole = lv;
          if (localNikke.type == 'DEF' && tid == 1102) classConsole = lv;
          if (localNikke.type == 'SUP' && tid == 1103) classConsole = lv;

          final compStr = localNikke.company.toString().split('.').last;
          if (compStr == 'Elysion' && tid == 1201) companyConsole = lv;
          if (compStr == 'Missilis' && tid == 1202) companyConsole = lv;
          if (compStr == 'Tetra' && tid == 1203) companyConsole = lv;
          if (compStr == 'Pilgrim' && tid == 1204) companyConsole = lv;
          if (compStr == 'Abnormal' && tid == 1205) companyConsole = lv;
        }
      }
    }

    final modifiableChar = Map<String, dynamic>.from(char);
    modifiableChar['commonConsoleLevel'] = common;
    modifiableChar['classConsoleLevel'] = classConsole;
    modifiableChar['companyConsoleLevel'] = companyConsole;
    return modifiableChar;
  }

  Widget _buildDetailPanel(
      Map<String, dynamic> char, Map<String, Nikke> nameMap, bool isDark, {ScrollController? scrollController}) {
    final nameCode = char['name_code'] as int? ?? 0;
    final String mappedName = BlablaMap.characterNames[nameCode] ?? '알 수 없음';
    final localNikke = nameMap[mappedName];

    final modifiableChar = _getCharWithConsoleLevels(char, localNikke);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 44.0),
      children: [
        _buildDetailHeader(char, localNikke, isDark),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics_outlined,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  "계산된 상세 스펙 스탯",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("면허증 닉네임 보이기",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                SizedBox(
                  height: 20,
                  child: Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _showNicknameOnLicense,
                      onChanged: (val) {
                        setState(() {
                          _showNicknameOnLicense = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCalculatedStatsGrid(modifiableChar, localNikke, isDark),
              // _buildDebugCpWidget(modifiableChar, localNikke, isDark), // 디버깅용 창 숨김 처리
            ],
          );
        }),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "각 부위별 장비 오버로드 상세 정보",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (localNikke != null) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/overload-simulator',
                    arguments: {
                      'nikke': localNikke,
                      'charData': modifiableChar,
                      'assumeCube15': _assumeCube15,
                    },
                  );
                },
                icon: const Icon(Icons.build_circle_outlined, size: 16),
                label: const Text("모듈작 시뮬레이션", style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildOverloadOptionsSum(char['equipment'] as List<dynamic>? ?? []),
        if ((char['equipment'] as List<dynamic>? ?? []).any((eq) => (eq['overloadOptions'] as List<dynamic>? ?? []).any((opt) => opt != 0)))
          const SizedBox(height: 12),
        _buildEquipmentOverloadList(
            char['equipment'] as List<dynamic>? ?? [], isDark),
      ],
    );
  }

  Widget _buildOverloadOptionsSum(List<dynamic> equips) {
    final Map<String, List<int>> groups = {};
    for (final eq in equips) {
      final options = eq['overloadOptions'] as List<dynamic>? ?? [];
      for (final optId in options) {
        final int id = optId as int? ?? 0;
        if (id == 0) continue;
        final String optName = _getOptionName(id);
        groups.putIfAbsent(optName, () => []).add(id);
      }
    }

    final List<Map<String, dynamic>> overloadSummaries = [];
    groups.forEach((optName, ids) {
      double sumPercent = 0.0;
      int maxLevel = 0;
      for (final id in ids) {
        sumPercent += BlablaMap.getOptionPercent(id);
        final int lvl = id % 100;
        if (lvl > maxLevel) {
          maxLevel = lvl;
        }
      }
      overloadSummaries.add({
        'name': optName,
        'sumPercent': sumPercent,
        'maxLevel': maxLevel,
        'count': ids.length,
      });
    });

    if (overloadSummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    overloadSummaries.sort((a, b) {
      final int countCompare = b['count'].compareTo(a['count']);
      if (countCompare != 0) return countCompare;
      return b['sumPercent'].compareTo(a['sumPercent']);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: overloadSummaries.map((info) {
        final String optName = info['name'];
        final double sumPercent = info['sumPercent'];
        final int maxLevel = info['maxLevel'] as int? ?? 0;
        final bool isLevel15 = maxLevel == 15;
        final bool isHighLevel = maxLevel >= 12;

        final Color boxBgColor = isLevel15
            ? const Color(0xFF232323)
            : const Color(0xFFEAEAEA);

        final Color labelColor = isLevel15
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF333333);

        final Color valueColor = isHighLevel
            ? const Color(0xFF049EE7)
            : const Color(0xFF7F8C8D);

        return Container(
          margin: const EdgeInsets.only(bottom: 6.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                optName,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '+${sumPercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailHeader(
      Map<String, dynamic> char, Nikke? localNikke, bool isDark) {
    final nameCode = char['name_code'] as int? ?? 0;
    final String mappedName = BlablaMap.characterNames[nameCode] ?? '알 수 없음';
    final grade = char['grade'] as int? ?? 0;
    final core = char['core'] as int? ?? 0;
    final level = char['level'] as int? ?? 1;

    final String starStr = '★' * grade + '☆' * (3 - grade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange, width: 2),
              image: localNikke != null
                  ? DecorationImage(
                      image: AssetImage(localNikke.imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mappedName,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (localNikke != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800.withOpacity(0.2),
                          border: Border.all(
                              color: Colors.orange.shade800, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getCompanyLabel(localNikke.company),
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "지휘관의 니케 코드: $nameCode",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Lv.$level",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "한계 돌파: $grade성 $starStr",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (core > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "+$core",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFavoriteItemShort(Map<String, dynamic>? favItem) {
    if (favItem == null) return '-';
    final int tid = favItem['tid'] as int? ?? 0;
    final int level = favItem['level'] as int? ?? 0;
    if (tid >= 200000) {
      final increasedLevel = level + 1;
      return '♥$increasedLevel';
    } else {
      final bool isSR = (tid % 10 == 2);
      final String type = isSR ? 'SR' : 'R';
      return '$type$level';
    }
  }

  Widget _buildCalculatedStatsGrid(
      Map<String, dynamic> char, Nikke? localNikke, bool isDark) {
    final combat = char['combat'] as int? ?? 0;

    double cp40 = 0;
    double cp400 = 0;
    Map<String, double> stats400 = {'hp': 0.0, 'atk': 0.0, 'def': 0.0};

    if (CpCalculator.isInitialized) {
      cp40 = CpCalculator.calculateCp(char, localNikke,
          targetLevel: 40, assumeCube15: _assumeCube15);
      cp400 = CpCalculator.calculateCp(char, localNikke,
          targetLevel: 400, assumeCube15: _assumeCube15);
      stats400 = CpCalculator.calculateTargetStats(char, localNikke,
          targetLevel: 400, assumeCube15: _assumeCube15);
    }

    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    final skill1 = skills['skill1'] ?? 1;
    final skill2 = skills['skill2'] ?? 1;
    final burst = skills['burst'] ?? 1;

    final String formattedPow = NumberFormat('#,###').format(combat);
    final String formattedPow40 = cp40 == -1.0
        ? '측정 불가'
        : (cp40 > 0 ? NumberFormat('#,###').format(cp40.round()) : '계산중...');
    final String formattedPow400 = cp400 == -1.0
        ? '측정 불가'
        : (cp400 > 0 ? NumberFormat('#,###').format(cp400.round()) : '계산중...');
    
    final String formattedHp400 = stats400['hp']! > 0 ? NumberFormat('#,###').format(stats400['hp']!.round()) : '-';
    final String formattedAtk400 = stats400['atk']! > 0 ? NumberFormat('#,###').format(stats400['atk']!.round()) : '-';
    final String formattedDef400 = stats400['def']! > 0 ? NumberFormat('#,###').format(stats400['def']!.round()) : '-';

    final String skillText = "$skill1 / $skill2 / $burst";

    final favItem = char['favoriteItem'] as Map<String, dynamic>?;
    final String collText = _formatFavoriteItemShort(favItem);
    final bool isFavorite =
        favItem != null && (favItem['tid'] as int? ?? 0) >= 200000;

    final cube = char['harmonyCube'] as Map<String, dynamic>?;
    final int cubeLv = cube != null ? (cube['level'] as int? ?? 0) : 0;
    final String cubeText = _getShortCubeName(cube);
    final bool showCubeToggle = cubeLv < 15;

    final List<Map<String, dynamic>> statItems = [
      {
        "label": "현재 투력 (Pow)",
        "value": formattedPow,
        "color": Colors.orangeAccent.shade200,
      },
      {
        "label": "40Lv 투력 (Pow)",
        "value": formattedPow40,
        "color": Colors.redAccent.shade200,
        "showToggle": showCubeToggle,
        "showLicenseButton": true,
      },
      {
        "label": "400Lv 투력 (Pow)",
        "value": formattedPow400,
        "color": Colors.redAccent.shade400,
      },
      {
        "label": "스킬 레벨 (Skill)",
        "value": skillText,
        "color": Colors.purpleAccent.shade100,
      },
      {
        "label": "소장품 단계 (Coll)",
        "value": collText,
        "color": isFavorite ? Colors.orange : Colors.pinkAccent.shade100,
      },
      {
        "label": "큐브 (Cube)",
        "value": cubeText,
        "color": Colors.cyanAccent.shade400,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 78,
      ),
      itemCount: statItems.length,
      itemBuilder: (context, index) {
        final item = statItems[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14151B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['label'],
                      style: TextStyle(
                        color:
                            isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item['showToggle'] == true)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("15Lv큐브",
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600)),
                        SizedBox(
                          height: 20,
                          child: Transform.scale(
                            scale: 0.6,
                            child: Switch(
                              value: _assumeCube15,
                              onChanged: (val) {
                                setState(() {
                                  _assumeCube15 = val;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['value'],
                    style: TextStyle(
                      color: item['color'],
                      fontSize: 21.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item['showLicenseButton'] == true)
                    SizedBox(
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () => _showLicenseDialog(char, localNikke),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          backgroundColor: Colors.purple.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text("면허 발급",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEquipmentOverloadList(List<dynamic> equips, bool isDark) {
    final Map<String, dynamic> equipsBySlot = {
      for (final eq in equips) eq['slot'] as String: eq
    };

    final List<String> slots = ['head', 'torso', 'arm', 'leg'];
    final List<String> slotLabels = [
      '머리 (Visor)',
      '몸통 (Chest/Vest)',
      '팔 (Arms/Guards)',
      '다리 (Legs/Boots)'
    ];

    return Column(
      children: List.generate(4, (index) {
        final slot = slots[index];
        final label = slotLabels[index];
        final eq = equipsBySlot[slot];

        if (eq == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14151B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  "장착 장비 없음",
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        final int tid = eq['tid'] as int? ?? 0;
        final int level = eq['level'] as int? ?? 0;
        final int tier = eq['tier'] as int? ?? 0;
        final String eqName =
            BlablaMap.equipmentNames[tid] ?? "$label 장비 ($tid)";
        final rawOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
        final List<dynamic> options = List.from(rawOptions);
        if (options.isNotEmpty) {
          while (options.length < 3) {
            options.add(0);
          }
        }
        final isOverloaded = options.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14151B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800.withOpacity(0.15),
                      border:
                          Border.all(color: Colors.orange.shade800, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Tier $tier",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "$eqName (+$level)",
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.bold,
                  color: tier >= 10
                      ? (isDark
                          ? Colors.pinkAccent.shade100
                          : Colors.pink.shade600)
                      : (isDark
                          ? Colors.orange.shade300
                          : Colors.orange.shade800),
                ),
              ),
              const SizedBox(height: 8),
              if (isOverloaded) ...[
                const Divider(color: Colors.grey, height: 16, thickness: 0.5),
                Column(
                  children: List.generate(options.length, (idx) {
                    final int id = options[idx] as int? ?? 0;
                    final String slotPrefix = "[${idx + 1}슬롯] ";
                    if (id == 0) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAEAEA),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$slotPrefix효과 없음",
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7F8C8D),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final double percent = BlablaMap.getOptionPercent(id);
                    final String name = BlablaMap.getOptionName(id);
                    final int optLevel = id % 100;

                    final bool isLevel15 = optLevel == 15;
                    final bool isHighLevel =
                        optLevel >= 12; // Lv. 12-15 are high level

                    // 1. Background color (matching in-game, independent of dark/light theme)
                    final Color boxBgColor = isLevel15
                        ? const Color(0xFF232323) // 최대레벨옵션일 경우 배경 (#232323)
                        : const Color(0xFFEAEAEA); // 일반 오버로드 옵션 칸 배경 (#eaeaea)

                    // 2. Option name text color (matching in-game, independent of dark/light theme)
                    final Color nameTextColor = isLevel15
                        ? const Color(0xFFFFFFFF) // 최대 레벨일 때는 흰색 글씨
                        : const Color(0xFF333333); // 일반 레벨일 때는 어두운 회색 글씨

                    // 3. Value and icon color (matching in-game)
                    final Color valueColor = isHighLevel
                        ? const Color(0xFF049EE7) // 파란색 글씨 (#049ee7)
                        : const Color(0xFF7F8C8D); // 일반 옵션 수치 색상 (회색)

                    final Color iconColor =
                        isHighLevel ? valueColor : const Color(0xFF7F8C8D);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: boxBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: iconColor,
                                size: 14.5,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$slotPrefix$name 증가 (Lv.$optLevel)",
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: nameTextColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "+${percent.toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: valueColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ] else ...[
                const Divider(color: Colors.grey, height: 16, thickness: 0.5),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "오버로드 옵션 없음",
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDebugCpWidget(
      Map<String, dynamic> char, Nikke? localNikke, bool isDark) {
    if (!CpCalculator.isInitialized) return const SizedBox();

    final debug = CpCalculator.debugCalculateCp(char, localNikke,
        targetLevel: 40, assumeCube15: _assumeCube15);

    final Color titleColor = isDark ? Colors.yellowAccent : Colors.deepOrange;
    final Color textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("🛠️ 40레벨 전투력 디버깅",
              style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text("최종 투력: ${debug['cp'].toStringAsFixed(2)}",
              style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text("[보정계수 (Bojung)] : ${debug['bojung'].toStringAsFixed(4)}",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text(
              "= 1.3 + (0.01 * ${debug['skill1']}) + (0.01 * ${debug['skill2']}) + (0.02 * ${debug['skillBurst']})",
              style: TextStyle(color: textColor, fontSize: 12)),
          Text(
              "  + (0.00828 * ${debug['ukoLevel']} 우코) + (0.0069 * ${debug['nonUkoLevel']} 비우코)",
              style: TextStyle(color: textColor, fontSize: 12)),
          Text(
              "  + (0.0092 * ${debug['cubeCoef']} 큐브) + (0.0069 * ${debug['colCoef']} 소장품)",
              style: TextStyle(color: textColor, fontSize: 12)),
          const Divider(),
          Text("[협전스탯_HP] : ${debug['finalHp'].toStringAsFixed(2)}",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text(
              "= ((${debug['baseHp']} * ${debug['lbMult']}) + (${debug['bondHp']} + ${debug['consoleHp']} + ${debug['bojungHp']})) * ${debug['coreMult']}",
              style: TextStyle(color: textColor, fontSize: 12)),
          Text(
              "  + (${debug['equipHp']} + ${debug['colHp']} + ${debug['cubeHp']})",
              style: TextStyle(color: textColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text("[협전스탯_ATK] : ${debug['finalAtk'].toStringAsFixed(2)}",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text(
              "= ((${debug['baseAtk']} * ${debug['lbMult']}) + (${debug['bondAtk']} + ${debug['consoleAtk']} + ${debug['bojungAtk']})) * ${debug['coreMult']}",
              style: TextStyle(color: textColor, fontSize: 12)),
          Text(
              "  + (${debug['equipAtk']} + ${debug['colAtk']} + ${debug['cubeAtk']})",
              style: TextStyle(color: textColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text("[협전스탯_DEF] : ${debug['finalDef'].toStringAsFixed(2)}",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text(
              "= ((${debug['baseDef']} * ${debug['lbMult']}) + (${debug['bondDef']} + ${debug['consoleDef']} + ${debug['bojungDef']})) * ${debug['coreMult']}",
              style: TextStyle(color: textColor, fontSize: 12)),
          Text(
              "  + (${debug['equipDef']} + ${debug['colDef']} + ${debug['cubeDef']})",
              style: TextStyle(color: textColor, fontSize: 12)),
          const Divider(),
          Text("[협전스탯 점수 (Score)] : ${debug['score'].toStringAsFixed(2)}",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text(
              "= 0.7 * ${debug['finalHp'].toStringAsFixed(2)} + 19.35 * ${debug['finalAtk'].toStringAsFixed(2)} + 70 * ${debug['finalDef'].toStringAsFixed(2)}",
              style: TextStyle(color: textColor, fontSize: 12)),
        ],
      ),
    );
  }

  Future<Uint8List?> _captureKeyToBytes(GlobalKey key) async {
    try {
      // Allow some delay for rendering
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  void _showLicenseDialog(Map<String, dynamic> char, Nikke? localNikke) {
    double cp40 = 0;
    if (CpCalculator.isInitialized) {
      cp40 = CpCalculator.calculateCp(char, localNikke,
          targetLevel: 40, assumeCube15: _assumeCube15);
    }

    final GlobalKey captureKey = GlobalKey();

    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("미리보기",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.black54),
                              onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.contain,
                        child: RepaintBoundary(
                          key: captureKey,
                          child:
                              _buildDriverLicenseCanvas(char, localNikke, cp40),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.content_copy,
                                color: Colors.purple),
                            label: const Text("클립보드 복사",
                                style: TextStyle(color: Colors.purple)),
                            onPressed: () async {
                              final bytes =
                                  await _captureKeyToBytes(captureKey);
                              if (bytes != null) {
                                try {
                                  await Pasteboard.writeImage(bytes);
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('클립보드에 복사되었습니다!')));
                                } catch (e) {
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('복사 실패: $e')));
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon:
                                const Icon(Icons.download, color: Colors.white),
                            label: const Text("이미지 다운로드",
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                elevation: 0),
                            onPressed: () async {
                              final bytes =
                                  await _captureKeyToBytes(captureKey);
                              if (bytes != null) {
                                if (kIsWeb) {
                                  final blob = html.Blob([bytes], 'image/png');
                                  final url =
                                      html.Url.createObjectUrlFromBlob(blob);
                                  html.AnchorElement(href: url)
                                    ..setAttribute('download',
                                        'license_${DateTime.now().millisecondsSinceEpoch}.png')
                                    ..click();
                                  html.Url.revokeObjectUrl(url);
                                } else {
                                  await ImageGallerySaver.saveImage(bytes,
                                      name:
                                          "license_${DateTime.now().millisecondsSinceEpoch}");
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('저장되었습니다!')));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildDriverLicenseCanvas(
      Map<String, dynamic> char, Nikke? localNikke, double cp40) {
    final nameCode = char['name_code'] as int? ?? 0;
    final String mappedName = BlablaMap.characterNames[nameCode] ?? '알 수 없음';
    final nickname = _profileData?['nickname'] ?? '지휘관';
    final displayName = _showNicknameOnLicense ? "$nickname의 $mappedName" : mappedName;
    final String formattedPow40 = cp40 == -1.0
        ? '측정 불가'
        : (cp40 > 0 ? NumberFormat('#,###').format(cp40.round()) : '계산중...');
    final today = DateFormat('yyyy.MM.dd').format(DateTime.now());

    final grade = char['grade'] as int? ?? 0;
    final core = char['core'] as int? ?? 0;
    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    final skill1 = skills['skill1'] ?? 1;
    final skill2 = skills['skill2'] ?? 1;
    final burst = skills['burst'] ?? 1;

    String starStr = '★' * grade + '☆' * (3 - grade);
    if (core > 0) {
      starStr += '  +$core';
    }

    String licenseType = "1종 보통";
    if (cp40 >= 70000) {
      licenseType = "1종 특수";
    } else if (cp40 >= 60000) {
      licenseType = "1종 대형";
    } else if (cp40 > 0 && cp40 < 40000) {
      licenseType = "자전거 면허";
    } else if (cp40 > 0 && cp40 < 50000) {
      licenseType = "1종 소형";
    }

    final bool isSpecial = licenseType == "1종 특수";
    final Color textColor = isSpecial ? Colors.white : Colors.black87;
    final Color subTextColor = isSpecial ? Colors.white70 : Colors.black54;

    return Container(
      width: 640,
      decoration: BoxDecoration(
        color: isSpecial ? const Color(0xFF151515) : Colors.white,
        gradient: isSpecial
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2C2C35),
                  Color(0xFF0F0F13),
                ],
              )
            : const RadialGradient(
                center: Alignment.centerRight,
                radius: 1.5,
                colors: [
                  Color(0xFFE8F4F8),
                  Color(0xFFFDE8F3),
                  Color(0xFFFFF6E5),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSpecial ? Colors.transparent : Colors.black12,
            width: isSpecial ? 0 : 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(licenseType,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color:
                                    isSpecial ? Colors.amber : Colors.black87,
                                shadows: isSpecial
                                    ? [
                                        Shadow(
                                          offset: const Offset(1, 1),
                                          blurRadius: 2.0,
                                          color: Colors.black.withOpacity(0.5),
                                        ),
                                        Shadow(
                                          offset: const Offset(0, 0),
                                          blurRadius: 6.0,
                                          color: Colors.amber.withOpacity(0.5),
                                        ),
                                      ]
                                    : null)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSpecial ? 0 : 6, vertical: 2),
                      color: isSpecial
                          ? Colors.transparent
                          : Colors.yellow.shade200,
                      child: Text("이 면허증은 현실에서",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSpecial
                                  ? Colors.red.shade400
                                  : Colors.black87)),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSpecial ? 0 : 6, vertical: 2),
                      color: isSpecial
                          ? Colors.transparent
                          : Colors.yellow.shade200,
                      child: Text("쓰면 안 돼요! (진짜임)",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSpecial
                                  ? Colors.red.shade400
                                  : Colors.black87)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 170,
                      height: 240,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSpecial
                                  ? Colors.amber.withOpacity(0.3)
                                  : Colors.black12,
                              width: 1),
                          color: isSpecial
                              ? Colors.grey.shade900
                              : Colors.grey.shade200,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black
                                    .withOpacity(isSpecial ? 0.5 : 0.1),
                                blurRadius: 4,
                                offset: const Offset(2, 2))
                          ]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: localNikke != null
                            ? Image.asset(
                                localNikke.imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              )
                            : const SizedBox(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "협전 운전 면허증",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: -0.5,
                                shadows: isSpecial
                                    ? [
                                        Shadow(
                                          offset: const Offset(1, 1),
                                          blurRadius: 2.0,
                                          color: Colors.black.withOpacity(0.5),
                                        ),
                                        Shadow(
                                          offset: const Offset(0, 0),
                                          blurRadius: 6.0,
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ]
                                    : null),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "(Driver's License)",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: subTextColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                          height: 2,
                          color: isSpecial
                              ? Colors.amber.withOpacity(0.6)
                              : Colors.pink.shade200),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Text("이름 : ",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Expanded(
                              child: Text(displayName,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                      letterSpacing: 1.0),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text("전투력 : ",
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text(formattedPow40,
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: isSpecial
                                      ? Colors.amber
                                      : Colors.black87,
                                  shadows: isSpecial
                                      ? [
                                          Shadow(
                                            offset: const Offset(1, 1),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                          Shadow(
                                            offset: const Offset(0, 0),
                                            blurRadius: 6.0,
                                            color: Colors.amber.withOpacity(0.5),
                                          ),
                                        ]
                                      : null)),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text("한계 돌파 : ",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text(starStr,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text("스킬 레벨 : ",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text("$skill1 / $skill2 / $burst",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textColor)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Spacer(),
                          Text(today,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 1.0)),
                          const Spacer(),
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Text("발급기관 : 미미르만만세",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: textColor)),
                              Positioned(
                                right: -10,
                                top: -60,
                                child: Opacity(
                                  opacity: 0.9,
                                  child: Transform.rotate(
                                    angle: -0.15,
                                    child: Image.asset(
                                      'assets/images/dorodojang.png',
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}
