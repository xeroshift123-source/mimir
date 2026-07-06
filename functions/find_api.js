const fs = require('fs');
const files = fs.readdirSync('.').filter(f => f.startsWith('scraped_'));
files.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  let idx = content.indexOf('API_SS_UGC_USER_PLAYER_INFO');
  if (idx !== -1) {
    console.log(`Found in ${f}:`);
    console.log(content.substring(idx - 100, idx + 100));
  }
});
