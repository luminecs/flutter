import 'dart:convert';
import 'dart:html' as html;
import 'dart:js';
import 'dart:js_util' as js_util;

void registerWebServiceExtension(Future<Map<String, dynamic>> Function(Map<String, String>) call) {
  // Define the result variable because packages/flutter_driver/lib/src/driver/web_driver.dart
  // checks for this value to become non-null when waiting for the result. If this value is
  // undefined at the time of the check, WebDriver throws an exception.
  context[r'$flutterDriverResult'] = null;

  js_util.setProperty(html.window, r'$flutterDriver', allowInterop((dynamic message) async {
    final Map<String, String> params = Map<String, String>.from(
        jsonDecode(message as String) as Map<String, dynamic>);
    final Map<String, dynamic> result = Map<String, dynamic>.from(
        await call(params));
    context[r'$flutterDriverResult'] = json.encode(result);
  }));
}