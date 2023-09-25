import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  failingPendingTimerTest();
}

void failingPendingTimerTest() {
  testWidgets('flutter_test pending timer - negative', (WidgetTester tester) async {
    Timer(const Duration(minutes: 10), () {});
  });
}