
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'event_simulation.dart';
import 'finders.dart';
import 'test_async_utils.dart';
import 'test_pointer.dart';
import 'tree_traversal.dart';
import 'window.dart';

const double kDragSlopDefault = 20.0;

const String _defaultPlatform = kIsWeb ? 'web' : 'android';

// Examples can assume:
// typedef MyWidget = Placeholder;

class SemanticsController {
  SemanticsController._(this._controller);

  static final int _scrollingActions =
    SemanticsAction.scrollUp.index |
    SemanticsAction.scrollDown.index |
    SemanticsAction.scrollLeft.index |
    SemanticsAction.scrollRight.index;

  static final int _importantFlagsForAccessibility =
    SemanticsFlag.hasCheckedState.index |
    SemanticsFlag.hasToggledState.index |
    SemanticsFlag.hasEnabledState.index |
    SemanticsFlag.isButton.index |
    SemanticsFlag.isTextField.index |
    SemanticsFlag.isFocusable.index |
    SemanticsFlag.isSlider.index |
    SemanticsFlag.isInMutuallyExclusiveGroup.index;

  final WidgetController _controller;

  SemanticsNode find(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    if (!_controller.binding.semanticsEnabled) {
      throw StateError('Semantics are not enabled.');
    }
    final Iterable<Element> candidates = finder.evaluate();
    if (candidates.isEmpty) {
      throw StateError('Finder returned no matching elements.');
    }
    if (candidates.length > 1) {
      throw StateError('Finder returned more than one element.');
    }
    final Element element = candidates.single;
    RenderObject? renderObject = element.findRenderObject();
    SemanticsNode? result = renderObject?.debugSemantics;
    while (renderObject != null && (result == null || result.isMergedIntoParent)) {
      renderObject = renderObject.parent;
      result = renderObject?.debugSemantics;
    }
    if (result == null) {
      throw StateError('No Semantics data found.');
    }
    return result;
  }

  Iterable<SemanticsNode> simulatedAccessibilityTraversal({FinderBase<Element>? start, FinderBase<Element>? end, FlutterView? view}) {
    TestAsyncUtils.guardSync();
    FlutterView? startView;
    FlutterView? endView;
    if (start != null) {
      startView = _controller.viewOf(start);
      if (view != null && startView != view) {
        throw StateError(
          'The start node is not part of the provided view.\n'
          'Finder: ${start.toString(describeSelf: true)}\n'
          'View of start node: $startView\n'
          'Specified view: $view'
        );
      }
    }
    if (end != null) {
      endView = _controller.viewOf(end);
      if (view != null && endView != view) {
        throw StateError(
          'The end node is not part of the provided view.\n'
          'Finder: ${end.toString(describeSelf: true)}\n'
          'View of end node: $endView\n'
          'Specified view: $view'
        );
      }
    }
    if (endView != null && startView != null && endView != startView) {
      throw StateError(
        'The start and end node are in different views.\n'
        'Start finder: ${start!.toString(describeSelf: true)}\n'
        'End finder: ${end!.toString(describeSelf: true)}\n'
        'View of start node: $startView\n'
        'View of end node: $endView'
      );
    }

    final FlutterView actualView = view ?? startView ?? endView ?? _controller.view;
    final RenderView renderView = _controller.binding.renderViews.firstWhere((RenderView r) => r.flutterView == actualView);

    final List<SemanticsNode> traversal = <SemanticsNode>[];
    _traverse(renderView.owner!.semanticsOwner!.rootSemanticsNode!, traversal);

    int startIndex = 0;
    int endIndex = traversal.length - 1;

    if (start != null) {
      final SemanticsNode startNode = find(start);
      startIndex = traversal.indexOf(startNode);
      if (startIndex == -1) {
        throw StateError(
          'The expected starting node was not found.\n'
          'Finder: ${start.toString(describeSelf: true)}\n\n'
          'Expected Start Node: $startNode\n\n'
          'Traversal: [\n  ${traversal.join('\n  ')}\n]');
      }
    }

    if (end != null) {
      final SemanticsNode endNode = find(end);
      endIndex = traversal.indexOf(endNode);
      if (endIndex == -1) {
        throw StateError(
          'The expected ending node was not found.\n'
          'Finder: ${end.toString(describeSelf: true)}\n\n'
          'Expected End Node: $endNode\n\n'
          'Traversal: [\n  ${traversal.join('\n  ')}\n]');
      }
    }

    return traversal.getRange(startIndex, endIndex + 1);
  }

