import 'package:flutter/material.dart';
import 'package:mimir/widgets/app_footer.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보 처리방침'),
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
                _buildTitle('개인정보 처리방침 (MIMIR 전용)', isDark),
                const SizedBox(height: 16),
                _buildParagraph(
                    "MIMIR (이하 '서비스')은(는) 정보주체의 자유와 권리 보호를 위해 「개인정보 보호법」 및 관계 법령을 준수하며, 안전하게 데이터를 관리하고 있습니다. 본 서비스는 디시인사이드 연동, 커뮤니티 채팅 등의 기능이 없는 순수 덱 빌딩 및 시각화 도우미로서, 다음과 같이 투명하게 개인정보를 처리합니다.",
                    isDark),
                const SizedBox(height: 32),
                
                _buildSectionTitle('1. 개인정보의 처리 목적', isDark),
                _buildParagraph(
                    "'서비스'는 별도의 회원가입 절차를 두지 않으며, 오직 다음의 목적을 위해서만 최소한의 정보를 처리합니다.", isDark),
                _buildBullet('서비스 제공: 연동된 지휘관의 게임 데이터(인게임 프로필 및 덱 스냅샷)를 가공하여 덱 빌딩, 장비 스펙 시각화, 전투력 분석 등의 콘텐츠 제공', isDark),
                _buildBullet('게임 계정 연동 및 소유권 검증: 블라블라링크(Blablalink)의 프로필 상태메시지 대조를 통한 본인 계정 소유 여부 확인 및 도용 방지', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('2. 처리하는 개인정보의 항목 및 수집 방법', isDark),
                _buildParagraph("'서비스'는 계정 연동 및 정보 제공을 위해 다음의 항목을 수집 및 처리하고 있습니다.", isDark),
                _buildBullet('식별 정보: 블라블라링크 ID (openId)', isDark),
                _buildBullet('기본 프로필: 인게임 닉네임, 서버 정보(한국/일본 등), 소속 유니온 및 유니온 레벨, 지휘관 레벨, 상태메시지(소유권 검증용)', isDark),
                _buildBullet('인게임 성장 지표: 대표 스쿼드 전투력, 싱크로 디바이스 레벨, 캠페인(일반/하드) 진행도, 타워 층수, 보유 니케 수', isDark),
                _buildBullet('보유 니케 상세 덱 정보: 캐릭터 이름 코드, 전투력, 레벨, 등급(한계돌파/코어강화 상태), 스킬 레벨, 호감도, 장착 큐브 정보, 오버로드 장비 세부 스펙(부위, 레벨, 티어, 옵션 등)', isDark),
                _buildBullet('시스템 생성 정보: 데이터 최종 갱신 일시(lastUpdatedAt)', isDark),
                const SizedBox(height: 16),
                _buildParagraph('수집 방법: 사용자가 블라블라링크 프로필 URL을 직접 입력하여 \'동기화 시작하기\'를 누를 때, 백엔드 시스템(Firebase Cloud Functions)이 공개 API를 통해 데이터를 조회하여 스냅샷 형태로 수집합니다.', isDark),
                const SizedBox(height: 16),
                _buildHighlightBox(
                  title: '[민감 정보 수집 절대 불가 안내]',
                  content: "본 '서비스'는 회원가입이나 로그인이 필요 없으며, 이용자의 성명, 연락처 등을 일절 수집하지 않습니다. 특히 게임 계정 접근에 필요한 세션 쿠키(game_token 등)나 인게임 비밀번호는 시스템 아키텍처 상 원천적으로 수집 및 보관하지 않으므로 안전하게 이용하실 수 있습니다.",
                  isDark: isDark,
                ),
                const SizedBox(height: 32),

                _buildSectionTitle('3. 개인정보의 처리 및 보유 기간', isDark),
                _buildParagraph('① \'서비스\'는 원칙적으로 개인정보 수집 및 이용 목적이 달성된 후(연동 해제 등)에는 해당 정보를 지체 없이 파기합니다.', isDark),
                _buildParagraph('② 수집된 데이터는 데이터베이스(Firebase Firestore)에 보관되며, 사용자가 앱/웹 내에서 \'연동 해제(데이터 삭제)\'를 요청할 때까지 보관 및 이용됩니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('4. 개인정보의 파기 절차 및 방법', isDark),
                _buildParagraph('① 파기 절차: 사용자가 연동 해제 또는 저장된 데이터의 삭제를 요청하는 경우, 해당 정보는 즉시 파기 절차에 들어갑니다.', isDark),
                _buildParagraph('② 파기 방법: 데이터베이스(Firestore)에 문서 ID(openId) 형태로 기록된 전자적 데이터는 복구 및 재생할 수 없는 기술적 방법을 사용하여 영구 삭제합니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('5. 개인정보 처리업무의 위탁', isDark),
                _buildParagraph('\'서비스\'는 원활한 데이터 저장 및 백엔드 운영 처리를 위하여 다음과 같이 개인정보 처리 업무를 클라우드 환경에 위탁하고 있습니다.', isDark),
                _buildBullet('위탁받는 자 (수탁자): Google LLC (Firebase)', isDark),
                _buildBullet('위탁하는 업무: 데이터베이스(Firestore) 보관 및 백엔드 데이터 동기화 함수(Cloud Functions) 실행 환경 제공', isDark),
                _buildBullet('안전성 확보: 위탁된 데이터는 Google Cloud의 철저한 보안 정책에 따라 암호화되어 안전하게 보관됩니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('6. 개인정보의 제3자 제공', isDark),
                _buildParagraph('\'서비스\'는 사용자의 데이터를 제1조(개인정보의 처리 목적)에서 명시한 범위 내에서만 처리하며, 사용자의 사전 동의 없이는 원칙적으로 외부(타 커뮤니티, 타 사이트 등)에 제공하지 않습니다. (단, 수사기관의 적법한 요구 등 법령에 명시된 경우는 제외)', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('7. 개인정보의 안전성 확보조치', isDark),
                _buildParagraph('\'서비스\'는 데이터의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다.', isDark),
                _buildBullet('기술적 조치: 클라이언트와 데이터베이스 간의 통신은 모두 암호화된 구간(HTTPS)을 통하여 이루어지며, 개인 세션 쿠키 등 보안상 취약할 수 있는 입력 폼을 원천 배제하여 데이터 유출 위험을 없앴습니다.', isDark),
                _buildBullet('관리적 조치: 데이터베이스(Firestore)에 대한 무단 접근을 차단하기 위해 인증된 보안 규칙(Security Rules)을 적용하고 있습니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('8. 정보주체의 권리·의무 및 행사방법', isDark),
                _buildParagraph('① 정보주체는 \'서비스\'에 대해 언제든지 동기화된 데이터의 열람, 정정, 삭제 및 연동 해제 등을 요구할 수 있습니다.', isDark),
                _buildParagraph('② 권리 행사는 \'서비스\' 앱/웹 내의 설정 또는 동기화 화면을 통하여 \'연동 해제(데이터 삭제)\' 기능을 이용하거나, 개발자 이메일로 연락해 주시면 지체 없이 조치하겠습니다.', isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('9. 개인정보 보호책임자', isDark),
                _buildParagraph('\'서비스\'는 개인정보 처리에 관한 업무를 총괄하고, 정보주체의 고충 처리를 위하여 아래와 같이 보호책임자를 지정하고 있습니다.', isDark),
                _buildBullet('책임자 성명: 귀정 (MIMIR 개발자)', isDark),
                _buildBullet("이메일/문의처: 앱 하단의 '문의 및 제보' 구글 폼 링크 이용", isDark),
                const SizedBox(height: 32),

                _buildSectionTitle('10. 개인정보 처리방침의 변경', isDark),
                _buildParagraph('본 개인정보 처리방침은 2026년 6월 3일부터 시행됩니다.', isDark),

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
