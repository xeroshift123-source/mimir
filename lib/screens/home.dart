import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/screens/calculate_list.dart';
import 'package:mimir/screens/deck_builder.dart';
import 'package:mimir/screens/deck_library.dart';
import 'package:mimir/screens/union_deck_builder.dart';
import 'package:mimir/screens/sync_screen.dart';
import 'package:mimir/screens/my_nikke_screen.dart';
import 'package:mimir/providers/theme_provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/services/database_service.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'package:mimir/widgets/auth_account_button.dart';
import 'package:mimir/widgets/app_footer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/raid_info.dart';
import '../data/raid_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentRaidPage = raidHistory.length - 1;
  late final PageController _raidPageController =
      PageController(initialPage: _currentRaidPage);
  bool _isHoveringRaid = false;

  @override
  void dispose() {
    _raidPageController.dispose();
    super.dispose();
  }

  String _selectedWeakness = '수냉';

  static const Map<String, String> _elementIconMap = {
    '전격': 'assets/icons/elements/icon-elements-Electric.webp',
    '철갑': 'assets/icons/elements/icon-elements-Iron.webp',
    '작열': 'assets/icons/elements/icon-elements-Fire.webp',
    '수냉': 'assets/icons/elements/icon-elements-Water.webp',
    '풍압': 'assets/icons/elements/icon-elements-Wind.webp',
  };

  void _showWeaknessDialog(BuildContext context, {String? initialWeakness}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        String tempWeakness = initialWeakness ?? _selectedWeakness;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: const Text("공략 약점 속성 선택",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: DropdownButtonHideUnderline(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.orange.shade300, width: 1.5),
                  ),
                  child: DropdownButton<String>(
                    value: tempWeakness,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setStateDialog(() {
                          tempWeakness = newValue;
                        });
                        setState(() {
                          _selectedWeakness = newValue;
                        });
                      }
                    },
                    items: <String>['전격', '철갑', '작열', '수냉', '풍압']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Image.asset(_elementIconMap[value]!,
                                width: 20, height: 20),
                            const SizedBox(width: 10),
                            Text(value,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("취소", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamed(
                      context,
                      DeckBuilderScreen.routeName,
                      arguments: tempWeakness,
                    );
                  },
                  child: const Text("확인"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCalculator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalculateListScreen()),
    );
  }

  void _openDeckLibrary(BuildContext context) {
    Navigator.pushNamed(context, DeckLibraryScreen.routeName);
  }

  static const _orange = Color(0xFFFF8800);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? const Color(0xFF1E1E24) : Colors.white;
  Color get _border =>
      _isDark ? const Color(0xFF35353E) : const Color(0xFFEEEEF2);
  Color get _muted => _isDark ? Colors.grey.shade400 : const Color(0xFF858590);

  Widget _panel({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(_isDark ? .08 : .025),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Future<void> _openLink(String address) async {
    try {
      if (await launchUrl(Uri.parse(address))) return;
    } catch (_) {
      // Surface launch failures in the same way on every platform.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크를 열 수 없습니다.')),
    );
  }

  void _openUnionRaid() {
    final current = raidHistory[_currentRaidPage];
    final raid = current.type == RaidType.union
        ? current
        : raidHistory.lastWhere((raid) => raid.type == RaidType.union);
    Navigator.pushNamed(context, UnionDeckBuilderScreen.routeName,
        arguments: raid);
  }

  Future<void> _openMyNikke() async {
    final uid = context.read<AuthProvider>().userId;
    final openId = await DatabaseService().getSelectedCommanderOpenId(uid);
    if (!mounted) return;
    if (openId != null) {
      Navigator.pushNamed(context, MyNikkeScreen.routeName, arguments: openId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('먼저 BLABLALINK 계정을 연동해 주세요.'),
        backgroundColor: Colors.orange,
      ));
      Navigator.pushNamed(context, SyncScreen.routeName);
    }
  }

  Widget _buildRaidSummaryCard(BuildContext context, RaidInfo raid) {
    final isDark = context.watch<ThemeProvider>().isDark;

    if (raid.type == RaidType.union) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ 카드 상단 이미지
                if (raid.imagePath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      raid.imagePath,
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                            height: 100,
                            color: Colors.grey.shade800,
                            child: const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white, size: 50)));
                      },
                    ),
                  ),
                // ✅ 카드 본문
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "유니온 레이드",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.red.shade900.withOpacity(0.3)
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? Colors.red.shade700
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: Text(
                              raid.seasonName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.red.shade300
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: isDark ? Colors.grey.shade400 : Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            raid.period,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark ? Colors.grey.shade400 : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (raid.unionBosses != null)
                        ...raid.unionBosses!.map((boss) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Image.asset(
                                  _elementIconMap[boss.element] ??
                                      "assets/icons/elements/icon-elements-Electric.webp",
                                  width: 20,
                                  height: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    boss.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                                if (boss.keyword != null &&
                                    boss.keyword!.isNotEmpty)
                                  Wrap(
                                    spacing: 4,
                                    alignment: WrapAlignment.end,
                                    children: boss.keyword!.map((kw) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          "#$kw",
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              UnionDeckBuilderScreen.routeName,
                              arguments: raid,
                            );
                          },
                          icon:
                              const Icon(Icons.group_work, color: Colors.white),
                          label: const Text(
                            "덱 구성하기",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ 카드 상단 이미지 (카드 폭에 딱 맞게)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  raid.imagePath,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                        height: 140,
                        color: Colors.grey.shade800,
                        child: const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white, size: 50)));
                  },
                ),
              ),

              // ✅ 카드 본문
              Padding(
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          raid.typeLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.red.shade900.withOpacity(0.3)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? Colors.red.shade700
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Text(
                            raid.seasonName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      raid.bossName ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 18,
                          color: isDark ? Colors.grey.shade400 : Colors.black,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          raid.period,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _chip(
                          context: context,
                          iconPath: _elementIconMap[raid.bossElement ?? ''] ??
                              "assets/icons/elements/icon-elements-fire.webp",
                          title: "보스 속성",
                          value: raid.bossElement ?? '',
                        ),
                        _chip(
                          context: context,
                          iconPath: _elementIconMap[raid.weakness ?? ''] ??
                              "assets/icons/elements/icon-elements-Electric.webp",
                          title: "약점 속성",
                          value: raid.weakness ?? '',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: (raid.keyword ?? const <String>[]).map((kw) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "#$kw",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            DeckBuilderScreen.routeName,
                            arguments: raid,
                          );
                        },
                        icon:
                            const Icon(Icons.build_circle, color: Colors.white),
                        label: const Text(
                          "덱 구성하기",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chip({
    required BuildContext context,
    required String iconPath,
    required String title,
    required String value,
  }) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242424) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconPath,
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _raidCard() {
    return Column(children: [
      MouseRegion(
        onEnter: (_) => setState(() => _isHoveringRaid = true),
        onExit: (_) => setState(() => _isHoveringRaid = false),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: SizedBox(
                height: 495,
                child: PageView.builder(
                  controller: _raidPageController,
                  clipBehavior: Clip.none,
                  onPageChanged: (index) {
                    setState(() {
                      _currentRaidPage = index;
                    });
                  },
                  itemCount: raidHistory.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _raidPageController,
                      builder: (context, child) {
                        double page = index.toDouble();
                        if (_raidPageController.position.haveDimensions) {
                          page = _raidPageController.page ?? page;
                        } else {
                          page = _raidPageController.initialPage.toDouble();
                        }
                        double diff = (page - index).abs();
                        double scale = (1 - (diff * 0.15)).clamp(0.85, 1.0);
                        double opacity = (1 - (diff * 0.5)).clamp(0.4, 1.0);

                        return Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        );
                      },
                      child: _buildRaidSummaryCard(context, raidHistory[index]),
                    );
                  },
                ),
              ),
            ),
            // 좌측 화살표
            if (_currentRaidPage > 0)
              Positioned(
                left: 0,
                child: IgnorePointer(
                  ignoring: !_isHoveringRaid,
                  child: AnimatedOpacity(
                    opacity: _isHoveringRaid ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 32),
                        onPressed: () {
                          _raidPageController.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            // 우측 화살표
            if (_currentRaidPage < raidHistory.length - 1)
              Positioned(
                right: 0,
                child: IgnorePointer(
                  ignoring: !_isHoveringRaid,
                  child: AnimatedOpacity(
                    opacity: _isHoveringRaid ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white, size: 32),
                        onPressed: () {
                          _raidPageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(raidHistory.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentRaidPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentRaidPage == index
                  ? Colors.orange
                  : Colors.grey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _tile(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      bool external = false,
      bool tinted = false}) {
    return Material(
      color: tinted ? color.withOpacity(_isDark ? .12 : .035) : _surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: _border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withOpacity(.07),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tinted ? color : null)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12, color: _muted)),
                    ],
                  ])),
              const SizedBox(width: 6),
              Icon(
                  external
                      ? Icons.north_east_rounded
                      : Icons.chevron_right_rounded,
                  size: external ? 16 : 20,
                  color: _muted),
            ]),
          )),
    );
  }

  Widget _pair(Widget first, Widget second) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 440 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(children: [first, const SizedBox(height: 10), second]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ]);
    });
  }

  Widget _section(
      String title, String subtitle, IconData icon, List<Widget> children) {
    return _panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: _orange, size: 25),
                const SizedBox(width: 10),
                Flexible(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5))),
              ]),
              Text(subtitle, style: TextStyle(fontSize: 11, color: _muted)),
            ],
          )),
      ...children,
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isDark ? const Color(0xFF141418) : const Color(0xFFFAFAFC),
      drawer: const AppDrawer(activeRoute: '/'),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('니케 덱 빌딩 도우미 MIMIR!',
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        centerTitle: true,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '테마 전환',
            icon: Icon(
                _isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          const AuthAccountButton(),
        ],
      ),
      body: SafeArea(
          child: SingleChildScrollView(
              child: Center(
                  child: ConstrainedBox(
        // Keep the original 400px card width, plus 16px outer padding per side.
        constraints: const BoxConstraints(maxWidth: 432),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(children: [
              _raidCard(),
              const SizedBox(height: 18),
              _section(
                  '덱 구성 및 라이브러리', '나에게 맞는 덱을 구성해보세요', Icons.dashboard_rounded, [
                _pair(
                  _tile(
                      title: '솔로 레이드',
                      subtitle: '덱 구성',
                      icon: Icons.my_location_rounded,
                      color: Colors.redAccent,
                      onTap: () => _showWeaknessDialog(context,
                          initialWeakness:
                              raidHistory[_currentRaidPage].weakness)),
                  _tile(
                      title: '유니온 레이드',
                      subtitle: '덱 구성',
                      icon: Icons.groups_rounded,
                      color: _orange,
                      onTap: _openUnionRaid),
                ),
                const SizedBox(height: 10),
                _tile(
                    title: '덱 라이브러리',
                    subtitle: '다양한 덱을 살펴보세요',
                    icon: Icons.auto_stories_rounded,
                    color: _orange,
                    onTap: () => _openDeckLibrary(context)),
              ]),
              const SizedBox(height: 12),
              _section('바로가기', '자주 쓰는 기능을 한 번에', Icons.link_rounded, [
                _pair(
                  _tile(
                      title: '솔레 금서고',
                      subtitle: '바로가기',
                      icon: Icons.history_rounded,
                      color: Colors.indigo,
                      external: true,
                      onTap: () =>
                          _openLink('https://soloraidhistory.vercel.app/')),
                  _tile(
                      title: 'DILDORO',
                      subtitle: '딜량 계산기',
                      icon: Icons.calculate_outlined,
                      color: Colors.indigo,
                      external: true,
                      onTap: () => _openLink('https://dildoro.com')),
                ),
                const SizedBox(height: 10),
                _tile(
                    title: '계산기',
                    subtitle: '일반 계산기',
                    icon: Icons.calculate_rounded,
                    color: Colors.indigo,
                    onTap: () => _openCalculator(context)),
                const SizedBox(height: 10),
                _tile(
                    title: '전투 정보 동기화',
                    subtitle: 'BLABLALINK 계정 연동',
                    icon: Icons.sync_rounded,
                    color: Colors.blue,
                    onTap: () =>
                        Navigator.pushNamed(context, SyncScreen.routeName)),
              ]),
              const SizedBox(height: 12),
              _tile(
                  title: '내 니케 정보',
                  subtitle: '',
                  icon: Icons.person_rounded,
                  color: _isDark
                      ? Colors.purpleAccent.shade100
                      : Colors.deepPurple,
                  tinted: true,
                  onTap: _openMyNikke),
              const AppFooter(),
            ])),
      )))),
    );
  }
}
