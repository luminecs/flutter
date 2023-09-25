import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart' hide TypeMatcher, isInstanceOf;

import '../../../rendering/custom_coordinate_systems.dart' as demo;

void main() {
  test('layers smoketest for rendering/custom_coordinate_systems.dart', () {
    FlutterError.onError = (FlutterErrorDetails details) { throw details.exception; };
    demo.main();
    expect(SchedulerBinding.instance.hasScheduledFrame, true);
  });
}