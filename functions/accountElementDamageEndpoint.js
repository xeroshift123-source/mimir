'use strict';

const { attachAccountElementDamageComparison } = require('./nikkeStatistics');
const {
  ACCOUNT_ELEMENT_DAMAGE_CACHE_ID,
  FRESHNESS_DAYS,
} = require('./nikkeStatisticsStore');

function createAccountElementDamageHandler({ functions, db, getAuthenticatedUid }) {
  return functions
    .runWith({ memory: '256MB', timeoutSeconds: 30 })
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
      if (!openId || openId.length > 256 || openId.includes('/')) {
        return res.status(400).json({ success: false, error: '통계를 조회할 지휘관이 필요합니다.' });
      }

      try {
        const [bindingSnapshot, commanderSnapshot, userSnapshot, cacheSnapshot] = await Promise.all([
          db.collection('open_id_bindings').doc(openId).get(),
          db.collection('commanders').doc(openId).get(),
          db.collection('users').doc(uid).get(),
          db.collection('nikke_statistics').doc(ACCOUNT_ELEMENT_DAMAGE_CACHE_ID).get(),
        ]);
        const userData = userSnapshot.data() || {};
        const linkedOpenIds = Array.isArray(userData.linkedOpenIds)
          ? userData.linkedOpenIds.filter(value => typeof value === 'string' && value.trim())
          : [];
        const legacyOpenId = typeof userData.openId === 'string' ? userData.openId.trim() : '';
        const boundUid = bindingSnapshot.data()?.uid;
        const isLinked = boundUid === uid
          || (!boundUid && (linkedOpenIds.includes(openId) || legacyOpenId === openId));
        if (!isLinked) {
          return res.status(403).json({ success: false, error: '연동된 지휘관의 통계만 조회할 수 있습니다.' });
        }
        if (!commanderSnapshot.exists) {
          return res.status(404).json({ success: false, error: '저장된 지휘관 정보를 찾을 수 없습니다.' });
        }
        if (!cacheSnapshot.exists) {
          return res.status(503).json({
            success: false,
            error: '속성별 우월코드 통계를 준비 중입니다. 다음 통계 갱신 후 다시 시도해 주세요.',
          });
        }

        const cacheData = cacheSnapshot.data();
        const comparison = attachAccountElementDamageComparison(
          cacheData,
          commanderSnapshot.data(),
        );
        const elements = comparison.elements.map(({ histogram, ...element }) => element);
        const generatedAtMs = cacheData?.generatedAt?.toMillis?.()
          || cacheData?.cachedAt?.toMillis?.()
          || Date.now();
        return res.status(200).json({
          success: true,
          data: {
            sampleCount: comparison.sampleCount,
            freshnessDays: FRESHNESS_DAYS,
            generatedAt: new Date(generatedAtMs).toISOString(),
            elements,
          },
        });
      } catch (error) {
        console.error('Account element damage statistics failed:', error);
        return res.status(500).json({ success: false, error: '속성별 우월코드 통계를 불러오는 중 서버 오류가 발생했습니다.' });
      }
    });
}

module.exports = { createAccountElementDamageHandler };
