const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const axios = require('axios');
const cors = require('cors')({ origin: true });
const { fetchCDNJson } = require('./cdnDecrypt');

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

        const { url } = req.body || {};
        if (!url) {
            return res.status(200).json({ success: false, error: 'Target URL is required.' });
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

        const results = { profile: null, gameInfo: null, characters: [] };

        // [Step 1] Profile & GamePlayerInfo 조회
        const profileRes = await axios.post(
            'https://api.blablalink.com/api/ugc/direct/standalonesite/User/GetUserProfile',
            { intl_openid: openId },
            { headers: customHeaders }
        ).catch(err => {
            console.error('GetUserProfile error:', err.message);
            return null;
        });

        if (profileRes && profileRes.data && profileRes.data.code === 0) {
            results.profile = profileRes.data.data;
        }

        // 💡 [소유권 검증]: 상태메세지(소개글)가 '미미르만만세' 인지 검증
        const profileStr = JSON.stringify(results.profile || {});
        if (!profileStr.includes('미미르만만세')) {
            return res.status(200).json({
                success: false,
                error: "소유권 확인 실패: 블라블라링크 프로필의 소개글(상태메시지)에 '미미르만만세'가 포함되어 있지 않습니다. 블라블라링크에서 소개글을 수정한 후 다시 시도해 주세요."
            });
        }

        const gameInfoRes = await axios.post(
            'https://api.blablalink.com/api/ugc/direct/standalonesite/User/GetUserGamePlayerInfo',
            { intl_openid: openId },
            { headers: customHeaders }
        ).catch(err => {
            console.error('GetUserGamePlayerInfo error:', err.message);
            return null;
        });

        if (gameInfoRes && gameInfoRes.data && gameInfoRes.data.code === 0 && gameInfoRes.data.data) {
            results.gameInfo = gameInfoRes.data.data;
            const areaIdStr = results.gameInfo.area_id ? results.gameInfo.area_id.toString() : '83';
            const areaId = parseInt(areaIdStr, 10) || 83;
            const proxyPayload = { intl_open_id: rawOpenId, nikke_area_id: areaId };

            // [Step 2] 인게임 Basic & Outpost 지표 조회
            const basicRes = await axios.post(
                'https://api.blablalink.com/api/game/proxy/Game/GetUserProfileBasicInfo',
                proxyPayload,
                { headers: customHeaders }
            ).catch(() => null);
            if (basicRes && basicRes.data && basicRes.data.code === 0 && basicRes.data.data) {
                Object.assign(results.gameInfo, basicRes.data.data.basic_info || basicRes.data.data);
            }

            const outpostRes = await axios.post(
                'https://api.blablalink.com/api/game/proxy/Game/GetUserProfileOutpostInfo',
                proxyPayload,
                { headers: customHeaders }
            ).catch(() => null);
            if (outpostRes && outpostRes.data && outpostRes.data.code === 0 && outpostRes.data.data) {
                Object.assign(results.gameInfo, outpostRes.data.data.outpost_info || outpostRes.data.data);
            }

            // [Step 3] 타 유저 대응 길드 디테일 연동
            const gsn = results.gameInfo.gsn || (results.gameInfo.basic_info ? results.gameInfo.basic_info.gsn : null);
            if (gsn && gsn !== "0" && gsn !== 0) {
                const guildRes = await axios.post(
                    'https://api.blablalink.com/api/game/proxy/Game/GetGuildDetail',
                    { ...proxyPayload, guild_id: gsn.toString() },
                    { headers: customHeaders }
                ).catch(() => null);
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
            const charRes = await axios.post(
                'https://api.blablalink.com/api/game/proxy/Game/GetUserCharacters',
                proxyPayload,
                { headers: customHeaders }
            ).catch(() => null);

            if (charRes && charRes.data && charRes.data.code === 0 && charRes.data.data) {
                const rawList = charRes.data.data.characters || [];
                const nameCodes = rawList.map(c => c.name_code).filter(Boolean);

                let detailsMap = {};
                if (nameCodes.length > 0) {
                    const detailsRes = await axios.post(
                        'https://api.blablalink.com/api/game/proxy/Game/GetUserCharacterDetails',
                        { ...proxyPayload, name_codes: nameCodes },
                        { headers: customHeaders }
                    ).catch(() => null);

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
        }

        // [Step 5] Firestore DB에 정적 스냅샷 저장
        const userDocRef = db.collection('commanders').doc(openId);

        const payloadToSave = {
            nickname: results.profile ? (results.profile.info ? results.profile.info.username : '지휘관') : '지휘관',
            server: results.gameInfo ? (() => {
                const sMap = { '81': '일본', '82': '일본', '83': '한국', '84': '북미', '85': '글로벌', '86': '동남아' };
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

        await userDocRef.set(payloadToSave, { merge: true });

        return res.status(200).json({ success: true, data: payloadToSave });

    } catch (e) {
        console.error('Scraping handler critical error:', e);
        return res.status(200).json({ success: false, error: e.message });
    }
});
