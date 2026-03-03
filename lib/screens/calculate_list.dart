import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mimir/widgets/ein_ada_form.dart';
import 'package:mimir/widgets/nayuta_helm_form.dart';

class CalculateListScreen extends StatefulWidget {
  static const routeName = '/calculate-list';

  const CalculateListScreen({super.key});

  @override
  State<CalculateListScreen> createState() => _CalculateListScreenState();
}

class _CalculateListScreenState extends State<CalculateListScreen> {
  int? _expandedIndex;

  final List<Map<String, dynamic>> _calculators = [
    {
      "title": "아인-에이다 계산기",
      "subtitle": "애장품 미란다 버프 시뮬레이션",
      "icon": "assets/icons/elements/icon-elements-Electric.webp",
      "content": const EinAdaCalculatorForm(),
    },
    {
      "title": "나유타-헬름 계산기",
      "subtitle": "애장품 미란다 버프 시뮬레이션",
      "icon": "assets/icons/elements/icon-elements-Wind.webp",
      "content": const NayutaHelmCalculatorForm(),
    },
    {
      "title": "흑련-리버렐리오 계산기",
      "subtitle": "리버렐리오 1스킬 차속 버프 시뮬레이션",
      "icon": "assets/icons/elements/icon-elements-Wind.webp",
      "content": const ScarletLibCalculatorForm(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          "전용 계산기 목록",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _calculators.length,
            itemBuilder: (context, index) {
              final item = _calculators[index];
              final isExpanded = _expandedIndex == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpanded ? Colors.orange : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (isExpanded)
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                  ],
                ),
                child: Column(
                  children: [
                    // --- 헤더 부분 ---
                    InkWell(
                      onTap: () => setState(
                          () => _expandedIndex = isExpanded ? null : index),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? Colors.orange
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.asset(
                                item['icon'],
                                width: 40,
                                height: 40,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['subtitle'],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            // 아이콘 회전 애니메이션
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: const Icon(Icons.expand_more,
                                  color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- 펼쳐지는 내용 (애니메이션 적용) ---
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: item['content'],
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ScarletLibCalculatorForm extends StatelessWidget {
  const ScarletLibCalculatorForm({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
          child:
              Text("추후 추가 예정입니다...ㅎㅎ;;", style: TextStyle(color: Colors.grey))),
    );
  }
}
