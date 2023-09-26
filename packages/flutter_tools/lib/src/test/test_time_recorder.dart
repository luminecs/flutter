import 'package:meta/meta.dart';

import '../base/logger.dart';

class TestTimeRecorder {
  TestTimeRecorder(this.logger,
      {this.stopwatchFactory = const StopwatchFactory()})
      : _phaseRecords = List<TestTimeRecord>.generate(
          TestTimePhases.values.length,
          (_) => TestTimeRecord(stopwatchFactory),
        );

  final List<TestTimeRecord> _phaseRecords;
  final Logger logger;
  final StopwatchFactory stopwatchFactory;

  Stopwatch start(TestTimePhases phase) {
    return _phaseRecords[phase.index].start();
  }

  void stop(TestTimePhases phase, Stopwatch stopwatch) {
    _phaseRecords[phase.index].stop(stopwatch);
  }

  void print() {
    for (final TestTimePhases phase in TestTimePhases.values) {
      logger.printTrace(_getPrintStringForPhase(phase));
    }
  }

  @visibleForTesting
  List<String> getPrintAsListForTesting() {
    final List<String> result = <String>[];
    for (final TestTimePhases phase in TestTimePhases.values) {
      result.add(_getPrintStringForPhase(phase));
    }
    return result;
  }

  @visibleForTesting
  Stopwatch getPhaseWallClockStopwatchForTesting(final TestTimePhases phase) {
    return _phaseRecords[phase.index]._wallClockRuntime;
  }

  String _getPrintStringForPhase(final TestTimePhases phase) {
    assert(_phaseRecords[phase.index].isDone());
    return 'Runtime for phase ${phase.name}: ${_phaseRecords[phase.index]}';
  }
}

class TestTimeRecord {
  TestTimeRecord(this.stopwatchFactory)
      : _wallClockRuntime = stopwatchFactory.createStopwatch();

  final StopwatchFactory stopwatchFactory;
  Duration _combinedRuntime = Duration.zero;
  final Stopwatch _wallClockRuntime;
  int _currentlyRunningCount = 0;

  Stopwatch start() {
    final Stopwatch stopwatch = stopwatchFactory.createStopwatch()..start();
    if (_currentlyRunningCount == 0) {
      _wallClockRuntime.start();
    }
    _currentlyRunningCount++;
    return stopwatch;
  }

  void stop(Stopwatch stopwatch) {
    _currentlyRunningCount--;
    if (_currentlyRunningCount == 0) {
      _wallClockRuntime.stop();
    }
    _combinedRuntime = _combinedRuntime + stopwatch.elapsed;
    assert(_currentlyRunningCount >= 0);
  }

  @override
  String toString() {
    return 'Wall-clock: ${_wallClockRuntime.elapsed}; combined: $_combinedRuntime.';
  }

  bool isDone() {
    return _currentlyRunningCount == 0;
  }
}

enum TestTimePhases {
  TestRunner,

  Compile,

  Run,

  CoverageTotal,

  CoverageCollect,

  CoverageParseJson,

  CoverageAddHitmap,

  CoverageDataCollect,

  WatcherFinishedTest,
}
