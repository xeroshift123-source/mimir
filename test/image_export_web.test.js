const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../web/image_export.js'), 'utf8');

function browser(options = {}) {
  const elements = [], timers = [], revoked = [], writes = [], downloads = [];
  let gesture = false;
  const document = {
    body: { append() {} },
    createElement(tag) {
      assert.equal(tag, 'a', 'export must not introduce a dialog or another button');
      const el = {
        tag, style: {},
        remove() { this.removed = true; },
        click() { downloads.push(this); },
      };
      elements.push(el);
      return el;
    },
  };
  const navigator = {
    userAgent: options.userAgent || 'iPhone',
    share() { assert.fail('download must not switch to a share sheet'); },
    clipboard: options.noClipboard ? undefined : { write(items) {
      writes.push({ items, gesture });
      if (options.syncDenial) throw new Error('NotAllowedError');
      if (options.denied || !gesture) return Promise.reject(new Error('NotAllowedError'));
      return items[0].data['image/png'].then(() => {});
    } },
  };
  const window = {};
  let urlId = 0;
  vm.runInNewContext(source, {
    window, navigator, document,
    ClipboardItem: class { constructor(data) { this.data = data; } },
    URL: { createObjectURL: () => `blob:${++urlId}`, revokeObjectURL: url => revoked.push(url) },
    setTimeout: (fn, delay) => timers.push({ fn, delay }),
  });
  return {
    api: window.mimirImageExport, elements, timers, revoked, writes, downloads,
    tapCopy(png) {
      gesture = true;
      const result = this.api.copy(png, 'recap.png');
      gesture = false;
      return result;
    },
  };
}
const png = new Blob(['png'], { type: 'image/png' });

// Reproduce the original failure: waiting for capture loses Safari's gesture.
test('clipboard write starts during the original tap, before capture completes', async () => {
  const b = browser();
  let finishCapture;
  const pendingPng = new Promise(resolve => { finishCapture = resolve; });
  const result = b.tapCopy(pendingPng);
  assert.equal(b.writes.length, 1);
  assert.equal(b.writes[0].gesture, true);
  assert.equal(b.downloads.length, 0);
  finishCapture(png);
  assert.equal(await result, true);
  assert.equal(await b.writes[0].items[0].data['image/png'], png);
  assert.equal(b.elements.length, 0);
});

for (const userAgent of ['iPhone', 'Android', 'Macintosh', 'Windows']) {
  test(`${userAgent}: download stays a direct PNG download without extra UI`, async () => {
    const b = browser({ userAgent });
    await b.api.save(png, 'license.png');
    assert.equal(b.downloads.length, 1);
    assert.equal(b.downloads[0].download, 'license.png');
    assert.equal(b.revoked.length, 0);
    assert.ok(b.downloads[0].removed);
    assert.ok(b.timers[0].delay >= 60000);
    b.timers[0].fn();
    assert.equal(b.revoked.length, 1);
  });
}

for (const options of [{ noClipboard: true }, { denied: true }, { syncDenial: true }]) {
  test(`unavailable clipboard retains the existing download fallback: ${JSON.stringify(options)}`, async () => {
    const b = browser(options);
    assert.equal(await b.tapCopy(Promise.resolve(png)), false);
    assert.equal(b.downloads.length, 1);
  });
}

test('failed capture rejects and never reports a successful copy or downloads a blank PNG', async () => {
  const b = browser();
  let failCapture;
  const result = b.tapCopy(new Promise((_, reject) => { failCapture = reject; }));
  const assertion = assert.rejects(result, /capture failed/);
  failCapture(new Error('capture failed'));
  await assertion;
  assert.equal(b.downloads.length, 0);
});
