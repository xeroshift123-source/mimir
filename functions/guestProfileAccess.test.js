'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { hashGuestAccessToken } = require('./guestProfileAccess');

test('게스트 토큰은 원문을 노출하지 않는 고정 길이 해시로 저장한다', () => {
  const first = hashGuestAccessToken('guest-token-one');
  const second = hashGuestAccessToken('guest-token-two');

  assert.match(first, /^[a-f0-9]{64}$/);
  assert.notEqual(first, second);
  assert.equal(first, hashGuestAccessToken('guest-token-one'));
});
