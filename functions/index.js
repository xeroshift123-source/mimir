const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const axios = require('axios');
const cors = require('cors')({ origin: true });
const { fetchCDNJson } = require('./cdnDecrypt');
const { createNikkeStatisticsHandler } = require('./nikkeStatisticsEndpoint');
const { createDailyNikkeStatisticsHandler } = require('./nikkeStatisticsSchedule');
const { createNikkeStatisticsRefreshHandler } = require('./nikkeStatisticsRefreshEndpoint');
const { issueGuestProfileToken, createGuestCommanderProfileHandler } = require('./guestProfileAccess');

admin.initializeApp();
const db = getFirestore('mimirdb');

// 💡 헬퍼 함수: base64 디코딩
function safeBase64Decode(str) {
    try {
        return Buffer.from(str, 'base64').toString('utf8');
    } catch (e) {
        return str;
    }
}

async function getAuthenticatedUid(req) {
    const authorization = req.headers.authorization || '';
    if (!authorization.startsWith('Bearer ')) return null;
    const decoded = await admin.auth().verifyIdToken(authorization.slice(7));
    return decoded.uid;
}
exports.scrapeNikkeProfile = functions.https.onRequest(async (req, res) => {
    // 💡 100% 무결점 동적 CORS 헤더 주입 및 Credentials 허용 (Flutter Web 연동 끝판왕)
    const origin = req.headers.origin || '*';
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    res.set('Access-Control-Allow-Credentials', 'true');

    // CORS Preflight Options 처리
    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    try {
        if (req.method !== 'POST') {
            return res.status(200).json({ success: false, error: 'Method Not Allowed' });
        }

        let authenticatedUid = null;
        try {
            authenticatedUid = await getAuthenticatedUid(req);
        } catch (authError) {
            console.warn('Invalid Firebase ID token:', authError.message);
            return res.status(401).json({ success: false, error: '로그인 인증이 만료되었습니다. 다시 로그인해 주세요.' });
        }
        const body = req.body || {};
        const isRefresh = body.refresh === true;
        const refreshOpenId = body.openId?.toString().trim() || '';
        let url = body.url?.toString().trim() || '';

        if (isRefresh) {
            if (!authenticatedUid) {
                return res.status(401).json({ success: false, error: '로그인이 필요합니다.' });
            }
            if (!refreshOpenId) {
                return res.status(400).json({ success: false, error: '새로고침할 지휘관이 지정되지 않았습니다.' });
            }

            const refreshBindingRef = db.collection('open_id_bindings').doc(refreshOpenId);
            try {
                url = await db.runTransaction(async (transaction) => {
                    const bindingSnapshot = await transaction.get(refreshBindingRef);
                    const bindingData = bindingSnapshot.data();
                    if (!bindingSnapshot.exists || bindingData?.uid !== authenticatedUid) {
                        const notLinked = new Error('현재 Google 계정에 연동된 지휘관만 새로고침할 수 있습니다.');
                        notLinked.code = 'REFRESH_NOT_LINKED';
                        throw notLinked;
                    }

                    const lastRefreshMs = bindingData.lastRefreshAt?.toMillis?.() || 0;
                    const remainingMs = 30000 - (Date.now() - lastRefreshMs);
                    if (remainingMs > 0) {
                        const cooldown = new Error('새로고침은 30초마다 할 수 있습니다.');
                        cooldown.code = 'REFRESH_COOLDOWN';
                        cooldown.retryAfterSeconds = Math.ceil(remainingMs / 1000);
                        throw cooldown;
                    }
                    if (!bindingData.syncUrl) {
                        const missingUrl = new Error('저장된 BLABLALINK 주소가 없습니다. 계정을 다시 연동해 주세요.');
                        missingUrl.code = 'REFRESH_URL_MISSING';
                        throw missingUrl;
                    }

                    transaction.set(refreshBindingRef, {
                        lastRefreshAt: admin.firestore.FieldValue.serverTimestamp()
                    }, { merge: true });
                    return bindingData.syncUrl;
                });
            } catch (refreshError) {
                if (refreshError.code === 'REFRESH_COOLDOWN') {
                    return res.status(429).json({
                        success: false,
                        error: refreshError.message,
                        retryAfterSeconds: refreshError.retryAfterSeconds
                    });
                }
                if (refreshError.code === 'REFRESH_NOT_LINKED') {
                    return res.status(403).json({ success: false, error: refreshError.message });
                }
                if (refreshError.code === 'REFRESH_URL_MISSING') {
                    return res.status(409).json({ success: false, error: refreshError.message });
                }
                throw refreshError;
            }
        }

        if (!url) {
            return res.status(400).json({ success: false, error: 'Target URL is required.' });
        }
        // 1. URL에서 openId 추출 및 디코딩
        let openId = '';
        try {
            const parsedUrl = new URL(url);
            openId = parsedUrl.searchParams.get('openid');
        } catch (e) {
            const match = url.match(/[?&]openid=([^&]+)/);
            if (match) openId = match[1];
        }

        if (!openId) {
            return res.status(200).json({ success: false, error: 'Invalid or missing openid parameter in target URL.' });
        }

        // Base64 유효성 검사 후 디코딩
        if (/^[A-Za-z0-9+/=]+$/.test(openId) && openId.length % 4 === 0) {
            openId = safeBase64Decode(openId);
        }
        openId = openId.replace(/\x00/g, '').trim(); // 💡 NULL 바이트 제거
        if (isRefresh && openId !== refreshOpenId) {
            return res.status(409).json({ success: false, error: '연동 정보가 일치하지 않습니다. 계정을 다시 연동해 주세요.' });
        }

        let rawOpenId = openId;
        if (openId.includes('-')) {
            rawOpenId = openId.split('-')[1];
        }

        const botCookie = process.env.BOT_COOKIE || '';
        const customHeaders = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Content-Type': 'application/json',
            'X-language': 'ko',
            'Origin': 'https://www.blablalink.com',
            'Referer': 'https://www.blablalink.com/',
            'Cookie': botCookie
        };

        // 💡 헬퍼: 자동 재시도(Auto-retry) Axios POST
        async function postWithRetry(endpoint, payload, maxRetries = 2, delayMs = 300) {
            for (let i = 0; i <= maxRetries; i++) {
                try {
                    const res = await axios.post(endpoint, payload, { headers: customHeaders, timeout: 6000 });
                    if (res && res.data && res.data.code === 0) {
                        return res;
                    }
                    if (i < maxRetries) {
                        await new Promise(r => setTimeout(r, delayMs));
                    } else {
                        return res;
                    }
                } catch (err) {
                    if (i < maxRetries) {
                        await new Promise(r => setTimeout(r, delayMs));
                    } else {
                        console.error(`POST ${endpoint} error:`, err.message);
                        return null;
                    }
                }
            }
            return null;
        }

        const results = { profile: null, gameInfo: null, characters: [] };

        // [Step 1] Profile & GamePlayerInfo 조회 (자동 재시도)
        const profileRes = await postWithRetry(
            'https://api.blablalink.com/api/ugc/direct/standalonesite/User/GetUserProfile',
            { intl_openid: openId }
        );

        if (profileRes && profileRes.data && profileRes.data.code === 0) {
            results.profile = profileRes.data.data;
        } else if (!profileRes) {
            return res.status(200).json({
                success: false,
                error: "블라블라링크 서버 통신 지연: 프로필 정보를 가져올 수 없습니다. 잠시 후 다시 시도해 주세요."
            });
        }

        // 💡 [소유권 검증]: 상태메세지(소개글)가 '미미르만만세' 인지 검증
        const profileStr = JSON.stringify(results.profile || {});
        if (!isRefresh && !profileStr.includes('미미르만만세')) {
            return res.status(200).json({
                success: false,
                error: "소유권 확인 실패: 블라블라링크 프로필의 소개글(상태메시지)에 '미미르만만세'가 포함되어 있지 않습니다. 블라블라링크에서 소개글을 수정한 후 다시 시도해 주세요."
            });
        }

        const gameInfoRes = await postWithRetry(
            'https://api.blablalink.com/api/ugc/direct/standalonesite/User/GetUserGamePlayerInfo',
            { intl_openid: openId }
        );

        if (gameInfoRes && gameInfoRes.data && gameInfoRes.data.code === 0 && gameInfoRes.data.data) {
            results.gameInfo = gameInfoRes.data.data;
            const areaIdStr = results.gameInfo.area_id ? results.gameInfo.area_id.toString() : '83';
            const areaId = parseInt(areaIdStr, 10) || 83;
            const proxyPayload = { intl_open_id: rawOpenId, nikke_area_id: areaId };

            // [Step 2] 인게임 Basic & Outpost 지표 조회
            const basicRes = await postWithRetry(
                'https://api.blablalink.com/api/game/proxy/Game/GetUserProfileBasicInfo',
                proxyPayload
            );
            if (basicRes && basicRes.data && basicRes.data.code === 0 && basicRes.data.data) {
                Object.assign(results.gameInfo, basicRes.data.data.basic_info || basicRes.data.data);
            }

            const outpostRes = await postWithRetry(
                'https://api.blablalink.com/api/game/proxy/Game/GetUserProfileOutpostInfo',
                proxyPayload
            );
            if (outpostRes && outpostRes.data && outpostRes.data.code === 0 && outpostRes.data.data) {
                Object.assign(results.gameInfo, outpostRes.data.data.outpost_info || outpostRes.data.data);
            }

            // [Step 3] 타 유저 대응 길드 디테일 연동
            const gsn = results.gameInfo.gsn || (results.gameInfo.basic_info ? results.gameInfo.basic_info.gsn : null);
            if (gsn && gsn !== "0" && gsn !== 0) {
                const guildRes = await postWithRetry(
                    'https://api.blablalink.com/api/game/proxy/Game/GetGuildDetail',
                    { ...proxyPayload, guild_id: gsn.toString() }
                );
                if (guildRes && guildRes.data && guildRes.data.code === 0 && guildRes.data.data) {
                    const detail = guildRes.data.data.guild_detail || {};
                    results.gameInfo.guild_name = detail.guild_name;
                    results.gameInfo.guild_level = detail.guild_level;
                    results.gameInfo.guild_id = detail.guild_id;
                }
            } else {
                results.gameInfo.guild_name = '없음';
                results.gameInfo.guild_level = 0;
            }

            // [Step 4] 보유 니케 및 초정밀 상세 스펙 조회
            const charRes = await postWithRetry(
                'https://api.blablalink.com/api/game/proxy/Game/GetUserCharacters',
                proxyPayload
            );

            if (charRes && charRes.data && charRes.data.code === 0 && charRes.data.data) {
                const rawList = charRes.data.data.characters || [];
                const nameCodes = rawList.map(c => c.name_code).filter(Boolean);

                let detailsMap = {};
                if (nameCodes.length > 0) {
                    const detailsRes = await postWithRetry(
                        'https://api.blablalink.com/api/game/proxy/Game/GetUserCharacterDetails',
                        { ...proxyPayload, name_codes: nameCodes }
                    );

                    if (detailsRes && detailsRes.data && detailsRes.data.code === 0 && detailsRes.data.data) {
                        const detailsList = detailsRes.data.data.character_details || [];
                        for (const d of detailsList) {
                            detailsMap[d.name_code] = d;
                        }
                    }
                }

                // 최종 데이터 정제 및 맵핑
                const mappedList = [];
                for (const c of rawList) {
                    const d = detailsMap[c.name_code] || {};

                    const equips = [];
                    const slots = ['head', 'torso', 'arm', 'leg'];
                    for (const slot of slots) {
                        const tid = d[`${slot}_equip_tid`];
                        if (tid) {
                            const options = [];
                            for (let optIdx = 1; optIdx <= 3; optIdx++) {
                                const optId = d[`${slot}_equip_option${optIdx}_id`];
                                options.push(optId || 0);
                            }
                            equips.push({
                                slot,
                                tid,
                                level: d[`${slot}_equip_lv`] || 0,
                                tier: d[`${slot}_equip_tier`] || 0,
                                overloadOptions: options
                            });
                        }
                    }

                    mappedList.push({
                        name_code: c.name_code,
                        combat: c.combat,
                        level: c.lv,
                        core: c.core,
                        grade: c.grade,
                        costumeId: c.costume_id,
                        skills: {
                            skill1: d.skill1_lv || 1,
                            skill2: d.skill2_lv || 1,
                            burst: d.ulti_skill_lv || 1
                        },
                        bondLevel: d.attractive_lv || 1,
                        favoriteItem: d.favorite_item_tid ? { tid: d.favorite_item_tid, level: d.favorite_item_lv || 0 } : null,
                        harmonyCube: d.harmony_cube_tid ? { tid: d.harmony_cube_tid, level: d.harmony_cube_lv || 0 } : null,
                        equipment: equips
                    });
                }
                mappedList.sort((a, b) => b.combat - a.combat);
                results.characters = mappedList;
            }
        } else {
            // API failed (e.g. privacy settings disabled or account unlinked)
            const errorMsg = gameInfoRes?.data?.msg || '알 수 없는 오류';
            return res.status(200).json({
                success: false, 
                error: `지휘관 게임 정보를 불러올 수 없습니다. 블라블라링크 설정에서 '내 정보 공개' 및 '캐릭터 정보 공개'가 켜져 있는지 확인해주세요. (API 응답: ${errorMsg})`
            });
        }

        // [Step 5] Firestore DB에 정적 스냅샷 저장
        const userDocRef = db.collection('commanders').doc(openId);

        const payloadToSave = {
            nickname: results.profile ? (results.profile.info ? results.profile.info.username : '지휘관') : '지휘관',
            server: results.gameInfo ? (() => {
                const sMap = { '81': '일본', '82': '일본', '83': '한국', '84': '글로벌', '85': '글로벌', '86': '동남아' };
                const aId = results.gameInfo.area_id ? results.gameInfo.area_id.toString() : '';
                return sMap[aId] || `기타 (${aId})`;
            })() : '알 수 없음',
            union: results.gameInfo ? results.gameInfo.guild_name : '없음',
            unionLevel: results.gameInfo ? results.gameInfo.guild_level : 0,
            combatPower: results.gameInfo ? results.gameInfo.team_combat : 0,
            synchroLevel: results.gameInfo ? results.gameInfo.synchro_level : 0,
            commanderLevel: results.gameInfo ? results.gameInfo.player_level : 0,
            ownedNikkesCount: results.gameInfo ? results.gameInfo.own_nikke_cnt : 0,
            costumeCount: results.gameInfo ? results.gameInfo.costume : 0,
            normalCampaign: results.gameInfo ? results.gameInfo.normal_progress : 0,
            hardCampaign: results.gameInfo ? results.gameInfo.hard_progress : 0,
            towerFloor: results.gameInfo ? results.gameInfo.tower_floor : 0,
            recycleRoom: results.gameInfo ? results.gameInfo.recycle_room_researches : [],
            infraCoreLevel: results.gameInfo ? results.gameInfo.infra_core_level : 0,
            characters: results.characters, // 176명 상세 덱
            lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        if (authenticatedUid) {
            const bindingRef = db.collection('open_id_bindings').doc(openId);
            const accountRef = db.collection('users').doc(authenticatedUid);

            try {
                await db.runTransaction(async (transaction) => {
                    const bindingSnapshot = await transaction.get(bindingRef);
                    const accountSnapshot = await transaction.get(accountRef);
                    const accountData = accountSnapshot.data() || {};
                    const linkedOpenIds = Array.isArray(accountData.linkedOpenIds)
                        ? accountData.linkedOpenIds.filter(value => typeof value === 'string' && value.trim())
                        : [];
                    if (accountData.openId && !linkedOpenIds.includes(accountData.openId)) {
                        linkedOpenIds.push(accountData.openId);
                    }
                    if (!linkedOpenIds.includes(openId)) {
                        linkedOpenIds.push(openId);
                    }

                    const boundUid = bindingSnapshot.data()?.uid;
                    if (boundUid && boundUid !== authenticatedUid) {
                        const conflict = new Error('이미 다른 Google 계정에 연동된 BLABLALINK 계정입니다.');
                        conflict.code = 'BLABLA_ALREADY_LINKED';
                        throw conflict;
                    }


                    transaction.set(userDocRef, payloadToSave, { merge: true });
                    transaction.set(bindingRef, {
                        openId,
                        uid: authenticatedUid,
                        syncUrl: url,
                        ...(!bindingSnapshot.exists ? { boundAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        ...(isRefresh ? { lastRefreshSucceededAt: admin.firestore.FieldValue.serverTimestamp() } : {})
                    }, { merge: true });
                    transaction.set(accountRef, {
                        linkedOpenIds,
                        ...(!accountData.selectedOpenId ? {
                            selectedOpenId: openId,
                            selectedOpenIdUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
                        } : {}),
                        openId,
                        syncUrl: url,
                        isVerified: true,
                        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        ...(isRefresh ? { lastRefreshSucceededAt: admin.firestore.FieldValue.serverTimestamp() } : {})
                    }, { merge: true });
                });
            } catch (bindingError) {
                if (bindingError.code === 'BLABLA_ALREADY_LINKED') {
                    return res.status(409).json({ success: false, error: bindingError.message });
                }
                throw bindingError;
            }
        } else {
            await userDocRef.set(payloadToSave, { merge: true });
        }

        const guestAccessToken = authenticatedUid
            ? null
            : await issueGuestProfileToken({ admin, db, openId });
        return res.status(200).json({
            success: true,
            data: payloadToSave,
            ...(guestAccessToken ? { guestAccessToken } : {})
        });
    } catch (e) {
        console.error('Scraping handler critical error:', e);
        return res.status(200).json({ success: false, error: e.message });
    }
});
exports.unlinkBlablaAccount = functions.https.onRequest(async (req, res) => {
    const origin = req.headers.origin || '*';
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Credentials', 'true');

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }
    if (req.method !== 'POST') {
        return res.status(405).json({ success: false, error: 'Method Not Allowed' });
    }

    let uid;
    try {
        uid = await getAuthenticatedUid(req);
    } catch (authError) {
        console.warn('Invalid Firebase ID token:', authError.message);
        return res.status(401).json({ success: false, error: '로그인 인증이 만료되었습니다. 다시 로그인해 주세요.' });
    }
    if (!uid) {
        return res.status(401).json({ success: false, error: '로그인이 필요합니다.' });
    }

    const openId = req.body?.openId?.toString().trim();
    if (!openId) {
        return res.status(400).json({ success: false, error: '해제할 BLABLALINK 계정이 지정되지 않았습니다.' });
    }

    try {
        let activeOpenId = null;
        let activeSyncUrl = null;
        let selectedOpenId = null;

        await db.runTransaction(async (transaction) => {
            const accountRef = db.collection('users').doc(uid);
            const bindingRef = db.collection('open_id_bindings').doc(openId);
            const accountSnapshot = await transaction.get(accountRef);
            const bindingSnapshot = await transaction.get(bindingRef);
            const accountData = accountSnapshot.data() || {};
            const boundUid = bindingSnapshot.data()?.uid;

            if (boundUid && boundUid !== uid) {
                const forbidden = new Error('다른 Google 계정의 연동은 해제할 수 없습니다.');
                forbidden.code = 'BLABLA_BINDING_FORBIDDEN';
                throw forbidden;
            }

            const linkedOpenIds = Array.isArray(accountData.linkedOpenIds)
                ? accountData.linkedOpenIds.filter(value => typeof value === 'string' && value.trim())
                : [];
            if (accountData.openId && !linkedOpenIds.includes(accountData.openId)) {
                linkedOpenIds.push(accountData.openId);
            }
            const remainingOpenIds = linkedOpenIds.filter(value => value !== openId);

            activeOpenId = accountData.openId;
            if (!activeOpenId || activeOpenId === openId || !remainingOpenIds.includes(activeOpenId)) {
                activeOpenId = remainingOpenIds.length > 0
                    ? remainingOpenIds[remainingOpenIds.length - 1]
                    : null;
            }

            let activeBindingSnapshot = null;
            if (activeOpenId && activeOpenId !== accountData.openId) {
                activeBindingSnapshot = await transaction.get(
                    db.collection('open_id_bindings').doc(activeOpenId)
                );
            }
            activeSyncUrl = activeOpenId === accountData.openId
                ? (accountData.syncUrl || null)
                : (activeBindingSnapshot?.data()?.syncUrl || null);
            selectedOpenId = remainingOpenIds.includes(accountData.selectedOpenId)
                ? accountData.selectedOpenId
                : activeOpenId;

            if (bindingSnapshot.exists && (!boundUid || boundUid === uid)) {
                transaction.delete(bindingRef);
            }
            if (accountSnapshot.exists) {
                const accountUpdate = {
                    linkedOpenIds: remainingOpenIds,
                    isVerified: remainingOpenIds.length > 0,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                };
                if (selectedOpenId) {
                    accountUpdate.selectedOpenId = selectedOpenId;
                    accountUpdate.selectedOpenIdUpdatedAt = admin.firestore.FieldValue.serverTimestamp();
                } else {
                    accountUpdate.selectedOpenId = admin.firestore.FieldValue.delete();
                    accountUpdate.selectedOpenIdUpdatedAt = admin.firestore.FieldValue.delete();
                }
                if (activeOpenId) {
                    accountUpdate.openId = activeOpenId;
                    if (activeSyncUrl) {
                        accountUpdate.syncUrl = activeSyncUrl;
                    } else {
                        accountUpdate.syncUrl = admin.firestore.FieldValue.delete();
                    }
                } else {
                    accountUpdate.openId = admin.firestore.FieldValue.delete();
                    accountUpdate.syncUrl = admin.firestore.FieldValue.delete();
                    accountUpdate.verifiedAt = admin.firestore.FieldValue.delete();
                }
                transaction.update(accountRef, accountUpdate);
            }
        });

        return res.status(200).json({
            success: true,
            activeOpenId,
            activeSyncUrl,
            selectedOpenId
        });
    } catch (error) {
        if (error.code === 'BLABLA_BINDING_FORBIDDEN') {
            return res.status(403).json({ success: false, error: error.message });
        }
        console.error('Unlink BLABLALINK account failed:', error);
        return res.status(500).json({ success: false, error: '연동 해제 중 서버 오류가 발생했습니다.' });
    }
});

exports.getNikkeStatistics = createNikkeStatisticsHandler({ functions, admin, db, getAuthenticatedUid });
exports.refreshDailyNikkeStatistics = createDailyNikkeStatisticsHandler({ functions, admin, db });
exports.refreshNikkeStatisticsNow = createNikkeStatisticsRefreshHandler({ functions, admin, db, getAuthenticatedUid });
exports.getGuestCommanderProfile = createGuestCommanderProfileHandler({ functions, db });
