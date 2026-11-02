// Run against `python -m http.server 8765 --bind 127.0.0.1 --directory web`.
// npm install --prefix scratch/score-runtime --ignore-scripts playwright-core@1.56.1
import { chromium } from '../scratch/score-runtime/node_modules/playwright-core/index.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const browser = await chromium.launch({ headless: true,
  executablePath: process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  const requests = [];
  context.on('request', request => requests.push(request.url()));
  page.on('console', message => { if (message.type() === 'error') console.error(message.text()); });
  await page.goto('http://127.0.0.1:8765/score/bundle-manifest.json');
  const fixtures = JSON.parse(fs.readFileSync('services/nikke_score/examples/score-reference.inputs.json', 'utf8'));
  const expected = JSON.parse(fs.readFileSync('services/nikke_score/examples/score-reference.results.json', 'utf8'));
  const calculate = spec => page.evaluate(spec => new Promise((resolve, reject) => {
    const worker = new Worker('/score/rapi-score-worker.js');
    const timer = setTimeout(() => { worker.terminate(); reject(new Error('timeout')); }, 180000);
    worker.onmessage = event => {
      clearTimeout(timer); worker.terminate();
      resolve(JSON.parse(event.data));
    };
    worker.onerror = event => { clearTimeout(timer); worker.terminate(); reject(new Error(event.message)); };
    worker.postMessage(JSON.stringify(spec));
  }), spec);
  for (const [target, fixture] of Object.entries(fixtures)) {
    const started = Date.now();
    const result = await calculate(fixture);
    assert.equal(result.score, expected[target].score, target);
    console.log(JSON.stringify({ target, ...result, milliseconds: Date.now() - started }));
  }
  const input = fixtures.rapi_red_hood;
  // Older saved specs lack provenance, but their explicit growth must still be used.
  delete input.character.growthDataQuality;
  input.character.core = 2;
  const changed = await calculate(input);
  assert.equal(changed.score, expected.rapi_red_hood.core2Score);
  console.log(JSON.stringify({ test: 'actual_core_2_legacy_spec', ...changed }));
  delete input.character.skills;
  assert.equal((await calculate(input)).error, 'score_unavailable');
  assert(requests.every(url => url.startsWith('http://127.0.0.1:8765/')));
  console.log(`PASS: all ${Object.keys(fixtures).length} functions, local-only assets, changed growth, missing input`);
} finally {
  await browser.close();
}