  void _traverse(SemanticsNode node, List<SemanticsNode> traversal){
    if (_isImportantForAccessibility(node)) {
      traversal.add(node);
    }

    final List<SemanticsNode> children = node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);
    for (final SemanticsNode child in children) {
      _traverse(child, traversal);
    }
  }

  bool _isImportantForAccessibility(SemanticsNode node) {
    // If the node scopes a route, it doesn't matter what other flags/actions it
    // has, it is _not_ important for accessibility, so we short circuit.
    if (node.hasFlag(SemanticsFlag.scopesRoute)) {
      return false;
    }

    final bool hasNonScrollingAction = node.getSemanticsData().actions & ~_scrollingActions != 0;
    if (hasNonScrollingAction) {
      return true;
    }

    final bool hasImportantFlag = node.getSemanticsData().flags & _importantFlagsForAccessibility != 0;
    if (hasImportantFlag) {
      return true;
    }

    final bool hasContent = node.label.isNotEmpty || node.value.isNotEmpty || node.hint.isNotEmpty;
    if (hasContent) {
      return true;
    }

    return false;
  }
}

abstract class WidgetController {
  WidgetController(this.binding);

  final WidgetsBinding binding;

  TestPlatformDispatcher get platformDispatcher => binding.platformDispatcher as TestPlatformDispatcher;

  TestFlutterView get view => platformDispatcher.implicitView!;

  SemanticsController get semantics {
    if (!binding.semanticsEnabled) {
      throw StateError(
        'Semantics are not enabled. Enable them by passing '
        '`semanticsEnabled: true` to `testWidgets`, or by manually creating a '
        '`SemanticsHandle` with `WidgetController.ensureSemantics()`.');
    }

    return _semantics;
  }
  late final SemanticsController _semantics = SemanticsController._(this);

  // FINDER API

  // TODO(ianh): verify that the return values are of type T and throw
  // a good message otherwise, in all the generic methods below

  TestFlutterView viewOf(FinderBase<Element> finder) {
    return _viewOf(finder) as TestFlutterView;
  }

  FlutterView _viewOf(FinderBase<Element> finder) {
    return firstWidget<View>(
      find.ancestor(
        of: finder,
        matching: find.byType(View),
      ),
    ).view;
  }

  bool any(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().isNotEmpty;
  }

  Iterable<Widget> get allWidgets {
    TestAsyncUtils.guardSync();
    return allElements.map<Widget>((Element element) => element.widget);
  }

