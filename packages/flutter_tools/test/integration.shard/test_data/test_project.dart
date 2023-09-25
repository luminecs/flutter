
import 'project.dart';

class TestProject extends Project {

  @override
  final String pubspec = '''
  name: test
  environment:
    sdk: '>=3.2.0-0 <4.0.0'

  dependencies:
    flutter:
      sdk: flutter
  dev_dependencies:
    flutter_test:
      sdk: flutter
  ''';

  @override
  final String main = r'''
int foo(int bar) {
  return bar + 2;
}
  ''';

  @override
  final String test = r'''
  import 'package:flutter_test/flutter_test.dart';
  import 'package:test/main.dart';

  void main() {
    testWidgets('it can test', (WidgetTester tester) async {
      expect(foo(2), 4);
    });
  }
''';
}