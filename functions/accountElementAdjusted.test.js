'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { elementWeight, adjustedTotals, buildAdjustedStatistics,
  attachAdjustedComparison } = require('./accountElementAdjusted');
const { buildStatisticsSnapshots } = require('./nikkeStatisticsStore');
const { aggregateAccountElementDamageStatistics } = require('./nikkeStatistics');
const elements = require('./nikkeElements.json');
const waterCode = Number(Object.keys(elements).find(code => elements[code].includes('Water')));

test('adoption thresholds use percent units and preserve the specified formula', () => {
  for (const [rate, multiplier] of [[0, .1], [2.99, .1], [3, .2], [4.99, .2], [5, .5], [9.99, .5], [10, 1], [100, 1]]) {
    assert.equal(elementWeight({ overload: [{ key: 'elementDamage', adoptionRate: rate,
      adopterAverageTotalPercent: 60, adopterAverageLineCount: 3 }] }), 60 * 3 * multiplier * .01);
  }
  assert.equal(elementWeight({ overload: [] }), 0);
});

test('weighted population includes zero accounts, and ranks using its own distribution', () => {
  const snapshots = [{ data: { nameCode: waterCode, overload: [{ key: 'elementDamage',
    adoptionRate: 50, adopterAverageTotalPercent: 58.82, adopterAverageLineCount: 3 }] } }];
  const cache = buildAdjustedStatistics(snapshots, [[[waterCode, 80]], []]);
  assert.ok(Math.abs(cache.weights[waterCode] - 1.7646) < 1e-12);
  assert.equal(adjustedTotals([[waterCode, 80]], cache.weights).Water, 141.17);
  const water = cache.elements.find(item => item.key === 'Water');
  assert.equal(water.adjustedAverage, 70.58);
  assert.deepEqual(water.histogram, { '141.17': 1, '0.00': 1 });
  const raw = [{ key: 'Water', topPercent: 88, averageTotalPercent: 123 }];
  const compared = attachAdjustedComparison(raw, cache, { characters: [] });
  assert.equal(compared[0].adjustedTopPercent, 75);
  assert.equal(compared[0].topPercent, 88);
  assert.equal(compared[0].averageTotalPercent, 123);
  assert.deepEqual(attachAdjustedComparison(raw, null, {}), raw);
});

test('daily pipeline keeps raw results unchanged and stores matching weights with adjusted distribution', () => {
  const commanders = [{ characters: [{ name_code: waterCode,
    equipment: [{ overloadOptions: [7000501] }] }] }, { characters: [] }];
  const snapshots = buildStatisticsSnapshots(commanders);
  assert.deepEqual(snapshots.find(item => item.id === 'account_element_damage').data,
    aggregateAccountElementDamageStatistics(commanders));
  const cache = snapshots.find(item => item.id === 'account_element_adjusted').data;
  assert.equal(cache.sampleCount, 2);
  assert.equal(cache.weights[waterCode], .0954);
  assert.equal(cache.elements.find(item => item.key === 'Water').histogram['0.91'], 1);
  for (const element of cache.elements) {
    assert.equal(Object.values(element.histogram).reduce((a, b) => a + b, 0), 2);
  }
});

test('dual elements receive the contribution and missing weights contribute zero', () => {
  const dual = Object.keys(elements).find(code => elements[code].length > 1);
  assert.ok(dual);
  const totals = adjustedTotals([[dual, 10], [waterCode, 99]], { [dual]: 2 });
  for (const key of elements[dual]) assert.equal(totals[key], 20);
});
