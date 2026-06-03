import 'package:flutter/material.dart';
import 'package:mimir/widgets/app_footer.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('이용약관'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle('서비스 이용약관 (MIMIR)', isDark),
                const SizedBox(height: 16),
                _buildParagraph(
                    "MIMIR (이하 '서비스')을 이용해 주셔서 감사합니다. 본 약관은 이용자가 서비스를 이용함에 있어 필요한 권리, 의무 및 책임사항 등을 규정함을 목적으로 합니다. 서비스를 이용함으로써 본 약관에 동의하는 것으로 간주됩니다.",
                    isDark),
                const SizedBox(height: 32),
                
                _buildSectionTitle('1. 서비스의 목적 및 성격', isDark),
                _buildParagraph(
                    "본 서비스는 '승리의 여신: 니케(NIKKE)' 이용자들의 덱 빌딩 및 스펙 시각화를 돕기 위해 개인이 비영리 목적으로 운영하는 비공식 팬 서비스입니다. 원작 개발사 및 퍼블리셔와 어떠한 공식적인 제휴나 관련이 없습니다.", isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('2. 지식재산권 및 저작권', isDark),
                _buildBullet('본 서비스 내에서 사용된 게임 관련 이미지, 텍스트, 리소스 등 모든 콘텐츠의 지식재산권 및 저작권은 원저작권자인 (주)시프트업(SHIFT UP Corp.) 및 Level Infinite에 귀속됩니다.', isDark),
                _buildBullet('본 서비스는 원저작권자의 권리를 침해할 의도가 없으며, 원저작권자의 요청이 있을 경우 즉시 관련 콘텐츠 삭제 또는 서비스 중단 등의 조치가 취해질 수 있습니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('3. 서비스 제공 및 중단', isDark),
                _buildParagraph('본 서비스는 타사 플랫폼(블라블라링크 등)의 공개 데이터를 연동하여 제공되므로, 해당 플랫폼의 정책 변경, 서버 상태 또는 게임 업데이트 등에 따라 서비스 이용이 사전 예고 없이 제한되거나 중단될 수 있습니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('4. 이용자의 의무 및 책임', isDark),
                _buildParagraph('이용자는 서비스를 이용할 때 다음 각 호의 행위를 하여서는 안 됩니다.', isDark),
                _buildBullet('비정상적인 방법(매크로, 봇 등)을 사용하여 서버에 과도한 부하를 유발하는 행위', isDark),
                _buildBullet('서비스의 버그나 취약점을 악용하는 행위', isDark),
                _buildBullet('타인의 계정 정보(openId 등)를 도용하여 부당한 이득을 취하거나 피해를 주는 행위', isDark),
                _buildParagraph('위와 같은 비정상적인 접근이 감지될 경우, 관리자는 사전 통보 없이 해당 이용자의 서비스 접근을 영구적으로 차단할 수 있습니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('5. 면책 조항 (Limitation of Liability)', isDark),
                _buildHighlightBox(
                  title: '[책임의 한계]',
                  content: "개발자는 무료로 제공되는 본 서비스의 완전성, 정확성, 안정성 및 영구성 등을 보증하지 않습니다. 서비스 이용으로 인해 발생하는 어떠한 직·간접적인 손해나 불이익, 데이터 손실 등에 대해서도 개발자는 법적 책임을 지지 않습니다. 모든 서비스 이용에 대한 책임은 이용자 본인에게 있습니다.",
                  isDark: isDark,
                ),
                const SizedBox(height: 32),

                _buildSectionTitle('6. 약관의 변경', isDark),
                _buildParagraph('개발자는 서비스 운영상 필요하다고 판단되는 경우 본 약관을 임의로 수정할 수 있으며, 변경된 약관은 서비스 내에 공지함으로써 효력이 발생합니다.', isDark),
                const SizedBox(height: 32),

                _buildParagraph('본 약관은 2026년 6월 3일부터 시행됩니다.', isDark),

                const SizedBox(height: 64),
                const AppFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildSectionTitle(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildBullet(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightBox({required String title, required String content, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
