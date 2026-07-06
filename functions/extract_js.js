const fs = require('fs');
const html = fs.readFileSync('../../.gemini/antigravity-ide/brain/82593f88-b975-43cd-99b3-0cb6fcb6d8fa/.system_generated/steps/67/content.md', 'utf8');
const regex = /src="([^"]+\.js)"/g;
let match;
const jsUrls = [];
while ((match = regex.exec(html)) !== null) {
  if (match[1].startsWith('http') || match[1].startsWith('//')) {
    jsUrls.push(match[1]);
  } else {
    jsUrls.push('https://www.blablalink.com' + match[1]);
  }
}
console.log(jsUrls);
