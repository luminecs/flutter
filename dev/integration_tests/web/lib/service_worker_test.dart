
import 'dart:html' as html;
Future<void> main() async {
  await html.window.navigator.serviceWorker?.ready;
  const String response = 'CLOSE?version=1';
  await html.HttpRequest.getString(response);
  html.document.body?.appendHtml(response);
}