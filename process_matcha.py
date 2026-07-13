import re
import os
import io

def process_file(filepath, changes):
    with io.open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()
    
    if "import 'package:mimir/utils/skill_data.dart';" not in text:
        text = text.replace("import 'package:mimir/utils/blabla_map.dart';", "import 'package:mimir/utils/blabla_map.dart';\nimport 'package:mimir/utils/skill_data.dart';")
    
    for old, new in changes:
        text = re.sub(old, new, text)
        
    with io.open(filepath, 'w', encoding='utf-8') as f:
        f.write(text)


def matcha_gakseol():
    filepath = r'c:\MMR\mimir\lib\widgets\matcha_gakseol_form.dart'
    changes = [
        # Variables
        (r'  final _mirandaAtkController = TextEditingController\(text: "[0-9.]+"\);', 
         '  int _mirandaBurstLevel = 10;\n  int _matchaS2Level = 10;\n  int _gakseolS2Level = 10;'),
        # Sync Miranda
        (r'      Map<String, dynamic>\? gakseolChar;', '      Map<String, dynamic>? gakseolChar;\n      Map<String, dynamic>? mirandaChar;'),
        (r"        if \(mappedName == '스노우 화이트 : 헤비암즈'\) gakseolChar = char;", "        if (mappedName == '스노우 화이트 : 헤비암즈') gakseolChar = char;\n        if (mappedName == '미란다') mirandaChar = char;"),
        # Sync Levels
        (r"      if \(matchaChar != null\)\n        applyCharStats\(matchaChar, '마르차나 : 마린 스터디', _matchaAtkController,\n            _matchaOverController\);\n      if \(gakseolChar != null\)\n        applyCharStats\(gakseolChar, '스노우 화이트 : 헤비암즈', _gakseolAtkController,\n            _gakseolOverController\);",
         """      if (mirandaChar != null) {
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
      }"""),
        # Dispose
        (r"    _mirandaAtkController\.dispose\(\);\n", ""),
        # Calculate
        (r"      double mirandaVal = _parse\(_mirandaAtkController\.text\) / 100;\n      const double matchaSkill2 = 1.6365; // 마르차나 자공증 : 2스킬 32.73% \* 5 = 163.65%",
         "      double mirandaVal = SkillData.mirandaBurst[_mirandaBurstLevel];\n      double matchaSkill2 = SkillData.matchaS2[_matchaS2Level];"),
        (r"      const double gakseolSkill2 =\n          1.2076; // 스노우화이트 자공증 : 2스킬 풀차지시 46.84% \+ 3단계 진입시 73.92% = 120.76%",
         "      double gakseolSkill2 = SkillData.gakseolS2[_gakseolS2Level];"),
        # Image tap matcha
        (r"        _buildCharacterInputRow\(\n            label: \"마르차나\",\n            imagePath: \"assets/nikke/marciana_marine_study\.webp\",\n            color: Colors\.cyan,\n            atkCtrl: _matchaAtkController,\n            overCtrl: _matchaOverController\),",
         """        _buildCharacterInputRow(
            label: "마르차나",
            imagePath: "assets/nikke/marciana_marine_study.webp",
            color: Colors.cyan,
            atkCtrl: _matchaAtkController,
            overCtrl: _matchaOverController,
            onImageTap: _showMatchaSkillDialog),"""),
        # Image tap gakseol
        (r"        _buildCharacterInputRow\(\n            label: \"스노우화이트\",\n            imagePath: \"assets/nikke/snow_white_heavy_arms\.webp\",\n            color: Colors\.grey,\n            atkCtrl: _gakseolAtkController,\n            overCtrl: _gakseolOverController\),",
         """        _buildCharacterInputRow(
            label: "스노우화이트",
            imagePath: "assets/nikke/snow_white_heavy_arms.webp",
            color: Colors.grey,
            atkCtrl: _gakseolAtkController,
            overCtrl: _gakseolOverController,
            onImageTap: _showGakseolSkillDialog),"""),
        # Result Cards
        (r"미란다\(\$\\{_mirandaAtkController\.text\\}%\)", "미란다(Lv.$_mirandaBurstLevel)"),
        (r"2스\(163.65%\)", "2스(Lv.$_matchaS2Level)"),
        (r"2스\(120.76%\)", "2스(Lv.$_gakseolS2Level)"),
        # Dialog
        (r"  void _showMirandaSettingsDialog\(\) \{\n    showDialog\(\n        context: context,\n        builder: \(context\) => AlertDialog\(\n                title: const Text\(\"미란다 설정\"\),\n                content: TextField\(\n                    controller: _mirandaAtkController,\n                    keyboardType:\n                        const TextInputType\.numberWithOptions\(decimal: true\),\n                    decoration: const InputDecoration\(labelText: \"미란다 공증 \(%\)\"\)\),\n                actions: \[\n                  TextButton\(\n                      onPressed: \(\) => Navigator\.pop\(context\),\n                      child: const Text\(\"취소\"\)\),\n                  ElevatedButton\(\n                      onPressed: \(\) \{\n                        setState\(\(\) \{\}\);\n                        Navigator\.pop\(context\);\n                      \},\n                      child: const Text\(\"확인\"\)\)\n                \]\)\);\n  \}",
        """  void _showMirandaSettingsDialog() => _showSettingDialog("미란다 설정", (setDialogState) => [
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
  }""")
    ]
    process_file(filepath, changes)

matcha_gakseol()
