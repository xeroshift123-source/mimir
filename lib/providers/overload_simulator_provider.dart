import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/overload_simulator_model.dart';
import 'package:mimir/utils/cp_calculator.dart';

class OverloadSimulatorProvider with ChangeNotifier {
  final Nikke nikke;
  final Map<String, dynamic>? charData;
  final bool assumeCube15;
  late List<OverloadEquipment> equipments;

  int totalModulesUsed = 0;
  int totalLockKeysUsed = 0;
  double currentCp = 0;

  final Random _random = Random();

  OverloadSimulatorProvider(this.nikke, {this.charData, this.assumeCube15 = false}) {
    _initializeEquipments();
    _calculateCP();
  }

  void _initializeEquipments() {
    equipments = [
      OverloadEquipment(part: EquipmentPart.head),
      OverloadEquipment(part: EquipmentPart.torso),
      OverloadEquipment(part: EquipmentPart.arm),
      OverloadEquipment(part: EquipmentPart.leg),
    ];

    if (charData != null) {
      final equips = charData!['equipment'] as List<dynamic>? ?? [];
      for (final eq in equips) {
        final slotName = eq['slot'] as String? ?? '';
        final options = eq['overloadOptions'] as List<dynamic>? ?? [];
        
        EquipmentPart? part;
        if (slotName == 'head') part = EquipmentPart.head;
        else if (slotName == 'torso') part = EquipmentPart.torso;
        else if (slotName == 'arm') part = EquipmentPart.arm;
        else if (slotName == 'leg') part = EquipmentPart.leg;
        
        if (part != null) {
          final targetEq = _getEquipment(part);
          for (int i = 0; i < options.length && i < 3; i++) {
            final int id = options[i] as int? ?? 0;
            if (id == 0) continue;
            targetEq.slots[i].optionType = _getOptionTypeFromId(id);
            targetEq.slots[i].skillLevel = id % 100;
          }
        }
      }
    }
  }

  OverloadOptionType? _getOptionTypeFromId(int id) {
    if (id >= 7000501 && id <= 7000515) return OverloadOptionType.elementalDamage;
    if (id >= 7000601 && id <= 7000615) return OverloadOptionType.hitRate;
    if (id >= 7000701 && id <= 7000715) return OverloadOptionType.maxAmmo;
    if (id >= 7000801 && id <= 7000815) return OverloadOptionType.attack;
    if (id >= 7000901 && id <= 7000915) return OverloadOptionType.chargeDamage;
    if (id >= 7001001 && id <= 7001015) return OverloadOptionType.chargeSpeed;
    if (id >= 7001101 && id <= 7001115) return OverloadOptionType.critRate;
    if (id >= 7001201 && id <= 7001215) return OverloadOptionType.critDamage;
    if (id >= 7001301 && id <= 7001315) return OverloadOptionType.defense;
    return null;
  }

  void _calculateCP() {
    // char map for CpCalculator. Use existing charData to preserve skills, console, etc.
    final charMap = Map<String, dynamic>.from(charData ?? {});

    charMap['equipment'] = equipments.map((eq) {
      // Find original equipment
      final equips = charData?['equipment'] as List<dynamic>? ?? [];
      final originalEq = equips.firstWhere(
        (e) => (e['slot'] as String?) == eq.part.name,
        orElse: () => null,
      );

      // Build overload options list for CpCalculator
      List<int> overloadOptions = [];
      for (final slot in eq.slots) {
        if (slot.isEmpty) continue;
        int baseId = getOptionBaseId(slot.optionType!);
        overloadOptions.add(baseId + slot.skillLevel!);
      }

      if (originalEq != null) {
        final newEq = Map<String, dynamic>.from(originalEq);
        newEq['overloadOptions'] = overloadOptions;
        return newEq;
      } else {
        return {
          'tier': 10, // Default if not found
          'slot': eq.part.name,
          'level': 0, 
          'overloadOptions': overloadOptions,
        };
      }
    }).toList();

    final cp = CpCalculator.calculateCp(charMap, nikke, targetLevel: 40, assumeCube15: assumeCube15);
    currentCp = cp > 0 ? cp : 0; // if -1, then return 0
    notifyListeners();
  }

  int getOptionBaseId(OverloadOptionType type) {
    switch (type) {
      case OverloadOptionType.elementalDamage: return 7000500;
      case OverloadOptionType.hitRate: return 7000600;
      case OverloadOptionType.maxAmmo: return 7000700;
      case OverloadOptionType.attack: return 7000800;
      case OverloadOptionType.chargeDamage: return 7000900;
      case OverloadOptionType.chargeSpeed: return 7001000;
      case OverloadOptionType.critRate: return 7001100;
      case OverloadOptionType.critDamage: return 7001200;
      case OverloadOptionType.defense: return 7001300;
    }
  }

  // 잠금 토글
  void toggleModuleLock(EquipmentPart part, int slotIndex) {
    final eq = _getEquipment(part);
    final slot = eq.slots[slotIndex];
    if (slot.isEmpty) return; // 빈 슬롯은 잠금 불가

    final bool wasLocked = slot.isModuleLocked;
    slot.isModuleLocked = !wasLocked;

    if (slot.isModuleLocked) {
      // 잠금을 켤 때 모듈 소모 (첫 번째 잠금: 2개, 두 번째 잠금: 3개)
      int lockCost = eq.moduleLockedCount + 1;
      totalModulesUsed += lockCost;
      slot.isKeyLocked = false; // 중복 잠금 방지
    } else {
      // 잠금을 풀 때 시뮬레이터 편의상 비용 환불
      int refundAmount = eq.moduleLockedCount + 2; 
      totalModulesUsed -= refundAmount;
      if (totalModulesUsed < 0) totalModulesUsed = 0;
    }
    notifyListeners();
  }

