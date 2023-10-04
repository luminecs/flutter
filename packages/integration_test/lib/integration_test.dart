import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show HttpClient, SocketException, WebSocket;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm;

import '_callback_io.dart' if (dart.library.html) '_callback_web.dart'
    as driver_actions;
import '_extension_io.dart' if (dart.library.html) '_extension_web.dart';
import 'common.dart';
import 'src/channel.dart';

const String _success = 'success';

const bool _shouldReportResultsToNative = bool.fromEnvironment(
  'INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE',
  defaultValue: true,
);

class IntegrationTestWidgetsFlutterBinding extends LiveTestWidgetsFlutterBinding
    implements IntegrationTestResults {
  IntegrationTestWidgetsFlutterBinding() {
    tearDownAll(() async {
      if (!_allTestsPassed.isCompleted) {
        _allTestsPassed.complete(failureMethodsDetails.isEmpty);
      }
      callbackManager.cleanup();

      // TODO(jiahaog): Print the message directing users to run with
      // `flutter test` when Web is supported.
      if (!_shouldReportResultsToNative || kIsWeb) {
        return;
      }

      try {
        await integrationTestChannel.invokeMethod<void>(
          'allTestsFinished',
          <String, dynamic>{
            'results':
                results.map<String, dynamic>((String name, Object result) {
              if (result is Failure) {
                return MapEntry<String, dynamic>(name, result.details);
              }
              return MapEntry<String, Object>(name, result);
            }),
          },
        );
      } on MissingPluginException {
        debugPrint(r'''
Warning: integration_test plugin was not detected.

If you're running the tests with `flutter drive`, please make sure your tests
are in the `integration_test/` directory of your package and use
`flutter test $path_to_test` to run it instead.

If you're running the tests with Android instrumentation or XCTest, this means
that you are not capturing test results properly! See the following link for
how to set up the integration_test plugin:

https://flutter.dev/docs/testing/integration-tests#testing-on-firebase-test-lab
''');
      }
    });

    final TestExceptionReporter oldTestExceptionReporter = reportTestException;
    reportTestException =
        (FlutterErrorDetails details, String testDescription) {
      results[testDescription] = Failure(testDescription, details.toString());
      oldTestExceptionReporter(details, testDescription);
    };
  }

  @override
  bool get overrideHttpClient => false;

  @override
  bool get registerTestTextInput => false;

  Size? _surfaceSize;

  // This flag is used to print warning messages when tracking performance
  // under debug mode.
  static bool _firstRun = false;

  @override
  Future<void> setSurfaceSize(Size? size) {
    return TestAsyncUtils.guard<void>(() async {
      assert(inTest);
      if (_surfaceSize == size) {
        return;
      }
      _surfaceSize = size;
      handleMetricsChanged();
    });
  }

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    final FlutterView view = renderView.flutterView;
    final Size? surfaceSize =
        view == platformDispatcher.implicitView ? _surfaceSize : null;
    return TestViewConfiguration.fromView(
      size: surfaceSize ?? view.physicalSize / view.devicePixelRatio,
      view: view,
    );
  }

  @override
  Completer<bool> get allTestsPassed => _allTestsPassed;
  final Completer<bool> _allTestsPassed = Completer<bool>();

  @override
  List<Failure> get failureMethodsDetails =>
      results.values.whereType<Failure>().toList();

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static IntegrationTestWidgetsFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static IntegrationTestWidgetsFlutterBinding? _instance;

  static IntegrationTestWidgetsFlutterBinding ensureInitialized() {
    if (_instance == null) {
      IntegrationTestWidgetsFlutterBinding();
    }
    return _instance!;
  }

  @visibleForTesting
  Map<String, Object> results = <String, Object>{};

  @override
  Map<String, dynamic>? reportData;

  final CallbackManager callbackManager = driver_actions.callbackManager;

  Future<List<int>> takeScreenshot(String screenshotName,
      [Map<String, Object?>? args]) async {
    reportData ??= <String, dynamic>{};
    reportData!['screenshots'] ??= <dynamic>[];
    final Map<String, dynamic> data =
        await callbackManager.takeScreenshot(screenshotName, args);
    assert(data.containsKey('bytes'));

    (reportData!['screenshots']! as List<dynamic>).add(data);
    return data['bytes']! as List<int>;
  }

  Future<void> convertFlutterSurfaceToImage() async {
    await callbackManager.convertFlutterSurfaceToImage();
  }

  @visibleForTesting
  Future<Map<String, dynamic>> callback(Map<String, String> params) async {
    return callbackManager.callback(
        params, this /* as IntegrationTestResults */);
  }

  // Emulates the Flutter driver extension, returning 'pass' or 'fail'.
  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    if (kIsWeb) {
      registerWebServiceExtension(callback);
    }

    registerServiceExtension(name: 'driver', callback: callback);
  }

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
    @Deprecated(
        'This parameter has no effect. Use the `timeout` parameter on `testWidgets` instead. '
        'This feature was deprecated after v2.6.0-1.0.pre.')
    Duration? timeout,
  }) async {
    await super.runTest(
      testBody,
      invariantTester,
      description: description,
    );
    results[description] ??= _success;
  }

  vm.VmService? _vmService;

  @visibleForTesting
  Future<void> enableTimeline({
    List<String> streams = const <String>['all'],
    @visibleForTesting vm.VmService? vmService,
    @visibleForTesting HttpClient? httpClient,
  }) async {
    assert(streams.isNotEmpty);
    if (vmService != null) {
      _vmService = vmService;
    }
    if (_vmService == null) {
      final developer.ServiceProtocolInfo info =
          await developer.Service.getInfo();
      assert(info.serverUri != null);
      final String address =
          'ws://localhost:${info.serverUri!.port}${info.serverUri!.path}ws';
      try {
        _vmService =
            await _vmServiceConnectUri(address, httpClient: httpClient);
      } on SocketException catch (e, s) {
        throw StateError(
          'Failed to connect to VM Service at $address.\n'
          'This may happen if DDS is enabled. If this test was launched via '
          '`flutter drive`, try adding `--no-dds`.\n'
          'The original exception was:\n'
          '$e\n$s',
        );
      }
    }
    await _vmService!.setVMTimelineFlags(streams);
  }

  Future<vm.Timeline> traceTimeline(
    Future<dynamic> Function() action, {
    List<String> streams = const <String>['all'],
    bool retainPriorEvents = false,
  }) async {
    await enableTimeline(streams: streams);
    if (retainPriorEvents) {
      await action();
      return _vmService!.getVMTimeline();
    }

    await _vmService!.clearVMTimeline();
    final vm.Timestamp startTime = await _vmService!.getVMTimelineMicros();
    await action();
    final vm.Timestamp endTime = await _vmService!.getVMTimelineMicros();
    return _vmService!.getVMTimeline(
      timeOriginMicros: startTime.timestamp,
      timeExtentMicros: endTime.timestamp,
    );
  }

  Future<void> traceAction(
    Future<dynamic> Function() action, {
    List<String> streams = const <String>['all'],
    bool retainPriorEvents = false,
    String reportKey = 'timeline',
  }) async {
    final vm.Timeline timeline = await traceTimeline(
      action,
      streams: streams,
      retainPriorEvents: retainPriorEvents,
    );
    reportData ??= <String, dynamic>{};
    reportData![reportKey] = timeline.toJson();
  }

  Future<_GarbageCollectionInfo> _runAndGetGCInfo(
      Future<void> Function() action) async {
    if (kIsWeb) {
      await action();
      return const _GarbageCollectionInfo();
    }

    final vm.Timeline timeline = await traceTimeline(
      action,
      streams: <String>['GC'],
    );

    final int oldGenGCCount =
        timeline.traceEvents!.where((vm.TimelineEvent event) {
      return event.json!['cat'] == 'GC' &&
          event.json!['name'] == 'CollectOldGeneration';
    }).length;
    final int newGenGCCount =
        timeline.traceEvents!.where((vm.TimelineEvent event) {
      return event.json!['cat'] == 'GC' &&
          event.json!['name'] == 'CollectNewGeneration';
    }).length;
    return _GarbageCollectionInfo(
      oldCount: oldGenGCCount,
      newCount: newGenGCCount,
    );
  }

  Future<void> watchPerformance(
    Future<void> Function() action, {
    String reportKey = 'performance',
  }) async {
    assert(() {
      if (_firstRun) {
        debugPrint(kDebugWarning);
        _firstRun = false;
      }
      return true;
    }());

    // The engine could batch FrameTimings and send them only once per second.
    // Delay for a sufficient time so either old FrameTimings are flushed and not
    // interfering our measurements here, or new FrameTimings are all reported.
    // TODO(CareF): remove this when flush FrameTiming is readily in engine.
    //              See https://github.com/flutter/flutter/issues/64808
    //              and https://github.com/flutter/flutter/issues/67593
    final List<FrameTiming> frameTimings = <FrameTiming>[];
    Future<void> delayForFrameTimings() async {
      int count = 0;
      while (frameTimings.isEmpty) {
        count++;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (count > 20) {
          debugPrint('delayForFrameTimings is taking longer than expected...');
        }
      }
    }

    await Future<void>.delayed(
        const Duration(seconds: 2)); // flush old FrameTimings
    final TimingsCallback watcher = frameTimings.addAll;
    addTimingsCallback(watcher);
    final _GarbageCollectionInfo gcInfo = await _runAndGetGCInfo(action);

    await delayForFrameTimings(); // make sure all FrameTimings are reported
    removeTimingsCallback(watcher);

    final FrameTimingSummarizer frameTimes = FrameTimingSummarizer(
      frameTimings,
      newGenGCCount: gcInfo.newCount,
      oldGenGCCount: gcInfo.oldCount,
    );
    reportData ??= <String, dynamic>{};
    reportData![reportKey] = frameTimes.summary;
  }

  @override
  Timeout defaultTestTimeout = Timeout.none;

  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    // This is a workaround where screenshots of root widgets have incorrect
    // bounds.
    // TODO(jiahaog): Remove when https://github.com/flutter/flutter/issues/66006 is fixed.
    return super.wrapWithDefaultView(RepaintBoundary(child: rootWidget));
  }

  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    // This method is called to log errors as they happen, and they will also
    // be eventually logged again at the end of the tests. The superclass
    // behavior is specific to the "live" execution semantics of
    // [LiveTestWidgetsFlutterBinding] so users don't have to wait until tests
    // finish to see the stack traces.
    //
    // Disable this because Integration Tests follow the semantics of
    // [AutomatedTestWidgetsFlutterBinding] that does not log the stack traces
    // live, and avoids the doubly logged stack trace.
    // TODO(jiahaog): Integration test binding should not inherit from
    // `LiveTestWidgetsFlutterBinding` https://github.com/flutter/flutter/issues/81534
  }
}

@immutable
class _GarbageCollectionInfo {
  const _GarbageCollectionInfo({this.oldCount = -1, this.newCount = -1});

  final int oldCount;
  final int newCount;
}

// Connect to the given uri and return a new [VmService] instance.
//
// Copied from vm_service_io so that we can pass a custom [HttpClient] for
// testing. Currently, the WebSocket API reuses an HttpClient that
// is created before the test can change the HttpOverrides.
Future<vm.VmService> _vmServiceConnectUri(
  String wsUri, {
  HttpClient? httpClient,
}) async {
  final WebSocket socket =
      await WebSocket.connect(wsUri, customClient: httpClient);
  final StreamController<dynamic> controller = StreamController<dynamic>();
  final Completer<void> streamClosedCompleter = Completer<void>();

  socket.listen(
    (dynamic data) => controller.add(data),
    onDone: () => streamClosedCompleter.complete(),
  );

  return vm.VmService(
    controller.stream,
    (String message) => socket.add(message),
    disposeHandler: () => socket.close(),
    streamClosed: streamClosedCompleter.future,
  );
}
