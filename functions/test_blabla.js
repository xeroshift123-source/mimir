const { fetchCDNJson } = require('./cdnDecrypt');

async function test() {
  const openId = '29080-1577807661796474158';
  const rawOpenId = '1577807661796474158';

  const paths = [
    `/data/user/${openId}.json`,
    `/profile/${openId}.json`,
    `/gameplayerinfo/${openId}.json`,
    `/api/ugc/direct/standalonesite/User/GetUserGamePlayerInfo/${openId}.json`,
    `/api/ugc/direct/standalonesite/User/GetUserGamePlayerInfo?intl_openid=${openId}`
  ];

  for(const p of paths) {
    console.log(`Testing CDN path: ${p}`);
    const data = await fetchCDNJson(p);
    console.log(data ? "SUCCESS" : "FAILED");
  }
}

test();
