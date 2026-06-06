import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/utils/blabla_map.dart';

class CpCalculator {
  static Map<String, dynamic>? _baseStats;
  static Map<String, dynamic>? _equipStats;
  static Map<String, dynamic>? _bondStats;
  static Map<String, dynamic>? _cubeStats;
  static Map<String, dynamic>? _colStats;

  static bool get isInitialized => _baseStats != null;

  static Future<void> init() async {
    if (_baseStats != null) return;
    try { _baseStats = jsonDecode(await rootBundle.loadString('assets/data/nikke_base_stats.json')); } catch (e) { print("base: $e"); }
    try { _equipStats = jsonDecode(await rootBundle.loadString('assets/data/nikke_equipment_stats.json')); } catch (e) { print("equip: $e"); }
    try { _bondStats = jsonDecode(await rootBundle.loadString('assets/data/nikke_bond_stats.json')); } catch (e) { print("bond: $e"); }
    try { _cubeStats = jsonDecode(await rootBundle.loadString('assets/data/nikke_cube_stats.json')); } catch (e) { print("cube: $e"); }
    try { _colStats = jsonDecode(await rootBundle.loadString('assets/data/nikke_collection_stats.json')); } catch (e) { print("col: $e"); }
  }

  static Map<String, double> getBaseStats(String role, String weaponType, int level) {
    if (_baseStats != null) {
      final lvlStr = level.toString();
      if (_baseStats!.containsKey(lvlStr)) {
        final roleData = _baseStats![lvlStr][role];
        if (roleData != null) {
          final hp = (roleData['HP'] as num).toDouble();
          final atk = (roleData['ATK'] as num).toDouble();
          final defMap = roleData['DEF'] as Map<String, dynamic>;
          final def = (defMap[weaponType] as num?)?.toDouble() ?? (defMap['AR'] as num).toDouble();
          return {'hp': hp, 'atk': atk, 'def': def};
        }
      }
    }
    return {'hp': 0, 'atk': 0, 'def': 0};
  }

  static Map<String, double> getBondStats(String role, int bondLevel) {
    if (_bondStats != null) {
      final lvlStr = bondLevel.toString();
      if (_bondStats!.containsKey(lvlStr)) {
        final roleData = _bondStats![lvlStr][role];
        if (roleData != null) {
          return {
            'hp': (roleData['HP'] as num).toDouble(),
            'atk': (roleData['ATK'] as num).toDouble(),
            'def': (roleData['DEF'] as num).toDouble(),
          };
        }
      }
    }
    return {'hp': 0, 'atk': 0, 'def': 0};
  }

  static Map<String, double> getConsoleStats(int commonLv, int classLv, int companyLv) {
    return {
      'hp': (commonLv * 450.0) + (classLv * 750.0),
      'atk': companyLv * 25.0,
      'def': (classLv * 5.0) + (companyLv * 5.0),
    };
  }

    static Map<String, double> getEquipmentStats(String role, String slot, int tier, int level, bool isOverload) {
    if (!isOverload && tier < 10) {
      return {'hp': 0, 'atk': 0, 'def': 0};
    }
    
    if (_equipStats != null) {
      final roleData = _equipStats![role] as Map<String, dynamic>?;
      if (roleData != null) {
        final l = level.clamp(0, 5);
        final levelData = roleData[l.toString()] as Map<String, dynamic>?;
        if (levelData != null) {
          final slotData = levelData[slot] as Map<String, dynamic>?;
          if (slotData != null) {
            final hp = slotData.containsKey('HP') ? (slotData['HP'] as num).toDouble() : 0.0;
            final atk = slotData.containsKey('ATK') ? (slotData['ATK'] as num).toDouble() : 0.0;
            final def = slotData.containsKey('DEF') ? (slotData['DEF'] as num).toDouble() : 0.0;
            return {'hp': hp, 'atk': atk, 'def': def};
          }
        }
      }
    }
    
    // Fallback if data doesn't exist
    double eqHp = 0, eqAtk = 0, eqDef = 0;
    if (slot == 'head') { eqAtk = 9576 + level * 478.8; }
    else if (slot == 'torso') { eqHp = 143640 + level * 7182.0; eqAtk = 521 + level * 26.05; }
    else if (slot == 'arm') { eqAtk = 5745 + level * 287.25; eqHp = 86184 + level * 4309.2; }
    else if (slot == 'leg') { eqHp = 86184 + level * 4309.2; eqDef = 782 + level * 39.1; }
    return {'hp': eqHp, 'atk': eqAtk, 'def': eqDef};
  }

