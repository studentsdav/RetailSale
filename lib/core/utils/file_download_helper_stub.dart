import 'dart:async';

Future<bool> downloadTextFile({
  required String filename,
  required String content,
}) async {
  throw UnsupportedError('Cannot download file on unsupported platform');
}
