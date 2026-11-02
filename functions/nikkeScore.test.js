'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { TARGETS, resolveTarget, POLICY_HASH, buildScoreItem, inputHash, requestBody, compareScore } = require('./nikkeScoreAdapter');
const { createScoreApi } = require('./nikkeScoreApi');
const { refreshScorePage } = require('./nikkeScoreSchedule');
const { createNikkeScoreHandler, createNikkeScoresHandler } = require('./nikkeScoreEndpoint');
const { pendingScoreSnapshot, calculateSyncedScores } = require('./nikkeScorePersistence');
const { migrateCachedScores } = require('./nikkeScoreMigration');
const standards = require('./nikkeScoreStandards.json');

const storedResult = (key = '5129:fire', damage = 2030000000, version = 'c80') => ({
  status: 'complete', profileKey: key, damage, score: damage * 5 / 1e8,
  calcVersion: version, policyHash: POLICY_HASH, calculatedAtMs: Date.now(),
});
const storedSnapshot = (syncId = 'sync-1') => ({ syncId, status: 'complete',
  results: { '5129:fire': storedResult(), '5129:iron': storedResult('5129:iron', 1000000000) } });

test('migration only copies matching existing cache values and never overwrites a sync snapshot', async () => {
  const p = profile();
  const hash = inputHash(buildScoreItem(p, '5129:fire', 'unused'), '5129:fire');
  const db = memoryDb({ 'commanders/account': p,
    [`nikke_score_cache/${hash}`]: { damage: 2030000000, calcVersion: 'c80', updatedAtMs: Date.now() } });
  assert.deepEqual(await migrateCachedScores({ db, openId: 'account' }), { matched: 1 });
  assert.equal(db.data.has('nikke_score_results/account'), false);
  assert.deepEqual(await migrateCachedScores({ db, openId: 'account', apply: true }), { matched: 1, applied: true });
  const saved = db.data.get('nikke_score_results/account');
  assert.equal(saved.results['5129:fire'].score, 101.5);
  assert.equal(saved.results['5129:iron'], undefined);
  assert.equal(saved.syncId, db.data.get('commanders/account').scoreSyncId);
  assert.deepEqual(await migrateCachedScores({ db, openId: 'account', apply: true }), { skipped: true });
  assert.deepEqual(db.data.get('nikke_score_results/account'), saved);
});
const httpFunctions = { runWith: () => ({ https: { onRequest: handler => handler } }) };
async function invoke(handler, body = { openId: 'account' }) {
  const output = {};
  const res = { set: () => {}, status: s => { output.status = s; return res; },
    json: b => { output.body = b; }, send: () => {} };
  await handler({ method: 'POST', headers: {}, body }, res);
  return output;
}

test('one successful sync computes and persists each owned element once; duplicate work is skipped', async () => {
  const db = memoryDb({ 'nikke_score_results/account': pendingScoreSnapshot('sync-1') });
  const p = profile(); p.characters[0].core = 7;
  const calls = [];
  const calculate = async (key, items) => {
    calls.push(key);
    assert.equal(items[0].data.characters.find(c => c.name_code === 5129).core, 7);
    return { calc_version: 'c80', items: [{ id: items[0].id, damage: 2030000000 }] };
  };
  const args = { db, openId: 'account', syncId: 'sync-1', commander: p, calculate };
  assert.deepEqual(await calculateSyncedScores(args), { status: 'complete', count: 2 });
  assert.deepEqual(calls, ['5129:fire', '5129:iron']);
  const saved = db.data.get('nikke_score_results/account');
  assert.equal(saved.results['5129:fire'].score, 101.5);
  assert.equal(saved.syncId, 'sync-1');
  assert.deepEqual(await calculateSyncedScores(args), { skipped: true });
  assert.equal(calls.length, 2);
  db.data.set('nikke_score_results/account', pendingScoreSnapshot('sync-2'));
  await calculateSyncedScores({ ...args, syncId: 'sync-2' });
  assert.equal(calls.length, 4);
});

