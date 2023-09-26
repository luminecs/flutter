import 'dart:convert';
import 'dart:io';

const String registry =
    'https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry';

Future<void> main() async {
  final HttpClient client = HttpClient();
  final HttpClientRequest request = await client.getUrl(Uri.parse(registry));
  final HttpClientResponse response = await request.close();
  final String body = (await response
          .cast<List<int>>()
          .transform<String>(utf8.decoder)
          .toList())
      .join();
  final File subtagRegistry = File('../language_subtag_registry.dart');
  final File subtagRegistryFlutterTools = File(
      '../../../../packages/flutter_tools/lib/src/localizations/language_subtag_registry.dart');

  final String content = '''

const String languageSubtagRegistry = \'\'\'$body\'\'\';''';

  subtagRegistry.writeAsStringSync(content);
  subtagRegistryFlutterTools.writeAsStringSync(content);

  client.close(force: true);
}
