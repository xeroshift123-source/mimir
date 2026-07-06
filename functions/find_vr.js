const fs = require('fs');
const t = fs.readFileSync('scraped_1.js', 'utf8');
const match = t.match(/vr\s*=\s*['"`]([^'"`]+)['"`]/g);
console.log(match);
