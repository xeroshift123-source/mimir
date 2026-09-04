const admin = require('firebase-admin');

const STATIC_LEVEL_BADGES = [
  ['level_400', 400],
  ['level_500', 500],
  ['level_600', 600],
  ['level_700', 700],
  ['level_808', 808],
  ['level_911', 911],
  ['level_1000', 1000],
];

const COUNTERS_NAME_CODES = [5129, 5169, 5170];

function asNumber(value) {
  const converted = Number(value);
  return Number.isFinite(converted) ? converted : 0;
}

function asDate(value) {
  if (value instanceof Date) return value;
  if (value && typeof value.toDate === 'function') return value.toDate();

  if (typeof value === 'number') {
    const digits = Math.trunc(value).toString();
    if (/^\d{8}$/.test(digits)) {
      return new Date(Date.UTC(
        Number(digits.slice(0, 4)),
        Number(digits.slice(4, 6)) - 1,
        Number(digits.slice(6, 8)),
      ));
    }
    return new Date(value < 100000000000 ? value * 1000 : value);
  }

  if (typeof value !== 'string' || !value.trim()) return null;
  const raw = value.trim();
  if (/^\d+$/.test(raw)) return asDate(Number(raw));
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function ageInDays(value, now) {
  const joinedAt = asDate(value);
  if (!joinedAt) return 0;
  const joinedDay = Date.UTC(
    joinedAt.getUTCFullYear(),
    joinedAt.getUTCMonth(),
    joinedAt.getUTCDate(),
  );
  const currentDay = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
  );
  return Math.max(0, Math.floor((currentDay - joinedDay) / 86400000));
}

function equipmentFor(character) {
  return Array.isArray(character?.equipment) ? character.equipment : [];
}

function isOverloaded(equipment) {
  if (asNumber(equipment?.tier) >= 10) return true;
  return Array.isArray(equipment?.overloadOptions)
    && equipment.overloadOptions.some(option => asNumber(option) !== 0);
}

function countMasterpieceShoes(profile) {
  const characters = Array.isArray(profile?.characters) ? profile.characters : [];
  return characters.reduce((count, character) => count + equipmentFor(character)
    .filter(equipment => equipment?.slot?.toString() === 'leg'
      && isOverloaded(equipment)
      && asNumber(equipment.level) === 5)
    .length, 0);
}

function highestNikkeLevel(profile) {
  const characters = Array.isArray(profile?.characters) ? profile.characters : [];
  return Math.max(
    asNumber(profile?.synchroLevel),
    ...characters.map(character => asNumber(character?.level)),
  );
}

function recycleRoomLevel(profile, tid) {
  const researches = Array.isArray(profile?.recycleRoom) ? profile.recycleRoom : [];
  const research = researches.find(item => Math.trunc(asNumber(item?.tid)) === tid);
  return research ? Math.trunc(asNumber(research.lv)) : null;
}

function hasExtremeFirepower(profile) {
  const attackerLevel = recycleRoomLevel(profile, 1101);
  const defenderLevel = recycleRoomLevel(profile, 1102);
  return attackerLevel != null
    && defenderLevel != null
    && attackerLevel - defenderLevel >= 10;
}

function hasMaxBondCounters(profile) {
  const characters = Array.isArray(profile?.characters) ? profile.characters : [];
  const maxBondNameCodes = new Set(characters
    .filter(character => asNumber(character?.bondLevel) >= 40)
    .map(character => Math.trunc(asNumber(character?.name_code))));
  return COUNTERS_NAME_CODES.every(nameCode => maxBondNameCodes.has(nameCode));
}

