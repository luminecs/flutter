import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> scrollAt(Offset position, WidgetTester tester,
    [Offset offset = const Offset(0.0, 20.0)]) {
  final TestPointer testPointer = TestPointer(1, PointerDeviceKind.mouse);
  // Create a hover event so that |testPointer| has a location when generating the scroll.
  testPointer.hover(position);
  return tester.sendEventToBinding(testPointer.scroll(offset));
}
