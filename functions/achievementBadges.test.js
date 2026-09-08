const assert = require('node:assert/strict');
const { evaluateProfiles } = require('./achievementBadges');

function ultimateCharacter(nameCode, averageLevel = 11) {
  return {
    name_code: nameCode,
    level: 1000,
    core: 7,
    skills: { skill1: 10, skill2: 10, burst: 10 },
    equipment: ['head', 'torso', 'arm', 'leg'].map((slot, index) => ({
      slot,
      tier: 10,
      level: 5,
      overloadOptions: index === 3
        ? [7000500 + averageLevel, 7000500 + averageLevel, 0]
        : [7000500 + averageLevel, 7000500 + averageLevel, 7000500 + averageLevel],
    })),
  };
}

const shoes = Array.from({ length: 20 }, (_, index) => ({
  name_code: index + 1,
  equipment: [{ slot: 'leg', tier: 10, level: 5 }],
}));

const results = evaluateProfiles([
  {
    openId: 'old-account',
    profile: {
      joinedAt: '2020-01-01T00:00:00Z',
      costumeCount: 100,
      synchroLevel: 911,
      characters: shoes,
    },
  },
  {
    openId: 'ultimate-account',
    profile: {
      synchroLevel: 1000,
      characters: [ultimateCharacter(1234)],
    },
  },
], new Date('2026-09-01T00:00:00Z'));

for (const id of [
  'thousand_days',
  'fashionista',
  'shoes_20',
  'level_400',
  'level_500',
  'level_600',
  'level_700',
  'level_808',
  'level_911',
  'level_1000',
  'ultimate_1234',
]) {
  assert.equal(results.has(id), true, `${id} should be earned`);
}

const belowAverage = evaluateProfiles([{
  openId: 'not-ultimate',
  profile: { characters: [ultimateCharacter(9999, 10)] },
}]);
assert.equal(belowAverage.has('ultimate_9999'), false);

const counterCharacters = [5129, 5169, 5170].map(nameCode => ({
  name_code: nameCode,
  bondLevel: 40,
}));
const counters = evaluateProfiles([{
  openId: 'counters-account',
  profile: { characters: counterCharacters },
}]);
assert.equal(counters.has('counters'), true);

const countersBelowBond = evaluateProfiles([{
  openId: 'counters-below-bond',
  profile: {
    characters: counterCharacters.map((character, index) => ({
      ...character,
      bondLevel: index === 2 ? 39 : 40,
    })),
  },
}]);
assert.equal(countersBelowBond.has('counters'), false);

const extremeFirepower = evaluateProfiles([{
  openId: 'extreme-firepower',
  profile: {
    recycleRoom: [
      { tid: 1101, lv: 25 },
      { tid: 1102, lv: 15 },
    ],
  },
}]);
assert.equal(extremeFirepower.has('extreme_firepower'), true);

const insufficientFirepower = evaluateProfiles([{
  openId: 'insufficient-firepower',
  profile: {
    recycleRoom: [
      { tid: 1101, lv: 24 },
      { tid: 1102, lv: 15 },
    ],
  },
}]);
assert.equal(insufficientFirepower.has('extreme_firepower'), false);

const missingDefenderConsole = evaluateProfiles([{
  openId: 'missing-defender-console',
  profile: { recycleRoom: [{ tid: 1101, lv: 99 }] },
}]);
assert.equal(missingDefenderConsole.has('extreme_firepower'), false);

const reliableCompanion = evaluateProfiles([{
  openId: 'reliable-companion',
  profile: {
    characters: [
      { name_code: 1, harmonyCube: { tid: 101, level: 14 } },
      { name_code: 2, harmonyCube: { tid: 102, level: 15 } },
    ],
  },
}]);
assert.equal(reliableCompanion.has('reliable_companion'), true);

const cubeBelowLevel15 = evaluateProfiles([{
  openId: 'cube-below-level-15',
  profile: {
    characters: [{ name_code: 1, harmonyCube: { tid: 101, level: 14 } }],
  },
}]);
assert.equal(cubeBelowLevel15.has('reliable_companion'), false);

