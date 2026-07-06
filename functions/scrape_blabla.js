const axios = require('axios');
const fs = require('fs');

async function scrape() {
  const res = await axios.get('https://www.blablalink.com/user?openid=MjkwODAtMTU3NzgwNzY2MTc5NjQ3NDE1OA==');
  const html = res.data;
  
  const jsUrls = [];
  const regex = /src=["']([^"']+\.js[^"']*)["']/g;
  let match;
  while ((match = regex.exec(html)) !== null) {
    jsUrls.push(match[1]);
  }
  
  console.log("Found JS:", jsUrls);
  
  for(let i=0; i<jsUrls.length; i++) {
    let url = jsUrls[i];
    if (url.startsWith('/')) {
       url = 'https://www.blablalink.com' + url;
    } else if (!url.startsWith('http')) {
       url = 'https://www.blablalink.com/' + url;
    }
    console.log("Fetching", url);
    const jsRes = await axios.get(url).catch(e => null);
    if (jsRes && jsRes.data) {
       fs.writeFileSync(`c:\\MMR\\mimir\\functions\\scraped_${i}.js`, jsRes.data);
    }
  }
}
scrape();
