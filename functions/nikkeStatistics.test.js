'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  aggregateAccountElementDamageStatistics,
  aggregateNikkeStatistics,
  attachAccountElementDamageComparison,
  attachUserComparison,
  equipmentPreset,
  percentileFromHistogram,
} = require('./nikkeStatistics');
const {
  ACCOUNT_ELEMENT_DAMAGE_CACHE_ID,
  buildStatisticsSnapshots,
  buildStatisticsSnapshotsFromStore,
  statisticsCacheKey,
} = require('./nikkeStatisticsStore');

function commander(server, skills, options) {
  return {
    server,
    characters: [{
      name_code: 1001,
      skills,
      equipment: [{ overloadOptions: options }],
    }],
  };
}

test('모든 서버의 최신 계정을 하나의 표본으로 집계한다', () => {
  const commanders = [
    commander('한국', { skill1: 10, skill2: 10, burst: 10 }, [7000801, 7000802, 7000501]),
    commander('한국', { skill1: 7, skill2: 10, burst: 7 }, [7000815]),
    commander('일본', { skill1: 1, skill2: 1, burst: 1 }, [7000715]),
  ];

  const result = aggregateNikkeStatistics(commanders, 1001, { minimumSample: 2 });

  assert.equal(result.server, '전체');
  assert.equal(result.sampleCount, 3);
  assert.equal(result.isSufficient, true);
  assert.equal(result.overload[0].name, '공격력');
  assert.equal(result.overload[0].averageLineCount, 1);
  assert.equal(result.overload[0].adoptionRate, 66.7);
  assert.equal(result.overload[0].averageTotalPercent, 8.29);
  assert.equal(result.combinedOffense.averageTotalPercent, 11.47);
  assert.deepEqual(result.combinedOffense.histogram, {
    '19.78': 1,
    '14.63': 1,
    '0.00': 1,
  });
  assert.deepEqual(new Set(result.skillPresets.map(item => item.preset)), new Set(['10/10/10', '7/10/7', '1/1/1']));
  assert.deepEqual(result.skillPresets.map(item => item.ratio), [33.3, 33.3, 33.3]);
});

test('내 옵션 합계를 동률 보정 백분위로 비교한다', () => {
  const first = commander('한국', { skill1: 10, skill2: 10, burst: 10 }, [7000801, 7000802]);
  const second = commander('한국', { skill1: 7, skill2: 10, burst: 7 }, [7000815]);
  const aggregate = aggregateNikkeStatistics([first, second], 1001);
  const compared = attachUserComparison(aggregate, first.characters[0]);

  assert.equal(compared.overload[0].myTotalPercent, 10.24);
  assert.equal(compared.overload[0].topPercent, 75);
  assert.equal(compared.combinedOffense.myTotalPercent, 10.24);
  assert.equal(compared.combinedOffense.topPercent, 75);
  assert.equal(compared.mySkillPreset, '10/10/10');
  assert.equal(percentileFromHistogram({ '10.00': 2, '20.00': 1 }, 10), 66.7);
});

test('이전 스키마 캐시는 우공 통계 없이도 기존 비교 결과를 반환한다', () => {
  const profile = commander('한국', { skill1: 10, skill2: 10, burst: 10 }, [7000801]);
  const legacyStatistics = aggregateNikkeStatistics([profile], 1001);
  delete legacyStatistics.combinedOffense;

  const compared = attachUserComparison(legacyStatistics, profile.characters[0]);

  assert.equal(compared.combinedOffense, null);
  assert.equal(compared.overload[0].myTotalPercent, 4.77);
});

test('예약 집계는 모든 서버를 통합한 니케별 스냅샷을 만든다', () => {
  const commanders = [
    commander('한국', { skill1: 10, skill2: 10, burst: 10 }, [7000801]),
    commander('일본', { skill1: 7, skill2: 7, burst: 7 }, [7000501]),
  ];
  commanders[0].characters.push({
    name_code: 1002,
    skills: { skill1: 1, skill2: 1, burst: 1 },
    equipment: [],
  });

  const snapshots = buildStatisticsSnapshots(commanders);

  assert.deepEqual(
    snapshots.map(snapshot => snapshot.id).sort(),
    [
      'account_element_adjusted',
      ACCOUNT_ELEMENT_DAMAGE_CACHE_ID,
      statisticsCacheKey(1001),
      statisticsCacheKey(1002),
    ].sort(),
  );
  assert.equal(snapshots.find(item => item.id === statisticsCacheKey(1001)).data.sampleCount, 2);
});

test('계정 전체 니케의 우월코드를 속성별로 합산하고 백분위를 계산한다', () => {
  const first = {
    characters: [
      {
        name_code: 5129,
        equipment: [{ overloadOptions: [7000515] }],
      },
      {
        name_code: 5002,
        equipment: [{ overloadOptions: [7000502] }],
      },
    ],
  };
  const second = {
    characters: [{
      name_code: 5129,
      equipment: [{ overloadOptions: [7000501] }],
    }],
  };

  const aggregate = aggregateAccountElementDamageStatistics([first, second]);
  const compared = attachAccountElementDamageComparison(aggregate, first);
  const byKey = Object.fromEntries(
    compared.elements.map(element => [element.key, element]),
  );

  assert.equal(compared.sampleCount, 2);
  assert.equal(byKey.Fire.averageTotalPercent, 19.35);
  assert.equal(byKey.Fire.myTotalPercent, 29.16);
  assert.equal(byKey.Fire.topPercent, 25);
  assert.equal(byKey.Iron.averageTotalPercent, 24.82);
  assert.equal(byKey.Iron.myTotalPercent, 40.1);
  assert.equal(byKey.Iron.topPercent, 25);
  assert.equal(byKey.Water.averageTotalPercent, 5.47);
  assert.equal(byKey.Water.myTotalPercent, 10.94);
  assert.equal(byKey.Water.topPercent, 25);
  assert.equal(byKey.Wind.myTotalPercent, 0);
  assert.equal(byKey.Electric.topPercent, 50);
});

