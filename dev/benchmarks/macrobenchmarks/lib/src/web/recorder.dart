
import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

const int _kDefaultWarmUpSampleCount = 200;

const int _kDefaultMeasuredSampleCount = 100;

const int kDefaultTotalSampleCount = _kDefaultWarmUpSampleCount + _kDefaultMeasuredSampleCount;

const String kProfilePrerollFrame = 'preroll_frame';

const String kProfileApplyFrame = 'apply_frame';

Duration timeAction(VoidCallback action) {
  final Stopwatch stopwatch = Stopwatch()..start();
  action();
  stopwatch.stop();
  return stopwatch.elapsed;
}

Future<Duration> timeAsyncAction(AsyncCallback action) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  return stopwatch.elapsed;
}

typedef AsyncVoidCallback = Future<void> Function();

Future<void> _dummyAsyncVoidCallback() async {}

@sealed
class Runner {
  Runner({
    required this.recorder,
    this.setUpAllDidRun = _dummyAsyncVoidCallback,
    this.tearDownAllWillRun = _dummyAsyncVoidCallback,
  });

  final Recorder recorder;

  final AsyncVoidCallback setUpAllDidRun;

  final AsyncVoidCallback tearDownAllWillRun;

  Future<Profile> run() async {
    await recorder.setUpAll();
    await setUpAllDidRun();
    final Profile profile = await recorder.run();
    await tearDownAllWillRun();
    await recorder.tearDownAll();
    return profile;
  }
}

abstract class Recorder {
  Recorder._(this.name, this.isTracingEnabled);

  final bool isTracingEnabled;

  final String name;

  Profile? get profile;

  bool shouldContinue() => profile?.shouldContinue() ?? true;

  Future<void> setUpAll() async {}

  Future<Profile> run();

  Future<void> tearDownAll() async {}
}

abstract class RawRecorder extends Recorder {
  RawRecorder({required String name, bool useCustomWarmUp = false})
    : _useCustomWarmUp = useCustomWarmUp, super._(name, false);

  final bool _useCustomWarmUp;

  FutureOr<void> body(Profile profile);

  @override
  Profile? get profile => _profile;
  Profile? _profile;

  @override
  @nonVirtual
  Future<Profile> run() async {
    _profile = Profile(name: name, useCustomWarmUp: _useCustomWarmUp);
    do {
      await Future<void>.delayed(Duration.zero);
      final FutureOr<void> result = body(_profile!);
      if (result is Future) {
        await result;
      }
    } while (shouldContinue());
    return _profile!;
  }
}

abstract class SceneBuilderRecorder extends Recorder {
  SceneBuilderRecorder({required String name}) : super._(name, true);

  @override
  Profile? get profile => _profile;
  Profile? _profile;

  @mustCallSuper
  void onBeginFrame() {}

  void onDrawFrame(SceneBuilder sceneBuilder);

  @override
  Future<Profile> run() {
    final Completer<Profile> profileCompleter = Completer<Profile>();
    _profile = Profile(name: name);

    PlatformDispatcher.instance.onBeginFrame = (_) {
      try {
        startMeasureFrame(profile!);
        onBeginFrame();
      } catch (error, stackTrace) {
        profileCompleter.completeError(error, stackTrace);
        rethrow;
      }
    };
    PlatformDispatcher.instance.onDrawFrame = () {
      try {
        _profile!.record('drawFrameDuration', () {
          final SceneBuilder sceneBuilder = SceneBuilder();
          onDrawFrame(sceneBuilder);
          _profile!.record('sceneBuildDuration', () {
            final Scene scene = sceneBuilder.build();
            _profile!.record('windowRenderDuration', () {
              view.render(scene);
            }, reported: false);
          }, reported: false);
        }, reported: true);
        endMeasureFrame();

        if (shouldContinue()) {
          PlatformDispatcher.instance.scheduleFrame();
        } else {
          profileCompleter.complete(_profile);
        }
      } catch (error, stackTrace) {
        profileCompleter.completeError(error, stackTrace);
        rethrow;
      }
    };
    PlatformDispatcher.instance.scheduleFrame();
    return profileCompleter.future;
  }

  FlutterView get view {
    assert(PlatformDispatcher.instance.implicitView != null, 'This benchmark requires the embedder to provide an implicit view.');
    return PlatformDispatcher.instance.implicitView!;
  }
}

