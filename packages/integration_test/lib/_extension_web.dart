import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js';
import 'dart:js_util' as js_util;

void registerWebServiceExtension(
    Future<Map<String, dynamic>> Function(Map<String, String>) callback) {
  // Define the result variable because packages/flutter_driver/lib/src/driver/web_driver.dart
  // checks for this value to become non-null when waiting for the result. If this value is
  // undefined at the time of the check, WebDriver throws an exception.
  context[r'$flutterDriverResult'] = null;

  js_util.setProperty(html.window, r'$flutterDriver',
      allowInterop((dynamic message) async {
    try {
      final Map<String, dynamic> messageJson =
          jsonDecode(message as String) as Map<String, dynamic>;
      final Map<String, String> params = messageJson.cast<String, String>();
      final Map<String, dynamic> result = await callback(params);
      context[r'$flutterDriverResult'] = json.encode(result);
    } catch (error, stackTrace) {
      // Encode the error in the same format the FlutterDriver extension uses.
      // See //packages/flutter_driver/lib/src/extension/extension.dart
      context[r'$flutterDriverResult'] = json.encode(<String, dynamic>{
        'isError': true,
        'response': '$error\n$stackTrace',
      });
    }
  }));
}
