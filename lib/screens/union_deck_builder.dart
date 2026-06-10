import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:universal_html/html.dart' as html;
import 'package:pasteboard/pasteboard.dart';

import 'package:mimir/models/enums.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/shared_deck.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/repository/mock_deck_repository.dart';
import 'package:mimir/repository/local_file_saver.dart';
import 'package:mimir/screens/login.dart';
import 'package:mimir/screens/deck_library.dart';
import 'package:mimir/widgets/nikke_card.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'package:mimir/services/database_service.dart';
import 'package:mimir/utils/blabla_map.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnionDeckBuilderScreen extends StatefulWidget {
  static const routeName = '/union-deck-builder';

  const UnionDeckBuilderScreen({super.key});

  @override
  State<UnionDeckBuilderScreen> createState() => _UnionDeckBuilderScreenState();
}

class _UnionDeckBuilderScreenState extends State<UnionDeckBuilderScreen> {
  String? _selectedNikkeId;
  bool _isNikkeSheetOpen = false;
  String? _weaknessElement;
  Map<String, dynamic>? _profileData; // 👈 추가

  static const Map<String, String> _elementIconMap = {
    '전격': 'assets/icons/elements/icon-elements-Electric.webp',
    '철갑': 'assets/icons/elements/icon-elements-Iron.webp',
    '작열': 'assets/icons/elements/icon-elements-Fire.webp',
    '수냉': 'assets/icons/elements/icon-elements-Water.webp',
    '풍압': 'assets/icons/elements/icon-elements-Wind.webp',
  };
  List<List<String?>>? _pendingSquadsIds;
  bool _restoredOnce = false;
  final GlobalKey _deckCaptureKey = GlobalKey();
  final GlobalKey _previewCaptureKey = GlobalKey();

  bool _hasCandidate = false;
  List<Nikke?> _candidateSquad = [null];
  List<String?>? _pendingCandidateIds;

  void _updateCandidateSquadSlots() {
    final active = _candidateSquad.whereType<Nikke>().toList();
    if (active.length < 10) {
      _candidateSquad = [...active, null];
    } else {
      _candidateSquad = active.sublist(0, 10);
    }
  }

  /// 스쿼드 5개 × 슬롯 5개
  /// _squads[스쿼드번호][슬롯번호] = Nikke?
  final List<List<Nikke?>> _squads = List.generate(
    3,
    (_) => List<Nikke?>.filled(5, null, growable: false),
  );

  final List<String> _squadNames = List.generate(3, (_) => '전격');
  static const _kSquadNamesKey = 'union_deck_builder_squad_elements';

  /// 지금 니케를 채워넣을 대상 스쿼드 인덱스 (0 = Squad 1)
  int _activeSquadIndex = 0;