abstract class WidgetRecorder extends Recorder implements FrameRecorder {
  WidgetRecorder({
    required String name,
    this.useCustomWarmUp = false,
  }) : super._(name, true);

  Widget createWidget();

  final List<VoidCallback> _didStopCallbacks = <VoidCallback>[];
  @override
  void registerDidStop(VoidCallback cb) {
    _didStopCallbacks.add(cb);
  }

  @override
  Profile? profile;
  Completer<void>? _runCompleter;

  final bool useCustomWarmUp;

  late Stopwatch _drawFrameStopwatch;

  @override
  @mustCallSuper
  void frameWillDraw() {
    startMeasureFrame(profile!);
    _drawFrameStopwatch = Stopwatch()..start();
  }

  @override
  @mustCallSuper
  void frameDidDraw() {
    endMeasureFrame();
    profile!.addDataPoint('drawFrameDuration', _drawFrameStopwatch.elapsed, reported: true);

    if (shouldContinue()) {
      PlatformDispatcher.instance.scheduleFrame();
    } else {
      for (final VoidCallback fn in _didStopCallbacks) {
        fn();
      }
      _runCompleter!.complete();
    }
  }

  @override
  void _onError(Object error, StackTrace? stackTrace) {
    _runCompleter!.completeError(error, stackTrace);
  }

  late final _RecordingWidgetsBinding _binding;

  @override
  @mustCallSuper
  Future<void> setUpAll() async {
    _binding = _RecordingWidgetsBinding.ensureInitialized();
  }

  @override
  Future<Profile> run() async {
    _runCompleter = Completer<void>();
    final Profile localProfile = profile = Profile(name: name, useCustomWarmUp: useCustomWarmUp);
    final Widget widget = createWidget();

    registerEngineBenchmarkValueListener(kProfilePrerollFrame, (num value) {
      localProfile.addDataPoint(
        kProfilePrerollFrame,
        Duration(microseconds: value.toInt()),
        reported: false,
      );
    });
    registerEngineBenchmarkValueListener(kProfileApplyFrame, (num value) {
      localProfile.addDataPoint(
        kProfileApplyFrame,
        Duration(microseconds: value.toInt()),
        reported: false,
      );
    });

    _binding._beginRecording(this, widget);

    try {
      await _runCompleter!.future;
      return localProfile;
    } finally {
      stopListeningToEngineBenchmarkValues(kProfilePrerollFrame);
      stopListeningToEngineBenchmarkValues(kProfileApplyFrame);
      _runCompleter = null;
      profile = null;
    }
  }
}

abstract class WidgetBuildRecorder extends Recorder implements FrameRecorder {
  WidgetBuildRecorder({required String name}) : super._(name, true);

  Widget createWidget();

  final List<VoidCallback> _didStopCallbacks = <VoidCallback>[];
  @override
  void registerDidStop(VoidCallback cb) {
    _didStopCallbacks.add(cb);
  }

  @override
  Profile? profile;
  Completer<void>? _runCompleter;

  late Stopwatch _drawFrameStopwatch;

  bool showWidget = true;

  late _WidgetBuildRecorderHostState _hostState;

  Widget? _getWidgetForFrame() {
    if (showWidget) {
      return createWidget();
    } else {
      return null;
    }
  }

  late final _RecordingWidgetsBinding _binding;

  @override
  @mustCallSuper
  Future<void> setUpAll() async {
    _binding = _RecordingWidgetsBinding.ensureInitialized();
  }

  @override
  @mustCallSuper
  void frameWillDraw() {
    if (showWidget) {
      startMeasureFrame(profile!);
      _drawFrameStopwatch = Stopwatch()..start();
    }
  }

  @override
  @mustCallSuper
  void frameDidDraw() {
    // Only record frames that show the widget.
    if (showWidget) {
      endMeasureFrame();
      profile!.addDataPoint('drawFrameDuration', _drawFrameStopwatch.elapsed, reported: true);
    }

    if (shouldContinue()) {
      showWidget = !showWidget;
      _hostState._setStateTrampoline();
    } else {
      for (final VoidCallback fn in _didStopCallbacks) {
        fn();
      }
      _runCompleter!.complete();
    }
  }

  @override
  void _onError(Object error, StackTrace? stackTrace) {
    _runCompleter!.completeError(error, stackTrace);
  }

