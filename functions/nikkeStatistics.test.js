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

test('서버별 최신 계정을 표본으로 옵션과 스킬 프리셋을 집계한다', () => {
  const commanders = [
    commander('한국', { skill1: 10, skill2: 10, burst: 10 }, [7000801, 7000802, 7000501]),
    commander('한국', { skill1: 7, skill2: 10, burst: 7 }, [7000815]),
    commander('일본', { skill1: 1, skill2: 1, burst: 1 }, [7000715]),
  ];

  const result = aggregateNikkeStatistics(commanders, 1001, {
    server: '한국',
    minimumSample: 2,
  });

  assert.equal(result.sampleCount, 2);
  assert.equal(result.isSufficient, true);
  assert.equal(result.overload[0].name, '공격력');
  assert.equal(result.overload[0].averageLineCount, 1.5);
  assert.equal(result.overload[0].adoptionRate, 100);
  assert.equal(result.overload[0].averageTotalPercent, 12.44);
  assert.deepEqual(result.skillPresets.map(item => item.preset), ['10/10/10', '7/10/7']);
  assert.deepEqual(result.skillPresets.map(item => item.ratio), [50, 50]);
});

test('내 옵션 합계를 동률 보정 백분위로 비교한다', () => {
  const first = commander('한국', { skill1: 10, skill2: 10, burst: 10 }, [7000801, 7000802]);
  const second = commander('한국', { skill1: 7, skill2: 10, burst: 7 }, [7000815]);
  const aggregate = aggregateNikkeStatistics([first, second], 1001, { server: '한국' });
  const compared = attachUserComparison(aggregate, first.characters[0]);

  assert.equal(compared.overload[0].myTotalPercent, 10.24);
  assert.equal(compared.overload[0].topPercent, 75);
  assert.equal(percentileFromHistogram({ '10.00': 2, '20.00': 1 }, 10), 66.7);
});

test('예약 집계는 서버와 니케별 통계 스냅샷을 만든다', () => {
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
      statisticsCacheKey('한국', 1001),
      statisticsCacheKey('한국', 1002),
      statisticsCacheKey('일본', 1001),
    ].sort(),
  );
  assert.equal(snapshots.find(item => item.id === statisticsCacheKey('한국', 1001)).data.sampleCount, 1);
});
