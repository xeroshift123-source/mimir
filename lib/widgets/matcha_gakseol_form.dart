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

class MatchaGakseolCalculatorForm extends StatefulWidget {
  const MatchaGakseolCalculatorForm({super.key});

  @override
  State<MatchaGakseolCalculatorForm> createState() =>
      _MatchaGakseolCalculatorFormState();
}

class _MatchaGakseolCalculatorFormState
    extends State<MatchaGakseolCalculatorForm> {
  // 기본값 복구
  final _matchaAtkController = TextEditingController(text: "85,000");
  final _matchaOverController = TextEditingController(text: "0");
  final _gakseolAtkController = TextEditingController(text: "80,000");
  final _gakseolOverController = TextEditingController(text: "0");

  int _mirandaBurstLevel = 10;
  int _matchaS2Level = 10;
  int _gakseolS2Level = 10;

  double resMatchaFinal = 0;
  double resGakseolFinal = 0;

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
            const SnackBar(
                content: Text('동기화된 프로필이 없습니다. 블라블라링크 동기화를 먼저 진행해주세요.')),
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

      Map<String, dynamic> injectConsoleLevels(
          Map<String, dynamic> c, Nikke? n) {
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

      Map<String, dynamic>? matchaChar;
      Map<String, dynamic>? gakseolChar;
      Map<String, dynamic>? mirandaChar;

      for (final char in characters) {
        final nameCode = char['name_code'] as int? ?? 0;
        final mappedName = BlablaMap.characterNames[nameCode] ?? '';
        if (mappedName == '마르차나 : 마린 스터디') matchaChar = char;
        if (mappedName == '스노우 화이트 : 헤비암즈') gakseolChar = char;
        if (mappedName == '미란다') mirandaChar = char;
      }

      if (matchaChar == null && gakseolChar == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('동기화된 데이터에서 마르차나와 스노우화이트을 찾을 수 없습니다.')),
          );
        }
        return;
      }

      final List<Map<String, dynamic>> dialogNikkes = [];
      if (matchaChar != null) {
        dialogNikkes.add({
          'name': '마르차나 : 마린 스터디',
          'char': matchaChar,
          'image': 'assets/nikke/marciana_marine_study.webp'
        });
      }
      if (gakseolChar != null) {
        dialogNikkes.add({
          'name': '스노우 화이트 : 헤비암즈',
          'char': gakseolChar,
          'image': 'assets/nikke/snow_white_heavy_arms.webp'
        });
      }

      if (!mounted) return;
      final selectedCubeLevels = await showDialog<Map<String, SyncOptions>>(
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

      void applyCharStats(Map<String, dynamic> char, String name,
          TextEditingController atkCtrl, TextEditingController overCtrl) {
        final localNikke = nikkeNameMap[name];
        final modChar = injectConsoleLevels(char, localNikke);
        final customOptions = selectedCubeLevels[name] ?? SyncOptions();
        final customCube = customOptions.cubeLevel;
        
        if (customOptions.limitBreak <= 3) {
           modChar['grade'] = customOptions.limitBreak;
           modChar['core'] = 0;
        } else {
           modChar['grade'] = 3;
           modChar['core'] = customOptions.limitBreak - 3;
        }
        modChar['bondLevel'] = customOptions.affection;
        
        final equips = List<dynamic>.from(modChar['equipment'] as List<dynamic>? ?? []);
        for(int i=0; i<equips.length; i++) {
           if (equips[i] == null) continue;
           final eq = Map<String, dynamic>.from(equips[i]);
           if(eq['slot'] == 'head') eq['level'] = customOptions.headLevel;
           if(eq['slot'] == 'torso') eq['level'] = customOptions.torsoLevel;
           if(eq['slot'] == 'arm') eq['level'] = customOptions.armLevel;
           if(eq['slot'] == 'leg') eq['level'] = customOptions.legLevel;
           equips[i] = eq;
        }
        modChar['equipment'] = equips;

        double atk400 = 0;
        double overAtk = 0;

        if (CpCalculator.isInitialized) {
          final cp = CpCalculator.calculateCp(modChar, localNikke,
              targetLevel: 400,
              assumeCube15: false,
              customCubeLevel: customCube);
          if (cp != -1.0) {
            final stats = CpCalculator.calculateTargetStats(modChar, localNikke,
                targetLevel: 400,
                assumeCube15: false,
                customCubeLevel: customCube);
            atk400 = stats['atk'] ?? 0;
          } else {
            atk400 = 0;
          }
        }

        final overloadEquips = modChar['equipment'] as List<dynamic>? ?? [];
        for (final eq in overloadEquips) {
          final options = eq['overloadOptions'] as List<dynamic>? ?? [];
          for (final opt in options) {
            final int id = opt as int? ?? 0;
            if (id >= 7000801 && id <= 7000815) {
              // 공격력 옵션
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
      if (matchaChar != null) {
        applyCharStats(matchaChar, '마르차나 : 마린 스터디', _matchaAtkController, _matchaOverController);
        final skills = matchaChar['skills'] as Map<String, dynamic>? ?? {};
        _matchaS2Level = skills['skill2'] ?? 10;
      }
      if (gakseolChar != null) {
        applyCharStats(gakseolChar, '스노우 화이트 : 헤비암즈', _gakseolAtkController, _gakseolOverController);
        final skills = gakseolChar['skills'] as Map<String, dynamic>? ?? {};
        _gakseolS2Level = skills['skill2'] ?? 10;
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
    _matchaAtkController.dispose();
    _matchaOverController.dispose();
    _gakseolAtkController.dispose();
    _gakseolOverController.dispose();
    super.dispose();
  }

  // 콤마 제거 후 파싱하는 헬퍼 함수
  double _parse(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  void _calculate() {
    setState(() {
      double mirandaVal = SkillData.mirandaBurst[_mirandaBurstLevel];
      double matchaSkill2 = SkillData.matchaS2[_matchaS2Level];

      double nBase = _parse(_matchaAtkController.text);
      double nOver = _parse(_matchaOverController.text) / 100;

      double hBase = _parse(_gakseolAtkController.text);
      double hOver = _parse(_gakseolOverController.text) / 100;
      double gakseolSkill2 = SkillData.gakseolS2[_gakseolS2Level];

      resMatchaFinal = nBase * (1 + nOver + matchaSkill2 + mirandaVal);
      resGakseolFinal = hBase * (1 + hOver + gakseolSkill2 + mirandaVal);

      double maxAtk = resMatchaFinal;
      String rival = "";
      if (resGakseolFinal > maxAtk) {
        maxAtk = resGakseolFinal;
        rival = "스노우화이트";
      }

      if (maxAtk != resMatchaFinal) {
        isError = true;
        double currentTotalBuff =
            nOver + matchaSkill2 + mirandaVal;
        double neededOver = ((maxAtk / nBase) - 1 - currentTotalBuff) * 100;
        resultMessage = "❌ 경고: $rival이 마르차나보다 최종 공격력이 높습니다!";
        needOverloadMessage =
            "마르차나의 오버공증이 최소 ${neededOver.toStringAsFixed(2)}% 더 필요합니다.";
      } else {
        isError = false;
        double secondMaxAtk = resGakseolFinal;
        String secondRival = "스노우화이트";
        double secondRivalBase = hBase;

        double margin = resMatchaFinal - secondMaxAtk;
        double matchaAllowedDecrease = (margin / nBase) * 100;
        double rivalAllowedIncrease = (margin / secondRivalBase) * 100;

        resultMessage = "✅ 정상: 마르차나의 최종 공격력이 가장 높습니다.";
        needOverloadMessage = "💡 현재 상태 기준 여유 수치\n"
            "• 마르차나 오버공증: ${matchaAllowedDecrease.toStringAsFixed(2)}% 더 낮아도 안전합니다.\n"
            "• $secondRival 오버공증: ${rivalAllowedIncrease.toStringAsFixed(2)}% 더 높아도 안전합니다.";
      }
    });
  }

  // ... (Dialog 및 UI Helper 함수들은 이전과 동일하며 _parse 로직 적용됨) ...
  void _showMirandaSettingsDialog() => _showSettingDialog("미란다 설정", (setDialogState) => [
        _buildSliderField("미란다 버스트", _mirandaBurstLevel, (v) => setDialogState(() => _mirandaBurstLevel = v))
      ]);

  void _showMatchaSkillDialog() => _showSettingDialog("마르차나 스킬 설정", (setDialogState) => [
        _buildSliderField("2스킬", _matchaS2Level, (v) => setDialogState(() => _matchaS2Level = v))
      ]);

  void _showGakseolSkillDialog() => _showSettingDialog("스노우화이트 스킬 설정", (setDialogState) => [
        _buildSliderField("2스킬", _gakseolS2Level, (v) => setDialogState(() => _gakseolS2Level = v))
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 24),
        _buildCharacterInputRow(
            label: "마르차나",
            imagePath: "assets/nikke/marciana_marine_study.webp",
            color: Colors.purple,
            atkCtrl: _matchaAtkController,
            overCtrl: _matchaOverController,
            onImageTap: _showMatchaSkillDialog),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
            label: "스노우화이트",
            imagePath: "assets/nikke/snow_white_heavy_arms.webp",
            color: Colors.blue,
            atkCtrl: _gakseolAtkController,
            overCtrl: _gakseolOverController,
            onImageTap: _showGakseolSkillDialog),

        const SizedBox(height: 24),
        // 동기화 자동 입력 버튼
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSyncing ? null : _handleAutoSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync, color: Colors.white),
            label: Text(
              _isSyncing ? "동기화 정보 불러오는 중..." : "동기화 스탯 자동 입력",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButtons(),
        const SizedBox(height: 20),
        _buildResultCard(
          "미란다 버프 포함 최종 결과",
          resMatchaFinal,
          resGakseolFinal,
          [
            "마르차나: 오버 + 2스(Lv.$_matchaS2Level, ${(SkillData.matchaS2[_matchaS2Level]*100).toStringAsFixed(2)}%) + 미란다(Lv.$_mirandaBurstLevel, ${(SkillData.mirandaBurst[_mirandaBurstLevel]*100).toStringAsFixed(2)}%)",
            "스노우화이트: 오버 + 2스(Lv.$_gakseolS2Level, ${(SkillData.gakseolS2[_gakseolS2Level]*100).toStringAsFixed(2)}%) + 미란다(Lv.$_mirandaBurstLevel, ${(SkillData.mirandaBurst[_mirandaBurstLevel]*100).toStringAsFixed(2)}%)",
          ],
          onSettingsTap: _showMirandaSettingsDialog,
        ),
        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(children: [
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
                      style: TextStyle(fontWeight: FontWeight.bold))))),
    ]);
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

  Widget _buildResultCard(
      String title, double matchaVal, double gakseolVal, List<String> notes,
      {VoidCallback? onSettingsTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double max = matchaVal;
    if (gakseolVal > max) max = gakseolVal;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black)),
            GestureDetector(
                onTap: onSettingsTap,
                child: Icon(Icons.settings_outlined,
                    size: 18,
                    color: isDark ? Colors.grey.shade400 : Colors.grey))
          ]),
          const SizedBox(height: 10),
          _resRow("마르차나", _formatter.format(matchaVal.toInt()),
              matchaVal == max, Colors.purple),
          const SizedBox(height: 4),
          _resRow("스노우화이트", _formatter.format(gakseolVal.toInt()),
              gakseolVal == max, Colors.blue),
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
}
