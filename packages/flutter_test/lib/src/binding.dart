import 'dart:async';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:matcher/expect.dart' show fail;
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:test_api/scaffolding.dart' as test_package show Timeout;
import 'package:vector_math/vector_math_64.dart';

import '_binding_io.dart' if (dart.library.html) '_binding_web.dart' as binding;
import 'goldens.dart';
import 'platform.dart';
import 'restoration.dart';
import 'stack_manipulation.dart';
import 'test_async_utils.dart';
import 'test_default_binary_messenger.dart';
import 'test_exception_reporter.dart';
import 'test_text_input.dart';
import 'window.dart';

enum EnginePhase {
  build,

  layout,

  compositingBits,

  paint,

  composite,

  flushSemantics,

  sendSemanticsUpdate,
}

typedef _MockMessageHandler = Future<void> Function(Object?);

enum TestBindingEventSource {
  test,

  device,
}

const Size _kDefaultTestViewportSize = Size(800.0, 600.0);

mixin TestDefaultBinaryMessengerBinding on BindingBase, ServicesBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static TestDefaultBinaryMessengerBinding get instance => BindingBase.checkInstance(_instance);
  static TestDefaultBinaryMessengerBinding? _instance;

  @override
  TestDefaultBinaryMessenger get defaultBinaryMessenger => super.defaultBinaryMessenger as TestDefaultBinaryMessenger;

  @override
  TestDefaultBinaryMessenger createBinaryMessenger() {
    Future<ByteData?> keyboardHandler(ByteData? message) async {
      return const StandardMethodCodec().encodeSuccessEnvelope(<int, int>{});
    }
    return TestDefaultBinaryMessenger(
      super.createBinaryMessenger(),
      outboundHandlers: <String, MessageHandler>{'flutter/keyboard': keyboardHandler},
    );
  }
}

class CapturedAccessibilityAnnouncement {
  const CapturedAccessibilityAnnouncement._(
    this.message,
    this.textDirection,
    this.assertiveness,
  );

  final String message;

  final TextDirection textDirection;

  final Assertiveness assertiveness;
}

// Examples can assume:
// late TestWidgetsFlutterBinding binding;
// late Size someSize;

