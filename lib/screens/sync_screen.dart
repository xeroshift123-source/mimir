import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'my_nikke_screen.dart';
import 'package:mimir/widgets/app_footer.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  static const String routeName = '/sync';

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  // Cloud Functions Endpoint
  final String _functionUrl = 'https://us-central1-nikke-mimir.cloudfunctions.net/scrapeNikkeProfile';

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('saved_sync_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _urlController.text = savedUrl;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    final enteredUrl = _urlController.text.trim();
    if (enteredUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("블라블라링크 프로필 URL을 입력해 주세요."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!enteredUrl.contains("blablalink.com") || !enteredUrl.contains("openid=")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("올바른 블라블라링크 프로필 URL 형식이 아닙니다.\n(?openid= 매개변수가 포함되어야 합니다)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "url": enteredUrl,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        // URL에서 openid 추출
        String? openId;
        try {
          final uri = Uri.parse(enteredUrl);
          openId = uri.queryParameters['openid'];
        } catch (e) {
          final match = RegExp(r'[?&]openid=([^&]+)').firstMatch(enteredUrl);
          if (match != null) {
            openId = match.group(1);
          }
        }

        if (openId != null && openId.isNotEmpty) {
          // 💡 backend와 동일하게 base64 디코딩 및 NULL 바이트 제거
          String resolvedOpenId = openId.trim();
          final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
          if (base64Pattern.hasMatch(resolvedOpenId) && resolvedOpenId.length % 4 == 0) {
            try {
              resolvedOpenId = utf8.decode(base64.decode(resolvedOpenId));
            } catch (_) {}
          }
          resolvedOpenId = resolvedOpenId.replaceAll(RegExp(r'\x00'), '').trim();

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_synced_openid', resolvedOpenId);
            await prefs.setString('saved_sync_url', enteredUrl);
          } catch (prefErr) {
            debugPrint("Failed to save openId to SharedPreferences: $prefErr");
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("동기화가 성공적으로 완료되었습니다! 🚀"),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacementNamed(
              context,
              MyNikkeScreen.routeName,
              arguments: resolvedOpenId,
            );
          }
        } else {
          throw Exception("프로필 URL에서 openid를 추출할 수 없습니다.");
        }
      } else {
        throw Exception(result['error'] ?? "서버 오류가 발생했습니다.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("동기화 실패: ${e.toString()}"),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          "블라블라링크 원클릭 동기화",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "지휘관 덱 동기화",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "블라블라링크의 프로필 정보를 Mimir와 동기화하여 소장품/애장품, 오버로드 덱 장비 정보를 한눈에 분석할 수 있습니다.",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ⚠️ 소유권 검증 안내 박스
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A1F10) : const Color(0xFFFFF9E6),
                      border: Border.all(
                        color: isDark ? Colors.orange.shade800 : Colors.orange.shade400,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "계정 소유권 확인 필수",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "타인의 덱 정보 무단 도용 및 조회를 차단하기 위해 본인 계정 인증을 진행합니다.\n"
                                "동기화 전, 블라블라링크 프로필의 [소개글(상태메시지)]을 반드시 '미미르만만세'로 수정해 주세요. 인증 완료 후에는 자유롭게 복구하셔도 됩니다.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🔗 URL 입력 필드
                  Text(
                    "블라블라링크 프로필 URL",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.link, color: Colors.orange),
                      hintText: "https://www.blablalink.com/user?openid=...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSync,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "동기화 시작하기",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 안내 카드
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.5) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "블라블라링크 프로필 URL 얻는 방법",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStep("1", "모바일 또는 PC 브라우저에서 공식 블라블라링크 홈페이지에 로그인합니다.", isDark),
                        _buildStep("2", "우측 상단 프로필 이미지 클릭 후 [마이페이지] 혹은 [프로필]에 진입합니다.", isDark),
                        _buildStep("3", "프로필 설정에서 소개글(상태메시지)을 '미미르만만세'로 변경 및 저장합니다.", isDark),
                        _buildStep("4", "주소창의 URL(openid 파라미터가 포함된 전체 주소)을 복사하여 위 필드에 입력합니다.", isDark),
                        _buildStep("5", "블라블라링크 설정에서 '내 정보 공개' 및 '캐릭터 정보 공개' 옵션이 활성화되어 있어야 동기화가 가능합니다.", isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String step, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}