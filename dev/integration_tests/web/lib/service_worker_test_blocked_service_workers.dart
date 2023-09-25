import 'dart:html' as html;
Future<void> main() async {
  const String response = 'CLOSE?version=1';
  await html.HttpRequest.getString(response);
  html.document.body?.appendHtml(response);
}