
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('included', (WidgetTester tester) async {
    expect(2 + 2, 4);
  }, tags: <String>['include-tag']);
  testWidgets('excluded', (WidgetTester tester) async {
    throw 'this test should have been filtered out';
  }, tags: <String>['exclude-tag']);
}