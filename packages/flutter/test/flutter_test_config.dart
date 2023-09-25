
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import '_goldens_io.dart'
  if (dart.library.html) '_goldens_web.dart' as flutter_goldens;

Future<void> testExecutable(FutureOr<void> Function() testMain) {
  // Enable checks because there are many implementations of [RenderBox] in this
  // package can benefit from the additional validations.
  debugCheckIntrinsicSizes = true;

  // Make tap() et al fail if the given finder specifies a widget that would not
  // receive the event.
  WidgetController.hitTestWarningShouldBeFatal = true;

  LeakTracking.warnForUnsupportedPlatforms = false;
  setLeakTrackingTestSettings(
    LeakTrackingTestSettings(switches: const Switches(disableNotGCed: true))
  );

  // Enable golden file testing using Skia Gold.
  return flutter_goldens.testExecutable(testMain);
}