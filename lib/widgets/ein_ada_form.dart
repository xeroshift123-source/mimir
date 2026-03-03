import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EinAdaCalculatorForm extends StatefulWidget {
  const EinAdaCalculatorForm({super.key});

  @override
  State<EinAdaCalculatorForm> createState() => _EinAdaCalculatorFormState();
}

class _EinAdaCalculatorFormState extends State<EinAdaCalculatorForm> {
  final _adaAtkController = TextEditingController(text: "80000");
  final _adaOverController = TextEditingController(text: "0");
  final _einAtkController = TextEditingController(text: "85000");
  final _einOverController = TextEditingController(text: "0");

  double resAdaAtkOnAdaB = 0;
  double resEinAtkOnAdaB = 0;
  double resAdaAtkOnEinB = 0;
  double resEinAtkOnEinB = 0;
  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  bool isError = false;

  final NumberFormat _formatter = NumberFormat('#,###');

  void _calculate() {
    setState(() {
      double adaBaseAtk = double.tryParse(_adaAtkController.text) ?? 0;
      double adaOver = (double.tryParse(_adaOverController.text) ?? 0) / 100;
      double einBaseAtk = double.tryParse(_einAtkController.text) ?? 0;
      double einOver = (double.tryParse(_einOverController.text) ?? 0) / 100;

      resAdaAtkOnAdaB = adaBaseAtk * (1 + 0.404 + 0.6 + 0.4 + adaOver);
      resEinAtkOnAdaB = einBaseAtk * (1 + 0.404 + 0.7012 + einOver);
      resAdaAtkOnEinB = adaBaseAtk * (1 + 0.404 + adaOver);
      resEinAtkOnEinB = einBaseAtk * (1 + 0.404 + 0.7012 + 0.6 + einOver);

      bool condition1 = resEinAtkOnEinB > resAdaAtkOnEinB;
      bool condition2 = resAdaAtkOnAdaB > resEinAtkOnAdaB;

      if (condition1 && condition2) {
        resultMessage = "✅ 현재 세팅: 정상 작동 가능!";
        isError = false;
      } else if (!condition2) {
        isError = true;
        double requiredAdaTotal = resEinAtkOnAdaB / adaBaseAtk;
        double currentAdaTotal = (1 + 0.404 + 0.6 + 0.4 + adaOver);
        double neededOver = (requiredAdaTotal - currentAdaTotal) * 100;
        resultMessage =
            "❌ 에이다 버스트 시 아인이 더 높습니다!\n에이다 공증 ${neededOver.toStringAsFixed(2)}% 추가 필요";
      } else {
        resultMessage = "⚠️ 아인 버스트 시 아인이 더 낮습니다.";
        isError = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 24),
        _buildCharacterInputRow(
          label: "에이다",
          imagePath: "assets/nikke/ada.webp",
          color: Colors.orange,
          atkCtrl: _adaAtkController,
          overCtrl: _adaOverController,
        ),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
          label: "아인",
          imagePath: "assets/nikke/ein.webp",
          color: Colors.blue,
          atkCtrl: _einAtkController,
          overCtrl: _einOverController,
        ),
        const SizedBox(height: 24),
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
            child: const Text("시뮬레이션 계산",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 20),
        _buildResultCard("<에이다 버스트 시>", resAdaAtkOnAdaB, resEinAtkOnAdaB,
            ["에이다: 미란다(40.4%)+1스(60%)+버스트(40%)", "아인: 미란다(40.4%)+1스(70.12%)"]),
        const SizedBox(height: 12),
        _buildResultCard("<아인 버스트 시>", resAdaAtkOnEinB, resEinAtkOnEinB,
            ["에이다: 미란다(40.4%)", "아인: 미란다(40.4%)+1스(70.12%)+에이다공증(60%)"]),
        const SizedBox(height: 16),
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
            ],
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
        labelStyle: const TextStyle(fontSize: 14),
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
      String title, double adaVal, double einVal, List<String> notes) {
    bool adaStronger = adaVal > einVal;
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87)),
          const SizedBox(height: 10),
          _resRow("에이다", _formatter.format(adaVal.toInt()), adaStronger,
              Colors.orange),
          const SizedBox(height: 4),
          _resRow("아인", _formatter.format(einVal.toInt()), !adaStronger,
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
