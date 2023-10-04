import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking('debugCheckHasCupertinoLocalizations throws',
      (WidgetTester tester) async {
    final GlobalKey noLocalizationsAvailable = GlobalKey();
    final GlobalKey localizationsAvailable = GlobalKey();

    await tester.pumpWidget(
      Container(
        key: noLocalizationsAvailable,
        child: CupertinoApp(
          home: Container(
            key: localizationsAvailable,
          ),
        ),
      ),
    );

    expect(
        () => debugCheckHasCupertinoLocalizations(
            noLocalizationsAvailable.currentContext!),
        throwsA(isAssertionError.having(
          (AssertionError e) => e.message,
          'message',
          contains('No CupertinoLocalizations found'),
        )));

    expect(
        debugCheckHasCupertinoLocalizations(
            localizationsAvailable.currentContext!),
        isTrue);
  });
}
