import re
import io

with io.open(r'c:\MMR\mimir\lib\widgets\matcha_gakseol_form.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Variables (Lines 29-32)
text = re.sub(r'  String\? _extraNikkeType;\n  final _extraAtkController = TextEditingController\(text: "80,000"\);\n  final _extraOverController = TextEditingController\(text: "0"\);\n  final _cludBurstController = TextEditingController\(text: "62.54"\);\n', '', text)

# 2. Variables (Line 37)
text = text.replace('  double targetExtra = 0;\n', '')
text = text.replace('  double resExtraFinal = 0;\n', '')
text = text.replace('  bool extraHasMiranda = false;\n', '')

# 3. Sync Logic Variables
text = text.replace('      Map<String, dynamic>? cludChar;\n      Map<String, dynamic>? cdieselChar;\n', '')
text = text.replace('        if (mappedName == \'루드밀라 : 윈터 오너\') cludChar = char;\n        if (mappedName == \'디젤 : 윈터 스위츠\') cdieselChar = char;\n', '')

# 4. Sync Dialog Nikkes
dialog_nikke = r'''      if \(_extraNikkeType == 'clud' && cludChar != null\) \{
        dialogNikkes\.add\(\{'name': '루드밀라 : 윈터 오너', 'char': cludChar, 'image': 'assets/nikke/ludmilla_winter_owner\.webp'\}\);
      \} else if \(_extraNikkeType == 'cdiesel' && cdieselChar != null\) \{
        dialogNikkes\.add\(\{'name': '디젤 : 윈터 스위츠', 'char': cdieselChar, 'image': 'assets/nikke/diesel_winter_sweets\.webp'\}\);
      \}'''
text = re.sub(dialog_nikke + '\n', '', text)

# 5. applyCharStats
apply_stats = r'''      if \(_extraNikkeType == 'clud' && cludChar != null\) \{
        applyCharStats\(cludChar, '루드밀라 : 윈터 오너', _extraAtkController, _extraOverController\);
      \} else if \(_extraNikkeType == 'cdiesel' && cdieselChar != null\) \{
        applyCharStats\(cdieselChar, '디젤 : 윈터 스위츠', _extraAtkController, _extraOverController\);
      \}'''
text = re.sub(apply_stats + '\n', '', text)

# 6. Dispose
text = text.replace('    _extraAtkController.dispose();\n    _extraOverController.dispose();\n    _cludBurstController.dispose();\n', '')

# 7. Calculate variables
text = text.replace('      double eBase = _parse(_extraAtkController.text);\n      double eOver = _parse(_extraOverController.text) / 100;\n      double ePre = (_extraNikkeType != null) ? (eBase * (1 + eOver)) : -1.0;\n', '')
text = text.replace('      targetExtra = _extraNikkeType != null ? ePre : 0;\n', '')

# 8. Comparison List
comp_list = r'''      if \(_extraNikkeType != null\) \{
        String eName = _extraNikkeType == 'clud' \? '클루드' : \(_extraNikkeType == 'cdiesel' \? '클디젤' : '일반3버'\);
        comparisonList\.add\(\{'id': 'extra', 'name': eName, 'val': ePre\}\);
      \}'''
text = re.sub(comp_list + '\n', '', text)

text = text.replace('      extraHasMiranda = top2.contains(\'extra\');\n', '')

# 9. Extra final
res_extra = r'''      if \(_extraNikkeType != null\) \{
        double cludBurstVal = _extraNikkeType == 'clud'
            \? _parse\(_cludBurstController\.text\) / 100
            : 0;
        resExtraFinal = eBase \*
            \(1 \+ eOver \+ cludBurstVal \+ \(extraHasMiranda \? mirandaVal : 0\)\);
      \}'''
text = re.sub(res_extra + '\n', '', text)

# 10. Max ATK rival
extra_rival = r'''      if \(_extraNikkeType != null && resExtraFinal > maxAtk\) \{
        maxAtk = resExtraFinal;
        rival = \(_extraNikkeType == 'clud'\) \? "클루드" : \(\(_extraNikkeType == 'cdiesel'\) \? "클디젤" : "일반 니케"\);
      \}'''
text = re.sub(extra_rival + '\n', '', text)

# 11. Error checking target diff
err_check = r'''      if \(_extraNikkeType != null && !matchaHasMiranda\) \{
        isError = true;
        resultMessage = "❌ 경고: 말차가 미란다 버프 타겟에서 밀려났습니다!";
        double targetDiff = min\(targetGakseol, targetExtra\) - targetMatcha;
        double neededIncrease = \(targetDiff / nBase\) \* 100;
        needOverloadMessage = "말차가 미란다 버프를 받으려면 오버공증이 최소 \$\{neededIncrease\.toStringAsFixed\(2\)\}% 더 필요합니다\.";
      \} else if \(maxAtk != resMatchaFinal\) \{'''
new_err_check = r'''      if (maxAtk != resMatchaFinal) {'''
text = re.sub(err_check, new_err_check, text)

text = text.replace('        double targetDiff = min(targetGakseol, targetExtra) - targetMatcha;', '        double targetDiff = targetGakseol - targetMatcha;')
# wait, actually the above replace might not be needed if I already replaced the whole block.
# Ah, I replaced the whole `if (_extraNikkeType != null && !matchaHasMiranda)` block so `targetDiff` is only in that removed block. Wait, I should add the logic to check if matcha has miranda buff.
# Actually, if maxAtk != resMatchaFinal, then matcha didn't win. Since there are only 2 chars now, it's just `if (maxAtk != resMatchaFinal)` or `if (targetGakseol > targetMatcha)`. The existing `else if (maxAtk != resMatchaFinal)` will handle it perfectly.

# 12. secondMaxAtk
second_max = r'''        if \(_extraNikkeType != null && resExtraFinal > resGakseolFinal\) \{
          secondMaxAtk = resExtraFinal;
          secondRival = \(_extraNikkeType == 'clud'\) \? "클루드" : \(\(_extraNikkeType == 'cdiesel'\) \? "클디젤" : "일반 니케"\);
          secondRivalBase = eBase;
        \}'''
text = re.sub(second_max + '\n', '', text)

# 13. _showBurstDialog
show_burst = r'''  void _showBurstDialog\(\) \{
    showDialog\(
        context: context,
        builder: \(context\) => AlertDialog\(
                title: const Text\("클루드 버스트 설정"\),
                content: TextField\(
                    controller: _cludBurstController,
                    keyboardType:
                        const TextInputType\.numberWithOptions\(decimal: true\),
                    decoration: const InputDecoration\(labelText: "자공증 \(%\)"\)\),
                actions: \[
                  TextButton\(
                      onPressed: \(\) => Navigator\.pop\(context\),
                      child: const Text\("취소"\)\),
                  ElevatedButton\(
                      onPressed: \(\) \{
                        setState\(\(\) \{\}\);
                        Navigator\.pop\(context\);
                      \},
                      child: const Text\("확인"\)\)
                \]\)\);
  \}'''
text = re.sub(show_burst + '\n', '', text)

# 14. Input row
input_row = r'''        if \(_extraNikkeType != null\) \.\.\[
          const SizedBox\(height: 16\),
          _buildCharacterInputRow\(
            label: _extraNikkeType == 'clud' \? "루드밀라:윈터오너" : \(_extraNikkeType == 'cdiesel' \? "디젤:윈터스위츠" : "일반3버"\),
            imagePath: _extraNikkeType == 'clud'
                \? "assets/nikke/ludmilla_winter_owner\.webp"
                : \(_extraNikkeType == 'cdiesel' \? "assets/nikke/diesel_winter_sweets\.webp" : "assets/nikke/soldiereg\.webp"\),
            color: Colors\.cyan,
            atkCtrl: _extraAtkController,
            overCtrl: _extraOverController,
            onImageTap: _extraNikkeType == 'clud' \? _showBurstDialog : null,
          \),
        \],
'''
text = re.sub(input_row, '', text)

# 15. Check card padding
check_card_pad = r'''        if \(_extraNikkeType != null\) \.\.\[
          _buildTargetingCheckCard\(\),
          const SizedBox\(height: 12\),
        \],'''
text = text.replace(check_card_pad, '        _buildTargetingCheckCard(),\n        const SizedBox(height: 12),')

# 16. Result notes
result_notes = r'''            if \(_extraNikkeType == 'clud'\)
              "클루드: 오버 \+ 자버프\(\$\{_cludBurstController\.text\}%\)\$\{extraHasMiranda \? ' \+ 미란다\(\$\{_mirandaAtkController\.text\}%\)' : ''\}",
            if \(_extraNikkeType == 'cdiesel'\)
              "클디젤: 오버\$\{extraHasMiranda \? ' \+ 미란다\(\$\{_mirandaAtkController\.text\}%\)' : ''\}",
            if \(_extraNikkeType == 'general'\)
              "일반3버: 오버\$\{extraHasMiranda \? ' \+ 미란다\(\$\{_mirandaAtkController\.text\}%\)' : ''\}",'''
text = re.sub(result_notes + '\n', '', text)

text = text.replace("          extraVal: _extraNikkeType != null ? resExtraFinal : null,\n          extraName: _extraNikkeType == 'clud' ? \"클루드\" : (_extraNikkeType == 'cdiesel' ? \"클디젤\" : \"일반3버\"),\n", "")

# 17. Button removing OutlinedButton
button_row = r'''      const SizedBox\(width: 8\),
      Expanded\(
          flex: 1,
          child: SizedBox\(
              height: 50,
              child: OutlinedButton\(
                  onPressed: \(\) \{\},
                  style: OutlinedButton\.styleFrom\(
                      side: const BorderSide\(color: Colors\.orange\),
                      shape: RoundedRectangleBorder\(
                          borderRadius: BorderRadius\.circular\(12\)\)\),
                  child: PopupMenuButton<String>\(
                      onSelected: \(val\) => setState\(\(\) =>
                          _extraNikkeType = \(val == 'remove' \? null : val\)\),
                      itemBuilder: \(context\) => \[
                            const PopupMenuItem\(
                                value: 'clud', child: Text\("클루드"\)\),
                            const PopupMenuItem\(
                                value: 'cdiesel', child: Text\("클디젤"\)\),
                            const PopupMenuItem\(
                                value: 'general', child: Text\("일반 니케"\)\),
                            const PopupMenuItem\(
                                value: 'remove',
                                child: Text\("제거",
                                    style: TextStyle\(color: Colors\.red\)\)\)
                          \],
                      child: const Row\(
                          mainAxisAlignment: MainAxisAlignment\.center,
                          children: \[
                            Text\("3버 추가",
                                style: TextStyle\(
                                    color: Colors\.orange,
                                    fontWeight: FontWeight\.bold,
                                    fontSize: 13\)\),
                            Icon\(Icons\.arrow_drop_down, color: Colors\.orange\)
                          \]\)\)\)\)\),'''
text = re.sub(button_row, '', text)

# 18. Target unit extra
target_extra = r'''          if \(_extraNikkeType != null\)
            _targetUnitColumn\(
                _extraNikkeType == 'clud' \? "클루드" : \(_extraNikkeType == 'cdiesel' \? "클디젤" : "일반3버"\),
                targetExtra,
                extraHasMiranda\),'''
text = re.sub(target_extra + '\n', '', text)

# 19. Result card parameters
text = text.replace('{double? extraVal, String? extraName, VoidCallback? onSettingsTap}', '{VoidCallback? onSettingsTap}')
text = text.replace('    if (extraVal != null && extraVal > max) max = extraVal;\n', '')

extra_res_row = r'''          if \(extraVal != null\) \.\.\[
            const SizedBox\(height: 4\),
            _resRow\(extraName!, _formatter\.format\(extraVal\.toInt\(\)\),
                extraVal == max, Colors\.cyan\)
          \],'''
text = re.sub(extra_res_row + '\n', '', text)


with io.open(r'c:\MMR\mimir\lib\widgets\matcha_gakseol_form.dart', 'w', encoding='utf-8') as f:
    f.write(text)

