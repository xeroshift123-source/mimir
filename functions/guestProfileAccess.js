'use strict';

const crypto = require('crypto');

const GUEST_ACCESS_DAYS = 30;

function hashGuestAccessToken(token) {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

async function issueGuestProfileToken({ admin, db, openId, now = new Date() }) {
  const token = crypto.randomBytes(32).toString('base64url');
  const tokenHash = hashGuestAccessToken(token);
  const expiresAt = new Date(now.getTime() + GUEST_ACCESS_DAYS * 24 * 60 * 60 * 1000);

  await db.collection('guest_profile_tokens').doc(tokenHash).set({
    openId,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  return token;
}

function createGuestCommanderProfileHandler({ functions, db }) {
  return functions.https.onRequest(async (req, res) => {
    const origin = req.headers.origin || '*';
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Allow-Credentials', 'true');

    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    }

    const openId = req.body?.openId?.toString().trim() || '';
    const accessToken = req.body?.accessToken?.toString().trim() || '';
    if (!openId || openId.length > 256 || openId.includes('/') || accessToken.length < 32 || accessToken.length > 256) {
      return res.status(400).json({ success: false, error: '게스트 프로필 접근 정보가 올바르지 않습니다.' });
    }

    try {
      const tokenRef = db.collection('guest_profile_tokens').doc(hashGuestAccessToken(accessToken));
      const tokenSnapshot = await tokenRef.get();
      const tokenData = tokenSnapshot.data() || {};
      const expiresAtMs = tokenData.expiresAt?.toMillis?.() || 0;
      if (!tokenSnapshot.exists || tokenData.openId !== openId || expiresAtMs <= Date.now()) {
        if (tokenSnapshot.exists && expiresAtMs <= Date.now()) {
          await tokenRef.delete().catch(() => {});
        }
        return res.status(403).json({
          success: false,
          error: '게스트 접근 권한이 만료되었습니다. BLABLALINK를 다시 동기화해 주세요.',
        });
      }

      const commanderSnapshot = await db.collection('commanders').doc(openId).get();
      if (!commanderSnapshot.exists) {
        return res.status(404).json({ success: false, error: '저장된 지휘관 정보를 찾을 수 없습니다.' });
      }
      return res.status(200).json({ success: true, data: commanderSnapshot.data() });
    } catch (error) {
      console.error('Guest commander profile lookup failed:', error);
      return res.status(500).json({ success: false, error: '지휘관 정보를 불러오는 중 서버 오류가 발생했습니다.' });
    }
  });
}

module.exports = {
  GUEST_ACCESS_DAYS,
  hashGuestAccessToken,
  issueGuestProfileToken,
  createGuestCommanderProfileHandler,
};
