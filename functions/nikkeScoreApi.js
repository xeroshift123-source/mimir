'use strict';

const axios = require('axios');
const { randomUUID } = require('node:crypto');
const { ScoreError, requestBody } = require('./nikkeScoreAdapter');
const ENDPOINT = 'https://dildoro.com/api/partner/v1/damage';

// Firestore leases serialize calls across the HTTP and scheduled functions.
async function withLease(db, name, ttlMs, work) {
  const ref = db.collection('nikke_score_state').doc(name);
  const owner = randomUUID();
  await db.runTransaction(async tx => {
    const data = (await tx.get(ref)).data();
    if (data?.expiresAtMs > Date.now()) throw new ScoreError('busy', '스코어 계산 중입니다. 잠시 후 다시 측정해 주세요.', 503, 5);
    tx.set(ref, { owner, expiresAtMs: Date.now() + ttlMs });
  });
  try { return await work(); }
  finally {
    await db.runTransaction(async tx => {
      if ((await tx.get(ref)).data()?.owner === owner) tx.delete(ref);
    });
  }
}

function createScoreApi(db, apiKey = () => process.env.DILDORO_API_KEY, transport = axios) {
  return async function calculate(nameCode, items) {
    if (!apiKey()) throw new ScoreError('not_configured', '스코어 계산 서비스를 준비 중입니다.', 503);
    if (!items.length || items.length > 100) throw new ScoreError('bad_request', '계산 요청은 1~100건이어야 합니다.', 400);
    return withLease(db, 'api_lock', 150000, async () => {
      const scenarios = [];
      for (const coreSize of [0, 100]) {
        const body = JSON.stringify(requestBody(nameCode, items, coreSize));
        let response;
        try {
          response = await transport.post(ENDPOINT, body, {
            timeout: 60000, maxRedirects: 0,
            headers: { 'X-Api-Key': apiKey(), 'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(body), 'User-Agent': 'Mozilla/5.0 (compatible; Mimir/1.0)',
              Accept: 'application/json' },
            validateStatus: () => true,
          });
        } catch (_) {
          // Axios errors contain the API key and growth payload; never log them.
          throw new ScoreError('upstream_timeout', '계산 서버 응답이 지연되고 있습니다. 다시 측정해 주세요.', 504);
        }
        if (response.status !== 200) {
          const retry = Number(response.headers?.['retry-after']);
          const busy = [429, 503].includes(response.status);
          throw new ScoreError(busy ? 'busy' : 'upstream_error',
            busy ? '계산 서버가 혼잡합니다. 잠시 후 다시 측정해 주세요.' : '계산 서비스 연결에 실패했습니다.',
            busy ? response.status : 502, busy ? (Number.isFinite(retry) && retry > 0 ? Math.ceil(retry) : 5) : null);
        }
        const result = response.data;
        if (typeof result?.calc_version !== 'string' || !result.calc_version.length
          || !Array.isArray(result.items) || result.items.length !== items.length) {
          throw new ScoreError('invalid_response', '계산 응답 형식이 올바르지 않습니다.', 502);
        }
        const seen = new Set();
        const expected = new Set(items.map(item => item.id));
        for (const item of result.items) {
          if (!expected.has(item?.id) || seen.has(item.id)
            || (!item.error && (!Number.isSafeInteger(item.damage) || item.damage < 0))) {
            throw new ScoreError('invalid_response', '계산 결과가 요청과 일치하지 않습니다.', 502);
          }
          seen.add(item.id);
        }
        scenarios.push(result);
      }
      if (scenarios[0].calc_version !== scenarios[1].calc_version) {
        throw new ScoreError('invalid_response', '계산 중 버전이 변경됐습니다. 다음 동기화에서 다시 계산합니다.', 502);
      }
      const coreItems = new Map(scenarios[1].items.map(item => [item.id, item]));
      const result = { calc_version: scenarios[0].calc_version,
        items: scenarios[0].items.map(item => {
          const coreItem = coreItems.get(item.id);
          if (item.error) return item;
          if (coreItem.error) return coreItem;
          return { id: item.id, damage: Math.round(item.damage / 2 + coreItem.damage / 2) };
        }) };
      await db.collection('nikke_score_state').doc('version').set({ calcVersion: result.calc_version, observedAtMs: Date.now() });
      return result;
    });
  };
}

const ITEM_ERRORS = {
  unknown_nikke: '조합에 계산 서버에 아직 등록되지 않은 니케가 있습니다.',
  unsupported_nikke: '조합에 딜 계산을 아직 지원하지 않는 니케가 있습니다.',
  bad_data: '육성 데이터를 확인할 수 없습니다. 다시 동기화해 주세요.',
  missing_data: '조합의 육성 정보가 부족합니다. 다시 동기화해 주세요.',
};
function checkItem(item) {
  if (item.error) throw new ScoreError(item.error.code, ITEM_ERRORS[item.error.code] || '이 조합의 딜량을 계산하지 못했습니다.');
  return item.damage;
}
module.exports = { createScoreApi, withLease, checkItem };
