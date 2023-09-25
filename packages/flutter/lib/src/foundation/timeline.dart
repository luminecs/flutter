// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '_timeline_io.dart'
  if (dart.library.js_util) '_timeline_web.dart' as impl;
import 'constants.dart';

abstract final class FlutterTimeline {
  static _BlockBuffer _buffer = _BlockBuffer();

  static bool get debugCollectionEnabled => _collectionEnabled;

  static set debugCollectionEnabled(bool value) {
    if (kReleaseMode) {
      throw _createReleaseModeNotSupportedError();
    }
    if (value == _collectionEnabled) {
      return;
    }
    _collectionEnabled = value;
    debugReset();
  }

  static StateError _createReleaseModeNotSupportedError() {
    return StateError('FlutterTimeline metric collection not supported in release mode.');
  }

  static bool _collectionEnabled = false;

  static void startSync(String name, { Map<String, Object?>? arguments, Flow? flow }) {
    Timeline.startSync(name, arguments: arguments, flow: flow);
    if (!kReleaseMode && _collectionEnabled) {
      _buffer.startSync(name, arguments: arguments, flow: flow);
    }
  }

  static void finishSync() {
    Timeline.finishSync();
    if (!kReleaseMode && _collectionEnabled) {
      _buffer.finishSync();
    }
  }

  static void instantSync(String name, { Map<String, Object?>? arguments }) {
    Timeline.instantSync(name, arguments: arguments);
  }

  static T timeSync<T>(String name, TimelineSyncFunction<T> function,
      { Map<String, Object?>? arguments, Flow? flow }) {
    startSync(name, arguments: arguments, flow: flow);
    try {
      return function();
    } finally {
      finishSync();
    }
  }

  static int get now => impl.performanceTimestamp.toInt();

  static AggregatedTimings debugCollect() {
    if (kReleaseMode) {
      throw _createReleaseModeNotSupportedError();
    }
    if (!_collectionEnabled) {
      throw StateError('Timeline metric collection not enabled.');
    }
    final AggregatedTimings result = AggregatedTimings(_buffer.computeTimings());
    debugReset();
    return result;
  }

  static void debugReset() {
    if (kReleaseMode) {
      throw _createReleaseModeNotSupportedError();
    }
    _buffer = _BlockBuffer();
  }
}

@immutable
final class TimedBlock {
  const TimedBlock({
    required this.name,
    required this.start,
    required this.end,
  }) : assert(end >= start, 'The start timestamp must not be greater than the end timestamp.');

  final String name;

  final double start;

  final double end;

  double get duration => end - start;

  @override
  String toString() {
    return 'TimedBlock($name, $start, $end, $duration)';
  }
}

@immutable
final class AggregatedTimings {
  AggregatedTimings(this.timedBlocks);

  final List<TimedBlock> timedBlocks;

  late final List<AggregatedTimedBlock> aggregatedBlocks = _computeAggregatedBlocks();

  List<AggregatedTimedBlock> _computeAggregatedBlocks() {
    final Map<String, (double, int)> aggregate = <String, (double, int)>{};
    for (final TimedBlock block in timedBlocks) {
      final (double, int) previousValue = aggregate.putIfAbsent(block.name, () => (0, 0));
      aggregate[block.name] = (previousValue.$1 + block.duration, previousValue.$2 + 1);
    }
    return aggregate.entries.map<AggregatedTimedBlock>(
      (MapEntry<String, (double, int)> entry) {
        return AggregatedTimedBlock(name: entry.key, duration: entry.value.$1, count: entry.value.$2);
      }
    ).toList();
  }

  AggregatedTimedBlock getAggregated(String name) {
    return aggregatedBlocks.singleWhere(
      (AggregatedTimedBlock block) => block.name == name,
      // Handle the case where there are no recorded blocks of the specified
      // type. In this case, the aggregated duration is simply zero, and so is
      // the number of occurrences (i.e. count).
      orElse: () => AggregatedTimedBlock(name: name, duration: 0, count: 0),
    );
  }
}

@immutable
final class AggregatedTimedBlock {
  const AggregatedTimedBlock({
    required this.name,
    required this.duration,
    required this.count,
  }) : assert(duration >= 0);

