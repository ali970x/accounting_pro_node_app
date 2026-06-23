import "dart:html" as html;

Future<bool> downloadTextFile({required String filename, required String content}) async {
  final blob = html.Blob([content], "text/plain;charset=utf-8");
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = "none";
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
