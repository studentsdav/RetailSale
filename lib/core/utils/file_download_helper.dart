import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

/// Universally downloads / saves a plain text file across Web, Android, iOS, Windows, macOS, Linux
Future<bool> saveOrDownloadTextFile({
  required String filename,
  required String content,
}) =>
    downloadTextFile(filename: filename, content: content);
