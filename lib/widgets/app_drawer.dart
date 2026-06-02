import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/providers/theme_provider.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/home.dart';
import 'package:mimir/screens/deck_builder.dart';
import 'package:mimir/screens/deck_library.dart';
import 'package:mimir/screens/calculate_list.dart';
import 'package:mimir/screens/login.dart';
import 'package:mimir/screens/sync_screen.dart';
import 'package:mimir/screens/my_nikke_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatelessWidget {
  final String activeRoute;

  const AppDrawer({super.key, required this.activeRoute});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);
    final headerColor = isDark ? const Color(0xFF1E1E1E) : Colors.orange;

    return Drawer(
      backgroundColor: scaffoldBg,
      child: Column(
        children: [
          // Elegant Drawer Header matching the Orange Theme & User Profile State
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            color: headerColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "M",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "MIMIR",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    // Small App version or status
                    Text(
                      "V1.0",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "니케 덱 빌딩 & 아카이브 플랫폼",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (AuthProvider.showLoginFeatures) ...[
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),

                  // 👤 User Authentication Profile Block
                  authProvider.isLoggedIn
                      ? Row(
                          children: [
                            // Radiant profile avatar with glowing border
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.orange, Colors.redAccent, Colors.purpleAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF121212),
                                child: Icon(
                                  authProvider.loginProvider == 'discord'
                                      ? Icons.sports_esports
                                      : authProvider.loginProvider == 'google'
                                          ? Icons.g_mobiledata
                                          : Icons.apple,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authProvider.nickname!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user,
                                        size: 11,
                                        color: Colors.orange.shade300,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${authProvider.loginProvider!.toUpperCase()} 로그인됨',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                              tooltip: "로그아웃",
                              onPressed: () {
                                authProvider.logout();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("로그아웃 되었습니다."),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.0,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context); // Close Drawer
                                Navigator.pushNamed(context, LoginScreen.routeName);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.login_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "소셜 계정 로그인",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            "덱 공유 및 추천 투표 활성화",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white60,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ],
            ),
          ),
          
          // Drawer Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  title: "홈 화면 (Home)",
                  route: "/",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.dashboard_customize_outlined,
                  activeIcon: Icons.dashboard_customize,
                  title: "덱 빌더 (Deck Builder)",
                  route: DeckBuilderScreen.routeName,
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != DeckBuilderScreen.routeName) {
                      Navigator.pushNamed(context, DeckBuilderScreen.routeName);
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.auto_awesome_motion_outlined,
                  activeIcon: Icons.auto_awesome_motion,
                  title: "덱 라이브러리 (Library)",
                  route: DeckLibraryScreen.routeName,
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != DeckLibraryScreen.routeName) {
                      Navigator.pushNamed(context, DeckLibraryScreen.routeName);
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.calculate_outlined,
                  activeIcon: Icons.calculate,
                  title: "조합 계산기 (Calculators)",
                  route: CalculateListScreen.routeName,
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != CalculateListScreen.routeName) {
                      Navigator.pushNamed(context, CalculateListScreen.routeName);
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.sync_rounded,
                  activeIcon: Icons.sync_rounded,
                  title: "프로필 동기화 (Sync Profile)",
                  route: SyncScreen.routeName,
                  onTap: () {
                    Navigator.pop(context);
                    if (activeRoute != SyncScreen.routeName) {
                      Navigator.pushNamed(context, SyncScreen.routeName);
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.person_search_outlined,
                  activeIcon: Icons.person_search,
                  title: "내 니케 정보 (My Nikkes)",
                  route: MyNikkeScreen.routeName,
                  onTap: () async {
                    Navigator.pop(context);
                    if (activeRoute != MyNikkeScreen.routeName) {
                      final prefs = await SharedPreferences.getInstance();
                      if (!context.mounted) return;
                      final savedOpenId = prefs.getString('last_synced_openid');
                      if (savedOpenId != null && savedOpenId.isNotEmpty) {
                        Navigator.pushNamed(
                          context,
                          MyNikkeScreen.routeName,
                          arguments: savedOpenId,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("먼저 블라블라링크 프로필 동기화를 진행해 주세요."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        Navigator.pushNamed(context, SyncScreen.routeName);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Theme switch at footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDark ? "다크 모드 활성" : "라이트 모드 활성",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Switch(
                  activeColor: Colors.orange,
                  value: isDark,
                  onChanged: (val) {
                    context.read<ThemeProvider>().toggleTheme();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String route,
    required VoidCallback onTap,
  }) {
    final bool isSelected = activeRoute == route;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.withOpacity(0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.orange : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? Colors.orange : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
            color: isSelected 
                ? (isDark ? Colors.white : Colors.black) 
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
