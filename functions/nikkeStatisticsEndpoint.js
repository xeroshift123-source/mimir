'use strict';

const {
  attachUserComparison,
} = require('./nikkeStatistics');
const {
  FRESHNESS_DAYS,
  statisticsCacheKey,
} = require('./nikkeStatisticsStore');

function createNikkeStatisticsHandler({ functions, admin, db, getAuthenticatedUid }) {
  return functions
    .runWith({ memory: '1GB', timeoutSeconds: 120 })
    .https.onRequest(async (req, res) => {
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
      const character = (Array.isArray(commander.characters) ? commander.characters : [])
        .find(item => Number(item?.name_code) === nameCode);
      if (!character) {
        return res.status(404).json({ success: false, error: '선택한 니케의 저장 정보를 찾을 수 없습니다.' });
      }

      const cacheKey = statisticsCacheKey(nameCode);
      const cacheRef = db.collection('nikke_statistics').doc(cacheKey);
      const cacheSnapshot = await cacheRef.get();
      const cacheData = cacheSnapshot.data();
      const cacheIsReadable = cacheSnapshot.exists
        && Number(cacheData?.schemaVersion) >= 7;

      if (!cacheIsReadable) {
        return res.status(503).json({
          success: false,
          error: '선택한 니케의 통계를 준비 중입니다. 다음 통계 갱신 후 다시 시도해 주세요.',
        });
      }

      const statistics = cacheData;
      let generatedAtMs = cacheData?.generatedAt?.toMillis?.()
        || cacheData?.cachedAt?.toMillis?.()
        || 0;

      const comparison = attachUserComparison(statistics, character);
      const overload = comparison.overload.map(({ histogram, ...option }) => option);
      let combinedOffense = null;
      if (comparison.combinedOffense) {
        const { histogram: _combinedHistogram, ...publicCombinedOffense }
          = comparison.combinedOffense;
        combinedOffense = publicCombinedOffense;
      }
      return res.status(200).json({
        success: true,
        data: {
          ...comparison,
          overload,
          combinedOffense,
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
