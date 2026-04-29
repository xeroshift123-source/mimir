import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class EinAdaCalculatorForm extends StatefulWidget {
  const EinAdaCalculatorForm({super.key});

  @override
  State<EinAdaCalculatorForm> createState() => _EinAdaCalculatorFormState();
}

class _EinAdaCalculatorFormState extends State<EinAdaCalculatorForm> {
  // --- 컨트롤러 설정 ---
  final _adaAtkController = TextEditingController(text: "80,000");
  final _adaOverController = TextEditingController(text: "0");
  final _einAtkController = TextEditingController(text: "85,000");
  final _einOverController = TextEditingController(text: "0");

  // 타키나 관련 추가
  bool _useTakina = false;
  final _takinaAtkController = TextEditingController(text: "70,000");
  final _takinaOverController = TextEditingController(text: "0");
  final _takinaS1Controller = TextEditingController(text: "47.29");

  final _mirandaAtkController = TextEditingController(text: "40.4");
  final _adaS1Controller = TextEditingController(text: "60.0");
  final _adaBurstController = TextEditingController(text: "40.0");
  final _einS1Controller = TextEditingController(text: "70.12");

  // --- 결과 데이터 변수 ---
  double targetAda = 0, targetEin = 0, targetTakina = 0;
  double resAdaOnAdaB = 0, resEinOnAdaB = 0;
  double resAdaOnEinB = 0, resEinOnEinB = 0;
  List<String> bufferedNikkes = []; // 미란다 버프를 받는 니케 명단

  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  bool isError = false;
  final NumberFormat _formatter = NumberFormat('#,###');

