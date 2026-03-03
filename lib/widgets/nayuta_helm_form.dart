import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NayutaHelmCalculatorForm extends StatefulWidget {
  const NayutaHelmCalculatorForm({super.key});

  @override
  State<NayutaHelmCalculatorForm> createState() =>
      _NayutaHelmCalculatorFormState();
}

class _NayutaHelmCalculatorFormState extends State<NayutaHelmCalculatorForm> {
  // 컨트롤러 초기값 설정
  final _nayutaAtkController = TextEditingController(text: "85000");
  final _nayutaOverController = TextEditingController(text: "0");
  final _helmAtkController = TextEditingController(text: "80000");
  final _helmOverController = TextEditingController(text: "0");

  double resNayutaFinal = 0;
  double resHelmFinal = 0;
  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  bool isError = false;

  final NumberFormat _formatter = NumberFormat('#,###');

  @override
  void dispose() {
    _nayutaAtkController.dispose();
    _nayutaOverController.dispose();
    _helmAtkController.dispose();
    _helmOverController.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      // 1. 입력값 파싱
      double nBaseAtk = double.tryParse(_nayutaAtkController.text) ?? 0;
      double nOver = (double.tryParse(_nayutaOverController.text) ?? 0) / 100;
      double hBaseAtk = double.tryParse(_helmAtkController.text) ?? 0;
      double hOver = (double.tryParse(_helmOverController.text) ?? 0) / 100;

      // 2. 버프 계수 정의
      const double mirandaBurst = 1.404; // 미란다 버스트 (1 + 0.404)
      const double nayutaSkill2 = 1.152; // 나유타 2스킬 (1 + 0.152)

      // 3. 최종 공격력 계산
      resNayutaFinal = nBaseAtk * (1 + nOver) * nayutaSkill2 * mirandaBurst;
      resHelmFinal = hBaseAtk * (1 + hOver) * mirandaBurst;

      // 4. 결과 비교 및 메시지 생성
      if (resNayutaFinal > resHelmFinal) {
        resultMessage = "✅ 정상: 나유타의 최종 공격력이 더 높습니다.";
        isError = false;
      } else {
        isError = true;

        // --- [추가된 역산 로직] ---
        // 나유타가 헬름과 같아지기 위해 필요한 총 오버공증 배율을 구합니다.
        // 공식: (헬름 최종공) / (나유타 기초공 * 나유타 2스킬 * 미란다 버스트)
        double requiredTotalRatio =
            resHelmFinal / (nBaseAtk * nayutaSkill2 * mirandaBurst);

        // 현재 나유타의 배율(1 + 현재 오버공증)을 빼서 추가로 필요한 %를 계산합니다.
        double neededOver = (requiredTotalRatio - (1 + nOver)) * 100;

        resultMessage =
            "❌ 경고: 헬름이 나유타보다 높습니다!\n나유타의 오버공증이 ${neededOver.toStringAsFixed(2)}% 더 필요합니다.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 24),
        // 나유타 입력창
        _buildCharacterInputRow(
          label: "나유타",
          imagePath: "assets/nikke/nayuta.webp",
          color: Colors.purple,
          atkCtrl: _nayutaAtkController,
          overCtrl: _nayutaOverController,
        ),
        const SizedBox(height: 16),
        // 헬름 입력창
        _buildCharacterInputRow(
          label: "헬름",
          imagePath: "assets/nikke/helm.webp",
          color: Colors.blue,
          atkCtrl: _helmAtkController,
          overCtrl: _helmOverController,
        ),
        const SizedBox(height: 24),
        // 계산 버튼
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _calculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("최종 버프 결과 계산",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 20),
        // 결과 카드 (단일 비교)
        _buildResultCard("모든 버프 적용 후 최종 공격력", resNayutaFinal, resHelmFinal,
            ["나유타: 오버공증 + 2스(15.2%) + 미란다(40.4%)", "헬름: 오버공증 + 미란다(40.4%)"]),
        const SizedBox(height: 16),
        // 하단 상태 메시지 박스
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isError ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isError ? Colors.red.shade200 : Colors.green.shade200),
          ),
          child: Text(
            resultMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isError ? Colors.red.shade800 : Colors.green.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
      ],
    );
  }

  // UI 컴포넌트들 (아인-에이다와 동일한 디자인 유지)
  Widget _buildCharacterInputRow({
    required String label,
    required String imagePath,
    required Color color,
    required TextEditingController atkCtrl,
    required TextEditingController overCtrl,
  }) {
    return Row(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
            image: DecorationImage(
                image: AssetImage(imagePath), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildCompactField("400렙 공", atkCtrl)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCompactField("오버공증 (%)", overCtrl)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildResultCard(
      String title, double nayutaVal, double helmVal, List<String> notes) {
    bool nayutaStronger = nayutaVal > helmVal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          _resRow("나유타", _formatter.format(nayutaVal.toInt()), nayutaStronger,
              Colors.purple),
          const SizedBox(height: 4),
          _resRow("헬름", _formatter.format(helmVal.toInt()), !nayutaStronger,
              Colors.blue),
          const Divider(height: 20),
          ...notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text("• $n",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              )),
        ],
      ),
    );
  }

  Widget _resRow(String name, String val, bool win, Color winColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name,
            style: TextStyle(
                fontSize: 12,
                color: win ? Colors.black : Colors.grey.shade600)),
        Text(val,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: win ? winColor : Colors.black87)),
      ],
    );
  }
}
