import 'package:flutter/material.dart';
import 'package:mimir/screens/privacy_policy_screen.dart';
import 'package:mimir/screens/terms_of_service_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                thickness: 1,
              ),
              const SizedBox(height: 16),
              // 🔗 Links/Buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFooterLink(context, "개인정보처리방침", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  }),
                  _buildDivider(isDark),
                  _buildFooterLink(context, "이용약관", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsOfServiceScreen(),
                      ),
                    );
                  }),
                  _buildDivider(isDark),
                  _buildFooterLink(context, "문의 및 제보", () async {
                    final Uri url = Uri.parse('https://naver.me/G2Yyk5AK');
                    if (!await launchUrl(url)) {
                      debugPrint('Could not launch \$url');
                    }
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 📄 Disclaimer
              Text(
                "본 서비스는 개인이 운영하는 비영리 팬 서비스입니다. 승리의 여신: 니케(NIKKE)와 관련된 캐릭터, 이미지, 텍스트 등 모든 자산의 권리는 원저작권자인 (주)시프트업(SHIFT UP Corp.) 및 Level Infinite에 귀속됩니다. 본 서비스는 공식 서비스를 사칭하지 않으며 영리 목적으로 이용되지 않습니다. 원저작권자의 요청이 있을 시 본 서비스는 즉시 중단되거나 관련 리소스가 삭제될 수 있습니다.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              // 🏷️ Copyright
              Text(
                "Copyright © 2026 Mimir. All Rights Reserved.",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(
      BuildContext context, String text, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Text(
      "|",
      style: TextStyle(
        fontSize: 10,
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
      ),
    );
  }
}