abstract class TestWidgetsFlutterBinding extends BindingBase
  with SchedulerBinding,
       ServicesBinding,
       GestureBinding,
       SemanticsBinding,
       RendererBinding,
       PaintingBinding,
       WidgetsBinding,
       TestDefaultBinaryMessengerBinding {

  TestWidgetsFlutterBinding() : platformDispatcher = TestPlatformDispatcher(
    platformDispatcher: PlatformDispatcher.instance,
  ) {
    debugPrint = debugPrintOverride;
    debugDisableShadows = disableShadows;
  }

  @Deprecated(
    'Use WidgetTester.platformDispatcher or WidgetTester.view instead. '
    'Deprecated to prepare for the upcoming multi-window support. '
    'This feature was deprecated after v3.9.0-0.1.pre.'
  )
  @override
  late final TestWindow window;

  @override
  final TestPlatformDispatcher platformDispatcher;

  @override
  TestRestorationManager get restorationManager {
    _restorationManager ??= createRestorationManager();
    return _restorationManager!;
  }
  TestRestorationManager? _restorationManager;

  void reset() {
    _restorationManager?.dispose();
    _restorationManager = null;
    resetGestureBinding();
    testTextInput.reset();
    if (registerTestTextInput) {
      _testTextInput.register();
    }
  }

  @override
  TestRestorationManager createRestorationManager() {
    return TestRestorationManager();
  }

  DebugPrintCallback get debugPrintOverride => debugPrint;

  @protected
  bool get disableShadows => false;

  @protected
  bool get overrideHttpClient => true;

  @protected
  bool get registerTestTextInput => true;

  Future<void> delayed(Duration duration);

  static TestWidgetsFlutterBinding get instance => BindingBase.checkInstance(_instance);
  static TestWidgetsFlutterBinding? _instance;

  static TestWidgetsFlutterBinding ensureInitialized([@visibleForTesting Map<String, String>? environment]) {
    if (_instance != null) {
      return _instance!;
    }
    return binding.ensureInitialized(environment);
  }

  @override
  void initInstances() {
    // This is initialized here because it's needed for the `super.initInstances`
    // call. It can't be handled as a ctor initializer because it's dependent
    // on `platformDispatcher`. It can't be handled in the ctor itself because
    // the base class ctor is called first and calls `initInstances`.
    window = TestWindow.fromPlatformDispatcher(platformDispatcher: platformDispatcher);

    super.initInstances();
    _instance = this;
    timeDilation = 1.0; // just in case the developer has artificially changed it for development
    if (overrideHttpClient) {
      binding.setupHttpOverrides();
    }
    _testTextInput = TestTextInput(onCleared: _resetFocusedEditable);
  }

  @override
  // ignore: must_call_super
  void initLicenses() {
    // Do not include any licenses, because we're a test, and the LICENSE file
    // doesn't get generated for tests.
  }

  @override
  bool debugCheckZone(String entryPoint) {
    // We skip all the zone checks in tests because the test framework makes heavy use
    // of zones and so the zones never quite match the way the framework expects.
    return true;
  }

  bool get inTest;

  int get microtaskCount;

  test_package.Timeout get defaultTestTimeout;

  Clock get clock;

  Future<void> pump([ Duration? duration, EnginePhase newPhase = EnginePhase.sendSemanticsUpdate ]);

  Future<T?> runAsync<T>(Future<T> Function() callback);

  Future<void> setLocale(String languageCode, String countryCode) {
    return TestAsyncUtils.guard<void>(() async {
      assert(inTest);
      final Locale locale = Locale(languageCode, countryCode == '' ? null : countryCode);
      dispatchLocalesChanged(<Locale>[locale]);
    });
  }

  Future<void> setLocales(List<Locale> locales) {
    return TestAsyncUtils.guard<void>(() async {
      assert(inTest);
      dispatchLocalesChanged(locales);
    });
  }

  @override
  Future<ui.AppExitResponse> exitApplication(ui.AppExitType exitType, [int exitCode = 0]) async {
    switch (exitType) {
      case ui.AppExitType.cancelable:
        // The test framework shouldn't actually exit when requested.
        return ui.AppExitResponse.cancel;
      case ui.AppExitType.required:
        throw FlutterError('Unexpected application exit request while running test');
    }
  }

  void readTestInitialLifecycleStateFromNativeWindow() {
    readInitialLifecycleStateFromNativeWindow();
  }

  Size? _surfaceSize;

  // TODO(pdblasi-google): Deprecate this. https://github.com/flutter/flutter/issues/123881
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
  void addRenderView(RenderView view) {
    _insideAddRenderView = true;
    try {
      super.addRenderView(view);
    } finally {
      _insideAddRenderView = false;
    }
  }

  bool _insideAddRenderView = false;

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    if (_insideAddRenderView
        && renderView.hasConfiguration
        && renderView.configuration is TestViewConfiguration
        && renderView == this.renderView) { // ignore: deprecated_member_use
      // If a test has reached out to the now deprecated renderView property to set a custom TestViewConfiguration
      // we are not replacing it. This is to maintain backwards compatibility with how things worked prior to the
      // deprecation of that property.
      // TODO(goderbauer): Remove this "if" when the deprecated renderView property is removed.
      return renderView.configuration;
    }
    final FlutterView view = renderView.flutterView;
    if (_surfaceSize != null && view == platformDispatcher.implicitView) {
      return ViewConfiguration(
        size: _surfaceSize!,
        devicePixelRatio: view.devicePixelRatio,
      );
    }
    return super.createViewConfigurationFor(renderView);
  }

  Future<void> idle() {
    return TestAsyncUtils.guard<void>(() {
      final Completer<void> completer = Completer<void>();
      Timer.run(() {
        completer.complete();
      });
      return completer.future;
    });
  }

  Offset globalToLocal(Offset point, RenderView view) => point;

  Offset localToGlobal(Offset point, RenderView view) => point;

  TestBindingEventSource get pointerEventSource => _pointerEventSource;
  TestBindingEventSource _pointerEventSource = TestBindingEventSource.device;

  bool shouldPropagateDevicePointerEvents = false;

  void handlePointerEventForSource(
    PointerEvent event, {
    TestBindingEventSource source = TestBindingEventSource.device,
  }) {
    withPointerEventSource(source, () => handlePointerEvent(event));
  }

  @protected
  void withPointerEventSource(TestBindingEventSource source, VoidCallback task) {
    final TestBindingEventSource previousSource = _pointerEventSource;
    _pointerEventSource = source;
    try {
      task();
    } finally {
      _pointerEventSource = previousSource;
    }
  }

  TestTextInput get testTextInput => _testTextInput;
  late TestTextInput _testTextInput;

  //
  // TODO(ianh): We should just remove this property and move the call to
  // requestKeyboard to the WidgetTester.showKeyboard method.
  EditableTextState? get focusedEditable => _focusedEditable;
  EditableTextState? _focusedEditable;
  set focusedEditable(EditableTextState? value) {
    if (_focusedEditable != value) {
      _focusedEditable = value;
      value?.requestKeyboard();
    }
  }

  void _resetFocusedEditable() {
    _focusedEditable = null;
  }

  dynamic takeException() {
    assert(inTest);
    final dynamic result = _pendingExceptionDetails?.exception;
    _pendingExceptionDetails = null;
    return result;
  }
  FlutterExceptionHandler? _oldExceptionHandler;
  late StackTraceDemangler _oldStackTraceDemangler;
  FlutterErrorDetails? _pendingExceptionDetails;

  _MockMessageHandler? _announcementHandler;
  List<CapturedAccessibilityAnnouncement> _announcements =
      <CapturedAccessibilityAnnouncement>[];

  List<CapturedAccessibilityAnnouncement> takeAnnouncements() {
    assert(inTest);
    final List<CapturedAccessibilityAnnouncement> announcements = _announcements;
    _announcements = <CapturedAccessibilityAnnouncement>[];
    return announcements;
  }

  static const TextStyle _messageStyle = TextStyle(
    color: Color(0xFF917FFF),
    fontSize: 40.0,
  );

  static const Widget _preTestMessage = Center(
    child: Text(
      'Test starting...',
      style: _messageStyle,
      textDirection: TextDirection.ltr,
    ),
  );

  static const Widget _postTestMessage = Center(
    child: Text(
      'Test finished.',
      style: _messageStyle,
      textDirection: TextDirection.ltr,
    ),
  );

  bool showAppDumpInErrors = false;

  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
  });

  void asyncBarrier() {
    TestAsyncUtils.verifyAllScopesClosed();
  }

  Zone? _parentZone;

  VoidCallback _createTestCompletionHandler(String testDescription, Completer<void> completer) {
    return () {
      // This can get called twice, in the case of a Future without listeners failing, and then
      // our main future completing.
      assert(Zone.current == _parentZone);
      if (_pendingExceptionDetails != null) {
        debugPrint = debugPrintOverride; // just in case the test overrides it -- otherwise we won't see the error!
        reportTestException(_pendingExceptionDetails!, testDescription);
        _pendingExceptionDetails = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
  }

  @protected
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    // By default we do nothing.
    // The LiveTestWidgetsFlutterBinding overrides this to report the exception to the console.
  }

  Future<void> _handleAnnouncementMessage(Object? mockMessage) async {
    final Map<Object?, Object?> message = mockMessage! as Map<Object?, Object?>;
    if (message['type'] == 'announce') {
      final Map<Object?, Object?> data =
          message['data']! as Map<Object?, Object?>;
      final String dataMessage = data['message'].toString();
      final TextDirection textDirection =
          TextDirection.values[data['textDirection']! as int];
      final int assertivenessLevel = (data['assertiveness'] as int?) ?? 0;
      final Assertiveness assertiveness =
          Assertiveness.values[assertivenessLevel];
      final CapturedAccessibilityAnnouncement announcement =
          CapturedAccessibilityAnnouncement._(
              dataMessage, textDirection, assertiveness);
      _announcements.add(announcement);
    }
  }

  Future<void> _runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester,
    String description,
  ) {
    assert(inTest);

    // Set the handler only if there is currently none.
    if (TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .checkMockMessageHandler(SystemChannels.accessibility.name, null)) {
      _announcementHandler = _handleAnnouncementMessage;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility, _announcementHandler);
    }

    _oldExceptionHandler = FlutterError.onError;
    _oldStackTraceDemangler = FlutterError.demangleStackTrace;
    int exceptionCount = 0; // number of un-taken exceptions
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_pendingExceptionDetails != null) {
        debugPrint = debugPrintOverride; // just in case the test overrides it -- otherwise we won't see the errors!
        if (exceptionCount == 0) {
          exceptionCount = 2;
          FlutterError.dumpErrorToConsole(_pendingExceptionDetails!, forceReport: true);
        } else {
          exceptionCount += 1;
        }
        FlutterError.dumpErrorToConsole(details, forceReport: true);
        _pendingExceptionDetails = FlutterErrorDetails(
          exception: 'Multiple exceptions ($exceptionCount) were detected during the running of the current test, and at least one was unexpected.',
          library: 'Flutter test framework',
        );
      } else {
        reportExceptionNoticed(details); // mostly this is just a hook for the LiveTestWidgetsFlutterBinding
        _pendingExceptionDetails = details;
      }
    };
    FlutterError.demangleStackTrace = (StackTrace stack) {
      // package:stack_trace uses ZoneSpecification.errorCallback to add useful
      // information to stack traces, meaning Trace and Chain classes can be
      // present. Because these StackTrace implementations do not follow the
      // format the framework expects, we convert them to a vm trace here.
      if (stack is stack_trace.Trace) {
        return stack.vmTrace;
      }
      if (stack is stack_trace.Chain) {
        return stack.toTrace().vmTrace;
      }
      return stack;
    };
    final Completer<void> testCompleter = Completer<void>();
    final VoidCallback testCompletionHandler = _createTestCompletionHandler(description, testCompleter);
    void handleUncaughtError(Object exception, StackTrace stack) {
      if (testCompleter.isCompleted) {
        // Well this is not a good sign.
        // Ideally, once the test has failed we would stop getting errors from the test.
        // However, if someone tries hard enough they could get in a state where this happens.
        // If we silently dropped these errors on the ground, nobody would ever know. So instead
        // we report them to the console. They don't cause test failures, but hopefully someone
        // will see them in the logs at some point.
        debugPrint = debugPrintOverride; // just in case the test overrides it -- otherwise we won't see the error!
        FlutterError.dumpErrorToConsole(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: ErrorDescription('running a test (but after the test had completed)'),
          library: 'Flutter test framework',
        ), forceReport: true);
        return;
      }
      // This is where test failures, e.g. those in expect(), will end up.
      // Specifically, runUnaryGuarded() will call this synchronously and
      // return our return value if _runTestBody fails synchronously (which it
      // won't, so this never happens), and Future will call this when the
      // Future completes with an error and it would otherwise call listeners
      // if the listener is in a different zone (which it would be for the
      // `whenComplete` handler below), or if the Future completes with an
      // error and the future has no listeners at all.
      //
      // This handler further calls the onError handler above, which sets
      // _pendingExceptionDetails. Nothing gets printed as a result of that
      // call unless we already had an exception pending, because in general
      // we want people to be able to cause the framework to report exceptions
      // and then use takeException to verify that they were really caught.
      // Now, if we actually get here, this isn't going to be one of those
      // cases. We only get here if the test has actually failed. So, once
      // we've carefully reported it, we then immediately end the test by
      // calling the testCompletionHandler in the _parentZone.
      //
      // We have to manually call testCompletionHandler because if the Future
      // library calls us, it is maybe _instead_ of calling a registered
      // listener from a different zone. In our case, that would be instead of
      // calling the whenComplete() listener below.
      //
      // We have to call it in the parent zone because if we called it in
      // _this_ zone, the test framework would find this zone was the current
      // zone and helpfully throw the error in this zone, causing us to be
      // directly called again.
      DiagnosticsNode treeDump;
      try {
        treeDump = rootElement?.toDiagnosticsNode() ?? DiagnosticsNode.message('<no tree>');
        // We try to stringify the tree dump here (though we immediately discard the result) because
        // we want to make sure that if it can't be serialized, we replace it with a message that
        // says the tree could not be serialized. Otherwise, the real exception might get obscured
        // by side-effects of the underlying issues causing the tree dumping code to flail.
        treeDump.toStringDeep();
      } catch (exception) {
        treeDump = DiagnosticsNode.message('<additional error caught while dumping tree: $exception>', level: DiagnosticLevel.error);
      }
      final List<DiagnosticsNode> omittedFrames = <DiagnosticsNode>[];
      final int stackLinesToOmit = reportExpectCall(stack, omittedFrames);
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        context: ErrorDescription('running a test'),
        library: 'Flutter test framework',
        stackFilter: (Iterable<String> frames) {
          return FlutterError.defaultStackFilter(frames.skip(stackLinesToOmit));
        },
        informationCollector: () sync* {
          if (stackLinesToOmit > 0) {
            yield* omittedFrames;
          }
          if (showAppDumpInErrors) {
            yield DiagnosticsProperty<DiagnosticsNode>('At the time of the failure, the widget tree looked as follows', treeDump, linePrefix: '# ', style: DiagnosticsTreeStyle.flat);
          }
          if (description.isNotEmpty) {
            yield DiagnosticsProperty<String>('The test description was', description, style: DiagnosticsTreeStyle.errorProperty);
          }
        },
      ));
      assert(_parentZone != null);
      assert(_pendingExceptionDetails != null, 'A test overrode FlutterError.onError but either failed to return it to its original state, or had unexpected additional errors that it could not handle. Typically, this is caused by using expect() before restoring FlutterError.onError.');
      _parentZone!.run<void>(testCompletionHandler);
    }
    final ZoneSpecification errorHandlingZoneSpecification = ZoneSpecification(
      handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone, Object exception, StackTrace stack) {
        handleUncaughtError(exception, stack);
      }
    );
    _parentZone = Zone.current;
    final Zone testZone = _parentZone!.fork(specification: errorHandlingZoneSpecification);
    testZone.runBinary<Future<void>, Future<void> Function(), VoidCallback>(_runTestBody, testBody, invariantTester)
      .whenComplete(testCompletionHandler);
    return testCompleter.future;
  }

  Future<void> _runTestBody(Future<void> Function() testBody, VoidCallback invariantTester) async {
    assert(inTest);
    // So that we can assert that it remains the same after the test finishes.
    _beforeTestCheckIntrinsicSizes = debugCheckIntrinsicSizes;

    runApp(Container(key: UniqueKey(), child: _preTestMessage)); // Reset the tree to a known state.
    await pump();
    // Pretend that the first frame produced in the test body is the first frame
    // sent to the engine.
    resetFirstFrameSent();

    final bool autoUpdateGoldensBeforeTest = autoUpdateGoldenFiles && !isBrowser;
    final TestExceptionReporter reportTestExceptionBeforeTest = reportTestException;
    final ErrorWidgetBuilder errorWidgetBuilderBeforeTest = ErrorWidget.builder;
    final bool shouldPropagateDevicePointerEventsBeforeTest = shouldPropagateDevicePointerEvents;

    // run the test
    await testBody();
    asyncBarrier(); // drains the microtasks in `flutter test` mode (when using AutomatedTestWidgetsFlutterBinding)

    if (_pendingExceptionDetails == null) {
      // We only try to clean up and verify invariants if we didn't already
      // fail. If we got an exception already, then we instead leave everything
      // alone so that we don't cause more spurious errors.
      runApp(Container(key: UniqueKey(), child: _postTestMessage)); // Unmount any remaining widgets.
      await pump();
      if (registerTestTextInput) {
        _testTextInput.unregister();
      }
      invariantTester();
      _verifyAutoUpdateGoldensUnset(autoUpdateGoldensBeforeTest && !isBrowser);
      _verifyReportTestExceptionUnset(reportTestExceptionBeforeTest);
      _verifyErrorWidgetBuilderUnset(errorWidgetBuilderBeforeTest);
      _verifyShouldPropagateDevicePointerEventsUnset(shouldPropagateDevicePointerEventsBeforeTest);
      _verifyInvariants();
    }

    assert(inTest);
    asyncBarrier(); // When using AutomatedTestWidgetsFlutterBinding, this flushes the microtasks.
  }

  late bool _beforeTestCheckIntrinsicSizes;

  void _verifyInvariants() {
    assert(debugAssertNoTransientCallbacks(
      'An animation is still running even after the widget tree was disposed.'
    ));
    assert(debugAssertNoPendingPerformanceModeRequests(
      'A performance mode was requested and not disposed by a test.'
    ));
    assert(debugAssertNoTimeDilation(
      'The timeDilation was changed and not reset by the test.'
    ));
    assert(debugAssertAllFoundationVarsUnset(
      'The value of a foundation debug variable was changed by the test.',
      debugPrintOverride: debugPrintOverride,
    ));
    assert(debugAssertAllGesturesVarsUnset(
      'The value of a gestures debug variable was changed by the test.',
    ));
    assert(debugAssertAllPaintingVarsUnset(
      'The value of a painting debug variable was changed by the test.',
      debugDisableShadowsOverride: disableShadows,
    ));
    assert(debugAssertAllRenderVarsUnset(
      'The value of a rendering debug variable was changed by the test.',
      debugCheckIntrinsicSizesOverride: _beforeTestCheckIntrinsicSizes,
    ));
    assert(debugAssertAllWidgetVarsUnset(
      'The value of a widget debug variable was changed by the test.',
    ));
    assert(debugAssertAllSchedulerVarsUnset(
      'The value of a scheduler debug variable was changed by the test.',
    ));
    assert(debugAssertAllServicesVarsUnset(
      'The value of a services debug variable was changed by the test.',
    ));
  }

  void _verifyAutoUpdateGoldensUnset(bool valueBeforeTest) {
    assert(() {
      if (autoUpdateGoldenFiles != valueBeforeTest) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: FlutterError(
              'The value of autoUpdateGoldenFiles was changed by the test.',
          ),
          stack: StackTrace.current,
          library: 'Flutter test framework',
        ));
      }
      return true;
    }());
  }

  void _verifyReportTestExceptionUnset(TestExceptionReporter valueBeforeTest) {
    assert(() {
      if (reportTestException != valueBeforeTest) {
        // We can't report this error to their modified reporter because we
        // can't be guaranteed that their reporter will cause the test to fail.
        // So we reset the error reporter to its initial value and then report
        // this error.
        reportTestException = valueBeforeTest;
        FlutterError.reportError(FlutterErrorDetails(
          exception: FlutterError(
            'The value of reportTestException was changed by the test.',
          ),
          stack: StackTrace.current,
          library: 'Flutter test framework',
        ));
      }
      return true;
    }());
  }

  void _verifyErrorWidgetBuilderUnset(ErrorWidgetBuilder valueBeforeTest) {
    assert(() {
      if (ErrorWidget.builder != valueBeforeTest) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: FlutterError(
              'The value of ErrorWidget.builder was changed by the test.',
          ),
          stack: StackTrace.current,
          library: 'Flutter test framework',
        ));
      }
      return true;
    }());
  }

  void _verifyShouldPropagateDevicePointerEventsUnset(bool valueBeforeTest) {
    assert(() {
      if (shouldPropagateDevicePointerEvents != valueBeforeTest) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: FlutterError(
              'The value of shouldPropagateDevicePointerEvents was changed by the test.',
          ),
          stack: StackTrace.current,
          library: 'Flutter test framework',
        ));
      }
      return true;
    }());
  }

  void postTest() {
    assert(inTest);
    FlutterError.onError = _oldExceptionHandler;
    FlutterError.demangleStackTrace = _oldStackTraceDemangler;
    _pendingExceptionDetails = null;
    _parentZone = null;
    buildOwner!.focusManager.dispose();

    if (TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .checkMockMessageHandler(
            SystemChannels.accessibility.name, _announcementHandler)) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler(SystemChannels.accessibility, null);
      _announcementHandler = null;
    }
    _announcements = <CapturedAccessibilityAnnouncement>[];

    ServicesBinding.instance.keyEventManager.keyMessageHandler = null;
    buildOwner!.focusManager = FocusManager()..registerGlobalHandlers();

    // Disabling the warning because @visibleForTesting doesn't take the testing
    // framework itself into account, but we don't want it visible outside of
    // tests.
    // ignore: invalid_use_of_visible_for_testing_member
    RawKeyboard.instance.clearKeysPressed();
    // ignore: invalid_use_of_visible_for_testing_member
    HardwareKeyboard.instance.clearState();
    // ignore: invalid_use_of_visible_for_testing_member
    keyEventManager.clearState();
    // ignore: invalid_use_of_visible_for_testing_member
    RendererBinding.instance.initMouseTracker();
    // ignore: invalid_use_of_visible_for_testing_member
    ServicesBinding.instance.resetLifecycleState();
  }
}

