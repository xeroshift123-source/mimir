'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createAccountElementDamageHandler } = require('./accountElementDamageEndpoint');

async function request(adjustedTime) {
  const time = value => ({ toMillis: () => value });
  const records = {
    'open_id_bindings/mine': { uid: 'user' },
    'users/user': {},
    'commanders/mine': { characters: [] },
    'nikke_statistics/account_element_damage': {
      generatedAt: time(1000), sampleCount: 2,
      elements: [{ key: 'Water', name: '수냉', averageTotalPercent: 40,
        histogram: { '0.00': 1, '80.00': 1 } }],
    },
  };
  if (adjustedTime != null) records['nikke_statistics/account_element_adjusted'] = {
    generatedAt: time(adjustedTime), sampleCount: 2, formulaVersion: 1, weights: {},
    elements: [{ key: 'Water', adjustedAverage: 0, histogram: { '0.00': 2 } }],
  };
  const reads = [];
  const handler = createAccountElementDamageHandler({
    functions: { runWith: () => ({ https: { onRequest: callback => callback } }) },
    getAuthenticatedUid: async () => 'user',
    db: { collection: collection => ({ doc: id => ({ async get() {
      const key = `${collection}/${id}`;
      reads.push(key);
      return { exists: Object.hasOwn(records, key), data: () => records[key] };
    } }) }) },
  });
  const response = { statusCode: 200, set() {}, status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; } };
  await handler({ method: 'POST', headers: {}, body: { openId: 'mine' } }, response);
  assert.equal(response.statusCode, 200);
  assert.equal(reads.length, 5);
  assert.equal(reads.filter(key => key.startsWith('commanders/')).length, 1);
  assert.equal(JSON.stringify(response.body).includes('histogram'), false);
  assert.equal(JSON.stringify(response.body).includes('weights'), false);
  return response.body.data.elements[0];
}

test('endpoint compares with the cached adjusted distribution without exposing it', async () => {
  const result = await request(1000);
  assert.equal(result.topPercent, 75);
  assert.equal(result.adjustedTopPercent, 50);
  assert.equal(result.adjustedScore, 0);
});
test('missing or mismatched adjusted generation preserves the old response', async () => {
  for (const stamp of [null, 2000]) {
    const result = await request(stamp);
    assert.equal(result.topPercent, 75);
    assert.equal(result.adjustedScore, undefined);
  }
});
