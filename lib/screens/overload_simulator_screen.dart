import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/models/overload_simulator_model.dart';
import 'package:mimir/providers/overload_simulator_provider.dart';
import 'package:mimir/utils/blabla_map.dart';
import 'package:intl/intl.dart';

class OverloadSimulatorScreen extends StatelessWidget {
  static const String routeName = '/overload-simulator';

  const OverloadSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 라우팅 아규먼트로 Map을 받아옴
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final nikke = args['nikke'] as Nikke;
    final charData = args['charData'] as Map<String, dynamic>?;
    final assumeCube15 = args['assumeCube15'] as bool? ?? false;

    return ChangeNotifierProvider(
      create: (_) => OverloadSimulatorProvider(nikke, charData: charData, assumeCube15: assumeCube15),
      child: const _OverloadSimulatorView(),
    );
  }
}

class _OverloadSimulatorView extends StatelessWidget {
  const _OverloadSimulatorView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OverloadSimulatorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('모듈작 시뮬레이션'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDark ? const Color(0xFF0D0E12) : const Color(0xFFF5F5F7),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Column(
            children: [
              _buildHeader(context, provider, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 800) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTotalOverloadStats(provider, isDark),
                            const SizedBox(height: 16),
                            _buildSimulatedStatsPanel(context, provider, isDark),
                            const SizedBox(height: 16),
                            _buildEquipmentSection(context, provider, EquipmentPart.head, '머리', isDark),
                            const SizedBox(height: 16),
                            _buildEquipmentSection(context, provider, EquipmentPart.torso, '몸통', isDark),
                            const SizedBox(height: 16),
                            _buildEquipmentSection(context, provider, EquipmentPart.arm, '팔', isDark),
                            const SizedBox(height: 16),
                            _buildEquipmentSection(context, provider, EquipmentPart.leg, '다리', isDark),
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 왼쪽: 옵션 총합 패널
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildTotalOverloadStats(provider, isDark),
                                  const SizedBox(height: 16),
                                  _buildSimulatedStatsPanel(context, provider, isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // 오른쪽: 2x2 그리드
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildEquipmentSection(context, provider, EquipmentPart.head, '머리', isDark)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildEquipmentSection(context, provider, EquipmentPart.torso, '몸통', isDark)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildEquipmentSection(context, provider, EquipmentPart.arm, '팔', isDark)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildEquipmentSection(context, provider, EquipmentPart.leg, '다리', isDark)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulatedStatsPanel(BuildContext context, OverloadSimulatorProvider provider, bool isDark) {
    int lbSliderValue = provider.simGrade;
    if (provider.simGrade == 3) {
      lbSliderValue = 3 + provider.simCore;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                "스탯 시뮬레이션",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 돌파
          _buildStatRow(
            title: "돌파",
            icon: Icons.star_border,
            isDark: isDark,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: lbSliderValue.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    activeColor: Colors.orange,
                    inactiveColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    onChanged: (val) {
                      int v = val.toInt();
                      int g = v <= 3 ? v : 3;
                      int c = v <= 3 ? 0 : v - 3;
                      provider.updateLimitBreakCore(g, c);
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    lbSliderValue <= 3 ? (lbSliderValue == 0 ? '명함' : '$lbSliderValue돌') : '+${lbSliderValue - 3}코어',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 호감도
          _buildStatRow(
            title: "호감도",
            icon: Icons.favorite_border,
            isDark: isDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.orange,
                  onPressed: provider.simBondLevel > 1 ? () => provider.updateBondLevel(provider.simBondLevel - 1) : null,
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${provider.simBondLevel} / 40',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.orange,
                  onPressed: provider.simBondLevel < 40 ? () => provider.updateBondLevel(provider.simBondLevel + 1) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 스킬
          _buildStatRow(
            title: "스킬",
            icon: Icons.auto_awesome,
            isDark: isDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSkillStepper(1, provider.simSkill1, provider, isDark),
                const Text("/", style: TextStyle(color: Colors.grey, fontSize: 18)),
                _buildSkillStepper(2, provider.simSkill2, provider, isDark),
                const Text("/", style: TextStyle(color: Colors.grey, fontSize: 18)),
                _buildSkillStepper(3, provider.simBurst, provider, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({required String title, required IconData icon, required Widget child, required bool isDark}) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildSkillStepper(int skillIndex, int level, OverloadSimulatorProvider provider, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: level > 1 ? () => provider.updateSkill(skillIndex, level - 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Icon(Icons.remove, size: 18, color: level > 1 ? Colors.orange : Colors.grey.shade400),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$level',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        InkWell(
          onTap: level < 10 ? () => provider.updateSkill(skillIndex, level + 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Icon(Icons.add, size: 18, color: level < 10 ? Colors.orange : Colors.grey.shade400),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalOverloadStats(OverloadSimulatorProvider provider, bool isDark) {
    final Map<OverloadOptionType, List<int>> groups = {};
    for (final eq in provider.equipments) {
      for (final slot in eq.slots) {
        if (slot.isEmpty) continue;
        groups.putIfAbsent(slot.optionType!, () => []).add(slot.skillLevel!);
      }
    }

    final List<Map<String, dynamic>> summaries = [];
    groups.forEach((type, levels) {
      double sumPercent = 0.0;
      int maxLevel = 0;
      for (final lvl in levels) {
        int baseId = provider.getOptionBaseId(type);
        sumPercent += BlablaMap.getOptionPercent(baseId + lvl);
        if (lvl > maxLevel) maxLevel = lvl;
      }
      summaries.add({
        'name': type.label,
        'sumPercent': sumPercent,
        'maxLevel': maxLevel,
        'count': levels.length,
      });
    });

    summaries.sort((a, b) {
      final int countCompare = b['count'].compareTo(a['count']);
      if (countCompare != 0) return countCompare;
      return b['sumPercent'].compareTo(a['sumPercent']);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                "오버로드 옵션 총합",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (summaries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("오버로드 옵션 없음", style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: summaries.map((info) {
                final bool isLevel15 = info['maxLevel'] == 15;
                final bool isHighLevel = info['maxLevel'] >= 12;

                final Color boxBgColor = isLevel15 ? const Color(0xFF232323) : const Color(0xFFEAEAEA);
                final Color labelColor = isLevel15 ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
                final Color valueColor = isHighLevel ? const Color(0xFF049EE7) : const Color(0xFF7F8C8D);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: boxBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(info['name'], style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('+${(info['sumPercent'] as double).toStringAsFixed(2)}%', style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OverloadSimulatorProvider provider, bool isDark) {
    final formatCp = NumberFormat('#,###').format(provider.currentCp.round());
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF14151B) : Colors.white,
      child: Row(
        children: [
          // 니케 이미지 (둥근 프로필)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              provider.nikke.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(width: 60, height: 60, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 16),
          // 이름 및 전투력
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      provider.nikke.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => provider.reset(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.refresh, size: 20, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '40Lv 전투력: $formatCp',
                  style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // 소모 재화 카운트
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/icons/module.png', width: 18, height: 18),
                    const SizedBox(width: 6),
                    Text('${provider.totalModulesUsed}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/icons/lockkey.png', width: 18, height: 18),
                    const SizedBox(width: 6),
                    Text('${provider.totalLockKeysUsed}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSection(
      BuildContext context, OverloadSimulatorProvider provider, EquipmentPart part, String title, bool isDark) {
    final eq = provider.equipments.firstWhere((e) => e.part == part);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              _buildEquipmentLevelStepper(context, provider, part, eq.level, isDark),
            ],
          ),
          const SizedBox(height: 12),
          // 3개의 옵션 슬롯
          for (int i = 0; i < 3; i++) ...[
            _buildOptionSlot(context, provider, part, i, eq.slots[i], isDark),
            if (i < 2) const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => provider.changeEffect(part),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('효과 변경'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => provider.changeValue(part),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('수치 변경'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEquipmentLevelStepper(BuildContext context, OverloadSimulatorProvider provider, EquipmentPart part, int level, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: level > 0 ? () => provider.updateEquipmentLevel(part, level - 1) : null,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(Icons.remove_circle_outline, size: 20, color: level > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade400),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '+$level',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        InkWell(
          onTap: level < 5 ? () => provider.updateEquipmentLevel(part, level + 1) : null,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(Icons.add_circle_outline, size: 20, color: level < 5 ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade400),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSlot(
      BuildContext context, OverloadSimulatorProvider provider, EquipmentPart part, int index, OverloadSlot slot, bool isDark) {
    
    final optLevel = slot.skillLevel ?? 0;
    final bool isLevel15 = optLevel == 15;
    final bool isHighLevel = optLevel >= 12;

    Color boxBgColor = isDark ? const Color(0xFF2A2B36) : Colors.grey.shade100;
    Color nameTextColor = isDark ? Colors.white : Colors.black87;
    Color iconColor = Colors.grey;
    String percentText = '';

    if (!slot.isEmpty) {
      boxBgColor = isLevel15 ? const Color(0xFF232323) : const Color(0xFFEAEAEA);
      nameTextColor = isLevel15 ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
      final valueColor = isHighLevel ? const Color(0xFF049EE7) : const Color(0xFF7F8C8D);
      iconColor = isHighLevel ? valueColor : const Color(0xFF7F8C8D);
      
      final baseId = provider.getOptionBaseId(slot.optionType!);
      percentText = '${BlablaMap.getOptionPercent(baseId + optLevel)}%';
    } else {
      boxBgColor = const Color(0xFFEAEAEA);
    }

    final borderColor = slot.isModuleLocked
        ? Colors.blue
        : slot.isKeyLocked
            ? Colors.orange
            : slot.isInitialLocked
                ? Colors.purple
                : Colors.transparent;

    final String slotPrefix = "[${index + 1}슬롯] ";

    return GestureDetector(
      onTap: () => _showLockDialog(context, provider, part, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: boxBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Row(
            key: ValueKey('${slot.optionType}_${slot.skillLevel}_${slot.isEmpty}'),
            children: [
              if (!slot.isEmpty) ...[
                Icon(Icons.flash_on, color: iconColor, size: 14.5),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: slot.isEmpty
                    ? Text('$slotPrefix효과 없음', style: const TextStyle(color: Color(0xFF7F8C8D), fontWeight: FontWeight.bold, fontSize: 14.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$slotPrefix${slot.optionType!.label} (Lv.$optLevel)',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isHighLevel ? const Color(0xFF049EE7) : nameTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            percentText,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isHighLevel ? const Color(0xFF049EE7) : nameTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              // 자물쇠 아이콘
              if (slot.isModuleLocked)
                const Icon(Icons.lock, color: Colors.blue, size: 20)
              else if (slot.isKeyLocked)
                const Icon(Icons.key, color: Colors.orange, size: 20)
              else if (slot.isInitialLocked)
                const Icon(Icons.lock, color: Colors.purple, size: 20)
              else
                const Icon(Icons.lock_open, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLockDialog(BuildContext context, OverloadSimulatorProvider provider, EquipmentPart part, int slotIndex) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('옵션 잠금 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Image.asset('assets/icons/module.png', width: 24, height: 24),
                title: const Text('모듈로 잠금'),
                subtitle: const Text('비용: 1슬롯-2개, 2슬롯-3개'),
                onTap: () {
                  provider.toggleModuleLock(part, slotIndex);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock, color: Colors.purple, size: 24),
                title: const Text('초기 상태로 잠금'),
                subtitle: const Text('비용 없음 (미리 잠겨있던 옵션)'),
                onTap: () {
                  provider.toggleInitialLock(part, slotIndex);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Image.asset('assets/icons/lockkey.png', width: 24, height: 24),
                title: const Text('락키로 잠금'),
                subtitle: const Text('비용: 1슬롯-20개, 2슬롯-30개'),
                onTap: () {
                  provider.toggleKeyLock(part, slotIndex);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_open),
                title: const Text('잠금 해제'),
                onTap: () {
                  provider.unlockSlot(part, slotIndex);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