class AutomatedTestWidgetsFlutterBinding extends TestWidgetsFlutterBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    binding.mockFlutterAssets();
  }

  static AutomatedTestWidgetsFlutterBinding get instance => BindingBase.checkInstance(_instance);
  static AutomatedTestWidgetsFlutterBinding? _instance;

  static AutomatedTestWidgetsFlutterBinding ensureInitialized() {
    if (AutomatedTestWidgetsFlutterBinding._instance == null) {
      AutomatedTestWidgetsFlutterBinding();
    }
    return AutomatedTestWidgetsFlutterBinding.instance;
  }

  FakeAsync? _currentFakeAsync; // set in runTest; cleared in postTest
  Completer<void>? _pendingAsyncTasks;

  @override
  Clock get clock {
    assert(inTest);
    return _clock!;
  }
  Clock? _clock;

  @override
  DebugPrintCallback get debugPrintOverride => debugPrintSynchronously;

  @override
  bool get disableShadows => true;

  @override
  test_package.Timeout defaultTestTimeout = const test_package.Timeout(Duration(minutes: 10));

  @override
  bool get inTest => _currentFakeAsync != null;

  @override
  int get microtaskCount => _currentFakeAsync!.microtaskCount;

  @override
  Future<void> pump([ Duration? duration, EnginePhase newPhase = EnginePhase.sendSemanticsUpdate ]) {
    return TestAsyncUtils.guard<void>(() {
      assert(inTest);
      assert(_clock != null);
      if (duration != null) {
        _currentFakeAsync!.elapse(duration);
      }
      _phase = newPhase;
      if (hasScheduledFrame) {
        _currentFakeAsync!.flushMicrotasks();
        handleBeginFrame(Duration(
          microseconds: _clock!.now().microsecondsSinceEpoch,
        ));
        _currentFakeAsync!.flushMicrotasks();
        handleDrawFrame();
      }
      _currentFakeAsync!.flushMicrotasks();
      return Future<void>.value();
    });
  }

  @override
  Future<T?> runAsync<T>(Future<T> Function() callback) {
    assert(() {
      if (_pendingAsyncTasks == null) {
        return true;
      }
      fail(
        'Reentrant call to runAsync() denied.\n'
        'runAsync() was called, then before its future completed, it '
        'was called again. You must wait for the first returned future '
        'to complete before calling runAsync() again.'
      );
    }());

    final Zone realAsyncZone = Zone.current.fork(
      specification: ZoneSpecification(
        scheduleMicrotask: (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
          Zone.root.scheduleMicrotask(f);
        },
        createTimer: (Zone self, ZoneDelegate parent, Zone zone, Duration duration, void Function() f) {
          return Zone.root.createTimer(duration, f);
        },
        createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone, Duration period, void Function(Timer timer) f) {
          return Zone.root.createPeriodicTimer(period, f);
        },
      ),
    );

    return realAsyncZone.run<Future<T?>>(() {
      final Completer<T?> result = Completer<T?>();
      _pendingAsyncTasks = Completer<void>();
      try {
        callback().then(result.complete).catchError(
          (Object exception, StackTrace stack) {
            FlutterError.reportError(FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'Flutter test framework',
              context: ErrorDescription('while running async test code'),
              informationCollector: () {
                return <DiagnosticsNode>[
                  ErrorHint('The exception was caught asynchronously.'),
                ];
              },
            ));
            result.complete(null);
          },
        );
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'Flutter test framework',
          context: ErrorDescription('while running async test code'),
            informationCollector: () {
              return <DiagnosticsNode>[
                ErrorHint('The exception was caught synchronously.'),
              ];
            },
        ));
        result.complete(null);
      }
      result.future.whenComplete(() {
        _pendingAsyncTasks!.complete();
        _pendingAsyncTasks = null;
      });
      return result.future;
    });
  }

  @override
  void ensureFrameCallbacksRegistered() {
    // Leave PlatformDispatcher alone, do nothing.
    assert(platformDispatcher.onDrawFrame == null);
    assert(platformDispatcher.onBeginFrame == null);
  }

  @override
  void scheduleWarmUpFrame() {
    // We override the default version of this so that the application-startup warm-up frame
    // does not schedule timers which we might never get around to running.
    assert(inTest);
    handleBeginFrame(null);
    _currentFakeAsync!.flushMicrotasks();
    handleDrawFrame();
    _currentFakeAsync!.flushMicrotasks();
  }

  @override
  void scheduleAttachRootWidget(Widget rootWidget) {
    // We override the default version of this so that the application-startup widget tree
    // build does not schedule timers which we might never get around to running.
    assert(inTest);
    attachRootWidget(rootWidget);
    _currentFakeAsync!.flushMicrotasks();
  }

  @override
  Future<void> idle() {
    assert(inTest);
    final Future<void> result = super.idle();
    _currentFakeAsync!.elapse(Duration.zero);
    return result;
  }

  int _firstFrameDeferredCount = 0;
  bool _firstFrameSent = false;

  @override
  bool get sendFramesToEngine => _firstFrameSent || _firstFrameDeferredCount == 0;

  @override
  void deferFirstFrame() {
    assert(_firstFrameDeferredCount >= 0);
    _firstFrameDeferredCount += 1;
  }

  @override
  void allowFirstFrame() {
    assert(_firstFrameDeferredCount > 0);
    _firstFrameDeferredCount -= 1;
    // Unlike in RendererBinding.allowFirstFrame we do not force a frame here
    // to give the test full control over frame scheduling.
  }

  @override
  void resetFirstFrameSent() {
    _firstFrameSent = false;
  }

  EnginePhase _phase = EnginePhase.sendSemanticsUpdate;

  // Cloned from RendererBinding.drawFrame() but with early-exit semantics.
  @override
  void drawFrame() {
    assert(inTest);
    try {
      debugBuildingDirtyElements = true;
      buildOwner!.buildScope(rootElement!);
      if (_phase != EnginePhase.build) {
        rootPipelineOwner.flushLayout();
        if (_phase != EnginePhase.layout) {
          rootPipelineOwner.flushCompositingBits();
          if (_phase != EnginePhase.compositingBits) {
            rootPipelineOwner.flushPaint();
            if (_phase != EnginePhase.paint && sendFramesToEngine) {
              _firstFrameSent = true;
              for (final RenderView renderView in renderViews) {
                renderView.compositeFrame(); // this sends the bits to the GPU
              }
              if (_phase != EnginePhase.composite) {
                rootPipelineOwner.flushSemantics(); // this sends the semantics to the OS.
                assert(_phase == EnginePhase.flushSemantics ||
                       _phase == EnginePhase.sendSemanticsUpdate);
              }
            }
          }
        }
      }
      buildOwner!.finalizeTree();
    } finally {
      debugBuildingDirtyElements = false;
    }
  }

  @override
  Future<void> delayed(Duration duration) {
    assert(_currentFakeAsync != null);
    _currentFakeAsync!.elapse(duration);
    return Future<void>.value();
  }

  void elapseBlocking(Duration duration) {
    _currentFakeAsync!.elapseBlocking(duration);
  }

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
  }) {
    assert(!inTest);
    assert(_currentFakeAsync == null);
    assert(_clock == null);

    final FakeAsync fakeAsync = FakeAsync();
    _currentFakeAsync = fakeAsync; // reset in postTest
    _clock = fakeAsync.getClock(DateTime.utc(2015));
    late Future<void> testBodyResult;
    fakeAsync.run((FakeAsync localFakeAsync) {
      assert(fakeAsync == _currentFakeAsync);
      assert(fakeAsync == localFakeAsync);
      testBodyResult = _runTest(testBody, invariantTester, description);
      assert(inTest);
    });

    return Future<void>.microtask(() async {
      // testBodyResult is a Future that was created in the Zone of the
      // fakeAsync. This means that if we await it here, it will register a
      // microtask to handle the future _in the fake async zone_. We avoid this
      // by calling '.then' in the current zone. While flushing the microtasks
      // of the fake-zone below, the new future will be completed and can then
      // be used without fakeAsync.

      final Future<void> resultFuture = testBodyResult.then<void>((_) {
        // Do nothing.
      });

      // Resolve interplay between fake async and real async calls.
      fakeAsync.flushMicrotasks();
      while (_pendingAsyncTasks != null) {
        await _pendingAsyncTasks!.future;
        fakeAsync.flushMicrotasks();
      }
      return resultFuture;
    });
  }

  @override
  void asyncBarrier() {
    assert(_currentFakeAsync != null);
    _currentFakeAsync!.flushMicrotasks();
    super.asyncBarrier();
  }

  @override
  void _verifyInvariants() {
    super._verifyInvariants();

    assert(inTest);

    bool timersPending = false;
    if (_currentFakeAsync!.periodicTimerCount != 0 ||
        _currentFakeAsync!.nonPeriodicTimerCount != 0) {
        debugPrint('Pending timers:');
        for (final FakeTimer timer in _currentFakeAsync!.pendingTimers) {
          debugPrint(
            'Timer (duration: ${timer.duration}, '
            'periodic: ${timer.isPeriodic}), created:');
          debugPrintStack(stackTrace: timer.creationStackTrace);
          debugPrint('');
        }
        timersPending = true;
    }
    assert(!timersPending, 'A Timer is still pending even after the widget tree was disposed.');
    assert(_currentFakeAsync!.microtaskCount == 0); // Shouldn't be possible.
  }

  @override
  void postTest() {
    super.postTest();
    assert(_currentFakeAsync != null);
    assert(_clock != null);
    _clock = null;
    _currentFakeAsync = null;
  }
}

