'use strict';
const { randomUUID } = require('node:crypto');
const { TARGETS, POLICY_HASH, ScoreError, buildScoreItem, inputHash } = require('./nikkeScoreAdapter');
const { createScoreApi, checkItem } = require('./nikkeScoreApi');

function pendingScoreSnapshot(syncId, now = Date.now()) {
  return { syncId, status: 'pending', policyHash: POLICY_HASH, results: {}, createdAtMs: now };
}

// Invoked only by successful profile syncs, never by views or ranking jobs.
async function calculateSyncedScores({ db, openId, syncId, commander,
  calculate = createScoreApi(db), wait = ms => new Promise(resolve => setTimeout(resolve, ms)),
  now = () => Date.now() }) {
  const ref = db.collection('nikke_score_results').doc(openId);
  const claimed = await db.runTransaction(async tx => {
    const snapshot = (await tx.get(ref)).data();
    if (snapshot?.syncId !== syncId || snapshot.status !== 'pending') return false;
    tx.set(ref, { ...snapshot, status: 'running', startedAtMs: now() });
    return true;
  });
  if (!claimed) return { skipped: true };
  const startedAt = now();
  const owned = new Set((commander.characters || []).map(c => c.name_code));
  const results = {};
  const groups = new Map();
  const failure = error => ({ status: 'error', code: error instanceof ScoreError ? error.code : 'internal',
    error: error instanceof ScoreError ? error.message : '동기화 후 스코어 저장에 실패했습니다. 다음 동기화에서 다시 계산합니다.' });
  async function save(status) {
    return db.runTransaction(async tx => {
      const snapshot = (await tx.get(ref)).data();
      if (snapshot?.syncId !== syncId) return false;
      tx.set(ref, { ...snapshot, status, results, updatedAtMs: now(),
        ...(status === 'running' ? {} : { completedAtMs: now() }) });
      return true;
    });
  }
  for (const [key, target] of TARGETS) {
    if (!owned.has(target.nameCode)) continue;
    try {
      const item = buildScoreItem(commander, key, randomUUID());
      if (!groups.has(target.weakness)) groups.set(target.weakness, []);
      groups.get(target.weakness).push({ key, target, item });
    } catch (error) { results[key] = failure(error); }
  }
  // The API shares battle conditions per request, but each item has its own
  // target, party and growth. Batch by weakness (up to 100 items), not by Nikke.
  const batches = [...groups.values()].flatMap(rows => {
    const chunks = [];
    for (let i = 0; i < rows.length; i += 100) chunks.push(rows.slice(i, i + 100));
    return chunks;
  });
  for (const batch of batches) {
    if ((await ref.get()).data()?.syncId !== syncId) return { superseded: true };
    try {
      if (now() - startedAt > 420000) {
        throw new ScoreError('sync_score_timeout', '동기화 점수 계산 시간이 초과됐습니다. 다음 동기화에서 다시 계산합니다.');
      }
      let response;
      for (let attempt = 0; ; attempt++) {
        try { response = await calculate(batch[0].key, batch.map(row => row.item)); break; }
        catch (error) {
          if (!error.retryAfter || attempt >= 2 || now() - startedAt > 400000) throw error;
          await wait(Math.min(error.retryAfter, 30) * 1000);
          if ((await ref.get()).data()?.syncId !== syncId) return { superseded: true };
        }
      }
      const responses = new Map(response.items.map(item => [item.id, item]));
      for (const { key, target, item } of batch) {
        try {
          const result = responses.get(item.id);
          if (!result) throw new ScoreError('invalid_response', '계산 결과가 요청과 일치하지 않습니다.', 502);
          const damage = checkItem(result);
          results[key] = { status: 'complete', damage, score: damage * 5 / 100000000,
            calcVersion: response.calc_version, policyHash: POLICY_HASH, profileKey: key,
            nameCode: target.nameCode, weakness: target.weakness, team: target.teamNames,
            inputHash: inputHash(item, key), calculatedAtMs: now() };
        } catch (error) { results[key] = failure(error); }
      }
    } catch (error) {
      for (const { key } of batch) results[key] = failure(error);
    }
    if (!await save('running')) return { superseded: true };
  }
  const status = Object.values(results).some(r => r.status === 'error') ? 'partial' : 'complete';
  if (!await save(status)) return { superseded: true };
  return { status, count: Object.keys(results).length };
}
module.exports = { pendingScoreSnapshot, calculateSyncedScores };
