'use strict';

// Check the raw response BEFORE the legacy UI mapper supplies default values.
function growthDataQuality(character, detail) {
  const missingFields = [];
  const check = (object, key) => {
    if (!Number.isInteger(object?.[key]) || object[key] < 0) missingFields.push(key);
  };
  for (const key of ['name_code', 'grade', 'core']) check(character, key);
  for (const key of ['skill1_lv', 'skill2_lv', 'ulti_skill_lv', 'attractive_lv',
    'favorite_item_tid', 'harmony_cube_tid']) check(detail, key);
  for (const key of ['skill1_lv', 'skill2_lv', 'ulti_skill_lv']) {
    if (detail?.[key] === 0) missingFields.push(key); // Legacy mapper turns 0 into 1.
  }
  if (detail?.favorite_item_tid) check(detail, 'favorite_item_lv');
  if (detail?.harmony_cube_tid) check(detail, 'harmony_cube_lv');
  for (const slot of ['head', 'torso', 'arm', 'leg']) {
    const tidKey = `${slot}_equip_tid`;
    check(detail, tidKey);
    if (!detail?.[tidKey]) continue; // Explicit 0 is a known empty slot.
    check(detail, `${slot}_equip_lv`);
    const tier = Math.trunc(detail[tidKey] / 100) % 100;
    if (tier < 10) check(detail, `${slot}_equip_corporation_type`);
    if (tier >= 10) {
      for (let i = 1; i <= 3; i++) check(detail, `${slot}_equip_option${i}_id`);
    }
  }
  return { schemaVersion: 1, complete: missingFields.length === 0, missingFields };
}

module.exports = { growthDataQuality };
