// First: dart compile js -O2 -o .dart_tool/image_export_smoke/main.js test/image_export_interop_smoke.dart
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFile } = require('node:child_process');
const root = path.join(__dirname, '..');
const chrome = process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const compiledTest = fs.readFileSync(path.join(root, '.dart_tool/image_export_smoke/main.js'));
const exporter = fs.readFileSync(path.join(root, 'web/image_export.js'));

const server = http.createServer((req, res) => {
  if (req.url === '/main.js' || req.url === '/image_export.js') {
    res.setHeader('Content-Type', 'application/javascript');
    return res.end(req.url === '/main.js' ? compiledTest : exporter);
  }
  res.setHeader('Content-Type', 'text/html');
  res.end('<!doctype html><html><head><meta charset="utf-8"></head><body><script src="/image_export.js"></script><script src="/main.js"></script></body></html>');
});
server.listen(0, '127.0.0.1', () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mimir-export-test-'));
  execFile(chrome, [
    '--headless', '--disable-gpu', '--no-first-run', `--user-data-dir=${profile}`,
    '--dump-dom', '--virtual-time-budget=3000', `http://127.0.0.1:${server.address().port}`,
  ], { timeout: 20000 }, (error, stdout, stderr) => {
    console.log(stdout);
    if (error || !stdout.includes('data-test-result="passed"')) {
      console.error(error || stderr);
      process.exitCode = 1;
    }
    server.close();
  });
});
