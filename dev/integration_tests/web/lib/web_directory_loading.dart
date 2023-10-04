import 'dart:html' as html;

// Attempt to load a file that is hosted in the applications's `web/` directory.
Future<void> main() async {
  try {
    final html.HttpRequest request = await html.HttpRequest.request(
      '/example',
      method: 'GET',
    );
    final String? body = request.responseText;
    if (body == 'This is an Example') {
      print('--- TEST SUCCEEDED ---');
    } else {
      print('--- TEST FAILED ---');
    }
  } catch (err) {
    print(err);
    print('--- TEST FAILED ---');
  }
}
