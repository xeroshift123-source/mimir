import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/nikke.dart';
import 'license_score_summary.dart';

class NikkeDriverLicense extends StatelessWidget {
  const NikkeDriverLicense(
      {super.key,
      required this.char,
      required this.localNikke,
      required this.cp40,
      this.nickname,
      this.scores = const []});
  final Map<String, dynamic> char;
  final Nikke? localNikke;
  final double cp40;
  final String? nickname;
  final List<LicenseScore> scores;

  @override
  Widget build(BuildContext context) {
    final mappedName = localNikke?.name ?? '알 수 없음';
    final displayName =
        nickname != null ? "$nickname의 $mappedName" : mappedName;
    final String formattedPow40 = cp40 == -1.0
        ? '측정 불가'
        : (cp40 > 0 ? NumberFormat('#,###').format(cp40.round()) : '계산중...');
    final today = DateFormat('yyyy.MM.dd').format(DateTime.now());

    final grade = char['grade'] as int? ?? 0;
    final core = char['core'] as int? ?? 0;
    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    final skill1 = skills['skill1'] ?? 1;
    final skill2 = skills['skill2'] ?? 1;
    final burst = skills['burst'] ?? 1;

    String starStr = '★' * grade + '☆' * (3 - grade);
    if (core > 0) {
      starStr += '  +$core';
    }

    String licenseType = "1종 보통";
    if (cp40 >= 80000) {
      licenseType = "AZX운용";
    } else if (cp40 >= 70000) {
      licenseType = "1종 특수";
    } else if (cp40 >= 60000) {
      licenseType = "1종 대형";
    } else if (cp40 > 0 && cp40 < 40000) {
      licenseType = "자전거 면허";
    } else if (cp40 > 0 && cp40 < 50000) {
      licenseType = "1종 소형";
    }

    final bool is80k = licenseType == "AZX운용";
    final bool isSpecial = licenseType == "1종 특수" || is80k;
    final Color textColor = isSpecial ? Colors.white : Colors.black87;
    final Color subTextColor = isSpecial ? Colors.white70 : Colors.black54;

    final Color badgeColor = is80k
        ? const Color(0xFFFF4D4D)
        : (isSpecial ? Colors.amber : Colors.black87);

    final List<Shadow>? textGlowShadows = is80k
        ? [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2.0,
              color: Colors.black.withOpacity(0.8),
            ),
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 8.0,
              color: const Color(0xFFFF1A1A).withOpacity(0.9),
            ),
          ]
        : (isSpecial
            ? [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 2.0,
                  color: Colors.black.withOpacity(0.5),
                ),
                Shadow(
                  offset: const Offset(0, 0),
                  blurRadius: 6.0,
                  color: Colors.amber.withOpacity(0.5),
                ),
              ]
            : null);

    return Container(
      width: 640,
      decoration: BoxDecoration(
        color: isSpecial ? const Color(0xFF151515) : Colors.white,
        gradient: is80k
            ? const RadialGradient(
                center: Alignment(0.85, 0.75),
                radius: 1.4,
                colors: [
                  Color(0xFF8B0000),
                  Color(0xFF330005),
                  Color(0xFF0A070A),
                ],
                stops: [0.0, 0.45, 1.0],
              )
            : (isSpecial
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2C2C35),
                      Color(0xFF0F0F13),
                    ],
                  )
                : const RadialGradient(
                    center: Alignment.centerRight,
                    radius: 1.5,
                    colors: [
                      Color(0xFFE8F4F8),
                      Color(0xFFFDE8F3),
                      Color(0xFFFFF6E5),
                    ],
                  )),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: is80k
                ? const Color(0xFFFF3333).withOpacity(0.6)
                : (isSpecial ? Colors.transparent : Colors.black12),
            width: is80k ? 1.5 : (isSpecial ? 0 : 1)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(licenseType,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: badgeColor,
                                  shadows: textGlowShadows)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSpecial ? 0 : 6, vertical: 2),
                        color: isSpecial
                            ? Colors.transparent
                            : Colors.yellow.shade200,
                        child: Text("이 면허증은 현실에서",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: is80k
                                    ? const Color(0xFFFF6666)
                                    : (isSpecial
                                        ? Colors.red.shade400
                                        : Colors.black87))),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSpecial ? 0 : 6, vertical: 2),
                        color: isSpecial
                            ? Colors.transparent
                            : Colors.yellow.shade200,
                        child: Text("쓰면 안 돼요! (진짜임)",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: is80k
                                    ? const Color(0xFFFF6666)
                                    : (isSpecial
                                        ? Colors.red.shade400
                                        : Colors.black87))),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 170,
                        height: 240,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: is80k
                                    ? const Color(0xFFFF3333).withOpacity(0.5)
                                    : (isSpecial
                                        ? Colors.amber.withOpacity(0.3)
                                        : Colors.black12),
                                width: 1),
                            color: isSpecial
                                ? Colors.grey.shade900
                                : Colors.grey.shade200,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withOpacity(isSpecial ? 0.5 : 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2))
                            ]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: localNikke != null
                              ? Image.asset(
                                  localNikke!.imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                )
                              : const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              is80k ? "AZX 운용 권한 증서" : "협전 운전 면허증",
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                  shadows: is80k
                                      ? [
                                          Shadow(
                                            offset: const Offset(1, 1),
                                            blurRadius: 2.0,
                                            color:
                                                Colors.black.withOpacity(0.8),
                                          ),
                                          Shadow(
                                            offset: const Offset(0, 0),
                                            blurRadius: 8.0,
                                            color: const Color(0xFFFF1A1A)
                                                .withOpacity(0.6),
                                          ),
                                        ]
                                      : (isSpecial
                                          ? [
                                              Shadow(
                                                offset: const Offset(1, 1),
                                                blurRadius: 2.0,
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                              ),
                                              Shadow(
                                                offset: const Offset(0, 0),
                                                blurRadius: 6.0,
                                                color: Colors.white
                                                    .withOpacity(0.3),
                                              ),
                                            ]
                                          : null)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              is80k ? "(AZX Operator)" : "(Driver's License)",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: subTextColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                            height: 2,
                            color: is80k
                                ? const Color(0xFFFF3333).withOpacity(0.8)
                                : (isSpecial
                                    ? Colors.amber.withOpacity(0.6)
                                    : Colors.pink.shade200)),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Text("이름 : ",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor)),
                            Expanded(
                                child: Text(displayName,
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                        letterSpacing: 1.0),
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text("전투력 : ",
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: textColor)),
                            Text(formattedPow40,
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: badgeColor,
                                    shadows: textGlowShadows)),
                            const SizedBox(width: 8),
                          ],
                        ),
                        LicenseScoreSummary(
                            scores: scores,
                            textColor: textColor,
                            scoreColor: badgeColor),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text("한계 돌파 : ",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor)),
                            Text(starStr,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text("스킬 레벨 : ",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor)),
                            Text("$skill1 / $skill2 / $burst",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: textColor)),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Spacer(),
                            Text(today,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: 1.0)),
                            const Spacer(),
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Text("발급기관 : 미미르만만세",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: textColor)),
                                Positioned(
                                  right: -10,
                                  top: -60,
                                  child: Opacity(
                                    opacity: 0.9,
                                    child: Transform.rotate(
                                      angle: -0.15,
                                      child: Image.asset(
                                        'assets/images/dorodojang.png',
                                        width: 100,
                                        height: 100,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
