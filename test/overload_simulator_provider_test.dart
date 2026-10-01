import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/overload_simulator_model.dart';
import 'package:mimir/providers/overload_simulator_provider.dart';

class _ScriptedRandom implements Random {
  final List<double> doubles;
  final List<int> ints;

  _ScriptedRandom(this.doubles, this.ints);

  @override
  double nextDouble() => doubles.removeAt(0);

  @override
  int nextInt(int max) {
    final value = ints.removeAt(0);
    expect(value, inInclusiveRange(0, max - 1));
    return value;
  }

  @override
  bool nextBool() => throw UnsupportedError('Unexpected nextBool');
}

OverloadSimulatorProvider _provider(Random random) {
  final provider = OverloadSimulatorProvider(
    Nikke.fromJson({
      'id': 'test',
      'name': 'test',
      'imageUrl': '',
      'rank': 'SSR',
    }),
    random: random,
  );
  addTearDown(provider.dispose);
  return provider;
}

void main() {
  for (final effect in [true, false]) {
    test(
        '${effect ? "effect" : "value"} undo restores slots once without refunds',
        () {
      final provider = _provider(Random(42));
      final slots = provider.equipments.first.slots;
      slots[0].optionType = OverloadOptionType.attack;
      slots[0].skillLevel = 5;
      slots[1].optionType = OverloadOptionType.maxAmmo;
      slots[1].skillLevel = 10;
      provider.toggleKeyLock(EquipmentPart.head, 1);
      expect(provider.canUndo(EquipmentPart.head), isFalse);
      provider.undoChange(EquipmentPart.head);
      expect(provider.totalModulesUsed, 0);

      if (effect) {
        provider.changeEffect(EquipmentPart.head);
      } else {
        provider.changeValue(EquipmentPart.head);
      }
      expect(provider.canUndo(EquipmentPart.head), isTrue);
      provider.undoChange(EquipmentPart.head);

      expect(provider.canUndo(EquipmentPart.head), isFalse);
      expect(slots[0].optionType, OverloadOptionType.attack);
      expect(slots[0].skillLevel, 5);
      expect(slots[1].optionType, OverloadOptionType.maxAmmo);
      expect(slots[1].skillLevel, 10);
      expect(slots[1].isKeyLocked, isTrue);
      expect(slots[2].isEmpty, isTrue);
      expect(slots[2].skillLevel, isNull);
      expect(provider.totalModulesUsed, 2);
      expect(provider.totalLockKeysUsed, 20);
      provider.undoChange(EquipmentPart.head);
      expect(provider.totalModulesUsed, 2);
      expect(provider.totalLockKeysUsed, 20);
    });
  }

  test('undo retains only latest roll per equipment and reset clears history',
      () {
    final provider = _provider(Random(12));
    provider.changeEffect(EquipmentPart.head);
    final slots = provider.equipments.first.slots;
    final firstRoll = slots.map((s) => (s.optionType, s.skillLevel)).toList();
    provider.changeValue(EquipmentPart.head);
    provider.changeEffect(EquipmentPart.arm);
    provider.updateEquipmentLevel(EquipmentPart.head, 5);
    provider.undoChange(EquipmentPart.head);
    expect(slots.map((s) => (s.optionType, s.skillLevel)).toList(), firstRoll);
    expect(provider.equipments.first.level, 5);
    expect(provider.canUndo(EquipmentPart.head), isFalse);
    expect(provider.canUndo(EquipmentPart.arm), isTrue);
    expect(provider.totalModulesUsed, 3);
    provider.changeValue(EquipmentPart.head);
    expect(provider.canUndo(EquipmentPart.head), isTrue);
    provider.reset();
    for (final part in EquipmentPart.values) {
      expect(provider.canUndo(part), isFalse);
    }
  });

  for (final sameType in [true, false]) {
    test(
        'effect rejects identical pair and allows ${sameType ? "same type" : "same level"}',
        () {
      final random = _ScriptedRandom(
        [0, 0, 0, 0.9, 0.9],
        [0, 0, sameType ? 0 : 10, sameType ? 1 : 0],
      );
      final provider = _provider(random);
      final slots = provider.equipments.first.slots;
      slots[0].optionType = OverloadOptionType.elementalDamage;
      slots[0].skillLevel = 1;

      provider.changeEffect(EquipmentPart.head);

      expect(
          slots[0].optionType,
          sameType
              ? OverloadOptionType.elementalDamage
              : OverloadOptionType.hitRate);
      expect(slots[0].skillLevel, sameType ? 2 : 1);
      expect(slots.skip(1).every((slot) => slot.isEmpty), isTrue);
      expect(provider.totalModulesUsed, 1);
      expect(random.doubles, isEmpty);
      expect(random.ints, isEmpty);
    });
  }

  test('value rejects old level at every tier boundary', () {
    for (final oldLevel in [1, 5, 6, 10, 11, 15]) {
      final tier = (oldLevel - 1) ~/ 5;
      final random = _ScriptedRandom(
        [
          [0.0, 0.6, 0.95][tier],
          0
        ],
        [(oldLevel - 1) % 5, oldLevel == 1 ? 1 : 0],
      );
      final provider = _provider(random);
      final slot = provider.equipments.first.slots.first;
      slot.optionType = OverloadOptionType.attack;
      slot.skillLevel = oldLevel;

      provider.changeValue(EquipmentPart.head);

      expect(slot.optionType, OverloadOptionType.attack);
      expect(slot.skillLevel, oldLevel == 1 ? 2 : 1);
      expect(provider.totalModulesUsed, 1);
      expect(random.doubles, isEmpty);
      expect(random.ints, isEmpty);
    }
  });

  for (final effect in [true, false]) {
    test(
        '${effect ? "effect" : "value"} preserves locks across rolls and charges each time',
        () {
      final provider = _provider(Random(42));
      final slots = provider.equipments.first.slots;
      for (var i = 0; i < 3; i++) {
        slots[i].optionType = OverloadOptionType.values[i];
        slots[i].skillLevel = 5;
      }
      slots[0].isModuleLocked = true;
      slots[1].isInitialLocked = true;
      slots[2].isKeyLocked = true;

      for (var roll = 1; roll <= 3; roll++) {
        if (effect) {
          provider.changeEffect(EquipmentPart.head);
        } else {
          provider.changeValue(EquipmentPart.head);
        }

        for (var i = 0; i < 3; i++) {
          expect(slots[i].optionType, OverloadOptionType.values[i]);
          expect(slots[i].skillLevel, 5);
        }
        expect(slots[0].isModuleLocked, isTrue);
        expect(slots[1].isInitialLocked, isTrue);
        expect(slots[2].isKeyLocked, isTrue);
        expect(provider.totalModulesUsed, 4 * roll);
        expect(provider.totalLockKeysUsed, 40 * roll);
      }

      provider.unlockSlot(EquipmentPart.head, 2);
      expect(slots[2].isKeyLocked, isFalse);
      provider.changeValue(EquipmentPart.head);
      expect(slots[2].skillLevel, isNot(5));
      expect(provider.totalModulesUsed, 15);
      expect(provider.totalLockKeysUsed, 120);
    });
  }

  test('repeated rolls exclude identical occupied options on every line', () {
    final provider = _provider(Random(1234));
    final slots = provider.equipments.first.slots;
    for (var roll = 0; roll < 1000; roll++) {
      final before = slots.map((s) => (s.optionType, s.skillLevel)).toList();
      provider.changeEffect(EquipmentPart.head);
      final types = <OverloadOptionType>{};
      for (var i = 0; i < 3; i++) {
        if (slots[i].isEmpty) continue;
        expect((slots[i].optionType, slots[i].skillLevel), isNot(before[i]));
        expect(types.add(slots[i].optionType!), isTrue);
        expect(slots[i].skillLevel, inInclusiveRange(1, 15));
      }
      final levels = slots.map((s) => s.skillLevel).toList();
      final optionTypes = slots.map((s) => s.optionType).toList();
      provider.changeValue(EquipmentPart.head);
      for (var i = 0; i < 3; i++) {
        expect(slots[i].optionType, optionTypes[i]);
        if (slots[i].isEmpty) {
          expect(slots[i].skillLevel, isNull);
        } else {
          expect(slots[i].skillLevel, isNot(levels[i]));
          expect(slots[i].skillLevel, inInclusiveRange(1, 15));
        }
      }
    }
    expect(provider.totalModulesUsed, 2000);
  });
}
