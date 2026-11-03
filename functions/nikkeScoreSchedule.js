'use strict';

const { randomUUID } = require('node:crypto');
const { TARGETS, POLICY_HASH, ScoreError } = require('./nikkeScoreAdapter');
const { withLease } = require('./nikkeScoreApi');
const { ELEMENTS, elementDamageTotals } = require('./nikkeScoreElements');
const PAGE_SIZE = 100;
const DAY = 86400000;
const millis = value => value?.toMillis?.() || Number(value) || 0;

// One page per invocation: resumable even for populations that exceed 540s.
async function refreshScorePage({ db, now = Date.now(), force = false }) {
  return withLease(db, 'statistics_lock', 530000, async () => {
    const jobRef = db.collection('nikke_score_state').doc('statistics');
    let job = (await jobRef.get()).data();
    const observed = (await db.collection('nikke_score_state').doc('version').get()).data();
    const versionChanged = job?.calcVersion && observed?.calcVersion && job.calcVersion !== observed.calcVersion;
    if (force && job?.complete) job = null;
    if (job?.source === 'stored-sync-v2' && job?.policyHash === POLICY_HASH && job?.nextRunAtMs > now && !versionChanged) return { waiting: true };
    if (!job || job.source !== 'stored-sync-v2' || job.policyHash !== POLICY_HASH || job.complete || versionChanged) {
      job = { source: 'stored-sync-v2', generation: randomUUID(), policyHash: POLICY_HASH, startedAtMs: now,
        cursor: null, page: 0, calcVersion: observed?.calcVersion || null, complete: false };
      await jobRef.set(job);
    }
    let query = db.collection('open_id_bindings').orderBy('__name__').limit(PAGE_SIZE).select('uid');
    if (job.cursor) query = query.startAfter(job.cursor);
    const bindings = await query.get();
    const refs = bindings.docs.filter(d => typeof d.data()?.uid === 'string' && d.data().uid.trim())
      .map(d => db.collection('commanders').doc(d.id));
    const profiles = refs.length ? await db.getAll(...refs, { fieldMask: ['scoreSyncId', 'lastUpdatedAt', 'characters'] }) : [];
    const scoreDocs = refs.length ? await db.getAll(...refs.map(ref => db.collection('nikke_score_results').doc(ref.id))) : [];
    const pageSamples = Object.fromEntries([...TARGETS.keys()].map(key => [key, []]));
    const elementSamples = Object.fromEntries(Object.keys(ELEMENTS).map(key => [key, []]));
    for (let i = 0; i < profiles.length; i++) {
      const commander = profiles[i].data(), scores = scoreDocs[i].data();
      if (!commander || !scores || !commander.scoreSyncId || commander.scoreSyncId !== scores.syncId
        || millis(commander.lastUpdatedAt) < job.startedAtMs - 30 * DAY) continue;
      for (const [key, result] of Object.entries(scores.results || {})) {
        if (pageSamples[key] && result.status === 'complete' && result.policyHash === POLICY_HASH
          && result.calcVersion === job.calcVersion && Number.isSafeInteger(result.damage) && result.damage >= 0) {
          pageSamples[key].push(result.damage);
        }
      }
      for (const [key, damage] of Object.entries(elementDamageTotals(scores, commander, job.calcVersion))) {
        elementSamples[key].push(damage);
      }
    }
    await db.collection('nikke_score_pages').doc(String(job.page)).set({
      generation: job.generation, samples: pageSamples, elementSamples,
    });
    if (bindings.size === PAGE_SIZE) {
      await jobRef.set({ ...job, cursor: bindings.docs[bindings.docs.length - 1].id, page: job.page + 1 });
      return { page: job.page, continuing: true };
    }
    const pages = await db.collection('nikke_score_pages').where('generation', '==', job.generation).get();
    const batch = db.batch();
    for (const code of TARGETS.keys()) {
      const damages = pages.docs.flatMap(page => page.data().samples[String(code)] || []);
      batch.set(db.collection('nikke_score_distributions').doc(String(code)), {
        damages, policyHash: POLICY_HASH, calcVersion: job.calcVersion,
        generatedAtMs: now, populationStartedAtMs: job.startedAtMs, generation: job.generation,
      });
    }
    for (const key of Object.keys(ELEMENTS)) {
      batch.set(db.collection('nikke_score_distributions').doc(`element-${key}`), {
        damages: pages.docs.flatMap(page => page.data().elementSamples?.[key] || []),
        policyHash: POLICY_HASH, calcVersion: job.calcVersion, generatedAtMs: now,
        populationStartedAtMs: job.startedAtMs, generation: job.generation,
      });
    }
    // Next midnight in Korea, independent of when the previous sweep started.
    batch.set(jobRef, { ...job, complete: true,
      nextRunAtMs: Math.floor((now + 9 * 3600000) / DAY + 1) * DAY - 9 * 3600000, completedAtMs: now });
    await batch.commit();
    return { complete: true, pages: job.page + 1 };
  });
}
async function refreshAllScoreStatistics({ db }) {
  let result = await refreshScorePage({ db, force: true });
  while (result.continuing) result = await refreshScorePage({ db });
  return result;
}
function createNikkeScoreSchedule({ functions, db }) {
  return functions.runWith({ timeoutSeconds: 540, memory: '1GB' })
    .pubsub.schedule('every 5 minutes').timeZone('Asia/Seoul').onRun(async () => {
      try { return await refreshScorePage({ db }); }
      catch (error) {
        if (!(error instanceof ScoreError) || !['busy', 'upstream_timeout'].includes(error.code)) {
          console.error('Score statistics page failed:', error?.code || 'internal');
          throw new Error('Score statistics page failed');
        }
        return null; // Retain cursor; retry the same page on the next tick.
      }
    });
}
module.exports = { refreshScorePage, refreshAllScoreStatistics, createNikkeScoreSchedule };
