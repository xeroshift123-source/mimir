import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:pasteboard/pasteboard.dart';

import 'package:mimir/models/enums.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:mimir/widgets/nikke_card.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeckBuilderScreen extends StatefulWidget {
  static const routeName = '/deck-builder';

  const DeckBuilderScreen({super.key});

  @override
  State<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends State<DeckBuilderScreen> {
  String? _selectedNikkeId;
  bool _isNikkeSheetOpen = false;
  List<List<String?>>? _pendingSquadsIds;
  bool _restoredOnce = false;
  final GlobalKey _deckCaptureKey = GlobalKey();
  final GlobalKey _previewCaptureKey = GlobalKey();

  /// 스쿼드 5개 × 슬롯 5개
  /// _squads[스쿼드번호][슬롯번호] = Nikke?
  final List<List<Nikke?>> _squads = List.generate(
    5,
    (_) => List<Nikke?>.filled(5, null, growable: false),
  );

  final List<String> _squadNames = List.generate(5, (i) => 'Squad ${i + 1}');
  static const _kSquadNamesKey = 'deck_builder_squad_names';

  /// 지금 니케를 채워넣을 대상 스쿼드 인덱스 (0 = Squad 1)
  int _activeSquadIndex = 0;

  @override
  void initState() {
    super.initState();

    // 첫 프레임 이후에 저장된 덱 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDeckFromLocal();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_restoredOnce) return;
    final nikkeList = context.watch<NikkeProvider>().nikkeList;
    if (nikkeList.isEmpty) return;
    if (_pendingSquadsIds == null) {
      _restoredOnce = true;
      return;
    }

    final mapById = {for (final n in nikkeList) n.id: n};

    final restoredSquads = _pendingSquadsIds!
        .map((squadIds) =>
            squadIds.map((id) => id == null ? null : mapById[id]).toList())
        .toList();

    setState(() {
      // 길이/슬롯 수가 다를 수도 있으니 방어적으로 적용
      for (int s = 0; s < _squads.length && s < restoredSquads.length; s++) {
        for (int i = 0;
            i < _squads[s].length && i < restoredSquads[s].length;
            i++) {
          _squads[s][i] = restoredSquads[s][i];
        }
      }
    });

    _restoredOnce = true;
    _pendingSquadsIds = null;
  }

  /// 왼쪽 니케 카드 클릭 시 → 선택만 처리
  void _onNikkeTap(Nikke nikke) {
    setState(() {
      // 이미 선택되어 있으면 해제, 아니면 선택
      _selectedNikkeId = (_selectedNikkeId == nikke.id) ? null : nikke.id;
    });
  }

  /// 스쿼드 카드 헤더를 눌렀을 때: 활성 스쿼드 변경
  void _onSquadHeaderTap(int squadIndex) {
    setState(() {
      _activeSquadIndex = squadIndex;
    });
  }

  // 🔽 기존에 이미 있던 검색 상태 (있다면 중복 선언 X)
  String _searchQuery = '';

  // 🔽 새로 추가: 여러 개 선택 가능한 필터들
  final Set<BurstType> _burstFilters = {};
  final Set<ElementType> _elementFilters = {};
  final Set<WeaponType> _weaponFilters = {};
  final Set<Company> _companyFilters = {};

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

  void _setSquadName(int squadIndex, String newName) {
    final name = newName.trim();
    if (name.isEmpty) return;

    setState(() {
      _squadNames[squadIndex] = name;
    });
    _saveDeckToLocal();
  }

  void _resetSquad(int squadIndex) {
    setState(() {
      for (int i = 0; i < _squads[squadIndex].length; i++) {
        _squads[squadIndex][i] = null;
      }
    });
    _saveDeckToLocal();
  }

  Future<Uint8List?> _capturePreview() async {
    try {
      final boundary = _previewCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<void> _downloadPreview() async {
    final bytes = await _capturePreview();
    if (bytes == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('캡쳐 실패')));
      return;
    }

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'mimir_deck_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final result = await ImageGallerySaver.saveImage(bytes, name: "mimir_deck_${DateTime.now().millisecondsSinceEpoch}");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('갤러리에 저장되었습니다!')));
    }
  }

  Future<void> _copyToClipboard() async {
    final bytes = await _capturePreview();
    if (bytes == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('캡쳐 실패')));
      return;
    }

    try {
      await Pasteboard.writeImage(bytes);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다!')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('클립보드 복사 실패: $e')));
    }
  }

  Widget _buildFiveSquadsShareCanvas() {
    const double w = 600;

    return Container(
      width: w,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...List.generate(_squads.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ShareSquadPanel(
                title: _squadNames[index],
                isActive: index == _activeSquadIndex,
                slots: _squads[index],
              ),
            );
          }),
          const SizedBox(height: 10),
          const Text(
            'Made with Mimir',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Future<void> _showFiveSquadsPreviewDialog() async {
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.25),
        builder: (context) {
          final mq = MediaQuery.of(context);
          final isMobile = mq.size.width < 600;

          final dialogW = isMobile
              ? mq.size.width - 12.0
              : math.min(mq.size.width - 24.0, 640.0);

          final dialogH =
              isMobile ? mq.size.height - 36.0 : mq.size.height * 0.90;

          return PopScope(
            canPop: true,
            onPopInvoked: (didPop) {
              if (!didPop) Navigator.of(context).pop();
            },
            child: Dialog(
              insetPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: SizedBox(
                width: dialogW,
                height: dialogH,
                child: Column(
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('미리보기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RepaintBoundary(
                              key: _previewCaptureKey,
                              child: _buildFiveSquadsShareCanvas(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.content_copy),
                            label: const Text('클립보드 복사'),
                            onPressed: _copyToClipboard,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('이미지 다운로드'),
                            onPressed: _downloadPreview,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('미리보기 생성 실패: $e')),
      );
    }
  }

  /// 스쿼드 슬롯 클릭
  /// - 선택된 니케가 있으면: 빈칸에 배치
  /// - 선택된 니케가 없으면: 해당 슬롯 비우기
  void _onSquadSlotTap(int squadIndex, int slotIndex) {
    setState(() {
      final current = _squads[squadIndex][slotIndex];

      if (_selectedNikkeId != null) {
        final nikkeList = context.read<NikkeProvider>().nikkeList;
        final selected = nikkeList.firstWhere((n) => n.id == _selectedNikkeId);

        // 중복 배치 제거
        for (int s = 0; s < _squads.length; s++) {
          for (int i = 0; i < _squads[s].length; i++) {
            if (_squads[s][i]?.id == selected.id) {
              _squads[s][i] = null;
            }
          }
        }

        _squads[squadIndex][slotIndex] = selected;

        // 한 번 배치했으면 선택 해제
        _selectedNikkeId = null;

        //  배치가 끝났으니 시트 다시 열기 (모바일 UX 루프)
        _isNikkeSheetOpen = true;
      } else {
        if (current != null) {
          _squads[squadIndex][slotIndex] = null;
        }
      }
    });

    _saveDeckToLocal();
  }

  void _onSlotSwap(
    int fromSquadIndex,
    int fromSlotIndex,
    int toSquadIndex,
    int toSlotIndex,
  ) {
    setState(() {
      final fromNikke = _squads[fromSquadIndex][fromSlotIndex];
      final toNikke = _squads[toSquadIndex][toSlotIndex];

      _squads[fromSquadIndex][fromSlotIndex] = toNikke;
      _squads[toSquadIndex][toSlotIndex] = fromNikke;

      // 드래그 후 왼쪽 선택 상태는 유지하거나 해제하고 싶으면 여기서 조정 가능
      // _selectedNikkeId = null;
    });

    _saveDeckToLocal();
  }

// 저장 키
  static const _kSquadsKey = 'deck_builder_squads';
  static const _kActiveKey = 'deck_builder_activeSquadIndex';

  Future<void> _saveDeckToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSquadNamesKey, jsonEncode(_squadNames));

    // Nikke? -> id(String?) 로 변환해서 저장
    final squadsAsIds =
        _squads.map((squad) => squad.map((n) => n?.id).toList()).toList();

    await prefs.setString(_kSquadsKey, jsonEncode(squadsAsIds));
    await prefs.setInt(_kActiveKey, _activeSquadIndex);
  }

  Future<void> _loadDeckFromLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_kSquadsKey);
    final savedActive = prefs.getInt(_kActiveKey);

    // (덱 이름 복원은 지금처럼 먼저 해도 OK)
    final rawNames = prefs.getString(_kSquadNamesKey);
    if (rawNames != null) {
      final decodedNames = (jsonDecode(rawNames) as List).cast<String>();
      for (int i = 0; i < _squadNames.length && i < decodedNames.length; i++) {
        _squadNames[i] = decodedNames[i];
      }
    }

    if (savedActive != null) _activeSquadIndex = savedActive;

    if (raw == null) return;

    final decoded = (jsonDecode(raw) as List)
        .map((squad) => (squad as List).map((e) => e as String?).toList())
        .toList()
        .cast<List<String?>>();

    _pendingSquadsIds = decoded;
    // 여기서 _squads에 바로 적용하지 말고, provider 준비되면 적용!
  }

  @override
  Widget build(BuildContext context) {
    final nikkeList = context.watch<NikkeProvider>().nikkeList;

    // 각 니케가 몇 번 스쿼드에 배치되어 있는지 계산
    final Map<String, int> assignedSquadMap = {};
    for (int s = 0; s < _squads.length; s++) {
      for (final nikke in _squads[s]) {
        if (nikke != null) {
          assignedSquadMap[nikke.id] = s;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "덱 구성",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            tooltip: '덱 캡쳐',
            icon: const Icon(Icons.camera_alt),
            onPressed: () async {
              await _showFiveSquadsPreviewDialog();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900; // 임계값은 취향대로

          if (isMobile) {
            // 📱 모바일 레이아웃
            return _buildMobileLayout(context, nikkeList, assignedSquadMap);
          } else {
            // 💻 데스크탑 / 태블릿 레이아웃
            return _buildDesktopLayout(context, nikkeList, assignedSquadMap);
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<Nikke> nikkeList,
    Map<String, int> assignedSquadMap,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1600,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: NikkeListPanel(
                nikkeList: nikkeList,
                selectedNikkeId: _selectedNikkeId,
                assignedSquadMap: assignedSquadMap,
                onNikkeTap: _onNikkeTap,
                searchQuery: _searchQuery,
                burstFilters: _burstFilters,
                elementFilters: _elementFilters,
                weaponFilters: _weaponFilters,
                companyFilters: _companyFilters,
                onSearchChanged: _onSearchChanged,
                onToggleBurst: _toggleBurstFilter,
                onToggleElement: _toggleElementFilter,
                onToggleWeapon: _toggleWeaponFilter,
                onToggleCompany: _toggleCompanyFilter,
                squadNames: _squadNames,
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 720,
              child: RepaintBoundary(
                key: _deckCaptureKey,
                child: SquadPanel(
                  squads: _squads,
                  squadNames: _squadNames,
                  activeSquadIndex: _activeSquadIndex,
                  onHeaderTap: _onSquadHeaderTap,
                  onSlotTap: _onSquadSlotTap,
                  onSwapSlots: _onSlotSwap,
                  onEditName: _setSquadName,
                  onResetSquad: _resetSquad,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<Nikke> nikkeList,
    Map<String, int> assignedSquadMap,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.7; // 바텀시트 높이 (70%)

    return Stack(
      children: [
        // 🔹 1) 뒤에 깔리는 스쿼드 화면
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: RepaintBoundary(
                  key: _deckCaptureKey,
                  child: SquadPanel(
                    squads: _squads,
                    squadNames: _squadNames,
                    activeSquadIndex: _activeSquadIndex,
                    onHeaderTap: _onSquadHeaderTap,
                    onSlotTap: _onSquadSlotTap,
                    onSwapSlots: _onSlotSwap,
                    onEditName: _setSquadName,
                    onResetSquad: _resetSquad,
                  ),
                ),
              ),
              // 핸들바 올라갈 자리 확보
              const SizedBox(height: 48),
            ],
          ),
        ),

        // 🔹 2) 맨 아래 고정 핸들바 (시트 열기 버튼)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isNikkeSheetOpen = true;
                });
              },
              child: Container(
                height: 48,
                color: Colors.grey.shade900,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '니케 목록 열기',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isNikkeSheetOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _isNikkeSheetOpen = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),

        // 🔹 3) 니케 리스트 바텀시트
        //  - AnimatedSlide 로 아래↔위 슬라이드
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSlide(
            offset: _isNikkeSheetOpen ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: sheetHeight,
                child: Material(
                  elevation: 12,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // 상단 드래그 핸들 + 닫기
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isNikkeSheetOpen = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // 🔥 여기 안에 기존 NikkeListPanel 재사용
                      Expanded(
                        child: NikkeListPanel(
                          nikkeList: nikkeList,
                          selectedNikkeId: _selectedNikkeId,
                          assignedSquadMap: assignedSquadMap,
                          // 모바일에서는 선택하면 시트 닫고, 선택 유지
                          onNikkeTap: (nikke) {
                            _onNikkeTap(nikke); // 기존 선택 로직 그대로
                            setState(() {
                              _isNikkeSheetOpen = false;
                            });
                          },

                          // 필터/검색 상태도 그대로 넘겨주기
                          searchQuery: _searchQuery,
                          burstFilters: _burstFilters,
                          elementFilters: _elementFilters,
                          weaponFilters: _weaponFilters,
                          companyFilters: _companyFilters,
                          onSearchChanged: _onSearchChanged,
                          onToggleBurst: _toggleBurstFilter,
                          onToggleElement: _toggleElementFilter,
                          onToggleWeapon: _toggleWeaponFilter,
                          onToggleCompany: _toggleCompanyFilter,
                          squadNames: _squadNames,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------
/// 왼쪽 니케 목록 패널
/// ---------------------------
/// 왼쪽 니케 목록 패널
class NikkeListPanel extends StatefulWidget {
  final List<Nikke> nikkeList;
  final String? selectedNikkeId;
  final Map<String, int> assignedSquadMap;
  final ValueChanged<Nikke>? onNikkeTap;
  final List<String> squadNames;

  // 🔽 필터 props
  final String searchQuery;
  final Set<BurstType> burstFilters;
  final Set<ElementType> elementFilters;
  final Set<WeaponType> weaponFilters;
  final Set<Company> companyFilters;

  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<BurstType>? onToggleBurst;
  final ValueChanged<ElementType>? onToggleElement;
  final ValueChanged<WeaponType>? onToggleWeapon;
  final ValueChanged<Company>? onToggleCompany;

  const NikkeListPanel({
    super.key,
    required this.nikkeList,
    required this.squadNames,
    this.selectedNikkeId,
    this.assignedSquadMap = const {},
    this.onNikkeTap,
    this.searchQuery = '',
    this.burstFilters = const {},
    this.elementFilters = const {},
    this.weaponFilters = const {},
    this.companyFilters = const {},
    this.onSearchChanged,
    this.onToggleBurst,
    this.onToggleElement,
    this.onToggleWeapon,
    this.onToggleCompany,
  });

  @override
  State<NikkeListPanel> createState() => _NikkeListPanelState();
}

class _NikkeListPanelState extends State<NikkeListPanel>
    with SingleTickerProviderStateMixin {
  bool _filterExpanded = false;

  @override
  Widget build(BuildContext context) {
    // 1) 필터 적용
    List<Nikke> filtered = List<Nikke>.from(widget.nikkeList);

    /// 정렬 (SSR → SR → R, 동일 등급 내에서는 이름순)
    filtered.sort((a, b) {
      final rankDiff = a.rank.sortValue.compareTo(b.rank.sortValue);
      if (rankDiff != 0) return rankDiff;
      // 등급이 같으면 이름순으로
      return a.name.compareTo(b.name);
    });

    // 이름 + ability 검색
    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery.trim().toLowerCase();

      bool matchNikke(Nikke n) {
        // 1) 이름 매칭
        final nameHit = n.name.toLowerCase().contains(q);

        // 2) ability 키워드 매칭 (null 안전)
        final abilityHit = (n.ability).any(
          (a) => a.toLowerCase().contains(q),
        );

        return nameHit || abilityHit;
      }

      filtered = filtered.where(matchNikke).toList();
    }

    // 버스트 필터
    if (widget.burstFilters.isNotEmpty) {
      filtered =
          filtered.where((n) => widget.burstFilters.contains(n.burst)).toList();
    }

    // 속성 필터
    if (widget.elementFilters.isNotEmpty) {
      filtered = filtered
          .where((n) => widget.elementFilters.contains(n.element))
          .toList();
    }

    // 무기 필터
    if (widget.weaponFilters.isNotEmpty) {
      filtered = filtered
          .where((n) => widget.weaponFilters.contains(n.weaponType))
          .toList();
    }

    // 기업 필터
    if (widget.companyFilters.isNotEmpty) {
      filtered = filtered
          .where((n) => widget.companyFilters.contains(n.company))
          .toList();
    }

    return Column(
      children: [
        // 🔹 상단 필터/검색 헤더
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 검색창
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  labelText: '니케 이름 검색',
                ),
                onChanged: widget.onSearchChanged,
              ),
              const SizedBox(height: 8),

              // 버스트 1/2/3 토글 + 필터 버튼
              Row(
                children: [
                  const Text('버스트'),
                  const SizedBox(width: 8),
                  _FilterTagButton(
                    label: 'I',
                    selected: widget.burstFilters.contains(BurstType.burst1),
                    onTap: () => widget.onToggleBurst?.call(BurstType.burst1),
                  ),
                  const SizedBox(width: 4),
                  _FilterTagButton(
                    label: 'II',
                    selected: widget.burstFilters.contains(BurstType.burst2),
                    onTap: () => widget.onToggleBurst?.call(BurstType.burst2),
                  ),
                  const SizedBox(width: 4),
                  _FilterTagButton(
                    label: 'III',
                    selected: widget.burstFilters.contains(BurstType.burst3),
                    onTap: () => widget.onToggleBurst?.call(BurstType.burst3),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterExpanded = !_filterExpanded;
                      });
                    },
                    icon: const Icon(Icons.filter_list),
                    label: const Text('필터'),
                  ),
                ],
              ),

              // 필터 패널 (속성/무기/기업)
              AnimatedSize(
                curve: Curves.easeInOutCubic,
                duration: const Duration(milliseconds: 260),
                clipBehavior: Clip.hardEdge,
                child: _filterExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildFilterPanel(),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 🔹 실제 니케 그리드 (필터 적용 후)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final nikke = filtered[index];

                final int? squadIndex = widget.assignedSquadMap[nikke.id];
                final bool isAssigned = squadIndex != null;

                final bool isSelected =
                    !isAssigned && widget.selectedNikkeId == nikke.id;
                final bool isDimmed = isAssigned ||
                    (widget.selectedNikkeId != null &&
                        widget.selectedNikkeId != nikke.id);

                final String? squadName =
                    (squadIndex == null) ? null : widget.squadNames[squadIndex];

                return NikkeCard(
                  nikke: nikke,
                  onTap: () {
                    if (isAssigned) return;
                    widget.onNikkeTap?.call(nikke);
                  },
                  isSelected: isSelected,
                  isDimmed: isDimmed,
                  assignedSquadIndex: squadIndex,
                  assignedSquadName: squadName, // ✅ 추가
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('속성'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _FilterTagButton(
              label: '작열',
              selected: widget.elementFilters.contains(ElementType.Fire),
              onTap: () => widget.onToggleElement?.call(ElementType.Fire),
            ),
            _FilterTagButton(
              label: '수냉',
              selected: widget.elementFilters.contains(ElementType.Water),
              onTap: () => widget.onToggleElement?.call(ElementType.Water),
            ),
            _FilterTagButton(
              label: '풍압',
              selected: widget.elementFilters.contains(ElementType.Wind),
              onTap: () => widget.onToggleElement?.call(ElementType.Wind),
            ),
            _FilterTagButton(
              label: '전격',
              selected: widget.elementFilters.contains(ElementType.Electric),
              onTap: () => widget.onToggleElement?.call(ElementType.Electric),
            ),
            _FilterTagButton(
              label: '철갑',
              selected: widget.elementFilters.contains(ElementType.Iron),
              onTap: () => widget.onToggleElement?.call(ElementType.Iron),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('무기'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _FilterTagButton(
              label: 'AR',
              selected: widget.weaponFilters.contains(WeaponType.AR),
              onTap: () => widget.onToggleWeapon?.call(WeaponType.AR),
            ),
            _FilterTagButton(
              label: 'SMG',
              selected: widget.weaponFilters.contains(WeaponType.SMG),
              onTap: () => widget.onToggleWeapon?.call(WeaponType.SMG),
            ),
            _FilterTagButton(
              label: 'SG',
              selected: widget.weaponFilters.contains(WeaponType.SG),
              onTap: () => widget.onToggleWeapon?.call(WeaponType.SG),
            ),
            _FilterTagButton(
              label: 'SR',
              selected: widget.weaponFilters.contains(WeaponType.SR),
              onTap: () => widget.onToggleWeapon?.call(WeaponType.SR),
            ),
            _FilterTagButton(
              label: 'RL',
              selected: widget.weaponFilters.contains(WeaponType.RL),
              onTap: () => widget.onToggleWeapon?.call(WeaponType.RL),
            ),
            _FilterTagButton(
              label: 'MG',
              selected: widget.weaponFilters.contains(WeaponType.MG),
              onTap: () => widget.onToggleWeapon?.call(WeaponType.MG),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('기업'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _FilterTagButton(
              label: '엘리시온',
              selected: widget.companyFilters.contains(Company.Elysion),
              onTap: () => widget.onToggleCompany?.call(Company.Elysion),
            ),
            _FilterTagButton(
              label: '미실리스',
              selected: widget.companyFilters.contains(Company.Missilis),
              onTap: () => widget.onToggleCompany?.call(Company.Missilis),
            ),
            _FilterTagButton(
              label: '테트라',
              selected: widget.companyFilters.contains(Company.Tetra),
              onTap: () => widget.onToggleCompany?.call(Company.Tetra),
            ),
            _FilterTagButton(
              label: '필그림',
              selected: widget.companyFilters.contains(Company.Pilgrim),
              onTap: () => widget.onToggleCompany?.call(Company.Pilgrim),
            ),
            _FilterTagButton(
              label: '어브노멀',
              selected: widget.companyFilters.contains(Company.Abnormal),
              onTap: () => widget.onToggleCompany?.call(Company.Abnormal),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterTagButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTagButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? const Color(0xff19aff4) : Colors.grey.shade800,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(selected ? 1.0 : 0.8),
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 스쿼드 패널: 스쿼드 카드 5개
class SquadPanel extends StatelessWidget {
  /// [스쿼드 인덱스][슬롯 인덱스] = Nikke?
  final List<List<Nikke?>> squads;
  final List<String> squadNames;
  final void Function(int squadIndex, String newName)? onEditName;
  final int activeSquadIndex;
  final ValueChanged<int>? onHeaderTap;
  final void Function(int squadIndex, int slotIndex)? onSlotTap;
  final void Function(int fromSquad, int fromSlot, int toSquad, int toSlot)?
      onSwapSlots;
  final ValueChanged<int>? onResetSquad;

  const SquadPanel({
    super.key,
    required this.squads,
    required this.activeSquadIndex,
    required this.squadNames,
    this.onHeaderTap,
    this.onSlotTap,
    this.onEditName,
    this.onSwapSlots,
    this.onResetSquad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.separated(
        itemCount: squads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final slots = squads[index];

          return SquadCard(
            name: squadNames[index],
            isActive: index == activeSquadIndex,
            hasWarning: false,
            slots: slots,
            squadIndex: index,
            onHeaderTap: () => onHeaderTap?.call(index),
            onSlotTap: (slotIndex) => onSlotTap?.call(index, slotIndex),
            onSwapSlots: onSwapSlots,
            onNameChanged: (newName) => onEditName?.call(index, newName),
            onReset: () => onResetSquad?.call(index),
          );
        },
      ),
    );
  }
}

class SquadCard extends StatefulWidget {
  final String name;
  final bool isActive;
  final bool hasWarning;
  final VoidCallback? onReset;
  final List<Nikke?> slots;
  final VoidCallback? onHeaderTap;
  final ValueChanged<int>? onSlotTap;
  final int? squadIndex;
  final void Function(int fromSquad, int fromSlot, int toSquad, int toSlot)?
      onSwapSlots;

  // ✅ 이름 확정 콜백 (부모가 _squadNames 갱신 + 저장)
  final ValueChanged<String>? onNameChanged;

  const SquadCard({
    super.key,
    required this.name,
    required this.slots,
    this.isActive = false,
    this.hasWarning = false,
    this.onReset,
    this.onHeaderTap,
    this.onSlotTap,
    this.squadIndex,
    this.onSwapSlots,
    this.onNameChanged,
  });

  @override
  State<SquadCard> createState() => _SquadCardState();
}

class _SquadCardState extends State<SquadCard> {
  bool _editingName = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
    _focusNode = FocusNode();

    // 포커스 아웃 시 자동 확정
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editingName) {
        _commitName();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SquadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 name이 바뀌면(로드/저장 후) 표시도 동기화
    if (oldWidget.name != widget.name && !_editingName) {
      _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editingName = true;
      _controller.text = widget.name;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _commitName() {
    final newName = _controller.text.trim();

    // 이름 반영/복구 로직 먼저
    if (newName.isEmpty) {
      _controller.text = widget.name;
    } else if (newName != widget.name) {
      widget.onNameChanged?.call(newName);
    }

    // ✅ 포커스/상태 변경은 다음 프레임으로 미룸 (KeyUp 처리 끝난 뒤)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.unfocus();
      setState(() {
        _editingName = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: widget.isActive ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: widget.onHeaderTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _editingName
                          ? Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.enter ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.numpadEnter)) {
                                  _commitName();
                                  return KeyEventResult.handled; // ✅ 여기서 소비
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textInputAction: TextInputAction.done,
                                onEditingComplete:
                                    _commitName, // ✅ 추가 (onSubmitted보다 안정적인 경우 많음)
                                onSubmitted: (_) => _commitName(), // ✅ 남겨둬도 됨
                              ),
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _startEditing, // ✅ 이름 누르면 바로 인라인 편집
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  widget.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    if (_editingName)
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: '이름 저장',
                        onPressed: _commitName,
                      ),
                    if (widget.hasWarning)
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 24),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '스쿼드 초기화',
                      onPressed: widget.onReset, // 아래에서 추가할 콜백
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 슬롯 5개 (기존 그대로)
            Row(
              children: List.generate(widget.slots.length, (slotIndex) {
                final nikke = widget.slots[slotIndex];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _SquadSlot(
                      squadIndex: widget.squadIndex ?? 0,
                      slotIndex: slotIndex,
                      displayIndex: slotIndex + 1,
                      nikke: nikke,
                      onTap: widget.onSlotTap == null
                          ? null
                          : () => widget.onSlotTap!(slotIndex),
                      onSwap: widget.onSwapSlots,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// 스쿼드 내의 하나의 슬롯
class _SquadSlot extends StatelessWidget {
  final int squadIndex; // 어느 스쿼드인지 (0-based)
  final int slotIndex; // 스쿼드 내 슬롯 인덱스 (0-based)
  final int displayIndex; // 화면에 보여줄 번호 (1,2,3,...)
  final Nikke? nikke;
  final VoidCallback? onTap;

  /// from → to 스왑 콜백
  final void Function(int fromSquad, int fromSlot, int toSquad, int toSlot)?
      onSwap;

  const _SquadSlot({
    required this.squadIndex,
    required this.slotIndex,
    required this.displayIndex,
    required this.nikke,
    this.onTap,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    // 1) 슬롯 기본 내용: 폭은 부모(Expanded)가 정하고,
    //    세로 비율은 AspectRatio 로 맞춘다.
    Widget content;
    if (nikke == null) {
      content = GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 0.75, // 폭:높이 = 4:3 느낌 (NikkeCard와 맞춤)
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.black.withOpacity(0.05),
            ),
            alignment: Alignment.center,
            child: Text(
              '$displayIndex',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      );
    } else {
      // NikkeCard 자체가 내부에서 AspectRatio(0.75)를 쓰고 있으니
      // 별도 width/height 없이 그냥 쓰면 됨.
      content = NikkeCard(
        nikke: nikke!,
        onTap: onTap,
        isSelected: false,
        isDimmed: false,
        assignedSquadIndex: null,
        showAssignedOverlay: false,
      );
    }

    // 2) 니케가 있는 슬롯만 드래그 가능
    if (nikke != null) {
      const feedbackWidth = 90.0; // 드래그 중에 따라다니는 카드 크기만 적당히 고정

      final dragData = _SlotDragData(
        squadIndex: squadIndex,
        slotIndex: slotIndex,
      );

      content = LongPressDraggable<_SlotDragData>(
        data: dragData,
        feedback: Material(
          color: Colors.transparent,
          elevation: 4,
          child: SizedBox(
            width: feedbackWidth,
            child: NikkeCard(
              nikke: nikke!,
              onTap: null,
              isSelected: false,
              isDimmed: false,
              assignedSquadIndex: null,
              showAssignedOverlay: false,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: content,
        ),
        child: content,
      );
    }

    // 3) DragTarget으로 감싸기 (그대로 유지)
    return DragTarget<_SlotDragData>(
      onWillAcceptWithDetails: (details) {
        final drag = details.data;
        if (drag.squadIndex == squadIndex && drag.slotIndex == slotIndex) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final drag = details.data;
        if (onSwap != null) {
          onSwap!(
            drag.squadIndex,
            drag.slotIndex,
            squadIndex,
            slotIndex,
          );
        }
      },
      builder: (context, candidate, rejected) {
        final isTargeted = candidate.isNotEmpty;

        if (isTargeted) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: content,
          );
        }

        return content;
      },
    );
  }
}

class _SlotDragData {
  final int squadIndex;
  final int slotIndex;

  const _SlotDragData({
    required this.squadIndex,
    required this.slotIndex,
  });
}

class _ShareSquadPanel extends StatelessWidget {
  final String title;
  final bool isActive;
  final List<Nikke?> slots;

  const _ShareSquadPanel({
    required this.title,
    required this.isActive,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(slots.length, (i) {
                final nikke = slots[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ShareSlotThumb(
                      nikke: nikke,
                      displayIndex: i + 1, // ✅ 1~5로 표시
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

class _ShareSlotThumb extends StatelessWidget {
  final Nikke? nikke;
  final int displayIndex;
  const _ShareSlotThumb({required this.nikke, required this.displayIndex});

  @override
  Widget build(BuildContext context) {
    // NikkeCard가 기본적으로 aspectRatio 0.75를 쓰고 있으니
    // 빈 슬롯도 동일한 비율로 맞춰주는 게 “형식 통일”에 좋음.
    if (nikke == null) {
      return AspectRatio(
        aspectRatio: 0.75,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400),
            color: Colors.black.withOpacity(0.05),
          ),
          alignment: Alignment.center,
          child: Text(
            '$displayIndex',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return NikkeCard(
      nikke: nikke!,
      onTap: null, // 캡쳐용이므로 클릭 X
      isSelected: false,
      isDimmed: false,
      assignedSquadIndex: null,
      showAssignedOverlay: false,
    );
  }
}

