import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:matcher/expect.dart' show fail;

import 'goldens.dart';

class LocalFileComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) {
    throw UnsupportedError('LocalFileComparator is not supported on the web.');
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    throw UnsupportedError('LocalFileComparator is not supported on the web.');
  }
}

Future<ComparisonResult> compareLists(List<int> test, List<int> master) async {
  throw UnsupportedError('Golden testing is not supported on the web.');
}

class DefaultWebGoldenComparator extends WebGoldenComparator {
  DefaultWebGoldenComparator(this.testUri);

  Uri testUri;

  @override
  Future<bool> compare(double width, double height, Uri golden) async {
    final String key = golden.toString();
    final html.HttpRequest request = await html.HttpRequest.request(
      'flutter_goldens',
      method: 'POST',
      sendData: json.encode(<String, Object>{
        'testUri': testUri.toString(),
        'key': key,
        'width': width.round(),
        'height': height.round(),
      }),
    );
    final String response = request.response as String;
    if (response == 'true') {
      return true;
    }
    fail(response);
  }

  @override
  Future<void> update(double width, double height, Uri golden) async {
    // Update is handled on the server side, just use the same logic here
    await compare(width, height, golden);
  }
}