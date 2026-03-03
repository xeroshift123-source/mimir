import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NayutaHelmCalculatorForm extends StatefulWidget {
  const NayutaHelmCalculatorForm({super.key});

  @override
  State<NayutaHelmCalculatorForm> createState() =>
      _NayutaHelmCalculatorFormState();
}

class _NayutaHelmCalculatorFormState extends State<NayutaHelmCalculatorForm> {
  final _nayutaAtkController = TextEditingController(text: "109834");
  final _nayutaOverController = TextEditingController(text: "22.21");
  final _helmAtkController = TextEditingController(text: "135680");
  final _helmOverController = TextEditingController(text: "5.47");

  String? _extraNikkeType;
  final _extraAtkController = TextEditingController(text: "114562");
  final _extraOverController = TextEditingController(text: "13.93");

  final _cludBurstController = TextEditingController(text: "62.54");
  // [추가] 미란다 버스트 계수 컨트롤러 (기본값 40.4)
  final _mirandaAtkController = TextEditingController(text: "40.4");

  double resNayutaFinal = 0;
  double resHelmFinal = 0;
  double resExtraFinal = 0;

  bool nayutaHasMiranda = false;
  bool helmHasMiranda = false;
  bool extraHasMiranda = false;

  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  bool isError = false;

  final NumberFormat _formatter = NumberFormat('#,###');

  @override
  void dispose() {
    _nayutaAtkController.dispose();
    _nayutaOverController.dispose();
    _helmAtkController.dispose();
    _helmOverController.dispose();
    _extraAtkController.dispose();
    _extraOverController.dispose();
    _cludBurstController.dispose();
    _mirandaAtkController.dispose(); // 해제 추가
    super.dispose();
  }

