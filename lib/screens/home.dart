import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/screens/calculate_list.dart';
import 'package:mimir/screens/deck_builder.dart';
import 'package:mimir/screens/union_deck_builder.dart';
import 'package:mimir/screens/login.dart';
import 'package:mimir/screens/sync_screen.dart';
import 'package:mimir/screens/my_nikke_screen.dart';
import 'package:mimir/providers/theme_provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'package:mimir/widgets/app_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late final PageController _raidPageController = PageController(
      initialPage: raidHistory.length - 1, viewportFraction: 1.0);

  @override
  void dispose() {
    _raidPageController.dispose();
    super.dispose();
  }

  bool _isHoveringRaid = false;

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

  Widget _buildMenuButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      bool isOutlined = false}) {
    if (isOutlined) {
      return SizedBox(
        height: 56,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 20),
          label: Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
  }

  // ✅ 레이드 요약 카드 위젯
  Widget _buildRaidSummaryCard(BuildContext context, RaidInfo raid) {
    final isDark = context.watch<ThemeProvider>().isDark;

    if (raid.type == RaidType.union) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                if (boss.keyword != null && boss.keyword!.isNotEmpty)
                                  Wrap(
                                    spacing: 4,
                                    alignment: WrapAlignment.end,
                                    children: boss.keyword!.map((kw) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(16),
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
                        }).toList(),
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
      constraints: const BoxConstraints(maxWidth: 400),
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
                    if (raid.keyword != null && raid.keyword!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
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
                          children: raid.keyword!.map((kw) {
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
                    ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(activeRoute: '/'),
      appBar: AppBar(
        title: const Text(
          "니케 덱 빌딩 도우미 MIMIR!",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Colors.white,
            ),
            tooltip: '테마 전환',
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
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
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoveringRaid = true),
                  onExit: (_) => setState(() => _isHoveringRaid = false),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
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
                                  if (_raidPageController
                                      .position.haveDimensions) {
                                    page = _raidPageController.page ?? page;
                                  } else {
                                    page = _raidPageController.initialPage
                                        .toDouble();
                                  }
                                  double diff = (page - index).abs();
                                  double scale =
                                      (1 - (diff * 0.15)).clamp(0.85, 1.0);
                                  double opacity =
                                      (1 - (diff * 0.5)).clamp(0.4, 1.0);

                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0),
                                  child: _buildRaidSummaryCard(
                                      context, raidHistory[index]),
                                ),
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
                                      duration:
                                          const Duration(milliseconds: 400),
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
                                      duration:
                                          const Duration(milliseconds: 400),
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
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      _buildMenuButton(
                        context,
                        title: "솔로 레이드 덱 구성",
                        icon: Icons.dashboard_customize,
                        color: Colors.orange,
                        onTap: () => _showWeaknessDialog(context,
                            initialWeakness:
                                raidHistory[_currentRaidPage].weakness),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuButton(
                        context,
                        title: "유니온 레이드 덱 구성",
                        icon: Icons.group_work,
                        color: Colors.orange.shade700,
                        onTap: () {
                          final currentRaid = raidHistory[_currentRaidPage];
                          final unionRaid = currentRaid.type == RaidType.union 
                              ? currentRaid 
                              : raidHistory.firstWhere((r) => r.type == RaidType.union);
                          Navigator.pushNamed(
                            context, 
                            UnionDeckBuilderScreen.routeName,
                            arguments: unionRaid,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuButton(
                        context,
                        title: "솔레 금서고 바로가기",
                        icon: Icons.history,
                        color: Colors.deepOrange,
                        onTap: () async {
                          final Uri url = Uri.parse('https://soloraidhistory.vercel.app/');
                          if (!await launchUrl(url)) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('링크를 열 수 없습니다.'),
                                    backgroundColor: Colors.orange),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuButton(
                        context,
                        title: "전투 정보 동기화",
                        icon: Icons.sync_rounded,
                        color: Colors.blueAccent,
                        onTap: () =>
                            Navigator.pushNamed(context, SyncScreen.routeName),
                        isOutlined: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context,
                              title: "계산기",
                              icon: Icons.calculate,
                              color: Colors.teal,
                              onTap: () => _openCalculator(context),
                              isOutlined: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMenuButton(
                              context,
                              title: "내 니케 정보",
                              icon: Icons.person_search,
                              color: Colors.purple,
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                if (!context.mounted) return;
                                final savedOpenId =
                                    prefs.getString('last_synced_openid');
                                if (savedOpenId != null &&
                                    savedOpenId.isNotEmpty) {
                                  Navigator.pushNamed(
                                      context, MyNikkeScreen.routeName,
                                      arguments: savedOpenId);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("먼저 블라블라링크 프로필 동기화를 진행해 주세요."),
                                        backgroundColor: Colors.orange),
                                  );
                                  Navigator.pushNamed(
                                      context, SyncScreen.routeName);
                                }
                              },
                              isOutlined: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const AppFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
