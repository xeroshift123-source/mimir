import 'package:flutter/material.dart';

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
  final Map<String, int> _cubeLevels = {};

  @override
  void initState() {
    super.initState();
    for (final n in widget.nikkes) {
      _cubeLevels[n['name']] = 15;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text("큐브 레벨 설정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.nikkes.length,
          separatorBuilder: (_, __) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final nikke = widget.nikkes[index];
            final name = nikke['name'] as String;
            final image = nikke['image'] as String;
            final currentVal = _cubeLevels[name]!.toDouble();

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("큐브 레벨 선택: ${currentVal.toInt()}", 
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
                          value: currentVal,
                          min: 0,
                          max: 15,
                          divisions: 15,
                          label: currentVal.toInt().toString(),
                          onChanged: (val) {
                            setState(() {
                              _cubeLevels[name] = val.toInt();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _cubeLevels),
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
