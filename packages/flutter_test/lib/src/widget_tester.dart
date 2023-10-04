import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:matcher/expect.dart' as matcher_expect;
import 'package:meta/meta.dart';
import 'package:test_api/scaffolding.dart' as test_package;

import 'binding.dart';
import 'controller.dart';
import 'finders.dart';
import 'matchers.dart';
import 'restoration.dart';
import 'test_async_utils.dart';
import 'test_compat.dart';
import 'test_pointer.dart';
import 'test_text_input.dart';
import 'tree_traversal.dart';

// Keep users from needing multiple imports to test semantics.
export 'package:flutter/rendering.dart' show SemanticsHandle;
// We re-export the matcher package minus some features that we reimplement.
//
//  - expect is reimplemented below, to catch incorrect async usage.
//
//  - isInstanceOf is reimplemented in matchers.dart because we don't want to
//    mark it as deprecated (ours is just a method, not a class).
//
export 'package:matcher/expect.dart' hide expect, isInstanceOf;
// We re-export the test package minus some features that we reimplement.
//
// Specifically:
//
//  - test, group, setUpAll, tearDownAll, setUp, tearDown, and expect would
//    conflict with our own implementations in test_compat.dart. This handles
//    setting up a declarer when one is not defined, which can happen when a
//    test is executed via `flutter run`.
//
// The test_api package has a deprecation warning to discourage direct use but
// that doesn't apply here.
export 'package:test_api/hooks.dart' show TestFailure;
export 'package:test_api/scaffolding.dart'
    show
        OnPlatform,
        Retry,
        Skip,
        Tags,
        TestOn,
        Timeout,
        addTearDown,
        markTestSkipped,
        printOnFailure,
        pumpEventQueue,
        registerException,
        spawnHybridCode,
        spawnHybridUri;

typedef WidgetTesterCallback = Future<void> Function(WidgetTester widgetTester);

// Return the last element that satisfies `test`, or return null if not found.
E? _lastWhereOrNull<E>(Iterable<E> list, bool Function(E) test) {
  late E result;
  bool foundMatching = false;
  for (final E element in list) {
    if (test(element)) {
      result = element;
      foundMatching = true;
    }
  }
  if (foundMatching) {
    return result;
  }
  return null;
}

// Examples can assume:
// typedef MyWidget = Placeholder;

@isTest
void testWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  test_package.Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
}) {
  assert(variant.values.isNotEmpty,
      'There must be at least one value to test in the testing variant.');
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  final WidgetTester tester = WidgetTester._(binding);
  for (final dynamic value in variant.values) {
    final String variationDescription = variant.describeValue(value);
    // IDEs may make assumptions about the format of this suffix in order to
    // support running tests directly from the editor (where they may have
    // access to only the test name, provided by the analysis server).
    // See https://github.com/flutter/flutter/issues/86659.
    final String combinedDescription = variationDescription.isNotEmpty
        ? '$description (variant: $variationDescription)'
        : description;
    test(
      combinedDescription,
      () {
        tester._testDescription = combinedDescription;
        SemanticsHandle? semanticsHandle;
        tester._recordNumberOfSemanticsHandles();
        if (semanticsEnabled) {
          semanticsHandle = tester.ensureSemantics();
        }
        test_package.addTearDown(binding.postTest);
        return binding.runTest(
          () async {
            binding
                .reset(); // TODO(ianh): the binding should just do this itself in _runTest
            debugResetSemanticsIdCounter();
            Object? memento;
            try {
              memento = await variant.setUp(value);
              await callback(tester);
            } finally {
              await variant.tearDown(value, memento);
            }
            semanticsHandle?.dispose();
          },
          tester._endOfTestVerifications,
          description: combinedDescription,
        );
      },
      skip: skip,
      timeout: timeout ?? binding.defaultTestTimeout,
      tags: tags,
      retry: retry,
    );
  }
}

abstract class TestVariant<T> {
  const TestVariant();