  @override
  Future<Profile> run() async {
    _runCompleter = Completer<void>();
    final Profile localProfile = profile = Profile(name: name);
    _binding._beginRecording(this, _WidgetBuildRecorderHost(this));

    try {
      await _runCompleter!.future;
      return localProfile;
    } finally {
      _runCompleter = null;
      profile = null;
    }
  }
}

class _WidgetBuildRecorderHost extends StatefulWidget {
  const _WidgetBuildRecorderHost(this.recorder);

  final WidgetBuildRecorder recorder;

  @override
  State<StatefulWidget> createState() => _WidgetBuildRecorderHostState();
}

class _WidgetBuildRecorderHostState extends State<_WidgetBuildRecorderHost> {
  @override
  void initState() {
    super.initState();
    widget.recorder._hostState = this;
  }

  // This is just to bypass the @protected on setState.
  void _setStateTrampoline() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: widget.recorder._getWidgetForFrame(),
    );
  }
}

class Timeseries {
  Timeseries(this.name, this.isReported);

  final String name;

  final bool isReported;

  int _warmUpSampleCount = 0;

  final List<double> _allValues = <double>[];

  int get count => _allValues.length;

  TimeseriesStats computeStats() {
    // Assertions do not use the `assert` keyword because benchmarks run in
    // profile mode, where asserts are tree-shaken out.
    if (_warmUpSampleCount == 0) {
      throw StateError(
        'The benchmark did not warm-up. Use at least one sample to warm-up '
        'the benchmark to reduce noise.');
    }
    if (_warmUpSampleCount >= count) {
      throw StateError(
        'The benchmark did not report any measured samples. Add at least one '
        'sample after warm-up is done. There were $_warmUpSampleCount warm-up '
        'samples, and no measured samples in this timeseries.'
      );
    }

    // The first few values we simply discard and never look at. They're from the warm-up phase.
    final List<double> warmUpValues = _allValues.sublist(0, _warmUpSampleCount);

    // Values we analyze.
    final List<double> candidateValues = _allValues.sublist(_warmUpSampleCount);

    // The average that includes outliers.
    final double dirtyAverage = _computeAverage(name, candidateValues);

    // The standard deviation that includes outliers.
    final double dirtyStandardDeviation = _computeStandardDeviationForPopulation(name, candidateValues);

    // Any value that's higher than this is considered an outlier.
    // Two standard deviations captures 95% of a normal distribution.
    final double outlierCutOff = dirtyAverage + dirtyStandardDeviation * 2;

    // Candidates with outliers removed.
    final Iterable<double> cleanValues = candidateValues.where((double value) => value <= outlierCutOff);

    // Outlier candidates.
    final Iterable<double> outliers = candidateValues.where((double value) => value > outlierCutOff);

    // Final statistics.
    final double cleanAverage = _computeAverage(name, cleanValues);
    final double standardDeviation = _computeStandardDeviationForPopulation(name, cleanValues);
    final double noise = cleanAverage > 0.0 ? standardDeviation / cleanAverage : 0.0;

    // Compute outlier average. If there are no outliers the outlier average is
    // the same as clean value average. In other words, in a perfect benchmark
    // with no noise the difference between average and outlier average is zero,
    // which the best possible outcome. Noise produces a positive difference
    // between the two.
    final double outlierAverage = outliers.isNotEmpty ? _computeAverage(name, outliers) : cleanAverage;

    final List<AnnotatedSample> annotatedValues = <AnnotatedSample>[
      for (final double warmUpValue in warmUpValues)
        AnnotatedSample(
          magnitude: warmUpValue,
          isOutlier: warmUpValue > outlierCutOff,
          isWarmUpValue: true,
        ),
      for (final double candidate in candidateValues)
        AnnotatedSample(
          magnitude: candidate,
          isOutlier: candidate > outlierCutOff,
          isWarmUpValue: false,
        ),
    ];

    return TimeseriesStats(
      name: name,
      average: cleanAverage,
      outlierCutOff: outlierCutOff,
      outlierAverage: outlierAverage,
      standardDeviation: standardDeviation,
      noise: noise,
      cleanSampleCount: cleanValues.length,
      outlierSampleCount: outliers.length,
      samples: annotatedValues,
    );
  }

  // Whether the timeseries is in the warm-up phase.
  bool _isWarmingUp = true;

