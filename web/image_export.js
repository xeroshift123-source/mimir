// No UI: both actions run from the existing Flutter buttons.
(() => {
  async function save(blob, filename) {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.style.display = 'none';
    document.body.append(link);
    try {
      link.click();
    } finally {
      link.remove();
      // Allow mobile browsers time to consume the URL before releasing it.
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    }
  }

  async function copy(pngPromise, filename) {
    const png = Promise.resolve(pngPromise);
    // A synchronous ClipboardItem/write failure must not leave the PNG
    // promise unhandled while the download fallback is being selected.
    png.catch(() => {});
    if (navigator.clipboard?.write && typeof ClipboardItem !== 'undefined') {
      try {
        // Safari requires write() in the original tap. Do not await the PNG.
        await navigator.clipboard.write([
          new ClipboardItem({ 'image/png': png }),
        ]);
        return true;
      } catch (_) {
        // Keep the existing download fallback if clipboard access is denied.
      }
    }
    await save(await png, filename);
    return false;
  }

  window.mimirImageExport = { save, copy };
})();
