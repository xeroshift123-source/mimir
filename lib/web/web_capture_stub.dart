Future<void> captureByElementId({
  required String elementId,
  required String fileName,
}) {
  throw UnsupportedError('Web element capture is only available on the Web.');
}

Future<void> copyElementById({required String elementId}) {
  throw UnsupportedError('Web clipboard capture is only available on the Web.');
}