  void add(double value, {required bool isWarmUpValue}) {
    if (value < 0.0) {
      throw StateError(
        'Timeseries $name: negative metric values are not supported. Got: $value',
      );
    }
    if (isWarmUpValue) {
      if (!_isWarmingUp) {
        throw StateError(
          'A warm-up value was added to the timeseries after the warm-up phase finished.'
        );
      }
      _warmUpSampleCount += 1;
    } else if (_isWarmingUp) {
      _isWarmingUp = false;
    }
    _allValues.add(value);
  }
}

@sealed
class TimeseriesStats {
  const TimeseriesStats({
    required this.name,
    required this.average,
    required this.outlierCutOff,
    required this.outlierAverage,
    required this.standardDeviation,
    required this.noise,
    required this.cleanSampleCount,
    required this.outlierSampleCount,
    required this.samples,
  });

  final String name;

  final double average;

  final double standardDeviation;

  final double noise;

  final double outlierCutOff;

  final double outlierAverage;

  final int cleanSampleCount;

  final int outlierSampleCount;

  final List<AnnotatedSample> samples;

  double get outlierRatio => average > 0.0
    ? outlierAverage / average
    : 1.0; // this can only happen in perfect benchmark that reports only zeros

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      '$name: (samples: $cleanSampleCount clean/$outlierSampleCount '
      'outliers/${cleanSampleCount + outlierSampleCount} '
      'measured/${samples.length} total)');
    buffer.writeln(' | average: $average μs');
    buffer.writeln(' | outlier average: $outlierAverage μs');
    buffer.writeln(' | outlier/clean ratio: ${outlierRatio}x');
    buffer.writeln(' | noise: ${_ratioToPercent(noise)}');
    return buffer.toString();
  }
}

@sealed
class AnnotatedSample {
  const AnnotatedSample({
    required this.magnitude,
    required this.isOutlier,
    required this.isWarmUpValue,
  });

  final double magnitude;

  final bool isOutlier;

  final bool isWarmUpValue;
}

class Profile {
  Profile({required this.name, this.useCustomWarmUp = false});

  final String name;

  final bool useCustomWarmUp;

  bool get isWarmingUp => _isWarmingUp;
  bool _isWarmingUp = true;

  bool get isRunning => _isRunning;
  bool _isRunning = true;

  void stopWarmingUp() {
    if (!_isWarmingUp) {
      throw StateError('Warm-up already stopped.');
    } else {
      _isWarmingUp = false;
    }
  }

  void stopBenchmark() {
    if (_isWarmingUp) {
      throw StateError(
        'Warm-up has not finished yet. Benchmark should only be stopped after '
        'it recorded at least one sample after the warm-up.'
      );
    } else if (scoreData.isEmpty) {
      throw StateError(
        'The benchmark did not collect any data.'
      );
    } else {
      _isRunning = false;
    }
  }

  final Map<String, Timeseries> scoreData = <String, Timeseries>{};

  final Map<String, dynamic> extraData = <String, dynamic>{};

  Duration record(String key, VoidCallback callback, { required bool reported }) {
    final Duration duration = timeAction(callback);
    addDataPoint(key, duration, reported: reported);
    return duration;
  }

  Future<Duration> recordAsync(String key, AsyncCallback callback, { required bool reported }) async {
    final Duration duration = await timeAsyncAction(callback);
    addDataPoint(key, duration, reported: reported);
    return duration;
  }

  void addDataPoint(String key, Duration duration, { required bool reported }) {
    scoreData.putIfAbsent(
        key,
        () => Timeseries(key, reported),
    ).add(duration.inMicroseconds.toDouble(), isWarmUpValue: isWarmingUp);

    if (!useCustomWarmUp) {
      // The stopWarmingUp and stopBenchmark will not be called. Use the
      // auto-stopping logic.
      _autoUpdateBenchmarkPhase();
    }
  }

  void addTimedBlock(AggregatedTimedBlock timedBlock, { required bool reported }) {
    addDataPoint(timedBlock.name, Duration(microseconds: timedBlock.duration.toInt()), reported: reported);
  }