  @override
  void initState() {
    super.initState();

    // 첫 프레임 이후에 저장된 덱 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDeckFromLocal();
      await _loadSyncedProfile(); // 👈 추가
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadSyncedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final openId = prefs.getString('last_synced_openid');
      if (openId != null && openId.isNotEmpty) {
        final profile = await DatabaseService().getCommanderProfile(openId);
        if (profile != null) {
          setState(() {
            _profileData = profile;
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to load synced profile in deck builder: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_restoredOnce) return;

    // Retrieve weakness element from route arguments if available
    final routeArgs = ModalRoute.of(context)?.settings.arguments as String?;
    if (routeArgs != null) {
      _weaknessElement = routeArgs;
    }

    final nikkeList = context.watch<NikkeProvider>().nikkeList;
    if (nikkeList.isEmpty) return;

    final mapById = {for (final n in nikkeList) n.id: n};

    setState(() {
      if (_pendingSquadsIds != null) {
        final restoredSquads = _pendingSquadsIds!
            .map((squadIds) =>
                squadIds.map((id) => id == null ? null : mapById[id]).toList())
            .toList();

        for (int s = 0; s < _squads.length && s < restoredSquads.length; s++) {
          for (int i = 0;
              i < _squads[s].length && i < restoredSquads[s].length;
              i++) {
            _squads[s][i] = restoredSquads[s][i];
          }
        }
      }

      if (_pendingCandidateIds != null) {
        _candidateSquad = _pendingCandidateIds!
            .map((id) => id == null ? null : mapById[id])
            .toList();
        _updateCandidateSquadSlots();
      }
    });

    _restoredOnce = true;
    _pendingSquadsIds = null;
    _pendingCandidateIds = null;
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
      if (squadIndex == 5) {
        _candidateSquad = [null];
      } else {
        for (int i = 0; i < _squads[squadIndex].length; i++) {
          _squads[squadIndex][i] = null;
        }
      }
    });
    _saveDeckToLocal();
  }

  void _addCandidate() {
    setState(() {
      _hasCandidate = true;
      _candidateSquad = [null];
    });
    _saveDeckToLocal();
  }

  void _removeCandidate() {
    setState(() {
      _hasCandidate = false;
      _candidateSquad = [null];
    });
    _saveDeckToLocal();
  }

  Future<Uint8List?> _capturePreview() async {
    try {
      final boundary = _previewCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('캡쳐 실패')));
      }
      return;
    }

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download',
            'mimir_deck_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await ImageGallerySaver.saveImage(bytes,
          name: "mimir_deck_${DateTime.now().millisecondsSinceEpoch}");
      if (mounted) {}
    }
  }

  Future<void> _publishDeckToLibrary() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      // Show login suggestion dialog
      showDialog(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1F26) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text("로그인 필요", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "구성하신 5개 스쿼드 덱을 공유 라이브러리에 게시하려면 로그인이 필요합니다. 지금 소셜 로그인 화면으로 이동하시겠습니까?",
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("취소", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Pop AlertDialog
                  Navigator.pushNamed(context, LoginScreen.routeName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text("로그인하러 가기"),
              ),
            ],
          );
        },
      );
      return;
    }

    // User is logged in, show elegant Publish Form Dialog
    final titleController = TextEditingController(
        text: "${authProvider.nickname}의 시즌 37 솔로레이드 공략 덱");
    final descController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1F26) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text("공유 라이브러리에 덱 등록",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text(
                    "작성자: ${authProvider.nickname}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                primary: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "현재 구성하신 5개 스쿼드(총 25인)를 공유 덱 라이브러리에 실시간으로 업로드합니다. 보스 공략을 위한 상세한 설명을 함께 작성해 보세요!",
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey, height: 1.5),
                      ),
                      const SizedBox(height: 18),

                      // Title textfield
                      const Text("덱 제목",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.orange)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "사령관님만의 덱 제목을 입력해 주세요",
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF14151B)
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.orange, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description textfield
                      const Text("상세 설명 및 공략 팁",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.orange)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText:
                              "크라운/클루드 등 핵심 메인 딜러 연동과 5개 스쿼드 배치 팁을 꼼꼼히 채워주시면 다른 사령관님들께 큰 도움이 됩니다!",
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF14151B)
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.orange, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("덱 제목을 입력해 주세요.")),
                      );
                      return;
                    }

                    // Extract squad ids
                    final List<List<String?>> squadIds = _squads
                        .map((squad) => squad.map((n) => n?.id).toList())
                        .toList();

                    final newDeck = SharedDeck(
                      id: "shared_${DateTime.now().millisecondsSinceEpoch}",
                      authorName: authProvider.nickname!,
                      title: title,
                      description: descController.text.trim(),
                      season: "SEASON 37",
                      squadsNikkeIds: squadIds,
                      upvotes: 0,
                      downvotes: 0,
                      createdAt: DateTime.now(),
                    );

                    // Add to repository
                    MockDeckRepository.addDeck(newDeck);

                    // If running on Web, automatically copy generated code to clipboard
                    if (kIsWeb) {
                      final code = generateDeckCode(newDeck);
                      Clipboard.setData(ClipboardData(text: code));
                      debugPrint("\n====================================");
                      debugPrint(
                          "Generated Deck Code for mock_deck_repository.dart:");
                      debugPrint(code);
                      debugPrint("====================================\n");
                    }

                    // Pop AlertDialog
                    Navigator.pop(context);

                    // Pop Preview Dialog as well!
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(kIsWeb
                                  ? "공유 완료! 웹 환경이므로 덱 소스 코드(Dart)가 클립보드에 복사되었습니다. mock_deck_repository.dart의 _decks 배열 안에 붙여넣어 주세요!"
                                  : "공유 라이브러리에 덱을 성공적으로 등록했습니다!"),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: kIsWeb ? 8 : 4),
                        behavior: SnackBarBehavior.floating,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    );

                    // Redirect to Deck Library
                    Navigator.pushNamed(context, DeckLibraryScreen.routeName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("등록하기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _copyToClipboard() async {
    final bytes = await _capturePreview();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('캡쳐 실패')));
      }
      return;
    }

    try {
      await Pasteboard.writeImage(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('클립보드 복사 실패: $e')));
      }
    }
  }

  Widget _buildFiveSquadsShareCanvas() {
    const double w = 600;

    return Container(
      width: w,
      color: const Color(0xFF090A0F),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...List.generate(_squads.length, (index) {
            final isLastWithoutCandidate =
                !_hasCandidate && index == _squads.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLastWithoutCandidate ? 0 : 8),
              child: _ShareSquadPanel(
                title: _squadNames[index],
                isActive: index == _activeSquadIndex,
                slots: _squads[index],
                weaknessElement: _squadNames[index],
              ),
            );
          }),
          if (_hasCandidate)
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: _ShareSquadPanel(
                title: '후보 덱',
                isActive: _activeSquadIndex == 5,
                slots: _candidateSquad,
                weaknessElement: '전격', // 후보 덱은 기본 속성
                isCandidate: true,
              ),
            ),
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
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogW,
                  maxHeight: dialogH,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '미리보기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: Colors.black),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.grey),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: RepaintBoundary(
                            key: _previewCaptureKey,
                            child: _buildFiveSquadsShareCanvas(),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.content_copy,
                                color: Colors.orange),
                            label: const Text('클립보드 복사',
                                style: TextStyle(color: Colors.orange)),
                            onPressed: _copyToClipboard,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon:
                                const Icon(Icons.download, color: Colors.white),
                            label: const Text('이미지 다운로드',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _downloadPreview,
                          ),
                          if (AuthProvider.showLoginFeatures) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_upload_rounded,
                                  color: Colors.white),
                              label: const Text('라이브러리에 공유',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _publishDeckToLibrary,
                            ),
                          ],
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
      final current = squadIndex == 5
          ? _candidateSquad[slotIndex]
          : _squads[squadIndex][slotIndex];

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
        for (int i = 0; i < _candidateSquad.length; i++) {
          if (_candidateSquad[i]?.id == selected.id) {
            _candidateSquad[i] = null;
          }
        }

        if (squadIndex == 5) {
          _candidateSquad[slotIndex] = selected;
          _updateCandidateSquadSlots();
        } else {
          _squads[squadIndex][slotIndex] = selected;
        }

        // 한 번 배치했으면 선택 해제
        _selectedNikkeId = null;

        //  배치가 끝났으니 시트 다시 열기 (모바일 UX 루프)
        _isNikkeSheetOpen = true;
      } else {
        if (current != null) {
          if (squadIndex == 5) {
            _candidateSquad[slotIndex] = null;
            _updateCandidateSquadSlots();
          } else {
            _squads[squadIndex][slotIndex] = null;
          }
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
      final fromNikke = fromSquadIndex == 5
          ? _candidateSquad[fromSlotIndex]
          : _squads[fromSquadIndex][fromSlotIndex];
      final toNikke = toSquadIndex == 5
          ? _candidateSquad[toSlotIndex]
          : _squads[toSquadIndex][toSlotIndex];

      if (fromSquadIndex == 5) {
        _candidateSquad[fromSlotIndex] = toNikke;
      } else {
        _squads[fromSquadIndex][fromSlotIndex] = toNikke;
      }

      if (toSquadIndex == 5) {
        _candidateSquad[toSlotIndex] = fromNikke;
      } else {
        _squads[toSquadIndex][toSlotIndex] = fromNikke;
      }

      if (fromSquadIndex == 5 || toSquadIndex == 5) {
        _updateCandidateSquadSlots();
      }
    });

    _saveDeckToLocal();
  }