  void toggleKeyLock(EquipmentPart part, int slotIndex) {
    final eq = _getEquipment(part);
    final slot = eq.slots[slotIndex];
    if (slot.isEmpty) return;

    slot.isKeyLocked = !slot.isKeyLocked;
    if (slot.isKeyLocked) {
      slot.isModuleLocked = false;
    }
    notifyListeners();
  }

  void reset() {
    totalModulesUsed = 0;
    totalLockKeysUsed = 0;
    _initializeEquipments();
    _calculateCP();
  }

  void unlockSlot(EquipmentPart part, int slotIndex) {
    final eq = _getEquipment(part);
    final slot = eq.slots[slotIndex];
    slot.unlock();
    notifyListeners();
  }

  OverloadEquipment _getEquipment(EquipmentPart part) {
    return equipments.firstWhere((eq) => eq.part == part);
  }

  // 효과 변경
  void changeEffect(EquipmentPart part) {
    final eq = _getEquipment(part);

    // 1. 비용 계산 및 소모
    int totalLockCount = eq.slots.where((s) => s.isLocked).length;
    int moduleCost = 1 + totalLockCount;
    
    int kLockCount = eq.keyLockedCount;
    int keyCost = 0;
    if (kLockCount == 1) keyCost = 20;
    else if (kLockCount == 2) keyCost = 50;

    totalModulesUsed += moduleCost;
    totalLockKeysUsed += keyCost;

    // 2. 잠금 해제될 락키 옵션 미리 확인
    final keyLockedSlots = eq.slots.where((s) => s.isKeyLocked).toList();

    // 3. 현재 잠긴 옵션 수집 (중복 방지용)
    final lockedOptions = eq.slots
        .where((s) => s.isLocked && !s.isEmpty)
        .map((s) => s.optionType!)
        .toSet();

    // 4. 슬롯 롤링
    final unlockProbabilities = [1.0, 0.5, 0.3];
    for (int i = 0; i < 3; i++) {
      final slot = eq.slots[i];
      if (slot.isLocked) continue;

      bool isUnlocked = _random.nextDouble() < unlockProbabilities[i];
      if (isUnlocked) {
        // 새 옵션 부여 (중복 제외)
        slot.optionType = _getRandomOptionType(lockedOptions);
        lockedOptions.add(slot.optionType!); // 방금 뽑은 것도 중복 방지 세트에 추가
        slot.skillLevel = _getRandomSkillLevel();
      } else {
        slot.optionType = null;
        slot.skillLevel = null;
      }
    }

    // 5. 락키 잠금 해제
    for (final slot in keyLockedSlots) {
      slot.isKeyLocked = false;
    }

    _calculateCP();
  }

  // 수치 변경
  void changeValue(EquipmentPart part) {
    final eq = _getEquipment(part);

    // 1. 비용 계산 (수치 변경도 효과 변경과 동일한 비용 구조를 가짐)
    int totalLockCount = eq.slots.where((s) => s.isLocked).length;
    int moduleCost = 1 + totalLockCount;
    
    int kLockCount = eq.keyLockedCount;
    int keyCost = 0;
    if (kLockCount == 1) keyCost = 20;
    else if (kLockCount == 2) keyCost = 50;

    totalModulesUsed += moduleCost;
    totalLockKeysUsed += keyCost;

    final keyLockedSlots = eq.slots.where((s) => s.isKeyLocked).toList();

    // 2. 잠기지 않은 유효한 슬롯의 수치(스킬 레벨)만 변경
    for (final slot in eq.slots) {
      if (slot.isLocked || slot.isEmpty) continue;
      slot.skillLevel = _getRandomSkillLevel();
    }

    // 3. 락키 잠금 해제
    for (final slot in keyLockedSlots) {
      slot.isKeyLocked = false;
    }

    _calculateCP();
  }

  OverloadOptionType _getRandomOptionType(Set<OverloadOptionType> excludeOptions) {
    // 확률 테이블
    final Map<OverloadOptionType, int> probabilities = {
      OverloadOptionType.elementalDamage: 10,
      OverloadOptionType.hitRate: 12,
      OverloadOptionType.maxAmmo: 12,
      OverloadOptionType.attack: 10,
      OverloadOptionType.chargeDamage: 12,
      OverloadOptionType.chargeSpeed: 12,
      OverloadOptionType.critDamage: 12,
      OverloadOptionType.critRate: 10,
      OverloadOptionType.defense: 10,
    };

    // 제외할 옵션 제거
    final availableOptions = probabilities.entries
        .where((e) => !excludeOptions.contains(e.key))
        .toList();

    if (availableOptions.isEmpty) {
      // 이론상 3개 슬롯인데 옵션이 9개라 빌 일은 없지만 안전 장치
      return OverloadOptionType.attack;
    }

    int totalWeight = availableOptions.fold(0, (sum, item) => sum + item.value);
    int randomVal = _random.nextInt(totalWeight);

    int currentSum = 0;
    for (final item in availableOptions) {
      currentSum += item.value;
      if (randomVal < currentSum) {
        return item.key;
      }
    }
    return availableOptions.last.key;
  }

  int _getRandomSkillLevel() {
    double rand = _random.nextDouble();
    if (rand < 0.60) {
      // 1~5레벨 (60%)
      return _random.nextInt(5) + 1;
    } else if (rand < 0.95) {
      // 6~10레벨 (35%)
      return _random.nextInt(5) + 6;
    } else {
      // 11~15레벨 (5%)
      return _random.nextInt(5) + 11;
    }
  }
}
