import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:mimir/services/database_service.dart';
import 'package:mimir/utils/cp_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:provider/provider.dart';
import 'package:mimir/utils/blabla_map.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/widgets/cube_level_dialog.dart';

class NayutaHelmCalculatorForm extends StatefulWidget {
  const NayutaHelmCalculatorForm({super.key});

  @override
  State<NayutaHelmCalculatorForm> createState() =>
      _NayutaHelmCalculatorFormState();
}

class _NayutaHelmCalculatorFormState extends State<NayutaHelmCalculatorForm> {
  // 기본값 복구
  final _nayutaAtkController = TextEditingController(text: "85,000");
  final _nayutaOverController = TextEditingController(text: "0");
  final _helmAtkController = TextEditingController(text: "80,000");
  final _helmOverController = TextEditingController(text: "0");

  String? _extraNikkeType;
  final _extraAtkController = TextEditingController(text: "80,000");
  final _extraOverController = TextEditingController(text: "0");
  final _cludBurstController = TextEditingController(text: "62.54");
  final _mirandaAtkController = TextEditingController(text: "40.4");

  double targetNayuta = 0;
  double targetHelm = 0;
  double targetExtra = 0;
  List<String> bufferedNikkes = [];

  double resNayutaFinal = 0;
  double resHelmFinal = 0;
  double resExtraFinal = 0;
  bool nayutaHasMiranda = false;
  bool helmHasMiranda = false;
  bool extraHasMiranda = false;

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

      Map<String, dynamic>? nayutaChar;
      Map<String, dynamic>? helmChar;
      Map<String, dynamic>? cludChar;
      Map<String, dynamic>? cdieselChar;
      
      for (final char in characters) {
        final nameCode = char['name_code'] as int? ?? 0;
        final mappedName = BlablaMap.characterNames[nameCode] ?? '';
        if (mappedName == '나유타') nayutaChar = char;
        if (mappedName == '헬름') helmChar = char;
        if (mappedName == '루드밀라 : 윈터 오너') cludChar = char;
        if (mappedName == '디젤 : 윈터 스위츠') cdieselChar = char;
      }

