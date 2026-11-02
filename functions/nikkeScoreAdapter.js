'use strict';

const { createHash } = require('node:crypto');
const targets = require('./nikkeScoreTargets.json');
const standards = require('./nikkeScoreStandards.json');
const { optionDefinition, optionValue } = require('./nikkeStatistics');
const TARGETS = new Map(targets.map(t => [t.key, t]));
function resolveTarget(key, weakness) {
  const target = typeof key === 'string' ? TARGETS.get(key)
    : weakness ? TARGETS.get(`${key}:${weakness}`) : targets.find(t => t.nameCode === key);
  if (!target) throw new ScoreError('unsupported_nikke', '아직 고정 조합이 등록되지 않은 니케·속성입니다.');
  return target;
}
const RESEARCH_IDS = [1001, 1101, 1102, 1103, 1201, 1202, 1203, 1204, 1205];
const SLOTS = ['head', 'torso', 'arm', 'leg'];
const OPTION_TYPES = { elementDamage: 'IncElementDmg', hitRate: 'StatAccuracyCircle',
  maxAmmo: 'StatAmmoLoad', attack: 'StatAtk', chargeDamage: 'StatChargeDamage',
  chargeSpeed: 'StatChargeTime', criticalRate: 'StatCritical',
  criticalDamage: 'StatCriticalDamage', defense: 'StatDef' };
const POLICY = { schema: 2, duration: 180, level: 400, boss: { def: 31784, core_size: 0 },
  burst: { burst_switch_delay: 0.1 }, partyGrowth: 'target-user-teammates-fixed',
  research: 'user-shared-by-party', cube: 'equipped-or-reload15',
  dummyFavorite: 'maximum-available-stage', targets, standards };
const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const POLICY_HASH = digest(POLICY);

class ScoreError extends Error {
  constructor(code, message, status = 422, retryAfter = null) {
    super(message); this.code = code; this.status = status; this.retryAfter = retryAfter;
  }
}
function integer(value, field, low, high) {
  if (!Number.isSafeInteger(value) || value < low || value > high) {
    throw new ScoreError('missing_growth', `${field} 육성 정보가 올바르지 않습니다. 다시 동기화해 주세요.`);
  }
  return value;
}