test('sync batches all owned targets into five weakness requests and matches shuffled results by id', async () => {
  const db = memoryDb({ 'nikke_score_results/account': pendingScoreSnapshot('batched') });
  const p = profile();
  p.characters = [...new Map([...TARGETS].map(([key, t]) => {
    const c = structuredClone(profile(key).characters[0]);
    c.equipment = [];
    return [t.nameCode, c];
  })).values()];
  p.characters.find(c => c.name_code === 5186).growthDataQuality.complete = false;
  const calls = [];
  const output = await calculateSyncedScores({ db, openId: 'account', syncId: 'batched', commander: p,
    calculate: async (key, items) => {
      calls.push({ key, count: items.length });
      assert.ok(items.length > 1 && items.length <= 100);
      assert.ok(items.every(item => TARGETS.has(`${item.target}:${resolveTarget(key).weakness}`)));
      return { calc_version: 'c80', items: [...items].reverse().map(item => item.target === 5185
        ? { id: item.id, error: { code: 'unsupported_nikke' } }
        : { id: item.id, damage: item.target * 1000 }) };
    } });
  assert.equal(calls.length, 5);
  assert.equal(calls.reduce((sum, call) => sum + call.count, 0), 55);
  assert.deepEqual(output, { status: 'partial', count: 56 });
  const saved = db.data.get('nikke_score_results/account').results;
  assert.equal(saved['5186:fire'].code, 'resync_required');
  assert.equal(saved['5185:fire'].code, 'unsupported_nikke');
  for (const [key, target] of TARGETS) {
    if ([5185, 5186].includes(target.nameCode)) continue;
    assert.equal(saved[key].damage, target.nameCode * 1000);
  }
});

test('profile and legacy score reads never calculate, write, or expire saved scores', async () => {
  const snapshot = storedSnapshot();
  snapshot.results['5129:fire'].calculatedAtMs = Date.now() - 90 * 86400000;
  const db = memoryDb({ 'open_id_bindings/account': { uid: 'owner' },
    'nikke_score_results/account': snapshot,
    'nikke_score_state/version': { calcVersion: 'c999' },
    'nikke_score_distributions/5129:fire': { damages: Array(20).fill(2030000000),
      policyHash: POLICY_HASH, calcVersion: 'c999', generatedAtMs: Date.now() } });
  const before = structuredClone([...db.data]);
  const args = { functions: httpFunctions, db, getAuthenticatedUid: async () => 'owner',
    calculate: () => { assert.fail('A read must never calculate'); } };
  for (let i = 0; i < 3; i++) {
    const bulk = await invoke(createNikkeScoresHandler(args));
    assert.equal(bulk.status, 200);
    assert.equal(bulk.body.data.results['5129:fire'].score, 101.5);
    assert.equal(bulk.body.data.results['5129:fire'].topPercent, null);
    const single = await invoke(createNikkeScoreHandler(args), { openId: 'account', nameCode: 5129, weakness: 'iron' });
    assert.equal(single.body.data.score, 50);
  }
  assert.deepEqual([...db.data], before);
});

test('a missing persisted score never falls back to cache or on-demand computation', async () => {
  const db = memoryDb({ 'open_id_bindings/account': { uid: 'owner' }, 'commanders/account': profile(),
    'nikke_score_cache/irrelevant': { damage: 100, calcVersion: 'c80' } });
  const before = structuredClone([...db.data]);
  const args = { functions: httpFunctions, db, getAuthenticatedUid: async () => 'owner' };
  assert.equal((await invoke(createNikkeScoresHandler(args))).body.data.status, 'not_saved');
  assert.equal((await invoke(createNikkeScoreHandler(args), { openId: 'account', nameCode: 5129 })).status, 404);
  assert.deepEqual([...db.data], before);
});

test('superseded sync cannot overwrite a newer snapshot or continue old requests', async () => {
  const db = memoryDb({ 'nikke_score_results/account': pendingScoreSnapshot('old') });
  let calls = 0;
  const result = await calculateSyncedScores({ db, openId: 'account', syncId: 'old', commander: profile(),
    calculate: async (key, items) => {
      calls++;
      db.data.set('nikke_score_results/account', pendingScoreSnapshot('new'));
      return { calc_version: 'c80', items: [{ id: items[0].id, damage: 1 }] };
    } });
  assert.deepEqual(result, { superseded: true });
  assert.equal(calls, 1);
  assert.equal(db.data.get('nikke_score_results/account').syncId, 'new');
  assert.deepEqual(db.data.get('nikke_score_results/account').results, {});
});