function ultimateNameCode(character) {
  if (asNumber(character?.core) !== 7) return null;
  const skills = character?.skills || {};
  if (['skill1', 'skill2', 'burst'].some(key => asNumber(skills[key]) !== 10)) {
    return null;
  }

  const requiredSlots = ['head', 'torso', 'arm', 'leg'];
  const bySlot = new Map();
  for (const equipment of equipmentFor(character)) {
    const slot = equipment?.slot?.toString();
    if (requiredSlots.includes(slot)) bySlot.set(slot, equipment);
  }
  if (requiredSlots.some(slot => {
    const equipment = bySlot.get(slot);
    return !equipment || !isOverloaded(equipment) || asNumber(equipment.level) !== 5;
  })) {
    return null;
  }

  const optionLevels = [...bySlot.values()]
    .flatMap(equipment => Array.isArray(equipment.overloadOptions)
      ? equipment.overloadOptions
      : [])
    .map(option => Math.trunc(asNumber(option)))
    .filter(option => option !== 0)
    .map(option => option % 100)
    .filter(level => level >= 1 && level <= 15);
  if (optionLevels.length < 11) return null;
  const average = optionLevels.reduce((sum, level) => sum + level, 0)
    / optionLevels.length;
  if (average < 11) return null;

  const nameCode = Math.trunc(asNumber(character?.name_code));
  return nameCode > 0 ? nameCode : null;
}

function evaluateProfiles(profileEntries, now = new Date()) {
  const earned = new Map();
  const earn = (id, openId, extra = {}) => {
    if (!earned.has(id)) earned.set(id, { sourceOpenId: openId, ...extra });
  };

  for (const { openId, profile } of profileEntries) {
    const joinedAt = profile?.joinedAt ?? profile?.createdAt ?? profile?.created_at;
    if (ageInDays(joinedAt, now) >= 1000) earn('thousand_days', openId);
    if (asNumber(profile?.costumeCount) >= 100) earn('fashionista', openId);
    if (hasMaxBondCounters(profile)) earn('counters', openId);
    if (hasExtremeFirepower(profile)) earn('extreme_firepower', openId);
    if (countMasterpieceShoes(profile) >= 20) earn('shoes_20', openId);

    const highestLevel = highestNikkeLevel(profile);
    for (const [id, threshold] of STATIC_LEVEL_BADGES) {
      if (highestLevel >= threshold) earn(id, openId);
    }

    const characters = Array.isArray(profile?.characters) ? profile.characters : [];
    for (const character of characters) {
      const nameCode = ultimateNameCode(character);
      if (nameCode != null) {
        earn(`ultimate_${nameCode}`, openId, { nameCode });
      }
    }
  }
  return earned;
}

