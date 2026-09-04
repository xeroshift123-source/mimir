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
                const SizedBox(height: 8),
                _buildParagraph('시행일: 2026년 9월 4일', isDark),
                const SizedBox(height: 16),
                _buildParagraph(
                    "MIMIR(이하 '서비스')은 정보주체의 자유와 권리를 보호하기 위해 「개인정보 보호법」 및 관계 법령을 준수하고, 서비스에서 처리하는 개인정보와 이용자의 권리를 다음과 같이 안내합니다.",
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('1. 개인정보의 처리 목적', isDark),
                _buildBullet(
                    '회원 및 계정 관리: Google 로그인, 이용자 식별, 서비스 닉네임 관리, 회원 탈퇴 및 부정 이용 방지',
                    isDark),
                _buildBullet(
                    '게임 계정 연동: BLABLALINK 프로필 상태메시지를 이용한 계정 소유권 확인, 연동 계정 관리 및 데이터 갱신',
                    isDark),
                _buildBullet(
                    '서비스 제공: 인게임 프로필과 캐릭터·장비 데이터를 이용한 덱 구성, 성장 상태 시각화, 전투력 분석, 통계 및 뱃지 산정',
                    isDark),
                _buildBullet(
                    '덱 라이브러리 운영: 공유 덱 게시글 작성·수정·삭제, 작성자 표시, 추천·비추천 및 전시 뱃지 제공',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('2. 처리하는 개인정보의 항목 및 수집 방법', isDark),
                _buildParagraph('[Google 로그인 및 MIMIR 계정]', isDark),
                _buildBullet(
                    '필수 처리 항목: Firebase 사용자 식별자(UID), Google 계정 이메일, Google 표시 이름 및 프로필 사진 URL, 로그인 제공자, MIMIR 닉네임, 계정 생성·수정 일시',
                    isDark),
                const SizedBox(height: 8),
                _buildParagraph('[BLABLALINK 계정 연동 및 게임 데이터]', isDark),
                _buildBullet(
                    '연동 정보: 사용자가 입력한 BLABLALINK 프로필 URL, BLABLALINK 식별자(openId), 연동·선택·갱신 일시, 소유권 확인 결과',
                    isDark),
                _buildBullet(
                    '기본 프로필: 인게임 닉네임, 서버, 소속 유니온 및 유니온 레벨, 지휘관 레벨, 가입·최근 접속 정보, 상태메시지(최초 소유권 확인 과정에서만 사용)',
                    isDark),
                _buildBullet(
                    '성장 정보: 대표 스쿼드 전투력, 싱크로 레벨, 캠페인 진행도, 타워 층수, 보유 니케·코스튬 수, 리사이클 룸, 인프라 코어 및 시뮬레이션 룸 오버클럭 기록',
                    isDark),
                _buildBullet(
                    '보유 니케 상세 정보: 캐릭터 코드, 전투력, 레벨, 한계돌파·코어강화, 스킬, 호감도, 큐브, 애장품 및 장비·오버로드 옵션',
                    isDark),
                const SizedBox(height: 8),
                _buildParagraph('[덱 라이브러리 및 뱃지]', isDark),
                _buildBullet(
                    '공유 게시글: 작성자 UID와 닉네임, 제목, 전체·스쿼드별 설명, 시즌·보스·약점 정보, 덱 구성, 작성·수정 일시',
                    isDark),
                _buildBullet(
                    '이용 기록: 공유 덱별 추천·비추천 값과 투표한 이용자의 UID, 획득 뱃지 및 전시 뱃지 식별자',
                    isDark),
                const SizedBox(height: 8),
                _buildParagraph('[서비스 이용 과정에서 자동 처리될 수 있는 정보]', isDark),
                _buildBullet(
                    'IP 주소, 사용자 에이전트, 접속·인증 기록 및 오류 기록이 Firebase Hosting, Authentication, Cloud Functions의 보안 유지와 장애 대응 과정에서 처리될 수 있습니다.',
                    isDark),
                const SizedBox(height: 16),
                _buildParagraph(
                    '수집 방법: Google 로그인 과정에서 이용자가 제공에 동의한 정보, 이용자가 직접 입력한 닉네임·프로필 URL·게시글, 서비스 이용 중 생성되는 기록, BLABLALINK 공개 API를 통해 조회한 게임 정보를 수집합니다.',
                    isDark),
                const SizedBox(height: 16),
                _buildHighlightBox(
                  title: '[비밀번호 및 개인 세션 정보 안내]',
                  content:
                      '서비스는 Google 비밀번호, 인게임 비밀번호 또는 이용자의 BLABLALINK 세션 쿠키를 수집·저장하지 않습니다. Google 인증은 Google과 Firebase Authentication을 통해 처리되며, MIMIR 데이터베이스에는 Google OAuth 액세스 토큰을 별도로 저장하지 않습니다.',
                  isDark: isDark,
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('3. 개인정보의 처리 및 보유 기간', isDark),
                _buildBullet(
                    'MIMIR 회원 정보: 회원 탈퇴 시까지. 탈퇴 시 Firebase Authentication 계정과 users 문서를 삭제합니다.',
                    isDark),
                _buildBullet(
                    'BLABLALINK 연동 정보: 해당 계정의 연동 해제 또는 MIMIR 회원 탈퇴 시까지. 단순 연동 해제는 계정 연결 및 저장 URL을 제거하는 기능이며, 이미 생성된 게임 데이터 스냅샷의 완전 삭제가 필요한 경우 제9조의 문의처로 요청할 수 있습니다.',
                    isDark),
                _buildBullet(
                    '공유 덱: 작성자가 삭제하거나 회원 탈퇴할 때까지. 회원 탈퇴 시 본인이 작성한 공유 덱도 삭제합니다.',
                    isDark),
                _buildBullet(
                    '다른 작성자의 덱에 남긴 투표 기록: 해당 공유 덱이 삭제될 때까지 보관될 수 있으며, 별도 삭제를 원하는 경우 문의처로 요청할 수 있습니다.',
                    isDark),
                _buildBullet(
                    '인증·접속 로그: Google의 Firebase 서비스별 정책에 따릅니다. Authentication의 IP 로그는 수 주, Hosting의 IP 정보는 수개월 동안 보관될 수 있고 Cloud Functions의 IP 정보는 서비스 제공을 위해 일시 처리됩니다.',
                    isDark),
                _buildParagraph(
                    '관계 법령에 따라 일정 기간 보관해야 하는 경우에는 해당 법령에서 정한 기간 동안 분리하여 보관한 뒤 파기합니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('4. 개인정보의 파기 절차 및 방법', isDark),
                _buildParagraph(
                    '보유 기간이 끝나거나 처리 목적이 달성된 개인정보는 지체 없이 삭제합니다. 전자적 파일은 데이터베이스에서 삭제하고, 종이 문서는 수집하지 않습니다. 클라우드 백업에 남은 정보는 수탁자의 삭제 주기에 따라 순차적으로 삭제될 수 있습니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('5. 개인정보 처리업무의 위탁', isDark),
                _buildBullet('수탁자: Google LLC', isDark),
                _buildBullet(
                    '위탁 업무: Google 로그인 및 인증(Firebase Authentication), 데이터 보관(Cloud Firestore), 백엔드 처리(Cloud Functions), 웹 서비스 제공(Firebase Hosting)',
                    isDark),
                _buildBullet(
                    '보유 기간: 서비스별 보유 정책 또는 위탁계약 종료 시까지. 다만 관련 법령과 백업 삭제 주기에 따라 일정 기간 보존될 수 있습니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('6. 개인정보의 국외 이전', isDark),
                _buildBullet('이전받는 자: Google LLC 및 Google이 공개한 재수탁자', isDark),
                _buildBullet(
                    '이전 국가·서비스 위치: Firebase Authentication은 미국에서 처리되며, Cloud Functions는 미국(us-central1)에서 실행됩니다. MIMIR의 주 데이터베이스(Cloud Firestore)는 대한민국 서울(asia-northeast3)에 위치합니다. 일부 운영·보안 데이터는 Google의 글로벌 인프라에서 처리될 수 있습니다.',
                    isDark),
                _buildBullet(
                    '이전 항목: 로그인 식별정보, 이메일·프로필 정보, 인증 토큰, 서비스 API 요청 데이터, IP 주소 및 접속 기술정보',
                    isDark),
                _buildBullet(
                    '이전 목적·방법·시점: 인증, 백엔드 기능 실행, 보안 및 장애 대응을 위해 해당 기능 이용 시 암호화된 네트워크로 전송',
                    isDark),
                _buildBullet(
                    '보유 기간: 제3조의 보유 기간과 Google의 서비스별 삭제 정책에 따릅니다. 국외 이전을 거부하면 Google 로그인과 계정 기반 기능을 이용할 수 없습니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('7. 개인정보의 공개 및 제3자 제공', isDark),
                _buildParagraph(
                    '서비스는 원칙적으로 처리 목적 범위를 벗어나 개인정보를 제3자에게 제공하지 않습니다. 다만 이용자가 덱 라이브러리에 게시글을 등록하면 아래 정보가 불특정 다수에게 공개됩니다.',
                    isDark),
                _buildBullet(
                    '공개 정보: 작성자 닉네임과 내부 계정 식별자(UID), 게시글 제목·설명·덱 구성·작성 시각 및 추천 수',
                    isDark),
                _buildBullet(
                    '작성자 닉네임을 클릭할 때 추가 공개되는 정보: 이용자가 직접 전시하도록 선택한 뱃지와 해당 공개 뱃지의 달성 정보',
                    isDark),
                _buildParagraph(
                    '게시글 작성자는 게시글을 삭제하여 공개를 중단할 수 있습니다. 법령에 특별한 규정이 있거나 적법한 절차에 따른 공공기관의 요구가 있는 경우에는 예외적으로 제공될 수 있습니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('8. 정보주체의 권리·의무 및 행사방법', isDark),
                _buildParagraph(
                    '이용자는 내 계정 정보 페이지에서 닉네임 수정, BLABLALINK 연동 해제, 전시 뱃지 변경 및 MIMIR 회원 탈퇴를 할 수 있습니다. 공유 덱은 해당 게시글에서 직접 수정하거나 삭제할 수 있습니다.',
                    isDark),
                _buildParagraph(
                    '개인정보의 열람·정정·삭제·처리정지 또는 동의 철회를 별도로 요청하려면 제9조의 문의처를 이용할 수 있습니다. 서비스는 본인 확인 후 관계 법령에 따라 지체 없이 처리합니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('9. 개인정보 보호책임자', isDark),
                _buildBullet('책임자 성명: 귀정 (MIMIR 개발자)', isDark),
                _buildBullet("문의처: 서비스 하단의 '문의 및 제보' Google 양식", isDark),
                _buildParagraph(
                    '개인정보 침해에 관한 상담이 필요한 경우 개인정보침해 신고센터(국번 없이 118) 등 관계 기관에 문의할 수 있습니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('10. 개인정보의 안전성 확보조치', isDark),
                _buildBullet(
                    '전송 구간 암호화(HTTPS), Firebase Authentication을 통한 인증, Firestore Security Rules와 서버 측 권한 검증을 적용합니다.',
                    isDark),
                _buildBullet(
                    'Google 비밀번호와 이용자의 BLABLALINK 세션 쿠키를 직접 수집하지 않으며, 관리 권한을 최소화하고 오류 기록에 개인정보가 불필요하게 남지 않도록 관리합니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('11. 로컬 저장소의 이용', isDark),
                _buildParagraph(
                    '서비스는 로그인 상태 유지, 테마, 최근 선택 계정, 덱 편집 임시 저장 및 비회원 프로필 접근 토큰 등을 브라우저 로컬 저장소에 저장할 수 있습니다. 이는 광고 추적 목적으로 사용되지 않으며, 브라우저 데이터 삭제 또는 회원 탈퇴 시 일부 항목을 삭제할 수 있습니다. 로컬 저장을 차단하면 일부 기능이 정상 작동하지 않을 수 있습니다.',
                    isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('12. 개인정보 처리방침의 변경', isDark),
                _buildParagraph(
                    '본 처리방침은 2026년 9월 4일부터 시행됩니다. 중요한 내용이 변경되는 경우 서비스 화면을 통해 알리겠습니다.',
                    isDark),
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

  Widget _buildHighlightBox(
      {required String title, required String content, required bool isDark}) {
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
