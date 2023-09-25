
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import 'material3.dart';
import 'recorder.dart';

class BenchMaterial3Semantics extends WidgetBuildRecorder {
  BenchMaterial3Semantics() : super(name: benchmarkName);

  static const String benchmarkName = 'bench_material3_semantics';

  @override
  Future<void> setUpAll() async {
    FlutterTimeline.debugCollectionEnabled = true;
    super.setUpAll();
    SemanticsBinding.instance.ensureSemantics();
  }

  @override
  Future<void> tearDownAll() async {
    FlutterTimeline.debugReset();
  }

  @override
  void frameDidDraw() {
    // Only record frames that show the widget. Frames that remove the widget
    // are not interesting.
    if (showWidget) {
      final AggregatedTimings timings = FlutterTimeline.debugCollect();
      final AggregatedTimedBlock semanticsBlock = timings.getAggregated('SEMANTICS');
      final AggregatedTimedBlock getFragmentBlock = timings.getAggregated('Semantics.GetFragment');
      final AggregatedTimedBlock compileChildrenBlock = timings.getAggregated('Semantics.compileChildren');
      profile!.addTimedBlock(semanticsBlock, reported: true);
      profile!.addTimedBlock(getFragmentBlock, reported: true);
      profile!.addTimedBlock(compileChildrenBlock, reported: true);
    }

    super.frameDidDraw();
    FlutterTimeline.debugReset();
  }

  @override
  Widget createWidget() {
    return const SingleColumnMaterial3Components();
  }
}

class BenchMaterial3ScrollSemantics extends WidgetRecorder {
  BenchMaterial3ScrollSemantics() : super(name: benchmarkName);

  static const String benchmarkName = 'bench_material3_scroll_semantics';

  @override
  Future<void> setUpAll() async {
    FlutterTimeline.debugCollectionEnabled = true;
    super.setUpAll();
    SemanticsBinding.instance.ensureSemantics();
  }

  @override
  Future<void> tearDownAll() async {
    FlutterTimeline.debugReset();
  }

  @override
  void frameDidDraw() {
    final AggregatedTimings timings = FlutterTimeline.debugCollect();
    final AggregatedTimedBlock semanticsBlock = timings.getAggregated('SEMANTICS');
    final AggregatedTimedBlock getFragmentBlock = timings.getAggregated('Semantics.GetFragment');
    final AggregatedTimedBlock compileChildrenBlock = timings.getAggregated('Semantics.compileChildren');
    profile!.addTimedBlock(semanticsBlock, reported: true);
    profile!.addTimedBlock(getFragmentBlock, reported: true);
    profile!.addTimedBlock(compileChildrenBlock, reported: true);

    super.frameDidDraw();
    FlutterTimeline.debugReset();
  }

  @override
  Widget createWidget() => _ScrollTest();
}

class _ScrollTest extends StatefulWidget {
  @override
  State<_ScrollTest> createState() => _ScrollTestState();
}

class _ScrollTestState extends State<_ScrollTest> with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();

    scrollController = ScrollController();

    bool forward = true;

    // A one-off timer is necessary to allow the framework to measure the
    // available scroll extents before the scroll controller can be exercised
    // to change the scroll position.
    Timer.run(() {
      ticker = createTicker((_) {
        scrollController.jumpTo(forward ? 1 : 0);
        forward = !forward;
      });
      ticker.start();
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleColumnMaterial3Components(
      scrollController: scrollController,
    );
  }
}