  T widget<T extends Widget>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().single.widget as T;
  }

  T firstWidget<T extends Widget>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().first.widget as T;
  }

  Iterable<T> widgetList<T extends Widget>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().map<T>((Element element) {
      final T result = element.widget as T;
      return result;
    });
  }

  Iterable<Layer> layerListOf(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    final Element element = finder.evaluate().single;
    final RenderObject object = element.renderObject!;
    RenderObject current = object;
    while (current.debugLayer == null) {
      current = current.parent!;
    }
    final ContainerLayer layer = current.debugLayer!;
    return _walkLayers(layer);
  }

  Iterable<Element> get allElements {
    TestAsyncUtils.guardSync();
    return collectAllElementsFrom(binding.rootElement!, skipOffstage: false);
  }

  T element<T extends Element>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().single as T;
  }

  T firstElement<T extends Element>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().first as T;
  }

  Iterable<T> elementList<T extends Element>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().cast<T>();
  }

  Iterable<State> get allStates {
    TestAsyncUtils.guardSync();
    return allElements.whereType<StatefulElement>().map<State>((StatefulElement element) => element.state);
  }

  T state<T extends State>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return _stateOf<T>(finder.evaluate().single, finder);
  }

  T firstState<T extends State>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return _stateOf<T>(finder.evaluate().first, finder);
  }

  Iterable<T> stateList<T extends State>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().map<T>((Element element) => _stateOf<T>(element, finder));
  }

  T _stateOf<T extends State>(Element element, FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    if (element is StatefulElement) {
      return element.state as T;
    }
    throw StateError('Widget of type ${element.widget.runtimeType}, with ${finder.describeMatch(Plurality.many)}, is not a StatefulWidget.');
  }

  Iterable<RenderObject> get allRenderObjects {
    TestAsyncUtils.guardSync();
    return allElements.map<RenderObject>((Element element) => element.renderObject!);
  }

  T renderObject<T extends RenderObject>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().single.renderObject! as T;
  }

  T firstRenderObject<T extends RenderObject>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().first.renderObject! as T;
  }

  Iterable<T> renderObjectList<T extends RenderObject>(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().map<T>((Element element) {
      final T result = element.renderObject! as T;
      return result;
    });
  }

  List<Layer> get layers {
    return <Layer>[
      for (final RenderView renderView in binding.renderViews)
        ..._walkLayers(renderView.debugLayer!)
    ];
  }
  Iterable<Layer> _walkLayers(Layer layer) sync* {
    TestAsyncUtils.guardSync();
    yield layer;
    if (layer is ContainerLayer) {
      final ContainerLayer root = layer;
      Layer? child = root.firstChild;
      while (child != null) {
        yield* _walkLayers(child);
        child = child.nextSibling;
      }
    }
  }

  // INTERACTION

  Future<void> tap(FinderBase<Element> finder, {int? pointer, int buttons = kPrimaryButton, bool warnIfMissed = true}) {
    return tapAt(getCenter(finder, warnIfMissed: warnIfMissed, callee: 'tap'), pointer: pointer, buttons: buttons);
  }

  Future<void> tapAt(Offset location, {int? pointer, int buttons = kPrimaryButton}) {
    return TestAsyncUtils.guard<void>(() async {
      final TestGesture gesture = await startGesture(location, pointer: pointer, buttons: buttons);
      await gesture.up();
    });
  }

  Future<TestGesture> press(FinderBase<Element> finder, {int? pointer, int buttons = kPrimaryButton, bool warnIfMissed = true}) {
    return TestAsyncUtils.guard<TestGesture>(() {
      return startGesture(getCenter(finder, warnIfMissed: warnIfMissed, callee: 'press'), pointer: pointer, buttons: buttons);
    });
  }

  Future<void> longPress(FinderBase<Element> finder, {int? pointer, int buttons = kPrimaryButton, bool warnIfMissed = true}) {
    return longPressAt(getCenter(finder, warnIfMissed: warnIfMissed, callee: 'longPress'), pointer: pointer, buttons: buttons);
  }

  Future<void> longPressAt(Offset location, {int? pointer, int buttons = kPrimaryButton}) {
    return TestAsyncUtils.guard<void>(() async {
      final TestGesture gesture = await startGesture(location, pointer: pointer, buttons: buttons);
      await pump(kLongPressTimeout + kPressTimeout);
      await gesture.up();
    });
  }

  Future<void> fling(
    FinderBase<Element> finder,
    Offset offset,
    double speed, {
    int? pointer,
    int buttons = kPrimaryButton,
    Duration frameInterval = const Duration(milliseconds: 16),
    Offset initialOffset = Offset.zero,
    Duration initialOffsetDelay = const Duration(seconds: 1),
    bool warnIfMissed = true,
    PointerDeviceKind deviceKind = PointerDeviceKind.touch,
  }) {
    return flingFrom(
      getCenter(finder, warnIfMissed: warnIfMissed, callee: 'fling'),
      offset,
      speed,
      pointer: pointer,
      buttons: buttons,
      frameInterval: frameInterval,
      initialOffset: initialOffset,
      initialOffsetDelay: initialOffsetDelay,
      deviceKind: deviceKind,
    );
  }

  Future<void> flingFrom(
    Offset startLocation,
    Offset offset,
    double speed, {
    int? pointer,
    int buttons = kPrimaryButton,
    Duration frameInterval = const Duration(milliseconds: 16),
    Offset initialOffset = Offset.zero,
    Duration initialOffsetDelay = const Duration(seconds: 1),
    PointerDeviceKind deviceKind = PointerDeviceKind.touch,
  }) {
    assert(offset.distance > 0.0);
    assert(speed > 0.0); // speed is pixels/second
    return TestAsyncUtils.guard<void>(() async {
      final TestPointer testPointer = TestPointer(pointer ?? _getNextPointer(), deviceKind, null, buttons);
      const int kMoveCount = 50; // Needs to be >= kHistorySize, see _LeastSquaresVelocityTrackerStrategy
      final double timeStampDelta = 1000000.0 * offset.distance / (kMoveCount * speed);
      double timeStamp = 0.0;
      double lastTimeStamp = timeStamp;
      await sendEventToBinding(testPointer.down(startLocation, timeStamp: Duration(microseconds: timeStamp.round())));
      if (initialOffset.distance > 0.0) {
        await sendEventToBinding(testPointer.move(startLocation + initialOffset, timeStamp: Duration(microseconds: timeStamp.round())));
        timeStamp += initialOffsetDelay.inMicroseconds;
        await pump(initialOffsetDelay);
      }
      for (int i = 0; i <= kMoveCount; i += 1) {
        final Offset location = startLocation + initialOffset + Offset.lerp(Offset.zero, offset, i / kMoveCount)!;
        await sendEventToBinding(testPointer.move(location, timeStamp: Duration(microseconds: timeStamp.round())));
        timeStamp += timeStampDelta;
        if (timeStamp - lastTimeStamp > frameInterval.inMicroseconds) {
          await pump(Duration(microseconds: (timeStamp - lastTimeStamp).truncate()));
          lastTimeStamp = timeStamp;
        }
      }
      await sendEventToBinding(testPointer.up(timeStamp: Duration(microseconds: timeStamp.round())));
    });
  }

  Future<void> trackpadFling(
    FinderBase<Element> finder,
    Offset offset,
    double speed, {
    int? pointer,
    int buttons = kPrimaryButton,
    Duration frameInterval = const Duration(milliseconds: 16),
    Offset initialOffset = Offset.zero,
    Duration initialOffsetDelay = const Duration(seconds: 1),
    bool warnIfMissed = true,
  }) {
    return trackpadFlingFrom(
      getCenter(finder, warnIfMissed: warnIfMissed, callee: 'fling'),
      offset,
      speed,
      pointer: pointer,
      buttons: buttons,
      frameInterval: frameInterval,
      initialOffset: initialOffset,
      initialOffsetDelay: initialOffsetDelay,
    );
  }

  Future<void> trackpadFlingFrom(
    Offset startLocation,
    Offset offset,
    double speed, {
    int? pointer,
    int buttons = kPrimaryButton,
    Duration frameInterval = const Duration(milliseconds: 16),
    Offset initialOffset = Offset.zero,
    Duration initialOffsetDelay = const Duration(seconds: 1),
  }) {
    assert(offset.distance > 0.0);
    assert(speed > 0.0); // speed is pixels/second
    return TestAsyncUtils.guard<void>(() async {
      final TestPointer testPointer = TestPointer(pointer ?? _getNextPointer(), PointerDeviceKind.trackpad, null, buttons);
      const int kMoveCount = 50; // Needs to be >= kHistorySize, see _LeastSquaresVelocityTrackerStrategy
      final double timeStampDelta = 1000000.0 * offset.distance / (kMoveCount * speed);
      double timeStamp = 0.0;
      double lastTimeStamp = timeStamp;
      await sendEventToBinding(testPointer.panZoomStart(startLocation, timeStamp: Duration(microseconds: timeStamp.round())));
      if (initialOffset.distance > 0.0) {
        await sendEventToBinding(testPointer.panZoomUpdate(startLocation, pan: initialOffset, timeStamp: Duration(microseconds: timeStamp.round())));
        timeStamp += initialOffsetDelay.inMicroseconds;
        await pump(initialOffsetDelay);
      }
      for (int i = 0; i <= kMoveCount; i += 1) {
        final Offset pan = initialOffset + Offset.lerp(Offset.zero, offset, i / kMoveCount)!;
        await sendEventToBinding(testPointer.panZoomUpdate(startLocation, pan: pan, timeStamp: Duration(microseconds: timeStamp.round())));
        timeStamp += timeStampDelta;
        if (timeStamp - lastTimeStamp > frameInterval.inMicroseconds) {
          await pump(Duration(microseconds: (timeStamp - lastTimeStamp).truncate()));
          lastTimeStamp = timeStamp;
        }
      }
      await sendEventToBinding(testPointer.panZoomEnd(timeStamp: Duration(microseconds: timeStamp.round())));
    });
  }

  Future<List<Duration>> handlePointerEventRecord(List<PointerEventRecord> records);

  Future<void> pump([Duration duration]);

  Future<int> pumpAndSettle([
    Duration duration = const Duration(milliseconds: 100),
  ]);

  Future<void> drag(
    FinderBase<Element> finder,
    Offset offset, {
    int? pointer,
    int buttons = kPrimaryButton,
    double touchSlopX = kDragSlopDefault,
    double touchSlopY = kDragSlopDefault,
    bool warnIfMissed = true,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) {
    return dragFrom(
      getCenter(finder, warnIfMissed: warnIfMissed, callee: 'drag'),
      offset,
      pointer: pointer,
      buttons: buttons,
      touchSlopX: touchSlopX,
      touchSlopY: touchSlopY,
      kind: kind,
    );
  }

  Future<void> dragFrom(
    Offset startLocation,
    Offset offset, {
    int? pointer,
    int buttons = kPrimaryButton,
    double touchSlopX = kDragSlopDefault,
    double touchSlopY = kDragSlopDefault,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) {
    assert(kDragSlopDefault > kTouchSlop);
    return TestAsyncUtils.guard<void>(() async {
      final TestGesture gesture = await startGesture(startLocation, pointer: pointer, buttons: buttons, kind: kind);

      final double xSign = offset.dx.sign;
      final double ySign = offset.dy.sign;

      final double offsetX = offset.dx;
      final double offsetY = offset.dy;

      final bool separateX = offset.dx.abs() > touchSlopX && touchSlopX > 0;
      final bool separateY = offset.dy.abs() > touchSlopY && touchSlopY > 0;

      if (separateY || separateX) {
        final double offsetSlope = offsetY / offsetX;
        final double inverseOffsetSlope = offsetX / offsetY;
        final double slopSlope = touchSlopY / touchSlopX;
        final double absoluteOffsetSlope = offsetSlope.abs();
        final double signedSlopX = touchSlopX * xSign;
        final double signedSlopY = touchSlopY * ySign;
        if (absoluteOffsetSlope != slopSlope) {
          // The drag goes through one or both of the extents of the edges of the box.
          if (absoluteOffsetSlope < slopSlope) {
            assert(offsetX.abs() > touchSlopX);
            // The drag goes through the vertical edge of the box.
            // It is guaranteed that the |offsetX| > touchSlopX.
            final double diffY = offsetSlope.abs() * touchSlopX * ySign;

            // The vector from the origin to the vertical edge.
            await gesture.moveBy(Offset(signedSlopX, diffY));
            if (offsetY.abs() <= touchSlopY) {
              // The drag ends on or before getting to the horizontal extension of the horizontal edge.
              await gesture.moveBy(Offset(offsetX - signedSlopX, offsetY - diffY));
            } else {
              final double diffY2 = signedSlopY - diffY;
              final double diffX2 = inverseOffsetSlope * diffY2;

              // The vector from the edge of the box to the horizontal extension of the horizontal edge.
              await gesture.moveBy(Offset(diffX2, diffY2));
              await gesture.moveBy(Offset(offsetX - diffX2 - signedSlopX, offsetY - signedSlopY));
            }
          } else {
            assert(offsetY.abs() > touchSlopY);
            // The drag goes through the horizontal edge of the box.
            // It is guaranteed that the |offsetY| > touchSlopY.
            final double diffX = inverseOffsetSlope.abs() * touchSlopY * xSign;

            // The vector from the origin to the vertical edge.
            await gesture.moveBy(Offset(diffX, signedSlopY));
            if (offsetX.abs() <= touchSlopX) {
              // The drag ends on or before getting to the vertical extension of the vertical edge.
              await gesture.moveBy(Offset(offsetX - diffX, offsetY - signedSlopY));
            } else {
              final double diffX2 = signedSlopX - diffX;
              final double diffY2 = offsetSlope * diffX2;

              // The vector from the edge of the box to the vertical extension of the vertical edge.
              await gesture.moveBy(Offset(diffX2, diffY2));
              await gesture.moveBy(Offset(offsetX - signedSlopX, offsetY - diffY2 - signedSlopY));
            }
          }
        } else { // The drag goes through the corner of the box.
          await gesture.moveBy(Offset(signedSlopX, signedSlopY));
          await gesture.moveBy(Offset(offsetX - signedSlopX, offsetY - signedSlopY));
        }
      } else { // The drag ends inside the box.
        await gesture.moveBy(offset);
      }
      await gesture.up();
    });
  }

  Future<void> timedDrag(
    FinderBase<Element> finder,
    Offset offset,
    Duration duration, {
    int? pointer,
    int buttons = kPrimaryButton,
    double frequency = 60.0,
    bool warnIfMissed = true,
  }) {
    return timedDragFrom(
      getCenter(finder, warnIfMissed: warnIfMissed, callee: 'timedDrag'),
      offset,
      duration,
      pointer: pointer,
      buttons: buttons,
      frequency: frequency,
    );
  }

  Future<void> timedDragFrom(
    Offset startLocation,
    Offset offset,
    Duration duration, {
    int? pointer,
    int buttons = kPrimaryButton,
    double frequency = 60.0,
  }) {
    assert(frequency > 0);
    final int intervals = duration.inMicroseconds * frequency ~/ 1E6;
    assert(intervals > 1);
    pointer ??= _getNextPointer();
    final List<Duration> timeStamps = <Duration>[
      for (int t = 0; t <= intervals; t += 1)
        duration * t ~/ intervals,
    ];
    final List<Offset> offsets = <Offset>[
      startLocation,
      for (int t = 0; t <= intervals; t += 1)
        startLocation + offset * (t / intervals),
    ];
    final List<PointerEventRecord> records = <PointerEventRecord>[
      PointerEventRecord(Duration.zero, <PointerEvent>[
          PointerAddedEvent(
            position: startLocation,
          ),
          PointerDownEvent(
            position: startLocation,
            pointer: pointer,
            buttons: buttons,
          ),
        ]),
      ...<PointerEventRecord>[
        for (int t = 0; t <= intervals; t += 1)
          PointerEventRecord(timeStamps[t], <PointerEvent>[
            PointerMoveEvent(
              timeStamp: timeStamps[t],
              position: offsets[t+1],
              delta: offsets[t+1] - offsets[t],
              pointer: pointer,
              buttons: buttons,
            ),
          ]),
      ],
      PointerEventRecord(duration, <PointerEvent>[
        PointerUpEvent(
          timeStamp: duration,
          position: offsets.last,
          pointer: pointer,
          // The PointerData received from the engine with
          // change = PointerChange.up, which translates to PointerUpEvent,
          // doesn't provide the button field.
          // buttons: buttons,
        ),
      ]),
    ];
    return TestAsyncUtils.guard<void>(() async {
      await handlePointerEventRecord(records);
    });
  }

  int get nextPointer => _nextPointer;

  static int _nextPointer = 1;

  static int _getNextPointer() {
    final int result = _nextPointer;
    _nextPointer += 1;
    return result;
  }

  TestGesture _createGesture({
    int? pointer,
    required PointerDeviceKind kind,
    required int buttons,
  }) {
    return TestGesture(
      dispatcher: sendEventToBinding,
      kind: kind,
      pointer: pointer ?? _getNextPointer(),
      buttons: buttons,
    );
  }

  Future<TestGesture> createGesture({
    int? pointer,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int buttons = kPrimaryButton,
  }) async {
    return _createGesture(pointer: pointer, kind: kind, buttons: buttons);
  }

  Future<TestGesture> startGesture(
    Offset downLocation, {
    int? pointer,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int buttons = kPrimaryButton,
  }) async {
    final TestGesture result = _createGesture(pointer: pointer, kind: kind, buttons: buttons);
    if (kind == PointerDeviceKind.trackpad) {
      await result.panZoomStart(downLocation);
    } else {
      await result.down(downLocation);
    }
    return result;
  }

  HitTestResult hitTestOnBinding(Offset location, { int? viewId }) {
    viewId ??= view.viewId;
    final HitTestResult result = HitTestResult();
    binding.hitTestInView(result, location, viewId);
    return result;
  }

  Future<void> sendEventToBinding(PointerEvent event) {
    return TestAsyncUtils.guard<void>(() async {
      binding.handlePointerEvent(event);
    });
  }

  @protected
  void printToConsole(String message) {
    debugPrint(message);
  }

  // GEOMETRY

  Offset getCenter(FinderBase<Element> finder, { bool warnIfMissed = false, String callee = 'getCenter' }) {
    return _getElementPoint(finder, (Size size) => size.center(Offset.zero), warnIfMissed: warnIfMissed, callee: callee);
  }

  Offset getTopLeft(FinderBase<Element> finder, { bool warnIfMissed = false, String callee = 'getTopLeft' }) {
    return _getElementPoint(finder, (Size size) => Offset.zero, warnIfMissed: warnIfMissed, callee: callee);
  }

  Offset getTopRight(FinderBase<Element> finder, { bool warnIfMissed = false, String callee = 'getTopRight' }) {
    return _getElementPoint(finder, (Size size) => size.topRight(Offset.zero), warnIfMissed: warnIfMissed, callee: callee);
  }

  Offset getBottomLeft(FinderBase<Element> finder, { bool warnIfMissed = false, String callee = 'getBottomLeft' }) {
    return _getElementPoint(finder, (Size size) => size.bottomLeft(Offset.zero), warnIfMissed: warnIfMissed, callee: callee);
  }

  Offset getBottomRight(FinderBase<Element> finder, { bool warnIfMissed = false, String callee = 'getBottomRight' }) {
    return _getElementPoint(finder, (Size size) => size.bottomRight(Offset.zero), warnIfMissed: warnIfMissed, callee: callee);
  }

  static bool hitTestWarningShouldBeFatal = false;

  Offset _getElementPoint(FinderBase<Element> finder, Offset Function(Size size) sizeToPoint, { required bool warnIfMissed, required String callee }) {
    TestAsyncUtils.guardSync();
    final Iterable<Element> elements = finder.evaluate();
    if (elements.isEmpty) {
      throw FlutterError('The finder "$finder" (used in a call to "$callee()") could not find any matching widgets.');
    }
    if (elements.length > 1) {
      throw FlutterError('The finder "$finder" (used in a call to "$callee()") ambiguously found multiple matching widgets. The "$callee()" method needs a single target.');
    }
    final Element element = elements.single;
    final RenderObject? renderObject = element.renderObject;
    if (renderObject == null) {
      throw FlutterError(
        'The finder "$finder" (used in a call to "$callee()") found an element, but it does not have a corresponding render object. '
        'Maybe the element has not yet been rendered?'
      );
    }
    if (renderObject is! RenderBox) {
      throw FlutterError(
        'The finder "$finder" (used in a call to "$callee()") found an element whose corresponding render object is not a RenderBox (it is a ${renderObject.runtimeType}: "$renderObject"). '
        'Unfortunately "$callee()" only supports targeting widgets that correspond to RenderBox objects in the rendering.'
      );
    }
    final RenderBox box = element.renderObject! as RenderBox;
    final Offset location = box.localToGlobal(sizeToPoint(box.size));
    if (warnIfMissed) {
      final FlutterView view = _viewOf(finder);
      final HitTestResult result = HitTestResult();
      binding.hitTestInView(result, location, view.viewId);
      bool found = false;
      for (final HitTestEntry entry in result.path) {
        if (entry.target == box) {
          found = true;
          break;
        }
      }
      if (!found) {
        final RenderView renderView = binding.renderViews.firstWhere((RenderView r) => r.flutterView == view);
        bool outOfBounds = false;
        outOfBounds = !(Offset.zero & renderView.size).contains(location);
        if (hitTestWarningShouldBeFatal) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Finder specifies a widget that would not receive pointer events.'),
            ErrorDescription('A call to $callee() with finder "$finder" derived an Offset ($location) that would not hit test on the specified widget.'),
            ErrorHint('Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.'),
            if (outOfBounds)
              ErrorHint('Indeed, $location is outside the bounds of the root of the render tree, ${renderView.size}.'),
            box.toDiagnosticsNode(name: 'The finder corresponds to this RenderBox', style: DiagnosticsTreeStyle.singleLine),
            ErrorDescription('The hit test result at that offset is: $result'),
            ErrorDescription('If you expected this target not to be able to receive pointer events, pass "warnIfMissed: false" to "$callee()".'),
            ErrorDescription('To make this error into a non-fatal warning, set WidgetController.hitTestWarningShouldBeFatal to false.'),
          ]);
        }
        printToConsole(
          '\n'
          'Warning: A call to $callee() with finder "$finder" derived an Offset ($location) that would not hit test on the specified widget.\n'
          'Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.\n'
          '${outOfBounds ? "Indeed, $location is outside the bounds of the root of the render tree, ${renderView.size}.\n" : ""}'
          'The finder corresponds to this RenderBox: $box\n'
          'The hit test result at that offset is: $result\n'
          '${StackTrace.current}'
          'To silence this warning, pass "warnIfMissed: false" to "$callee()".\n'
          'To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.\n',
        );
      }
    }
    return location;
  }

  Size getSize(FinderBase<Element> finder) {
    TestAsyncUtils.guardSync();
    final Element element = finder.evaluate().single;
    final RenderBox box = element.renderObject! as RenderBox;
    return box.size;
  }

  Future<bool> sendKeyEvent(
    LogicalKeyboardKey key, {
    String platform = _defaultPlatform,
    String? character,
    PhysicalKeyboardKey? physicalKey
  }) async {
    final bool handled = await simulateKeyDownEvent(key, platform: platform, character: character, physicalKey: physicalKey);
    // Internally wrapped in async guard.
    await simulateKeyUpEvent(key, platform: platform, physicalKey: physicalKey);
    return handled;
  }

  Future<bool> sendKeyDownEvent(
    LogicalKeyboardKey key, {
    String platform = _defaultPlatform,
    String? character,
    PhysicalKeyboardKey? physicalKey
  }) async {
    // Internally wrapped in async guard.
    return simulateKeyDownEvent(key, platform: platform, character: character, physicalKey: physicalKey);
  }

  Future<bool> sendKeyUpEvent(
      LogicalKeyboardKey key, {
        String platform = _defaultPlatform,
        PhysicalKeyboardKey? physicalKey
      }) async {
    // Internally wrapped in async guard.
    return simulateKeyUpEvent(key, platform: platform, physicalKey: physicalKey);
  }

  Future<bool> sendKeyRepeatEvent(
      LogicalKeyboardKey key, {
        String platform = _defaultPlatform,
        String? character,
        PhysicalKeyboardKey? physicalKey
      }) async {
    // Internally wrapped in async guard.
    return simulateKeyRepeatEvent(key, platform: platform, character: character, physicalKey: physicalKey);
  }

  Rect getRect(FinderBase<Element> finder) => Rect.fromPoints(getTopLeft(finder), getBottomRight(finder));

  // TODO(pdblasi-google): Deprecate this and point references to semantics.find. See https://github.com/flutter/flutter/issues/112670.
  SemanticsNode getSemantics(FinderBase<Element> finder) => semantics.find(finder);

  SemanticsHandle ensureSemantics() {
    return binding.ensureSemantics();
  }

  Future<void> ensureVisible(FinderBase<Element> finder) => Scrollable.ensureVisible(element(finder));

  Future<void> scrollUntilVisible(
    FinderBase<Element> finder,
    double delta, {
      FinderBase<Element>? scrollable,
      int maxScrolls = 50,
      Duration duration = const Duration(milliseconds: 50),
    }
  ) {
    assert(maxScrolls > 0);
    scrollable ??= find.byType(Scrollable);
    return TestAsyncUtils.guard<void>(() async {
      Offset moveStep;
      switch (widget<Scrollable>(scrollable!).axisDirection) {
        case AxisDirection.up:
          moveStep = Offset(0, delta);
        case AxisDirection.down:
          moveStep = Offset(0, -delta);
        case AxisDirection.left:
          moveStep = Offset(delta, 0);
        case AxisDirection.right:
          moveStep = Offset(-delta, 0);
      }
      await dragUntilVisible(
        finder,
        scrollable,
        moveStep,
        maxIteration: maxScrolls,
        duration: duration,
      );
    });
  }

  Future<void> dragUntilVisible(
    FinderBase<Element> finder,
    FinderBase<Element> view,
    Offset moveStep, {
      int maxIteration = 50,
      Duration duration = const Duration(milliseconds: 50),
  }) {
    return TestAsyncUtils.guard<void>(() async {
      while (maxIteration > 0 && finder.evaluate().isEmpty) {
        await drag(view, moveStep);
        await pump(duration);
        maxIteration -= 1;
      }
      await Scrollable.ensureVisible(element(finder));
    });
  }
}