test('failed calculation is stored as an error; later reads do not retry it', async () => {
  const db = memoryDb({ 'nikke_score_results/account': pendingScoreSnapshot('sync-1'),
    'open_id_bindings/account': { uid: 'owner' } });
  let calls = 0;
  await calculateSyncedScores({ db, openId: 'account', syncId: 'sync-1', commander: profile(),
    calculate: async (key, items) => {
      calls++;
      if (key === '5129:fire') throw new Error('sensitive upstream failure');
      return { calc_version: 'c80', items: [{ id: items[0].id, damage: 100 }] };
    } });
  const saved = db.data.get('nikke_score_results/account');
  assert.equal(saved.status, 'partial');
  assert.equal(saved.results['5129:fire'].status, 'error');
  assert.equal(saved.results['5129:fire'].score, undefined);
  assert.ok(!JSON.stringify(saved).includes('sensitive'));
  const handler = createNikkeScoresHandler({ functions: httpFunctions, db, getAuthenticatedUid: async () => 'owner' });
  await invoke(handler); await invoke(handler);
  assert.equal(calls, 2);
});

test('ranking aggregates stored results only and excludes stale, unlinked, mixed-revision samples', async () => {
  const now = Date.now(), seed = { 'nikke_score_state/version': { calcVersion: 'c80' } };
  for (let i = 0; i < 104; i++) {
    const id = String(i).padStart(3, '0');
    seed[`open_id_bindings/${id}`] = { uid: i === 103 ? '' : 'owner' };
    seed[`commanders/${id}`] = { scoreSyncId: i === 102 ? 'new' : 'sync-1', lastUpdatedAt: i === 101 ? now - 31 * 86400000 : now };
    if (i !== 100) seed[`nikke_score_results/${id}`] = storedSnapshot();
  }
  const db = memoryDb(seed);
  const calculate = () => { assert.fail('Statistics must not calculate'); };
  const beforeScores = structuredClone([...db.data].filter(([k]) => k.startsWith('nikke_score_results/')));
  assert.equal((await refreshScorePage({ db, now, calculate })).continuing, true);
  assert.equal((await refreshScorePage({ db, now, calculate })).complete, true);
  assert.equal(db.data.get('nikke_score_distributions/5129:fire').damages.length, 100);
  assert.equal(db.data.get('nikke_score_distributions/5129:iron').damages.length, 100);
  assert.deepEqual([...db.data].filter(([k]) => k.startsWith('nikke_score_results/')), beforeScores);
  assert.deepEqual(await refreshScorePage({ db, now, calculate }), { waiting: true });
});

test('ranking restarts when a new synced calculator version is observed, without recalculating old scores', async () => {
  const now = Date.now();
  const db = memoryDb({ 'nikke_score_state/version': { calcVersion: 'c80' },
    'open_id_bindings/account': { uid: 'owner' }, 'commanders/account': { scoreSyncId: 'sync-1', lastUpdatedAt: now },
    'nikke_score_results/account': storedSnapshot() });
  await refreshScorePage({ db, now });
  db.data.set('nikke_score_state/version', { calcVersion: 'c81' });
  await refreshScorePage({ db, now });
  assert.equal(db.data.get('nikke_score_distributions/5129:fire').calcVersion, 'c81');
  assert.deepEqual(db.data.get('nikke_score_distributions/5129:fire').damages, []);
  assert.equal(db.data.get('nikke_score_results/account').results['5129:fire'].calcVersion, 'c80');
});

function profile(code = 5129) {
  const target = resolveTarget(code);
  const fixed = structuredClone(standards[target.key]);
  return { characters: fixed.characters.filter(c => c.name_code === target.nameCode), stateEffects: fixed.stateEffects,
    recycleRoom: [1001, 1101, 1102, 1103, 1201, 1202, 1203, 1204, 1205].map(tid => ({ tid, lv: tid === 1001 ? 250 : 120 })),
    nickname: 'PRIVATE', openid: 'PRIVATE', lastUpdatedAt: Date.now() };
}

