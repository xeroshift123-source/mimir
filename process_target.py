import re
import io

def process_file():
    filepath = r'c:\MMR\mimir\lib\widgets\matcha_gakseol_form.dart'
    with io.open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()

    # Remove variables
    text = re.sub(r'  double targetMatcha = 0;\n  double targetGakseol = 0;\n  List<String> bufferedNikkes = \[\];\n\n', '', text)
    text = re.sub(r'  bool matchaHasMiranda = false;\n  bool gakseolHasMiranda = false;\n', '', text)

    # Calculate
    old_calc = """      double nBase = _parse(_matchaAtkController.text);
      double nOver = _parse(_matchaOverController.text) / 100;
      double nPre = nBase * (1 + nOver + matchaSkill2);

      double hBase = _parse(_gakseolAtkController.text);
      double hOver = _parse(_gakseolOverController.text) / 100;
      double gakseolSkill2 = SkillData.gakseolS2[_gakseolS2Level];
      double hPre = hBase * (1 + hOver + gakseolSkill2);

      targetMatcha = nPre;
      targetGakseol = hPre;

      List<Map<String, dynamic>> comparisonList = [
        {'id': 'matcha', 'name': '마르차나 : 마린 스터디', 'val': nPre},
        {'id': 'gakseol', 'name': '스노우 화이트 : 헤비암즈', 'val': hPre}
      ];
      comparisonList.sort((a, b) => b['val'].compareTo(a['val']));
      Set<String> top2 = {comparisonList[0]['id'], comparisonList[1]['id']};
      bufferedNikkes = [
        comparisonList[0]['name'] as String,
        comparisonList[1]['name'] as String
      ];

      matchaHasMiranda = top2.contains('matcha');
      gakseolHasMiranda = top2.contains('gakseol');

      resMatchaFinal = nBase *
          (1 + nOver + matchaSkill2 + (matchaHasMiranda ? mirandaVal : 0));
      resGakseolFinal = hBase *
          (1 + hOver + gakseolSkill2 + (gakseolHasMiranda ? mirandaVal : 0));"""
    
    new_calc = """      double nBase = _parse(_matchaAtkController.text);
      double nOver = _parse(_matchaOverController.text) / 100;

      double hBase = _parse(_gakseolAtkController.text);
      double hOver = _parse(_gakseolOverController.text) / 100;
      double gakseolSkill2 = SkillData.gakseolS2[_gakseolS2Level];

      resMatchaFinal = nBase * (1 + nOver + matchaSkill2 + mirandaVal);
      resGakseolFinal = hBase * (1 + hOver + gakseolSkill2 + mirandaVal);"""
    
    text = text.replace(old_calc, new_calc)

    # Build
    old_build_card = """        _buildTargetingCheckCard(),
        const SizedBox(height: 12),
        _buildResultCard(
          "미란다 버프 우선순위 및 최종 결과",
          resMatchaFinal,
          resGakseolFinal,
          [
            "마르차나: 오버 + 2스(Lv.$_matchaS2Level)${matchaHasMiranda ? ' + 미란다(Lv.$_mirandaBurstLevel)' : ''}",
            "스노우화이트: 오버 + 2스(Lv.$_gakseolS2Level)${gakseolHasMiranda ? ' + 미란다(Lv.$_mirandaBurstLevel)' : ''}",
          ],
          onSettingsTap: _showMirandaSettingsDialog,
        ),"""
        
    new_build_card = """        _buildResultCard(
          "미란다 버프 포함 최종 결과",
          resMatchaFinal,
          resGakseolFinal,
          [
            "마르차나: 오버 + 2스(Lv.$_matchaS2Level, ${(SkillData.matchaS2[_matchaS2Level]*100).toStringAsFixed(2)}%) + 미란다(Lv.$_mirandaBurstLevel, ${(SkillData.mirandaBurst[_mirandaBurstLevel]*100).toStringAsFixed(2)}%)",
            "스노우화이트: 오버 + 2스(Lv.$_gakseolS2Level, ${(SkillData.gakseolS2[_gakseolS2Level]*100).toStringAsFixed(2)}%) + 미란다(Lv.$_mirandaBurstLevel, ${(SkillData.mirandaBurst[_mirandaBurstLevel]*100).toStringAsFixed(2)}%)",
          ],
          onSettingsTap: _showMirandaSettingsDialog,
        ),"""
    
    text = text.replace(old_build_card, new_build_card)
    
    # Remove _buildTargetingCheckCard completely
    targeting_card_regex = r'  Widget _buildTargetingCheckCard\(\) \{.*?\n  \}\n\n'
    text = re.sub(targeting_card_regex, '', text, flags=re.DOTALL)

    with io.open(filepath, 'w', encoding='utf-8') as f:
        f.write(text)

process_file()