  @override
  void dispose() {
    _adaAtkController.dispose();
    _adaOverController.dispose();
    _einAtkController.dispose();
    _einOverController.dispose();
    _takinaAtkController.dispose();
    _takinaOverController.dispose();
    _takinaS1Controller.dispose();
    _mirandaAtkController.dispose();
    _adaS1Controller.dispose();
    _adaBurstController.dispose();
    _einS1Controller.dispose();
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  void _calculate() {
    setState(() {
      double aAtk = _parse(_adaAtkController.text);
      double aOver = _parse(_adaOverController.text) / 100;
      double eAtk = _parse(_einAtkController.text);
      double eOver = _parse(_einOverController.text) / 100;
      double tAtk = _parse(_takinaAtkController.text);
      double tOver = _parse(_takinaOverController.text) / 100;
      double tS1 = _parse(_takinaS1Controller.text) / 100;

      double miranda = _parse(_mirandaAtkController.text) / 100;
      double aS1 = _parse(_adaS1Controller.text) / 100;
      double aB = _parse(_adaBurstController.text) / 100;
      double eS1 = _parse(_einS1Controller.text) / 100;

      // 1. 미란다 타겟팅 수치 판정 (사령관님 공식 반영)
      // 아인, 에이다: 400렙공 * (1 + 오버공증)
      // 타키나: 400렙공 * (1 + 1스킬 + 오버공증)
      targetAda = aAtk * (1 + aOver);
      targetEin = eAtk * (1 + eOver);
      targetTakina = _useTakina ? tAtk * (1 + tS1 + tOver) : 0;

      // 상위 공격력 2명 추출 로직
      var list = [
        {'name': '에이다', 'val': targetAda},
        {'name': '아인', 'val': targetEin},
        if (_useTakina) {'name': '타키나', 'val': targetTakina},
      ];
      list.sort((a, b) => (b['val'] as double).compareTo(a['val'] as double));
      bufferedNikkes = [list[0]['name'] as String, list[1]['name'] as String];

      // 2. 실제 전투 중 최종 공격력 계산 (미란다 버프 포함 여부 결정)
      bool adaGetsM = bufferedNikkes.contains('에이다');
      bool einGetsM = bufferedNikkes.contains('아인');
      double mValA = adaGetsM ? miranda : 0;
      double mValE = einGetsM ? miranda : 0;

      // <에이다 버스트 시>
      resAdaOnAdaB = aAtk * (1 + mValA + aS1 + aB + aOver);
      resEinOnAdaB = eAtk * (1 + mValE + eS1 + eOver);

      // <아인 버스트 시>
      resAdaOnEinB = aAtk * (1 + mValA + aOver);
      resEinOnEinB = eAtk * (1 + mValE + eS1 + eOver);

      // 3. 상태 메시지 및 에러 판정
      if (_useTakina && bufferedNikkes.contains('타키나')) {
        isError = true;
        resultMessage = "❌ 타키나가 미란다 버프를 탈취 중입니다! (타키나 수치를 낮추십시오)";
      } else if (resEinOnAdaB > resAdaOnAdaB) {
        isError = true;
        resultMessage = "⚠️ 에이다 버스트 시 아인의 공격력이 더 높습니다.";
      } else {
        isError = false;
        resultMessage = "✅ 모든 버프 타겟팅 및 위계가 정상입니다.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 24),
        // 캐릭터 입력 영역
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

        // 타키나 활성화 시 입력창 추가
        if (_useTakina) ...[
          const SizedBox(height: 16),
          _buildCharacterInputRow(
              label: "타키나",
              imagePath: "assets/nikke/takina.webp",
              color: Colors.redAccent,
              atkCtrl: _takinaAtkController,
              overCtrl: _takinaOverController,
              onImageTap: _showTakinaSkillDialog),
        ],

        const SizedBox(height: 24),

        // 버튼 영역
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
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSideButton("미란다 ⚙️", _showMirandaDialog),
            const SizedBox(width: 8),
            _buildToggleButton(),
          ],
        ),
        const SizedBox(height: 20),

        // --- 결과 카드 영역 ---

        // 1. 타키나 활성화 시 최상단 타겟팅 확인 카드
        if (_useTakina) ...[
          _buildTargetingCheckCard(),
          const SizedBox(height: 12),
        ],

        // 2. 에이다 버스트 시 카드 (원본 유지)
        _buildResultCard("<에이다 버스트 시>", resAdaOnAdaB, resEinOnAdaB, [
          "에이다: ${bufferedNikkes.contains('에이다') ? '미란다(${_mirandaAtkController.text}%) + ' : ''}1스(${_adaS1Controller.text}%) + 버스트(${_adaBurstController.text}%) + 오버",
          "아인: ${bufferedNikkes.contains('아인') ? '미란다(${_mirandaAtkController.text}%) + ' : ''}1스(${_einS1Controller.text}%) + 오버"
        ]),

        const SizedBox(height: 12),

        // 3. 아인 버스트 시 카드 (원본 유지)
        _buildResultCard("<아인 버스트 시>", resAdaOnEinB, resEinOnEinB, [
          "에이다: ${bufferedNikkes.contains('에이다') ? '미란다(${_mirandaAtkController.text}%) + ' : ''}오버",
          "아인: ${bufferedNikkes.contains('아인') ? '미란다(${_mirandaAtkController.text}%) + ' : ''}1스(${_einS1Controller.text}%) + 오버"
        ]),

        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  // --- 추가된 타겟팅 판별 카드 ---
  Widget _buildTargetingCheckCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.gps_fixed, size: 16, color: Colors.orange),
          SizedBox(width: 6),
          Text("미란다 버프 타겟팅 판정 (버스트 전)",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.orange)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _targetUnitColumn("에이다", targetAda, bufferedNikkes.contains('에이다')),
          _targetUnitColumn("아인", targetEin, bufferedNikkes.contains('아인')),
          _targetUnitColumn(
              "타키나", targetTakina, bufferedNikkes.contains('타키나')),
        ]),
        const Divider(height: 20),
        Text("• 미란다 버프 수혜자: ${bufferedNikkes.join(', ')}",
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ]),
    );
  }

  Widget _targetUnitColumn(String name, double val, bool isBuffered) {
    return Column(children: [
      Text(name,
          style: TextStyle(
              fontSize: 11, color: isBuffered ? Colors.black : Colors.grey)),
      const SizedBox(height: 4),
      Text(_formatter.format(val.toInt()),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isBuffered ? Colors.orange : Colors.grey)),
      if (isBuffered)
        Container(
            margin: const EdgeInsets.only(top: 2),
            width: 30,
            height: 2,
            color: Colors.orange),
    ]);
  }

  // --- 헬퍼 위젯 및 기존 함수 (원본 형식 유지) ---
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

  Widget _buildSideButton(String label, VoidCallback onTap) {
    return SizedBox(
        height: 50,
        child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Row(children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.settings, size: 16, color: Colors.orange)
            ])));
  }

  Widget _buildToggleButton() {
    return SizedBox(
        height: 50,
        child: OutlinedButton(
            onPressed: () => setState(() => _useTakina = !_useTakina),
            style: OutlinedButton.styleFrom(
                backgroundColor: _useTakina
                    ? Colors.redAccent.withOpacity(0.1)
                    : Colors.white,
                side: BorderSide(
                    color:
                        _useTakina ? Colors.redAccent : Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text("타키나",
                style: TextStyle(
                    color: _useTakina ? Colors.redAccent : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13))));
  }

  Widget _buildResultCard(
      String title, double adaVal, double einVal, List<String> notes) {
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
          _resRow("에이다", _formatter.format(adaVal.toInt()), adaVal > einVal,
              Colors.orange),
          const SizedBox(height: 4),
          _resRow("아인", _formatter.format(einVal.toInt()), einVal > adaVal,
              Colors.blue),
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

  // --- 다이얼로그 함수부 ---
  void _showMirandaDialog() => _showSettingDialog(
      "미란다 설정", [_buildPopupField("미란다 버스트 공증 (%)", _mirandaAtkController)]);
  void _showAdaSkillDialog() => _showSettingDialog("에이다 스킬 설정", [
        _buildPopupField("1스킬 공증 (%)", _adaS1Controller),
        _buildPopupField("버스트 자공증 (%)", _adaBurstController)
      ]);
  void _showEinSkillDialog() => _showSettingDialog(
      "아인 스킬 설정", [_buildPopupField("1스킬 공증 (%)", _einS1Controller)]);
  void _showTakinaSkillDialog() => _showSettingDialog(
      "타키나 스킬 설정", [_buildPopupField("1스킬 자공증 (%)", _takinaS1Controller)]);

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
}
