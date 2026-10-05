import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<bool> downloadTextFile({
  required String filename,
  required String content,
}) async {
  try {
    Directory? targetDir;

    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        targetDir = publicDownload;
      } else {
        targetDir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      // Desktop: Windows, macOS, Linux
      targetDir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    final filePath = p.join(targetDir.path, filename);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);

    // Try to open the file with the default text viewer
    try {
      await OpenFile.open(filePath, type: 'text/plain');
    } catch (_) {}

    return true;
  } catch (e) {
    return false;
  }
}
