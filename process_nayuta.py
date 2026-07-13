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


def nayuta_helm():
    filepath = r'c:\MMR\mimir\lib\widgets\nayuta_helm_form.dart'
    changes = [
        # Variables
        (r'  final _cludBurstController = TextEditingController\(text: "[0-9.]+"\);\n  final _mirandaAtkController = TextEditingController\(text: "[0-9.]+"\);', 
         '  int _cludBurstLevel = 10;\n  int _mirandaBurstLevel = 10;\n  int _nayutaS2Level = 10;'),
        # Sync Miranda
        (r'      Map<String, dynamic>\? cdieselChar;', '      Map<String, dynamic>? cdieselChar;\n      Map<String, dynamic>? mirandaChar;'),
        (r"        if \(mappedName == '디젤 : 윈터 스위츠'\) cdieselChar = char;", "        if (mappedName == '디젤 : 윈터 스위츠') cdieselChar = char;\n        if (mappedName == '미란다') mirandaChar = char;"),
        # Sync Levels
        (r"      if \(nayutaChar != null\) applyCharStats\(nayutaChar, '나유타', _nayutaAtkController, _nayutaOverController\);\n      if \(helmChar != null\) applyCharStats\(helmChar, '헬름', _helmAtkController, _helmOverController\);\n      if \(_extraNikkeType == 'clud' && cludChar != null\) \{\n        applyCharStats\(cludChar, '루드밀라 : 윈터 오너', _extraAtkController, _extraOverController\);\n      \} else if \(_extraNikkeType == 'cdiesel' && cdieselChar != null\) \{\n        applyCharStats\(cdieselChar, '디젤 : 윈터 스위츠', _extraAtkController, _extraOverController\);\n      \}",
         """      if (mirandaChar != null) {
        final skills = mirandaChar['skills'] as Map<String, dynamic>? ?? {};
        _mirandaBurstLevel = skills['burst'] ?? 10;
      }
      if (nayutaChar != null) {
        applyCharStats(nayutaChar, '나유타', _nayutaAtkController, _nayutaOverController);
        final skills = nayutaChar['skills'] as Map<String, dynamic>? ?? {};
        _nayutaS2Level = skills['skill2'] ?? 10;
      }
      if (helmChar != null) {
        applyCharStats(helmChar, '헬름', _helmAtkController, _helmOverController);
      }
      if (_extraNikkeType == 'clud' && cludChar != null) {
        applyCharStats(cludChar, '루드밀라 : 윈터 오너', _extraAtkController, _extraOverController);
        final skills = cludChar['skills'] as Map<String, dynamic>? ?? {};
        _cludBurstLevel = skills['burst'] ?? 10;
      } else if (_extraNikkeType == 'cdiesel' && cdieselChar != null) {
        applyCharStats(cdieselChar, '디젤 : 윈터 스위츠', _extraAtkController, _extraOverController);
      }"""),
        # Dispose
        (r"    _cludBurstController\.dispose\(\);\n    _mirandaAtkController\.dispose\(\);\n", ""),
        # Calculate
        (r"      double mirandaVal = _parse\(_mirandaAtkController\.text\) / 100;\n      const double nayutaSkill2 = [0-9.]+;",
         "      double mirandaVal = SkillData.mirandaBurst[_mirandaBurstLevel];\n      double nayutaSkill2 = SkillData.nayutaS2[_nayutaS2Level];"),
        (r"      if \(_extraNikkeType != null\) \{\n        double cludBurstVal = _extraNikkeType == 'clud'\n            \? _parse\(_cludBurstController\.text\) / 100\n            : 0;",
         "      if (_extraNikkeType != null) {\n        double cludBurstVal = _extraNikkeType == 'clud' ? SkillData.cludBurst[_cludBurstLevel] : 0;"),
        # Image tap nayuta
        (r"        _buildCharacterInputRow\(\n            label: \"나유타\",\n            imagePath: \"assets/nikke/nayuta\.webp\",\n            color: Colors\.purple,\n            atkCtrl: _nayutaAtkController,\n            overCtrl: _nayutaOverController\),",
         """        _buildCharacterInputRow(
            label: "나유타",
            imagePath: "assets/nikke/nayuta.webp",
            color: Colors.purple,
            atkCtrl: _nayutaAtkController,
            overCtrl: _nayutaOverController,
            onImageTap: _showNayutaSkillDialog),"""),
        # Result Cards
        (r"미란다\(\$\\{_mirandaAtkController\.text\\}%\)", "미란다(Lv.$_mirandaBurstLevel)"),
        (r"2스\([0-9.]+%\)", "2스(Lv.$_nayutaS2Level)"),
        (r"자버프\(\$\\{_cludBurstController\.text\\}%\)", "자버프(Lv.$_cludBurstLevel)"),
        # Dialog
        (r"  void _showMirandaSettingsDialog\(\) \{\n    showDialog\(\n        context: context,\n        builder: \(context\) => AlertDialog\(\n                title: const Text\(\"미란다 설정\"\),\n                content: TextField\(\n                    controller: _mirandaAtkController,\n                    keyboardType:\n                        const TextInputType\.numberWithOptions\(decimal: true\),\n                    decoration: const InputDecoration\(labelText: \"미란다 공증 \(%\)\"\)\),\n                actions: \[\n                  TextButton\(\n                      onPressed: \(\) => Navigator\.pop\(context\),\n                      child: const Text\(\"취소\"\)\),\n                  ElevatedButton\(\n                      onPressed: \(\) \{\n                        setState\(\(\) \{\}\);\n                        Navigator\.pop\(context\);\n                      \},\n                      child: const Text\(\"확인\"\)\)\n                \]\)\);\n  \}\n\n  void _showBurstDialog\(\) \{\n    showDialog\(\n        context: context,\n        builder: \(context\) => AlertDialog\(\n                title: const Text\(\"클루드 버스트 설정\"\),\n                content: TextField\(\n                    controller: _cludBurstController,\n                    keyboardType:\n                        const TextInputType\.numberWithOptions\(decimal: true\),\n                    decoration: const InputDecoration\(labelText: \"자공증 \(%\)\"\)\),\n                actions: \[\n                  TextButton\(\n                      onPressed: \(\) => Navigator\.pop\(context\),\n                      child: const Text\(\"취소\"\)\),\n                  ElevatedButton\(\n                      onPressed: \(\) \{\n                        setState\(\(\) \{\}\);\n                        Navigator\.pop\(context\);\n                      \},\n                      child: const Text\(\"확인\"\)\)\n                \]\)\);\n  \}",
        """  void _showMirandaSettingsDialog() => _showSettingDialog("미란다 설정", (setDialogState) => [
        _buildSliderField("미란다 버스트", _mirandaBurstLevel, (v) => setDialogState(() => _mirandaBurstLevel = v))
      ]);

  void _showBurstDialog() => _showSettingDialog("클루드 스킬 설정", (setDialogState) => [
        _buildSliderField("버스트", _cludBurstLevel, (v) => setDialogState(() => _cludBurstLevel = v))
      ]);

  void _showNayutaSkillDialog() => _showSettingDialog("나유타 스킬 설정", (setDialogState) => [
        _buildSliderField("2스킬", _nayutaS2Level, (v) => setDialogState(() => _nayutaS2Level = v))
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

nayuta_helm()
