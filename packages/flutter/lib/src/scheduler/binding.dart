import 'dart:async';
import 'dart:collection';
import 'dart:developer' show Flow, Timeline, TimelineTask;
import 'dart:ui' show AppLifecycleState, DartPerformanceMode, FramePhase, FrameTiming, PlatformDispatcher, TimingsCallback;

import 'package:collection/collection.dart' show HeapPriorityQueue, PriorityQueue;
import 'package:flutter/foundation.dart';

import 'debug.dart';
import 'priority.dart';
import 'service_extensions.dart';

export 'dart:ui' show AppLifecycleState, FrameTiming, TimingsCallback;

export 'priority.dart' show Priority;

double get timeDilation => _timeDilation;
double _timeDilation = 1.0;
set timeDilation(double value) {
  assert(value > 0.0);
  if (_timeDilation == value) {
    return;
  }
  // If the binding has been created, we need to resetEpoch first so that we
  // capture start of the epoch with the current time dilation.
  SchedulerBinding._instance?.resetEpoch();
  _timeDilation = value;
}

typedef FrameCallback = void Function(Duration timeStamp);

typedef TaskCallback<T> = FutureOr<T> Function();

typedef SchedulingStrategy = bool Function({ required int priority, required SchedulerBinding scheduler });

class _TaskEntry<T> {
  _TaskEntry(this.task, this.priority, this.debugLabel, this.flow) {
    assert(() {
      debugStack = StackTrace.current;
      return true;
    }());
  }
  final TaskCallback<T> task;
  final int priority;
  final String? debugLabel;
  final Flow? flow;

  late StackTrace debugStack;
  final Completer<T> completer = Completer<T>();

  void run() {
    if (!kReleaseMode) {
      Timeline.timeSync(
        debugLabel ?? 'Scheduled Task',
        () {
          completer.complete(task());
        },
        flow: flow != null ? Flow.step(flow!.id) : null,
      );
    } else {
      completer.complete(task());
    }
  }
}

class _FrameCallbackEntry {
  _FrameCallbackEntry(this.callback, { bool rescheduling = false }) {
    assert(() {
      if (rescheduling) {
        assert(() {
          if (debugCurrentCallbackStack == null) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('scheduleFrameCallback called with rescheduling true, but no callback is in scope.'),
              ErrorDescription(
                'The "rescheduling" argument should only be set to true if the '
                'callback is being reregistered from within the callback itself, '
                'and only then if the callback itself is entirely synchronous.',
              ),
              ErrorHint(
                'If this is the initial registration of the callback, or if the '
                'callback is asynchronous, then do not use the "rescheduling" '
                'argument.',
              ),
            ]);
          }
          return true;
        }());
        debugStack = debugCurrentCallbackStack;
      } else {
        // TODO(ianh): trim the frames from this library, so that the call to scheduleFrameCallback is the top one
        debugStack = StackTrace.current;
      }
      return true;
    }());
  }

  final FrameCallback callback;

  static StackTrace? debugCurrentCallbackStack;
  StackTrace? debugStack;
}

enum SchedulerPhase {
  idle,

  transientCallbacks,

  midFrameMicrotasks,

  persistentCallbacks,

  postFrameCallbacks,
}

typedef _PerformanceModeCleanupCallback = VoidCallback;

class PerformanceModeRequestHandle {
  PerformanceModeRequestHandle._(_PerformanceModeCleanupCallback this._cleanup);

  _PerformanceModeCleanupCallback? _cleanup;

  void dispose() {
    assert(_cleanup != null);
    _cleanup!();
    _cleanup = null;
  }
}

