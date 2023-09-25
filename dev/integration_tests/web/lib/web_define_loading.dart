
import 'dart:html' as html;

Future<void> main() async {
  final StringBuffer output = StringBuffer();
  const String combined = String.fromEnvironment('test.valueA') +
    String.fromEnvironment('test.valueB');
  if (combined == 'Example,AValue') {
    output.write('--- TEST SUCCEEDED ---');
    print('--- TEST SUCCEEDED ---');
  } else {
    output.write('--- TEST FAILED ---');
    print('--- TEST FAILED ---');
  }

  html.HttpRequest.request(
    '/test-result',
    method: 'POST',
    sendData: '$output',
  );
}