  static Map<String, double> getCubeStats(int level) {
    if (_cubeStats != null && _cubeStats!.containsKey(level.toString())) {
      final data = _cubeStats![level.toString()];
      return {
        'hp': (data['HP'] as num).toDouble(),
        'atk': (data['ATK'] as num).toDouble(),
        'def': (data['DEF'] as num).toDouble(),
      };
    }
    return {'hp': 0, 'atk': 0, 'def': 0};
  }

  static Map<String, double> getCollectionStats(String grade, int level) {
    if (_colStats != null && _colStats!.containsKey(grade)) {
      final gradeData = _colStats![grade] as Map<String, dynamic>;
      if (gradeData.containsKey(level.toString())) {
        final data = gradeData[level.toString()];
        return {
          'hp': (data['HP'] as num).toDouble(),
          'atk': (data['ATK'] as num).toDouble(),
          'def': (data['DEF'] as num).toDouble(),
        };
      }
    }
    return {'hp': 0, 'atk': 0, 'def': 0};
  }

  static double getCubeCoef(int level) {
    if (_cubeStats != null && _cubeStats!.containsKey(level.toString())) {
      final data = _cubeStats![level.toString()];
      return (data['s1'] as num).toDouble() + (data['s2'] as num).toDouble() + (level >= 5 ? 4.0 : 0.0);
    }
    return 0.0;
  }

  static double getCollectionCoef(String grade, int level) {
    if (_colStats != null && _colStats!.containsKey(grade)) {
      final gradeData = _colStats![grade] as Map<String, dynamic>;
      if (gradeData.containsKey(level.toString())) {
        final data = gradeData[level.toString()];
        int skillLevel = (data['skill'] as num).toInt();
        if (grade == 'R') {
          return skillLevel * 6.33;
        } else if (grade == 'SR') {
          return skillLevel * 2.0 + 10.66;
        }
      }
    }
    return 0.0;
  }

  static Map<String, double> calculateTargetStats(Map<String, dynamic> char, Nikke? localNikke, {required int targetLevel, bool assumeCube15 = false}) {
    final int grade = char['grade'] as int? ?? 0;
    final int core = char['core'] as int? ?? 0;
    final int bondLv = char['bondLevel'] as int? ?? 0;
    
    final int commonConsoleLv = char['commonConsoleLevel'] as int? ?? 0;
    final int classConsoleLv = char['classConsoleLevel'] as int? ?? 0;
    final int companyConsoleLv = char['companyConsoleLevel'] as int? ?? 0;

    final cubeMap = char['harmonyCube'] as Map<String, dynamic>?;
    int cubeLv = cubeMap != null ? (cubeMap['level'] as int? ?? 0) : 0;
    if (assumeCube15) cubeLv = 15;

    final colMap = char['favoriteItem'] as Map<String, dynamic>?;
    int colLv = 0;
    String colGrade = 'R';
    if (colMap != null) {
      colLv = colMap['level'] as int? ?? 0;
      final int tid = colMap['tid'] as int? ?? 0;
      if (tid >= 200000) {
        colGrade = 'SR';
        colLv = 15;
      } else if (tid % 10 == 2) {
        colGrade = 'SR';
      }
    }

    String rawRole = localNikke?.type ?? 'ATK';
    String role = 'Attacker';
    if (rawRole == 'DEF') role = 'Defender';
    if (rawRole == 'SUP') role = 'Supporter';

    final String weapon = localNikke?.weaponType.name ?? 'AR';

    Map<String, double> base = getBaseStats(role, weapon, targetLevel);
    Map<String, double> bond = getBondStats(role, bondLv);
    Map<String, double> console = getConsoleStats(commonConsoleLv, classConsoleLv, companyConsoleLv);
    
    double bojungHp = 3000.0 * grade;
    double bojungAtk = 20.0 * grade;
    double bojungDef = 100.0 * grade;

    double equipHp = 0, equipAtk = 0, equipDef = 0;
    final equips = char['equipment'] as List<dynamic>? ?? [];
    for (final eq in equips) {
      final int eqLevel = eq['level'] as int? ?? 0;
      final int eqTier = eq['tier'] as int? ?? 1;
      final String eqSlot = eq['slot'] as String? ?? '';
      final eqOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
      final bool isOverload = eqOptions.isNotEmpty || eqTier >= 10;
      
      final st = getEquipmentStats(role, eqSlot, eqTier, eqLevel, isOverload);
      equipHp += st['hp']!;
      equipAtk += st['atk']!;
      equipDef += st['def']!;
    }

    Map<String, double> cube = getCubeStats(cubeLv);
    Map<String, double> col = getCollectionStats(colGrade, colLv);

    final double lbMult = 1.0 + 0.02 * grade;
    final double coreMult = 1.0 + 0.02 * core;

    double finalHp = (base['hp']! * lbMult + (bond['hp']! + console['hp']! + bojungHp)) * coreMult + (equipHp + col['hp']! + cube['hp']!);
    double finalAtk = (base['atk']! * lbMult + (bond['atk']! + console['atk']! + bojungAtk)) * coreMult + (equipAtk + col['atk']! + cube['atk']!);
    double finalDef = (base['def']! * lbMult + (bond['def']! + console['def']! + bojungDef)) * coreMult + (equipDef + col['def']! + cube['def']!);

    return {
      'hp': finalHp,
      'atk': finalAtk,
      'def': finalDef,
    };
  }