  void _autoUpdateBenchmarkPhase() {
    if (useCustomWarmUp) {
      StateError(
        'Must not call _autoUpdateBenchmarkPhase if custom warm-up is used. '
        'Call `stopWarmingUp` and `stopBenchmark` instead.'
      );
    }

    if (_isWarmingUp) {
      final bool doesHaveEnoughWarmUpSamples = scoreData.keys
        .every((String key) => scoreData[key]!.count >= _kDefaultWarmUpSampleCount);
      if (doesHaveEnoughWarmUpSamples) {
        stopWarmingUp();
      }
    } else if (_isRunning) {
      final bool doesHaveEnoughTotalSamples = scoreData.keys
        .every((String key) => scoreData[key]!.count >= kDefaultTotalSampleCount);
      if (doesHaveEnoughTotalSamples) {
        stopBenchmark();
      }
    }
  }

  bool shouldContinue() {
    // If there are no `Timeseries` in the `scoreData`, then we haven't
    // recorded anything yet. Don't stop.
    if (scoreData.isEmpty) {
      return true;
    }

    return isRunning;
  }

  Map<String, dynamic> toJson() {
    final List<String> scoreKeys = <String>[];
    final Map<String, dynamic> json = <String, dynamic>{
      'name': name,
      'scoreKeys': scoreKeys,
    };

    for (final String key in scoreData.keys) {
      final Timeseries timeseries = scoreData[key]!;

      if (timeseries.isReported) {
        scoreKeys.add('$key.average');
        // Report `outlierRatio` rather than `outlierAverage`, because
        // the absolute value of outliers is less interesting than the
        // ratio.
        scoreKeys.add('$key.outlierRatio');
      }

      final TimeseriesStats stats = timeseries.computeStats();
      json['$key.average'] = stats.average;
      json['$key.outlierAverage'] = stats.outlierAverage;
      json['$key.outlierRatio'] = stats.outlierRatio;
      json['$key.noise'] = stats.noise;
    }

    json.addAll(extraData);

    return json;
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('name: $name');
    for (final String key in scoreData.keys) {
      final Timeseries timeseries = scoreData[key]!;
      final TimeseriesStats stats = timeseries.computeStats();
      buffer.writeln(stats.toString());
    }
    for (final String key in extraData.keys) {
      final dynamic value = extraData[key];
      if (value is List) {
        buffer.writeln('$key:');
        for (final dynamic item in value) {
          buffer.writeln(' - $item');
        }
      } else {
        buffer.writeln('$key: $value');
      }
    }
    return buffer.toString();
  }
}

double _computeAverage(String label, Iterable<double> values) {
  if (values.isEmpty) {
    throw StateError('$label: attempted to compute an average of an empty value list.');
  }

  final double sum = values.reduce((double a, double b) => a + b);
  return sum / values.length;
}

double _computeStandardDeviationForPopulation(String label, Iterable<double> population) {
  if (population.isEmpty) {
    throw StateError('$label: attempted to compute the standard deviation of empty population.');
  }
  final double mean = _computeAverage(label, population);
  final double sumOfSquaredDeltas = population.fold<double>(
    0.0,
    (double previous, double value) => previous += math.pow(value - mean, 2),
  );
  return math.sqrt(sumOfSquaredDeltas / population.length);
}

String _ratioToPercent(double value) {
  return '${(value * 100).toStringAsFixed(2)}%';
}

abstract class FrameRecorder {
  void registerDidStop(VoidCallback cb);

  void frameWillDraw();

  void frameDidDraw();

  void _onError(Object error, StackTrace? stackTrace);
}