// Small Firestore fake covering transactions, cursor pages, field queries and batches.
function memoryDb(seed = {}) {
  const data = new Map(Object.entries(seed));
  const ref = path => ({ path, id: path.split('/').at(-1),
    get: async () => snap(path),
    set: async (value, opts) => data.set(path, opts?.merge ? { ...data.get(path), ...structuredClone(value) } : structuredClone(value)),
    delete: async () => data.delete(path) });
  const snap = path => ({ id: path.split('/').at(-1), ref: ref(path), exists: data.has(path), data: () => structuredClone(data.get(path)) });
  const collection = (path, opts = {}) => ({
    doc: id => ref(`${path}/${id}`),
    orderBy: () => collection(path, opts), select: () => collection(path, opts),
    limit: limit => collection(path, { ...opts, limit }), startAfter: cursor => collection(path, { ...opts, cursor }),
    where: (field, op, value) => collection(path, { ...opts, field, value }),
    get: async () => {
      const docs = [...data.keys()].filter(k => k.startsWith(path + '/') && k.split('/').length === 2)
        .sort().map(snap).filter(s => (!opts.cursor || s.id > opts.cursor)
          && (!opts.field || s.data()[opts.field] === opts.value)).slice(0, opts.limit || Infinity);
      return { docs, size: docs.length, empty: docs.length === 0 };
    },
  });
  const db = { data, collection, getAll: async (...refs) => refs.filter(r => r.path).map(r => snap(r.path)),
    runTransaction: async work => work({ get: r => r.get(), set: (r, v, o) => r.set(v, o), delete: r => r.delete() }),
    batch: () => {
      const ops = [];
      return { set: (r, v, o) => ops.push(() => r.set(v, o)), commit: async () => { for (const op of ops) await op(); } };
    } };
  return db;
}

test('all 56 policies use the requested weakness, 5 unique members, and only target actual growth', () => {
  assert.equal(TARGETS.size, 56);
  for (const [key, target] of TARGETS) {
    const code = target.nameCode;
    const p = profile(key);
    p.characters[0].core = 7;
    const item = buildScoreItem(p, key, 'test');
    assert.equal(new Set(item.team).size, 5);
    assert.ok(item.team.includes(code));
    assert.equal(requestBody(key, [item]).weakness, target.weakness);
    assert.equal(item.data.characters.find(c => c.name_code === code).core, 7);
    assert.ok(item.data.characters.filter(c => c.name_code !== code).every(c => c.core === 0));
    assert.ok(!JSON.stringify(item).includes('PRIVATE'));
    const used = new Set(item.data.character_details.flatMap(d => ['head', 'torso', 'arm', 'leg']
      .flatMap(s => [1, 2, 3].map(i => d[`${s}_equip_option${i}_id`])).filter(Boolean)));
    assert.deepEqual(new Set(item.data.state_effects.map(e => e.id)), used);
    assert.deepEqual(item.data.outpost_info.recycle_room_researches, p.recycleRoom);
    assert.equal(item.data.character_details.length, 5);
  }
});

test('actual teammate changes and API request IDs cannot change the target fingerprint', () => {
  const p = profile();
  const a = buildScoreItem(p, 5129, 'first');
  const mate = structuredClone(standards['5129:fire'].characters.find(c => c.name_code !== 5129));
  mate.core = 7; p.characters.push(mate);
  assert.equal(inputHash(a), inputHash(buildScoreItem(p, 5129, 'second')));
  p.characters[0].core = 7;
  assert.notEqual(inputHash(a), inputHash(buildScoreItem(p, 5129, 'third')));
});