  static double calculateCp(Map<String, dynamic> char, Nikke? localNikke, {int targetLevel = 40, bool assumeCube15 = false}) {
    final equips = char['equipment'] as List<dynamic>? ?? [];
    int validEquips = 0;
    bool allOverload = true;
    for (final eq in equips) {
      if (eq == null) continue;
      final eqTier = eq['tier'] as int? ?? 1;
      final eqOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
      final bool isOverload = eqOptions.isNotEmpty || eqTier >= 10;
      if (!isOverload) {
        allOverload = false;
        break;
      }
      validEquips++;
    }
    
    if (validEquips < 4 || !allOverload) {
      return -1.0;
    }

    final stats = calculateTargetStats(char, localNikke, targetLevel: targetLevel, assumeCube15: assumeCube15);
    double score = 0.7 * stats['hp']! + 19.35 * stats['atk']! + 70.0 * stats['def']!;

    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    int skill1 = skills['skill1'] as int? ?? 1;
    int skill2 = skills['skill2'] as int? ?? 1;
    int skillBurst = skills['burst'] as int? ?? 1;
    
    int ukoLevel = 0;
    int nonUkoLevel = 0;
    for (final eq in equips) {
      final eqOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
      for (final opt in eqOptions) {
        final int id = opt as int? ?? 0;
        if (id == 0) continue;
        final String stat = BlablaMap.getOptionName(id);
        final int level = id % 100;
        if (stat.contains('우월코드') || stat.contains('우월 코드')) {
          ukoLevel += level;
        } else {
          nonUkoLevel += level;
        }
      }
    }

    final cubeMap = char['harmonyCube'] as Map<String, dynamic>?;
    int cubeLv = cubeMap != null ? (cubeMap['level'] as int? ?? 0) : 0;
    if (assumeCube15) cubeLv = 15;

    final colMap = char['favoriteItem'] as Map<String, dynamic>?;
    int colLv = 0;
    String colGrade = 'R';
    if (colMap != null) {
      colLv = colMap['level'] as int? ?? 0;
      final int tid = colMap['tid'] as int? ?? 0;
      if (tid >= 200000) {
        colGrade = 'SR';
        colLv = 15;
      } else if (tid % 10 == 2) {
        colGrade = 'SR';
      }
    }

    double bojung = 1.3 
                  + (0.01 * skill1) 
                  + (0.01 * skill2) 
                  + (0.02 * skillBurst) 
                  + (0.00828 * ukoLevel) 
                  + (0.0069 * nonUkoLevel) 
                  + (0.0092 * getCubeCoef(cubeLv)) 
                  + (0.0069 * getCollectionCoef(colGrade, colLv));

    return score * bojung / 100.0;
  }

