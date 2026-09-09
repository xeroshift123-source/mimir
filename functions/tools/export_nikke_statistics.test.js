'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { Timestamp, Firestore } = require('firebase-admin/firestore');
const { aggregateNikkeStatistics } = require('../nikkeStatistics');
const { exportDocument, readDocuments } = require('./export_nikke_statistics');

function fixture(nameCode = 1) {
  return aggregateNikkeStatistics([
    { characters: [{ name_code: nameCode, equipment: [{ overloadOptions: [7000501] }] }] },
    { characters: [{ name_code: nameCode }] },
  ], nameCode);
}

test('preserves generated aggregates and zero bins, strips unexpected personal fields at every level', () => {
  const data = fixture();
  const original = structuredClone(data);
  data.uid = 'PRIVATE';
  data.overload[0].uid = 'PRIVATE';
  data.combinedOffense.myTotalPercent = 999;
  data.skillPresets[0].openId = 'PRIVATE';
  const exported = exportDocument('all_1', data);
  assert.deepEqual(exported, { documentId: 'all_1', ...original });
  assert.equal(exported.overload[0].histogram['0.00'], 1);
  assert.equal(JSON.stringify(exported).includes('PRIVATE'), false);
});

test('excludes account documents, rejects mismatched IDs and nonnumeric histogram keys', () => {
  assert.equal(exportDocument('account_element_damage', { uid: 'PRIVATE' }), null);
  assert.equal(exportDocument('legacy_1', fixture()), null);
  assert.throws(() => exportDocument('all_2', fixture()));
  const data = fixture();
  data.overload[0].histogram.PRIVATE = 1;
  assert.throws(() => exportDocument('all_1', data), /histogram/);
});

test('preserves nanosecond timestamps and missing elementDamage without inventing zeros', () => {
  const data = fixture();
  data.generatedAt = new Timestamp(1700000000, 123456789);
  data.overload = [];
  const exported = exportDocument('all_1', data);
  assert.deepEqual(exported.overload, []);
  assert.equal(exported.generatedAt.nanoseconds, 123456789);
  assert.equal(exported.generatedAt.seconds, 1700000000);
  assert.equal(exported.cachedAt, undefined);
});

test('uses only the aggregate query, paginates all documents, and sorts numerically', async () => {
  const docs = [10, 2, 3, 4].map(n => ({ id: `all_${n}`, data: () => fixture(n) }));
  let calls = 0;
  let cursor;
  const query = {
    orderBy(field) { assert.equal(field, '__name__'); return this; },
    startAt(value) { assert.equal(value, 'all_'); return this; },
    endBefore(value) { assert.equal(value, 'all`'); return this; },
    select(...fields) { assert.equal(fields.includes('uid'), false); return this; },
    limit(value) { assert.equal(value, 2); return this; },
    startAfter(value) { cursor = value; return this; },
    async get() {
      const offset = cursor ? docs.indexOf(cursor) + 1 : 0;
      const page = docs.slice(offset, offset + 2);
      calls += 1;
      return { docs: page, size: page.length };
    },
  };
  // No write methods or other collection access are available on this fake.
  const result = await readDocuments({ collection(name) {
    assert.equal(name, 'nikke_statistics'); return query;
  } }, 2);
  assert.deepEqual(result.map(doc => doc.nameCode), [2, 3, 4, 10]);
  assert.equal(calls, 3);
});

test('installed Firestore SDK accepts the actual paginated query without network access', async () => {
  const db = new Firestore({ projectId: 'nikke-mimir' });
  const query = db.collection('nikke_statistics').orderBy('__name__')
    .startAt('all_').endBefore('all`').select('nameCode', 'overload').limit(100);
  assert.doesNotThrow(() => query.startAfter('all_100'));
  await db.terminate();
});