test('서버용 속성 맵은 니케 데이터와 이중 속성을 반영한다', () => {
  const nikkes = require('../assets/nikkes.json');
  const elementMap = require('./nikkeElements.json');

  for (const nikke of nikkes) {
    assert.ok(
      elementMap[String(nikke.blablaNameCode)]?.includes(nikke.element),
      `${nikke.id}의 기본 속성이 서버 맵에 없습니다.`,
    );
  }
  assert.deepEqual(elementMap['5129'], ['Fire', 'Iron']);
  assert.deepEqual(elementMap['5002'], ['Iron', 'Water']);
});

test('희귀 옵션의 평균과 백분위는 미채택자를 0으로 포함한다', () => {
  const commanders = Array.from({ length: 100 }, (_, index) =>
    commander(
      '한국',
      { skill1: 10, skill2: 10, burst: 10 },
      index === 0 ? [7001301, 7001302, 7001303, 7001304] : [],
    ));

  const aggregate = aggregateNikkeStatistics(commanders, 1001);
  const defense = aggregate.overload.find(option => option.key === 'defense');
  const compared = attachUserComparison(aggregate, commanders[0].characters[0]);
  const myDefense = compared.overload.find(option => option.key === 'defense');

  assert.equal(defense.adoptionRate, 1);
  assert.equal(defense.averageLineCount, 0.04);
  assert.equal(defense.adopterAverageLineCount, 4);
  assert.equal(defense.averageTotalPercent, 0.23);
  assert.equal(defense.adopterAverageTotalPercent, 23.3);
  assert.equal(defense.histogram['0.00'], 99);
  assert.equal(myDefense.topPercent, 0.5);
});

test('장비 강화 프리셋은 머리/장갑/상의/다리 순서로 유효한 장비만 집계한다', () => {
  const character = {
    equipment: [
      { slot: 'torso', tier: 9, corporationType: 0, level: 4 },
      { slot: 'leg', tier: 8, corporationType: 2, level: 3 },
      { slot: 'head', tid: 3111001, corporationType: 0, level: 5 },
      { slot: 'arm', tid: 3310901, corporationType: 3, level: 2 },
    ],
  };

  assert.equal(equipmentPreset(character), '5/2/X/X');

  const first = commander('한국', { skill1: 10, skill2: 10, burst: 10 }, []);
  first.characters[0].equipment = character.equipment;
  const second = commander('일본', { skill1: 10, skill2: 10, burst: 10 }, []);
  second.characters[0].equipment = character.equipment;
  const aggregate = aggregateNikkeStatistics([first, second], 1001);
  const compared = attachUserComparison(aggregate, first.characters[0]);

  assert.equal(aggregate.equipmentPresets[0].preset, '5/2/X/X');
  assert.equal(aggregate.equipmentPresets[0].ratio, 100);
  assert.equal(compared.myEquipmentPreset, '5/2/X/X');
});

test('예약 집계는 지휘관 문서를 작은 페이지로 읽고 필요한 필드만 요청한다', async () => {
  const nowMs = Date.parse('2026-08-28T00:00:00+09:00');
  const bindings = Array.from({ length: 130 }, (_, index) => ({
    id: `open-${String(index).padStart(2, '0')}`,
    data: () => ({ uid: `uid-${index}` }),
  }));
  const commanders = new Map(bindings.map((binding, index) => [
    binding.id,
    {
      lastUpdatedAt: { toMillis: () => nowMs },
      ...commander('한국', { skill1: 10, skill2: 10, burst: 10 }, index === 0 ? [7000801] : []),
    },
  ]));
  const getAllCalls = [];

  function bindingQuery() {
    let limit = 25;
    let cursor = null;
    return {
      orderBy() { return this; },
      limit(value) { limit = value; return this; },
      select() { return this; },
      startAfter(doc) { cursor = doc; return this; },
      async get() {
        const start = cursor ? bindings.findIndex(binding => binding.id === cursor.id) + 1 : 0;
        const docs = bindings.slice(start, start + limit);
        return { docs, empty: docs.length === 0, size: docs.length };
      },
    };
  }

  const db = {
    collection(name) {
      if (name === 'open_id_bindings') return bindingQuery();
      if (name === 'commanders') return { doc: id => ({ id }) };
      throw new Error(`Unexpected collection: ${name}`);
    },
    async getAll(...args) {
      const options = args.pop();
      getAllCalls.push({ refs: args, options });
      return args.map(ref => ({ exists: true, data: () => commanders.get(ref.id) }));
    },
  };

  const result = await buildStatisticsSnapshotsFromStore(db, nowMs);

  assert.equal(result.commanderCount, 130);
  assert.equal(result.snapshots[0].data.sampleCount, 130);
  assert.equal(getAllCalls.length, 2);
  assert.deepEqual(getAllCalls.map(call => call.refs.length), [100, 30]);
  assert.deepEqual(getAllCalls[0].options.fieldMask, ['lastUpdatedAt', 'characters']);
});
