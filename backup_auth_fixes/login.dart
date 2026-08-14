import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/services/database_service.dart';

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
  
  // Defer nickname setup until successful Google Sign-In
  bool _showNicknameSetup = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
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
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    String currentStep = "[Step 1: AuthProvider 참조]";
    try {
      currentStep = "[Step 1: AuthProvider 참조]";
      final authProvider = context.read<AuthProvider>();

      currentStep = "[Step 2: authProvider.login() 실행]";
      await authProvider.login(provider, customNickname: '');

      if (!mounted) return;

      currentStep = "[Step 3: isLoggedIn 상태 확인]";
      if (authProvider.isLoggedIn) {
        currentStep = "[Step 4: userId 조회 및 DatabaseService 연결]";
        final uid = authProvider.userId ?? '';
        final userDoc = await DatabaseService().getUserDoc(uid);

        currentStep = "[Step 5: SharedPreferences 닉네임 로드]";
        final prefs = await SharedPreferences.getInstance();
        final registeredNick = (userDoc != null && userDoc['nickname'] != null && userDoc['nickname'].toString().isNotEmpty)
            ? userDoc['nickname'].toString()
            : ((userDoc != null && userDoc['displayName'] != null && userDoc['displayName'].toString().isNotEmpty)
                ? userDoc['displayName'].toString()
                : prefs.getString('user_nickname'));

        currentStep = "[Step 6: 닉네임 검증 및 스킵 여부 확인]";
        if (registeredNick != null &&
            registeredNick.trim().isNotEmpty &&
            registeredNick.trim() != 'Commander' &&
            registeredNick.trim() != '지휘관') {
          final cleanNick = registeredNick.trim();
          await authProvider.updateNickname(cleanNick);
          await prefs.setString('user_nickname', cleanNick);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("로그인 성공! 환영합니다, $cleanNick 지휘관님!"),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }

        currentStep = "[Step 7: 신규 사용자 닉네임 설정 화면 표시]";
        setState(() {
          _nicknameController.text = authProvider.nickname ?? '';
          _showNicknameSetup = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("⚠️ Login error at $currentStep: $e\n$stackTrace");
      if (mounted) {
        final stackLines = stackTrace.toString().split('\n');
        final topTrace = stackLines
            .where((l) => l.contains('.dart') || l.contains('package:'))
            .take(3)
            .join('\n');
        final msg = e.toString().replaceAll('Exception: ', '');

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("🔍 로그인 디버그 진단 리포트"),
            content: SingleChildScrollView(
              child: SelectableText(
                "📌 발생 위치/단계:\n$currentStep\n\n"
                "📌 예외 종류:\n${e.runtimeType}\n\n"
                "📌 상세 메시지:\n$msg\n\n"
                "📌 스택 트레이스:\n${topTrace.isEmpty ? stackTrace.toString() : topTrace}",
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("닫기"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleNicknameSubmit() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final enteredName = _nicknameController.text.trim();
    if (enteredName.isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text("지휘관 닉네임을 입력해 주세요."),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final uid = authProvider.userId ?? '';

    // Check Nickname Uniqueness across all commanders
    final isAvailable = await DatabaseService()
        .isNicknameAvailable(enteredName, currentUid: uid);
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              "❌ '$enteredName'은(는) 이미 사용 중인 닉네임입니다. 다른 닉네임을 설정해 주세요."),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    await authProvider.updateNickname(enteredName);
    await DatabaseService().saveUserProfile({
      'uid': uid,
      'nickname': enteredName,
    });

    setState(() {
      _isLoading = false;
    });

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '${authProvider.nickname} 지휘관님, 환영합니다!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101116) : const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF191A22) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.orange.withOpacity(0.35)
                            : Colors.orange.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(isDark ? 0.12 : 0.06),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!_showNicknameSetup) ...[
                          // 1. Logo
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                width: 90,
                                height: 90,
                                color: Colors.orange,
                                child: const Icon(
                                  Icons.shield,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),

                          // 2. Title MIMIR with Orange accent hint
                          Text(
                            "M I M I R",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. Subtitle with Orange dash lines
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 16,
                                height: 1.5,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "니케 덱 빌딩 도우미",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 16,
                                height: 1.5,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 44),

                          // 4. Google Login Button with Orange border accent
                          if (_isLoading)
                            const SizedBox(
                              height: 52,
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.orange),
                              ),
                            )
                          else
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF22242E) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _handleSocialLogin('google'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(22, 22),
                                        painter: GoogleLogoPainter(),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        "구글 로그인",
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF2C2C2C),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          // STEP 2: Deferred Nickname Registration View
                          Text(
                            "지휘관 닉네임 설정",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "MIMIR 플랫폼에서 표시될\n지휘관님의 고유 닉네임을 설정해 주세요.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          TextField(
                            controller: _nicknameController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person, color: Colors.orange),
                              hintText: "지휘관 닉네임을 입력해 주세요",
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF121318) : const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                ),
                              ),
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
                          const SizedBox(height: 28),

                          if (_isLoading)
                            const Center(child: CircularProgressIndicator(color: Colors.orange))
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _handleNicknameSubmit,
                                child: const Text(
                                  "MIMIR 시작하기",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
}

/// Precise Vector Painter for Google 4-Color 'G' Logo
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = w * 0.22;
    final center = Offset(w / 2, h / 2);
    final radius = (w - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Blue arc (Right & Center bar)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -0.55, 1.8, false, bluePaint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - stroke / 2, radius + stroke / 2, stroke),
      barPaint,
    );

    // 2. Green arc (Bottom)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 1.25, 1.25, false, greenPaint);

    // 3. Yellow arc (Bottom-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 2.5, 1.0, false, yellowPaint);

    // 4. Red arc (Top)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 3.5, 1.5, false, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
