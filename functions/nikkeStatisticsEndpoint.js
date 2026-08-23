'use strict';

const {
  aggregateNikkeStatistics,
  attachUserComparison,
} = require('./nikkeStatistics');
const {
  STATISTICS_SCHEMA_VERSION,
  FRESHNESS_DAYS,
  MINIMUM_SAMPLE,
  statisticsCacheKey,
  loadEligibleLinkedCommanders,
  writeStatisticsSnapshots,
} = require('./nikkeStatisticsStore');

function createNikkeStatisticsHandler({ functions, admin, db, getAuthenticatedUid }) {
  return functions.https.onRequest(async (req, res) => {
    const origin = req.headers.origin || '*';
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Credentials', 'true');

    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    }

    let uid;
    try {
      uid = await getAuthenticatedUid(req);
    } catch (_) {
      return res.status(401).json({ success: false, error: '로그인 인증이 만료되었습니다. 다시 로그인해 주세요.' });
    }
    if (!uid) return res.status(401).json({ success: false, error: '로그인이 필요합니다.' });

    const openId = req.body?.openId?.toString().trim() || '';
    const nameCode = Number(req.body?.nameCode);
    if (!openId || openId.length > 256 || openId.includes('/') || !Number.isInteger(nameCode) || nameCode <= 0) {
      return res.status(400).json({ success: false, error: '통계를 조회할 지휘관과 니케가 필요합니다.' });
    }

    try {
      const [bindingSnapshot, commanderSnapshot, userSnapshot] = await Promise.all([
        db.collection('open_id_bindings').doc(openId).get(),
        db.collection('commanders').doc(openId).get(),
        db.collection('users').doc(uid).get(),
      ]);
      const bindingData = bindingSnapshot.data() || {};
      const userData = userSnapshot.data() || {};
      const linkedOpenIds = Array.isArray(userData.linkedOpenIds)
        ? userData.linkedOpenIds.filter(value => typeof value === 'string' && value.trim())
        : [];
      const legacyOpenId = typeof userData.openId === 'string' ? userData.openId.trim() : '';
      const isLinkedInUserProfile = linkedOpenIds.includes(openId) || legacyOpenId === openId;
      const boundUid = typeof bindingData.uid === 'string' ? bindingData.uid : '';

      if ((boundUid && boundUid !== uid) || (!boundUid && !isLinkedInUserProfile)) {
        return res.status(403).json({ success: false, error: '연동된 지휘관의 통계만 조회할 수 있습니다.' });
      }
      if (!commanderSnapshot.exists) {
        return res.status(404).json({ success: false, error: '저장된 지휘관 정보를 찾을 수 없습니다.' });
      }

      // 기존 단일 계정 사용자는 users 문서만 연동 정보가 남아 있을 수 있어
      // 최초 통계 조회 시 서버에서 안전하게 1:1 바인딩으로 마이그레이션한다.
      if (!boundUid && isLinkedInUserProfile) {
        try {
          await db.runTransaction(async transaction => {
            const latestBinding = await transaction.get(bindingSnapshot.ref);
            const latestBoundUid = latestBinding.data()?.uid;
            if (latestBoundUid && latestBoundUid !== uid) {
              const conflict = new Error('이미 다른 Google 계정에 연동된 지휘관입니다.');
              conflict.code = 'STATISTICS_BINDING_CONFLICT';
              throw conflict;
            }

            const migration = {
              openId,
              uid,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              ...(!latestBinding.exists
                ? { boundAt: admin.firestore.FieldValue.serverTimestamp() }
                : {}),
            };
            if (legacyOpenId === openId && typeof userData.syncUrl === 'string' && userData.syncUrl.trim()) {
              migration.syncUrl = userData.syncUrl.trim();
            }
            transaction.set(bindingSnapshot.ref, migration, { merge: true });
          });
        } catch (migrationError) {
          if (migrationError.code === 'STATISTICS_BINDING_CONFLICT') {
            return res.status(403).json({ success: false, error: migrationError.message });
          }
          throw migrationError;
        }
      }

      const commander = commanderSnapshot.data();
      const server = commander.server?.toString() || '알 수 없음';
      const character = (Array.isArray(commander.characters) ? commander.characters : [])
        .find(item => Number(item?.name_code) === nameCode);
      if (!character) {
        return res.status(404).json({ success: false, error: '선택한 니케의 저장 정보를 찾을 수 없습니다.' });
      }

      const cacheKey = statisticsCacheKey(server, nameCode);
      const cacheRef = db.collection('nikke_statistics').doc(cacheKey);
      const cacheSnapshot = await cacheRef.get();
      const cacheData = cacheSnapshot.data();
      const cacheIsUsable = cacheSnapshot.exists
        && cacheData?.schemaVersion === STATISTICS_SCHEMA_VERSION;

      let statistics;
      let generatedAtMs = cacheData?.generatedAt?.toMillis?.()
        || cacheData?.cachedAt?.toMillis?.()
        || 0;
      if (cacheIsUsable) {
        statistics = cacheData;
      } else {
        // 첫 배포 직후나 신규 니케처럼 예약 집계 문서가 아직 없는 경우에만
        // 한 번 즉시 생성한다. 이후 요청은 매일 자정에 만든 문서를 그대로 읽는다.
        const eligibleCommanders = await loadEligibleLinkedCommanders(db);

        statistics = aggregateNikkeStatistics(eligibleCommanders, nameCode, {
          server,
          minimumSample: MINIMUM_SAMPLE,
        });
        generatedAtMs = Date.now();
        await writeStatisticsSnapshots({
          db,
          admin,
          snapshots: [{ id: cacheKey, data: statistics }],
          generatedAt: new Date(generatedAtMs),
        });
      }

      const comparison = attachUserComparison(statistics, character);
      const overload = comparison.overload.map(({ histogram, ...option }) => option);
      return res.status(200).json({
        success: true,
        data: {
          ...comparison,
          overload,
          freshnessDays: FRESHNESS_DAYS,
          generatedAt: new Date(generatedAtMs || Date.now()).toISOString(),
          canRefreshStatistics: userData.isAdmin === true,
        },
      });
    } catch (error) {
      console.error('Nikke statistics failed:', error);
      return res.status(500).json({ success: false, error: '니케 통계를 계산하는 중 서버 오류가 발생했습니다.' });
    }
  });
}

module.exports = { createNikkeStatisticsHandler };
