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
import 'package:mimir/models/enums.dart';
import 'package:mimir/widgets/cube_level_dialog.dart';

class MatchaGakseolCalculatorForm extends StatefulWidget {
  const MatchaGakseolCalculatorForm({super.key});

  @override
  State<MatchaGakseolCalculatorForm> createState() =>
      _MatchaGakseolCalculatorFormState();
}

class _MatchaGakseolCalculatorFormState
    extends State<MatchaGakseolCalculatorForm> {
  final _nikke1AtkController = TextEditingController(text: "80,000");
  final _nikke1OverController = TextEditingController(text: "0");

  final _nikke2AtkController = TextEditingController(text: "80,000");
  final _nikke2OverController = TextEditingController(text: "0");

  bool _useNayuta = false;
  final _nayutaAtkController = TextEditingController(text: "85,000");
  final _nayutaOverController = TextEditingController(text: "0");
  int _nayutaS2Level = 10;

  Nikke? _nikke1;
  Nikke? _nikke2;

  int _mirandaBurstLevel = 10;

  // 슬롯 1 개별 스킬 레벨
  int _nikke1MatchaS2Level = 10;
  int _nikke1GakseolS2Level = 10;
  int _nikke1AdaS1Level = 10;
  int _nikke1AdaBurstLevel = 10;

  // 슬롯 2 개별 스킬 레벨
  int _nikke2MatchaS2Level = 10;
  int _nikke2GakseolS2Level = 10;
  int _nikke2AdaS1Level = 10;
  int _nikke2AdaBurstLevel = 10;

  double resNikke1FinalOnAdaB = 0;
  double resNikke1FinalOnOtherB = 0;
  double resNikke2FinalOnAdaB = 0;
  double resNikke2FinalOnOtherB = 0;
  double resNayutaFinal = 0;

  bool nayutaHasMiranda = false;

  List<String> bufferedNikkes = [];

  String resultMessage = "니케 1과 니케 2를 선택하고 계산하기를 눌러주세요.";
  String needOverloadMessage = "";
  bool isError = false;
  final NumberFormat _formatter = NumberFormat('#,###');

  bool _isSyncing = false;

  final Set<String> allowed7NikkeNames = {
    '마르차나 : 마린 스터디',
    '스노우 화이트 : 헤비암즈',
    '미하라 : 본딩 체인',
    '헬름',
    '에이다',
    '디젤 : 윈터 스위츠',
    '프리바티',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<NikkeProvider>();
      if (provider.nikkeList.isEmpty) {
        await provider.loadNikkes();
      }
    });
  }

  Future<void> _handleAutoSync() async {
    if (_nikke1 == null && _nikke2 == null && !_useNayuta) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('동기화를 진행할 니케를 먼저 선택해주세요.')),
        );
      }
      return;
    }

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
      if (!mounted) return;
      var localNikkes = context.read<NikkeProvider>().nikkeList;
      if (localNikkes.isEmpty) {
        await context.read<NikkeProvider>().loadNikkes();
        if (!mounted) return;
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

      Map<String, dynamic>? nikke1Char;
      Map<String, dynamic>? nikke2Char;
      Map<String, dynamic>? nayutaChar;
      Map<String, dynamic>? mirandaChar;

      final n1Name = _nikke1?.name ?? '';
      final n2Name = _nikke2?.name ?? '';

      for (final char in characters) {
        final nameCode = char['name_code'] as int? ?? 0;
        final mappedName = BlablaMap.characterNames[nameCode] ?? '';
        if (n1Name.isNotEmpty && (mappedName == n1Name || (n1Name == '에이다' && mappedName == '에이다'))) nikke1Char = char;
        if (n2Name.isNotEmpty && (mappedName == n2Name || (n2Name == '에이다' && mappedName == '에이다'))) nikke2Char = char;
        if (mappedName == '나유타') nayutaChar = char;
        if (mappedName == '미란다') mirandaChar = char;
      }

      if (nikke1Char == null && nikke2Char == null && (!_useNayuta || nayutaChar == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동기화된 데이터에서 선택한 니케 정보를 찾을 수 없습니다.')),
          );
        }
        return;
      }

      final List<Map<String, dynamic>> dialogNikkes = [];
      if (nikke1Char != null && _nikke1 != null) {
        dialogNikkes.add({
          'name': _nikke1!.name,
          'char': nikke1Char,
          'image': _nikke1!.imageUrl,
        });
      }
      if (nikke2Char != null && _nikke2 != null && _nikke2!.name != _nikke1?.name) {
        dialogNikkes.add({
          'name': _nikke2!.name,
          'char': nikke2Char,
          'image': _nikke2!.imageUrl,
        });
      }
      if (_useNayuta && nayutaChar != null) {
        dialogNikkes.add({
          'name': '나유타',
          'char': nayutaChar,
          'image': 'assets/nikke/nayuta.webp',
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

      if (nikke1Char != null && _nikke1 != null) {
        applyCharStats(nikke1Char, _nikke1!.name, _nikke1AtkController, _nikke1OverController);
        final skills = nikke1Char['skills'] as Map<String, dynamic>? ?? {};
        if (_nikke1!.name == '마르차나 : 마린 스터디') {
          _nikke1MatchaS2Level = skills['skill2'] ?? 10;
        } else if (_nikke1!.name == '스노우 화이트 : 헤비암즈') {
          _nikke1GakseolS2Level = skills['skill2'] ?? 10;
        } else if (_nikke1!.name == '에이다') {
          _nikke1AdaS1Level = skills['skill1'] ?? 10;
          _nikke1AdaBurstLevel = skills['burst'] ?? 10;
        }
      }
      if (nikke2Char != null && _nikke2 != null) {
        applyCharStats(nikke2Char, _nikke2!.name, _nikke2AtkController, _nikke2OverController);
        final skills = nikke2Char['skills'] as Map<String, dynamic>? ?? {};
        if (_nikke2!.name == '마르차나 : 마린 스터디') {
          _nikke2MatchaS2Level = skills['skill2'] ?? 10;
        } else if (_nikke2!.name == '스노우 화이트 : 헤비암즈') {
          _nikke2GakseolS2Level = skills['skill2'] ?? 10;
        } else if (_nikke2!.name == '에이다') {
          _nikke2AdaS1Level = skills['skill1'] ?? 10;
          _nikke2AdaBurstLevel = skills['burst'] ?? 10;
        }
      }
      if (_useNayuta && nayutaChar != null) {
        applyCharStats(nayutaChar, '나유타', _nayutaAtkController, _nayutaOverController);
        final skills = nayutaChar['skills'] as Map<String, dynamic>? ?? {};
        _nayutaS2Level = skills['skill2'] ?? 10;
      }

      if (mounted) {
        _calculate();
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
    _nikke1AtkController.dispose();
    _nikke1OverController.dispose();
    _nikke2AtkController.dispose();
    _nikke2OverController.dispose();
    _nayutaAtkController.dispose();
    _nayutaOverController.dispose();
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  void _calculate() {
    if (_nikke1 == null || _nikke2 == null) {
      setState(() {
        isError = false;
        resultMessage = "니케 1과 니케 2를 모두 선택해 주세요.";
        needOverloadMessage = "";
        bufferedNikkes = [];
        resNikke1FinalOnAdaB = 0;
        resNikke1FinalOnOtherB = 0;
        resNikke2FinalOnAdaB = 0;
        resNikke2FinalOnOtherB = 0;
        resNayutaFinal = 0;
        nayutaHasMiranda = false;
      });
      return;
    }

    setState(() {
      double mirandaVal = SkillData.mirandaBurst[_mirandaBurstLevel];

      // 슬롯 1 스탯 & 스킬
      double n1Base = _parse(_nikke1AtkController.text);
      double n1Over = _parse(_nikke1OverController.text) / 100;
      String n1Name = _nikke1!.name;
      double n1TargetSkill = 0.0;
      double n1BattleSkillSelf = 0.0;

      if (n1Name == '마르차나 : 마린 스터디') {
        n1TargetSkill = SkillData.matchaS2[_nikke1MatchaS2Level];
        n1BattleSkillSelf = n1TargetSkill;
      } else if (n1Name == '스노우 화이트 : 헤비암즈') {
        n1TargetSkill = SkillData.gakseolS2[_nikke1GakseolS2Level];
        n1BattleSkillSelf = n1TargetSkill;
      } else if (n1Name == '에이다') {
        n1TargetSkill = 0.0; // 사전 타겟팅: 에이다 1스/버스트 미반영
        n1BattleSkillSelf = 0.0;
      }

      double n1Target = n1Base * (1 + n1Over + n1TargetSkill);

      // 슬롯 2 스탯 & 스킬
      double n2Base = _parse(_nikke2AtkController.text);
      double n2Over = _parse(_nikke2OverController.text) / 100;
      String n2Name = _nikke2!.name;
      double n2TargetSkill = 0.0;
      double n2BattleSkillSelf = 0.0;

      if (n2Name == '마르차나 : 마린 스터디') {
        n2TargetSkill = SkillData.matchaS2[_nikke2MatchaS2Level];
        n2BattleSkillSelf = n2TargetSkill;
      } else if (n2Name == '스노우 화이트 : 헤비암즈') {
        n2TargetSkill = SkillData.gakseolS2[_nikke2GakseolS2Level];
        n2BattleSkillSelf = n2TargetSkill;
      } else if (n2Name == '에이다') {
        n2TargetSkill = 0.0;
        n2BattleSkillSelf = 0.0;
      }

      double n2Target = n2Base * (1 + n2Over + n2TargetSkill);

      // 나유타 스탯 & 스킬
      double nayutaBase = _parse(_nayutaAtkController.text);
      double nayutaOver = _parse(_nayutaOverController.text) / 100;
      double nayutaSkill2 = SkillData.nayutaS2[_nayutaS2Level];
      double nayutaTarget = nayutaBase * (1 + nayutaOver + nayutaSkill2);

      // 미란다 사전 타겟팅 추출 (상위 2명이 미란다 버프 수혜)
      List<Map<String, dynamic>> targetUnits = [
        {'id': 'n1', 'name': n1Name, 'val': n1Target},
        {'id': 'n2', 'name': n2Name, 'val': n2Target},
      ];
      if (_useNayuta) {
        targetUnits.add({'id': 'nayuta', 'name': '나유타', 'val': nayutaTarget});
      }

      targetUnits.sort((a, b) => (b['val'] as double).compareTo(a['val'] as double));

      Set<String> mirandaBuffedIds = {};
      if (targetUnits.isNotEmpty) mirandaBuffedIds.add(targetUnits[0]['id'] as String);
      if (targetUnits.length > 1) mirandaBuffedIds.add(targetUnits[1]['id'] as String);
      if (targetUnits.length > 2 && targetUnits[1]['val'] == targetUnits[2]['val']) {
        mirandaBuffedIds.add(targetUnits[2]['id'] as String);
      }

      bool n1HasMiranda = mirandaBuffedIds.contains('n1');
      bool n2HasMiranda = mirandaBuffedIds.contains('n2');
      nayutaHasMiranda = mirandaBuffedIds.contains('nayuta');

      bufferedNikkes = [];
      if (n1HasMiranda) bufferedNikkes.add(n1Name);
      if (n2HasMiranda) bufferedNikkes.add(n2Name);
      if (_useNayuta && nayutaHasMiranda) bufferedNikkes.add('나유타');

      // 에이다 스킬 관련 변수 판정
      bool isN1Ada = (n1Name == '에이다');
      bool isN2Ada = (n2Name == '에이다');

      // 에이다 1스킬 합연산 버프액 = 에이다 기본 공격력 * 에이다 1스킬%
      double adaBuffAtkAmount = 0.0;
      if (isN1Ada) {
        adaBuffAtkAmount = n1Base * SkillData.adaS1[_nikke1AdaS1Level];
      } else if (isN2Ada) {
        adaBuffAtkAmount = n2Base * SkillData.adaS1[_nikke2AdaS1Level];
      }

      // <에이다 버스트 시>
      // 에이다 본인: 기본공 * (1 + 오버공증 + 미란다 + 1스% + 버스트%)
      double n1FinalOnAda = n1Base * (1 + n1Over + n1BattleSkillSelf + (n1HasMiranda ? mirandaVal : 0));
      if (isN1Ada) {
        n1FinalOnAda = n1Base * (1 + n1Over + (n1HasMiranda ? mirandaVal : 0) + SkillData.adaS1[_nikke1AdaS1Level] + SkillData.adaBurst[_nikke1AdaBurstLevel]);
      }
      resNikke1FinalOnAdaB = n1FinalOnAda;

      double n2FinalOnAda = n2Base * (1 + n2Over + n2BattleSkillSelf + (n2HasMiranda ? mirandaVal : 0));
      if (isN2Ada) {
        n2FinalOnAda = n2Base * (1 + n2Over + (n2HasMiranda ? mirandaVal : 0) + SkillData.adaS1[_nikke2AdaS1Level] + SkillData.adaBurst[_nikke2AdaBurstLevel]);
      }
      resNikke2FinalOnAdaB = n2FinalOnAda;

      // <다른 니케 버스트 시>
      // 에이다 본인: 기본공 * (1 + 오버공증 + 미란다)
      // 버스트 니케: 본인 전투공격력 + 에이다 1스 버프액(adaBuffAtkAmount)
      if (isN1Ada) {
        resNikke1FinalOnOtherB = n1Base * (1 + n1Over + (n1HasMiranda ? mirandaVal : 0));
        resNikke2FinalOnOtherB = n2Base * (1 + n2Over + n2BattleSkillSelf + (n2HasMiranda ? mirandaVal : 0)) + adaBuffAtkAmount;
      } else if (isN2Ada) {
        resNikke1FinalOnOtherB = n1Base * (1 + n1Over + n1BattleSkillSelf + (n1HasMiranda ? mirandaVal : 0)) + adaBuffAtkAmount;
        resNikke2FinalOnOtherB = n2Base * (1 + n2Over + (n2HasMiranda ? mirandaVal : 0));
      } else {
        resNikke1FinalOnOtherB = n1Base * (1 + n1Over + n1BattleSkillSelf + (n1HasMiranda ? mirandaVal : 0));
        resNikke2FinalOnOtherB = n2Base * (1 + n2Over + n2BattleSkillSelf + (n2HasMiranda ? mirandaVal : 0));
      }

      resNayutaFinal = nayutaBase * (1 + nayutaOver + nayutaSkill2 + (nayutaHasMiranda ? mirandaVal : 0));

      // 판정 메시지 및 오류 판정 (1번 니케 미란다 버프 수령이 최우선 목적)
      if (!n1HasMiranda) {
        // 1번 니케가 미란다 버프를 받지 못한 경우 (목표 실패)
        isError = true;
        resultMessage = "❌ 경고: 1번 니케($n1Name)가 미란다 버프를 적용받지 못하고 있습니다!";
        double targetCutoff = (targetUnits.length > 1) ? (targetUnits[1]['val'] as double) : 0;
        double margin = targetCutoff - n1Target;
        double neededIncrease = (n1Base > 0) ? (margin / n1Base) * 100 : 0;
        needOverloadMessage = "• $n1Name이(가) 미란다 버프를 받으려면 오버공증이 최소 ${neededIncrease.toStringAsFixed(2)}% 더 필요합니다.";
      } else {
        // 1번 니케가 미란다 버프를 정상적으로 받은 경우 (목표 성공 -> 초록색)
        if (isN1Ada || isN2Ada) {
          String otherName = isN1Ada ? n2Name : n1Name;
          double otherFinalOnOtherB = isN1Ada ? resNikke2FinalOnOtherB : resNikke1FinalOnOtherB;
          double adaFinalOnOtherB = isN1Ada ? resNikke1FinalOnOtherB : resNikke2FinalOnOtherB;
          double otherBase = isN1Ada ? n2Base : n1Base;
          double adaBase = isN1Ada ? n1Base : n2Base;

          if (adaFinalOnOtherB > otherFinalOnOtherB) {
            isError = true;
            resultMessage = "❌ 경고: $otherName 버스트 시 에이다의 공격력이 $otherName보다 높습니다!";
            double margin = adaFinalOnOtherB - otherFinalOnOtherB;
            double neededIncrease = (otherBase > 0) ? (margin / otherBase) * 100 : 0;
            double neededDecrease = (adaBase > 0) ? (margin / adaBase) * 100 : 0;
            needOverloadMessage = "• $otherName이(가) $otherName 버스트 시 에이다보다 공격력이 높으려면 오버공증이 최소 ${neededIncrease.toStringAsFixed(2)}% 더 필요합니다.\n"
                "• 또는 에이다의 오버공증을 ${neededDecrease.toStringAsFixed(2)}% 낮춰야 합니다.";
          } else {
            isError = false;
            resultMessage = "✅ 정상: $n1Name이(가) 미란다 버프를 정상 적용받습니다.";
            List<String> details = [];

            if (_useNayuta && nayutaHasMiranda && !n2HasMiranda) {
              double margin = nayutaTarget - n2Target;
              double neededIncrease = (n2Base > 0) ? (margin / n2Base) * 100 : 0;
              double neededNayutaDecrease = (nayutaBase > 0) ? (margin / nayutaBase) * 100 : 0;
              details.add("💡 참고: 나유타가 $n2Name 대신 2번째 미란다 버프를 수령 중입니다.");
              details.add("• $n2Name이(가) 나유타로부터 미란다 버프를 되찾으려면 오버공증이 최소 ${neededIncrease.toStringAsFixed(2)}% 더 필요합니다.");
              details.add("• 또는 나유타의 오버공증을 ${neededNayutaDecrease.toStringAsFixed(2)}% 낮춰야 합니다.");
            } else {
              double marginOtherB = otherFinalOnOtherB - adaFinalOnOtherB;
              double otherAllowedDecrease = (otherBase > 0) ? (marginOtherB / otherBase) * 100 : 0;
              double adaAllowedIncrease = (adaBase > 0) ? (marginOtherB / adaBase) * 100 : 0;
              details.add("💡 현재 상태 기준 여유 수치");
              details.add("• $otherName 오버공증: ${otherAllowedDecrease.toStringAsFixed(2)}% 더 낮아도 안전합니다.");
              details.add("• 에이다 오버공증: ${adaAllowedIncrease.toStringAsFixed(2)}% 더 높아도 안전합니다.");
            }
            needOverloadMessage = details.join("\n");
          }
        } else {
          // 에이다 미포함 일반 조합
          isError = false;
          resultMessage = "✅ 정상: $n1Name이(가) 미란다 버프를 정상 적용받습니다.";
          List<String> details = [];

          if (_useNayuta && nayutaHasMiranda && !n2HasMiranda) {
            double margin = nayutaTarget - n2Target;
            double neededIncrease = (n2Base > 0) ? (margin / n2Base) * 100 : 0;
            double neededNayutaDecrease = (nayutaBase > 0) ? (margin / nayutaBase) * 100 : 0;
            details.add("💡 참고: 나유타가 $n2Name 대신 2번째 미란다 버프를 수령 중입니다.");
            details.add("• $n2Name이(가) 나유타로부터 미란다 버프를 되찾으려면 오버공증이 최소 ${neededIncrease.toStringAsFixed(2)}% 더 필요합니다.");
            details.add("• 또는 나유타의 오버공증을 ${neededNayutaDecrease.toStringAsFixed(2)}% 낮춰야 합니다.");
          } else {
            if (n1Target != n2Target) {
              String winnerName = n1HasMiranda ? n1Name : n2Name;
              String loserName = n1HasMiranda ? n2Name : n1Name;
              double winnerTarget = n1HasMiranda ? n1Target : n2Target;
              double loserTarget = n1HasMiranda ? n2Target : n1Target;
              double winnerBase = n1HasMiranda ? n1Base : n2Base;
              double loserBase = n1HasMiranda ? n2Base : n1Base;

              double margin = winnerTarget - loserTarget;
              double winnerAllowedDecrease = (winnerBase > 0) ? (margin / winnerBase) * 100 : 0;
              double loserNeededIncrease = (loserBase > 0) ? (margin / loserBase) * 100 : 0;

              details.add("💡 현재 상태 기준 여유 수치");
              details.add("• $winnerName 오버공증: ${winnerAllowedDecrease.toStringAsFixed(2)}% 더 낮아도 안전합니다.");
              details.add("• $loserName 오버공증: ${loserNeededIncrease.toStringAsFixed(2)}% 더 높아도 버프를 탈취할 수 있습니다.");
            } else {
              resultMessage = "✅ 두 니케의 사전 공격력이 동일하여 모두 미란다 버프를 적용받습니다.";
            }
          }
          needOverloadMessage = details.join("\n");
        }
      }
    });
  }

  void _showMirandaSettingsDialog() => _showSettingDialog("미란다 설정", (setDialogState) => [
        _buildSliderField("미란다 버스트", _mirandaBurstLevel, (v) => setDialogState(() => _mirandaBurstLevel = v))
      ]);

  void _showNayutaSettingsDialog() => _showSettingDialog("나유타 설정", (setDialogState) => [
        _buildSliderField("2스킬 (자공증)", _nayutaS2Level, (v) => setDialogState(() => _nayutaS2Level = v))
      ]);

  void _showNikkeSkillDialog(int slotIndex) {
    final nikke = slotIndex == 1 ? _nikke1 : _nikke2;
    final name = nikke?.name ?? '니케';

    if (name == '마르차나 : 마린 스터디') {
      _showSettingDialog("$name 스킬 설정", (setDialogState) => [
        _buildSliderField("2스킬", slotIndex == 1 ? _nikke1MatchaS2Level : _nikke2MatchaS2Level, (v) {
          setDialogState(() {
            if (slotIndex == 1) {
              _nikke1MatchaS2Level = v;
            } else {
              _nikke2MatchaS2Level = v;
            }
          });
        })
      ]);
    } else if (name == '스노우 화이트 : 헤비암즈') {
      _showSettingDialog("$name 스킬 설정", (setDialogState) => [
        _buildSliderField("2스킬", slotIndex == 1 ? _nikke1GakseolS2Level : _nikke2GakseolS2Level, (v) {
          setDialogState(() {
            if (slotIndex == 1) {
              _nikke1GakseolS2Level = v;
            } else {
              _nikke2GakseolS2Level = v;
            }
          });
        })
      ]);
    } else if (name == '에이다') {
      _showSettingDialog("$name 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬 (아군 공증)", slotIndex == 1 ? _nikke1AdaS1Level : _nikke2AdaS1Level, (v) {
          setDialogState(() {
            if (slotIndex == 1) {
              _nikke1AdaS1Level = v;
            } else {
              _nikke2AdaS1Level = v;
            }
          });
        }),
        _buildSliderField("버스트 (자공증)", slotIndex == 1 ? _nikke1AdaBurstLevel : _nikke2AdaBurstLevel, (v) {
          setDialogState(() {
            if (slotIndex == 1) {
              _nikke1AdaBurstLevel = v;
            } else {
              _nikke2AdaBurstLevel = v;
            }
          });
        }),
      ]);
    }
  }

  void _showNikkeSelectorModal(int slotIndex) {
    var rawNikkes = List<Nikke>.from(context.read<NikkeProvider>().nikkeList);

    // 디젤 : 윈터 스위츠가 nikkeList에 없는 경우를 위해 픽스처 추가
    if (!rawNikkes.any((n) => n.name == '디젤 : 윈터 스위츠')) {
      rawNikkes.add(Nikke(
        id: 'diesel_winter_sweets',
        name: '디젤 : 윈터 스위츠',
        imageUrl: 'assets/nikke/diesel_winter_sweets.webp',
        burst: BurstType.burst3,
        element: ElementType.Fire,
        weaponType: WeaponType.MG,
        company: Company.Elysion,
        coolTime: 40,
        type: 'ATK',
        ability: [],
        rank: Rank.SSR,
      ));
    }

    final filtered7Nikkes = rawNikkes
        .where((n) => allowed7NikkeNames.contains(n.name))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    "니케 선택 (슬롯 $slotIndex)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered7Nikkes.length,
                      itemBuilder: (context, idx) {
                        final n = filtered7Nikkes[idx];
                        final isSelected = (slotIndex == 1 && n.name == _nikke1?.name) ||
                            (slotIndex == 2 && n.name == _nikke2?.name);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (slotIndex == 1) {
                                _nikke1 = n;
                              } else {
                                _nikke2 = n;
                              }
                            });
                            Navigator.pop(context);
                            _calculate();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.orange : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                width: isSelected ? 2 : 1,
                              ),
                              color: isDark ? const Color(0xFF242424) : Colors.grey.shade50,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        n.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 30),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  child: Text(
                                    n.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.orange : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
                          _calculate();
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
    bool hasSkillSettings1 = _nikke1?.name == '마르차나 : 마린 스터디' || _nikke1?.name == '스노우 화이트 : 헤비암즈' || _nikke1?.name == '에이다';
    bool hasSkillSettings2 = _nikke2?.name == '마르차나 : 마린 스터디' || _nikke2?.name == '스노우 화이트 : 헤비암즈' || _nikke2?.name == '에이다';

    return Column(
      children: [
        const Divider(height: 24),
        _buildCharacterInputRow(
            label: _nikke1?.name ?? "니케 1 선택",
            imagePath: _nikke1?.imageUrl,
            color: Colors.purple,
            atkCtrl: _nikke1AtkController,
            overCtrl: _nikke1OverController,
            onImageTap: () => _showNikkeSelectorModal(1),
            onSettingsTap: hasSkillSettings1 ? () => _showNikkeSkillDialog(1) : null),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
            label: _nikke2?.name ?? "니케 2 선택",
            imagePath: _nikke2?.imageUrl,
            color: Colors.blue,
            atkCtrl: _nikke2AtkController,
            overCtrl: _nikke2OverController,
            onImageTap: () => _showNikkeSelectorModal(2),
            onSettingsTap: hasSkillSettings2 ? () => _showNikkeSkillDialog(2) : null),

        if (_useNayuta) ...[
          const SizedBox(height: 16),
          _buildCharacterInputRow(
              label: "나유타",
              imagePath: "assets/nikke/nayuta.webp",
              color: Colors.teal,
              atkCtrl: _nayutaAtkController,
              overCtrl: _nayutaOverController,
              onSettingsTap: _showNayutaSettingsDialog),
        ],

        const SizedBox(height: 16),
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
        _buildResultArea(),
        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("시뮬레이션 계산",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _showMirandaSettingsDialog,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF242424) : Colors.white,
              side: const BorderSide(color: Colors.orange, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("미란다 ",
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Icon(Icons.settings, size: 15, color: Colors.orange),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _useNayuta = !_useNayuta;
              });
              _calculate();
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: _useNayuta
                  ? Colors.teal.withOpacity(isDark ? 0.25 : 0.12)
                  : (isDark ? const Color(0xFF242424) : Colors.white),
              side: BorderSide(
                color: _useNayuta ? Colors.teal : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                width: _useNayuta ? 1.5 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(
              _useNayuta ? "나유타 💡" : "나유타",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _useNayuta
                    ? Colors.teal
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterInputRow(
      {required String label,
      required String? imagePath,
      required Color color,
      required TextEditingController atkCtrl,
      required TextEditingController overCtrl,
      VoidCallback? onImageTap,
      VoidCallback? onSettingsTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = imagePath != null && imagePath.isNotEmpty;

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
                  color: isDark ? const Color(0xFF242424) : Colors.grey.shade100,
                  image: hasImage
                      ? DecorationImage(
                          image: AssetImage(imagePath),
                          fit: BoxFit.cover,
                          onError: (_, __) {})
                      : null),
              child: !hasImage
                  ? Center(
                      child: Icon(Icons.person_add_rounded,
                          color: color, size: 28),
                    )
                  : null),
          if (onImageTap != null)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.swap_horiz,
                    size: 12, color: Colors.white),
              ),
            ),
          if (onSettingsTap != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onSettingsTap,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.settings,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: hasImage ? color : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            if (onImageTap != null)
              InkWell(
                onTap: onImageTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    hasImage ? "니케 변경" : "니케 선택",
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
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

  String _buildNikkeNote(String name, {required int slotIndex, required bool isAdaBurstCard}) {
    if (name == '나유타') {
      List<String> parts = [];
      if (nayutaHasMiranda) {
        parts.add("미란다(Lv.$_mirandaBurstLevel)");
      }
      parts.add("2스(Lv.$_nayutaS2Level)");
      parts.add("오버");
      return "나유타: ${parts.join(' + ')}";
    }

    final n1Name = _nikke1?.name ?? '';
    final n2Name = _nikke2?.name ?? '';
    bool isN1Ada = (n1Name == '에이다');
    bool isN2Ada = (n2Name == '에이다');
    bool isCurrentNikkeAda = (name == '에이다');

    int matchaS2Lv = slotIndex == 1 ? _nikke1MatchaS2Level : _nikke2MatchaS2Level;
    int gakseolS2Lv = slotIndex == 1 ? _nikke1GakseolS2Level : _nikke2GakseolS2Level;
    int adaS1Lv = slotIndex == 1 ? _nikke1AdaS1Level : _nikke2AdaS1Level;
    int adaBurstLv = slotIndex == 1 ? _nikke1AdaBurstLevel : _nikke2AdaBurstLevel;

    if (isCurrentNikkeAda) {
      adaS1Lv = isN1Ada ? _nikke1AdaS1Level : _nikke2AdaS1Level;
      adaBurstLv = isN1Ada ? _nikke1AdaBurstLevel : _nikke2AdaBurstLevel;
    } else if (isN1Ada || isN2Ada) {
      int adaSlotIndex = isN1Ada ? 1 : 2;
      adaS1Lv = adaSlotIndex == 1 ? _nikke1AdaS1Level : _nikke2AdaS1Level;
    }

    bool receivesAdaBuff = !isCurrentNikkeAda && (isN1Ada || isN2Ada) && !isAdaBurstCard;

    List<String> multParts = [];
    if (bufferedNikkes.contains(name)) {
      multParts.add("미란다(Lv.$_mirandaBurstLevel)");
    }

    if (name == '마르차나 : 마린 스터디') {
      multParts.add("2스(Lv.$matchaS2Lv)");
    } else if (name == '스노우 화이트 : 헤비암즈') {
      multParts.add("2스(Lv.$gakseolS2Lv)");
    }

    if (isCurrentNikkeAda) {
      if (isAdaBurstCard) {
        multParts.add("1스(Lv.$adaS1Lv)");
        multParts.add("버스트(Lv.$adaBurstLv)");
      }
    }

    multParts.add("오버");

    if (receivesAdaBuff) {
      double adaBase = isN1Ada
          ? _parse(_nikke1AtkController.text)
          : (isN2Ada ? _parse(_nikke2AtkController.text) : 0);
      double adaBuffAtkAmount = adaBase * SkillData.adaS1[adaS1Lv];
      String formattedBuffAtk = _formatter.format(adaBuffAtkAmount.round());

      return "$name: (${multParts.join(' + ')}) + 에이다1스(Lv.$adaS1Lv: $formattedBuffAtk)";
    }

    return "$name: ${multParts.join(' + ')}";
  }

  Widget _buildResultArea() {
    if (_nikke1 == null || _nikke2 == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            "니케 1과 니케 2를 클릭하여 선택 후 수치를 입력하세요.",
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      );
    }

    final n1Name = _nikke1!.name;
    final n2Name = _nikke2!.name;
    bool isN1Ada = (n1Name == '에이다');
    bool isN2Ada = (n2Name == '에이다');

    if (isN1Ada || isN2Ada) {
      String otherName = isN1Ada ? n2Name : n1Name;

      List<String> notesAdaB = [
        _buildNikkeNote(n1Name, slotIndex: 1, isAdaBurstCard: true),
        _buildNikkeNote(n2Name, slotIndex: 2, isAdaBurstCard: true),
      ];
      if (_useNayuta) {
        notesAdaB.add(_buildNikkeNote('나유타', slotIndex: 0, isAdaBurstCard: true));
      }

      List<String> notesOtherB = [
        _buildNikkeNote(n1Name, slotIndex: 1, isAdaBurstCard: false),
        _buildNikkeNote(n2Name, slotIndex: 2, isAdaBurstCard: false),
      ];
      if (_useNayuta) {
        notesOtherB.add(_buildNikkeNote('나유타', slotIndex: 0, isAdaBurstCard: false));
      }

      return Column(
        children: [
          _buildSingleResultCard(
            "<에이다 버스트 시>",
            resNikke1FinalOnAdaB,
            resNikke2FinalOnAdaB,
            resNayutaFinal,
            notesAdaB,
            winColor1: isN1Ada ? Colors.orange : Colors.purple,
            winColor2: isN2Ada ? Colors.orange : Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildSingleResultCard(
            "<$otherName 버스트 시>",
            resNikke1FinalOnOtherB,
            resNikke2FinalOnOtherB,
            resNayutaFinal,
            notesOtherB,
            winColor1: isN1Ada ? Colors.purple : Colors.orange,
            winColor2: isN2Ada ? Colors.blue : Colors.orange,
          ),
        ],
      );
    } else {
      List<String> notes = [
        _buildNikkeNote(n1Name, slotIndex: 1, isAdaBurstCard: false),
        _buildNikkeNote(n2Name, slotIndex: 2, isAdaBurstCard: false),
      ];
      if (_useNayuta) {
        notes.add(_buildNikkeNote('나유타', slotIndex: 0, isAdaBurstCard: false));
      }

      return _buildSingleResultCard(
        "미란다 버프 포함 최종 결과",
        resNikke1FinalOnOtherB,
        resNikke2FinalOnOtherB,
        resNayutaFinal,
        notes,
        winColor1: Colors.purple,
        winColor2: Colors.blue,
      );
    }
  }

  Widget _buildSingleResultCard(
      String title, double val1, double val2, double valNayuta, List<String> notes,
      {Color winColor1 = Colors.purple, Color winColor2 = Colors.blue}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n1Name = _nikke1?.name ?? '니케 1';
    final n2Name = _nikke2?.name ?? '니케 2';

    double maxVal = max(val1, val2);
    if (_useNayuta) {
      maxVal = max(maxVal, valNayuta);
    }

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
                onTap: _showMirandaSettingsDialog,
                child: Icon(Icons.settings_outlined,
                    size: 18,
                    color: isDark ? Colors.grey.shade400 : Colors.grey))
          ]),
          const SizedBox(height: 10),
          _resRow(n1Name, _formatter.format(val1.toInt()), val1 == maxVal, winColor1, bufferedNikkes.contains(n1Name)),
          const SizedBox(height: 4),
          _resRow(n2Name, _formatter.format(val2.toInt()), val2 == maxVal, winColor2, bufferedNikkes.contains(n2Name)),
          if (_useNayuta) ...[
            const SizedBox(height: 4),
            _resRow("나유타", _formatter.format(valNayuta.toInt()), valNayuta == maxVal, Colors.teal, nayutaHasMiranda),
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

  Widget _resRow(String name, String val, bool win, Color winColor, bool hasMiranda) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: win ? FontWeight.bold : FontWeight.normal,
                  color: win
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
          if (hasMiranda) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange, width: 0.8),
              ),
              child: const Text(
                "미란다",
                style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
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