enum LiveTestWidgetsFlutterBindingFramePolicy {
  onlyPumps,

  fadePointers,

  fullyLive,

  benchmark,

  benchmarkLive,
}

class LiveTestWidgetsFlutterBinding extends TestWidgetsFlutterBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;

    RenderView.debugAddPaintCallback(_handleRenderViewPaint);
  }

  static LiveTestWidgetsFlutterBinding get instance => BindingBase.checkInstance(_instance);
  static LiveTestWidgetsFlutterBinding? _instance;

  static LiveTestWidgetsFlutterBinding ensureInitialized() {
    if (LiveTestWidgetsFlutterBinding._instance == null) {
      LiveTestWidgetsFlutterBinding();
    }
    return LiveTestWidgetsFlutterBinding.instance;
  }

  @override
  bool get inTest => _inTest;
  bool _inTest = false;

  @override
  Clock get clock => const Clock();

  @override
  int get microtaskCount {
    // The Dart SDK doesn't report this number.
    assert(false, 'microtaskCount cannot be reported when running in real time');
    return -1;
  }

  @override
  test_package.Timeout get defaultTestTimeout => test_package.Timeout.none;

  Completer<void>? _pendingFrame;
  bool _expectingFrame = false;
  bool _expectingFrameToReassemble = false;
  bool _viewNeedsPaint = false;
  bool _runningAsyncTasks = false;

  LiveTestWidgetsFlutterBindingFramePolicy framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;

  @override
  Future<void> delayed(Duration duration) {
    return Future<void>.delayed(duration);
  }

  @override
  void scheduleFrame() {
    if (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
      // In benchmark mode, don't actually schedule any engine frames.
      return;
    }
    super.scheduleFrame();
  }

  @override
  void scheduleForcedFrame() {
    if (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
      // In benchmark mode, don't actually schedule any engine frames.
      return;
    }
    super.scheduleForcedFrame();
  }

  @override
  Future<void> reassembleApplication() {
    _expectingFrameToReassemble = true;
    return super.reassembleApplication();
  }

  bool? _doDrawThisFrame;

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    assert(_doDrawThisFrame == null);
    if (_expectingFrame ||
        _expectingFrameToReassemble ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.fullyLive) ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive) ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) ||
        (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.fadePointers && _viewNeedsPaint)) {
      _doDrawThisFrame = true;
      super.handleBeginFrame(rawTimeStamp);
    } else {
      _doDrawThisFrame = false;
    }
  }

  @override
  void handleDrawFrame() {
    assert(_doDrawThisFrame != null);
    if (_doDrawThisFrame!) {
      super.handleDrawFrame();
    }
    _doDrawThisFrame = null;
    _viewNeedsPaint = false;
    _expectingFrameToReassemble = false;
    if (_expectingFrame) { // set during pump
      assert(_pendingFrame != null);
      _pendingFrame!.complete(); // unlocks the test API
      _pendingFrame = null;
      _expectingFrame = false;
    } else if (framePolicy != LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
      platformDispatcher.scheduleFrame();
    }
  }

  void _markViewsNeedPaint([int? viewId]) {
    _viewNeedsPaint = true;
    final Iterable<RenderView> toMark = viewId == null
        ? renderViews
        : renderViews.where((RenderView renderView) => renderView.flutterView.viewId == viewId);
    for (final RenderView renderView in toMark) {
      renderView.markNeedsPaint();
    }
  }

  TextPainter? _label;
  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 10.0,
  );

  void _setDescription(String value) {
    if (value.isEmpty) {
      _label = null;
      return;
    }
    // TODO(ianh): Figure out if the test name is actually RTL.
    _label ??= TextPainter(textAlign: TextAlign.left, textDirection: TextDirection.ltr);
    _label!.text = TextSpan(text: value, style: _labelStyle);
    _label!.layout();
    _markViewsNeedPaint();
  }

  final Expando<Map<int, _LiveTestPointerRecord>> _renderViewToPointerIdToPointerRecord = Expando<Map<int, _LiveTestPointerRecord>>();

  void _handleRenderViewPaint(PaintingContext context, Offset offset, RenderView renderView) {
    assert(offset == Offset.zero);

    final Map<int, _LiveTestPointerRecord>? pointerIdToRecord = _renderViewToPointerIdToPointerRecord[renderView];
    if (pointerIdToRecord != null && pointerIdToRecord.isNotEmpty) {
      final double radius = renderView.configuration.size.shortestSide * 0.05;
      final Path path = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius))
        ..moveTo(0.0, -radius * 2.0)
        ..lineTo(0.0, radius * 2.0)
        ..moveTo(-radius * 2.0, 0.0)
        ..lineTo(radius * 2.0, 0.0);
      final Canvas canvas = context.canvas;
      final Paint paint = Paint()
        ..strokeWidth = radius / 10.0
        ..style = PaintingStyle.stroke;
      bool dirty = false;
      for (final _LiveTestPointerRecord record in pointerIdToRecord.values) {
        paint.color = record.color.withOpacity(record.decay < 0 ? (record.decay / (_kPointerDecay - 1)) : 1.0);
        canvas.drawPath(path.shift(record.position), paint);
        if (record.decay < 0) {
          dirty = true;
        }
        record.decay += 1;
      }
      pointerIdToRecord
          .keys
          .where((int pointer) => pointerIdToRecord[pointer]!.decay == 0)
          .toList()
          .forEach(pointerIdToRecord.remove);
      if (dirty) {
        scheduleMicrotask(() {
          _markViewsNeedPaint(renderView.flutterView.viewId);
        });
      }
    }

    _label?.paint(context.canvas, offset - const Offset(0.0, 10.0));
  }

  HitTestDispatcher? deviceEventDispatcher;

  @override
  void handlePointerEvent(PointerEvent event) {
    switch (pointerEventSource) {
      case TestBindingEventSource.test:
        RenderView? target;
        for (final RenderView renderView in renderViews) {
          if (renderView.flutterView.viewId == event.viewId) {
            target = renderView;
            break;
          }
        }
        if (target != null) {
          final _LiveTestPointerRecord? record = _renderViewToPointerIdToPointerRecord[target]?[event.pointer];
          if (record != null) {
            record.position = event.position;
            if (!event.down) {
              record.decay = _kPointerDecay;
            }
            _markViewsNeedPaint(event.viewId);
          } else if (event.down) {
            _renderViewToPointerIdToPointerRecord[target] ??= <int, _LiveTestPointerRecord>{};
            _renderViewToPointerIdToPointerRecord[target]![event.pointer] = _LiveTestPointerRecord(
              event.pointer,
              event.position,
            );
            _markViewsNeedPaint(event.viewId);
          }
        }
        super.handlePointerEvent(event);
      case TestBindingEventSource.device:
        if (shouldPropagateDevicePointerEvents) {
          super.handlePointerEvent(event);
          break;
        }
        if (deviceEventDispatcher != null) {
          // The pointer events received with this source has a global position
          // (see [handlePointerEventForSource]). Transform it to the local
          // coordinate space used by the testing widgets.
          final RenderView renderView = renderViews.firstWhere((RenderView r) => r.flutterView.viewId == event.viewId);
          final PointerEvent localEvent = event.copyWith(position: globalToLocal(event.position, renderView));
          withPointerEventSource(TestBindingEventSource.device,
            () => super.handlePointerEvent(localEvent)
          );
        }
    }
  }

  @override
  void dispatchEvent(PointerEvent event, HitTestResult? hitTestResult) {
    switch (pointerEventSource) {
      case TestBindingEventSource.test:
        super.dispatchEvent(event, hitTestResult);
      case TestBindingEventSource.device:
        assert(hitTestResult != null || event is PointerAddedEvent || event is PointerRemovedEvent);
        if (shouldPropagateDevicePointerEvents) {
          super.dispatchEvent(event, hitTestResult);
          break;
        }
        assert(deviceEventDispatcher != null);
        if (hitTestResult != null) {
          deviceEventDispatcher!.dispatchEvent(event, hitTestResult);
        }
    }
  }

  @override
  Future<void> pump([ Duration? duration, EnginePhase newPhase = EnginePhase.sendSemanticsUpdate ]) {
    assert(newPhase == EnginePhase.sendSemanticsUpdate);
    assert(inTest);
    assert(!_expectingFrame);
    assert(_pendingFrame == null);
    if (framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive) {
      // Ignore all pumps and just wait.
      return delayed(duration ?? Duration.zero);
    }
    return TestAsyncUtils.guard<void>(() {
      if (duration != null) {
        Timer(duration, () {
          _expectingFrame = true;
          scheduleFrame();
        });
      } else {
        _expectingFrame = true;
        scheduleFrame();
      }
      _pendingFrame = Completer<void>();
      return _pendingFrame!.future;
    });
  }

  @override
  Future<T?> runAsync<T>(Future<T> Function() callback) async {
    assert(() {
      if (!_runningAsyncTasks) {
        return true;
      }
      fail(
        'Reentrant call to runAsync() denied.\n'
        'runAsync() was called, then before its future completed, it '
        'was called again. You must wait for the first returned future '
        'to complete before calling runAsync() again.'
      );
    }());

    _runningAsyncTasks = true;
    try {
      return await callback();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Flutter test framework',
        context: ErrorSummary('while running async test code'),
      ));
      return null;
    } finally {
      _runningAsyncTasks = false;
    }
  }

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
  }) {
    assert(!inTest);
    _inTest = true;
    _setDescription(description);
    return _runTest(testBody, invariantTester, description);
  }

  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    final DebugPrintCallback testPrint = debugPrint;
    debugPrint = debugPrintOverride;
    debugPrint('(The following exception is now available via WidgetTester.takeException:)');
    FlutterError.dumpErrorToConsole(exception, forceReport: true);
    debugPrint(
      '(If WidgetTester.takeException is called, the above exception will be ignored. '
      'If it is not, then the above exception will be dumped when another exception is '
      'caught by the framework or when the test ends, whichever happens first, and then '
      'the test will fail due to having not caught or expected the exception.)'
    );
    debugPrint = testPrint;
  }

  @override
  void postTest() {
    super.postTest();
    assert(!_expectingFrame);
    assert(_pendingFrame == null);
    _inTest = false;
  }

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    final FlutterView view = renderView.flutterView;
    if (view == platformDispatcher.implicitView) {
      return TestViewConfiguration.fromView(
        size: _surfaceSize ?? _kDefaultTestViewportSize,
        view: view,
      );
    }
    final double devicePixelRatio = view.devicePixelRatio;
    return TestViewConfiguration.fromView(
      size: view.physicalSize / devicePixelRatio,
      view: view,
    );
  }

  @override
  Offset globalToLocal(Offset point, RenderView view) {
    // The method is expected to translate the given point expressed in logical
    // pixels in the global coordinate space to the local coordinate space (also
    // expressed in logical pixels).
    // The inverted transform translates from the global coordinate space in
    // physical pixels to the local coordinate space in logical pixels.
    final Matrix4 transform = view.configuration.toMatrix();
    final double det = transform.invert();
    assert(det != 0.0);
    // In order to use the transform, we need to translate the point first into
    // the physical coordinate space by applying the device pixel ratio.
    return MatrixUtils.transformPoint(
      transform,
      point * view.configuration.devicePixelRatio,
    );
  }

  @override
  Offset localToGlobal(Offset point, RenderView view) {
    // The method is expected to translate the given point expressed in logical
    // pixels in the local coordinate space to the global coordinate space (also
    // expressed in logical pixels).
    // The transform translates from the local coordinate space in logical
    // pixels to the global coordinate space in physical pixels.
    final Matrix4 transform = view.configuration.toMatrix();
    final Offset pointInPhysicalPixels = MatrixUtils.transformPoint(transform, point);
    // We need to apply the device pixel ratio to get back to logical pixels.
    return pointInPhysicalPixels / view.configuration.devicePixelRatio;
  }
}

