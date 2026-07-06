const fs = require('fs');
const t = fs.readFileSync('scraped_1.js', 'utf8');
const match = t.match(/[A-Za-z0-9_]+\s*=\s*['"`]([^'"`]*User[^'"`]*)['"`]/g);
if(match) {
  console.log(match.slice(0, 30));
}
