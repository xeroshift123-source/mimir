const axios = require('axios');

async function test() {
  const originalOpenId = 'MjkwODAtMTU3NzgwNzY2MTc5NjQ3NDE1OA==';
  let decodedOpenId = Buffer.from(originalOpenId, 'base64').toString('utf8');
  let rawOpenId = decodedOpenId.split('-')[1];

  const botCookie = "OptanonAlertBoxClosed=2025-11-09T02:52:04.579Z; game_login_game=0; game_token=5b80485552bbd3f0566c05060ed8d6a50180cca8; game_gameid=29080; game_openid=1499416586116033864; game_channelid=131; game_user_name=Player_84lEucY7; game_uid=8014550373519487; game_adult_status=1; OptanonConsent=isGpcEnabled=0&datestamp=Fri+Jul+03+2026+19%3A07%3A23+GMT%2B0900+(%ED%95%9C%EA%B5%AD+%ED%91%9C%EC%A4%80%EC%8B%9C)&version=202409.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=fbe3d064-2069-42f4-9a96-2d1cba77282f&interactionCount=1&isAnonUser=1&landingPath=NotLandingPage&groups=C0001%3A1%2CC0004%3A0&intType=3&geolocation=KR%3B11&AwaitingReconsent=false";

  const customHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Content-Type': 'application/json',
    'X-language': 'ko',
    'Origin': 'https://www.blablalink.com',
    'Referer': 'https://www.blablalink.com/',
    'Cookie': botCookie
  };

  console.log("Testing GetUserGamePlayerInfo with new cookie...");
  const r1 = await axios.post(
    'https://api.blablalink.com/api/ugc/direct/standalonesite/User/GetUserGamePlayerInfo',
    { intl_openid: decodedOpenId },
    { headers: customHeaders }
  ).catch(err => err.response);
  
  if (r1.data) {
     console.log("GamePlayerInfo code:", r1.data.code);
     if (r1.data.code === 0) {
        console.log("SUCCESS! Keys:", Object.keys(r1.data.data));
     } else {
        console.log("Failed:", r1.data.msg);
     }
  }

  const proxyPayload = { intl_open_id: rawOpenId, nikke_area_id: 83 };
  console.log("Testing GetUserCharacters with new cookie...");
  const r2 = await axios.post(
    'https://api.blablalink.com/api/game/proxy/Game/GetUserCharacters',
    proxyPayload,
    { headers: customHeaders }
  ).catch(err => err.response);
  
  if (r2.data) {
     console.log("GetUserCharacters code:", r2.data.code);
     if (r2.data.code === 0) {
        console.log("Characters count:", r2.data.data.characters?.length);
     } else {
        console.log("Failed:", r2.data.msg);
     }
  }
}

test();
