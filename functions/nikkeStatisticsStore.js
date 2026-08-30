'use strict';

const {
  addCharacterToStatistics,
  createNikkeStatisticsAccumulator,
  finalizeNikkeStatistics,
} = require('./nikkeStatistics');

const STATISTICS_SCHEMA_VERSION = 7;
const FRESHNESS_DAYS = 30;
const MINIMUM_SAMPLE = 20;
const READ_PAGE_SIZE = 25;

function statisticsCacheKey(nameCode) {
  return `all_${Number(nameCode)}`;
}

function timestampMillis(value) {
  if (typeof value?.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number(value) || 0;
}

async function forEachEligibleLinkedCommander(db, nowMs, visit, pageSize = READ_PAGE_SIZE) {
  const freshnessLimitMs = nowMs - FRESHNESS_DAYS * 24 * 60 * 60 * 1000;
  let lastBinding = null;
  let commanderCount = 0;

  while (true) {
    let query = db.collection('open_id_bindings')
      .orderBy('__name__')
      .limit(pageSize)
      .select('uid');
    if (lastBinding) query = query.startAfter(lastBinding);

    const bindings = await query.get();
    if (bindings.empty) break;

    const commanderRefs = bindings.docs
      .filter(doc => typeof doc.data()?.uid === 'string' && doc.data().uid.trim())
      .map(doc => db.collection('commanders').doc(doc.id));
    if (commanderRefs.length > 0) {
      const commanderSnapshots = await db.getAll(
        ...commanderRefs,
        { fieldMask: ['lastUpdatedAt', 'characters'] },
      );
      for (const snapshot of commanderSnapshots) {
        if (!snapshot.exists) continue;
        const commander = snapshot.data();
        if (timestampMillis(commander.lastUpdatedAt) < freshnessLimitMs) continue;
        visit(commander);
        commanderCount += 1;
      }
    }

    lastBinding = bindings.docs[bindings.docs.length - 1];
    if (bindings.size < pageSize) break;
  }

  return commanderCount;
}

function buildStatisticsSnapshots(commanders) {
  const accumulators = new Map();
  for (const commander of commanders) {
    addCommanderToAccumulators(accumulators, commander);
  }
  return finalizeStatisticsSnapshots(accumulators);
}

function finalizeStatisticsSnapshots(accumulators) {
  return [...accumulators.entries()].map(([nameCode, accumulator]) => ({
    id: statisticsCacheKey(nameCode),
    data: finalizeNikkeStatistics(accumulator),
  }));
}

function addCommanderToAccumulators(accumulators, commander) {
  const seenNameCodes = new Set();
  for (const character of Array.isArray(commander?.characters) ? commander.characters : []) {
    const nameCode = Number(character?.name_code);
    if (!Number.isInteger(nameCode) || nameCode <= 0 || seenNameCodes.has(nameCode)) continue;
    seenNameCodes.add(nameCode);
    let accumulator = accumulators.get(nameCode);
    if (!accumulator) {
      accumulator = createNikkeStatisticsAccumulator(nameCode, { minimumSample: MINIMUM_SAMPLE });
      accumulators.set(nameCode, accumulator);
    }
    addCharacterToStatistics(accumulator, character);
  }
}

async function buildStatisticsSnapshotsFromStore(db, nowMs = Date.now()) {
  const accumulators = new Map();
  const commanderCount = await forEachEligibleLinkedCommander(
    db,
    nowMs,
    commander => addCommanderToAccumulators(accumulators, commander),
  );
  const snapshots = finalizeStatisticsSnapshots(accumulators);
  return { commanderCount, snapshots };
}

async function aggregateNikkeStatisticsFromStore(db, nameCode, nowMs = Date.now()) {
  const accumulator = createNikkeStatisticsAccumulator(nameCode, { minimumSample: MINIMUM_SAMPLE });
  await forEachEligibleLinkedCommander(db, nowMs, commander => {
    const character = (Array.isArray(commander.characters) ? commander.characters : [])
      .find(item => Number(item?.name_code) === Number(nameCode));
    if (character) addCharacterToStatistics(accumulator, character);
  });
  return finalizeNikkeStatistics(accumulator);
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
  aggregateNikkeStatisticsFromStore,
  buildStatisticsSnapshotsFromStore,
  forEachEligibleLinkedCommander,
  buildStatisticsSnapshots,
  writeStatisticsSnapshots,
};
