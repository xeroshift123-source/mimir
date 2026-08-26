#!/usr/bin/env node
'use strict';

/**
 * BlablaLink stage-clear API discovery/probe utility.
 *
 * This file is intentionally standalone. It does not import Firebase modules,
 * initialize Firebase Admin, or write to Firestore.
 *
 * Examples (PowerShell):
 *   $env:BOT_COOKIE = '...'
 *   node functions/tools/probe_stage_api.js --openId '29080-...' --areaId 83
 *   node functions/tools/probe_stage_api.js --url 'https://www.blablalink.com/user?openid=...'
 *   node functions/tools/probe_stage_api.js --stageId 123456 --areaId 83 --mode hard
 *   node functions/tools/probe_stage_api.js --discover-only
 */

const axios = require('axios');
const fs = require('fs');
const path = require('path');

const WEB_ORIGIN = 'https://www.blablalink.com';
const API_ORIGIN = 'https://api.blablalink.com';
const PROFILE_PATH = '/user';
const KEYWORDS = [
  'stage', 'clear', 'campaign', 'chapter', 'record', 'history',
  'battle', 'squad', 'formation', 'deck', 'quest', 'lineup',
];
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
  + 'AppleWebKit/537.36 (KHTML, like Gecko) '
  + 'Chrome/120.0.0.0 Safari/537.36';

const CANDIDATES = {
  main: {
    name: 'GetMainQuestClearLineup',
    endpoint: '/api/game/proxy/Game/GetMainQuestClearLineup',
    modes: ['normal', 'hard'],
    payload: ({ stageId, areaId }) => ({ stage_id: stageId, area_id: areaId }),
  },
  tower: {
    name: 'GetCampaignStageCharacterInfo',
    endpoint: '/api/game/proxy/Game/GetCampaignStageCharacterInfo',
    modes: ['tower'],
    payload: ({ stageId, areaId }) => ({ stage_id: stageId, area_id: areaId }),
  },
};

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const equalIndex = token.indexOf('=');
    if (equalIndex !== -1) {
      args[token.slice(2, equalIndex)] = token.slice(equalIndex + 1);
      continue;
    }
    const key = token.slice(2);
    const next = argv[index + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      index += 1;
    } else {
      args[key] = true;
    }
  }
  return args;
}

function printHelp() {
  console.log(`
Usage:
  node functions/tools/probe_stage_api.js [options]

Options:
  --openId <id>          Full (29080-...) or raw BlablaLink open ID
  --url <profile-url>    Extract the openid query parameter from a profile URL
  --areaId <number>      NIKKE area/server ID (or AREA_ID env)
  --stageId <number>     Exact game stage ID (or STAGE_ID env)
  --mode <mode>          normal (default), hard, or tower
  --candidate <value>    auto (default), main, tower, or both
  --discover-only        Analyze bundles without calling a game API
  --skip-discovery       Skip bundle analysis and only probe
  --save-responses       Save full JSON responses under functions/tools/probe-output
  --max-preview <chars>  Console JSON preview length (default: 12000)
  --help                 Show this help

Environment:
  BOT_COOKIE             Required for API probing; never hardcoded by this script
  OPEN_ID, AREA_ID, STAGE_ID are accepted as argument fallbacks

Safety:
  At most one discovered stage endpoint is called by default. Use
  --candidate both explicitly to call both candidates.
`);
}

function maybeDecodeOpenId(value) {
  if (!value) return '';
  let decoded = String(value).trim();
  try {
    const normalized = decoded.replace(/-/g, '+').replace(/_/g, '/');
    if (/^[A-Za-z0-9+/]+={0,2}$/.test(normalized)) {
      const candidate = Buffer.from(normalized, 'base64').toString('utf8');
      if (/^[\x20-\x7E]+$/.test(candidate) && candidate.length > 3) {
        decoded = candidate;
      }
    }
  } catch (_) {
    // Keep the original value.
  }
  return decoded.replace(/\x00/g, '').trim();
}

function extractOpenId(args) {
  let value = args.openId || args.openid || process.env.OPEN_ID || '';
  if (args.url) {
    try {
      value = new URL(String(args.url)).searchParams.get('openid') || value;
    } catch (_) {
      const match = String(args.url).match(/[?&]openid=([^&]+)/i);
      if (match) value = decodeURIComponent(match[1]);
    }
  }
  return maybeDecodeOpenId(value);
}

