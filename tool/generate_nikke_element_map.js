'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'assets', 'nikkes.json');
const outputPath = path.join(root, 'functions', 'nikkeElements.json');
const alternateElements = {
  rapi_red_hood: ['Iron'],
  sugar: ['Water'],
};

const nikkes = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const elementMap = Object.fromEntries(nikkes.map(nikke => {
  const elements = [...new Set([
    nikke.element,
    ...(alternateElements[nikke.id] || []),
  ])];
  return [String(nikke.blablaNameCode), elements];
}));

fs.writeFileSync(outputPath, `${JSON.stringify(elementMap, null, 2)}\n`);
console.log(`Generated ${Object.keys(elementMap).length} Nikke element mappings.`);
