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


def ein_ada():
    filepath = r'c:\MMR\mimir\lib\widgets\ein_ada_form.dart'
    changes = [
        # Variables
        (r'  final _takinaS1Controller = TextEditingController\(text: "[0-9.]+"\);', '  int _takinaS1Level = 1;'),
        (r'  final _mirandaAtkController = TextEditingController\(text: "[0-9.]+"\);\n  final _adaS1Controller = TextEditingController\(text: "[0-9.]+"\);\n  final _adaBurstController = TextEditingController\(text: "[0-9.]+"\);\n  final _einS1Controller = TextEditingController\(text: "[0-9.]+"\);', 
         '  int _mirandaBurstLevel = 10;\n  int _adaS1Level = 10;\n  int _adaBurstLevel = 10;\n  int _einS1Level = 10;'),
        # Sync Miranda
        (r'      Map<String, dynamic>\? takinaChar;', '      Map<String, dynamic>? takinaChar;\n      Map<String, dynamic>? mirandaChar;'),
        (r"        if \(mappedName == '타키나'\) takinaChar = char;", "        if (mappedName == '타키나') takinaChar = char;\n        if (mappedName == '미란다') mirandaChar = char;"),
        # Sync Levels
        (r"      if \(einChar != null\) applyCharStats\(einChar, '아인', _einAtkController, _einOverController\);\n      if \(adaChar != null\) applyCharStats\(adaChar, '에이다', _adaAtkController, _adaOverController\);\n      if \(_useTakina && takinaChar != null\) \{\n        applyCharStats\(takinaChar, '타키나', _takinaAtkController, _takinaOverController\);\n      \}",
         """      if (mirandaChar != null) {
        final skills = mirandaChar['skills'] as Map<String, dynamic>? ?? {};
        _mirandaBurstLevel = skills['burst'] ?? 10;
      }
      if (einChar != null) {
        applyCharStats(einChar, '아인', _einAtkController, _einOverController);
        final skills = einChar['skills'] as Map<String, dynamic>? ?? {};
        _einS1Level = skills['skill1'] ?? 10;
      }
      if (adaChar != null) {
        applyCharStats(adaChar, '에이다', _adaAtkController, _adaOverController);
        final skills = adaChar['skills'] as Map<String, dynamic>? ?? {};
        _adaS1Level = skills['skill1'] ?? 10;
        _adaBurstLevel = skills['burst'] ?? 10;
      }
      if (_useTakina && takinaChar != null) {
        applyCharStats(takinaChar, '타키나', _takinaAtkController, _takinaOverController);
        final skills = takinaChar['skills'] as Map<String, dynamic>? ?? {};
        _takinaS1Level = skills['skill1'] ?? 1;
      }"""),
        # Dispose
        (r"    _takinaS1Controller\.dispose\(\);\n    _mirandaAtkController\.dispose\(\);\n    _adaS1Controller\.dispose\(\);\n    _adaBurstController\.dispose\(\);\n    _einS1Controller\.dispose\(\);\n", ""),
        # Calculate
        (r"      double miranda = _parse\(_mirandaAtkController\.text\) / 100;\n      double aS1 = _parse\(_adaS1Controller\.text\) / 100;\n      double aB = _parse\(_adaBurstController\.text\) / 100;\n      double eS1 = _parse\(_einS1Controller\.text\) / 100;",
         "      double miranda = SkillData.mirandaBurst[_mirandaBurstLevel];\n      double aS1 = SkillData.adaS1[_adaS1Level];\n      double aB = SkillData.adaBurst[_adaBurstLevel];\n      double eS1 = SkillData.einS1[_einS1Level];"),
        (r"      double tS1 = _parse\(_takinaS1Controller\.text\) / 100;", "      double tS1 = SkillData.takinaS1[_takinaS1Level];"),
        # Result Cards
        (r"미란다\(\$\\{_mirandaAtkController\.text\\}%\)", "미란다(Lv.$_mirandaBurstLevel)"),
        (r"1스\(\$\\{_adaS1Controller\.text\\}%\)", "1스(Lv.$_adaS1Level)"),
        (r"버스트\(\$\\{_adaBurstController\.text\\}%\)", "버스트(Lv.$_adaBurstLevel)"),
        (r"1스\(\$\\{_einS1Controller\.text\\}%\)", "1스(Lv.$_einS1Level)"),
        (r"1스\(\$\\{_takinaS1Controller\.text\\}%\)", "1스(Lv.$_takinaS1Level)"),
        # Dialog
        (r"  void _showMirandaDialog\(\) => _showSettingDialog\(\n      \"미란다 설정\", \[_buildPopupField\(\"미란다 버스트 공증 \(%\)\", _mirandaAtkController\)\]\);\n  void _showAdaSkillDialog\(\) => _showSettingDialog\(\"에이다 스킬 설정\", \[\n        _buildPopupField\(\"1스킬 공증 \(%\)\", _adaS1Controller\),\n        _buildPopupField\(\"버스트 자공증 \(%\)\", _adaBurstController\)\n      \]\);\n  void _showEinSkillDialog\(\) => _showSettingDialog\(\n      \"아인 스킬 설정\", \[_buildPopupField\(\"1스킬 공증 \(%\)\", _einS1Controller\)\]\);\n  void _showTakinaSkillDialog\(\) => _showSettingDialog\(\n      \"타키나 스킬 설정\", \[_buildPopupField\(\"1스킬 자공증 \(%\)\", _takinaS1Controller\)\]\);\n\n  void _showSettingDialog\(String title, List<Widget> fields\) \{\n    showDialog\(\n        context: context,\n        builder: \(context\) => AlertDialog\(\n                title: Text\(title,\n                    style: const TextStyle\(\n                        fontSize: 16, fontWeight: FontWeight\.bold\)\),\n                content:\n                    Column\(mainAxisSize: MainAxisSize\.min, children: fields\),\n                actions: \[\n                  TextButton\(\n                      onPressed: \(\) => Navigator\.pop\(context\),\n                      child: const Text\(\"취소\"\)\),\n                  ElevatedButton\(\n                      onPressed: \(\) \{\n                        setState\(\(\) \{\}\);\n                        Navigator\.pop\(context\);\n                      \},\n                      style: ElevatedButton\.styleFrom\(\n                          backgroundColor: Colors\.orange\),\n                      child: const Text\(\"확인\",\n                          style: TextStyle\(color: Colors\.white\)\)\)\n                \]\)\);\n  \}\n\n  Widget _buildPopupField\(String label, TextEditingController controller\) \{\n    final isDark = Theme\.of\(context\)\.brightness == Brightness\.dark;\n    return Padding\(\n        padding: const EdgeInsets\.symmetric\(vertical: 8\),\n        child: TextField\(\n            controller: controller,\n            keyboardType: const TextInputType\.numberWithOptions\(decimal: true\),\n            style: TextStyle\(color: isDark \? Colors\.white : Colors\.black\),\n            decoration: InputDecoration\(\n                labelText: label,\n                labelStyle: TextStyle\(\n                    color:\n                        isDark \? Colors\.grey\.shade400 : Colors\.grey\.shade700\),\n                enabledBorder: OutlineInputBorder\(\n                    borderRadius: BorderRadius\.circular\(10\),\n                    borderSide: BorderSide\(\n                        color: isDark\n                            \? Colors\.grey\.shade800\n                            : Colors\.grey\.shade300\)\),\n                border: OutlineInputBorder\(\n                    borderRadius: BorderRadius\.circular\(10\)\)\)\)\);\n  \}",
        """  void _showMirandaDialog() => _showSettingDialog("미란다 설정", (setDialogState) => [
        _buildSliderField("미란다 버스트", _mirandaBurstLevel, (v) => setDialogState(() => _mirandaBurstLevel = v))
      ]);
  void _showAdaSkillDialog() => _showSettingDialog("에이다 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬", _adaS1Level, (v) => setDialogState(() => _adaS1Level = v)),
        _buildSliderField("버스트", _adaBurstLevel, (v) => setDialogState(() => _adaBurstLevel = v))
      ]);
  void _showEinSkillDialog() => _showSettingDialog("아인 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬", _einS1Level, (v) => setDialogState(() => _einS1Level = v))
      ]);
  void _showTakinaSkillDialog() => _showSettingDialog("타키나 스킬 설정", (setDialogState) => [
        _buildSliderField("1스킬", _takinaS1Level, (v) => setDialogState(() => _takinaS1Level = v))
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

ein_ada()
