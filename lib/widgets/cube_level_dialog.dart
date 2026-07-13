import 'package:flutter/material.dart';

class SyncOptions {
  int cubeLevel;
  int headLevel;
  int torsoLevel;
  int armLevel;
  int legLevel;
  int limitBreak;
  int affection;

  SyncOptions({
    this.cubeLevel = 15,
    this.headLevel = 0,
    this.torsoLevel = 0,
    this.armLevel = 0,
    this.legLevel = 0,
    this.limitBreak = 0,
    this.affection = 1,
  });
}

class CubeLevelDialog extends StatefulWidget {
  final List<Map<String, dynamic>> nikkes;
  // Each map should contain:
  // 'name' (String): The name of the Nikke
  // 'image' (String): The asset image path
  // 'char' (Map<String, dynamic>): The character data from DB to extract initial cube level

  const CubeLevelDialog({super.key, required this.nikkes});

  @override
  State<CubeLevelDialog> createState() => _CubeLevelDialogState();
}

class _CubeLevelDialogState extends State<CubeLevelDialog> {
  final Map<String, SyncOptions> _options = {};
  final Map<String, bool> _nonOverloadedNikkes = {};

  @override
  void initState() {
    super.initState();
    for (final n in widget.nikkes) {
      final char = n['char'] as Map<String, dynamic>? ?? {};
      int head = 0, torso = 0, arm = 0, leg = 0;
      final equips = char['equipment'] as List<dynamic>? ?? [];
      
      int validEquips = 0;
      bool allOverload = true;

      for (final eq in equips) {
        if (eq == null) continue;
        final slot = eq['slot'] as String? ?? '';
        final level = eq['level'] as int? ?? 0;
        final eqTier = eq['tier'] as int? ?? 1;
        final rawOptions = eq['overloadOptions'] as List<dynamic>? ?? [];
        final eqOptions = rawOptions.where((opt) => opt != 0 && opt != "0" && opt != "").toList();
        final bool isOverload = eqOptions.isNotEmpty || eqTier >= 10;
        
        if (!isOverload) {
          allOverload = false;
        }
        validEquips++;

        if (slot == 'head') head = level;
        if (slot == 'torso') torso = level;
        if (slot == 'arm') arm = level;
        if (slot == 'leg') leg = level;
      }
      
      if (validEquips < 4 || !allOverload) {
        _nonOverloadedNikkes[n['name']] = true;
      } else {
        _nonOverloadedNikkes[n['name']] = false;
      }
      final grade = char['grade'] as int? ?? 0;
      final core = char['core'] as int? ?? 0;
      final bond = char['bondLevel'] as int? ?? 1;
      final int lb = (grade == 3 && core > 0) ? 3 + core : grade;

      _options[n['name']] = SyncOptions(
        cubeLevel: 15,
        headLevel: head,
        torsoLevel: torso,
        armLevel: arm,
        legLevel: leg,
        limitBreak: lb,
        affection: bond,
      );
    }
  }

  Widget _buildEquipStepper(String label, int value, VoidCallback onDec, VoidCallback onInc, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: onDec,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Icon(Icons.remove, size: 16, color: value > 0 ? Colors.orange : Colors.grey.shade400),
          ),
        ),
        SizedBox(
          width: 16,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        InkWell(
          onTap: onInc,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Icon(Icons.add, size: 16, color: value < 5 ? Colors.orange : Colors.grey.shade400),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text("동기화 시뮬레이션 설정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.nikkes.length,
          separatorBuilder: (_, __) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final nikke = widget.nikkes[index];
            final name = nikke['name'] as String;
            final image = nikke['image'] as String;
            final currentOpt = _options[name]!;

            final isNonOverload = _nonOverloadedNikkes[name] == true;

            if (isNonOverload) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange, width: 2),
                      image: DecorationImage(
                        image: AssetImage(image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '오버로드 한 개라도 안 된 장비를 착용할 경우 공격력 입력이 불가능합니다!',
                              style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("큐브 레벨: ${currentOpt.cubeLevel}", 
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: Colors.orange,
                    inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    thumbColor: Colors.orange,
                    overlayColor: Colors.orange.withOpacity(0.2),
                    valueIndicatorColor: Colors.orange,
                    activeTickMarkColor: isDark ? Colors.white : Colors.white70,
                    inactiveTickMarkColor: Colors.orange.withOpacity(0.5),
                  ),
                  child: Slider(
                    value: currentOpt.cubeLevel.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    label: currentOpt.cubeLevel.toString(),
                    onChanged: (val) {
                      setState(() {
                        currentOpt.cubeLevel = val.toInt();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange, width: 2),
                        image: DecorationImage(
                          image: AssetImage(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("돌파", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(currentOpt.limitBreak <= 3 ? "${currentOpt.limitBreak} 돌파" : "코어 +${currentOpt.limitBreak - 3}", 
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: Colors.purple.shade400,
                          inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          thumbColor: Colors.purple.shade400,
                          overlayColor: Colors.purple.shade400.withOpacity(0.2),
                          valueIndicatorColor: Colors.purple.shade400,
                          activeTickMarkColor: isDark ? Colors.white : Colors.white70,
                          inactiveTickMarkColor: Colors.purple.shade400.withOpacity(0.5),
                        ),
                        child: Slider(
                          value: currentOpt.limitBreak.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: currentOpt.limitBreak <= 3 ? "${currentOpt.limitBreak}" : "+${currentOpt.limitBreak - 3}",
                          onChanged: (val) {
                            setState(() {
                              currentOpt.limitBreak = val.toInt();
                            });
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("호감도", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text("${currentOpt.affection}", 
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: Colors.pink.shade400,
                          inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          thumbColor: Colors.pink.shade400,
                          overlayColor: Colors.pink.shade400.withOpacity(0.2),
                          valueIndicatorColor: Colors.pink.shade400,
                        ),
                        child: Slider(
                          value: currentOpt.affection.toDouble(),
                          min: 1,
                          max: 40,
                          divisions: 39,
                          label: currentOpt.affection.toString(),
                          onChanged: (val) {
                            setState(() {
                              currentOpt.affection = val.toInt();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildEquipStepper('머리', currentOpt.headLevel, () {
                            if (currentOpt.headLevel > 0) setState(() => currentOpt.headLevel--);
                          }, () {
                            if (currentOpt.headLevel < 5) setState(() => currentOpt.headLevel++);
                          }, isDark),
                          const Text("/", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          _buildEquipStepper('몸통', currentOpt.torsoLevel, () {
                            if (currentOpt.torsoLevel > 0) setState(() => currentOpt.torsoLevel--);
                          }, () {
                            if (currentOpt.torsoLevel < 5) setState(() => currentOpt.torsoLevel++);
                          }, isDark),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildEquipStepper('팔', currentOpt.armLevel, () {
                            if (currentOpt.armLevel > 0) setState(() => currentOpt.armLevel--);
                          }, () {
                            if (currentOpt.armLevel < 5) setState(() => currentOpt.armLevel++);
                          }, isDark),
                          const Text("/", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          _buildEquipStepper('다리', currentOpt.legLevel, () {
                            if (currentOpt.legLevel > 0) setState(() => currentOpt.legLevel--);
                          }, () {
                            if (currentOpt.legLevel < 5) setState(() => currentOpt.legLevel++);
                          }, isDark),
                        ],
                      ),
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
          },
        ),
      ),
      ],
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _options),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text("선택 완료", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
