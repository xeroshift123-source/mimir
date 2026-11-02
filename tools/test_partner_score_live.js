'use strict';
// Synthetic-only smoke test. Set DILDORO_API_KEY in this process, never in source.
const fs = require('node:fs');
const path = require('node:path');
const axios = require('../functions/node_modules/axios');
const { TARGETS, buildScoreItem, requestBody } = require('../functions/nikkeScoreAdapter');
const standards = require('../functions/nikkeScoreStandards.json');

async function main() {
  const key = process.env.DILDORO_API_KEY;
  if (!key) throw Error('DILDORO_API_KEY is required');
  const results = [];
  for (const [code, target] of TARGETS) {
    if (process.env.SCORE_TEST_KEYS && !process.env.SCORE_TEST_KEYS.split(',').includes(code)) continue;
    const fixed = structuredClone(standards[code]);
    const commander = { characters: fixed.characters.filter(c => c.name_code === target.nameCode),
      stateEffects: fixed.stateEffects,
      recycleRoom: [1001, 1101, 1102, 1103, 1201, 1202, 1203, 1204, 1205]
        .map(tid => ({ tid, lv: tid === 1001 ? 180 : 100 })) };
    const base = buildScoreItem(commander, code, 'synthetic-base');
    commander.characters[0].core = 7;
    const stronger = buildScoreItem(commander, code, 'synthetic-core7');
    const items = [base, stronger];
    if (code === '5124:electric') {
      commander.characters[0].equipment[0].overloadOptions = [7000602, 7001001, 0];
      commander.stateEffects.push(
        { id: '7000602', function_details: [{ function_type: 'StatAccuracyCircle', function_value: -547 }] },
        { id: '7001001', function_details: [{ function_type: 'StatChargeTime', function_value: -198 }] });
      items.push(buildScoreItem(commander, code, 'synthetic-signed-options'));
    }
    const body = JSON.stringify(requestBody(code, items));
    const response = await axios.post('https://dildoro.com/api/partner/v1/damage', body, {
      timeout: 60000, maxRedirects: 0, validateStatus: () => true,
      headers: { 'X-Api-Key': key, 'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body), 'User-Agent': 'Mozilla/5.0 (compatible; Mimir/1.0)' },
    });
    const payload = response.data;
    const row = { profileKey: code, nameCode: target.nameCode, name: target.name, weakness: target.weakness,
      httpStatus: response.status, calcVersion: payload?.calc_version,
      items: payload?.items || [],
    };
    results.push(row);
    console.log(JSON.stringify(row));
    if (response.status !== 200 || !Array.isArray(payload?.items)
      || payload.items.length !== items.length || payload.items.some(i => i.error)) {
      process.exitCode = 1;
    }
  }
  const dir = path.resolve(__dirname, '../scratch');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'partner-score-live-results.json'), JSON.stringify(results, null, 2));
}
main().catch(error => { console.error(error?.code || 'live_test_failed'); process.exitCode = 1; });