      if (nayutaChar == null && helmChar == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동기화된 데이터에서 나유타와 헬름을 찾을 수 없습니다.')),
          );
        }
        return;
      }

      final List<Map<String, dynamic>> dialogNikkes = [];
      if (nayutaChar != null) {
        dialogNikkes.add({'name': '나유타', 'char': nayutaChar, 'image': 'assets/nikke/nayuta.webp'});
      }
      if (helmChar != null) {
        dialogNikkes.add({'name': '헬름', 'char': helmChar, 'image': 'assets/nikke/helm.webp'});
      }
      if (_extraNikkeType == 'clud' && cludChar != null) {
        dialogNikkes.add({'name': '루드밀라 : 윈터 오너', 'char': cludChar, 'image': 'assets/nikke/ludmilla_winter_owner.webp'});
      } else if (_extraNikkeType == 'cdiesel' && cdieselChar != null) {
        dialogNikkes.add({'name': '디젤 : 윈터 스위츠', 'char': cdieselChar, 'image': 'assets/nikke/diesel_winter_sweets.webp'});
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

      if (nayutaChar != null) applyCharStats(nayutaChar, '나유타', _nayutaAtkController, _nayutaOverController);
      if (helmChar != null) applyCharStats(helmChar, '헬름', _helmAtkController, _helmOverController);
      if (_extraNikkeType == 'clud' && cludChar != null) {
        applyCharStats(cludChar, '루드밀라 : 윈터 오너', _extraAtkController, _extraOverController);
      } else if (_extraNikkeType == 'cdiesel' && cdieselChar != null) {
        applyCharStats(cdieselChar, '디젤 : 윈터 스위츠', _extraAtkController, _extraOverController);
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
    _nayutaAtkController.dispose();
    _nayutaOverController.dispose();
    _helmAtkController.dispose();
    _helmOverController.dispose();
    _extraAtkController.dispose();
    _extraOverController.dispose();
    _cludBurstController.dispose();
    _mirandaAtkController.dispose();
    super.dispose();
  }

  // 콤마 제거 후 파싱하는 헬퍼 함수
  double _parse(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  void _calculate() {
    setState(() {
      double mirandaVal = _parse(_mirandaAtkController.text) / 100;
      const double nayutaSkill2 = 0.152;

      double nBase = _parse(_nayutaAtkController.text);
      double nOver = _parse(_nayutaOverController.text) / 100;
      double nPre = nBase * (1 + nOver + nayutaSkill2);

      double hBase = _parse(_helmAtkController.text);
      double hOver = _parse(_helmOverController.text) / 100;
      double hPre = hBase * (1 + hOver);

      double eBase = _parse(_extraAtkController.text);
      double eOver = _parse(_extraOverController.text) / 100;
      double ePre = (_extraNikkeType != null) ? (eBase * (1 + eOver)) : -1.0;

      targetNayuta = nPre;
      targetHelm = hPre;
      targetExtra = _extraNikkeType != null ? ePre : 0;

      List<Map<String, dynamic>> comparisonList = [
        {'id': 'nayuta', 'name': '나유타', 'val': nPre},
        {'id': 'helm', 'name': '헬름', 'val': hPre}
      ];
      if (_extraNikkeType != null) {
        String eName = _extraNikkeType == 'clud' ? '클루드' : (_extraNikkeType == 'cdiesel' ? '클디젤' : '일반3버');
        comparisonList.add({'id': 'extra', 'name': eName, 'val': ePre});
      }
      comparisonList.sort((a, b) => b['val'].compareTo(a['val']));
      Set<String> top2 = {comparisonList[0]['id'], comparisonList[1]['id']};
      bufferedNikkes = [comparisonList[0]['name'] as String, comparisonList[1]['name'] as String];

      nayutaHasMiranda = top2.contains('nayuta');
      helmHasMiranda = top2.contains('helm');
      extraHasMiranda = top2.contains('extra');

      resNayutaFinal = nBase *
          (1 + nOver + nayutaSkill2 + (nayutaHasMiranda ? mirandaVal : 0));
      resHelmFinal = hBase * (1 + hOver + (helmHasMiranda ? mirandaVal : 0));

      if (_extraNikkeType != null) {
        double cludBurstVal = _extraNikkeType == 'clud'
            ? _parse(_cludBurstController.text) / 100
            : 0;
        resExtraFinal = eBase *
            (1 + eOver + cludBurstVal + (extraHasMiranda ? mirandaVal : 0));
      }

      double maxAtk = resNayutaFinal;
      String rival = "";
      if (resHelmFinal > maxAtk) {
        maxAtk = resHelmFinal;
        rival = "헬름";
      }
      if (_extraNikkeType != null && resExtraFinal > maxAtk) {
        maxAtk = resExtraFinal;
        rival = (_extraNikkeType == 'clud') ? "클루드" : ((_extraNikkeType == 'cdiesel') ? "클디젤" : "일반 니케");
      }

      if (_extraNikkeType != null && !nayutaHasMiranda) {
        isError = true;
        resultMessage = "❌ 경고: 나유타가 미란다 버프 타겟에서 밀려났습니다!";
        double targetDiff = min(targetHelm, targetExtra) - targetNayuta;
        double neededIncrease = (targetDiff / nBase) * 100;
        needOverloadMessage = "나유타가 미란다 버프를 받으려면 오버공증이 최소 ${neededIncrease.toStringAsFixed(2)}% 더 필요합니다.";
      } else if (maxAtk != resNayutaFinal) {
        isError = true;
        double currentTotalBuff = nOver + nayutaSkill2 + (nayutaHasMiranda ? mirandaVal : 0);
        double neededOver = ((maxAtk / nBase) - 1 - currentTotalBuff) * 100;
        resultMessage = "❌ 경고: $rival이 나유타보다 최종 공격력이 높습니다!";
        needOverloadMessage = "나유타의 오버공증이 최소 ${neededOver.toStringAsFixed(2)}% 더 필요합니다.";
      } else {
        isError = false;
        double secondMaxAtk = resHelmFinal;
        String secondRival = "헬름";
        double secondRivalBase = hBase;

        if (_extraNikkeType != null && resExtraFinal > resHelmFinal) {
          secondMaxAtk = resExtraFinal;
          secondRival = (_extraNikkeType == 'clud') ? "클루드" : ((_extraNikkeType == 'cdiesel') ? "클디젤" : "일반 니케");
          secondRivalBase = eBase;
        }

        double margin = resNayutaFinal - secondMaxAtk;
        double nayutaAllowedDecrease = (margin / nBase) * 100;
        double rivalAllowedIncrease = (margin / secondRivalBase) * 100;

        resultMessage = "✅ 정상: 나유타의 최종 공격력이 가장 높습니다.";
        needOverloadMessage = "💡 현재 상태 기준 여유 수치\n"
            "• 나유타 오버공증: ${nayutaAllowedDecrease.toStringAsFixed(2)}% 더 낮아도 안전합니다.\n"
            "• $secondRival 오버공증: ${rivalAllowedIncrease.toStringAsFixed(2)}% 더 높아도 안전합니다.";
      }
    });
  }

  // ... (Dialog 및 UI Helper 함수들은 이전과 동일하며 _parse 로직 적용됨) ...
  void _showMirandaSettingsDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text("미란다 설정"),
                content: TextField(
                    controller: _mirandaAtkController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "미란다 공증 (%)")),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("취소")),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text("확인"))
                ]));
  }

  void _showBurstDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text("클루드 버스트 설정"),
                content: TextField(
                    controller: _cludBurstController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "자공증 (%)")),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("취소")),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text("확인"))
                ]));
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
            overCtrl: _nayutaOverController),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
            label: "헬름",
            imagePath: "assets/nikke/helm.webp",
            color: Colors.blue,
            atkCtrl: _helmAtkController,
            overCtrl: _helmOverController),
        if (_extraNikkeType != null) ...[
          const SizedBox(height: 16),
          _buildCharacterInputRow(
            label: _extraNikkeType == 'clud' ? "루드밀라:윈터오너" : (_extraNikkeType == 'cdiesel' ? "디젤:윈터스위츠" : "일반3버"),
            imagePath: _extraNikkeType == 'clud'
                ? "assets/nikke/ludmilla_winter_owner.webp"
                : (_extraNikkeType == 'cdiesel' ? "assets/nikke/diesel_winter_sweets.webp" : "assets/nikke/soldiereg.webp"),
            color: Colors.cyan,
            atkCtrl: _extraAtkController,
            overCtrl: _extraOverController,
            onImageTap: _extraNikkeType == 'clud' ? _showBurstDialog : null,
          ),
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
        _buildActionButtons(),
        const SizedBox(height: 20),
        if (_extraNikkeType != null) ...[
          _buildTargetingCheckCard(),
          const SizedBox(height: 12),
        ],
        _buildResultCard(
          "미란다 버프 우선순위 및 최종 결과",
          resNayutaFinal,
          resHelmFinal,
          [
            "나유타: 오버 + 2스(15.2%)${nayutaHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            "헬름: 오버${helmHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            if (_extraNikkeType == 'clud')
              "클루드: 오버 + 자버프(${_cludBurstController.text}%)${extraHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            if (_extraNikkeType == 'cdiesel')
              "클디젤: 오버${extraHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
            if (_extraNikkeType == 'general')
              "일반3버: 오버${extraHasMiranda ? ' + 미란다(${_mirandaAtkController.text}%)' : ''}",
          ],
          extraVal: _extraNikkeType != null ? resExtraFinal : null,
          extraName: _extraNikkeType == 'clud' ? "클루드" : (_extraNikkeType == 'cdiesel' ? "클디젤" : "일반3버"),
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
                                value: 'cdiesel', child: Text("클디젤")),
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
    ]);
  }

  Widget _buildTargetingCheckCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.purple.shade800 : Colors.purple.shade200,
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.gps_fixed, size: 16, color: Colors.purple),
          SizedBox(width: 6),
          Text("미란다 버프 타겟팅 판정 (버스트 전)",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.purple)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _targetUnitColumn("나유타", targetNayuta, nayutaHasMiranda),
          _targetUnitColumn("헬름", targetHelm, helmHasMiranda),
          if (_extraNikkeType != null)
            _targetUnitColumn(
                _extraNikkeType == 'clud' ? "클루드" : (_extraNikkeType == 'cdiesel' ? "클디젤" : "일반3버"),
                targetExtra,
                extraHasMiranda),
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
                  ? Colors.purple
                  : (isDark ? Colors.grey.shade400 : Colors.grey))),
      if (isBuffered)
        Container(
            margin: const EdgeInsets.only(top: 2),
            width: 30,
            height: 2,
            color: Colors.purple),
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
      String title, double nayutaVal, double helmVal, List<String> notes,
      {double? extraVal, String? extraName, VoidCallback? onSettingsTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double max = nayutaVal;
    if (helmVal > max) max = helmVal;
    if (extraVal != null && extraVal > max) max = extraVal;
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