  Iterable<T> get values;

  String describeValue(T value);

  Future<Object?> setUp(T value);

  Future<void> tearDown(T value, covariant Object? memento);
}

class DefaultTestVariant extends TestVariant<void> {
  const DefaultTestVariant();

  @override
  Iterable<void> get values => const <void>[null];

  @override
  String describeValue(void value) => '';

  @override
  Future<void> setUp(void value) async {}

  @override
  Future<void> tearDown(void value, void memento) async {}
}

class TargetPlatformVariant extends TestVariant<TargetPlatform> {
  const TargetPlatformVariant(this.values);

  TargetPlatformVariant.all({
    Set<TargetPlatform> excluding = const <TargetPlatform>{},
  }) : values = TargetPlatform.values.toSet()..removeAll(excluding);

  TargetPlatformVariant.desktop()
      : values = <TargetPlatform>{
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        };

  TargetPlatformVariant.mobile()
      : values = <TargetPlatform>{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.fuchsia,
        };

  TargetPlatformVariant.only(TargetPlatform platform)
      : values = <TargetPlatform>{platform};

  @override
  final Set<TargetPlatform> values;

  @override
  String describeValue(TargetPlatform value) => value.toString();

  @override
  Future<TargetPlatform?> setUp(TargetPlatform value) async {
    final TargetPlatform? previousTargetPlatform =
        debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = value;
    return previousTargetPlatform;
  }

  @override
  Future<void> tearDown(TargetPlatform value, TargetPlatform? memento) async {
    debugDefaultTargetPlatformOverride = memento;
  }
}

class ValueVariant<T> extends TestVariant<T> {
  ValueVariant(this.values);

  T? get currentValue => _currentValue;
  T? _currentValue;

  @override
  final Set<T> values;

  @override
  String describeValue(T value) => value.toString().replaceFirst('$T.', '');

  @override
  Future<T> setUp(T value) async => _currentValue = value;

  @override
  Future<void> tearDown(T value, T memento) async {}
}

const String kDebugWarning = '''
┏╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┓
┇ ⚠    THIS BENCHMARK IS BEING RUN IN DEBUG MODE     ⚠  ┇
┡╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┦
│                                                       │
│  Numbers obtained from a benchmark while asserts are  │
│  enabled will not accurately reflect the performance  │
│  that will be experienced by end users using release  ╎
│  builds. Benchmarks should be run using this command  ╎
│  line:  "flutter run --profile test.dart" or          ┊
│  or "flutter drive --profile -t test.dart".           ┊
│                                                       ┊
└─────────────────────────────────────────────────╌┄┈  🐢
''';

Future<void> benchmarkWidgets(
  WidgetTesterCallback callback, {
  bool mayRunWithAsserts = false,
  bool semanticsEnabled = false,
}) {
  assert(() {
    if (mayRunWithAsserts) {
      return true;
    }
    debugPrint(kDebugWarning);
    return true;
  }());
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  assert(binding is! AutomatedTestWidgetsFlutterBinding);
  final WidgetTester tester = WidgetTester._(binding);
  SemanticsHandle? semanticsHandle;
  if (semanticsEnabled) {
    semanticsHandle = tester.ensureSemantics();
  }
  tester._recordNumberOfSemanticsHandles();
  return binding.runTest(
    () async {
      await callback(tester);
      semanticsHandle?.dispose();
    },
    tester._endOfTestVerifications,
  );
}

void expect(
  dynamic actual,
  dynamic matcher, {
  String? reason,
  dynamic skip, // true or a String
}) {
  TestAsyncUtils.guardSync();
  matcher_expect.expect(actual, matcher, reason: reason, skip: skip);
}

void expectSync(
  dynamic actual,
  dynamic matcher, {
  String? reason,
}) {
  matcher_expect.expect(actual, matcher, reason: reason);
}

