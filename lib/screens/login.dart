import 'package:flutter/material.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const orange = Color(0xFFF57C00);

  final TextEditingController _nicknameController = TextEditingController();
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  bool _isLoading = false;
  bool _showNicknameSetup = false;
  bool _isGoogleButtonHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSocialLogin() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    try {
      final signedIn = await authProvider.login('google', customNickname: '');
      if (!mounted) return;

      if (!signedIn) {
        setState(() => _isLoading = false);
        return;
      }

      if (authProvider.hasProfileSyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google 로그인은 완료됐지만 프로필 동기화에 실패했습니다. 잠시 후 새로고침해 주세요.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      if (authProvider.hasCompletedProfile) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${authProvider.nickname} 사령관님, 다시 오신 것을 환영합니다!',
            ),
            backgroundColor: orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _isLoading = false;
        _nicknameController.clear();
        _showNicknameSetup = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_loginErrorMessage(error));
    }
  }

  String _loginErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('popup-closed-by-user') ||
        message.contains('cancelled-popup-request')) {
      return 'Google 로그인이 취소되었습니다.';
    }
    if (message.contains('popup-blocked')) {
      return '브라우저에서 로그인 팝업을 허용해 주세요.';
    }
    return 'Google 로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  }

  Future<void> _handleNicknameSubmit() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showError('사령관 닉네임을 입력해 주세요.');
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.updateNickname(nickname);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
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
          backgroundColor: orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('닉네임 저장에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _Background(isDark: isDark)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;

                return Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 40,
                          vertical: compact ? 16 : 36,
                        ),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: _buildCard(
                                isDark: isDark,
                                compact: compact,
                                authProvider: authProvider,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _BackButton(isDark: isDark),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required bool compact,
    required AuthProvider authProvider,
  }) {
    final primaryText = isDark ? Colors.white : const Color(0xFF1D1E22);
    final secondaryText =
        isDark ? const Color(0xFFAAADB5) : const Color(0xFF696C73);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(minHeight: compact ? 560 : 680),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 26 : 72,
        vertical: compact ? 42 : 64,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1D21) : Colors.white,
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.96),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.12),
            blurRadius: 44,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: orange.withOpacity(isDark ? 0.06 : 0.035),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              'assets/logo.png',
              width: compact ? 92 : 118,
              height: compact ? 92 : 118,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          Text(
            'MIMIR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryText,
              fontSize: compact ? 32 : 42,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: compact ? 8 : 13,
            ),
          ),
          const SizedBox(height: 18),
          _BrandSubtitle(color: secondaryText),
          SizedBox(height: compact ? 38 : 54),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _showNicknameSetup
                ? _buildNicknameForm(
                    key: const ValueKey('nickname'),
                    isDark: isDark,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  )
                : _buildLoginForm(
                    key: const ValueKey('login'),
                    isDark: isDark,
                    authProvider: authProvider,
                    secondaryText: secondaryText,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm({
    required Key key,
    required bool isDark,
    required AuthProvider authProvider,
    required Color secondaryText,
  }) {
    final canLogin = !_isLoading && authProvider.isInitialized;

    return Column(
      key: key,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isGoogleButtonHovered = true),
          onExit: (_) => setState(() => _isGoogleButtonHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 470, minHeight: 66),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFF7F7F8) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _isGoogleButtonHovered ? orange : const Color(0xFFD7D9DE),
                width: _isGoogleButtonHovered ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isGoogleButtonHovered
                      ? orange.withOpacity(0.14)
                      : Colors.black.withOpacity(0.09),
                  blurRadius: _isGoogleButtonHovered ? 22 : 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: canLogin ? _handleSocialLogin : null,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: orange,
                          ),
                        )
                      else
                        const _GoogleMark(),
                      const SizedBox(width: 18),
                      Flexible(
                        child: Text(
                          _isLoading ? 'Google 인증 중...' : 'Google 계정으로 로그인',
                          style: TextStyle(
                            color: canLogin || _isLoading
                                ? const Color(0xFF1E1F23)
                                : const Color(0xFF9A9CA2),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _AuthStatus(authProvider: authProvider),
        const SizedBox(height: 14),
        Text(
          'Google 계정으로 안전하게 로그인합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryText, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildNicknameForm({
    required Key key,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '사령관 닉네임 등록',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryText,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'MIMIR에서 사용할 닉네임을 설정해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryText, fontSize: 13.5),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _nicknameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isLoading) _handleNicknameSubmit();
          },
          style: TextStyle(color: primaryText, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '사령관 닉네임',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: orange),
            filled: true,
            fillColor:
                isDark ? const Color(0xFF15161A) : const Color(0xFFF8F8F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : const Color(0xFFD9DBDF),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: orange, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 58,
          child: FilledButton(
            onPressed: _isLoading ? null : _handleNicknameSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'MIMIR 시작하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF111215), Color(0xFF1B1713)]
              : const [Color(0xFFF7F8FA), Color(0xFFF0F1F3)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -170,
            right: -120,
            child: _AmbientCircle(
              size: 430,
              color: _LoginScreenState.orange.withOpacity(isDark ? 0.12 : 0.07),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -160,
            child: _AmbientCircle(
              size: 500,
              color:
                  _LoginScreenState.orange.withOpacity(isDark ? 0.08 : 0.045),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark
          ? Colors.black.withOpacity(0.18)
          : Colors.white.withOpacity(0.7),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: '뒤로 가기',
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : const Color(0xFF303136),
        ),
      ),
    );
  }
}

class _AmbientCircle extends StatelessWidget {
  const _AmbientCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _BrandSubtitle extends StatelessWidget {
  const _BrandSubtitle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 24, height: 2, color: _LoginScreenState.orange),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            '니케 덱 빌딩 도우미',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(width: 24, height: 2, color: _LoginScreenState.orange),
      ],
    );
  }
}

class _AuthStatus extends StatelessWidget {
  const _AuthStatus({required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    final hasError = authProvider.initializationError != null;
    final isReady = authProvider.isInitialized;
    final color = hasError
        ? Colors.red.shade600
        : isReady
            ? Colors.green.shade600
            : _LoginScreenState.orange;
    final label = hasError
        ? 'Firebase 연결을 확인해 주세요'
        : isReady
            ? '안전한 로그인 준비 완료'
            : '로그인 준비 중';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFFEA4335),
          Color(0xFFFBBC05),
          Color(0xFF34A853),
        ],
      ).createShader(bounds),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
