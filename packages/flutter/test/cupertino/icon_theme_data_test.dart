import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking('IconTheme.of works',
      (WidgetTester tester) async {
    const IconThemeData data = IconThemeData(
        size: 16.0,
        fill: 0.0,
        weight: 400.0,
        grade: 0.0,
        opticalSize: 48.0,
        color: Color(0xAAAAAAAA),
        opacity: 0.5);

    late IconThemeData retrieved;
    await tester.pumpWidget(
      IconTheme(
          data: data,
          child: Builder(builder: (BuildContext context) {
            retrieved = IconTheme.of(context);
            return const SizedBox();
          })),
    );

    expect(retrieved, data);

    await tester.pumpWidget(
      IconTheme(
        data: const CupertinoIconThemeData(color: CupertinoColors.systemBlue),
        child: MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: Builder(
            builder: (BuildContext context) {
              retrieved = IconTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
        retrieved.color, isSameColorAs(CupertinoColors.systemBlue.darkColor));
  });
}
