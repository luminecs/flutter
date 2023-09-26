// @dart = 2.12

import 'dart:html' as html;

// Verify that web applications can be run in sound mode.
void main() {
  const bool isWeak = <int?>[] is List<int>;
  String output;
  if (isWeak) {
    output = '--- TEST FAILED ---';
  } else {
    output = '--- TEST SUCCEEDED ---';
  }
  print(output);
  html.HttpRequest.request(
    '/test-result',
    method: 'POST',
    sendData: output,
  );
}
