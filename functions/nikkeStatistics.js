'use strict';

const OPTION_DEFINITIONS = [
  { min: 7000501, max: 7000515, key: 'elementDamage', name: '우월코드 대미지', values: [9.54, 10.94, 12.34, 13.75, 15.15, 16.55, 17.95, 19.35, 20.75, 22.15, 23.56, 24.96, 26.36, 27.76, 29.16] },
  { min: 7000601, max: 7000615, key: 'hitRate', name: '명중률', values: [4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63] },
  { min: 7000701, max: 7000715, key: 'maxAmmo', name: '최대 장탄 수', values: [27.84, 31.95, 36.06, 40.17, 44.28, 48.39, 52.50, 56.60, 60.71, 64.82, 68.93, 73.04, 77.15, 81.26, 85.37] },
  { min: 7000801, max: 7000815, key: 'attack', name: '공격력', values: [4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63] },
  { min: 7000901, max: 7000915, key: 'chargeDamage', name: '차지 대미지', values: [4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63] },
  { min: 7001001, max: 7001015, key: 'chargeSpeed', name: '차지 속도', values: [1.98, 2.28, 2.57, 2.86, 3.16, 3.45, 3.75, 4.04, 4.33, 4.63, 4.92, 5.21, 5.51, 5.80, 6.09] },
  { min: 7001101, max: 7001115, key: 'criticalRate', name: '크리티컬 확률', values: [2.30, 2.64, 2.98, 3.32, 3.66, 4.00, 4.35, 4.69, 5.03, 5.37, 5.70, 6.05, 6.39, 6.73, 7.07] },
  { min: 7001201, max: 7001215, key: 'criticalDamage', name: '크리티컬 대미지', values: [6.64, 7.62, 8.60, 9.58, 10.56, 11.54, 12.52, 13.50, 14.48, 15.46, 16.44, 17.42, 18.40, 19.38, 20.36] },
  { min: 7001301, max: 7001315, key: 'defense', name: '방어력', values: [4.77, 5.47, 6.18, 6.88, 7.59, 8.29, 9.00, 9.70, 10.40, 11.11, 11.81, 12.52, 13.22, 13.93, 14.63] },
];

function optionDefinition(optionId) {
  return OPTION_DEFINITIONS.find(({ min, max }) => optionId >= min && optionId <= max) || null;
}

function optionValue(optionId) {
  const definition = optionDefinition(optionId);
  if (!definition) return 0;
  return definition.values[optionId - definition.min] || 0;
}

function characterOptionTotals(character) {
  const totals = new Map();
  for (const equipment of Array.isArray(character?.equipment) ? character.equipment : []) {
    for (const rawId of Array.isArray(equipment?.overloadOptions) ? equipment.overloadOptions : []) {
      const optionId = Number(rawId) || 0;
      const definition = optionDefinition(optionId);
      if (!definition) continue;
      const current = totals.get(definition.key) || { key: definition.key, name: definition.name, totalPercent: 0, lineCount: 0 };
      current.totalPercent += optionValue(optionId);
      current.lineCount += 1;
      totals.set(definition.key, current);
    }
  }
  return totals;
}

const EQUIPMENT_PRESET_SLOTS = ['head', 'arm', 'torso', 'leg'];

function equipmentTier(equipment) {
  const explicitTier = Number(equipment?.tier) || 0;
  if (explicitTier > 0) return explicitTier;
  const tid = Number(equipment?.tid) || 0;
  return Math.trunc(tid / 100) % 100;
}

function equipmentPreset(character) {
  const equipmentBySlot = new Map(
    (Array.isArray(character?.equipment) ? character.equipment : [])
      .filter(equipment => equipment?.slot)
      .map(equipment => [equipment.slot, equipment]),
  );

  return EQUIPMENT_PRESET_SLOTS.map(slot => {
    const equipment = equipmentBySlot.get(slot);
    if (!equipment) return 'X';
    const tier = equipmentTier(equipment);
    const corporationType = Number(equipment.corporationType) || 0;
    const isOverload = tier >= 10;
    const isManufacturerT9 = tier === 9 && corporationType > 0;
    return isOverload || isManufacturerT9
      ? String(Math.max(0, Number(equipment.level) || 0))
      : 'X';
  }).join('/');
}

function percentileFromHistogram(histogram, value) {
  const entries = Object.entries(histogram || {}).map(([rawValue, count]) => ({ value: Number(rawValue), count: Number(count) || 0 }));
  const total = entries.reduce((sum, item) => sum + item.count, 0);
  if (total === 0) return null;
  const greater = entries.filter(item => item.value > value).reduce((sum, item) => sum + item.count, 0);
  const equal = entries.filter(item => Math.abs(item.value - value) < 0.005).reduce((sum, item) => sum + item.count, 0);
  return Number((((greater + equal * 0.5) / total) * 100).toFixed(1));
}

