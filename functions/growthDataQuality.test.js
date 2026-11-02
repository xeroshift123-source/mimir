'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { growthDataQuality } = require('./growthDataQuality');

function completeEmpty() {
  return { skill1_lv: 10, skill2_lv: 10, ulti_skill_lv: 10, attractive_lv: 30,
    favorite_item_tid: 0, harmony_cube_tid: 0, head_equip_tid: 0,
    torso_equip_tid: 0, arm_equip_tid: 0, leg_equip_tid: 0 };
}
const character = { name_code: 5129, grade: 3, core: 0 };
test('explicit empty items are known, missing details require resync', () => {
  assert.equal(growthDataQuality(character, completeEmpty()).complete, true);
  const missing = growthDataQuality(character, {});
  assert.equal(missing.complete, false);
  assert(missing.missingFields.includes('skill1_lv'));
  assert(missing.missingFields.includes('head_equip_tid'));
});
test('all three overload fields must be captured, including explicit zero', () => {
  const detail = { ...completeEmpty(), head_equip_tid: 3111001, head_equip_lv: 5,
    head_equip_option1_id: 7000510, head_equip_option2_id: 0, head_equip_option3_id: 0 };
  assert.equal(growthDataQuality(character, detail).complete, true);
  delete detail.head_equip_option3_id;
  assert.equal(growthDataQuality(character, detail).complete, false);
});
test('an equipped cube without its level is unknown', () => {
  assert.equal(growthDataQuality(character, { ...completeEmpty(), harmony_cube_tid: 1000303 }).complete, false);
});

test('invalid zero skill is not made valid by the legacy default mapper', () => {
  const quality = growthDataQuality(character, { ...completeEmpty(), skill1_lv: 0 });
  assert.equal(quality.complete, false);
  assert(quality.missingFields.includes('skill1_lv'));
});
