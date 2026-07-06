const fs = require('fs');
const t = fs.readFileSync('scraped_1.js', 'utf8');
const match = t.match(/['"`](\/api\/[^'"`]+)['"`]/g);
if(match) {
  const unique = [...new Set(match)];
  console.log(unique);
}
