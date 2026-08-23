'use strict';

const { aggregateNikkeStatistics } = require('./nikkeStatistics');

const STATISTICS_SCHEMA_VERSION = 5;
const FRESHNESS_DAYS = 30;
const MINIMUM_SAMPLE = 20;

function statisticsCacheKey(nameCode) {
  return `all_${Number(nameCode)}`;
}

function timestampMillis(value) {
  if (typeof value?.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number(value) || 0;
}

async function loadEligibleLinkedCommanders(db, nowMs = Date.now()) {
  const bindings = await db.collection('open_id_bindings').get();
  const commanderRefs = bindings.docs
    .filter(doc => typeof doc.data()?.uid === 'string' && doc.data().uid.trim())
    .map(doc => db.collection('commanders').doc(doc.id));
  const snapshots = [];

  for (let index = 0; index < commanderRefs.length; index += 200) {
    const chunk = commanderRefs.slice(index, index + 200);
    if (chunk.length > 0) snapshots.push(...await db.getAll(...chunk));
  }

  const freshnessLimitMs = nowMs - FRESHNESS_DAYS * 24 * 60 * 60 * 1000;
  return snapshots
    .filter(snapshot => snapshot.exists)
    .map(snapshot => snapshot.data())
    .filter(commander => timestampMillis(commander.lastUpdatedAt) >= freshnessLimitMs);
}

function buildStatisticsSnapshots(commanders) {
  const nameCodes = new Set();

  for (const commander of commanders) {
    for (const character of Array.isArray(commander.characters) ? commander.characters : []) {
      const nameCode = Number(character?.name_code);
      if (Number.isInteger(nameCode) && nameCode > 0) nameCodes.add(nameCode);
    }
  }

  return [...nameCodes].map(nameCode => ({
    id: statisticsCacheKey(nameCode),
    data: aggregateNikkeStatistics(commanders, nameCode, {
      minimumSample: MINIMUM_SAMPLE,
    }),
  }));
}

async function writeStatisticsSnapshots({ db, admin, snapshots, generatedAt = new Date() }) {
  const timestamp = admin.firestore.Timestamp.fromDate(generatedAt);
  const payloads = snapshots.map(snapshot => ({
    ref: db.collection('nikke_statistics').doc(snapshot.id),
    data: {
      ...snapshot.data,
      schemaVersion: STATISTICS_SCHEMA_VERSION,
      freshnessDays: FRESHNESS_DAYS,
      generatedAt: timestamp,
      cachedAt: timestamp,
    },
  }));

  for (let index = 0; index < payloads.length; index += 450) {
    const batch = db.batch();
    for (const payload of payloads.slice(index, index + 450)) {
      batch.set(payload.ref, payload.data);
    }
    await batch.commit();
  }

  return payloads.length;
}

module.exports = {
  STATISTICS_SCHEMA_VERSION,
  FRESHNESS_DAYS,
  MINIMUM_SAMPLE,
  statisticsCacheKey,
  loadEligibleLinkedCommanders,
  buildStatisticsSnapshots,
  writeStatisticsSnapshots,
};
