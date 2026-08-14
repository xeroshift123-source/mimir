import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/services/database_service.dart';
import 'package:mimir/widgets/app_drawer.dart';
import 'package:mimir/widgets/blabla_binding_dialog.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  static const String routeName = '/account';

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _boundNikkeProfile;
  String? _boundOpenId;

  @override
  void initState() {
    super.initState();
    _loadBoundAccount();
  }

  Future<void> _loadBoundAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      String? openId;

      if (auth.userId != null && auth.userId!.isNotEmpty) {
        try {
          final userDoc = await DatabaseService().getUserDoc(auth.userId!);
          openId = userDoc?['openId'] as String?;
        } catch (_) {}
      }

      // Fallback to local SharedPreferences backup if Firestore doc has no openId yet
      if (openId == null || openId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        openId = prefs.getString('auth_bound_openid');
      }

      if (openId != null && openId.isNotEmpty) {
        _boundOpenId = openId;
        final profile = await DatabaseService().getCommanderProfile(openId);
        setState(() {
          _boundNikkeProfile = profile;
        });
      }
    } catch (e) {
      debugPrint("Error loading bound account: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleUnbind() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("계정 연동 해제"),
        content: const Text("현재 1:1 연동된 니케 계정과의 매핑을 해제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("연동 해제"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null && _boundOpenId != null) {
        await DatabaseService().unbindBlablaAccount(auth.userId!, _boundOpenId!);
        setState(() {
          _boundNikkeProfile = null;
          _boundOpenId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("계정 연동이 해제되었습니다.")),
          );
        }
      }
    }
  }

  Future<void> _showEditNicknameDialog(AuthProvider auth) async {
    final controller = TextEditingController(text: auth.nickname ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.orange),
                  SizedBox(width: 8),
                  Text("지휘관 닉네임 변경",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "MIMIR 플랫폼에서 표시될 고유 닉네임을 설정합니다.\n(다른 지휘관님이 사용 중인 닉네임으로는 변경할 수 없습니다)",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "새 지휘관 닉네임",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        errorText: errorMessage,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "닉네임을 입력해 주세요.";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text("취소"),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newNick = controller.text.trim();
                          if (newNick == auth.nickname) {
                            Navigator.pop(dialogCtx);
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          final isAvailable = await DatabaseService()
                              .isNicknameAvailable(newNick,
                                  currentUid: auth.userId);

                          if (!isAvailable) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = "❌ 이미 다른 지휘관님이 사용 중인 닉네임입니다.";
                            });
                            return;
                          }

                          await auth.updateNickname(newNick);
                          if (auth.userId != null) {
                            await DatabaseService().saveUserProfile({
                              'uid': auth.userId,
                              'nickname': newNick,
                            });
                          }

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "닉네임이 '$newNick'(으)로 성공적으로 변경되었습니다!"),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("변경 저장"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("마이페이지 & 계정 관리"),
      ),
      drawer: const AppDrawer(activeRoute: AccountScreen.routeName),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Google Social Account Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F202B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.orange.shade100,
                        backgroundImage: auth.profileImageUrl != null && auth.profileImageUrl!.startsWith('http')
                            ? NetworkImage(auth.profileImageUrl!)
                            : null,
                        child: auth.profileImageUrl == null || !auth.profileImageUrl!.startsWith('http')
                            ? const Icon(Icons.person, size: 32, color: Colors.orange)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  auth.nickname ?? "지휘관",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _showEditNicknameDialog(auth),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.edit_note_rounded,
                                        size: 22, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.isLoggedIn ? "Google 계정 로그인 중" : "비로그인 상태",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (auth.isLoggedIn)
                        OutlinedButton.icon(
                          onPressed: () async {
                            await auth.logout();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text("로그아웃"),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Nikke Account 1:1 Binding Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "연동된 인게임 니케 계정",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (_boundNikkeProfile == null)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => BlablaBindingDialog(
                              onBound: _loadBoundAccount,
                            ),
                          );
                        },
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text("1:1 계정 연동하기"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_boundNikkeProfile != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1F28) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.orange.withOpacity(0.35)
                            : Colors.orange.withOpacity(0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.deepOrange],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepOrange.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: _buildServerIcon(
                                _boundNikkeProfile!['server'] as String? ?? '한국',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _boundNikkeProfile!['nickname'] as String? ?? '알 수 없음',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.green.withOpacity(0.35), width: 1),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text(
                                              "1:1 인증 완료",
                                              style: TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14151D) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoColumn("서버", _boundNikkeProfile!['server'] as String? ?? '한국', isDark),
                              Container(width: 1, height: 28, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                              _buildInfoColumn("유니온", _boundNikkeProfile!['union'] as String? ?? '없음', isDark),
                              Container(width: 1, height: 28, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                              _buildInfoColumn("싱크로 레벨", "Lv.${_boundNikkeProfile!['synchroLevel'] ?? 0}", isDark, isHighlight: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _handleUnbind,
                              icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.redAccent),
                              label: const Text("연동 해제", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14151D) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.link_off_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          "연동된 인게임 니케 계정이 없습니다.",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "블라블라링크 URL을 1:1 연동하면 '새로고침' 한 번으로 최신 니케가 동기화됩니다.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => BlablaBindingDialog(
                                onBound: _loadBoundAccount,
                              ),
                            );
                          },
                          icon: const Icon(Icons.verified_rounded, size: 16),
                          label: const Text("지금 1:1 계정 연동하기"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
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
    );
  }

  Widget _buildInfoColumn(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? Colors.orange
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildServerIcon(String serverStr) {
    final s = serverStr.toLowerCase().trim();
    String assetPath;

    if (s.contains('한국') || s.contains('kr') || s.contains('korea')) {
      assetPath = 'assets/icons/server/KR.png';
    } else if (s.contains('일본') || s.contains('jp') || s.contains('japan')) {
      assetPath = 'assets/icons/server/JP.png';
    } else if (s.contains('북미') || s.contains('na') || s.contains('us')) {
      assetPath = 'assets/icons/server/NA.png';
    } else {
      // 글로벌(Global) 및 기타 서버
      assetPath = 'assets/icons/server/GB.png';
    }

    return Image.asset(
      assetPath,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.public, color: Colors.white, size: 26);
      },
    );
  }
}
