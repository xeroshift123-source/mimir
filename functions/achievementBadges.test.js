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

console.log('achievementBadges tests passed');