const cubeNotEquipped = evaluateProfiles([{
  openId: 'cube-not-equipped',
  profile: { characters: [{ name_code: 1, harmonyCube: null }] },
}]);
assert.equal(cubeNotEquipped.has('reliable_companion'), false);

function overloadedCharacter(nameCode, slots = ['head', 'torso', 'arm', 'leg']) {
  return {
    name_code: nameCode,
    equipment: slots.map(slot => ({ slot, tier: 10, level: 0 })),
  };
}

const noDistinction = evaluateProfiles([{
  openId: 'no-distinction',
  profile: { characters: [overloadedCharacter(3001)] },
}]);
assert.equal(noDistinction.has('no_distinction'), true);

const lowRarityWithThreeOverloads = evaluateProfiles([{
  openId: 'low-rarity-three-overloads',
  profile: {
    characters: [overloadedCharacter(1013, ['head', 'torso', 'arm'])],
  },
}]);
assert.equal(lowRarityWithThreeOverloads.has('no_distinction'), false);

const ssrWithFourOverloads = evaluateProfiles([{
  openId: 'ssr-four-overloads',
  profile: { characters: [overloadedCharacter(5001)] },
}]);
assert.equal(ssrWithFourOverloads.has('no_distinction'), false);

for (const nameCode of [5055, 5056, 5059, 5078]) {
  const unionLeaderTears = evaluateProfiles([{
    openId: `union-leader-tears-${nameCode}`,
    profile: { characters: [{ name_code: nameCode, grade: 3 }] },
  }]);
  assert.equal(unionLeaderTears.has('union_leader_tears'), true);
}

const rehabilitationNikkeBelowLimitBreak = evaluateProfiles([{
  openId: 'rehabilitation-nikke-below-limit-break',
  profile: { characters: [{ name_code: 5055, grade: 2 }] },
}]);
assert.equal(rehabilitationNikkeBelowLimitBreak.has('union_leader_tears'), false);

const unrelatedLimitBrokenNikke = evaluateProfiles([{
  openId: 'unrelated-limit-broken-nikke',
  profile: { characters: [{ name_code: 5001, grade: 3 }] },
}]);
assert.equal(unrelatedLimitBrokenNikke.has('union_leader_tears'), false);

const battleData = evaluateProfiles([], new Date(), { hasSharedDeck: true });
assert.equal(battleData.has('battle_data'), true);

const noBattleData = evaluateProfiles([], new Date(), { hasSharedDeck: false });
assert.equal(noBattleData.has('battle_data'), false);

const elementDamageStatistics = {
  sampleCount: 100,
  elements: [
    { key: 'Fire', histogram: { '10.00': 100 } },
    { key: 'Water', histogram: { '10.00': 100 } },
    { key: 'Wind', histogram: { '10.00': 100 } },
    { key: 'Electric', histogram: { '10.00': 100 } },
    { key: 'Iron', histogram: { '10.00': 100 } },
  ],
};
const firstClass = evaluateProfiles([{
  openId: 'first-class-account',
  profile: {
    characters: [1012, 1018, 1007, 1013, 1010].map(nameCode => ({
      name_code: nameCode,
      equipment: [{ overloadOptions: [7000515] }],
    })),
  },
}], new Date(), { accountElementDamageStatistics: elementDamageStatistics });
for (const id of [
  'first_class_fire',
  'first_class_water',
  'first_class_wind',
  'first_class_electric',
  'first_class_iron',
]) {
  assert.equal(firstClass.has(id), true, `${id} should be earned`);
}

const noElementOptions = evaluateProfiles([{
  openId: 'no-element-options',
  profile: { characters: [{ name_code: 1012, equipment: [] }] },
}], new Date(), { accountElementDamageStatistics: elementDamageStatistics });
assert.equal(noElementOptions.has('first_class_fire'), false);

console.log('achievementBadges tests passed');
