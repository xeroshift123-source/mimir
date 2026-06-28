import 'package:flutter/foundation.dart';

enum EquipmentPart { head, torso, arm, leg }

enum OverloadOptionType {
  elementalDamage("우월코드 데미지 증가"),
  hitRate("명중률 증가"),
  maxAmmo("최대 장탄 수 증가"),
  attack("공격력 증가"),
  chargeDamage("차지 데미지 증가"),
  chargeSpeed("차지 속도 증가"),
  critDamage("크리티컬 피해량 증가"),
  critRate("크리티컬 확률 증가"),
  defense("방어력 증가");

  final String label;
  const OverloadOptionType(this.label);
}

class OverloadSlot {
  OverloadOptionType? optionType;
  int? skillLevel;
  bool isModuleLocked;
  bool isKeyLocked;
  bool isInitialLocked;

  OverloadSlot({
    this.optionType,
    this.skillLevel,
    this.isModuleLocked = false,
    this.isKeyLocked = false,
    this.isInitialLocked = false,
  });

  bool get isLocked => isModuleLocked || isKeyLocked || isInitialLocked;
  bool get isEmpty => optionType == null;

  void unlock() {
    isModuleLocked = false;
    isKeyLocked = false;
    isInitialLocked = false;
  }
}

class OverloadEquipment {
  final EquipmentPart part;
  final List<OverloadSlot> slots;

  OverloadEquipment({
    required this.part,
    List<OverloadSlot>? slots,
  }) : slots = slots ?? List.generate(3, (_) => OverloadSlot());

  int get moduleLockedCount => slots.where((s) => s.isModuleLocked).length;
  int get initialLockedCount => slots.where((s) => s.isInitialLocked).length;
  int get keyLockedCount => slots.where((s) => s.isKeyLocked).length;
  int get lockedCount => slots.where((s) => s.isLocked).length;
}