// 저장 키
  static const _kSquadsKey = 'union_deck_builder_squads';
  static const _kActiveKey = 'union_deck_builder_activeSquadIndex';

  Future<void> _saveDeckToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSquadNamesKey, jsonEncode(_squadNames));

    // Nikke? -> id(String?) 로 변환해서 저장
    final squadsAsIds =
        _squads.map((squad) => squad.map((n) => n?.id).toList()).toList();

    await prefs.setString(_kSquadsKey, jsonEncode(squadsAsIds));
    await prefs.setInt(_kActiveKey, _activeSquadIndex);

    // 후보 덱 저장
    await prefs.setBool('union_deck_builder_has_candidate', _hasCandidate);
    final candidateAsIds = _candidateSquad.map((n) => n?.id).toList();
    await prefs.setString(
        'union_deck_builder_candidate_squad', jsonEncode(candidateAsIds));

    // 약점 속성 저장
    if (_weaknessElement != null) {
      await prefs.setString('deck_builder_weakness_element', _weaknessElement!);
    }
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

    // 후보 덱 로드
    final savedHasCandidate = prefs.getBool('union_deck_builder_has_candidate');
    if (savedHasCandidate != null) {
      _hasCandidate = savedHasCandidate;
    }

    final rawCandidate = prefs.getString('union_deck_builder_candidate_squad');
    if (rawCandidate != null) {
      final decodedCandidate =
          (jsonDecode(rawCandidate) as List).cast<String?>();
      _pendingCandidateIds = decodedCandidate;
    }

    // 약점 속성 로드 (routeArgs 로 들어온 게 없을 때만)
    final savedWeakness = prefs.getString('deck_builder_weakness_element');
    if (savedWeakness != null && _weaknessElement == null) {
      _weaknessElement = savedWeakness;
    }

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
    _weaknessElement ??= '전격';

    // 각 니케가 몇 번 스쿼드에 배치되어 있는지 계산
    final Map<String, int> assignedSquadMap = {};
    for (int s = 0; s < _squads.length; s++) {
      for (final nikke in _squads[s]) {
        if (nikke != null) {
          assignedSquadMap[nikke.id] = s;
        }
      }
    }
    for (final nikke in _candidateSquad) {
      if (nikke != null) {
        assignedSquadMap[nikke.id] = 5;
      }
    }

    final Map<String, Map<String, dynamic>> syncedCharsByName = {};
    if (_profileData != null && _profileData!['characters'] != null) {
      final chars = _profileData!['characters'] as List<dynamic>;
      for (final char in chars) {
        if (char is Map<String, dynamic>) {
          final nameCode = char['name_code'] as int? ?? 0;
          final String mappedName = BlablaMap.characterNames[nameCode] ?? '';
          if (mappedName.isNotEmpty) {
            syncedCharsByName[mappedName] = char;
          }
        }
      }
    }

    return Scaffold(
      drawer: const AppDrawer(activeRoute: UnionDeckBuilderScreen.routeName),
      appBar: AppBar(
        title: const Text(
          "덱 구성",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            tooltip: '덱 캡쳐',
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: () async {
              await _showFiveSquadsPreviewDialog();
            },
          ),
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
                                (auth.nickname != null &&
                                        auth.nickname!.isNotEmpty)
                                    ? auth.nickname!
                                        .substring(0, 1)
                                        .toUpperCase()
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
                      icon: const Icon(Icons.login_rounded,
                          size: 16, color: Colors.white),
                      label: const Text(
                        "로그인",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900; // 임계값은 취향대로

          if (isMobile) {
            // 📱 모바일 레이아웃
            return _buildMobileLayout(
                context, nikkeList, assignedSquadMap, syncedCharsByName);
          } else {
            // 💻 데스크탑 / 태블릿 레이아웃
            return _buildDesktopLayout(
                context, nikkeList, assignedSquadMap, syncedCharsByName);
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<Nikke> nikkeList,
    Map<String, int> assignedSquadMap,
    Map<String, Map<String, dynamic>> syncedCharacters,
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
                syncedCharacters: syncedCharacters,
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
                  hasCandidate: _hasCandidate,
                  candidateSquad: _candidateSquad,
                  onAddCandidate: _addCandidate,
                  onRemoveCandidate: _removeCandidate,
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
    Map<String, Map<String, dynamic>> syncedCharacters,
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
                    hasCandidate: _hasCandidate,
                    candidateSquad: _candidateSquad,
                    onAddCandidate: _addCandidate,
                    onRemoveCandidate: _removeCandidate,
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFE0E0E0),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '니케 목록 열기',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
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
                          syncedCharacters: syncedCharacters,
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
  final Map<String, Map<String, dynamic>> syncedCharacters; // 👈 추가
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
    this.syncedCharacters = const {}, // 👈 추가
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

    /// 정렬
    if (widget.syncedCharacters.isNotEmpty) {
      filtered.sort((a, b) {
        final aOwned = widget.syncedCharacters.containsKey(a.name);
        final bOwned = widget.syncedCharacters.containsKey(b.name);

        if (aOwned && !bOwned) return -1;
        if (!aOwned && bOwned) return 1;

        if (aOwned && bOwned) {
          final aChar = widget.syncedCharacters[a.name]!;
          final bChar = widget.syncedCharacters[b.name]!;
          final aPower = aChar['combat'] as int? ?? 0;
          final bPower = bChar['combat'] as int? ?? 0;
          final powerDiff = bPower.compareTo(aPower); // Descending
          if (powerDiff != 0) return powerDiff;
        }

        // Fallback: SSR → SR → R, then name
        final rankDiff = a.rank.sortValue.compareTo(b.rank.sortValue);
        if (rankDiff != 0) return rankDiff;
        return a.name.compareTo(b.name);
      });
    } else {
      /// 정렬 (SSR → SR → R, 동일 등급 내에서는 이름순)
      filtered.sort((a, b) {
        final rankDiff = a.rank.sortValue.compareTo(b.rank.sortValue);
        if (rankDiff != 0) return rankDiff;
        // 등급이 같으면 이름순으로
        return a.name.compareTo(b.name);
      });
    }

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
      filtered = filtered.where((n) {
        if (n.burst == BurstType.burst0) return true;
        return widget.burstFilters.contains(n.burst);
      }).toList();
    }

    // 속성 필터
    if (widget.elementFilters.isNotEmpty) {
      filtered = filtered.where((n) {
        if (n.id == 'rapi_red_hood' && widget.elementFilters.contains(ElementType.Iron)) return true;
        return widget.elementFilters.contains(n.element);
      }).toList();
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

                final bool isSynced = widget.syncedCharacters.isNotEmpty;
                final bool isNotOwned = isSynced &&
                    !widget.syncedCharacters.containsKey(nikke.name) &&
                    !nikke.isTemporary;

                final bool isSelected = !isAssigned &&
                    !isNotOwned &&
                    widget.selectedNikkeId == nikke.id;
                final bool isDimmed = isAssigned ||
                    isNotOwned ||
                    (widget.selectedNikkeId != null &&
                        widget.selectedNikkeId != nikke.id);

                final String? squadName = (squadIndex == null)
                    ? null
                    : (squadIndex == 5
                        ? '후보 덱'
                        : widget.squadNames[squadIndex]);

                final Map<String, dynamic>? syncedChar =
                    widget.syncedCharacters[nikke.name];

                final card = NikkeCard(
                  nikke: nikke,
                  onTap: () {
                    if (isAssigned || isNotOwned) return;
                    widget.onNikkeTap?.call(nikke);
                  },
                  isSelected: isSelected,
                  isDimmed: isDimmed,
                  assignedSquadIndex: squadIndex,
                  assignedSquadName: squadName,
                  isNotOwned: isNotOwned,
                );

                if (syncedChar != null) {
                  return NikkeHoverTooltip(
                    charData: syncedChar,
                    nikke: nikke,
                    child: card,
                  );
                } else {
                  return card;
                }
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
  final bool hasCandidate;
  final List<Nikke?> candidateSquad;
  final VoidCallback? onAddCandidate;
  final VoidCallback? onRemoveCandidate;

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
    required this.hasCandidate,
    required this.candidateSquad,
    this.onAddCandidate,
    this.onRemoveCandidate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        itemCount: squads.length + 1,
        itemBuilder: (context, index) {
          if (index == squads.length) {
            // 후보군 섹션
            if (hasCandidate) {
              return Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SquadCard(
                  name: '후보 덱',
                  isActive: activeSquadIndex == 5,
                  hasWarning: false,
                  slots: candidateSquad,
                  squadIndex: 5,
                  onHeaderTap: () => onHeaderTap?.call(5),
                  onSlotTap: (slotIndex) => onSlotTap?.call(5, slotIndex),
                  onSwapSlots: onSwapSlots,
                  onNameChanged: null, // 후보 덱은 이름 변경 필요 없음
                  onReset: () => onResetSquad?.call(5),
                  onDelete: onRemoveCandidate,
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Card(
                    elevation: 1,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E) // M2 1dp surface
                        : const Color(0xFFF0F4FA),
                    child: InkWell(
                      onTap: onAddCandidate,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          final slots = squads[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == squads.length - 1 ? 0 : 12),
            child: SquadCard(
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
            ),
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
  final VoidCallback? onDelete;
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
    this.onDelete,
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
  static const Map<String, String> _elementIconMap = {
    '전격': 'assets/icons/elements/icon-elements-Electric.webp',
    '철갑': 'assets/icons/elements/icon-elements-Iron.webp',
    '작열': 'assets/icons/elements/icon-elements-Fire.webp',
    '수냉': 'assets/icons/elements/icon-elements-Water.webp',
    '풍압': 'assets/icons/elements/icon-elements-Wind.webp',
  };

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ['전격', '철갑', '작열', '수냉', '풍압']
                              .contains(widget.name)
                          ? DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: widget.name,
                                isDense: true,
                                dropdownColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF2D2D2D)
                                    : Colors.white,
                                focusColor: Colors.transparent,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    widget.onNameChanged?.call(newValue);
                                  }
                                },
                                items: <String>[
                                  '전격',
                                  '철갑',
                                  '작열',
                                  '수냉',
                                  '풍압'
                                ].map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          _elementIconMap[value] ??
                                              'assets/icons/elements/icon-elements-Electric.webp',
                                          width: 18,
                                          height: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
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
                    const SizedBox(width: 8),
                    const Spacer(),
                    if (widget.hasWarning)
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 24),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: '후보군 제거',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onDelete,
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '스쿼드 초기화',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onReset,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 슬롯 5개 (기존 그대로)
            Column(
              children: [
                Row(
                  children: List.generate(5, (colIndex) {
                    if (colIndex < widget.slots.length) {
                      final nikke = widget.slots[colIndex];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _SquadSlot(
                            squadIndex: widget.squadIndex ?? 0,
                            slotIndex: colIndex,
                            displayIndex: colIndex + 1,
                            nikke: nikke,
                            onTap: widget.onSlotTap == null
                                ? null
                                : () => widget.onSlotTap!(colIndex),
                            onSwap: widget.onSwapSlots,
                          ),
                        ),
                      );
                    } else {
                      return const Expanded(child: SizedBox());
                    }
                  }),
                ),
                if (widget.slots.length > 5) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (colIndex) {
                      final actualIndex = colIndex + 5;
                      if (actualIndex < widget.slots.length) {
                        final nikke = widget.slots[actualIndex];
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: _SquadSlot(
                              squadIndex: widget.squadIndex ?? 0,
                              slotIndex: actualIndex,
                              displayIndex: actualIndex + 1,
                              nikke: nikke,
                              onTap: widget.onSlotTap == null
                                  ? null
                                  : () => widget.onSlotTap!(actualIndex),
                              onSwap: widget.onSwapSlots,
                            ),
                          ),
                        );
                      } else {
                        return const Expanded(child: SizedBox());
                      }
                    }),
                  ),
                ],
              ],
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
  final String weaknessElement;
  final bool isCandidate;

  const _ShareSquadPanel({
    required this.title,
    required this.isActive,
    required this.slots,
    required this.weaknessElement,
    this.isCandidate = false,
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
    final targetEnum =
        elementKoreanToEnum[weaknessElement] ?? ElementType.Electric;
    final bool hasWeaknessMatch =
        activeNikkes.any((n) => n.element == targetEnum);
    final bool hasCooldownReduction =
        activeNikkes.any((n) => n.ability.contains("버스트 쿨타임 감소"));

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
    if (activeNikkes.where((n) => n.ability.contains("지속데미지")).length >= 2) {
      dynamicTags.add("지속딜");
    }
    if (activeNikkes.where((n) => n.ability.contains("파츠")).length >= 2) {
      dynamicTags.add("파츠");
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
    final explosionCount =
        activeNikkes.where((n) => n.ability.contains("폭발데미지")).length;
    final rlCount =
        activeNikkes.where((n) => n.weaponType == WeaponType.RL).length;
    if (explosionCount >= 2 || (explosionCount >= 1 && rlCount >= 1)) {
      dynamicTags.add("폭발뎀");
    }

    final Map<String, String> elementIconMap = {
      '전격': 'assets/icons/elements/icon-elements-Electric.webp',
      '철갑': 'assets/icons/elements/icon-elements-Iron.webp',
      '작열': 'assets/icons/elements/icon-elements-Fire.webp',
      '수냉': 'assets/icons/elements/icon-elements-Water.webp',
      '풍압': 'assets/icons/elements/icon-elements-Wind.webp',
    };

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
            width: isCandidate ? 70 : 90,
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
                      child: Row(
                        children: [
                          if (elementIconMap.containsKey(title)) ...[
                            Image.asset(
                              elementIconMap[title]!,
                              width: 14,
                              height: 14,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isCandidate) ...[
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
              ],
            ),
          ),
          if (!isCandidate) ...[
            const SizedBox(width: 8),
            const _VerticalDottedLine(
              height: 110,
              color: Colors.white12,
              dashHeight: 3,
              gap: 3,
              strokeWidth: 1,
            ),
            const SizedBox(width: 12),
          ] else ...[
            const SizedBox(width: 41),
          ],
          Expanded(
            child: isCandidate
                ? Column(
                    children: [
                      Row(
                        children: List.generate(5, (colIndex) {
                          if (colIndex < activeNikkes.length) {
                            final nikke = activeNikkes[colIndex];
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _ShareSlotThumb(
                                  nikke: nikke,
                                  displayIndex: colIndex + 1,
                                ),
                              ),
                            );
                          } else {
                            return const Expanded(child: SizedBox());
                          }
                        }),
                      ),
                      if (activeNikkes.length > 5) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(5, (colIndex) {
                            final actualIndex = colIndex + 5;
                            if (actualIndex < activeNikkes.length) {
                              final nikke = activeNikkes[actualIndex];
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: _ShareSlotThumb(
                                    nikke: nikke,
                                    displayIndex: actualIndex + 1,
                                  ),
                                ),
                              );
                            } else {
                              return const Expanded(child: SizedBox());
                            }
                          }),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: List.generate(slots.length, (i) {
                      final nikke = slots[i];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _ShareSlotThumb(
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

class _ShareSlotThumb extends StatelessWidget {
  final Nikke? nikke;
  final int displayIndex;
  const _ShareSlotThumb({required this.nikke, required this.displayIndex});

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

class _VerticalDottedLine extends StatelessWidget {
  final double height;
  final Color color;
  final double dashHeight;
  final double strokeWidth;
  final double gap;

  const _VerticalDottedLine({
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
      painter: _DottedLinePainter(
        color: color,
        dashHeight: dashHeight,
        strokeWidth: strokeWidth,
        gap: gap,
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double strokeWidth;
  final double gap;

  _DottedLinePainter({
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

// ---------------------------
// Hover Tooltip for Owned Nikkes
// ---------------------------
class NikkeHoverTooltip extends StatefulWidget {
  final Widget child;
  final Map<String, dynamic> charData;
  final Nikke nikke;

  const NikkeHoverTooltip({
    super.key,
    required this.child,
    required this.charData,
    required this.nikke,
  });

  @override
  State<NikkeHoverTooltip> createState() => _NikkeHoverTooltipState();
}

class _NikkeHoverTooltipState extends State<NikkeHoverTooltip> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _showTooltip() {
    _hideTooltip();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 320,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(10, 0),
            child: IgnorePointer(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF14151B), // Sleek dark mode background
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800, width: 1),
                  ),
                  child: _buildTooltipContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltipContent() {
    final char = widget.charData;
    final name = widget.nikke.name;
    final grade = char['grade'] as int? ?? 0;
    final core = char['core'] as int? ?? 0;
    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    final skill1 = skills['skill1'] ?? 1;
    final skill2 = skills['skill2'] ?? 1;
    final burst = skills['burst'] ?? 1;
    final favItem = char['favoriteItem'] as Map<String, dynamic>?;
    final equips = char['equipment'] as List<dynamic>? ?? [];

    final String stars = '★' * grade;

    final Map<String, dynamic> equipsBySlot = {
      for (final eq in equips) eq['slot'] as String: eq
    };

    String getEquipLevel(String slot) {
      final eq = equipsBySlot[slot];
      if (eq == null) return '+0';
      final int level = eq['level'] as int? ?? 0;
      return '+$level';
    }

    final Map<String, List<int>> groups = {};
    for (final eq in equips) {
      final options = eq['overloadOptions'] as List<dynamic>? ?? [];
      for (final optId in options) {
        final int id = optId as int? ?? 0;
        if (id == 0) continue;
        final String optName = BlablaMap.getOptionName(id);
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

    overloadSummaries.sort((a, b) {
      final int countCompare = b['count'].compareTo(a['count']);
      if (countCompare != 0) return countCompare;
      return b['sumPercent'].compareTo(a['sumPercent']);
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (stars.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                stars,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                ),
              ),
            ],
            if (core > 0) ...[
              const SizedBox(width: 4),
              Text(
                '(+$core)',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$skill1 / $skill2 / $burst',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '스킬 레벨',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (favItem != null) _buildTooltipCollectionPill(favItem),
          ],
        ),
        const Divider(color: Colors.grey, height: 24),
        const Text(
          '장비 강화',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  children: [
                    const TextSpan(text: '머리 '),
                    TextSpan(
                      text: getEquipLevel('head'),
                      style: const TextStyle(
                        color: Color(0xFFF06292),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' / 몸통 '),
                    TextSpan(
                      text: getEquipLevel('torso'),
                      style: const TextStyle(
                        color: Color(0xFFF06292),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  children: [
                    const TextSpan(text: '장갑 '),
                    TextSpan(
                      text: getEquipLevel('arm'),
                      style: const TextStyle(
                        color: Color(0xFFF06292),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' / 신발 '),
                    TextSpan(
                      text: getEquipLevel('leg'),
                      style: const TextStyle(
                        color: Color(0xFFF06292),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (overloadSummaries.isNotEmpty) ...[
          const Divider(color: Colors.grey, height: 24),
          ...overloadSummaries.map((info) {
            final String optName = info['name'];
            final double sumPercent = info['sumPercent'];
            final int maxLevel = info['maxLevel'] as int? ?? 0;
            final bool isLevel15 = maxLevel == 15;
            final bool isHighLevel = maxLevel >= 12;

            final Color boxBgColor =
                isLevel15 ? const Color(0xFF232323) : const Color(0xFFEAEAEA);

            final Color labelColor =
                isLevel15 ? const Color(0xFFFFFFFF) : const Color(0xFF333333);

            final Color valueColor =
                isHighLevel ? const Color(0xFF049EE7) : const Color(0xFF7F8C8D);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3.0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '+${sumPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildTooltipCollectionPill(Map<String, dynamic> favItem) {
    final int tid = favItem['tid'] as int? ?? 0;
    final int level = favItem['level'] as int? ?? 0;
    final bool isFavorite = tid >= 200000;

    if (isFavorite) {
      final increasedLevel = level + 1;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _showTooltip(),
        onExit: (_) => _hideTooltip(),
        child: widget.child,
      ),
    );
  }
}
