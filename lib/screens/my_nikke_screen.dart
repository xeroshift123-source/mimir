import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/enums.dart';
import 'package:mimir/utils/blabla_map.dart';
import 'package:mimir/services/database_service.dart';
import 'package:mimir/widgets/app_drawer.dart';

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
          _errorMessage = "올바른 지휘관 OpenID 정보가 제공되지 않았습니다.\n프로필 동기화 화면에서 먼저 동기화를 수행해 주세요.";
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
          _errorMessage = "데이터베이스에서 프로필 정보를 찾을 수 없습니다.\n블라블라링크 동기화를 다시 진행해 주세요.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "프로필 로드 중 오류가 발생했습니다: ${e.toString()}";
      });
    }
  }

  // 💡 Overload option scaling formula
  double _getOptionPercent(int id) {
    final int tier = id % 100;
    if (tier < 1 || tier > 15) return 0.0;

    if (id >= 7000501 && id <= 7000515) {
      // 우월코드 대미지 증가
      const vals = [0.0, 9.54, 10.94, 12.34, 13.75, 15.15, 16.55, 17.95, 19.35, 20.75, 22.15, 23.56, 24.96, 26.36, 27.76, 29.16];
      return vals[tier];
    } else if (id >= 7000601 && id <= 7000615) {
      // 명중률 증가
      const vals = [0.0, 4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63];
      return vals[tier];
    } else if (id >= 7000701 && id <= 7000715) {
      // 최대 장탄 수 증가
      const vals = [0.0, 27.84, 31.95, 36.06, 40.17, 44.28, 48.39, 52.50, 56.60, 60.71, 64.82, 68.93, 73.04, 77.15, 81.26, 85.37];
      return vals[tier];
    } else if (id >= 7000801 && id <= 7000815) {
      // 공격력 증가
      const vals = [0.0, 4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63];
      return vals[tier];
    } else if (id >= 7000901 && id <= 7000915) {
      // 차지 대미지 증가
      const vals = [0.0, 4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63];
      return vals[tier];
    } else if (id >= 7001001 && id <= 7001015) {
      // 차지 속도 증가
      const vals = [0.0, 1.98, 2.28, 2.57, 2.86, 3.16, 3.45, 3.75, 4.04, 4.33, 4.63, 4.92, 5.21, 5.51, 5.80, 6.09];
      return vals[tier];
    } else if (id >= 7001101 && id <= 7001115) {
      // 크리티컬 확률 증가
      const vals = [0.0, 2.30, 2.64, 2.98, 3.32, 3.66, 4.00, 4.35, 4.69, 5.03, 5.37, 5.70, 6.05, 6.39, 6.73, 7.07];
      return vals[tier];
    } else if (id >= 7001201 && id <= 7001215) {
      // 크리티컬 대미지 증가
      const vals = [0.0, 6.64, 7.62, 8.60, 9.58, 10.56, 11.54, 12.52, 13.50, 14.48, 15.46, 16.44, 17.42, 18.40, 19.38, 20.36];
      return vals[tier];
    } else if (id >= 7001301 && id <= 7001315) {
      // 방어력 증가
      const vals = [0.0, 4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63];
      return vals[tier];
    }
    return 0.0;
  }

  String _getOptionName(int id) {
    if (id >= 7000501 && id <= 7000515) return '우월코드 대미지';
    if (id >= 7000601 && id <= 7000615) return '명중률';
    if (id >= 7000701 && id <= 7000715) return '최대 장탄 수';
    if (id >= 7000801 && id <= 7000815) return '공격력';
    if (id >= 7000901 && id <= 7000915) return '차지 대미지';
    if (id >= 7001001 && id <= 7001015) return '차지 속도';
    if (id >= 7001101 && id <= 7001115) return '크리티컬 확률';
    if (id >= 7001201 && id <= 7001215) return '크리티컬 대미지';
    if (id >= 7001301 && id <= 7001315) return '방어력';
    return '알 수 없는 옵션';
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
      backgroundColor: isDark ? const Color(0xFF0D0E12) : const Color(0xFFF5F5F7),
      drawer: const AppDrawer(activeRoute: '/my-nikkes'),
      appBar: AppBar(
        title: Text(
          _profileData != null ? "내 니케 데이터보기 (${_profileData!['nickname']})" : "내 니케 데이터보기",
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
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
            const Icon(Icons.error_outline_rounded, size: 72, color: Colors.redAccent),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      
      // 1. Search Query
      if (_searchQuery.isNotEmpty &&
          !mappedName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      final localNikke = nikkeNameMap[mappedName];
      if (localNikke == null) return true; // Keep mapped if local not found, filters don't apply

      // 2. Filters
      if (_burstFilters.isNotEmpty && !_burstFilters.contains(localNikke.burst)) return false;
      if (_elementFilters.isNotEmpty && !_elementFilters.contains(localNikke.element)) return false;
      if (_weaponFilters.isNotEmpty && !_weaponFilters.contains(localNikke.weaponType)) return false;
      if (_companyFilters.isNotEmpty && !_companyFilters.contains(localNikke.company)) return false;

      return true;
    }).toList();

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
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildProfileSummaryBar(isDark),
                          _buildSearchAndFilters(isDark),
                          Expanded(
                            child: _buildNikkeList(filteredChars, nikkeNameMap, isDark),
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
                        : _buildDetailPanel(filteredChars[_selectedCharIndex.clamp(0, filteredChars.length - 1)], nikkeNameMap, isDark),
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
                child: _buildNikkeGrid(filteredChars, nikkeNameMap, isDark, true),
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

    final formattedCP = NumberFormat('#,###').format(cp);

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF14151B) : Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
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
        ],
      ),
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
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "니케 이름 검색...",
                      hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF121212) : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
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
                  color: _filterExpanded || _hasActiveFilters() ? Colors.orange : Colors.grey,
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
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.orange),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      color: isSel ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.black87),
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
        childAspectRatio: 0.75, // Aspect ratio of 0.75 exactly maps to 90x120 style cards
      ),
      itemCount: filteredChars.length,
      itemBuilder: (context, index) {
        final char = filteredChars[index];
        final nameCode = char['name_code'] as int? ?? 0;
        final String mappedName = BlablaMap.characterNames[nameCode] ?? '알 수 없음';
        final localNikke = nameMap[mappedName];

        final isSelected = !isMobile && _selectedCharIndex == index;
        final grade = char['grade'] as int? ?? 0;
        final core = char['core'] as int? ?? 0;
        final level = char['level'] as int? ?? 1;
        final combat = char['combat'] as int? ?? 0;

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
                            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
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
                          errorBuilder: (_, __, ___) => const SizedBox(width: 14, height: 14),
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
                          errorBuilder: (_, __, ___) => const SizedBox(width: 14, height: 14),
                        ),
                      ),
                    ),

                  // 4. Core Break Badge (red ribbon under element)
                  if (core > 0)
                    Positioned(
                      left: 4,
                      top: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
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
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
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
                                starIdx < grade ? Icons.star_rounded : Icons.star_border_rounded,
                                color: starIdx < grade ? Colors.amber : Colors.white30,
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
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                              Text(
                                NumberFormat('#,###').format(combat),
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
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

  void _showMobileDetailsSheet(Map<String, dynamic> char, Map<String, Nikke> nameMap, bool isDark) {
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
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _buildDetailPanel(char, nameMap, isDark),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, double> _calculateStats(Map<String, dynamic> char, Nikke? localNikke) {
    final int level = char['level'] as int? ?? 1;
    final int grade = char['grade'] as int? ?? 0;
    final int core = char['core'] as int? ?? 0;

    String role = 'Supporter';
    final String name = localNikke?.name ?? '';
    
    const attackers = {
      '홍련', '홍련 : 흑영', '모더니아', '레드 후드', '앨리스', '신데렐라', '스노우 화이트', 
      '맥스웰', '아인', '파워', '2B', 'A2', '아니스 : 스파클링 서머', '루드밀라 : 윈터 오너', 
      '길로틴', '메이든', '하란', '에피넬', '베스티', '브리드', '솔린', '율하', '드레이크', 
      '라플라스', '사쿠라 : 블룸 인 서머', '로산나 : 시크 오션', '누아르', '프리바티', '그레이브'
    };
    const defenders = {
      '크라운', '노아', '블랑', '디젤', '센티', '비스킷', '노이즈', '티아', '소다', 
      '킬로', '신', '베이', '루마니'
    };
    
    if (attackers.contains(name)) {
      role = 'Attacker';
    } else if (defenders.contains(name)) {
      role = 'Defender';
    }

    double baseHp = 0;
    double baseAtk = 0;
    double baseDef = 0;
    double hpGrowth = 0;
    double atkGrowth = 0;
    double defGrowth = 0;

    if (role == 'Attacker') {
      baseHp = 502000;
      baseAtk = 24200;
      baseDef = 3300;
      hpGrowth = 11900;
      atkGrowth = 562;
      defGrowth = 76;
    } else if (role == 'Defender') {
      baseHp = 608000;
      baseAtk = 17100;
      baseDef = 4600;
      hpGrowth = 14500;
      atkGrowth = 401;
      defGrowth = 110;
    } else { // Supporter
      baseHp = 555000;
      baseAtk = 20650;
      baseDef = 3950;
      hpGrowth = 13200;
      atkGrowth = 482;
      defGrowth = 94;
    }

    double hp = 0;
    double atk = 0;
    double def = 0;

    if (level <= 200) {
      final ratio = level / 200.0;
      hp = baseHp * ratio;
      atk = baseAtk * ratio;
      def = baseDef * ratio;
    } else {
      final diff = level - 200;
      hp = baseHp + diff * hpGrowth;
      atk = baseAtk + diff * atkGrowth;
      def = baseDef + diff * defGrowth;
    }

    final statMultiplier = 1.0 + (grade * 0.02) + (core * 0.02);
    hp *= statMultiplier;
    atk *= statMultiplier;
    def *= statMultiplier;

    final equips = char['equipment'] as List<dynamic>? ?? [];
    for (final eq in equips) {
      final int level = eq['level'] as int? ?? 0;
      final int tier = eq['tier'] as int? ?? 1;
      final String slot = eq['slot'] as String? ?? '';

      double eqHp = 0;
      double eqAtk = 0;
      double eqDef = 0;

      if (tier >= 10) {
        if (slot == 'head') {
          eqAtk = 9576 + level * 478.8;
        } else if (slot == 'torso') {
          eqHp = 143640 + level * 7182;
          eqDef = 521 + level * 26.05;
        } else if (slot == 'arm') {
          eqAtk = 5745 + level * 287.25;
          eqHp = 86184 + level * 4309.2;
        } else if (slot == 'leg') {
          eqHp = 86184 + level * 4309.2;
          eqDef = 782 + level * 39.1;
        }
      } else if (tier == 9) {
        if (slot == 'head') {
          eqAtk = 6200 + level * 310;
        } else if (slot == 'torso') {
          eqHp = 93000 + level * 4650;
          eqDef = 380 + level * 19;
        } else if (slot == 'arm') {
          eqAtk = 3700 + level * 185;
          eqHp = 55800 + level * 2790;
        } else if (slot == 'leg') {
          eqHp = 55800 + level * 2790;
          eqDef = 550 + level * 27.5;
        }
      } else {
        if (slot == 'head') eqAtk = 2000 * (tier / 8.0);
        if (slot == 'torso') eqHp = 30000 * (tier / 8.0);
        if (slot == 'arm') eqAtk = 1200 * (tier / 8.0);
        if (slot == 'leg') eqHp = 18000 * (tier / 8.0);
      }

      hp += eqHp;
      atk += eqAtk;
      def += eqDef;
    }

    double overloadAtkPct = 0;
    double overloadDefPct = 0;
    double overloadHpPct = 0;

    for (final eq in equips) {
      final options = eq['overloadOptions'] as List<dynamic>? ?? [];
      for (final optId in options) {
        final int id = optId as int? ?? 0;
        final double pct = _getOptionPercent(id) / 100.0;
        final String optName = _getOptionName(id);
        if (optName == '공격력') {
          overloadAtkPct += pct;
        } else if (optName == '방어력') {
          overloadDefPct += pct;
        }
      }
    }

    final double finalHp = hp * (1.0 + overloadHpPct);
    final double finalAtk = atk * (1.0 + overloadAtkPct);
    final double finalDef = def * (1.0 + overloadDefPct);

    return {
      'hp': finalHp,
      'atk': finalAtk,
      'def': finalDef,
    };
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
        final String mappedName = BlablaMap.characterNames[nameCode] ?? '알 수 없음';
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
                color: isSelected ? Colors.orange : (isDark ? Colors.grey.shade900 : Colors.grey.shade300),
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
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      border: Border.all(color: Colors.redAccent, width: 1),
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
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
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
    final combat = char['combat'] as int? ?? 0;
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
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
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
                    errorBuilder: (_, __, ___) => const SizedBox(width: 14, height: 14),
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
                    errorBuilder: (_, __, ___) => const SizedBox(width: 14, height: 14),
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
      return const Text("-", style: TextStyle(color: Colors.grey, fontSize: 13));
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
      return const Text("-", style: TextStyle(color: Colors.grey, fontSize: 12));
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
    String type = '큐브';
    final lastDigit = tid % 10;
    switch (lastDigit) {
      case 1: type = '명중'; break;      // Assault Cube
      case 2: type = '차뎀'; break;      // Onslaught Cube
      case 3: type = '재장전'; break;    // Resilience Cube
      case 4: type = '차속'; break;      // Adjutant Cube
      case 5: type = '탄환'; break;      // Bastion Cube
      case 6: type = '탄환'; break;      // Wingman Cube
      case 7: type = '충속'; break;      // Quantum Cube
      case 8: type = '체력'; break;      // Vigor Cube
      case 9: type = '힐량'; break;      // Healing Cube
      case 0: type = '방어'; break;      // Endurance/Tempering Cube
    }
    return '$type $level';
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
            const Text(" / ", style: TextStyle(color: Colors.grey, fontSize: 12)),
            buildSlotText('torso', '몸통'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildSlotText('arm', '장갑'),
            const Text(" / ", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        sumPercent += _getOptionPercent(id);
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
        final int maxLevel = info['maxLevel'];

        final bool isLevel15 = maxLevel == 15;
        final bool isLevel12OrHigher = maxLevel >= 12;

        final Color boxBgColor = isLevel15 ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE);
        final Color labelColor = isLevel15 ? Colors.white70 : Colors.black87;
        Color valueColor = isLevel15 ? const Color(0xFF64B5F6) : Colors.black87;
        if (isLevel12OrHigher) {
          valueColor = isLevel15 ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1);
        }

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

  Widget _buildDetailPanel(Map<String, dynamic> char, Map<String, Nikke> nameMap, bool isDark) {
    final nameCode = char['name_code'] as int? ?? 0;
    final String mappedName = BlablaMap.characterNames[nameCode] ?? '알 수 없음';
    final localNikke = nameMap[mappedName];

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildDetailHeader(char, localNikke, isDark),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.analytics_outlined, color: Colors.orange.shade700, size: 20),
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
        const SizedBox(height: 12),
        _buildCalculatedStatsGrid(char, localNikke, isDark),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              "각 부위별 장비 오버로드 상세 정보",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEquipmentOverloadList(char['equipment'] as List<dynamic>? ?? [], isDark),
      ],
    );
  }

  Widget _buildDetailHeader(Map<String, dynamic> char, Nikke? localNikke, bool isDark) {
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
        border: Border.all(color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800.withOpacity(0.2),
                          border: Border.all(color: Colors.orange.shade800, width: 1),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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

  Widget _buildCalculatedStatsGrid(Map<String, dynamic> char, Nikke? localNikke, bool isDark) {
    final combat = char['combat'] as int? ?? 0;
    final stats = _calculateStats(char, localNikke);
    
    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    final skill1 = skills['skill1'] ?? 1;
    final skill2 = skills['skill2'] ?? 1;
    final burst = skills['burst'] ?? 1;

    final String formattedPow = NumberFormat('#,###').format(combat);
    final String formattedHP = NumberFormat('#,###').format(stats['hp']!.round());
    final String formattedATK = NumberFormat('#,###').format(stats['atk']!.round());
    final String formattedDEF = NumberFormat('#,###').format(stats['def']!.round());
    final String skillText = "$skill1 / $skill2 / $burst";
    
    final favItem = char['favoriteItem'] as Map<String, dynamic>?;
    final String collText = _formatFavoriteItemShort(favItem);
    final bool isFavorite = favItem != null && (favItem['tid'] as int? ?? 0) >= 200000;

    final cube = char['harmonyCube'] as Map<String, dynamic>?;
    final String cubeText = _getShortCubeName(cube);

    final List<Map<String, dynamic>> statItems = [
      {
        "label": "전투력 (Pow)",
        "value": formattedPow,
        "color": Colors.orangeAccent.shade200,
      },
      {
        "label": "체력 (HP)",
        "value": formattedHP,
        "color": Colors.red.shade400,
      },
      {
        "label": "공격력 (ATK)",
        "value": formattedATK,
        "color": Colors.amber.shade400,
      },
      {
        "label": "방어력 (DEF)",
        "value": formattedDEF,
        "color": Colors.tealAccent.shade400,
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
        childAspectRatio: 3.4,
      ),
      itemCount: statItems.length,
      itemBuilder: (context, index) {
        final item = statItems[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14151B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['label'],
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['value'],
                style: TextStyle(
                  color: item['color'],
                  fontSize: 21.5,
                  fontWeight: FontWeight.bold,
                ),
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
              border: Border.all(color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),
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
        final String eqName = BlablaMap.equipmentNames[tid] ?? "$label 장비 ($tid)";
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800.withOpacity(0.15),
                      border: Border.all(color: Colors.orange.shade800, width: 1),
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
                      ? (isDark ? Colors.pinkAccent.shade100 : Colors.pink.shade600)
                      : (isDark ? Colors.orange.shade300 : Colors.orange.shade800),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$slotPrefix효과 없음",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final double percent = _getOptionPercent(id);
                    final String name = _getOptionName(id);
                    final int optLevel = id % 100;
                    
                    final bool isLevel15 = optLevel == 15;
                    final bool isLevel12OrHigher = optLevel >= 12;
                    
                    final Color boxBgColor = isLevel15 ? const Color(0xFF121212) : const Color(0xFFEEEEEE);
                    Color textColor = Colors.black87;
                    if (isLevel12OrHigher) {
                      textColor = isLevel15 ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1);
                    }
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                color: isLevel15 ? const Color(0xFF64B5F6) : (isLevel12OrHigher ? const Color(0xFF0D47A1) : Colors.orange.shade700), 
                                size: 14.5,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$slotPrefix$name 증가 (Lv.$optLevel)",
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "+${percent.toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
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
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
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
}