test('dummy favorites use character-specific maximum stages while actual target items are preserved', () => {
  const favorites = require('../services/nikke_score/favorite_items.json').items;
  for (const [key, target] of TARGETS) {
    const item = buildScoreItem(profile(key), key, 'favorite-check');
    for (const d of item.data.character_details.filter(d => d.name_code !== target.nameCode)) {
      const favorite = favorites[String(d.name_code)];
      assert.equal(d.favorite_item_lv, favorite ? 2 : 15);
      if (favorite) assert.equal(d.favorite_item_tid, favorite.tid);
      else assert.ok(d.favorite_item_tid >= 100000 && d.favorite_item_tid < 200000);
    }
  }
  // Privaty has a favorite, but as the actual target her equipped stage is authoritative.
  const p = profile('5007:water');
  for (const item of [null, { tid: 100102, level: 7 }, { tid: favorites['5007'].tid, level: 0 }]) {
    p.characters[0].favoriteItem = item;
    const d = buildScoreItem(p, '5007:water', 'actual').data.character_details.find(d => d.name_code === 5007);
    assert.equal(d.favorite_item_tid, item?.tid || 0);
    assert.equal(d.favorite_item_lv, item?.level || 0);
  }
});

test('cube fallback does not replace equipped cubes or hide missing cube data', () => {
  const p = profile();
  p.characters[0].harmonyCube = { tid: 1000304, level: 9 };
  assert.deepEqual(buildScoreItem(p, 5129, 'equipped').cubes['5129'], { tid: 1000304, lv: 9 });
  delete p.characters[0].harmonyCube;
  assert.throws(() => buildScoreItem(p, 5129, 'unknown'), { code: 'missing_growth' });
});

test('signed accuracy and charge-time options survive raw and legacy mapping', () => {
  for (const [id, type, value] of [[7000602, 'StatAccuracyCircle', -547], [7001001, 'StatChargeTime', -198]]) {
    const p = profile(5124);
    p.characters[0].equipment[0].overloadOptions[0] = id;
    p.stateEffects.push({ id: String(id), function_details: [{ function_type: type, function_value: value }] });
    const raw = buildScoreItem(p, 5124, 'raw');
    assert.deepEqual(raw.data.state_effects.find(e => e.id === id).function_details[0],
      { function_type: type, function_value: value });
    p.stateEffects = p.stateEffects.filter(e => String(e.id) !== String(id));
    assert.deepEqual(buildScoreItem(p, 5124, 'legacy').data.state_effects.find(e => e.id === id).function_details[0],
      { function_type: type, function_value: value });
  }
  const p = profile();
  p.characters[0].equipment[0].overloadOptions[0] = 7000801;
  p.stateEffects.push({ id: 7000801, function_details: [{ function_type: 'StatAtk', function_value: -477 }] });
  assert.throws(() => buildScoreItem(p, 5129, 'bad'), { code: 'unknown_option' });
});

test('same Nikke has distinct element policies and cache keys; requested roster is complete', () => {
  const roster = require('../services/nikke_score/collection_team_selection.json');
  assert.deepEqual([...TARGETS.keys()].sort(), roster.profiles.map(p => p.key).sort());
  assert.equal(new Set([...TARGETS.values()].map(t => t.nameCode)).size, 54);
  for (const [a, b] of [['5129:fire', '5129:iron'], ['5002:iron', '5002:water']]) {
    const item = buildScoreItem(profile(a), a, 'same');
    assert.notEqual(inputHash(item, a), inputHash(item, b));
    assert.notEqual(requestBody(a, [item]).weakness, requestBody(b, [item]).weakness);
  }
  assert.ok(TARGETS.has('5185:fire'));
  assert.ok(![...TARGETS.values()].some(t => [1019, 5155].includes(t.nameCode)));
  assert.deepEqual(resolveTarget('5159:fire').team, [1021, 5172, 5159, 5161, 5173]);
  assert.deepEqual(resolveTarget('5137:wind').team, [5065, 5133, 5137, 5132, 5007]);
  assert.equal(resolveTarget('5045:electric').nameCode, 5045);
});

test('missing target, unverified growth, missing research and unknown options never fall back', () => {
  for (const mutate of [p => p.characters = [], p => p.characters[0].growthDataQuality.complete = false,
    p => p.recycleRoom.pop(), p => p.recycleRoom = {}, p => p.characters = {},
    p => p.characters[0].equipment = [null], p => p.characters[0].skills.skill1 = '10',
    p => { p.characters[0].equipment[0].overloadOptions[0] = 123456; }]) {
    const p = profile(); mutate(p);
    assert.throws(() => buildScoreItem(p, 5129, 'test'));
  }
});

