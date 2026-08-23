'use strict';

const { refreshAllNikkeStatistics } = require('./nikkeStatisticsSchedule');

function createNikkeStatisticsRefreshHandler({ functions, admin, db, getAuthenticatedUid }) {
  return functions
    .runWith({ timeoutSeconds: 540, memory: '1GB' })
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

      const userSnapshot = await db.collection('users').doc(uid).get();
      if (userSnapshot.data()?.isAdmin !== true) {
        return res.status(403).json({ success: false, error: '관리자만 전체 통계를 갱신할 수 있습니다.' });
      }

      try {
        const result = await refreshAllNikkeStatistics({
          admin,
          db,
          source: `manual:${uid}`,
        });
        return res.status(200).json({ success: true, data: result });
      } catch (error) {
        if (error.code === 'STATISTICS_REFRESH_RUNNING') {
          return res.status(409).json({ success: false, error: error.message });
        }
        console.error('Manual Nikke statistics refresh failed:', error);
        return res.status(500).json({ success: false, error: '통계 갱신 중 서버 오류가 발생했습니다.' });
      }
    });
}

module.exports = { createNikkeStatisticsRefreshHandler };
