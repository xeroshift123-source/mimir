import 'package:flutter/material.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/sync_screen.dart';
import 'package:mimir/services/database_service.dart';
import 'package:provider/provider.dart';

class AccountSettingsScreen extends StatefulWidget {
  static const routeName = '/account';

  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final DatabaseService _database = DatabaseService();

  bool _initialized = false;
  bool _saving = false;
  bool _loadingLink = true;
  List<LinkedCommanderAccount> _linkedCommanders = const [];
  String? _unlinkingOpenId;
  String? _linkError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    _nicknameController.text =
        context.read<AuthProvider>().nickname?.trim() ?? '';
    _initialized = true;
    _loadLinkedCommanders();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedCommanders() async {
    final uid = context.read<AuthProvider>().userId;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loadingLink = false);
      return;
    }

    setState(() {
      _loadingLink = true;
      _linkError = null;
    });

    try {
      final accounts = await _database.getLinkedCommanderAccounts(uid);
      if (!mounted) return;
      setState(() {
        _linkedCommanders = accounts;
        _loadingLink = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingLink = false;
        _linkError = '연동 정보를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _openLinkScreen() async {
    await Navigator.pushNamed(context, SyncScreen.routeName);
    if (mounted) await _loadLinkedCommanders();
  }

  Future<void> _unlinkCommander(LinkedCommanderAccount account) async {
    final uid = context.read<AuthProvider>().userId;
    if (uid == null || uid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('BLABLALINK 연동 해제'),
        content: Text(
          '${account.nickname}과의 연동을 해제할까요?\n다른 연동 계정은 그대로 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('연동 해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _unlinkingOpenId = account.openId);
    try {
      await _database.unlinkCommanderFromUser(uid, account.openId);
      if (!mounted) return;
      await _loadLinkedCommanders();
      if (!mounted) return;
      _showMessage('${account.nickname} 연동을 해제했습니다.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('연동 해제에 실패했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _unlinkingOpenId = null);
    }
  }

  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showMessage('지휘관명을 입력해 주세요.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateNickname(nickname);
      if (!mounted) return;
      _showMessage('지휘관명이 변경되었습니다.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('지휘관명 변경에 실패했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '계정 설정',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: auth.isLoggedIn
          ? Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeader(auth: auth, secondary: secondary),
                      const SizedBox(height: 20),
                      _NicknameCard(
                        controller: _nicknameController,
                        secondary: secondary,
                        saving: _saving,
                        onSave: _saveNickname,
                      ),
                      const SizedBox(height: 16),
                      _BlablaLinkCard(
                        secondary: secondary,
                        loading: _loadingLink,
                        accounts: _linkedCommanders,
                        unlinkingOpenId: _unlinkingOpenId,
                        error: _linkError,
                        onAdd: _openLinkScreen,
                        onUnlink: _unlinkCommander,
                        onRetry: _loadLinkedCommanders,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('로그인이 필요한 화면입니다.'),
              ),
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.auth, required this.secondary});

  final AuthProvider auth;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final initial = (auth.nickname?.isNotEmpty ?? false)
        ? auth.nickname!.substring(0, 1).toUpperCase()
        : 'M';
    final hasPhoto = auth.profileImageUrl?.startsWith('http') == true;

    return Card(
      color: Colors.orange.withOpacity(0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.orange,
              child: ClipOval(
                child: hasPhoto
                    ? Image.network(
                        auth.profileImageUrl!,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _ProfileInitial(initial: initial),
                      )
                    : _ProfileInitial(initial: initial),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.nickname ?? '지휘관',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    auth.email ?? 'Google 계정',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInitial extends StatelessWidget {
  const _ProfileInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 68,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _NicknameCard extends StatelessWidget {
  const _NicknameCard({
    required this.controller,
    required this.secondary,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final Color secondary;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '지휘관명',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'MIMIR에서 표시되는 이름입니다.',
              style: TextStyle(color: secondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!saving) onSave();
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: Colors.orange,
                ),
                hintText: '지휘관명',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color: Colors.orange,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '변경사항 저장',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlablaLinkCard extends StatelessWidget {
  const _BlablaLinkCard({
    required this.secondary,
    required this.loading,
    required this.accounts,
    required this.unlinkingOpenId,
    required this.error,
    required this.onAdd,
    required this.onUnlink,
    required this.onRetry,
  });

  final Color secondary;
  final bool loading;
  final List<LinkedCommanderAccount> accounts;
  final String? unlinkingOpenId;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<LinkedCommanderAccount> onUnlink;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.link_rounded, color: Colors.orange, size: 22),
                SizedBox(width: 9),
                Text(
                  'BLABLALINK 연동',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              )
            else if (error != null) ...[
              Text(error!, style: TextStyle(color: secondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 불러오기'),
              ),
            ] else ...[
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '연동된 지휘관이 없습니다. BLABLALINK 계정을 추가해 주세요.',
                    style: TextStyle(color: secondary, height: 1.45),
                  ),
                ),
              for (final account in accounts) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.shield_outlined),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '연동된 지휘관',
                              style: TextStyle(color: secondary, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              account.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      unlinkingOpenId == null ? () => onUnlink(account) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: unlinkingOpenId == account.openId
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_off_rounded),
                  label: const Text('연동 해제'),
                ),
                const SizedBox(height: 14),
              ],
              FilledButton.icon(
                onPressed: unlinkingOpenId == null ? onAdd : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.add_link_rounded),
                label: const Text(
                  '계정 추가',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
