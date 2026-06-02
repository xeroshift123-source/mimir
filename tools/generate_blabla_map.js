const fs = require('fs');
const path = require('path');

function generate() {
  console.log("Generating Blabla mapping...");

  // 1. Character Mapping
  const charFilePath = path.join(__dirname, '../scratch/_character_ko_nikke_list_ko_v2.json');
  let charMapStr = '';
  if (fs.existsSync(charFilePath)) {
    const chars = JSON.parse(fs.readFileSync(charFilePath, 'utf8'));
    const uniqueChars = {};
    for (const c of chars) {
      if (c.name_code && c.name_localkey && c.name_localkey.name) {
        uniqueChars[c.name_code] = c.name_localkey.name;
      }
    }
    
    // 💡 Apply highly accurate overrides matching the user's account and database
    uniqueChars[5170] = "네온 : 비전아이";
    uniqueChars[5129] = "앨리스";
    uniqueChars[5024] = "드레이크";
    uniqueChars[5077] = "아인";
    uniqueChars[5156] = "스노우 화이트 : 헤비암즈";
    uniqueChars[5161] = "리버렐리오";
    uniqueChars[5169] = "아니스 : 스타";
    uniqueChars[5163] = "루마니";
    
    const entries = Object.entries(uniqueChars).map(([code, name]) => `    ${code}: "${name}",`).join('\n');
    charMapStr = `  static const Map<int, String> characterNames = {\n${entries}\n  };`;
    console.log(`Generated ${Object.keys(uniqueChars).length} character mappings.`);
  } else {
    console.error("Character JSON not found at:", charFilePath);
  }

  // 2. Equipment Mapping
  const equipFilePath = path.join(__dirname, '../scratch/_equip_ItemEquipTable-ko.json');
  let equipMapStr = '';
  if (fs.existsSync(equipFilePath)) {
    const equipData = JSON.parse(fs.readFileSync(equipFilePath, 'utf8'));
    const records = equipData.records || [];
    const uniqueEquips = {};
    for (const r of records) {
      if (r.id && r.name_localkey) {
        uniqueEquips[r.id] = r.name_localkey;
      }
    }
    const entries = Object.entries(uniqueEquips).map(([tid, name]) => `    ${tid}: "${name}",`).join('\n');
    equipMapStr = `  static const Map<int, String> equipmentNames = {\n${entries}\n  };`;
    console.log(`Generated ${Object.keys(uniqueEquips).length} equipment mappings.`);
  } else {
    console.error("Equipment JSON not found at:", equipFilePath);
  }

  // Write to blabla_map.dart
  const dartCode = `// Generated mapping file. Do not edit manually.
class BlablaMap {
${charMapStr}

${equipMapStr}
}
`;

  const outputDir = path.join(__dirname, '../lib/utils');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  fs.writeFileSync(path.join(outputDir, 'blabla_map.dart'), dartCode, 'utf8');
  console.log("blabla_map.dart successfully generated!");
}

generate();
