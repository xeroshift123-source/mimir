import 'package:flutter/material.dart';
import 'package:mimir/screens/calculate_list.dart';
import 'package:mimir/screens/deck_builder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedWeakness = '수냉';

  static const Map<String, String> _elementIconMap = {
    '전격': 'assets/icons/elements/icon-elements-Electric.webp',
    '철갑': 'assets/icons/elements/icon-elements-Iron.webp',
    '작열': 'assets/icons/elements/icon-elements-Fire.webp',
    '수냉': 'assets/icons/elements/icon-elements-Water.webp',
    '풍압': 'assets/icons/elements/icon-elements-Wind.webp',
  };

  void _openDeckBuilder(BuildContext context) {
    Navigator.pushNamed(
      context,
      DeckBuilderScreen.routeName,
      arguments: _selectedWeakness,
    );
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
                  "assets/images/raids/ultra.webp",
                  width: double.infinity,
                  fit: BoxFit.contain,
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
                            "SEASON 37",
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
                      "울트라",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 18, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          "5/28(목) 12:00 ~ 6/4(목) 4:59",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
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
                              "assets/icons/elements/icon-elements-fire.webp",
                          title: "보스 속성",
                          value: "작열",
                        ),
                        _chip(
                          iconPath: _elementIconMap[_selectedWeakness] ??
                              "assets/icons/elements/icon-elements-Electric.webp",
                          title: "약점 속성",
                          value: _selectedWeakness,
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

// ✅ 계산기 화면으로 이동 (가상의 routeName 사용)
  void _openCalculator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalculateListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "니케 덱 빌딩 도우미 MIMIR!",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        centerTitle: true,
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

                // 🎯 솔로 레이드 보스 약점 속성 선택 Dropdown
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.orange.shade300, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedWeakness,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.orange, size: 28),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedWeakness = newValue;
                            });
                          }
                        },
                        items: <String>['전격', '철갑', '작열', '수냉', '풍압']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                Image.asset(
                                  _elementIconMap[value]!,
                                  width: 20,
                                  height: 20,
                                ),
                                const SizedBox(width: 10),
                                Text('공략 약점 속성: $value'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ 버튼 그룹 (계산기 & 덱 구성)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Row(
                    children: [
                      // 🧮 계산기 버튼 (조금 더 보조적인 느낌)
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => _openCalculator(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.orange, width: 1.5),
                              foregroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "계산기",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ⚔️ 덱 구성 시작 버튼 (메인 액션)
                      Expanded(
                        flex: 2, // 메인 버튼을 더 넓게 설정
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _openDeckBuilder(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "덱 구성 시작",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800),
                            ),
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
    );
  }
}
