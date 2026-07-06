const fs = require('fs');
const content = fs.readFileSync('scraped_1.js', 'utf8');
const regex = /vr\s*=\s*['"`]([^'"`]+)['"`]/g;
let match;
while ((match = regex.exec(content)) !== null) {
  console.log("vr =", match[1]);
}