test('empty equipment and collection remain empty; absent cube falls back to reload15', () => {
  const p = profile();
  p.characters[0].equipment = []; p.characters[0].favoriteItem = null; p.characters[0].harmonyCube = null;
  const item = buildScoreItem(p, 5129, 'test');
  const d = item.data.character_details.find(c => c.name_code === 5129);
  assert.equal(d.head_equip_tier, 0); assert.equal(d.leg_equip_option3_id, 0);
  assert.equal(d.favorite_item_tid, 0);
  assert.equal(d.harmony_cube_tid, 0); // Raw growth stays faithful; explicit override supplies fallback.
  assert.deepEqual(item.cubes['5129'], { tid: 1000303, lv: 15 });
});

test('ranking uses unrounded damage, midrank ties, and rejects stale or mixed populations', () => {
  const now = Date.now();
  const d = { damages: Array(20).fill(100), calcVersion: 'c80', policyHash: POLICY_HASH, generatedAtMs: now };
  assert.equal(compareScore(d, 100, 'c80', now).topPercent, 50);
  assert.equal(compareScore(d, 101, 'c80', now).topPercent, 0);
  assert.equal(compareScore(d, 99, 'c80', now).topPercent, 100);
  assert.equal(compareScore(d, 100, 'c81', now).topPercent, null);
  assert.equal(compareScore({ ...d, policyHash: 'old' }, 100, 'c80', now).sampleCount, 0);
  assert.equal(compareScore(d, 100, 'c80', now + 86400001).topPercent, null);
  assert.equal(compareScore({ ...d, damages: [100] }, 100, 'c80', now).topPercent, null);
});

test('API provides byte Content-Length, 60s timeout and validates returned item IDs', async () => {
  const db = memoryDb();
  const item = buildScoreItem(profile(), 5129, 'test');
  const transport = { post: async (url, body, options) => {
    assert.equal(url, 'https://dildoro.com/api/partner/v1/damage');
    assert.equal(options.headers['Content-Length'], Buffer.byteLength(body));
    assert.equal(options.timeout, 60000);
    assert.equal(options.headers['X-Api-Key'], 'test-secret');
    return { status: 200, data: { calc_version: 'c80', items: [{ id: 'test', damage: 2030000000 }] } };
  } };
  const response = await createScoreApi(db, () => 'test-secret', transport)(5129, [item]);
  assert.equal(response.items[0].damage * 5 / 1e8, 101.5);
  transport.post = async () => ({ status: 200, data: { calc_version: 'c80', items: [{ id: 'wrong', damage: 1 }] } });
  await assert.rejects(createScoreApi(db, () => 'test-secret', transport)(5129, [item]), { code: 'invalid_response' });
});

test('upstream rate limits preserve Retry-After; credentials and bodies never enter errors', async () => {
  const db = memoryDb();
  const item = buildScoreItem(profile(), 5129, 'test');
  const call = createScoreApi(db, () => 'test-secret', { post: async () => ({ status: 429, headers: { 'retry-after': '17' } }) });
  await assert.rejects(call(5129, [item]), error => error.retryAfter === 17 && !error.message.includes('test-secret'));
  const timeout = createScoreApi(db, () => 'test-secret', { post: async () => { throw Error('test-secret'); } });
  await assert.rejects(timeout(5129, [item]), error => error.code === 'upstream_timeout' && !error.message.includes('test-secret'));
  db.data.set('nikke_score_state/api_lock', { owner: 'other', expiresAtMs: Date.now() + 10000 });
  await assert.rejects(call(5129, [item]), { code: 'busy' });
});

test('endpoint rejects unauthenticated and unrelated accounts without calling upstream', async () => {
  const functions = { runWith: () => ({ https: { onRequest: handler => handler } }) };
  for (const uid of [null, 'attacker']) {
    const handler = createNikkeScoreHandler({ functions, db: memoryDb({ 'open_id_bindings/other': { uid: 'owner' } }),
      getAuthenticatedUid: async () => uid });
    let status;
    const res = { set: () => {}, status: s => { status = s; return res; }, json: () => {}, send: () => {} };
    await handler({ method: 'POST', headers: {}, body: { openId: 'other', nameCode: 5129 } }, res);
    assert.equal(status, uid ? 403 : 401);
  }
});