function buildScoreItem(commander, profileKey, id) {
  const target = resolveTarget(profileKey);
  const nameCode = target.nameCode;
  if (!Array.isArray(commander?.characters)) throw new ScoreError('missing_target', '저장된 니케 정보가 없습니다. 다시 동기화해 주세요.');
  const characters = [], details = [], effects = new Map(), cubes = {};
  for (let index = 0; index < target.team.length; index++) {
    const code = target.team[index];
    const fixed = standards[target.key];
    const source = code === nameCode ? commander : fixed;
    const matches = source.characters.filter(c => c?.name_code === code);
    const label = target.teamNames[index];
    if (matches.length !== 1) throw new ScoreError('missing_target', `${label} 보유 정보가 없습니다.`);
    const c = matches[0];
    if (c.growthDataQuality?.complete !== true || c.growthDataQuality?.schemaVersion !== 1) {
      throw new ScoreError('resync_required', `${label}의 육성 수집 정보가 부족합니다. 계정을 다시 동기화해 주세요.`);
    }
    const grade = integer(c.grade, label + ' 돌파', 0, 3);
    const core = integer(c.core, label + ' 코어', 0, 7);
    if (core && grade !== 3) throw new ScoreError('missing_growth', `${label} 돌파·코어 정보가 일치하지 않습니다.`);
    characters.push({ name_code: code, grade, core });
    const d = { name_code: code,
      skill1_lv: integer(c.skills?.skill1, label + ' 스킬1', 1, 10),
      skill2_lv: integer(c.skills?.skill2, label + ' 스킬2', 1, 10),
      ulti_skill_lv: integer(c.skills?.burst, label + ' 버스트', 1, 10),
      attractive_lv: integer(c.bondLevel, label + ' 호감도', 1, 40) };
    for (const [key, prefix, max] of [['favoriteItem', 'favorite_item', 15], ['harmonyCube', 'harmony_cube', 15]]) {
      if (!(key in c)) throw new ScoreError('missing_growth', `${label} 소장품·큐브 정보가 없습니다. 다시 동기화해 주세요.`);
      const entry = c[key];
      d[`${prefix}_tid`] = entry === null ? 0 : integer(entry?.tid, label + ' ' + key, 1, 999999999);
      d[`${prefix}_lv`] = entry === null ? 0 : integer(entry?.level, label + ' ' + key + ' 레벨', key === 'harmonyCube' ? 1 : 0, max);
    }
    cubes[String(code)] = c.harmonyCube === null ? { tid: 1000303, lv: 15 }
      : { tid: d.harmony_cube_tid, lv: d.harmony_cube_lv };
    if (!Array.isArray(c.equipment) || c.equipment.length > 4) throw new ScoreError('missing_growth', `${label} 장비 정보가 없습니다.`);
    const seen = new Set();
    for (const slot of SLOTS) {
      for (const field of ['tier', 'lv', 'corporation_type', 'option1_id', 'option2_id', 'option3_id']) d[`${slot}_equip_${field}`] = 0;
    }
    for (const eq of c.equipment) {
      const slot = eq?.slot;
      if (!SLOTS.includes(slot) || seen.has(slot)) throw new ScoreError('missing_growth', `${label} 장비 부위가 올바르지 않습니다.`);
      seen.add(slot);
      d[`${slot}_equip_tier`] = integer(eq.tier, label + ' 장비 등급', 1, 10);
      d[`${slot}_equip_lv`] = integer(eq.level, label + ' 장비 강화', 0, 5);
      const corp = integer(eq.corporationType, label + ' 기업 장비', 0, 7);
      if (![0, 1, 2, 3, 4, 7].includes(corp)) throw new ScoreError('missing_growth', `${label} 기업 장비 정보가 올바르지 않습니다.`);
      d[`${slot}_equip_corporation_type`] = corp;
      if (!Array.isArray(eq.overloadOptions) || eq.overloadOptions.length !== 3) throw new ScoreError('missing_growth', `${label} 장비 옵션 정보가 없습니다.`);
      eq.overloadOptions.forEach((rawId, i) => {
        const optionId = integer(rawId, label + ' 옵션', 0, 999999999);
        d[`${slot}_equip_option${i + 1}_id`] = optionId;
        if (!optionId) return;
        if (eq.tier !== 10) throw new ScoreError('missing_growth', `${label} 오버로드 장비 정보가 일치하지 않습니다.`);
        const raw = (Array.isArray(source.stateEffects) ? source.stateEffects : []).find(e => String(e?.id) === String(optionId));
        const first = raw?.function_details?.[0];
        const definition = optionDefinition(optionId);
        const effect = first ? { function_type: first.function_type, function_value: first.function_value }
          : definition ? { function_type: OPTION_TYPES[definition.key],
            function_value: Math.round(optionValue(optionId) * 100) * (['hitRate', 'chargeSpeed'].includes(definition.key) ? -1 : 1) } : null;
        if (!effect || !Object.values(OPTION_TYPES).concat('IncHurtDef').includes(effect.function_type)
          || !Number.isSafeInteger(effect.function_value)
          || (effect.function_value < 0 && !['StatAccuracyCircle', 'StatChargeTime'].includes(effect.function_type))) {
          throw new ScoreError('unknown_option', `${label} 장비 옵션을 확인할 수 없습니다. 다시 동기화해 주세요.`);
        }
        effects.set(optionId, { id: optionId, function_details: [effect] });
      });
    }
    details.push(d);
  }
  if (!Array.isArray(commander.recycleRoom)) throw new ScoreError('missing_research', '연구실 정보가 없습니다. 다시 동기화해 주세요.');
  const researches = RESEARCH_IDS.map(tid => {
    const rows = commander.recycleRoom.filter(r => r?.tid === tid);
    if (rows.length !== 1) throw new ScoreError('missing_research', '연구실 9개 항목이 필요합니다. 계정을 다시 동기화해 주세요.');
    return { tid, lv: integer(rows[0].lv, '연구실', 0, 999999) };
  });
  return { id, target: nameCode, team: [...target.team], cubes,
    data: { characters, character_details: details,
      state_effects: [...effects.values()].sort((a, b) => a.id - b.id),
      outpost_info: { recycle_room_researches: researches } } };
}
function requestBody(nameCode, items) {
  return { duration: POLICY.duration, level: POLICY.level, weakness: resolveTarget(nameCode).weakness,
    boss: POLICY.boss, burst: POLICY.burst, items };
}
function inputHash(item, profileKey) { const { id, ...input } = item; return digest({ policy: POLICY_HASH,
  profile: resolveTarget(profileKey ?? item.target).key, input }); }
function compareScore(distribution, damage, version, now = Date.now()) {
  const valid = distribution?.policyHash === POLICY_HASH && distribution?.calcVersion === version
    && now - distribution.generatedAtMs < 24 * 60 * 60 * 1000;
  const values = valid && Array.isArray(distribution.damages) ? distribution.damages : [];
  const greater = values.filter(v => v > damage).length;
  const equal = values.filter(v => v === damage).length;
  return { sampleCount: values.length,
    topPercent: values.length >= 20 ? (greater + equal * 0.5) / values.length * 100 : null,
    generatedAt: valid ? new Date(distribution.generatedAtMs).toISOString() : null };
}
module.exports = { TARGETS, resolveTarget, POLICY_HASH, ScoreError, buildScoreItem, requestBody, inputHash, compareScore };
