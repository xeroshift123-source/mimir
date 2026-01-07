import 'package:flutter/material.dart';
import 'package:mimir/screens/deck_builder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDeckBuilder(BuildContext context) {
    Navigator.pushNamed(context, DeckBuilderScreen.routeName);
  }

  // ✅ 레이드 요약 카드 위젯
  Widget _buildRaidSummaryCard(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ 카드 상단 이미지 (카드 폭에 딱 맞게)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  "assets/images/raids/only_one.webp",
                  width: double.infinity,
                  height: 400,
                  fit: BoxFit.cover,
                ),
              ),

              // ✅ 카드 본문
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "다음 솔로 레이드",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: const Text(
                            "SEASON 33",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "온리 원 (Only One)",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 18, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          "1/8(목) 12:00 ~ 1/15(목) 04:59",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _chip(
                          iconPath:
                              "assets/icons/elements/icon-elements-Fire.webp",
                          title: "보스 속성",
                          value: "작열",
                        ),
                        _chip(
                          iconPath:
                              "assets/icons/elements/icon-elements-Water.webp",
                          title: "약점 속성",
                          value: "수냉",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chip({
    required String iconPath,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconPath,
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "니케 솔레 덱 편집기",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ 레이드 요약 영역
                _buildRaidSummaryCard(context),

                const SizedBox(height: 24),

                // ✅ 기존 버튼 (더 존재감 있게)
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _openDeckBuilder(context),
                    child: const Text(
                      "덱 구성 시작하기",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
