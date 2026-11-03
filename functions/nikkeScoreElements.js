'use strict';
const { TARGETS, POLICY_HASH, compareScore } = require('./nikkeScoreAdapter');
const ELEMENTS = { fire: '작열', water: '수냉', wind: '풍압', electric: '전격', iron: '철갑' };

// Unowned targets contribute zero; failed, missing or stale owned results do not
// become artificially low account totals. Sum damage before converting to score.
function elementDamageTotals(snapshot, commander, version) {
  if (!snapshot || !['complete', 'partial'].includes(snapshot.status)
    || snapshot.syncId !== commander?.scoreSyncId || !Array.isArray(commander.characters)
    || !version) return {};
  const owned = new Set((commander.characters || []).map(c => c.name_code));
  const totals = {};
  for (const element of Object.keys(ELEMENTS)) {
    let sum = 0, valid = true;
    for (const [key, target] of TARGETS) {
      if (target.weakness !== element || !owned.has(target.nameCode)) continue;
      const r = snapshot.results?.[key];
      if (r?.status !== 'complete' || r.policyHash !== POLICY_HASH || r.calcVersion !== version
        || !Number.isSafeInteger(r.damage) || r.damage < 0) { valid = false; break; }
      sum += r.damage;
    }
    if (valid && Number.isSafeInteger(sum)) totals[element] = sum;
  }
  return totals;
}

function compareElements(snapshot, commander, distributions, now = Date.now()) {
  const versions = new Set(Object.values(snapshot?.results || {})
    .filter(r => r.status === 'complete' && r.policyHash === POLICY_HASH).map(r => r.calcVersion));
  const version = versions.size === 1 ? [...versions][0] : null;
  const totals = elementDamageTotals(snapshot, commander, version);
  return Object.entries(ELEMENTS).map(([key, name]) => {
    const distribution = distributions[key];
    const damage = totals[key];
    const comparison = compareScore(distribution, damage, version, now);
    const valid = damage !== undefined;
    const samples = comparison.generatedAt ? distribution.damages : [];
    return { key, name, score: valid ? damage * 5 / 1e8 : null,
      average: samples.length ? samples.reduce((a, b) => a + b, 0) / samples.length * 5 / 1e8 : null,
      ...comparison, topPercent: valid ? comparison.topPercent : null };
  });
}
module.exports = { ELEMENTS, elementDamageTotals, compareElements };
