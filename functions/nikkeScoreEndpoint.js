'use strict';
const { ScoreError, resolveTarget, POLICY_HASH, compareScore } = require('./nikkeScoreAdapter');
const { ELEMENTS, compareElements } = require('./nikkeScoreElements');

// The legacy calculation URL is also read-only, so old clients cannot compute
// on navigation. Only the sync handler can create or replace stored scores.
function createReadHandler({ functions, db, getAuthenticatedUid }, all) {
  return functions.runWith({ timeoutSeconds: 60, memory: '512MB' }).https.onRequest(async (req, res) => {
    res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
    res.set('Vary', 'Origin');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Cache-Control', 'no-store');
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    try {
      let uid;
      try { uid = await getAuthenticatedUid(req); } catch (_) { /* denied below */ }
      if (!uid) throw new ScoreError('unauthenticated', '로그인이 필요합니다.', 401);
      const { openId, nameCode, weakness } = req.body || {};
      if (typeof openId !== 'string' || !openId.trim() || openId.length > 256 || openId.includes('/')
        || (!all && (!Number.isSafeInteger(nameCode)
          || (weakness !== undefined && !['fire', 'iron', 'electric', 'wind', 'water'].includes(weakness))))) {
        throw new ScoreError('bad_request', '지휘관과 니케·속성을 확인해 주세요.', 400);
      }
      const [binding, user] = await Promise.all([
        db.collection('open_id_bindings').doc(openId).get(), db.collection('users').doc(uid).get(),
      ]);
      const boundUid = binding.data()?.uid;
      const userData = user.data() || {};
      const linked = boundUid ? boundUid === uid : userData.openId === openId
        || (Array.isArray(userData.linkedOpenIds) && userData.linkedOpenIds.includes(openId));
      if (!linked) throw new ScoreError('forbidden', '연동된 지휘관만 조회할 수 있습니다.', 403);
      const snapshot = (await db.collection('nikke_score_results').doc(openId).get()).data();
      const saved = snapshot?.results || {};
      const keys = all ? Object.keys(saved) : [resolveTarget(nameCode, weakness).key];
      const distributions = keys.length
        ? await db.getAll(...keys.map(key => db.collection('nikke_score_distributions').doc(key))) : [];
      const results = {};
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i], item = saved[key];
        if (!item) continue;
        results[key] = item.status !== 'complete' ? item : { ...item,
          canRefreshStatistics: userData.isAdmin === true,
          ...compareScore(item.policyHash === POLICY_HASH ? distributions[i].data() : null,
            item.damage, item.calcVersion),
          calculatedAt: new Date(item.calculatedAtMs).toISOString() };
      }
      if (all) {
        const [commander, ...elementDocs] = await db.getAll(
          db.collection('commanders').doc(openId),
          ...Object.keys(ELEMENTS).map(key => db.collection('nikke_score_distributions').doc(`element-${key}`)));
        return res.status(200).json({ success: true, data: {
          syncId: snapshot?.syncId || null, status: snapshot?.status || 'not_saved', results,
          canRefreshStatistics: userData.isAdmin === true,
          elements: compareElements(snapshot, commander.data(), Object.fromEntries(
            Object.keys(ELEMENTS).map((key, i) => [key, elementDocs[i].data()]))),
        } });
      }
      const item = results[keys[0]];
      if (!item) throw new ScoreError('score_not_saved',
        ['pending', 'running'].includes(snapshot?.status)
          ? '동기화 후 스코어를 저장 중입니다. 잠시 후 프로필을 다시 열어 주세요.'
          : '저장된 스코어가 없습니다. 프로필을 동기화하면 계산 후 저장됩니다.', 404);
      if (item.status !== 'complete') throw new ScoreError(item.code, item.error);
      return res.status(200).json({ success: true, data: item });
    } catch (error) {
      const known = error instanceof ScoreError;
      if (!known) console.error('Stored score read failed:', error?.code || 'internal');
      return res.status(known ? error.status : 500).json({ success: false,
        code: known ? error.code : 'internal',
        error: known ? error.message : '저장된 스코어를 불러오지 못했습니다.' });
    }
  });
}
const createNikkeScoreHandler = dependencies => createReadHandler(dependencies, false);
const createNikkeScoresHandler = dependencies => createReadHandler(dependencies, true);
module.exports = { createNikkeScoreHandler, createNikkeScoresHandler };