  final String name;

  final double duration;

  final int count;

  @override
  String toString() {
    return 'AggregatedTimedBlock($name, $duration, $count)';
  }
}

const int _kSliceSize = 500;

final class _Float64ListChain {
  _Float64ListChain();

  final List<Float64List> _chain = <Float64List>[];
  Float64List _slice = Float64List(_kSliceSize);
  int _pointer = 0;

  int get length => _length;
  int _length = 0;

  void add(double element) {
    _slice[_pointer] = element;
    _pointer += 1;
    _length += 1;
    if (_pointer >= _kSliceSize) {
      _chain.add(_slice);
      _slice = Float64List(_kSliceSize);
      _pointer = 0;
    }
  }

  List<double> extractElements() {
    final List<double> result = <double>[];
    _chain.forEach(result.addAll);
    for (int i = 0; i < _pointer; i++) {
      result.add(_slice[i]);
    }
    return result;
  }
}

final class _StringListChain {
  _StringListChain();

  final List<List<String?>> _chain = <List<String?>>[];
  List<String?> _slice = List<String?>.filled(_kSliceSize, null);
  int _pointer = 0;

  int get length => _length;
  int _length = 0;

  void add(String element) {
    _slice[_pointer] = element;
    _pointer += 1;
    _length += 1;
    if (_pointer >= _kSliceSize) {
      _chain.add(_slice);
      _slice = List<String?>.filled(_kSliceSize, null);
      _pointer = 0;
    }
  }

  List<String> extractElements() {
    final List<String> result = <String>[];
    for (final List<String?> slice in _chain) {
      for (final String? element in slice) {
        result.add(element!);
      }
    }
    for (int i = 0; i < _pointer; i++) {
      result.add(_slice[i]!);
    }
    return result;
  }
}

final class _BlockBuffer {
  // Start-finish blocks can be nested. Track this nestedness by stacking the
  // start timestamps. Finish timestamps will pop timings from the stack and
  // add the (start, finish) tuple to the _block.
  static const int _stackDepth = 1000;
  static final Float64List _startStack = Float64List(_stackDepth);
  static final List<String?> _nameStack = List<String?>.filled(_stackDepth, null);
  static int _stackPointer = 0;

  final _Float64ListChain _starts = _Float64ListChain();
  final _Float64ListChain _finishes = _Float64ListChain();
  final _StringListChain _names = _StringListChain();

  List<TimedBlock> computeTimings() {
    assert(
      _stackPointer == 0,
      'Invalid sequence of `startSync` and `finishSync`.\n'
      'The operation stack was not empty. The following operations are still '
      'waiting to be finished via the `finishSync` method:\n'
      '${List<String>.generate(_stackPointer, (int i) => _nameStack[i]!).join(', ')}'
    );

    final List<TimedBlock> result = <TimedBlock>[];
    final int length = _finishes.length;
    final List<double> starts = _starts.extractElements();
    final List<double> finishes = _finishes.extractElements();
    final List<String> names = _names.extractElements();

    assert(starts.length == length);
    assert(finishes.length == length);
    assert(names.length == length);

    for (int i = 0; i < length; i++) {
      result.add(TimedBlock(
        start: starts[i],
        end: finishes[i],
        name: names[i],
      ));
    }

    return result;
  }

  void startSync(String name, { Map<String, Object?>? arguments, Flow? flow }) {
    _startStack[_stackPointer] = impl.performanceTimestamp;
    _nameStack[_stackPointer] = name;
    _stackPointer += 1;
  }

  void finishSync() {
    assert(
      _stackPointer > 0,
      'Invalid sequence of `startSync` and `finishSync`.\n'
      'Attempted to finish timing a block of code, but there are no pending '
      '`startSync` calls.'
    );

    final double finishTime = impl.performanceTimestamp;
    final double startTime = _startStack[_stackPointer - 1];
    final String name = _nameStack[_stackPointer - 1]!;
    _stackPointer -= 1;

    _starts.add(startTime);
    _finishes.add(finishTime);
    _names.add(name);
  }
}