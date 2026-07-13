import re
import os
import io

def process_file(filepath):
    with io.open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()

    # Change dialog return type
    text = text.replace(
        'final selectedCubeLevels = await showDialog<Map<String, int>>(',
        'final selectedCubeLevels = await showDialog<Map<String, SyncOptions>>('
    )

    # Change applyCharStats logic
    old_apply_char_stats = """        final localNikke = nikkeNameMap[name];
        final modChar = injectConsoleLevels(char, localNikke);
        final customCube = selectedCubeLevels[name] ?? 0;
        
        double atk400 = 0;
        double overAtk = 0;"""

    new_apply_char_stats = """        final localNikke = nikkeNameMap[name];
        final modChar = injectConsoleLevels(char, localNikke);
        
        final customOptions = selectedCubeLevels[name] ?? SyncOptions();
        final customCube = customOptions.cubeLevel;
        
        final equips = List<dynamic>.from(modChar['equipment'] as List<dynamic>? ?? []);
        for(int i=0; i<equips.length; i++) {
           if (equips[i] == null) continue;
           final eq = Map<String, dynamic>.from(equips[i]);
           if(eq['slot'] == 'head') eq['level'] = customOptions.headLevel;
           if(eq['slot'] == 'torso') eq['level'] = customOptions.torsoLevel;
           if(eq['slot'] == 'arm') eq['level'] = customOptions.armLevel;
           if(eq['slot'] == 'leg') eq['level'] = customOptions.legLevel;
           equips[i] = eq;
        }
        modChar['equipment'] = equips;
        
        double atk400 = 0;
        double overAtk = 0;"""

    text = text.replace(old_apply_char_stats, new_apply_char_stats)

    with io.open(filepath, 'w', encoding='utf-8') as f:
        f.write(text)

files = [
    r'c:\MMR\mimir\lib\widgets\ein_ada_form.dart',
    r'c:\MMR\mimir\lib\widgets\nayuta_helm_form.dart',
    r'c:\MMR\mimir\lib\widgets\matcha_gakseol_form.dart'
]

for f in files:
    process_file(f)
