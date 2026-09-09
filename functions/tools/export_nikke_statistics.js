'use strict';

// Standalone, read-only export. Never import index.js or call refresh endpoints.
const fs = require('node:fs/promises');
const path = require('node:path');
const { parseArgs } = require('node:util');
const { statisticsCacheKey } = require('../nikkeStatisticsStore');

const ROOT = path.resolve(__dirname, '../..');
const SCALARS = {
  schemaVersion: 'number', nameCode: 'number', server: 'string',
  sampleCount: 'number', minimumSample: 'number', isSufficient: 'boolean',
  freshnessDays: 'number',
};
const OPTION_FIELDS = {
  key: 'string', name: 'string', userCount: 'number', adoptionRate: 'number',
  averageTotalPercent: 'number', averageLineCount: 'number',
  adopterAverageTotalPercent: 'number', adopterAverageLineCount: 'number',
};

function pick(data, fields) {
  const result = {};
  for (const [key, type] of Object.entries(fields)) {
    if (!Object.hasOwn(data, key)) continue;
    const value = data[key];
    if (typeof value !== type || (type === 'number' && !Number.isFinite(value))) {
      throw new Error(`Unexpected type for aggregate field: ${key}`);
    }
    result[key] = value;
  }
  return result;
}

function histogram(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Invalid histogram');
  }
  // Only numeric bins and counts can cross the export boundary.
  for (const [bin, count] of Object.entries(value)) {
    if (!/^\d+(?:\.\d+)?$/.test(bin) || !Number.isFinite(Number(bin))
      || !Number.isSafeInteger(count) || count < 0) {
      throw new Error('Invalid histogram bin or count');
    }
  }
  return { ...value };
}

function timestamp(value) {
  if (value === null) return null;
  if (typeof value?.toDate === 'function') {
    return { iso: value.toDate().toISOString(), seconds: value.seconds, nanoseconds: value.nanoseconds };
  }
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)
    && Number.isFinite(Date.parse(value))) return value;
  throw new Error('Unexpected aggregate timestamp format');
}

function exportDocument(id, data) {
  if (!/^all_[1-9]\d*$/.test(id)) return null;
  if (!Number.isSafeInteger(data.nameCode) || data.nameCode <= 0
    || statisticsCacheKey(data.nameCode) !== id || !Array.isArray(data.overload)) {
    throw new Error('Nikke document does not match the expected cache schema');
  }
  const result = { documentId: id, ...pick(data, SCALARS) };
  result.overload = data.overload.map(option => ({
    ...pick(option, OPTION_FIELDS), histogram: histogram(option.histogram),
  }));
  if (data.combinedOffense != null) {
    result.combinedOffense = {
      ...pick(data.combinedOffense, { averageTotalPercent: 'number' }),
      histogram: histogram(data.combinedOffense.histogram),
    };
  }
  for (const key of ['skillPresets', 'equipmentPresets']) {
    if (data[key] === undefined) continue;
    if (!Array.isArray(data[key])) throw new Error(`Invalid ${key}`);
    result[key] = data[key].map(item => {
      const preset = pick(item, { preset: 'string', count: 'number', ratio: 'number' });
      if (!/^(?:\d+|X)(?:\/(?:\d+|X)){2,3}$/.test(preset.preset)) {
        throw new Error('Unexpected aggregate preset');
      }
      return preset;
    });
  }
  for (const key of ['generatedAt', 'cachedAt']) {
    if (Object.hasOwn(data, key)) result[key] = timestamp(data[key]);
  }
  return result;
}

async function readDocuments(db, pageSize = 100) {
  const documents = [];
  let cursor;
  while (true) {
    let query = db.collection('nikke_statistics')
      .orderBy('__name__').startAt('all_').endBefore('all`')
      .select(...Object.keys(SCALARS), 'overload', 'combinedOffense',
        'skillPresets', 'equipmentPresets', 'generatedAt', 'cachedAt')
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const exported = exportDocument(doc.id, doc.data());
      if (exported) documents.push(exported);
    }
    if (page.size < pageSize) break;
    cursor = page.docs[page.docs.length - 1];
  }
  return documents.sort((a, b) => a.nameCode - b.nameCode);
}

async function main() {
  const { values } = parseArgs({ options: {
    output: { type: 'string' }, help: { type: 'boolean', short: 'h' },
  } });
  if (values.help) {
    console.log('node functions/tools/export_nikke_statistics.js [--output <local-json-path>]');
    console.log('Reads nikke-mimir / mimirdb / nikke_statistics only. Uses Application Default Credentials.');
    return;
  }
  if (process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Unset FIRESTORE_EMULATOR_HOST to export production statistics.');
  const project = JSON.parse(await fs.readFile(path.join(ROOT, '.firebaserc'), 'utf8')).projects.default;
  if (project !== 'nikke-mimir') throw new Error('Unexpected Firebase project; review configuration first.');
  const output = path.resolve(values.output || path.join(ROOT, 'nikke_statistics_export.json'));
  try {
    await fs.access(output);
    throw new Error('Output already exists; use --output with a new filename.');
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const { initializeApp, applicationDefault, deleteApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const app = initializeApp({ projectId: project, credential: applicationDefault() }, 'statistics-export');
  const db = getFirestore(app, 'mimirdb');
  try {
    const startedAt = new Date().toISOString();
    const documents = await readDocuments(db);
    if (documents.length === 0) throw new Error('No matching Nikke statistics found; no output written.');
    const payload = {
      exportVersion: 1, projectId: project, databaseId: 'mimirdb', collection: 'nikke_statistics',
      startedAt, exportedAt: new Date().toISOString(), documentCount: documents.length,
      notes: [
        'Only existing all_<nameCode> aggregate documents; no account records or account_element_damage.',
        'Explicit aggregate field allowlist; missing fields and all stored histogram bins are preserved.',
        'Current generator stores only the top 5 overload options. Missing elementDamage does not imply zero.',
        'sampleCount counts eligible linked commander accounts owning this Nikke, not unique people.',
        'Current schema includes non-adopters in histogram 0.00; adoptionRate is percent (0 to 100).',
        'Timestamps preserve seconds/nanoseconds with an ISO display value. Pagination is not a single-time snapshot.',
      ],
      documents,
    };
    await fs.writeFile(output, JSON.stringify(payload, null, 2) + '\n', { encoding: 'utf8', flag: 'wx' });
    console.log(`Exported ${documents.length} Nikke documents to ${output}`);
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch(error => {
    console.error(`Export failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { exportDocument, readDocuments };
