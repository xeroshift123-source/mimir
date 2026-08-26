const fs = require('fs');
const path = require('path');

function generate() {
  console.log("Generating Blabla mapping...");

  // Equipment Mapping
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

  const outputDir = path.join(__dirname, '../lib/utils');
  const outputPath = path.join(outputDir, 'blabla_map.dart');
  if (!fs.existsSync(outputPath)) {
    console.error('Existing blabla_map.dart not found:', outputPath);
    return;
  }
  const dartCode = fs.readFileSync(outputPath, 'utf8');
  const updatedCode = dartCode.replace(
    /  static const Map<int, String> equipmentNames = \{[\s\S]*?\n  \};/,
    equipMapStr,
  );
  if (updatedCode === dartCode) {
    console.error('equipmentNames block not found in blabla_map.dart');
    return;
  }
  fs.writeFileSync(outputPath, updatedCode, 'utf8');
  console.log("blabla_map.dart equipment mapping successfully updated!");
}

generate();
