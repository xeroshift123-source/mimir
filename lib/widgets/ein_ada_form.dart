import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:mimir/services/database_service.dart';
import 'package:mimir/utils/cp_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:provider/provider.dart';
import 'package:mimir/utils/blabla_map.dart';
import 'package:mimir/utils/skill_data.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/widgets/cube_level_dialog.dart';

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
  int _takinaS1Level = 1;

  int _mirandaBurstLevel = 10;
  int _adaS1Level = 10;
  int _adaBurstLevel = 10;
  int _einS1Level = 10;

  // --- 결과 데이터 변수 ---
  double targetAda = 0, targetEin = 0, targetTakina = 0;
  double resAdaOnAdaB = 0, resEinOnAdaB = 0;
  double resAdaOnEinB = 0, resEinOnEinB = 0;
  List<String> bufferedNikkes = []; // 미란다 버프를 받는 니케 명단

  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  String needOverloadMessage = "";
  bool isError = false;
  final NumberFormat _formatter = NumberFormat('#,###');

  bool _isSyncing = false;

  Future<void> _handleAutoSync() async {
    setState(() => _isSyncing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final openId = prefs.getString('last_synced_openid');
      if (openId == null || openId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동기화된 프로필이 없습니다. 블라블라링크 동기화를 먼저 진행해주세요.')),
          );
        }
        return;
      }

      final dbService = DatabaseService();
      final profile = await dbService.getCommanderProfile(openId);
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 데이터를 불러올 수 없습니다.')),
          );
        }
        return;
      }

      final characters = profile['characters'] as List<dynamic>? ?? [];
      final recycleRoom = profile['recycleRoom'] as List<dynamic>? ?? [];
      var localNikkes = context.read<NikkeProvider>().nikkeList;
      if (localNikkes.isEmpty) {
        await context.read<NikkeProvider>().loadNikkes();
        localNikkes = context.read<NikkeProvider>().nikkeList;
      }
      final Map<String, Nikke> nikkeNameMap = {
        for (final n in localNikkes) n.name: n
      };

      Map<String, dynamic> injectConsoleLevels(Map<String, dynamic> c, Nikke? n) {
        int common = 0, classConsole = 0, companyConsole = 0;
        for (final item in recycleRoom) {
          if (item is Map) {
            final tid = item['tid'] as int? ?? 0;
            final lv = item['lv'] as int? ?? 0;
            if (tid == 1001) common = lv;
            if (n != null) {
              if (n.type == 'ATK' && tid == 1101) classConsole = lv;
              if (n.type == 'DEF' && tid == 1102) classConsole = lv;
              if (n.type == 'SUP' && tid == 1103) classConsole = lv;
              final compStr = n.company.toString().split('.').last;
              if (compStr == 'Elysion' && tid == 1201) companyConsole = lv;
              if (compStr == 'Missilis' && tid == 1202) companyConsole = lv;
              if (compStr == 'Tetra' && tid == 1203) companyConsole = lv;
              if (compStr == 'Pilgrim' && tid == 1204) companyConsole = lv;
              if (compStr == 'Abnormal' && tid == 1205) companyConsole = lv;
            }
          }
        }
        final mod = Map<String, dynamic>.from(c);
        mod['commonConsoleLevel'] = common;
        mod['classConsoleLevel'] = classConsole;
        mod['companyConsoleLevel'] = companyConsole;
        return mod;
      }

      Map<String, dynamic>? einChar;
      Map<String, dynamic>? adaChar;
      Map<String, dynamic>? takinaChar;
      Map<String, dynamic>? mirandaChar;
      
      for (final char in characters) {
        final nameCode = char['name_code'] as int? ?? 0;
        final mappedName = BlablaMap.characterNames[nameCode] ?? '';
        if (mappedName == '아인') einChar = char;
        if (mappedName == '에이다') adaChar = char;
        if (mappedName == '타키나') takinaChar = char;
        if (mappedName == '미란다') mirandaChar = char;
      }

      if (einChar == null && adaChar == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동기화된 데이터에서 아인과 에이다를 찾을 수 없습니다.')),
          );
        }
        return;
      }

      final List<Map<String, dynamic>> dialogNikkes = [];
      if (einChar != null) {
        dialogNikkes.add({'name': '아인', 'char': einChar, 'image': 'assets/nikke/ein.webp'});
      }
      if (adaChar != null) {
        dialogNikkes.add({'name': '에이다', 'char': adaChar, 'image': 'assets/nikke/ada.webp'});
      }
      if (_useTakina && takinaChar != null) {
        dialogNikkes.add({'name': '타키나', 'char': takinaChar, 'image': 'assets/nikke/takina.webp'});
      }

      if (!mounted) return;
      final selectedCubeLevels = await showDialog<Map<String, int>>(
        context: context,
        builder: (context) => CubeLevelDialog(nikkes: dialogNikkes),
      );

      if (selectedCubeLevels == null) {
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      if (!CpCalculator.isInitialized) {
        await CpCalculator.init();
      }

      void applyCharStats(Map<String, dynamic> char, String name, TextEditingController atkCtrl, TextEditingController overCtrl) {
        final localNikke = nikkeNameMap[name];
        final modChar = injectConsoleLevels(char, localNikke);
        final customCube = selectedCubeLevels[name] ?? 0;
        
        double atk400 = 0;
        double overAtk = 0;
        
        if (CpCalculator.isInitialized) {
          final cp = CpCalculator.calculateCp(modChar, localNikke, targetLevel: 400, assumeCube15: false, customCubeLevel: customCube);
          if (cp != -1.0) {
            final stats = CpCalculator.calculateTargetStats(modChar, localNikke, targetLevel: 400, assumeCube15: false, customCubeLevel: customCube);
            atk400 = stats['atk'] ?? 0;
          } else {
            atk400 = 0;
          }
        }
        
        final equips = modChar['equipment'] as List<dynamic>? ?? [];
        for (final eq in equips) {
          final options = eq['overloadOptions'] as List<dynamic>? ?? [];
          for (final opt in options) {
            final int id = opt as int? ?? 0;
            if (id >= 7000801 && id <= 7000815) { // 공격력 옵션
              overAtk += BlablaMap.getOptionPercent(id);
            }
          }
        }
        
        atkCtrl.text = atk400 > 0 ? _formatter.format(atk400.round()) : "0";
        overCtrl.text = overAtk.toStringAsFixed(2);
      }

      if (mirandaChar != null) {
        final skills = mirandaChar['skills'] as Map<String, dynamic>? ?? {};
        _mirandaBurstLevel = skills['burst'] ?? 10;
      }
      if (einChar != null) {
        applyCharStats(einChar, '아인', _einAtkController, _einOverController);
        final skills = einChar['skills'] as Map<String, dynamic>? ?? {};
        _einS1Level = skills['skill1'] ?? 10;
      }
      if (adaChar != null) {
        applyCharStats(adaChar, '에이다', _adaAtkController, _adaOverController);
        final skills = adaChar['skills'] as Map<String, dynamic>? ?? {};
        _adaS1Level = skills['skill1'] ?? 10;
        _adaBurstLevel = skills['burst'] ?? 10;
      }
      if (_useTakina && takinaChar != null) {
        applyCharStats(takinaChar, '타키나', _takinaAtkController, _takinaOverController);
        final skills = takinaChar['skills'] as Map<String, dynamic>? ?? {};
        _takinaS1Level = skills['skill1'] ?? 1;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('동기화된 스탯 정보를 성공적으로 불러왔습니다! 🚀')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('자동 입력 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void dispose() {
    _adaAtkController.dispose();
    _adaOverController.dispose();
    _einAtkController.dispose();
    _einOverController.dispose();
    _takinaAtkController.dispose();
    _takinaOverController.dispose();
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
      double tS1 = SkillData.takinaS1[_takinaS1Level];

      double miranda = SkillData.mirandaBurst[_mirandaBurstLevel];
      double aS1 = SkillData.adaS1[_adaS1Level];
      double aB = SkillData.adaBurst[_adaBurstLevel];
      double eS1 = SkillData.einS1[_einS1Level];

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
        resultMessage = "❌ 타키나가 미란다 버프를 탈취 중입니다!";
        double targetDiff = targetTakina - min(targetAda, targetEin);
        double neededDecrease = (targetDiff / tAtk) * 100;
        // 타키나를 낮추거나 다른 애들을 올려야 함
        needOverloadMessage =
            "타키나의 오버공증을 최소 ${neededDecrease.toStringAsFixed(2)}% 낮추거나 딜러들의 오버공증을 높여야 합니다.";
      } else if (resEinOnAdaB > resAdaOnAdaB) {
        isError = true;
        resultMessage = "⚠️ 에이다 버스트 시 아인의 공격력이 더 높습니다.";
        double margin = resEinOnAdaB - resAdaOnAdaB;
        double neededIncrease = (margin / aAtk) * 100;
        needOverloadMessage =
            "에이다의 오버공증이 ${neededIncrease.toStringAsFixed(2)}% 더 필요합니다.";
      } else {
        isError = false;
        resultMessage = "✅ 모든 버프 타겟팅 및 위계가 정상입니다.";

        double marginBurst = resAdaOnAdaB - resEinOnAdaB;
        double adaAllowedDecrease = (marginBurst / aAtk) * 100;
        double einAllowedIncrease = (marginBurst / eAtk) * 100;

        needOverloadMessage = "💡 현재 상태 기준 여유 수치\n"
            "• 에이다 오버공증: ${adaAllowedDecrease.toStringAsFixed(2)}% 더 낮아도 안전합니다.\n"
            "• 아인 오버공증: ${einAllowedIncrease.toStringAsFixed(2)}% 더 높아도 안전합니다.";

        if (_useTakina) {
          double marginTarget = min(targetAda, targetEin) - targetTakina;
          double takinaAllowedIncrease = (marginTarget / tAtk) * 100;
          needOverloadMessage +=
              "\n• 타키나 오버공증: ${takinaAllowedIncrease.toStringAsFixed(2)}% 더 높아도 안전합니다.";
        }
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

        // 동기화 자동 입력 버튼
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSyncing ? null : _handleAutoSync,
            icon: _isSyncing 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.sync, color: Colors.white),
            label: Text(
              _isSyncing ? "동기화 정보 불러오는 중..." : "동기화 스탯 자동 입력",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

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
          "에이다: ${bufferedNikkes.contains('에이다') ? '미란다(Lv.$_mirandaBurstLevel) + ' : ''}1스(Lv.$_adaS1Level) + 버스트(Lv.$_adaBurstLevel) + 오버",
          "아인: ${bufferedNikkes.contains('아인') ? '미란다(Lv.$_mirandaBurstLevel) + ' : ''}1스(Lv.$_einS1Level) + 오버"
        ]),

        const SizedBox(height: 12),

        // 3. 아인 버스트 시 카드 (원본 유지)
        _buildResultCard("<아인 버스트 시>", resAdaOnEinB, resEinOnEinB, [
          "에이다: ${bufferedNikkes.contains('에이다') ? '미란다(Lv.$_mirandaBurstLevel) + ' : ''}오버",
          "아인: ${bufferedNikkes.contains('아인') ? '미란다(Lv.$_mirandaBurstLevel) + ' : ''}1스(Lv.$_einS1Level) + 오버"
        ]),

        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  // --- 추가된 타겟팅 판별 카드 ---
  Widget _buildTargetingCheckCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
          width: 1.5,
        ),
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
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
      ]),
    );
  }

  Widget _targetUnitColumn(String name, double val, bool isBuffered) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Text(name,
          style: TextStyle(
              fontSize: 11,
              color: isBuffered
                  ? (isDark ? Colors.white : Colors.black)
                  : Colors.grey)),
      const SizedBox(height: 4),
      Text(_formatter.format(val.toInt()),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isBuffered
                  ? Colors.orange
                  : (isDark ? Colors.grey.shade400 : Colors.grey))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
            fontSize: 12, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF242424) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300))));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
        height: 50,
        child: OutlinedButton(
            onPressed: () => setState(() => _useTakina = !_useTakina),
            style: OutlinedButton.styleFrom(
                backgroundColor: _useTakina
                    ? Colors.redAccent.withOpacity(isDark ? 0.2 : 0.1)
                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                side: BorderSide(
                    color: _useTakina
                        ? Colors.redAccent
                        : (isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text("타키나",
                style: TextStyle(
                    color: _useTakina
                        ? Colors.redAccent
                        : (isDark ? Colors.grey.shade400 : Colors.grey),
                    fontWeight: FontWeight.bold,
                    fontSize: 13))));
  }

  Widget _buildResultCard(
      String title, double adaVal, double einVal, List<String> notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double maxVal = max(adaVal, einVal);
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          _resRow("에이다", _formatter.format(adaVal.toInt()), adaVal == maxVal,
              Colors.orange),
          const SizedBox(height: 4),
          _resRow("아인", _formatter.format(einVal.toInt()), einVal == maxVal,
              Colors.blue),
          const Divider(height: 20),
          ...notes.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text("• $n",
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade400 : Colors.grey))))
        ]));
  }

  Widget _resRow(String name, String val, bool win, Color winColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(name,
          style: TextStyle(
              fontSize: 12,
              color: win
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
      Text(val,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: win
                  ? winColor
                  : (isDark ? Colors.grey.shade300 : Colors.black87)))
    ]);
  }

  Widget _buildStatusBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color boxColor;
    Color borderColor;
    Color textColor;
    Color detailColor;

    if (isError) {
      boxColor =
          isDark ? Colors.red.shade900.withOpacity(0.4) : Colors.red.shade50;
      borderColor = isDark ? Colors.red.shade900 : Colors.red.shade200;
      textColor = isDark ? Colors.red.shade300 : Colors.red.shade800;
      detailColor = isDark ? Colors.red.shade200 : Colors.red.shade900;
    } else {
      boxColor = isDark
          ? Colors.green.shade900.withOpacity(0.4)
          : Colors.green.shade50;
      borderColor = isDark ? Colors.green.shade900 : Colors.green.shade200;
      textColor = isDark ? Colors.green.shade300 : Colors.green.shade800;
      detailColor = isDark ? Colors.green.shade200 : Colors.green.shade900;
    }

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor)),
        child: Column(
          children: [
            Text(resultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            if (needOverloadMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(needOverloadMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: detailColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]
          ],
        ));
  }

  // --- 다이얼로그 함수부 ---
  void _showMirandaDialog() => _showSettingDialog("미란다 설정", (setDialogState) => [
        _buildSliderField("미란다 버스트", _mirandaBurstLevel, (v) => setDialogState(() => _mirandaBurstLevel = v))
      ]);
  void _showAdaSkillDialog() => _showSettingDialog("에이다 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬", _adaS1Level, (v) => setDialogState(() => _adaS1Level = v)),
        _buildSliderField("버스트", _adaBurstLevel, (v) => setDialogState(() => _adaBurstLevel = v))
      ]);
  void _showEinSkillDialog() => _showSettingDialog("아인 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬", _einS1Level, (v) => setDialogState(() => _einS1Level = v))
      ]);
  void _showTakinaSkillDialog() => _showSettingDialog("타키나 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬", _takinaS1Level, (v) => setDialogState(() => _takinaS1Level = v))
      ]);

  void _showSettingDialog(String title, List<Widget> Function(void Function(void Function())) builder) {
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                  title: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: builder(setDialogState)),
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
                  ]),
            ));
  }

  Widget _buildSliderField(String label, int currentLevel, ValueChanged<int> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87)),
            Text("Lv.$currentLevel",
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
          ],
        ),
        Slider(
          value: currentLevel.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: Colors.orange,
          onChanged: (val) => onChanged(val.toInt()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
