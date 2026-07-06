const fs = require('fs');
const files = ['scraped_1.js', 'scraped_2.js', 'scraped_3.js', 'scraped_0.js'];
files.forEach(f => {
  if(!fs.existsSync(f)) return;
  const t = fs.readFileSync(f, 'utf8');
  const match = t.match(/['"`]\/api\/[^'"`]+['"`]/g);
  if(match) {
    const urls = match.filter(x => x.toLowerCase().includes('user') || x.toLowerCase().includes('game'));
    if(urls.length > 0) {
      console.log("In " + f + ":");
      console.log([...new Set(urls)]);
    }
  }
});
