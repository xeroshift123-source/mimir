'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  aggregateNikkeStatistics,
  attachUserComparison,
  percentileFromHistogram,
} = require('./nikkeStatistics');
const { buildStatisticsSnapshots, statisticsCacheKey } = require('./nikkeStatisticsStore');

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
  assert.equal(compared.mySkillPreset, '10/10/10');
  assert.equal(percentileFromHistogram({ '10.00': 2, '20.00': 1 }, 10), 66.7);
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
      statisticsCacheKey(1001),
      statisticsCacheKey(1002),
    ].sort(),
  );
  assert.equal(snapshots.find(item => item.id === statisticsCacheKey(1001)).data.sampleCount, 2);
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
