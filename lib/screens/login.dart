import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  
  // 💡 Defer nickname setup until successful Google Sign-In
  bool _showNicknameSetup = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSocialLogin(String provider) async {
    setState(() {
      _isLoading = true;
    });

    // Simulate standard smooth OAuth callback loading delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    // Call login with empty nickname to authenticate first
    await authProvider.login(provider, customNickname: '');

    setState(() {
      _isLoading = false;
      // Prefill controller with the standard default generated name or Google name
      _nicknameController.text = authProvider.nickname ?? '';
      _showNicknameSetup = true; // Switch view to post-login Nickname Setup!
    });
  }

  Future<void> _handleNicknameSubmit() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final enteredName = _nicknameController.text.trim();
    if (enteredName.isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text("사령관 닉네임을 입력해 주세요."),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    await authProvider.updateNickname(enteredName);

    setState(() {
      _isLoading = false;
    });

    // Beautiful snackbar
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '${authProvider.nickname} 사령관님, 환영합니다!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // pop screen
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showNicknameSetup ? "사령관 등록" : "소셜 로그인",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 🎨 Premium Background with elegant glowing shapes
          Container(
            width: double.infinity,
            height: double.infinity,
            color: isDark ? const Color(0xFF0D0E12) : const Color(0xFFF5F5F7),
          ),
          if (isDark) ...[
            // Glowing neon orange ambient light
            Positioned(
              top: -size.height * 0.1,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.2,
              right: -size.width * 0.1,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],

          // 📐 Center Form
          Center(
            child: SingleChildScrollView(
              primary: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1F26).withOpacity(0.7)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? Colors.orange.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(isDark ? 0.08 : 0.03),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(32),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Logo icon representation
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.orange,
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Icon(
                                        _showNicknameSetup ? Icons.person : Icons.security,
                                        size: 36,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  if (!_showNicknameSetup) ...[
                                    // STEP 1: Google Authentication View
                                    Text(
                                      "MIMIR PLATFORM",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Google 계정으로 편리하게 로그인하여\n사령관님들께 강력한 덱을 공유해 보세요!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // 🎨 Premium Segmented Control for Authentication Mode
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF14151B) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildSegment(
                                              title: "시뮬레이션 모드 (권장)",
                                              isActive: !context.watch<AuthProvider>().useRealFirebaseMode,
                                              onTap: () {
                                                context.read<AuthProvider>().setRealFirebaseMode(false);
                                              },
                                            ),
                                            _buildSegment(
                                              title: "Firebase 실시간 연동",
                                              isActive: context.watch<AuthProvider>().useRealFirebaseMode,
                                              onTap: () {
                                                context.read<AuthProvider>().setRealFirebaseMode(true);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: context.watch<AuthProvider>().isRealAuthActive
                                              ? Colors.green.withOpacity(0.12)
                                              : Colors.orange.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: context.watch<AuthProvider>().isRealAuthActive
                                                ? Colors.green
                                                : Colors.orange,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: context.watch<AuthProvider>().isRealAuthActive
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              context.watch<AuthProvider>().isRealAuthActive
                                                  ? "Firebase 백엔드 실시간 연결됨"
                                                  : "하이브리드 시뮬레이션 모드 활성",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: context.watch<AuthProvider>().isRealAuthActive
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Divider(height: 32, thickness: 1),
                                    const SizedBox(height: 8),

                                    if (_isLoading) ...[
                                      Center(
                                        child: Column(
                                          children: [
                                            const CircularProgressIndicator(color: Colors.orange),
                                            const SizedBox(height: 16),
                                            Text(
                                              "Google 인증을 진행하고 있습니다...",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      // Only Google login button
                                      _buildSocialButton(
                                        title: "Google 계정으로 로그인",
                                        icon: Icons.g_mobiledata,
                                        iconColor: const Color(0xFFEA4335),
                                        color: isDark ? const Color(0xFFF5F5F7) : Colors.white,
                                        textColor: Colors.black87,
                                        border: Border.all(color: Colors.grey.shade300),
                                        onTap: () => _handleSocialLogin('google'),
                                      ),
                                    ],
                                  ] else ...[
                                    // STEP 2: Deferred Nickname Registration View
                                    const Text(
                                      "사령관 닉네임 등록",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "구글 인증 성공! MIMIR 플랫폼에서 활약할\n사령관님의 고유 닉네임을 설정해 주세요.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    // Nickname Input field
                                    Text(
                                      "사령관 닉네임 설정",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _nicknameController,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.person, color: Colors.orange),
                                        hintText: "사령관 닉네임을 채워주세요",
                                        hintStyle: TextStyle(
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                          fontSize: 13,
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF14151B).withOpacity(0.8)
                                            : Colors.grey.shade50,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Colors.orange,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Divider(height: 32, thickness: 1),
                                    const SizedBox(height: 8),

                                    if (_isLoading) ...[
                                      const Center(child: CircularProgressIndicator(color: Colors.orange)),
                                    ] else ...[
                                      // Setup confirmation button
                                      _buildSocialButton(
                                        title: "MIMIR 시작하기",
                                        icon: Icons.rocket_launch_rounded,
                                        color: Colors.orange,
                                        textColor: Colors.white,
                                        onTap: _handleNicknameSubmit,
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Color color,
    required Color textColor,
    BoxBorder? border,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: iconColor ?? textColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegment({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}