function aggregateNikkeStatistics(commanders, nameCode, { minimumSample = 20 } = {}) {
  const optionBuckets = new Map();
  const skillCounts = new Map();
  const equipmentCounts = new Map();
  let sampleCount = 0;

  for (const commander of commanders) {
    if (!commander) continue;
    const character = (Array.isArray(commander.characters) ? commander.characters : [])
      .find(item => Number(item?.name_code) === Number(nameCode));
    if (!character) continue;
    sampleCount += 1;

    const skills = character.skills || {};
    const preset = `${Number(skills.skill1) || 1}/${Number(skills.skill2) || 1}/${Number(skills.burst) || 1}`;
    skillCounts.set(preset, (skillCounts.get(preset) || 0) + 1);
    const gearPreset = equipmentPreset(character);
    equipmentCounts.set(gearPreset, (equipmentCounts.get(gearPreset) || 0) + 1);

    for (const option of characterOptionTotals(character).values()) {
      const bucket = optionBuckets.get(option.key) || {
        key: option.key,
        name: option.name,
        userCount: 0,
        totalPercent: 0,
        totalLines: 0,
        histogram: {},
      };
      const roundedTotal = Number(option.totalPercent.toFixed(2));
      const histogramKey = roundedTotal.toFixed(2);
      bucket.userCount += 1;
      bucket.totalPercent += roundedTotal;
      bucket.totalLines += option.lineCount;
      bucket.histogram[histogramKey] = (bucket.histogram[histogramKey] || 0) + 1;
      optionBuckets.set(option.key, bucket);
    }
  }

  const overload = [...optionBuckets.values()]
    .map(bucket => {
      const histogram = { ...bucket.histogram };
      const nonAdopterCount = sampleCount - bucket.userCount;
      if (nonAdopterCount > 0) {
        histogram['0.00'] = (histogram['0.00'] || 0) + nonAdopterCount;
      }
      return {
        key: bucket.key,
        name: bucket.name,
        userCount: bucket.userCount,
        adoptionRate: sampleCount === 0 ? 0 : Number((bucket.userCount / sampleCount * 100).toFixed(1)),
        averageTotalPercent: sampleCount === 0 ? 0 : Number((bucket.totalPercent / sampleCount).toFixed(2)),
        averageLineCount: sampleCount === 0 ? 0 : Number((bucket.totalLines / sampleCount).toFixed(2)),
        adopterAverageTotalPercent: Number((bucket.totalPercent / bucket.userCount).toFixed(2)),
        adopterAverageLineCount: Number((bucket.totalLines / bucket.userCount).toFixed(2)),
        histogram,
      };
    })
    .sort((a, b) =>
      b.averageLineCount - a.averageLineCount
      || b.userCount - a.userCount
      || b.averageTotalPercent - a.averageTotalPercent)
    .slice(0, 5);

  const skillPresets = [...skillCounts.entries()]
    .map(([preset, count]) => ({ preset, count, ratio: sampleCount === 0 ? 0 : Number((count / sampleCount * 100).toFixed(1)) }))
    .sort((a, b) => b.count - a.count || a.preset.localeCompare(b.preset))
    .slice(0, 4);

  const equipmentPresets = [...equipmentCounts.entries()]
    .map(([preset, count]) => ({ preset, count, ratio: sampleCount === 0 ? 0 : Number((count / sampleCount * 100).toFixed(1)) }))
    .sort((a, b) => b.count - a.count || a.preset.localeCompare(b.preset))
    .slice(0, 4);

  return {
    schemaVersion: 7,
    nameCode: Number(nameCode),
    server: '전체',
    sampleCount,
    minimumSample,
    isSufficient: sampleCount >= minimumSample,
    overload,
    skillPresets,
    equipmentPresets,
  };
}

function attachUserComparison(statistics, character) {
  const mine = characterOptionTotals(character);
  const skills = character?.skills || {};
  const mySkillPreset = `${Number(skills.skill1) || 1}/${Number(skills.skill2) || 1}/${Number(skills.burst) || 1}`;
  return {
    ...statistics,
    mySkillPreset,
    myEquipmentPreset: equipmentPreset(character),
    overload: statistics.overload.map(option => {
      const myOption = mine.get(option.key);
      if (!myOption) return { ...option, myTotalPercent: null, myLineCount: 0, topPercent: null };
      const myTotalPercent = Number(myOption.totalPercent.toFixed(2));
      return {
        ...option,
        myTotalPercent,
        myLineCount: myOption.lineCount,
        topPercent: percentileFromHistogram(option.histogram, myTotalPercent),
      };
    }),
  };
}

module.exports = {
  aggregateNikkeStatistics,
  attachUserComparison,
  characterOptionTotals,
  equipmentPreset,
  equipmentTier,
  percentileFromHistogram,
};