  static Map<String, dynamic> debugCalculateCp(Map<String, dynamic> char, Nikke? localNikke, {int targetLevel = 40, bool assumeCube15 = false}) {
    final int grade = char['grade'] as int? ?? 0;
    final int core = char['core'] as int? ?? 0;
    final int bondLv = char['bondLevel'] as int? ?? 0;
    
    final int commonConsoleLv = char['commonConsoleLevel'] as int? ?? 0;
    final int classConsoleLv = char['classConsoleLevel'] as int? ?? 0;
    final int companyConsoleLv = char['companyConsoleLevel'] as int? ?? 0;

    final cubeMap = char['harmonyCube'] as Map<String, dynamic>?;
    int cubeLv = cubeMap != null ? (cubeMap['level'] as int? ?? 0) : 0;
    if (assumeCube15) cubeLv = 15;

    final colMap = char['favoriteItem'] as Map<String, dynamic>?;
    int colLv = 0;
    String colGrade = 'R';
    if (colMap != null) {
      colLv = colMap['level'] as int? ?? 0;
      final int tid = colMap['tid'] as int? ?? 0;
      if (tid >= 200000) {
        colGrade = 'SR';
        colLv = 15;
      } else if (tid % 10 == 2) {
        colGrade = 'SR';
      }
    }

    String rawRole = localNikke?.type ?? 'ATK';
    String role = 'Attacker';
    if (rawRole == 'DEF') role = 'Defender';
    if (rawRole == 'SUP') role = 'Supporter';
    final String weapon = localNikke?.weaponType.name ?? 'AR';

    Map<String, double> base = getBaseStats(role, weapon, targetLevel);
    Map<String, double> bond = getBondStats(role, bondLv);
    Map<String, double> console = getConsoleStats(commonConsoleLv, classConsoleLv, companyConsoleLv);
    
    double bojungHp = 3000.0 * grade;
    double bojungAtk = 20.0 * grade;
    double bojungDef = 100.0 * grade;

    double equipHp = 0, equipAtk = 0, equipDef = 0;
    final equips = char['equipment'] as List<dynamic>? ?? [];
    for (final eq in equips) {
      final int eqLevel = eq['level'] as int? ?? 0;
      final int eqTier = eq['tier'] as int? ?? 1;
      final String eqSlot = eq['slot'] as String? ?? '';
      final eqOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
      final bool isOverload = eqOptions.isNotEmpty || eqTier >= 10;
      final st = getEquipmentStats(role, eqSlot, eqTier, eqLevel, isOverload);
      equipHp += st['hp']!; equipAtk += st['atk']!; equipDef += st['def']!;
    }

    Map<String, double> cube = getCubeStats(cubeLv);
    Map<String, double> col = getCollectionStats(colGrade, colLv);

    final double lbMult = 1.0 + 0.02 * grade;
    final double coreMult = 1.0 + 0.02 * core;

    double finalHp = (base['hp']! * lbMult + (bond['hp']! + console['hp']! + bojungHp)) * coreMult + (equipHp + col['hp']! + cube['hp']!);
    double finalAtk = (base['atk']! * lbMult + (bond['atk']! + console['atk']! + bojungAtk)) * coreMult + (equipAtk + col['atk']! + cube['atk']!);
    double finalDef = (base['def']! * lbMult + (bond['def']! + console['def']! + bojungDef)) * coreMult + (equipDef + col['def']! + cube['def']!);

    double score = 0.7 * finalHp + 19.35 * finalAtk + 70.0 * finalDef;

    final skills = char['skills'] as Map<String, dynamic>? ?? {};
    int skill1 = skills['skill1'] as int? ?? 1;
    int skill2 = skills['skill2'] as int? ?? 1;
    int skillBurst = skills['burst'] as int? ?? 1;
    
    int ukoLevel = 0; int nonUkoLevel = 0;
    for (final eq in equips) {
      final eqOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
      for (final opt in eqOptions) {
        final int id = opt as int? ?? 0;
        if (id == 0) continue;
        final String stat = BlablaMap.getOptionName(id);
        final int level = id % 100;
        if (stat.contains('우월코드') || stat.contains('우월 코드')) ukoLevel += level;
        else nonUkoLevel += level;
      }
    }

    double bojung = 1.3 + (0.01 * skill1) + (0.01 * skill2) + (0.02 * skillBurst) 
                  + (0.00828 * ukoLevel) + (0.0069 * nonUkoLevel) 
                  + (0.0092 * getCubeCoef(cubeLv)) + (0.0069 * getCollectionCoef(colGrade, colLv));

    return {
      'baseHp': base['hp'], 'baseAtk': base['atk'], 'baseDef': base['def'],
      'bondHp': bond['hp'], 'bondAtk': bond['atk'], 'bondDef': bond['def'],
      'consoleHp': console['hp'], 'consoleAtk': console['atk'], 'consoleDef': console['def'],
      'bojungHp': bojungHp, 'bojungAtk': bojungAtk, 'bojungDef': bojungDef,
      'equipHp': equipHp, 'equipAtk': equipAtk, 'equipDef': equipDef,
      'cubeHp': cube['hp'], 'cubeAtk': cube['atk'], 'cubeDef': cube['def'],
      'colHp': col['hp'], 'colAtk': col['atk'], 'colDef': col['def'],
      'lbMult': lbMult, 'coreMult': coreMult,
      'finalHp': finalHp, 'finalAtk': finalAtk, 'finalDef': finalDef,
      'score': score, 'bojung': bojung,
      'cp': score * bojung / 100.0,
      'skill1': skill1, 'skill2': skill2, 'skillBurst': skillBurst,
      'ukoLevel': ukoLevel, 'nonUkoLevel': nonUkoLevel,
      'cubeCoef': getCubeCoef(cubeLv), 'colCoef': getCollectionCoef(colGrade, colLv)
    };
  }
}