class _RecordingWidgetsBinding extends BindingBase
    with
        GestureBinding,
        SchedulerBinding,
        ServicesBinding,
        PaintingBinding,
        SemanticsBinding,
        RendererBinding,
        WidgetsBinding {

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static _RecordingWidgetsBinding get instance => BindingBase.checkInstance(_instance);
  static _RecordingWidgetsBinding? _instance;

  static _RecordingWidgetsBinding ensureInitialized() {
    if (_instance == null) {
      _RecordingWidgetsBinding();
    }
    return instance;
  }

  FrameRecorder? _recorder;
  bool _hasErrored = false;

  bool _benchmarkStopped = false;

  void _beginRecording(FrameRecorder recorder, Widget widget) {
    if (_recorder != null) {
      throw Exception(
        'Cannot call _RecordingWidgetsBinding._beginRecording more than once',
      );
    }
    final FlutterExceptionHandler? originalOnError = FlutterError.onError;

    recorder.registerDidStop(() {
      _benchmarkStopped = true;
    });

    // Fail hard and fast on errors. Benchmarks should not have any errors.
    FlutterError.onError = (FlutterErrorDetails details) {
      _haltBenchmarkWithError(details.exception, details.stack);
      originalOnError?.call(details);
    };
    _recorder = recorder;
    runApp(widget);
  }

  void _haltBenchmarkWithError(Object error, StackTrace? stackTrace) {
    if (_hasErrored) {
      return;
    }
    _recorder?._onError(error, stackTrace);
    _hasErrored = true;
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    // Don't keep on truckin' if there's an error or the benchmark has stopped.
    if (_hasErrored || _benchmarkStopped) {
      return;
    }
    try {
      super.handleBeginFrame(rawTimeStamp);
    } catch (error, stackTrace) {
      _haltBenchmarkWithError(error, stackTrace);
      rethrow;
    }
  }

  @override
  void scheduleFrame() {
    // Don't keep on truckin' if there's an error or the benchmark has stopped.
    if (_hasErrored || _benchmarkStopped) {
      return;
    }
    super.scheduleFrame();
  }

  @override
  void handleDrawFrame() {
    // Don't keep on truckin' if there's an error or the benchmark has stopped.
    if (_hasErrored || _benchmarkStopped) {
      return;
    }
    try {
      _recorder?.frameWillDraw();
      super.handleDrawFrame();
      _recorder?.frameDidDraw();
    } catch (error, stackTrace) {
      _haltBenchmarkWithError(error, stackTrace);
      rethrow;
    }
  }
}

int _currentFrameNumber = 1;

bool _calledStartMeasureFrame = false;

bool _isMeasuringFrame = false;

void startMeasureFrame(Profile profile) {
  if (_calledStartMeasureFrame) {
    throw Exception('`startMeasureFrame` called twice in a row.');
  }

  _calledStartMeasureFrame = true;

  if (!profile.isWarmingUp) {
    // Tell the browser to mark the beginning of the frame.
    web.window.performance.mark('measured_frame_start#$_currentFrameNumber');
    _isMeasuringFrame = true;
  }
}

void endMeasureFrame() {
  if (!_calledStartMeasureFrame) {
    throw Exception('`startMeasureFrame` has not been called before calling `endMeasureFrame`');
  }

  _calledStartMeasureFrame = false;

  if (_isMeasuringFrame) {
    // Tell the browser to mark the end of the frame, and measure the duration.
    web.window.performance.mark('measured_frame_end#$_currentFrameNumber');
    web.window.performance.measure(
      'measured_frame',
      'measured_frame_start#$_currentFrameNumber'.toJS,
      'measured_frame_end#$_currentFrameNumber',
    );

    // Increment the current frame number.
    _currentFrameNumber += 1;

    _isMeasuringFrame = false;
  }
}

typedef EngineBenchmarkValueListener = void Function(num value);

// Maps from a value label name to a listener.
final Map<String, EngineBenchmarkValueListener> _engineBenchmarkListeners = <String, EngineBenchmarkValueListener>{};

void registerEngineBenchmarkValueListener(String name, EngineBenchmarkValueListener listener) {
  if (_engineBenchmarkListeners.containsKey(name)) {
    throw StateError(
      'A listener for "$name" is already registered.\n'
      'Call `stopListeningToEngineBenchmarkValues` to unregister the previous '
      'listener before registering a new one.'
    );
  }

  if (_engineBenchmarkListeners.isEmpty) {
    // The first listener is being registered. Register the global listener.
    ui_web.benchmarkValueCallback = _dispatchEngineBenchmarkValue;
  }
  _engineBenchmarkListeners[name] = listener;
}

void stopListeningToEngineBenchmarkValues(String name) {
  _engineBenchmarkListeners.remove(name);
  if (_engineBenchmarkListeners.isEmpty) {

    // The last listener unregistered. Remove the global listener.
    ui_web.benchmarkValueCallback = null;
  }
}

// Dispatches a benchmark value reported by the engine to the relevant listener.
//
// If there are no listeners registered for [name], ignores the value.
void _dispatchEngineBenchmarkValue(String name, double value) {
  final EngineBenchmarkValueListener? listener = _engineBenchmarkListeners[name];
  if (listener != null) {
    listener(value);
  }
}