class TestViewConfiguration extends ViewConfiguration {
  @Deprecated(
    'Use TestViewConfiguration.fromView instead. '
    'Deprecated to prepare for the upcoming multi-window support. '
    'This feature was deprecated after v3.7.0-32.0.pre.'
  )
  factory TestViewConfiguration({
    Size size = _kDefaultTestViewportSize,
    ui.FlutterView? window,
  }) {
    return TestViewConfiguration.fromView(size: size, view: window ?? ui.window);
  }

  TestViewConfiguration.fromView({required ui.FlutterView view, super.size = _kDefaultTestViewportSize})
      : _paintMatrix = _getMatrix(size, view.devicePixelRatio, view),
        super(devicePixelRatio: view.devicePixelRatio);

  static Matrix4 _getMatrix(Size size, double devicePixelRatio, ui.FlutterView window) {
    final double inverseRatio = devicePixelRatio / window.devicePixelRatio;
    final double actualWidth = window.physicalSize.width * inverseRatio;
    final double actualHeight = window.physicalSize.height * inverseRatio;
    final double desiredWidth = size.width;
    final double desiredHeight = size.height;
    double scale, shiftX, shiftY;
    if ((actualWidth / actualHeight) > (desiredWidth / desiredHeight)) {
      scale = actualHeight / desiredHeight;
      shiftX = (actualWidth - desiredWidth * scale) / 2.0;
      shiftY = 0.0;
    } else {
      scale = actualWidth / desiredWidth;
      shiftX = 0.0;
      shiftY = (actualHeight - desiredHeight * scale) / 2.0;
    }
    final Matrix4 matrix = Matrix4.compose(
      Vector3(shiftX, shiftY, 0.0), // translation
      Quaternion.identity(), // rotation
      Vector3(scale, scale, 1.0), // scale
    );
    return matrix;
  }

  final Matrix4 _paintMatrix;

  @override
  Matrix4 toMatrix() => _paintMatrix.clone();

  @override
  String toString() => 'TestViewConfiguration';
}

const int _kPointerDecay = -2;

class _LiveTestPointerRecord {
  _LiveTestPointerRecord(
    this.pointer,
    this.position,
  ) : color = HSVColor.fromAHSV(0.8, (35.0 * pointer) % 360.0, 1.0, 1.0).toColor(),
      decay = 1;
  final int pointer;
  final Color color;
  Offset position;
  int decay; // >0 means down, <0 means up, increases by one each time, removed at 0
}