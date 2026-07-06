const fs = require('fs');
const content = fs.readFileSync('scraped_3.js', 'utf8');
const idx = content.indexOf('API_SS_UGC_USER_PLAYER_INFO');
if (idx !== -1) {
  // Find what API_SS_UGC_USER_PLAYER_INFO is replaced with in scraped_3.js.
  // We know it exports `er` which is `useGetUserGamePlayerInfo`.
  // Wait, let's search for "useGetUserGamePlayerInfo" and print context.
  const idx2 = content.indexOf('useGetUserGamePlayerInfo');
  console.log(content.substring(idx2 - 100, idx2 + 100));
}
