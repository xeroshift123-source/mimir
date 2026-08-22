import 'package:flutter/material.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/account_settings.dart';
import 'package:mimir/screens/login.dart';
import 'package:provider/provider.dart';

enum _AccountAction { settings, logout }

class AuthAccountButton extends StatelessWidget {
  const AuthAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthProvider.showLoginFeatures) {
      return const SizedBox.shrink();
    }

    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, LoginScreen.routeName),
          icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
          label: const Text(
            '로그인',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<_AccountAction>(
      tooltip: '${auth.nickname ?? '지휘관'} 계정 메뉴',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 250),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.35),
        ),
      ),
      elevation: 10,
      onSelected: (action) => _handleAction(context, auth, action),
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          height: 58,
          child: Row(
            children: [
              _ProfileAvatar(auth: auth, radius: 18),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.nickname ?? '지휘관',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Google 계정',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<_AccountAction>(
          value: _AccountAction.settings,
          height: 46,
          child: Row(
            children: [
              Icon(Icons.manage_accounts_outlined, size: 20),
              SizedBox(width: 12),
              Text('계정 설정'),
            ],
          ),
        ),
        const PopupMenuItem<_AccountAction>(
          value: _AccountAction.logout,
          height: 46,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
              SizedBox(width: 12),
              Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: _ProfileAvatar(auth: auth, radius: 16)),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    AuthProvider auth,
    _AccountAction action,
  ) async {
    switch (action) {
      case _AccountAction.settings:
        await Navigator.pushNamed(context, AccountSettingsScreen.routeName);
        return;
      case _AccountAction.logout:
        await auth.logout();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃되었습니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.auth, required this.radius});

  final AuthProvider auth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = (auth.nickname?.trim().isNotEmpty ?? false)
        ? auth.nickname!.trim().substring(0, 1).toUpperCase()
        : 'M';
    final photoUrl = auth.profileImageUrl;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white, Colors.orangeAccent],
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.orange,
        child: ClipOval(
          child: photoUrl != null && photoUrl.startsWith('http')
              ? Image.network(
                  photoUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _Initial(initial: initial, fontSize: radius * 0.72),
                )
              : _Initial(initial: initial, fontSize: radius * 0.72),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.fontSize});

  final String initial;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
