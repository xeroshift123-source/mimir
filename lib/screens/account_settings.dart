import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/screens/sync_screen.dart';
import 'package:mimir/screens/recap_screen.dart';
import 'package:mimir/services/database_service.dart';
import 'package:mimir/utils/safe_network_image_provider.dart';
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
  String? _selectingOpenId;
  String? _selectedOpenId;
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
      final selectedOpenId = await _database.getSelectedCommanderOpenId(uid);
      if (!mounted) return;
      setState(() {
        _linkedCommanders = accounts;
        _selectedOpenId = selectedOpenId;
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

  Future<void> _selectCommander(LinkedCommanderAccount account) async {
    final uid = context.read<AuthProvider>().userId;
    if (uid == null || uid.isEmpty || _selectedOpenId == account.openId) return;

    setState(() => _selectingOpenId = account.openId);
    try {
      await _database.selectCommanderForUser(uid, account.openId);
      if (!mounted) return;
      setState(() => _selectedOpenId = account.openId);
      _showMessage('${account.nickname}을(를) 표시 계정으로 선택했습니다.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('표시 계정 변경에 실패했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _selectingOpenId = null);
    }
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
                        selectedOpenId: _selectedOpenId,
                        selectingOpenId: _selectingOpenId,
                        unlinkingOpenId: _unlinkingOpenId,
                        error: _linkError,
                        onAdd: _openLinkScreen,
                        onSelect: _selectCommander,
                        onUnlink: _unlinkCommander,
                        onRecap: (account) {
                          HapticFeedback.mediumImpact();
                          Navigator.pushNamed(
                            context,
                            RecapScreen.routeName,
                            arguments: account.openId,
                          );
                        },
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
                    ? Image(
                        image: SafeNetworkImageProvider(auth.profileImageUrl!),
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
    required this.selectedOpenId,
    required this.selectingOpenId,
    required this.unlinkingOpenId,
    required this.error,
    required this.onAdd,
    required this.onSelect,
    required this.onUnlink,
    required this.onRecap,
    required this.onRetry,
  });

  final Color secondary;
  final bool loading;
  final List<LinkedCommanderAccount> accounts;
  final String? selectedOpenId;
  final String? selectingOpenId;
  final String? unlinkingOpenId;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<LinkedCommanderAccount> onSelect;
  final ValueChanged<LinkedCommanderAccount> onUnlink;
  final ValueChanged<LinkedCommanderAccount> onRecap;
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
            const SizedBox(height: 7),
            Text(
              '계정을 선택하면 내 니케 정보에 해당 지휘관이 표시됩니다.',
              style: TextStyle(color: secondary, fontSize: 12, height: 1.4),
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
                _LinkedCommanderCard(
                  account: account,
                  secondary: secondary,
                  selected: selectedOpenId == account.openId,
                  selecting: selectingOpenId == account.openId,
                  unlinking: unlinkingOpenId == account.openId,
                  actionsEnabled:
                      unlinkingOpenId == null && selectingOpenId == null,
                  onSelect: () => onSelect(account),
                  onUnlink: () => onUnlink(account),
                  onRecap: () => onRecap(account),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: unlinkingOpenId == null && selectingOpenId == null
                    ? onAdd
                    : null,
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

class _LinkedCommanderCard extends StatelessWidget {
  const _LinkedCommanderCard({
    required this.account,
    required this.secondary,
    required this.selected,
    required this.selecting,
    required this.unlinking,
    required this.actionsEnabled,
    required this.onSelect,
    required this.onUnlink,
    required this.onRecap,
  });

  final LinkedCommanderAccount account;
  final Color secondary;
  final bool selected;
  final bool selecting;
  final bool unlinking;
  final bool actionsEnabled;
  final VoidCallback onSelect;
  final VoidCallback onUnlink;
  final VoidCallback onRecap;

  String get _serverSymbol {
    if (account.server.contains('한국')) return '🇰🇷';
    if (account.server.contains('일본')) return '🇯🇵';
    if (account.server.contains('글로벌')) return '🌐';
    if (account.server.contains('동남아')) return '🌏';
    return '🏳️';
  }

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor.withOpacity(0.18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(selected ? 0.1 : 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(selected ? 0.72 : 0.18),
          width: selected ? 1.6 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.09),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: InkWell(
              onTap: actionsEnabled && !selected ? onSelect : null,
              onLongPress: actionsEnabled ? onRecap : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _serverSymbol,
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  account.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (selecting) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                ),
                              ] else if (selected) ...[
                                const SizedBox(width: 7),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${account.server} 서버',
                              style: TextStyle(
                                color: secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: divider),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed: actionsEnabled ? onUnlink : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: unlinking
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      )
                    : const Icon(Icons.link_off_rounded, size: 19),
                label: const Text(
                  '연동 해제',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
