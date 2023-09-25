
// This test is a use case of flutter/flutter#60796
// the test should be run as:
// flutter drive -t test/using_array.dart --driver test_driver/scrolling_test_e2e_test.dart

import 'package:complex_layout/main.dart' as app;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Iterable<PointerEvent> dragInputEvents(
  final Duration epoch,
  final Offset center, {
  final Offset totalMove = const Offset(0, -400),
  final Duration totalTime = const Duration(milliseconds: 2000),
  final double frequency = 90,
}) sync* {
  final Offset startLocation = center - totalMove / 2;
  // The issue is about 120Hz input on 90Hz refresh rate device.
  // We test 90Hz input on 60Hz device here, which shows similar pattern.
  final int moveEventCount = totalTime.inMicroseconds * frequency ~/ const Duration(seconds: 1).inMicroseconds;
  final Offset movePerEvent = totalMove / moveEventCount.toDouble();
  yield PointerAddedEvent(
    timeStamp: epoch,
    position: startLocation,
  );
  yield PointerDownEvent(
    timeStamp: epoch,
    position: startLocation,
    pointer: 1,
  );
  for (int t = 0; t < moveEventCount + 1; t++) {
    final Offset position = startLocation + movePerEvent * t.toDouble();
    yield PointerMoveEvent(
      timeStamp: epoch + totalTime * t ~/ moveEventCount,
      position: position,
      delta: movePerEvent,
      pointer: 1,
    );
  }
  final Offset position = startLocation + totalMove;
  yield PointerUpEvent(
    timeStamp: epoch + totalTime,
    position: position,
    pointer: 1,
  );
}

enum TestScenario {
  resampleOn90Hz,
  resampleOn59Hz,
  resampleOff90Hz,
  resampleOff59Hz,
}

class ResampleFlagVariant extends TestVariant<TestScenario> {
  ResampleFlagVariant(this.binding);
  final IntegrationTestWidgetsFlutterBinding binding;

  @override
  final Set<TestScenario> values = Set<TestScenario>.from(TestScenario.values);

  late TestScenario currentValue;
  bool get resample {
    switch (currentValue) {
      case TestScenario.resampleOn90Hz:
      case TestScenario.resampleOn59Hz:
        return true;
      case TestScenario.resampleOff90Hz:
      case TestScenario.resampleOff59Hz:
        return false;
    }
  }
  double get frequency {
    switch (currentValue) {
      case TestScenario.resampleOn90Hz:
      case TestScenario.resampleOff90Hz:
        return 90.0;
      case TestScenario.resampleOn59Hz:
      case TestScenario.resampleOff59Hz:
        return 59.0;
    }
  }

  Map<String, dynamic>? result;

  @override
  String describeValue(TestScenario value) {
    switch (value) {
      case TestScenario.resampleOn90Hz:
        return 'resample on with 90Hz input';
      case TestScenario.resampleOn59Hz:
        return 'resample on with 59Hz input';
      case TestScenario.resampleOff90Hz:
        return 'resample off with 90Hz input';
      case TestScenario.resampleOff59Hz:
        return 'resample off with 59Hz input';
    }
  }

  @override
  Future<bool> setUp(TestScenario value) async {
    currentValue = value;
    final bool original = binding.resamplingEnabled;
    binding.resamplingEnabled = resample;
    return original;
  }

  @override
  Future<void> tearDown(TestScenario value, bool memento) async {
    binding.resamplingEnabled = memento;
    binding.reportData![describeValue(value)] = result;
  }
}

Future<void> main() async {
  final WidgetsBinding widgetsBinding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  assert(widgetsBinding is IntegrationTestWidgetsFlutterBinding);
  final IntegrationTestWidgetsFlutterBinding binding = widgetsBinding as IntegrationTestWidgetsFlutterBinding;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  binding.reportData ??= <String, dynamic>{};
  final ResampleFlagVariant variant = ResampleFlagVariant(binding);
  testWidgets('Smoothness test', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    final Finder scrollerFinder = find.byKey(const ValueKey<String>('complex-scroll'));
    final ListView scroller = tester.widget<ListView>(scrollerFinder);
    final ScrollController? controller = scroller.controller;
    final List<int> frameTimestamp = <int>[];
    final List<double> scrollOffset = <double>[];
    final List<Duration> delays = <Duration>[];
    binding.addPersistentFrameCallback((Duration timeStamp) {
      if (controller?.hasClients ?? false) {
        // This if is necessary because by the end of the test the widget tree
        // is destroyed.
        frameTimestamp.add(timeStamp.inMicroseconds);
        scrollOffset.add(controller!.offset);
      }
    });

    Duration now() => binding.currentSystemFrameTimeStamp;
    Future<void> scroll() async {
      // Extra 50ms to avoid timeouts.
      final Duration startTime = const Duration(milliseconds: 500) + now();
      for (final PointerEvent event in dragInputEvents(
        startTime,
        tester.getCenter(scrollerFinder),
        frequency: variant.frequency,
      )) {
        await tester.binding.delayed(event.timeStamp - now());
        // This now measures how accurate the above delayed is.
        final Duration delay = now() - event.timeStamp;
        if (delays.length < frameTimestamp.length) {
          while (delays.length < frameTimestamp.length - 1) {
            delays.add(Duration.zero);
          }
          delays.add(delay);
        } else if (delays.last < delay) {
          delays.last = delay;
        }
        tester.binding.handlePointerEventForSource(event, source: TestBindingEventSource.test);
      }
    }

    for (int n = 0; n < 5; n++) {
      await scroll();
    }
    variant.result = scrollSummary(scrollOffset, delays, frameTimestamp);
    await tester.pumpAndSettle();
    scrollOffset.clear();
    delays.clear();
    await tester.idle();
  }, semanticsEnabled: false, variant: variant);
}

Map<String, dynamic> scrollSummary(
  List<double> scrollOffset,
  List<Duration> delays,
  List<int> frameTimestamp,
) {
  double jankyCount = 0;
  double absJerkAvg = 0;
  int lostFrame = 0;
  for (int i = 1; i < scrollOffset.length-1; i += 1) {
    if (frameTimestamp[i+1] - frameTimestamp[i-1] > 40E3 ||
        (i >= delays.length || delays[i] > const Duration(milliseconds: 16))) {
      // filter data points from slow frame building or input simulation artifact
      lostFrame += 1;
      continue;
    }
    //
    final double absJerk = (scrollOffset[i-1] + scrollOffset[i+1] - 2*scrollOffset[i]).abs();
    absJerkAvg += absJerk;
    if (absJerk > 0.5) {
      jankyCount += 1;
    }
  }
  // expect(lostFrame < 0.1 * frameTimestamp.length, true);
  absJerkAvg /= frameTimestamp.length - lostFrame;

  return <String, dynamic>{
    'janky_count': jankyCount,
    'average_abs_jerk': absJerkAvg,
    'dropped_frame_count': lostFrame,
    'frame_timestamp': List<int>.from(frameTimestamp),
    'scroll_offset': List<double>.from(scrollOffset),
    'input_delay': delays.map<int>((Duration data) => data.inMicroseconds).toList(),
  };
}