// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
}) async {
  try {
    final bytes = utf8.encode(content);
    // Explicitly declare text/plain;charset=utf-8 MIME type
    final blob = html.Blob([bytes], 'text/plain;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..setAttribute('target', '_blank')
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);

    // Give browser time to start the download stream before revoking URL
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });

    return true;
  } catch (e) {
    return false;
  }
}