mixin SchedulerBinding on BindingBase {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;

    if (!kReleaseMode) {
      addTimingsCallback((List<FrameTiming> timings) {
        timings.forEach(_profileFramePostEvent);
      });
    }
  }

  static SchedulerBinding get instance => BindingBase.checkInstance(_instance);
  static SchedulerBinding? _instance;

  final List<TimingsCallback> _timingsCallbacks = <TimingsCallback>[];

  void addTimingsCallback(TimingsCallback callback) {
    _timingsCallbacks.add(callback);
    if (_timingsCallbacks.length == 1) {
      assert(platformDispatcher.onReportTimings == null);
      platformDispatcher.onReportTimings = _executeTimingsCallbacks;
    }
    assert(platformDispatcher.onReportTimings == _executeTimingsCallbacks);
  }

  void removeTimingsCallback(TimingsCallback callback) {
    assert(_timingsCallbacks.contains(callback));
    _timingsCallbacks.remove(callback);
    if (_timingsCallbacks.isEmpty) {
      platformDispatcher.onReportTimings = null;
    }
  }

  @pragma('vm:notify-debugger-on-exception')
  void _executeTimingsCallbacks(List<FrameTiming> timings) {
    final List<TimingsCallback> clonedCallbacks =
        List<TimingsCallback>.of(_timingsCallbacks);
    for (final TimingsCallback callback in clonedCallbacks) {
      try {
        if (_timingsCallbacks.contains(callback)) {
          callback(timings);
        }
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<TimingsCallback>(
              'The TimingsCallback that gets executed was',
              callback,
              style: DiagnosticsTreeStyle.errorProperty,
            ),
          ];
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: ErrorDescription('while executing callbacks for FrameTiming'),
          informationCollector: collector,
        ));
      }
    }
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    if (!kReleaseMode) {
      registerNumericServiceExtension(
        name: SchedulerServiceExtensions.timeDilation.name,
        getter: () async => timeDilation,
        setter: (double value) async {
          timeDilation = value;
        },
      );
    }
  }

  AppLifecycleState? get lifecycleState => _lifecycleState;
  AppLifecycleState? _lifecycleState;

  @visibleForTesting
  void resetLifecycleState() {
    _lifecycleState = null;
  }

  @protected
  @mustCallSuper
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    if (lifecycleState == state) {
      return;
    }
    _lifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        _setFramesEnabledState(true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setFramesEnabledState(false);
    }
  }

  SchedulingStrategy schedulingStrategy = defaultSchedulingStrategy;

  static int _taskSorter (_TaskEntry<dynamic> e1, _TaskEntry<dynamic> e2) {
    return -e1.priority.compareTo(e2.priority);
  }
  final PriorityQueue<_TaskEntry<dynamic>> _taskQueue = HeapPriorityQueue<_TaskEntry<dynamic>>(_taskSorter);

  Future<T> scheduleTask<T>(
    TaskCallback<T> task,
    Priority priority, {
    String? debugLabel,
    Flow? flow,
  }) {
    final bool isFirstTask = _taskQueue.isEmpty;
    final _TaskEntry<T> entry = _TaskEntry<T>(
      task,
      priority.value,
      debugLabel,
      flow,
    );
    _taskQueue.add(entry);
    if (isFirstTask && !locked) {
      _ensureEventLoopCallback();
    }
    return entry.completer.future;
  }

  @override
  void unlocked() {
    super.unlocked();
    if (_taskQueue.isNotEmpty) {
      _ensureEventLoopCallback();
    }
  }

  // Whether this scheduler already requested to be called from the event loop.
  bool _hasRequestedAnEventLoopCallback = false;

  // Ensures that the scheduler services a task scheduled by
  // [SchedulerBinding.scheduleTask].
  void _ensureEventLoopCallback() {
    assert(!locked);
    assert(_taskQueue.isNotEmpty);
    if (_hasRequestedAnEventLoopCallback) {
      return;
    }
    _hasRequestedAnEventLoopCallback = true;
    Timer.run(_runTasks);
  }

  // Scheduled by _ensureEventLoopCallback.
  void _runTasks() {
    _hasRequestedAnEventLoopCallback = false;
    if (handleEventLoopCallback()) {
      _ensureEventLoopCallback();
    } // runs next task when there's time
  }

  @visibleForTesting
  @pragma('vm:notify-debugger-on-exception')
  bool handleEventLoopCallback() {
    if (_taskQueue.isEmpty || locked) {
      return false;
    }
    final _TaskEntry<dynamic> entry = _taskQueue.first;
    if (schedulingStrategy(priority: entry.priority, scheduler: this)) {
      try {
        _taskQueue.removeFirst();
        entry.run();
      } catch (exception, exceptionStack) {
        StackTrace? callbackStack;
        assert(() {
          callbackStack = entry.debugStack;
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: exceptionStack,
          library: 'scheduler library',
          context: ErrorDescription('during a task callback'),
          informationCollector: (callbackStack == null) ? null : () {
            return <DiagnosticsNode>[
              DiagnosticsStackTrace(
                '\nThis exception was thrown in the context of a scheduler callback. '
                'When the scheduler callback was _registered_ (as opposed to when the '
                'exception was thrown), this was the stack',
                callbackStack,
              ),
            ];
          },
        ));
      }
      return _taskQueue.isNotEmpty;
    }
    return false;
  }

  int _nextFrameCallbackId = 0; // positive
  Map<int, _FrameCallbackEntry> _transientCallbacks = <int, _FrameCallbackEntry>{};
  final Set<int> _removedIds = HashSet<int>();

  int get transientCallbackCount => _transientCallbacks.length;

  int scheduleFrameCallback(FrameCallback callback, { bool rescheduling = false }) {
    scheduleFrame();
    _nextFrameCallbackId += 1;
    _transientCallbacks[_nextFrameCallbackId] = _FrameCallbackEntry(callback, rescheduling: rescheduling);
    return _nextFrameCallbackId;
  }

  void cancelFrameCallbackWithId(int id) {
    assert(id > 0);
    _transientCallbacks.remove(id);
    _removedIds.add(id);
  }

  bool debugAssertNoTransientCallbacks(String reason) {
    assert(() {
      if (transientCallbackCount > 0) {
        // We cache the values so that we can produce them later
        // even if the information collector is called after
        // the problem has been resolved.
        final int count = transientCallbackCount;
        final Map<int, _FrameCallbackEntry> callbacks = Map<int, _FrameCallbackEntry>.of(_transientCallbacks);
        FlutterError.reportError(FlutterErrorDetails(
          exception: reason,
          library: 'scheduler library',
          informationCollector: () => <DiagnosticsNode>[
            if (count == 1)
              // TODO(jacobr): I have added an extra line break in this case.
              ErrorDescription(
                'There was one transient callback left. '
                'The stack trace for when it was registered is as follows:',
              )
            else
              ErrorDescription(
                'There were $count transient callbacks left. '
                'The stack traces for when they were registered are as follows:',
              ),
            for (final int id in callbacks.keys)
              DiagnosticsStackTrace('── callback $id ──', callbacks[id]!.debugStack, showSeparator: false),
          ],
        ));
      }
      return true;
    }());
    return true;
  }

  bool debugAssertNoPendingPerformanceModeRequests(String reason) {
    assert(() {
      if (_performanceMode != null) {
        throw FlutterError(reason);
      }
      return true;
    }());
    return true;
  }

  bool debugAssertNoTimeDilation(String reason) {
    assert(() {
      if (timeDilation != 1.0) {
        throw FlutterError(reason);
      }
      return true;
    }());
    return true;
  }

  static void debugPrintTransientCallbackRegistrationStack() {
    assert(() {
      if (_FrameCallbackEntry.debugCurrentCallbackStack != null) {
        debugPrint('When the current transient callback was registered, this was the stack:');
        debugPrint(
          FlutterError.defaultStackFilter(
            FlutterError.demangleStackTrace(
              _FrameCallbackEntry.debugCurrentCallbackStack!,
            ).toString().trimRight().split('\n'),
          ).join('\n'),
        );
      } else {
        debugPrint('No transient callback is currently executing.');
      }
      return true;
    }());
  }

  final List<FrameCallback> _persistentCallbacks = <FrameCallback>[];

  void addPersistentFrameCallback(FrameCallback callback) {
    _persistentCallbacks.add(callback);
  }

  final List<FrameCallback> _postFrameCallbacks = <FrameCallback>[];

  void addPostFrameCallback(FrameCallback callback) {
    _postFrameCallbacks.add(callback);
  }

  Completer<void>? _nextFrameCompleter;

  Future<void> get endOfFrame {
    if (_nextFrameCompleter == null) {
      if (schedulerPhase == SchedulerPhase.idle) {
        scheduleFrame();
      }
      _nextFrameCompleter = Completer<void>();
      addPostFrameCallback((Duration timeStamp) {
        _nextFrameCompleter!.complete();
        _nextFrameCompleter = null;
      });
    }
    return _nextFrameCompleter!.future;
  }

  bool get hasScheduledFrame => _hasScheduledFrame;
  bool _hasScheduledFrame = false;

  SchedulerPhase get schedulerPhase => _schedulerPhase;
  SchedulerPhase _schedulerPhase = SchedulerPhase.idle;

  bool get framesEnabled => _framesEnabled;

  bool _framesEnabled = true;
  void _setFramesEnabledState(bool enabled) {
    if (_framesEnabled == enabled) {
      return;
    }
    _framesEnabled = enabled;
    if (enabled) {
      scheduleFrame();
    }
  }

  @protected
  void ensureFrameCallbacksRegistered() {
    platformDispatcher.onBeginFrame ??= _handleBeginFrame;
    platformDispatcher.onDrawFrame ??= _handleDrawFrame;
  }

  void ensureVisualUpdate() {
    switch (schedulerPhase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.postFrameCallbacks:
        scheduleFrame();
        return;
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
      case SchedulerPhase.persistentCallbacks:
        return;
    }
  }

  void scheduleFrame() {
    if (_hasScheduledFrame || !framesEnabled) {
      return;
    }
    assert(() {
      if (debugPrintScheduleFrameStacks) {
        debugPrintStack(label: 'scheduleFrame() called. Current phase is $schedulerPhase.');
      }
      return true;
    }());
    ensureFrameCallbacksRegistered();
    platformDispatcher.scheduleFrame();
    _hasScheduledFrame = true;
  }

  void scheduleForcedFrame() {
    if (_hasScheduledFrame) {
      return;
    }
    assert(() {
      if (debugPrintScheduleFrameStacks) {
        debugPrintStack(label: 'scheduleForcedFrame() called. Current phase is $schedulerPhase.');
      }
      return true;
    }());
    ensureFrameCallbacksRegistered();
    platformDispatcher.scheduleFrame();
    _hasScheduledFrame = true;
  }

  bool _warmUpFrame = false;

  void scheduleWarmUpFrame() {
    if (_warmUpFrame || schedulerPhase != SchedulerPhase.idle) {
      return;
    }

    _warmUpFrame = true;
    TimelineTask? debugTimelineTask;
    if (!kReleaseMode) {
      debugTimelineTask = TimelineTask()..start('Warm-up frame');
    }
    final bool hadScheduledFrame = _hasScheduledFrame;
    // We use timers here to ensure that microtasks flush in between.
    Timer.run(() {
      assert(_warmUpFrame);
      handleBeginFrame(null);
    });
    Timer.run(() {
      assert(_warmUpFrame);
      handleDrawFrame();
      // We call resetEpoch after this frame so that, in the hot reload case,
      // the very next frame pretends to have occurred immediately after this
      // warm-up frame. The warm-up frame's timestamp will typically be far in
      // the past (the time of the last real frame), so if we didn't reset the
      // epoch we would see a sudden jump from the old time in the warm-up frame
      // to the new time in the "real" frame. The biggest problem with this is
      // that implicit animations end up being triggered at the old time and
      // then skipping every frame and finishing in the new time.
      resetEpoch();
      _warmUpFrame = false;
      if (hadScheduledFrame) {
        scheduleFrame();
      }
    });

    // Lock events so touch events etc don't insert themselves until the
    // scheduled frame has finished.
    lockEvents(() async {
      await endOfFrame;
      if (!kReleaseMode) {
        debugTimelineTask!.finish();
      }
    });
  }

  Duration? _firstRawTimeStampInEpoch;
  Duration _epochStart = Duration.zero;
  Duration _lastRawTimeStamp = Duration.zero;

  void resetEpoch() {
    _epochStart = _adjustForEpoch(_lastRawTimeStamp);
    _firstRawTimeStampInEpoch = null;
  }

  Duration _adjustForEpoch(Duration rawTimeStamp) {
    final Duration rawDurationSinceEpoch = _firstRawTimeStampInEpoch == null ? Duration.zero : rawTimeStamp - _firstRawTimeStampInEpoch!;
    return Duration(microseconds: (rawDurationSinceEpoch.inMicroseconds / timeDilation).round() + _epochStart.inMicroseconds);
  }

  Duration get currentFrameTimeStamp {
    assert(_currentFrameTimeStamp != null);
    return _currentFrameTimeStamp!;
  }
  Duration? _currentFrameTimeStamp;

  Duration get currentSystemFrameTimeStamp {
    return _lastRawTimeStamp;
  }

  int _debugFrameNumber = 0;
  String? _debugBanner;

  // Whether the current engine frame needs to be postponed till after the
  // warm-up frame.
  //
  // Engine may begin a frame in the middle of the warm-up frame because the
  // warm-up frame is scheduled by timers while the engine frame is scheduled
  // by platform specific frame scheduler (e.g. `requestAnimationFrame` on the
  // web). When this happens, we let the warm-up frame finish, and postpone the
  // engine frame.
  bool _rescheduleAfterWarmUpFrame = false;

  void _handleBeginFrame(Duration rawTimeStamp) {
    if (_warmUpFrame) {
      // "begin frame" and "draw frame" must strictly alternate. Therefore
      // _rescheduleAfterWarmUpFrame cannot possibly be true here as it is
      // reset by _handleDrawFrame.
      assert(!_rescheduleAfterWarmUpFrame);
      _rescheduleAfterWarmUpFrame = true;
      return;
    }
    handleBeginFrame(rawTimeStamp);
  }

  void _handleDrawFrame() {
    if (_rescheduleAfterWarmUpFrame) {
      _rescheduleAfterWarmUpFrame = false;
      // Reschedule in a post-frame callback to allow the draw-frame phase of
      // the warm-up frame to finish.
      addPostFrameCallback((Duration timeStamp) {
        // Force an engine frame.
        //
        // We need to reset _hasScheduledFrame here because we cancelled the
        // original engine frame, and therefore did not run handleBeginFrame
        // who is responsible for resetting it. So if a frame callback set this
        // to true in the "begin frame" part of the warm-up frame, it will
        // still be true here and cause us to skip scheduling an engine frame.
        _hasScheduledFrame = false;
        scheduleFrame();
      });
      return;
    }
    handleDrawFrame();
  }

  final TimelineTask? _frameTimelineTask = kReleaseMode ? null : TimelineTask();

  void handleBeginFrame(Duration? rawTimeStamp) {
    _frameTimelineTask?.start('Frame');
    _firstRawTimeStampInEpoch ??= rawTimeStamp;
    _currentFrameTimeStamp = _adjustForEpoch(rawTimeStamp ?? _lastRawTimeStamp);
    if (rawTimeStamp != null) {
      _lastRawTimeStamp = rawTimeStamp;
    }

    assert(() {
      _debugFrameNumber += 1;

      if (debugPrintBeginFrameBanner || debugPrintEndFrameBanner) {
        final StringBuffer frameTimeStampDescription = StringBuffer();
        if (rawTimeStamp != null) {
          _debugDescribeTimeStamp(_currentFrameTimeStamp!, frameTimeStampDescription);
        } else {
          frameTimeStampDescription.write('(warm-up frame)');
        }
        _debugBanner = '▄▄▄▄▄▄▄▄ Frame ${_debugFrameNumber.toString().padRight(7)}   ${frameTimeStampDescription.toString().padLeft(18)} ▄▄▄▄▄▄▄▄';
        if (debugPrintBeginFrameBanner) {
          debugPrint(_debugBanner);
        }
      }
      return true;
    }());

    assert(schedulerPhase == SchedulerPhase.idle);
    _hasScheduledFrame = false;
    try {
      // TRANSIENT FRAME CALLBACKS
      _frameTimelineTask?.start('Animate');
      _schedulerPhase = SchedulerPhase.transientCallbacks;
      final Map<int, _FrameCallbackEntry> callbacks = _transientCallbacks;
      _transientCallbacks = <int, _FrameCallbackEntry>{};
      callbacks.forEach((int id, _FrameCallbackEntry callbackEntry) {
        if (!_removedIds.contains(id)) {
          _invokeFrameCallback(callbackEntry.callback, _currentFrameTimeStamp!, callbackEntry.debugStack);
        }
      });
      _removedIds.clear();
    } finally {
      _schedulerPhase = SchedulerPhase.midFrameMicrotasks;
    }
  }

  DartPerformanceMode? _performanceMode;
  int _numPerformanceModeRequests = 0;

  PerformanceModeRequestHandle? requestPerformanceMode(DartPerformanceMode mode) {
    // conflicting requests are not allowed.
    if (_performanceMode != null && _performanceMode != mode) {
      return null;
    }

    if (_performanceMode == mode) {
      assert(_numPerformanceModeRequests > 0);
      _numPerformanceModeRequests++;
    } else if (_performanceMode == null) {
      assert(_numPerformanceModeRequests == 0);
      _performanceMode = mode;
      _numPerformanceModeRequests = 1;
    }

    return PerformanceModeRequestHandle._(_disposePerformanceModeRequest);
  }

  void _disposePerformanceModeRequest() {
    _numPerformanceModeRequests--;
    if (_numPerformanceModeRequests == 0) {
      _performanceMode = null;
      PlatformDispatcher.instance.requestDartPerformanceMode(DartPerformanceMode.balanced);
    }
  }

  DartPerformanceMode? debugGetRequestedPerformanceMode() {
    if (!(kDebugMode || kProfileMode)) {
      return null;
    } else {
      return _performanceMode;
    }
  }

  void handleDrawFrame() {
    assert(_schedulerPhase == SchedulerPhase.midFrameMicrotasks);
    _frameTimelineTask?.finish(); // end the "Animate" phase
    try {
      // PERSISTENT FRAME CALLBACKS
      _schedulerPhase = SchedulerPhase.persistentCallbacks;
      for (final FrameCallback callback in List<FrameCallback>.of(_persistentCallbacks)) {
        _invokeFrameCallback(callback, _currentFrameTimeStamp!);
      }

      // POST-FRAME CALLBACKS
      _schedulerPhase = SchedulerPhase.postFrameCallbacks;
      final List<FrameCallback> localPostFrameCallbacks =
          List<FrameCallback>.of(_postFrameCallbacks);
      _postFrameCallbacks.clear();
      for (final FrameCallback callback in localPostFrameCallbacks) {
        _invokeFrameCallback(callback, _currentFrameTimeStamp!);
      }
    } finally {
      _schedulerPhase = SchedulerPhase.idle;
      _frameTimelineTask?.finish(); // end the Frame
      assert(() {
        if (debugPrintEndFrameBanner) {
          debugPrint('▀' * _debugBanner!.length);
        }
        _debugBanner = null;
        return true;
      }());
      _currentFrameTimeStamp = null;
    }
  }

  void _profileFramePostEvent(FrameTiming frameTiming) {
    postEvent('Flutter.Frame', <String, dynamic>{
      'number': frameTiming.frameNumber,
      'startTime': frameTiming.timestampInMicroseconds(FramePhase.buildStart),
      'elapsed': frameTiming.totalSpan.inMicroseconds,
      'build': frameTiming.buildDuration.inMicroseconds,
      'raster': frameTiming.rasterDuration.inMicroseconds,
      'vsyncOverhead': frameTiming.vsyncOverhead.inMicroseconds,
    });
  }

  static void _debugDescribeTimeStamp(Duration timeStamp, StringBuffer buffer) {
    if (timeStamp.inDays > 0) {
      buffer.write('${timeStamp.inDays}d ');
    }
    if (timeStamp.inHours > 0) {
      buffer.write('${timeStamp.inHours - timeStamp.inDays * Duration.hoursPerDay}h ');
    }
    if (timeStamp.inMinutes > 0) {
      buffer.write('${timeStamp.inMinutes - timeStamp.inHours * Duration.minutesPerHour}m ');
    }
    if (timeStamp.inSeconds > 0) {
      buffer.write('${timeStamp.inSeconds - timeStamp.inMinutes * Duration.secondsPerMinute}s ');
    }
    buffer.write('${timeStamp.inMilliseconds - timeStamp.inSeconds * Duration.millisecondsPerSecond}');
    final int microseconds = timeStamp.inMicroseconds - timeStamp.inMilliseconds * Duration.microsecondsPerMillisecond;
    if (microseconds > 0) {
      buffer.write('.${microseconds.toString().padLeft(3, "0")}');
    }
    buffer.write('ms');
  }

  // Calls the given [callback] with [timestamp] as argument.
  //
  // Wraps the callback in a try/catch and forwards any error to
  // [debugSchedulerExceptionHandler], if set. If not set, prints
  // the error.
  @pragma('vm:notify-debugger-on-exception')
  void _invokeFrameCallback(FrameCallback callback, Duration timeStamp, [ StackTrace? callbackStack ]) {
    assert(_FrameCallbackEntry.debugCurrentCallbackStack == null);
    assert(() {
      _FrameCallbackEntry.debugCurrentCallbackStack = callbackStack;
      return true;
    }());
    try {
      callback(timeStamp);
    } catch (exception, exceptionStack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: exceptionStack,
        library: 'scheduler library',
        context: ErrorDescription('during a scheduler callback'),
        informationCollector: (callbackStack == null) ? null : () {
          return <DiagnosticsNode>[
            DiagnosticsStackTrace(
              '\nThis exception was thrown in the context of a scheduler callback. '
              'When the scheduler callback was _registered_ (as opposed to when the '
              'exception was thrown), this was the stack',
              callbackStack,
            ),
          ];
        },
      ));
    }
    assert(() {
      _FrameCallbackEntry.debugCurrentCallbackStack = null;
      return true;
    }());
  }
}

bool defaultSchedulingStrategy({ required int priority, required SchedulerBinding scheduler }) {
  if (scheduler.transientCallbackCount > 0) {
    return priority >= Priority.animation.value;
  }
  return true;
}