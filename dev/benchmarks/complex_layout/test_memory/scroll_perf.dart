import 'dart:async';

import 'package:complex_layout/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const double speed = 1500.0;

const int maxIterations = 4;

const Duration pauses = Duration(milliseconds: 500);

Future<void> main() async {
  final Completer<void> ready = Completer<void>();
  runApp(GestureDetector(
    onTap: () {
      debugPrint('Received tap.');
      ready.complete();
    },
    behavior: HitTestBehavior.opaque,
    child: const IgnorePointer(
      child: ComplexLayoutApp(),
    ),
  ));
  await SchedulerBinding.instance.endOfFrame;

  await Future<void>.delayed(const Duration(milliseconds: 50));
  debugPrint('==== MEMORY BENCHMARK ==== READY ====');

  await ready.future; // waits for tap sent by devicelab task
  debugPrint('Continuing...');

  // remove onTap handler, enable pointer events for app
  runApp(GestureDetector(
    child: const IgnorePointer(
      ignoring: false,
      child: ComplexLayoutApp(),
    ),
  ));
  await SchedulerBinding.instance.endOfFrame;

  final WidgetController controller =
      LiveWidgetController(WidgetsBinding.instance);

  // Scroll down
  for (int iteration = 0; iteration < maxIterations; iteration += 1) {
    debugPrint('Scroll down... $iteration/$maxIterations');
    await controller.fling(
        find.byType(ListView), const Offset(0.0, -700.0), speed);
    await Future<void>.delayed(pauses);
  }

  // Scroll up
  for (int iteration = 0; iteration < maxIterations; iteration += 1) {
    debugPrint('Scroll up... $iteration/$maxIterations');
    await controller.fling(
        find.byType(ListView), const Offset(0.0, 300.0), speed);
    await Future<void>.delayed(pauses);
  }

  debugPrint('==== MEMORY BENCHMARK ==== DONE ====');
}
