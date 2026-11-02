'use strict';
const { randomUUID } = require('node:crypto');
const { TARGETS, POLICY_HASH, buildScoreItem, inputHash, ScoreError } = require('./nikkeScoreAdapter');
const millis = value => value?.toMillis?.() || Number(value) || 0;

// One-time migration only: copy exact matching historical cache results.
// No calculator dependency, no guessing missing values, no replacement of sync results.
async function migrateCachedScores({ db, openId, apply = false, now = Date.now() }) {
  const profileRef = db.collection('commanders').doc(openId);
  const resultRef = db.collection('nikke_score_results').doc(openId);
  const [profileDoc, existing] = await Promise.all([profileRef.get(), resultRef.get()]);
  const profile = profileDoc.data();
  if (!profile || existing.exists || profile.scoreSyncId) return { skipped: true };
  const keys = [], hashes = [];
  for (const [key] of TARGETS) {
    try {
      const item = buildScoreItem(profile, key, 'cache-migration');
      keys.push(key); hashes.push(inputHash(item, key));
    } catch (error) { if (!(error instanceof ScoreError)) throw error; }
  }
  if (!keys.length) return { matched: 0 };
  const cached = await db.getAll(...hashes.map(hash => db.collection('nikke_score_cache').doc(hash)));
  const results = {};
  for (let i = 0; i < keys.length; i++) {
    const c = cached[i].data(), key = keys[i], target = TARGETS.get(key);
    if (!Number.isSafeInteger(c?.damage) || c.damage < 0 || typeof c.calcVersion !== 'string' || !c.calcVersion) continue;
    results[key] = { status: 'complete', profileKey: key, nameCode: target.nameCode, weakness: target.weakness,
      team: target.teamNames, damage: c.damage, score: c.damage * 5 / 1e8, calcVersion: c.calcVersion,
      policyHash: POLICY_HASH, inputHash: hashes[i], calculatedAtMs: c.updatedAtMs || now };
  }
  const matched = Object.keys(results).length;
  if (!apply || !matched) return { matched };
  const syncId = `cache-${randomUUID()}`;
  const applied = await db.runTransaction(async tx => {
    const current = (await tx.get(profileRef)).data();
    const saved = await tx.get(resultRef);
    if (!current || current.scoreSyncId || saved.exists
      || millis(current.lastUpdatedAt) !== millis(profile.lastUpdatedAt)) return false;
    tx.set(profileRef, { scoreSyncId: syncId }, { merge: true });
    tx.set(resultRef, { syncId, status: matched === keys.length ? 'complete' : 'partial',
      origin: 'matching-cache-migration', results, createdAtMs: now, completedAtMs: now, policyHash: POLICY_HASH });
    return true;
  });
  return { matched, applied };
}
module.exports = { migrateCachedScores };
