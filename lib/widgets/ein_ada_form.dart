import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EinAdaCalculatorForm extends StatefulWidget {
  const EinAdaCalculatorForm({super.key});

  @override
  State<EinAdaCalculatorForm> createState() => _EinAdaCalculatorFormState();
}

class _EinAdaCalculatorFormState extends State<EinAdaCalculatorForm> {
  // 기본값 복구
  final _adaAtkController = TextEditingController(text: "80,000");
  final _adaOverController = TextEditingController(text: "0");
  final _einAtkController = TextEditingController(text: "85,000");
  final _einOverController = TextEditingController(text: "0");

  final _mirandaAtkController = TextEditingController(text: "40.4");
  final _adaS1Controller = TextEditingController(text: "60.0");
  final _adaBurstController = TextEditingController(text: "40.0");
  final _einS1Controller = TextEditingController(text: "70.12");

  double resAdaAtkOnAdaB = 0;
  double resEinAtkOnAdaB = 0;
  double resAdaAtkOnEinB = 0;
  double resEinAtkOnEinB = 0;
  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  bool isError = false;

  final NumberFormat _formatter = NumberFormat('#,###');

  @override
  void dispose() {
    _adaAtkController.dispose();
    _adaOverController.dispose();
    _einAtkController.dispose();
    _einOverController.dispose();
    _mirandaAtkController.dispose();
    _adaS1Controller.dispose();
    _adaBurstController.dispose();
    _einS1Controller.dispose();
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  void _calculate() {
    setState(() {
      double adaBase = _parse(_adaAtkController.text);
      double adaOver = _parse(_adaOverController.text) / 100;
      double einBase = _parse(_einAtkController.text);
      double einOver = _parse(_einOverController.text) / 100;

      double miranda = _parse(_mirandaAtkController.text) / 100;
      double adaS1 = _parse(_adaS1Controller.text) / 100;
      double adaB = _parse(_adaBurstController.text) / 100;
      double einS1 = _parse(_einS1Controller.text) / 100;

      // 합연산 적용
      resAdaAtkOnAdaB = adaBase * (1 + miranda + adaS1 + adaB + adaOver);
      resEinAtkOnAdaB = einBase * (1 + miranda + einS1 + einOver);
      resAdaAtkOnEinB = adaBase * (1 + miranda + adaOver);
      resEinAtkOnEinB =
          einBase * (1 + miranda + einS1 + adaOver + einOver); // 예시 로직 유지

      bool condition1 = resEinAtkOnEinB > resAdaAtkOnEinB;
      bool condition2 = resAdaAtkOnAdaB > resEinAtkOnAdaB;

      if (condition1 && condition2) {
        resultMessage = "✅ 정상 작동 가능!";
        isError = false;
      } else if (!condition2) {
        isError = true;
        double neededOver =
            ((resEinAtkOnAdaB / adaBase) - (1 + miranda + adaS1 + adaB)) * 100;
        resultMessage =
            "❌ 에이다 버스트 시 아인이 더 높습니다!\n에이다 오버공증 ${neededOver.toStringAsFixed(2)}% 추가 필요";
      } else {
        resultMessage = "⚠️ 아인 버스트 시 아인이 더 낮습니다.";
        isError = true;
      }
    });
  }

  // ... (Dialog 및 UI Helper 함수들은 이전과 동일하며 _parse 로직 적용됨) ...
  void _showMirandaDialog() {
    _showSettingDialog(
        "미란다 설정", [_buildPopupField("미란다 버스트 공증 (%)", _mirandaAtkController)]);
  }

  void _showAdaSkillDialog() {
    _showSettingDialog("에이다 스킬 설정", [
      _buildPopupField("1스킬 공증 (%)", _adaS1Controller),
      _buildPopupField("버스트 자공증 (%)", _adaBurstController)
    ]);
  }

  void _showEinSkillDialog() {
    _showSettingDialog(
        "아인 스킬 설정", [_buildPopupField("1스킬 공증 (%)", _einS1Controller)]);
  }

  void _showSettingDialog(String title, List<Widget> fields) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                content:
                    Column(mainAxisSize: MainAxisSize.min, children: fields),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("취소")),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      child: const Text("확인",
                          style: TextStyle(color: Colors.white)))
                ]));
  }

  Widget _buildPopupField(String label, TextEditingController controller) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)))));
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
            onImageTap: _showAdaSkillDialog),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
            label: "아인",
            imagePath: "assets/nikke/ein.webp",
            color: Colors.blue,
            atkCtrl: _einAtkController,
            overCtrl: _einOverController,
            onImageTap: _showEinSkillDialog),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                flex: 2,
                child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                        onPressed: _calculate,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text("시뮬레이션 계산",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15))))),
            const SizedBox(width: 8),
            Expanded(
                flex: 1,
                child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                        onPressed: _showMirandaDialog,
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("미란다",
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              SizedBox(width: 4),
                              Icon(Icons.settings,
                                  size: 16, color: Colors.orange)
                            ])))),
          ],
        ),
        const SizedBox(height: 20),
        _buildResultCard("<에이다 버스트 시>", resAdaAtkOnAdaB, resEinAtkOnAdaB, [
          "에이다: 미란다(${_mirandaAtkController.text}%)+1스(${_adaS1Controller.text}%)+버스트(${_adaBurstController.text}%)",
          "아인: 미란다(${_mirandaAtkController.text}%)+1스(${_einS1Controller.text}%)"
        ]),
        const SizedBox(height: 12),
        _buildResultCard("<아인 버스트 시>", resAdaAtkOnEinB, resEinAtkOnEinB, [
          "에이다: 미란다(${_mirandaAtkController.text}%)",
          "아인: 미란다(${_mirandaAtkController.text}%)+1스(${_einS1Controller.text}%)+에이다공증"
        ]),
        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  Widget _buildCharacterInputRow(
      {required String label,
      required String imagePath,
      required Color color,
      required TextEditingController atkCtrl,
      required TextEditingController overCtrl,
      VoidCallback? onImageTap}) {
    return Row(children: [
      GestureDetector(
        onTap: onImageTap,
        child: Stack(children: [
          Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                  image: DecorationImage(
                      image: AssetImage(imagePath), fit: BoxFit.cover))),
          Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.settings,
                      size: 12, color: Colors.white)))
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _buildCompactField("400렙 공", atkCtrl)),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactField("오버공증 (%)", overCtrl))
        ])
      ]))
    ]);
  }

  Widget _buildCompactField(String label, TextEditingController controller) {
    return TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                borderSide: BorderSide(color: Colors.grey.shade200))));
  }

  Widget _buildResultCard(
      String title, double adaVal, double einVal, List<String> notes) {
    bool adaWin = adaVal > einVal;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          _resRow(
              "에이다", _formatter.format(adaVal.toInt()), adaWin, Colors.orange),
          const SizedBox(height: 4),
          _resRow(
              "아인", _formatter.format(einVal.toInt()), !adaWin, Colors.blue),
          const Divider(height: 20),
          ...notes.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text("• $n",
                  style: const TextStyle(fontSize: 10, color: Colors.grey))))
        ]));
  }

  Widget _resRow(String name, String val, bool win, Color winColor) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(name,
          style: TextStyle(
              fontSize: 12, color: win ? Colors.black : Colors.grey.shade600)),
      Text(val,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: win ? winColor : Colors.black87))
    ]);
  }

  Widget _buildStatusBox() {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isError ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isError ? Colors.red.shade200 : Colors.green.shade200)),
        child: Text(resultMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isError ? Colors.red.shade800 : Colors.green.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13)));
  }
}
