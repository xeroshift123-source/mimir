import io
import re

with io.open(r'c:\MMR\mimir\lib\widgets\nayuta_helm_form.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('NayutaHelm', 'MatchaGakseol')
text = text.replace('_nayutaAtkController', '_matchaAtkController')
text = text.replace('_nayutaOverController', '_matchaOverController')
text = text.replace('_helmAtkController', '_gakseolAtkController')
text = text.replace('_helmOverController', '_gakseolOverController')
text = text.replace('targetNayuta', 'targetMatcha')
text = text.replace('targetHelm', 'targetGakseol')
text = text.replace('resNayutaFinal', 'resMatchaFinal')
text = text.replace('resHelmFinal', 'resGakseolFinal')
text = text.replace('nayutaHasMiranda', 'matchaHasMiranda')
text = text.replace('helmHasMiranda', 'gakseolHasMiranda')
text = text.replace('nayutaChar', 'matchaChar')
text = text.replace('helmChar', 'gakseolChar')

text = text.replace("'나유타'", "'마르차나 : 마린 스터디'")
text = text.replace("'헬름'", "'스노우 화이트 : 헤비암즈'")
text = text.replace('"나유타"', '"말차"')
text = text.replace('"헬름"', '"각설"')
text = text.replace('나유타', '말차')
text = text.replace('헬름', '각설')
text = text.replace('nayuta', 'matcha')
text = text.replace('helm', 'gakseol')

text = text.replace('assets/nikke/matcha.webp', 'assets/nikke/marciana_marine_study.webp')
text = text.replace('assets/nikke/gakseol.webp', 'assets/nikke/snow_white_heavy_arms.webp')

# Nayuta has a hardcoded skill 2 buff (0.152). Matcha (Marciana: Marine Study) might not have it or has a different one.
# For safety, I'll remove it or set it to 0.
# The variable is nayutaSkill2
text = text.replace('const double matchaSkill2 = 0.152;', 'const double matchaSkill2 = 0.0; // TODO: Adjust if she has ATK self buff')
text = text.replace("말차: 오버 + 2스(15.2%)", "말차: 오버")

with io.open(r'c:\MMR\mimir\lib\widgets\matcha_gakseol_form.dart', 'w', encoding='utf-8') as f:
    f.write(text)