function corsHeaders(req, res) {
  res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function serializeState(data) {
  const unlockMap = data.badgeUnlocks && typeof data.badgeUnlocks === 'object'
    ? data.badgeUnlocks
    : {};
  const unlocks = Object.entries(unlockMap).map(([id, unlock]) => ({
    id,
    acquiredAt: unlock?.acquiredAt?.toDate?.().toISOString()
      || unlock?.acquiredAt
      || new Date().toISOString(),
    ...(unlock?.nameCode ? { nameCode: unlock.nameCode } : {}),
  }));
  const unlockedIds = new Set(unlocks.map(unlock => unlock.id));
  const displayedBadgeIds = Array.isArray(data.displayedBadgeIds)
    ? data.displayedBadgeIds.filter(id => unlockedIds.has(id)).slice(0, 4)
    : [];
  return { unlocks, displayedBadgeIds };
}

function createEvaluateAchievementBadgesHandler({ db, getAuthenticatedUid }) {
  return async (req, res) => {
    corsHeaders(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    }

    try {
      const uid = await getAuthenticatedUid(req);
      if (!uid) return res.status(401).json({ success: false, error: '로그인이 필요합니다.' });

      const userRef = db.collection('users').doc(uid);
      const userSnapshot = await userRef.get();
      const userData = userSnapshot.data() || {};
      const linkedOpenIds = Array.isArray(userData.linkedOpenIds)
        ? userData.linkedOpenIds.filter(value => typeof value === 'string' && value.trim())
        : [];
      if (userData.openId && !linkedOpenIds.includes(userData.openId)) {
        linkedOpenIds.push(userData.openId);
      }

      const snapshots = linkedOpenIds.length
        ? await db.getAll(...linkedOpenIds.map(openId => db.collection('commanders').doc(openId)))
        : [];
      const profileEntries = snapshots
        .filter(snapshot => snapshot.exists)
        .map(snapshot => ({ openId: snapshot.id, profile: snapshot.data() }));
      const earned = evaluateProfiles(profileEntries);
      const now = admin.firestore.Timestamp.now();

      await db.runTransaction(async transaction => {
        const freshSnapshot = await transaction.get(userRef);
        const freshData = freshSnapshot.data() || {};
        const unlocks = freshData.badgeUnlocks && typeof freshData.badgeUnlocks === 'object'
          ? { ...freshData.badgeUnlocks }
          : {};
        let changed = false;
        for (const [id, evidence] of earned) {
          if (unlocks[id]) continue;
          unlocks[id] = {
            acquiredAt: now,
            sourceOpenId: evidence.sourceOpenId,
            ...(evidence.nameCode ? { nameCode: evidence.nameCode } : {}),
          };
          changed = true;
        }
        if (changed) {
          transaction.set(userRef, {
            badgeUnlocks: unlocks,
            badgesUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      });

      const updatedSnapshot = await userRef.get();
      return res.status(200).json({
        success: true,
        ...serializeState(updatedSnapshot.data() || {}),
      });
    } catch (error) {
      console.error('evaluateAchievementBadges failed:', error);
      return res.status(500).json({ success: false, error: '뱃지 정보를 불러오지 못했습니다.' });
    }
  };
}

function createUpdateDisplayedBadgesHandler({ db, getAuthenticatedUid }) {
  return async (req, res) => {
    corsHeaders(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    }

    try {
      const uid = await getAuthenticatedUid(req);
      if (!uid) return res.status(401).json({ success: false, error: '로그인이 필요합니다.' });
      const rawIds = Array.isArray(req.body?.badgeIds) ? req.body.badgeIds : [];
      const badgeIds = [...new Set(rawIds
        .filter(id => typeof id === 'string')
        .map(id => id.trim())
        .filter(Boolean))];
      if (badgeIds.length > 4) {
        return res.status(400).json({ success: false, error: '뱃지는 최대 4개까지 전시할 수 있습니다.' });
      }

      const userRef = db.collection('users').doc(uid);
      await db.runTransaction(async transaction => {
        const snapshot = await transaction.get(userRef);
        const data = snapshot.data() || {};
        const unlocks = data.badgeUnlocks && typeof data.badgeUnlocks === 'object'
          ? data.badgeUnlocks
          : {};
        if (badgeIds.some(id => !unlocks[id])) {
          const error = new Error('획득한 뱃지만 전시할 수 있습니다.');
          error.code = 'BADGE_LOCKED';
          throw error;
        }
        transaction.set(userRef, {
          displayedBadgeIds: badgeIds,
          badgesUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      });
      return res.status(200).json({ success: true, displayedBadgeIds: badgeIds });
    } catch (error) {
      if (error.code === 'BADGE_LOCKED') {
        return res.status(403).json({ success: false, error: error.message });
      }
      console.error('updateDisplayedBadges failed:', error);
      return res.status(500).json({ success: false, error: '전시 뱃지를 저장하지 못했습니다.' });
    }
  };
}

function createGetPublicBadgeShowcaseHandler({ db }) {
  return async (req, res) => {
    corsHeaders(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') {
      return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    }

    try {
      const uid = typeof req.body?.uid === 'string' ? req.body.uid.trim() : '';
      if (!uid || uid.length > 128) {
        return res.status(400).json({ success: false, error: '작성자 정보가 올바르지 않습니다.' });
      }

      const snapshot = await db.collection('users').doc(uid).get();
      if (!snapshot.exists) {
        return res.status(404).json({ success: false, error: '작성자 정보를 찾을 수 없습니다.' });
      }

      const state = serializeState(snapshot.data() || {});
      const displayedIds = new Set(state.displayedBadgeIds);
      return res.status(200).json({
        success: true,
        displayedBadgeIds: state.displayedBadgeIds,
        unlocks: state.unlocks.filter(unlock => displayedIds.has(unlock.id)),
      });
    } catch (error) {
      console.error('getPublicBadgeShowcase failed:', error);
      return res.status(500).json({ success: false, error: '전시 뱃지를 불러오지 못했습니다.' });
    }
  };
}

module.exports = {
  evaluateProfiles,
  createEvaluateAchievementBadgesHandler,
  createUpdateDisplayedBadgesHandler,
  createGetPublicBadgeShowcaseHandler,
};