class LiveWidgetController extends WidgetController {
  LiveWidgetController(super.binding);

  @override
  Future<void> pump([Duration? duration]) async {
    if (duration != null) {
      await Future<void>.delayed(duration);
    }
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  @override
  Future<int> pumpAndSettle([
    Duration duration = const Duration(milliseconds: 100),
  ]) {
    assert(duration > Duration.zero);
    return TestAsyncUtils.guard<int>(() async {
      int count = 0;
      do {
        await pump(duration);
        count += 1;
      } while (binding.hasScheduledFrame);
      return count;
    });
  }

  @override
  Future<List<Duration>> handlePointerEventRecord(List<PointerEventRecord> records) {
    assert(records.isNotEmpty);
    return TestAsyncUtils.guard<List<Duration>>(() async {
      final List<Duration> handleTimeStampDiff = <Duration>[];
      DateTime? startTime;
      for (final PointerEventRecord record in records) {
        final DateTime now = clock.now();
        startTime ??= now;
        // So that the first event is promised to receive a zero timeDiff.
        final Duration timeDiff = record.timeDelay - now.difference(startTime);
        if (timeDiff.isNegative) {
          // This happens when something (e.g. GC) takes a long time during the
          // processing of the events.
          // Flush all past events.
          handleTimeStampDiff.add(-timeDiff);
          record.events.forEach(binding.handlePointerEvent);
        } else {
          await Future<void>.delayed(timeDiff);
          handleTimeStampDiff.add(
            // Recalculating the time diff for getting exact time when the event
            // packet is sent. For a perfect Future.delayed like the one in a
            // fake async this new diff should be zero.
            clock.now().difference(startTime) - record.timeDelay,
          );
          record.events.forEach(binding.handlePointerEvent);
        }
      }

      return handleTimeStampDiff;
    });
  }
}