  // [신규] 미란다 설정 다이얼로그
  void _showMirandaSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("미란다 버프 설정",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "미란다 버스트의 공격력 증가 수치(%)를 입력하세요.\n10레벨 - 40.4%\n7레벨 - 34.89%",
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _mirandaAtkController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "미란다 공증 (%)",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("확인", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBurstDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("클루드 버스트 수치 설정",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("클루드의 버스트 공증 수치(%)를 입력하세요.",
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _cludBurstController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "버스트 공증 (%)",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("확인", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _calculate() {
    setState(() {
      // [수정] 입력받은 미란다 계수 사용
      double mirandaVal =
          (double.tryParse(_mirandaAtkController.text) ?? 40.4) / 100;
      double mirandaMult = 1 + mirandaVal;
      const double nayutaSkill2 = 1.152;

      double nBase = double.tryParse(_nayutaAtkController.text) ?? 0;
      double nOver = (double.tryParse(_nayutaOverController.text) ?? 0) / 100;
      double nPre = nBase * (1 + nOver) * nayutaSkill2;

      double hBase = double.tryParse(_helmAtkController.text) ?? 0;
      double hOver = (double.tryParse(_helmOverController.text) ?? 0) / 100;
      double hPre = hBase * (1 + hOver);

      double eBase = double.tryParse(_extraAtkController.text) ?? 0;
      double eOver = (double.tryParse(_extraOverController.text) ?? 0) / 100;
      double ePre = (_extraNikkeType != null) ? (eBase * (1 + eOver)) : -1.0;

      List<Map<String, dynamic>> comparisonList = [
        {'id': 'nayuta', 'val': nPre},
        {'id': 'helm', 'val': hPre},
      ];
      if (_extraNikkeType != null) {
        comparisonList.add({'id': 'extra', 'val': ePre});
      }

      comparisonList.sort((a, b) => b['val'].compareTo(a['val']));
      Set<String> top2 = {comparisonList[0]['id'], comparisonList[1]['id']};

      nayutaHasMiranda = top2.contains('nayuta');
      helmHasMiranda = top2.contains('helm');
      extraHasMiranda = top2.contains('extra');

      resNayutaFinal = nPre * (nayutaHasMiranda ? mirandaMult : 1.0);
      resHelmFinal = hPre * (helmHasMiranda ? mirandaMult : 1.0);

      if (_extraNikkeType != null) {
        double currentExtra = ePre * (extraHasMiranda ? mirandaMult : 1.0);
        if (_extraNikkeType == 'clud') {
          double cludBurstVal =
              (double.tryParse(_cludBurstController.text) ?? 0) / 100;
          resExtraFinal = currentExtra * (1 + cludBurstVal);
        } else {
          resExtraFinal = currentExtra;
        }
      }

      double maxAtk = resNayutaFinal;
      String rival = "";
      if (resHelmFinal > maxAtk) {
        maxAtk = resHelmFinal;
        rival = "헬름";
      }
      if (_extraNikkeType != null && resExtraFinal > maxAtk) {
        maxAtk = resExtraFinal;
        rival = (_extraNikkeType == 'clud') ? "클루드" : "일반 니케";
      }

      if (maxAtk == resNayutaFinal) {
        resultMessage = "✅ 정상: 나유타의 최종 공격력이 가장 높습니다.";
        isError = false;
      } else {
        isError = true;
        double targetMult = nayutaHasMiranda ? mirandaMult : 1.0;
        double requiredTotalRatio =
            maxAtk / (nBase * nayutaSkill2 * targetMult);
        double neededOver = (requiredTotalRatio - (1 + nOver)) * 100;
        resultMessage =
            "❌ 경고: $rival이 나유타보다 높습니다!\n나유타의 오버공증이 ${neededOver.toStringAsFixed(2)}% 더 필요합니다.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 24),
        _buildCharacterInputRow(
          label: "나유타",
          imagePath: "assets/nikke/nayuta.webp",
          color: Colors.purple,
          atkCtrl: _nayutaAtkController,
          overCtrl: _nayutaOverController,
        ),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
          label: "헬름",
          imagePath: "assets/nikke/helm.webp",
          color: Colors.blue,
          atkCtrl: _helmAtkController,
          overCtrl: _helmOverController,
        ),
        if (_extraNikkeType != null) ...[
          const SizedBox(height: 16),
          _buildCharacterInputRow(
            label: _extraNikkeType == 'clud' ? "루드밀라:윈터오너" : "일반3버",
            imagePath: _extraNikkeType == 'clud'
                ? "assets/nikke/ludmilla_winter_owner.webp"
                : "assets/nikke/soldiereg.webp",
            color: Colors.cyan,
            atkCtrl: _extraAtkController,
            overCtrl: _extraOverController,
            onImageTap: _extraNikkeType == 'clud' ? _showBurstDialog : null,
          ),
        ],
        const SizedBox(height: 24),
        _buildActionButtons(),
        const SizedBox(height: 20),
        _buildResultCard(
          "미란다 버프 우선순위 및 최종 결과",
          resNayutaFinal, resHelmFinal,
          [
            "나유타: 오버 + 2스(15.2%)${nayutaHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            "헬름: 오버${helmHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            if (_extraNikkeType == 'clud')
              "클루드: 오버 + 버스트(${_cludBurstController.text}%)${extraHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            if (_extraNikkeType == 'general')
              "일반3버: 오버${extraHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
          ],
          extraVal: _extraNikkeType != null ? resExtraFinal : null,
          extraName: _extraNikkeType == 'clud' ? "클루드" : "일반3버",
          onSettingsTap: _showMirandaSettingsDialog, // 설정 아이콘 연결
        ),
        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  // --- UI 컴포넌트 ---

  Widget _buildActionButtons() {
    return Row(
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
                    child: const Text("최종 결과 계산",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15))))),
        const SizedBox(width: 8),
        Expanded(
            flex: 1,
            child: SizedBox(
                height: 50,
                child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: PopupMenuButton<String>(
                        onSelected: (val) => setState(() =>
                            _extraNikkeType = (val == 'remove' ? null : val)),
                        itemBuilder: (context) => [
                              const PopupMenuItem(
                                  value: 'clud', child: Text("클루드")),
                              const PopupMenuItem(
                                  value: 'general', child: Text("일반 니케")),
                              const PopupMenuItem(
                                  value: 'remove',
                                  child: Text("제거",
                                      style: TextStyle(color: Colors.red)))
                            ],
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("3버 추가",
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Icon(Icons.arrow_drop_down, color: Colors.orange)
                            ]))))),
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
    return Row(
      children: [
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
            if (onImageTap != null)
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
        ])),
      ],
    );
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
      String title, double nayutaVal, double helmVal, List<String> notes,
      {double? extraVal, String? extraName, VoidCallback? onSettingsTap}) {
    double max = nayutaVal;
    if (helmVal > max) max = helmVal;
    if (extraVal != null && extraVal > max) max = extraVal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [수정] 결과 카드 헤더 영역에 설정 아이콘 추가
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              GestureDetector(
                onTap: onSettingsTap,
                child: const Icon(Icons.settings_outlined,
                    size: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _resRow("나유타", _formatter.format(nayutaVal.toInt()), nayutaVal == max,
              Colors.purple),
          const SizedBox(height: 4),
          _resRow("헬름", _formatter.format(helmVal.toInt()), helmVal == max,
              Colors.blue),
          if (extraVal != null) ...[
            const SizedBox(height: 4),
            _resRow(extraName!, _formatter.format(extraVal.toInt()),
                extraVal == max, Colors.cyan)
          ],
          const Divider(height: 20),
          ...notes.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text("• $n",
                  style: const TextStyle(fontSize: 10, color: Colors.grey)))),
        ],
      ),
    );
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
