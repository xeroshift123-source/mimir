import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/login.dart';
import 'package:mimir/widgets/ein_ada_form.dart';
import 'package:mimir/widgets/nayuta_helm_form.dart';
import 'package:mimir/widgets/scarlet_lib_form.dart';
import 'package:mimir/widgets/app_drawer.dart';

class CalculateListScreen extends StatefulWidget {
  static const routeName = '/calculate-list';

  const CalculateListScreen({super.key});

  @override
  State<CalculateListScreen> createState() => _CalculateListScreenState();
}

class _CalculateListScreenState extends State<CalculateListScreen> {
  int? _expandedIndex;

  final List<Map<String, dynamic>> _calculators = [
    {
      "title": "아인-에이다 계산기",
      "subtitle": "애장품 미란다 버프 시뮬레이션",
      "icon": "assets/icons/elements/icon-elements-Electric.webp",
      "content": const EinAdaCalculatorForm(),
    },
    {
      "title": "나유타-헬름 계산기",
      "subtitle": "애장품 미란다 버프 시뮬레이션",
      "icon": "assets/icons/elements/icon-elements-Wind.webp",
      "content": const NayutaHelmCalculatorForm(),
    },
    {
      "title": "흑련-리버렐리오 계산기",
      "subtitle": "리버렐리오 1스킬 차속 버프 시뮬레이션",
      "icon": "assets/icons/elements/icon-elements-Wind.webp",
      "content": const ScarletLibCalculatorForm(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(activeRoute: '/calculate-list'),
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          "전용 계산기 목록",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _calculators.length,
            itemBuilder: (context, index) {
              final item = _calculators[index];
              final isExpanded = _expandedIndex == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpanded
                        ? Colors.orange
                        : (isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (isExpanded)
                      BoxShadow(
                        color: Colors.orange.withOpacity(isDark ? 0.2 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                  ],
                ),
                child: Column(
                  children: [
                    // --- 헤더 부분 ---
                    InkWell(
                      onTap: () => setState(
                          () => _expandedIndex = isExpanded ? null : index),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? Colors.orange
                                    : (isDark
                                        ? const Color(0xFF242424)
                                        : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.asset(
                                item['icon'],
                                width: 40,
                                height: 40,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['subtitle'],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            // 아이콘 회전 애니메이션
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(Icons.expand_more,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- 펼쳐지는 내용 (애니메이션 적용) ---
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: item['content'],
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