Future<void> expectLater(
  dynamic actual,
  dynamic matcher, {
  String? reason,
  dynamic skip, // true or a String
}) {
  // We can't wrap the delegate in a guard, or we'll hit async barriers in
  // [TestWidgetsFlutterBinding] while we're waiting for the matcher to complete
  TestAsyncUtils.guardSync();
  return matcher_expect
      .expectLater(actual, matcher, reason: reason, skip: skip)
      .then<void>((dynamic value) => null);
}

class WidgetTester extends WidgetController
    implements HitTestDispatcher, TickerProvider {
  WidgetTester._(super.binding) {
    if (binding is LiveTestWidgetsFlutterBinding) {
      (binding as LiveTestWidgetsFlutterBinding).deviceEventDispatcher = this;
    }
  }

  String get testDescription => _testDescription;
  String _testDescription = '';

  @override
  TestWidgetsFlutterBinding get binding =>
      super.binding as TestWidgetsFlutterBinding;

  Future<void> pumpWidget(
    Widget widget, [
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) {
    return TestAsyncUtils.guard<void>(() {
      binding.attachRootWidget(binding.wrapWithDefaultView(widget));
      binding.scheduleFrame();
      return binding.pump(duration, phase);
    });
  }

  @override
  Future<List<Duration>> handlePointerEventRecord(
      Iterable<PointerEventRecord> records) {
    assert(records.isNotEmpty);
    return TestAsyncUtils.guard<List<Duration>>(() async {
      final List<Duration> handleTimeStampDiff = <Duration>[];
      DateTime? startTime;
      for (final PointerEventRecord record in records) {
        final DateTime now = binding.clock.now();
        startTime ??= now;
        // So that the first event is promised to receive a zero timeDiff
        final Duration timeDiff = record.timeDelay - now.difference(startTime);
        if (timeDiff.isNegative) {
          // Flush all past events
          handleTimeStampDiff.add(-timeDiff);
          for (final PointerEvent event in record.events) {
            binding.handlePointerEventForSource(event,
                source: TestBindingEventSource.test);
          }
        } else {
          await binding.pump();
          await binding.delayed(timeDiff);
          handleTimeStampDiff.add(
            binding.clock.now().difference(startTime) - record.timeDelay,
          );
          for (final PointerEvent event in record.events) {
            binding.handlePointerEventForSource(event,
                source: TestBindingEventSource.test);
          }
        }
      }
      await binding.pump();
      // This makes sure that a gesture is completed, with no more pointers
      // active.
      return handleTimeStampDiff;
    });
  }

  @override
  Future<void> pump([
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) {
    return TestAsyncUtils.guard<void>(() => binding.pump(duration, phase));
  }

  Future<void> pumpBenchmark(Duration duration) async {
    assert(() {
      final TestWidgetsFlutterBinding widgetsBinding = binding;
      return widgetsBinding is LiveTestWidgetsFlutterBinding &&
          widgetsBinding.framePolicy ==
              LiveTestWidgetsFlutterBindingFramePolicy.benchmark;
    }());

    dynamic caughtException;
    void handleError(dynamic error, StackTrace stackTrace) =>
        caughtException ??= error;

    await Future<void>.microtask(() {
      binding.handleBeginFrame(duration);
    }).catchError(handleError);
    await idle();
    await Future<void>.microtask(() {
      binding.handleDrawFrame();
    }).catchError(handleError);
    await idle();

    if (caughtException != null) {
      throw caughtException
          as Object; // ignore: only_throw_errors, rethrowing caught exception.
    }
  }

  @override
  Future<int> pumpAndSettle([
    Duration duration = const Duration(milliseconds: 100),
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration timeout = const Duration(minutes: 10),
  ]) {
    assert(duration > Duration.zero);
    assert(timeout > Duration.zero);
    assert(() {
      final WidgetsBinding binding = this.binding;
      if (binding is LiveTestWidgetsFlutterBinding &&
          binding.framePolicy ==
              LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
        matcher_expect.fail(
          'When using LiveTestWidgetsFlutterBindingFramePolicy.benchmark, '
          'hasScheduledFrame is never set to true. This means that pumpAndSettle() '
          'cannot be used, because it has no way to know if the application has '
          'stopped registering new frames.',
        );
      }
      return true;
    }());
    return TestAsyncUtils.guard<int>(() async {
      final DateTime endTime = binding.clock.fromNowBy(timeout);
      int count = 0;
      do {
        if (binding.clock.now().isAfter(endTime)) {
          throw FlutterError('pumpAndSettle timed out');
        }
        await binding.pump(duration, phase);
        count += 1;
      } while (binding.hasScheduledFrame);
      return count;
    });
  }

  Future<void> pumpFrames(
    Widget target,
    Duration maxDuration, [
    Duration interval = const Duration(milliseconds: 16, microseconds: 683),
  ]) {
    // The interval following the last frame doesn't have to be within the fullDuration.
    Duration elapsed = Duration.zero;
    return TestAsyncUtils.guard<void>(() async {
      binding.attachRootWidget(binding.wrapWithDefaultView(target));
      binding.scheduleFrame();
      while (elapsed < maxDuration) {
        await binding.pump(interval);
        elapsed += interval;
      }
    });
  }

  Future<void> restartAndRestore() async {
    assert(
      binding.restorationManager.debugRootBucketAccessed,
      'The current widget tree did not inject the root bucket of the RestorationManager and '
      'therefore no restoration data has been collected to restore from. Did you forget to wrap '
      'your widget tree in a RootRestorationScope?',
    );
    return TestAsyncUtils.guard<void>(() async {
      final RootWidget widget = binding.rootElement!.widget as RootWidget;
      final TestRestorationData restorationData =
          binding.restorationManager.restorationData;
      runApp(Container(key: UniqueKey()));
      await pump();
      binding.restorationManager.restoreFrom(restorationData);
      binding.attachToBuildOwner(widget);
      binding.scheduleFrame();
      return binding.pump();
    });
  }

  Future<TestRestorationData> getRestorationData() async {
    assert(
      binding.restorationManager.debugRootBucketAccessed,
      'The current widget tree did not inject the root bucket of the RestorationManager and '
      'therefore no restoration data has been collected. Did you forget to wrap your widget tree '
      'in a RootRestorationScope?',
    );
    return binding.restorationManager.restorationData;
  }

  Future<void> restoreFrom(TestRestorationData data) {
    binding.restorationManager.restoreFrom(data);
    return pump();
  }

  Future<T?> runAsync<T>(
    Future<T> Function() callback, {
    @Deprecated('This is no longer supported and has no effect. '
        'This feature was deprecated after v3.12.0-1.1.pre.')
    Duration additionalTime = const Duration(milliseconds: 1000),
  }) =>
      binding.runAsync<T?>(callback);

  bool get hasRunningAnimations => binding.transientCallbackCount > 0;

  @override
  HitTestResult hitTestOnBinding(Offset location, {int? viewId}) {
    viewId ??= view.viewId;
    final RenderView renderView = binding.renderViews
        .firstWhere((RenderView r) => r.flutterView.viewId == viewId);
    location = binding.localToGlobal(location, renderView);
    return super.hitTestOnBinding(location, viewId: viewId);
  }

  @override
  Future<void> sendEventToBinding(PointerEvent event) {
    return TestAsyncUtils.guard<void>(() async {
      binding.handlePointerEventForSource(event,
          source: TestBindingEventSource.test);
    });
  }

  @override
  void dispatchEvent(PointerEvent event, HitTestResult result) {
    if (event is PointerDownEvent) {
      final RenderObject innerTarget = result.path
          .map((HitTestEntry candidate) => candidate.target)
          .whereType<RenderObject>()
          .first;
      final Element? innerTargetElement = binding.renderViews
              .contains(innerTarget)
          ? null
          : _lastWhereOrNull(
              collectAllElementsFrom(binding.rootElement!, skipOffstage: true),
              (Element element) => element.renderObject == innerTarget,
            );
      if (innerTargetElement == null) {
        printToConsole('No widgets found at ${event.position}.');
        return;
      }
      final List<Element> candidates = <Element>[];
      innerTargetElement.visitAncestorElements((Element element) {
        candidates.add(element);
        return true;
      });
      assert(candidates.isNotEmpty);
      String? descendantText;
      int numberOfWithTexts = 0;
      int numberOfTypes = 0;
      int totalNumber = 0;
      printToConsole(
          'Some possible finders for the widgets at ${event.position}:');
      for (final Element element in candidates) {
        if (totalNumber > 13) {
          break;
        }
        totalNumber += 1; // optimistically assume we'll be able to describe it

        final Widget widget = element.widget;
        if (widget is Tooltip) {
          final String message =
              widget.message ?? widget.richMessage!.toPlainText();
          final Iterable<Element> matches = find.byTooltip(message).evaluate();
          if (matches.length == 1) {
            printToConsole("  find.byTooltip('$message')");
            continue;
          }
        }

        if (widget is Text) {
          assert(descendantText == null);
          assert(widget.data != null || widget.textSpan != null);
          final String text = widget.data ?? widget.textSpan!.toPlainText();
          final Iterable<Element> matches = find.text(text).evaluate();
          descendantText = widget.data;
          if (matches.length == 1) {
            printToConsole("  find.text('$text')");
            continue;
          }
        }

        final Key? key = widget.key;
        if (key is ValueKey<dynamic>) {
          String? keyLabel;
          if (key is ValueKey<int> ||
              key is ValueKey<double> ||
              key is ValueKey<bool>) {
            keyLabel = 'const ${key.runtimeType}(${key.value})';
          } else if (key is ValueKey<String>) {
            keyLabel = "const Key('${key.value}')";
          }
          if (keyLabel != null) {
            final Iterable<Element> matches = find.byKey(key).evaluate();
            if (matches.length == 1) {
              printToConsole('  find.byKey($keyLabel)');
              continue;
            }
          }
        }

        if (!_isPrivate(widget.runtimeType)) {
          if (numberOfTypes < 5) {
            final Iterable<Element> matches =
                find.byType(widget.runtimeType).evaluate();
            if (matches.length == 1) {
              printToConsole('  find.byType(${widget.runtimeType})');
              numberOfTypes += 1;
              continue;
            }
          }

          if (descendantText != null && numberOfWithTexts < 5) {
            final Iterable<Element> matches = find
                .widgetWithText(widget.runtimeType, descendantText)
                .evaluate();
            if (matches.length == 1) {
              printToConsole(
                  "  find.widgetWithText(${widget.runtimeType}, '$descendantText')");
              numberOfWithTexts += 1;
              continue;
            }
          }
        }

        if (!_isPrivate(element.runtimeType)) {
          final Iterable<Element> matches =
              find.byElementType(element.runtimeType).evaluate();
          if (matches.length == 1) {
            printToConsole('  find.byElementType(${element.runtimeType})');
            continue;
          }
        }

        totalNumber -=
            1; // if we got here, we didn't actually find something to say about it
      }
      if (totalNumber == 0) {
        printToConsole('  <could not come up with any unique finders>');
      }
    }
  }

  bool _isPrivate(Type type) {
    // used above so that we don't suggest matchers for private types
    return '_'.matchAsPrefix(type.toString()) != null;
  }

  dynamic takeException() {
    return binding.takeException();
  }

  List<CapturedAccessibilityAnnouncement> takeAnnouncements() {
    return binding.takeAnnouncements();
  }

  Future<void> idle() {
    return TestAsyncUtils.guard<void>(() => binding.idle());
  }

  Set<Ticker>? _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= <_TestTicker>{};
    final _TestTicker result = _TestTicker(onTick, _removeTicker);
    _tickers!.add(result);
    return result;
  }

  void _removeTicker(_TestTicker ticker) {
    assert(_tickers != null);
    assert(_tickers!.contains(ticker));
    _tickers!.remove(ticker);
  }

  void verifyTickersWereDisposed([String when = 'when none should have been']) {
    if (_tickers != null) {
      for (final Ticker ticker in _tickers!) {
        if (ticker.isActive) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('A Ticker was active $when.'),
            ErrorDescription('All Tickers must be disposed.'),
            ErrorHint('Tickers used by AnimationControllers '
                'should be disposed by calling dispose() on the AnimationController itself. '
                'Otherwise, the ticker will leak.'),
            ticker.describeForError('The offending ticker was'),
          ]);
        }
      }
    }
  }

  void _endOfTestVerifications() {
    verifyTickersWereDisposed('at the end of the test');
    _verifySemanticsHandlesWereDisposed();
  }

  void _verifySemanticsHandlesWereDisposed() {
    assert(_lastRecordedSemanticsHandles != null);
    // TODO(goderbauer): Fix known leak in web engine when running integration tests and remove this "correction", https://github.com/flutter/flutter/issues/121640.
    final int knownWebEngineLeakForLiveTestsCorrection =
        kIsWeb && binding is LiveTestWidgetsFlutterBinding ? 1 : 0;

    if (_currentSemanticsHandles - knownWebEngineLeakForLiveTestsCorrection >
        _lastRecordedSemanticsHandles!) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A SemanticsHandle was active at the end of the test.'),
        ErrorDescription(
            'All SemanticsHandle instances must be disposed by calling dispose() on '
            'the SemanticsHandle.'),
      ]);
    }
    _lastRecordedSemanticsHandles = null;
  }

  int? _lastRecordedSemanticsHandles;

  // TODO(goderbauer): Only use binding.debugOutstandingSemanticsHandles when deprecated binding.pipelineOwner is removed.
  // ignore: deprecated_member_use
  int get _currentSemanticsHandles =>
      binding.debugOutstandingSemanticsHandles +
      binding.pipelineOwner.debugOutstandingSemanticsHandles;

  void _recordNumberOfSemanticsHandles() {
    _lastRecordedSemanticsHandles = _currentSemanticsHandles;
  }

  TestTextInput get testTextInput => binding.testTextInput;

  Future<void> showKeyboard(FinderBase<Element> finder) async {
    bool skipOffstage = true;
    if (finder is Finder) {
      skipOffstage = finder.skipOffstage;
    }
    return TestAsyncUtils.guard<void>(() async {
      final EditableTextState editable = state<EditableTextState>(
        find.descendant(
          of: finder,
          matching: find.byType(EditableText, skipOffstage: skipOffstage),
          matchRoot: true,
        ),
      );
      // Setting focusedEditable causes the binding to call requestKeyboard()
      // on the EditableTextState, which itself eventually calls TextInput.attach
      // to establish the connection.
      binding.focusedEditable = editable;
      await pump();
    });
  }

  Future<void> enterText(FinderBase<Element> finder, String text) async {
    return TestAsyncUtils.guard<void>(() async {
      await showKeyboard(finder);
      testTextInput.enterText(text);
      await idle();
    });
  }

  Future<void> pageBack() async {
    return TestAsyncUtils.guard<void>(() async {
      Finder backButton = find.byTooltip('Back');
      if (backButton.evaluate().isEmpty) {
        backButton = find.byType(CupertinoNavigationBarBackButton);
      }

      expectSync(backButton, findsOneWidget,
          reason: 'One back button expected on screen');

      await tap(backButton);
    });
  }

  @override
  void printToConsole(String message) {
    binding.debugPrintOverride(message);
  }
}

typedef _TickerDisposeCallback = void Function(_TestTicker ticker);

class _TestTicker extends Ticker {
  _TestTicker(super.onTick, this._onDispose);

  final _TickerDisposeCallback _onDispose;

  @override
  void dispose() {
    _onDispose(this);
    super.dispose();
  }
}
