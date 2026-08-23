'use strict';

const {
  loadEligibleLinkedCommanders,
  buildStatisticsSnapshots,
  writeStatisticsSnapshots,
} = require('./nikkeStatisticsStore');

async function refreshAllNikkeStatistics({ admin, db, source }) {
  const startedAt = new Date();
  const metaRef = db.collection('statistics_meta').doc('daily_nikke');
  const lockDurationMs = 10 * 60 * 1000;

  await db.runTransaction(async transaction => {
    const metaSnapshot = await transaction.get(metaRef);
    const meta = metaSnapshot.data() || {};
    const previousStartedAt = meta.lastStartedAt?.toMillis?.() || 0;
    if (meta.status === 'running' && startedAt.getTime() - previousStartedAt < lockDurationMs) {
      const conflict = new Error('이미 통계를 갱신하고 있습니다. 잠시 후 다시 시도해 주세요.');
      conflict.code = 'STATISTICS_REFRESH_RUNNING';
      throw conflict;
    }
    transaction.set(metaRef, {
      status: 'running',
      source,
      lastStartedAt: admin.firestore.Timestamp.fromDate(startedAt),
    }, { merge: true });
  });

  try {
    const commanders = await loadEligibleLinkedCommanders(db, startedAt.getTime());
    const snapshots = buildStatisticsSnapshots(commanders);
    const documentCount = await writeStatisticsSnapshots({
      db,
      admin,
      snapshots,
      generatedAt: startedAt,
    });

    await metaRef.set({
      status: 'success',
      source,
      commanderCount: commanders.length,
      documentCount,
      lastSuccessfulAt: admin.firestore.FieldValue.serverTimestamp(),
      lastError: admin.firestore.FieldValue.delete(),
    }, { merge: true });

    console.log(`Nikke statistics refresh completed (${source}): ${commanders.length} commanders, ${documentCount} documents.`);
    return { commanderCount: commanders.length, documentCount, generatedAt: startedAt.toISOString() };
  } catch (error) {
    console.error(`Nikke statistics refresh failed (${source}):`, error);
    await metaRef.set({
      status: 'failed',
      source,
      lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastError: error?.message?.toString().slice(0, 500) || 'Unknown error',
    }, { merge: true });
    throw error;
  }
}

function createDailyNikkeStatisticsHandler({ functions, admin, db }) {
  return functions
    .runWith({ timeoutSeconds: 540, memory: '1GB' })
    .pubsub.schedule('0 0 * * *')
    .timeZone('Asia/Seoul')
    .onRun(() => refreshAllNikkeStatistics({ admin, db, source: 'schedule' }));
}

module.exports = { createDailyNikkeStatisticsHandler, refreshAllNikkeStatistics };