function rawOpenId(openId) {
  if (!openId) return '';
  const parts = openId.split('-');
  return parts.length > 1 ? parts[parts.length - 1] : openId;
}

function positiveInteger(value, label, required = false) {
  if (value === undefined || value === null || value === '') {
    if (required) throw new Error(`${label} is required.`);
    return null;
  }
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number <= 0) {
    throw new Error(`${label} must be a positive integer.`);
  }
  return number;
}

function headers(botCookie = '') {
  return {
    'User-Agent': USER_AGENT,
    'Content-Type': 'application/json',
    'X-language': 'ko',
    Origin: WEB_ORIGIN,
    Referer: `${WEB_ORIGIN}/`,
    ...(botCookie ? { Cookie: botCookie } : {}),
  };
}

function absoluteAssetUrl(value, baseUrl) {
  return new URL(value, baseUrl).href;
}

function extractScriptUrls(html, pageUrl) {
  const urls = [];
  const regex = /(?:src|href)=["']([^"']+\.(?:js|mjs)(?:\?[^"']*)?)["']/gi;
  let match;
  while ((match = regex.exec(html)) !== null) {
    urls.push(absoluteAssetUrl(match[1], pageUrl));
  }
  return [...new Set(urls)];
}

function importedFiles(source) {
  const matches = source.matchAll(/["'`](?:\.\/)?([A-Za-z0-9_@.-]+\.js)["'`]/g);
  return [...new Set([...matches].map((match) => match[1]))];
}

function extractGameProxyEndpoints(registrySource) {
  const factoryMatch = registrySource.match(
    /([A-Za-z_$][\w$]*)=a\([`"']\/game\/proxy\/Game[`"']\)/,
  );
  if (!factoryMatch) return [];
  const factory = factoryMatch[1].replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const endpointRegex = new RegExp(`${factory}\\([\\x60"'](\\/[A-Za-z0-9_]+)[\\x60"']\\)`, 'g');
  return [...new Set(
    [...registrySource.matchAll(endpointRegex)]
      .map((match) => `/api/game/proxy/Game${match[1]}`),
  )].sort();
}

function relevantEndpoint(endpoint) {
  const lower = endpoint.toLowerCase();
  return KEYWORDS.some((keyword) => lower.includes(keyword));
}

async function getText(url, options = {}) {
  const response = await axios.get(url, {
    timeout: 20000,
    headers: { 'User-Agent': USER_AGENT, ...(options.headers || {}) },
    responseType: 'text',
    transformResponse: [(value) => value],
    validateStatus: (status) => status >= 200 && status < 300,
  });
  return String(response.data);
}

async function discoverEndpoints() {
  console.log('\n=== A. ENDPOINT DISCOVERY ===');
  const pageUrl = `${WEB_ORIGIN}${PROFILE_PATH}`;
  const html = await getText(pageUrl);
  const scripts = extractScriptUrls(html, pageUrl);
  const firstPartyScripts = scripts.filter((url) => url.startsWith(`${WEB_ORIGIN}/`));
  console.log(`Profile page: ${pageUrl}`);
  console.log(`First-party entry scripts: ${firstPartyScripts.length}`);

  const mainUrl = firstPartyScripts.find((url) => /\/index-[^/]+\.js(?:\?|$)/.test(url));
  const registryUrl = firstPartyScripts.find((url) => /\/v4-[^/]+\.js(?:\?|$)/.test(url));
  if (!mainUrl || !registryUrl) {
    throw new Error('Could not locate the current index/v4 bundle pair.');
  }

  const [mainSource, registrySource] = await Promise.all([
    getText(mainUrl),
    getText(registryUrl),
  ]);
  const endpoints = extractGameProxyEndpoints(registrySource);
  const relevant = endpoints.filter(relevantEndpoint);
  console.log(`Main bundle: ${mainUrl}`);
  console.log(`API registry: ${registryUrl}`);
  console.log(`Extracted /api/game/proxy/Game endpoints: ${endpoints.length}`);
  console.log('Keyword-matched candidates:');
  relevant.forEach((endpoint) => console.log(`  - ${endpoint}`));

  const namedEvidence = [
    'GetMainQuestClearLineup',
    'GetCampaignStageCharacterInfo',
  ].map((name) => ({
    name,
    endpointFound: endpoints.some((endpoint) => endpoint.endsWith(`/${name}`)),
    queryWrapperFound: mainSource.includes(name === 'GetMainQuestClearLineup'
      ? 'API_GAME_GET_MAIN_QUEST_CLEAR_LINEUP'
      : 'API_GAME_GET_CAMPAIGN_STAGE_CHARACTER_INFO'),
  }));

  // The current feature implementation lives in a lazy-loaded home chunk.
  // Search only likely feature chunks, not every asset body.
  const baseUrl = new URL('.', mainUrl).href;
  const featureFiles = importedFiles(mainSource).filter((file) =>
    /^(?:home|user|campaign|record)-/i.test(file),
  );
  const featureSources = [];
  for (const file of featureFiles) {
    try {
      const source = await getText(absoluteAssetUrl(file, baseUrl));
      if (source.includes('stage_id') && source.includes('area_id')) {
        featureSources.push({ file, source });
      }
    } catch (error) {
      console.warn(`  [bundle skipped] ${file}: ${error.message}`);
    }
  }
  const usage = featureSources.map(({ file, source }) => ({
    file,
    requestPayloadEvidence:
      /stage_id\s*:\s*[\w$.]+\s*,\s*area_id\s*:\s*[\w$.]+/.test(source)
      || (source.includes('stage_id') && source.includes('area_id')),
    responseFieldEvidence: [
      'list', 'slot', 'tid', 'combat', 'lv',
    ].filter((field) => source.includes(field)),
    uiFieldEvidence: [
      'normal', 'hard', 'tower', 'chapter', 'stage', 'squad', 'total_power',
    ].filter((field) => source.includes(field)),
  }));

  console.log('\nVerified current candidates:');
  for (const evidence of namedEvidence) {
    console.log(
      `  - ${evidence.name}: registry=${evidence.endpointFound}, query-wrapper=${evidence.queryWrapperFound}`,
    );
  }
  if (usage.length) {
    console.log('\nLazy feature bundle evidence:');
    console.log(JSON.stringify(usage, null, 2));
  }
  console.log('\nObserved payload for both current candidates: { stage_id, area_id }');
  console.log('Observed response/UI path: data.list[] -> slot, tid, combat, lv; UI derives total power by summing combat.');

  return { mainUrl, registryUrl, endpoints, relevant, namedEvidence, usage };
}

function cookieGameOpenId(cookie) {
  const match = String(cookie).match(/(?:^|;\s*)game_openid=([^;]+)/i);
  return match ? decodeURIComponent(match[1]) : '';
}

async function postApi(endpoint, payload, botCookie) {
  const url = endpoint.startsWith('http') ? endpoint : `${API_ORIGIN}${endpoint}`;
  try {
    const response = await axios.post(url, payload, {
      headers: headers(botCookie),
      timeout: 10000,
      validateStatus: () => true,
    });
    return { url, status: response.status, body: response.data };
  } catch (error) {
    return {
      url,
      status: error.response?.status || null,
      body: error.response?.data || null,
      networkError: error.message,
    };
  }
}

function bodyData(body) {
  return body && typeof body === 'object' && 'data' in body ? body.data : body;
}

function walk(value, visitor, key = '', pathParts = [], seen = new Set()) {
  if (value === null || value === undefined || typeof value !== 'object') return;
  if (seen.has(value)) return;
  seen.add(value);
  if (Array.isArray(value)) {
    visitor(value, key, pathParts);
    value.forEach((item, index) => walk(item, visitor, String(index), [...pathParts, index], seen));
    return;
  }
  for (const [childKey, childValue] of Object.entries(value)) {
    visitor(childValue, childKey, [...pathParts, childKey]);
    walk(childValue, visitor, childKey, [...pathParts, childKey], seen);
  }
}

function analyzeStageEvidence(body) {
  const data = bodyData(body);
  const result = {
    responseKeys: data && typeof data === 'object' ? Object.keys(data) : [],
    identifierPaths: [],
    characterPaths: [],
    combatPaths: [],
    levelPaths: [],
    fiveMemberArrayPaths: [],
  };
  const pathText = (parts) => parts.join('.');
  walk(data, (value, key, parts) => {
    const lower = key.toLowerCase();
    if (/(stage|chapter)(_id)?$/.test(lower)) result.identifierPaths.push(pathText(parts));
    if (/(character|name_code|tid|nikke)(_id)?$/.test(lower)) result.characterPaths.push(pathText(parts));
    if (/(combat|power|total_power|team_combat)$/.test(lower)) result.combatPaths.push(pathText(parts));
    if (/(lv|level)$/.test(lower)) result.levelPaths.push(pathText(parts));
    if (Array.isArray(value) && value.length === 5) result.fiveMemberArrayPaths.push(pathText(parts));
  });
  for (const key of Object.keys(result)) {
    if (Array.isArray(result[key])) result[key] = [...new Set(result[key])].slice(0, 30);
  }
  result.hasStageIdentifier = result.identifierPaths.length > 0;
  result.hasCharacterIdentifier = result.characterPaths.length > 0;
  result.hasCombat = result.combatPaths.length > 0;
  result.hasLevel = result.levelPaths.length > 0;
  result.hasFiveMemberArray = result.fiveMemberArrayPaths.length > 0;
  result.hasSquadEvidence = result.hasFiveMemberArray
    && result.hasCharacterIdentifier
    && result.hasCombat
    && result.hasLevel;
  return result;
}

function apiCode(body) {
  if (!body || typeof body !== 'object') return null;
  if (typeof body.code === 'number') return body.code;
  if (typeof body.ret === 'number') return body.ret;
  return null;
}

function summarizeResult(result, payload) {
  const code = apiCode(result.body);
  const message = result.body?.msg || result.body?.message || result.networkError || '';
  const evidence = analyzeStageEvidence(result.body);
  const httpOk = result.status !== null && result.status >= 200 && result.status < 300;
  const apiSuccess = httpOk && code === 0;
  const verifiedStageRecord = apiSuccess
    && evidence.hasStageIdentifier
    && evidence.hasSquadEvidence;
  return {
    endpoint: result.url,
    requestPayload: payload,
    httpStatus: result.status,
    code,
    msg: message,
    apiSuccess,
    verifiedStageRecord,
    verdict: verifiedStageRecord
      ? 'VERIFIED_STAGE_RECORD'
      : apiSuccess
        ? 'API_SUCCESS_BUT_INCOMPLETE_STAGE_RECORD_EVIDENCE'
        : 'FAILED',
    evidence,
  };
}

function responsePreview(body, maxChars) {
  let serialized;
  try {
    serialized = JSON.stringify(body, null, 2);
  } catch (_) {
    serialized = String(body);
  }
  if (serialized.length <= maxChars) return serialized;
  return `${serialized.slice(0, maxChars)}\n... [truncated ${serialized.length - maxChars} chars]`;
}

function saveResponse(name, value) {
  const outputDir = path.join(__dirname, 'probe-output');
  fs.mkdirSync(outputDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputPath = path.join(outputDir, `${stamp}-${name}.json`);
  fs.writeFileSync(outputPath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  return outputPath;
}

function basicProgress(data, mode) {
  const basic = data?.data?.basic_info || data?.data || {};
  if (mode === 'hard') {
    return basic.progress_hard_campaign || basic.hard_progress || 0;
  }
  return basic.progress_normal_campaign || basic.normal_progress || 0;
}

async function resolveStageId({ stageId, openId, areaId, mode, botCookie }) {
  if (stageId) return { stageId, source: 'argument/environment' };
  if (mode === 'tower') {
    throw new Error('--stageId is required for tower mode (tower floor is not the API stage_id).');
  }
  if (!openId) {
    throw new Error('--openId/--url (or OPEN_ID) is required when --stageId is omitted.');
  }
  const payload = { intl_open_id: rawOpenId(openId), nikke_area_id: areaId };
  console.log('\nResolving the latest campaign stage via existing GetUserProfileBasicInfo...');
  const result = await postApi(
    '/api/game/proxy/Game/GetUserProfileBasicInfo',
    payload,
    botCookie,
  );
  const code = apiCode(result.body);
  console.log(JSON.stringify({ status: result.status, code, msg: result.body?.msg || '' }, null, 2));
  if (result.status < 200 || result.status >= 300 || code !== 0) {
    throw new Error('Could not resolve stage_id from GetUserProfileBasicInfo. Pass --stageId explicitly.');
  }
  const resolved = positiveInteger(basicProgress(result.body, mode), 'resolved stageId', true);
  return { stageId: resolved, source: `GetUserProfileBasicInfo (${mode} progress)` };
}

function selectedCandidates(value, mode) {
  const selection = String(value || 'auto').toLowerCase();
  if (selection === 'both') return [CANDIDATES.main, CANDIDATES.tower];
  if (selection === 'main') return [CANDIDATES.main];
  if (selection === 'tower') return [CANDIDATES.tower];
  if (selection !== 'auto') throw new Error('--candidate must be auto, main, tower, or both.');
  return [mode === 'tower' ? CANDIDATES.tower : CANDIDATES.main];
}

async function probe(args) {
  console.log('\n=== B. ENDPOINT PROBE ===');
  const botCookie = process.env.BOT_COOKIE || '';
  if (!botCookie) {
    console.log('Skipped: BOT_COOKIE is not set. Discovery completed without an authenticated API call.');
    return [];
  }

  const openId = extractOpenId(args);
  const areaId = positiveInteger(args.areaId || process.env.AREA_ID, 'areaId', true);
  const requestedStageId = positiveInteger(args.stageId || process.env.STAGE_ID, 'stageId');
  const mode = String(args.mode || 'normal').toLowerCase();
  if (!['normal', 'hard', 'tower'].includes(mode)) {
    throw new Error('--mode must be normal, hard, or tower.');
  }

  const cookieOpenId = cookieGameOpenId(botCookie);
  const targetRawOpenId = rawOpenId(openId);
  if (cookieOpenId && targetRawOpenId && cookieOpenId !== targetRawOpenId) {
    console.warn(
      'WARNING: BOT_COOKIE game_openid differs from the requested openId. '
      + 'The discovered stage endpoints do not accept openId, and the web UI exposes '
      + 'this section only for the logged-in/self account. The response may belong to '
      + 'the BOT_COOKIE account, not the requested commander.',
    );
  }

  const resolved = await resolveStageId({
    stageId: requestedStageId,
    openId,
    areaId,
    mode,
    botCookie,
  });
  console.log(`stage_id=${resolved.stageId} (${resolved.source}), area_id=${areaId}, mode=${mode}`);

  const candidates = selectedCandidates(args.candidate, mode);
  if (candidates.length > 1) {
    console.warn('Explicit --candidate both selected: two stage candidates will be called once each.');
  }
  const maxPreview = positiveInteger(args['max-preview'] || 12000, 'max-preview', true);
  const summaries = [];

  for (const candidate of candidates) {
    const payload = candidate.payload({ stageId: resolved.stageId, areaId });
    console.log(`\n[PROBE] ${candidate.name}`);
    console.log(`POST ${API_ORIGIN}${candidate.endpoint}`);
    console.log(`payload=${JSON.stringify(payload)}`);
    const result = await postApi(candidate.endpoint, payload, botCookie);
    const summary = summarizeResult(result, payload);
    summaries.push(summary);
    console.log('summary=');
    console.log(JSON.stringify(summary, null, 2));
    console.log('response=');
    console.log(responsePreview(result.body, maxPreview));
    if (args['save-responses']) {
      console.log(`saved=${saveResponse(candidate.name, result.body)}`);
    }
    if (summary.verifiedStageRecord) {
      console.log(`\n*** SUCCESSFUL ENDPOINT: ${candidate.name} ***`);
    } else if (summary.apiSuccess) {
      console.log(
        `\n*** API code=0, but strict stage-record evidence is incomplete: ${candidate.name} ***`,
      );
    }
  }

  console.log('\nProbe verdicts:');
  summaries.forEach((summary) => {
    console.log(`  - ${summary.endpoint}: ${summary.verdict}`);
  });
  return summaries;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    return;
  }

  let discovery = null;
  if (!args['skip-discovery']) {
    discovery = await discoverEndpoints();
  }
  let probeResults = [];
  if (!args['discover-only']) {
    probeResults = await probe(args);
  }

  console.log('\n=== FINAL DIAGNOSTIC SUMMARY ===');
  console.log(JSON.stringify({
    discovery: discovery ? {
      relevantEndpoints: discovery.relevant,
      usageBundles: discovery.usage.map((item) => item.file),
    } : 'skipped',
    probeResults: probeResults.map((item) => ({
      endpoint: item.endpoint,
      status: item.httpStatus,
      code: item.code,
      verdict: item.verdict,
    })),
    firestoreWrites: false,
  }, null, 2));
}

main().catch((error) => {
  console.error(`\n[FATAL] ${error.stack || error.message}`);
  process.exitCode = 1;
});

