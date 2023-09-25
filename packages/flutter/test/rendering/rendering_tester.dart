
import 'dart:async';
import 'dart:ui' show SemanticsUpdate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' show EnginePhase, TestDefaultBinaryMessengerBinding, fail;

export 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
export 'package:flutter_test/flutter_test.dart' show EnginePhase, TestDefaultBinaryMessengerBinding;

class TestRenderingFlutterBinding extends BindingBase with SchedulerBinding, ServicesBinding, GestureBinding, PaintingBinding, SemanticsBinding, RendererBinding, TestDefaultBinaryMessengerBinding {
  TestRenderingFlutterBinding({ this.onErrors }) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      Zone.current.parent!.handleUncaughtError(details.exception, details.stack!);
    };
  }

  static TestRenderingFlutterBinding get instance => BindingBase.checkInstance(_instance);
  static TestRenderingFlutterBinding? _instance;

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    // TODO(goderbauer): Create (fake) window if embedder doesn't provide an implicit view.
    assert(platformDispatcher.implicitView != null);
    _renderView = initRenderView(platformDispatcher.implicitView!);
  }

  @override
  RenderView get renderView => _renderView;
  late RenderView _renderView;

  @override
  PipelineOwner get pipelineOwner => rootPipelineOwner;

  RenderView initRenderView(FlutterView view) {
    final RenderView renderView = RenderView(view: view);
    rootPipelineOwner.rootNode = renderView;
    addRenderView(renderView);
    renderView.prepareInitialFrame();
    return renderView;
  }

  @override
  PipelineOwner createRootPipelineOwner() {
    return PipelineOwner(
      onSemanticsOwnerCreated: () {
        renderView.scheduleInitialSemantics();
      },
      onSemanticsUpdate: (SemanticsUpdate update) {
        renderView.updateSemantics(update);
      },
      onSemanticsOwnerDisposed: () {
        renderView.clearSemantics();
      },
    );
  }

  static TestRenderingFlutterBinding ensureInitialized({ VoidCallback? onErrors }) {
    if (_instance != null) {
      return _instance!;
    }
    return TestRenderingFlutterBinding(onErrors: onErrors);
  }

  final List<FlutterErrorDetails> _errors = <FlutterErrorDetails>[];

  VoidCallback? onErrors;

  FlutterErrorDetails? takeFlutterErrorDetails() {
    if (_errors.isEmpty) {
      return null;
    }
    return _errors.removeAt(0);
  }

  Iterable<FlutterErrorDetails> takeAllFlutterErrorDetails() sync* {
    // sync* and yield are used for lazy evaluation. Otherwise, the list would be
    // drained eagerly and allow a test pass with unexpected errors.
    while (_errors.isNotEmpty) {
      yield _errors.removeAt(0);
    }
  }

  Iterable<dynamic> takeAllFlutterExceptions() sync* {
    // sync* and yield are used for lazy evaluation. Otherwise, the list would be
    // drained eagerly and allow a test pass with unexpected errors.
    while (_errors.isNotEmpty) {
      yield _errors.removeAt(0).exception;
    }
  }

  EnginePhase phase = EnginePhase.composite;

  void pumpCompleteFrame() {
    final FlutterExceptionHandler? oldErrorHandler = FlutterError.onError;
    FlutterError.onError = _errors.add;
    try {
      TestRenderingFlutterBinding.instance.handleBeginFrame(null);
      TestRenderingFlutterBinding.instance.handleDrawFrame();
    } finally {
      FlutterError.onError = oldErrorHandler;
      if (_errors.isNotEmpty) {
        if (onErrors != null) {
          onErrors!();
          if (_errors.isNotEmpty) {
            _errors.forEach(FlutterError.dumpErrorToConsole);
            fail('There are more errors than the test inspected using TestRenderingFlutterBinding.takeFlutterErrorDetails.');
          }
        } else {
          _errors.forEach(FlutterError.dumpErrorToConsole);
          fail('Caught error while rendering frame. See preceding logs for details.');
        }
      }
    }
  }

  @override
  void drawFrame() {
    assert(phase != EnginePhase.build, 'rendering_tester does not support testing the build phase; use flutter_test instead');
    final FlutterExceptionHandler? oldErrorHandler = FlutterError.onError;
    FlutterError.onError = _errors.add;
    try {
      rootPipelineOwner.flushLayout();
      if (phase == EnginePhase.layout) {
        return;
      }
      rootPipelineOwner.flushCompositingBits();
      if (phase == EnginePhase.compositingBits) {
        return;
      }
      rootPipelineOwner.flushPaint();
      if (phase == EnginePhase.paint) {
        return;
      }
      for (final RenderView renderView in renderViews) {
        renderView.compositeFrame();
      }
      if (phase == EnginePhase.composite) {
        return;
      }
      rootPipelineOwner.flushSemantics();
      if (phase == EnginePhase.flushSemantics) {
        return;
      }
      assert(phase == EnginePhase.flushSemantics || phase == EnginePhase.sendSemanticsUpdate);
    } finally {
      FlutterError.onError = oldErrorHandler;
      if (_errors.isNotEmpty) {
        if (onErrors != null) {
          onErrors!();
          if (_errors.isNotEmpty) {
            _errors.forEach(FlutterError.dumpErrorToConsole);
            fail('There are more errors than the test inspected using TestRenderingFlutterBinding.takeFlutterErrorDetails.');
          }
        } else {
          _errors.forEach(FlutterError.dumpErrorToConsole);
          fail('Caught error while rendering frame. See preceding logs for details.');
        }
      }
    }
  }
}

void layout(
  RenderBox box, { // If you want to just repump the last box, call pumpFrame().
  BoxConstraints? constraints,
  Alignment alignment = Alignment.center,
  EnginePhase phase = EnginePhase.layout,
  VoidCallback? onErrors,
}) {
  assert(box.parent == null); // We stick the box in another, so you can't reuse it easily, sorry.

  TestRenderingFlutterBinding.instance.renderView.child = null;
  if (constraints != null) {
    box = RenderPositionedBox(
      alignment: alignment,
      child: RenderConstrainedBox(
        additionalConstraints: constraints,
        child: box,
      ),
    );
  }
  TestRenderingFlutterBinding.instance.renderView.child = box;

  pumpFrame(phase: phase, onErrors: onErrors);
}

void pumpFrame({ EnginePhase phase = EnginePhase.layout, VoidCallback? onErrors }) {
  assert(TestRenderingFlutterBinding.instance.renderView.child != null); // call layout() first!

  if (onErrors != null) {
    TestRenderingFlutterBinding.instance.onErrors = onErrors;
  }

  TestRenderingFlutterBinding.instance.phase = phase;
  TestRenderingFlutterBinding.instance.drawFrame();
}

class TestCallbackPainter extends CustomPainter {
  const TestCallbackPainter({ required this.onPaint });

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
  }

  @override
  bool shouldRepaint(TestCallbackPainter oldPainter) => true;
}

class RenderSizedBox extends RenderBox {
  RenderSizedBox(this._size);

  final Size _size;

  @override
  double computeMinIntrinsicWidth(double height) {
    return _size.width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _size.width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _size.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _size.height;
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.constrain(_size);
  }

  @override
  void performLayout() { }

  @override
  bool hitTestSelf(Offset position) => true;
}

class FakeTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick, [ bool disableAnimations = false ]) {
    return FakeTicker();
  }
}

class FakeTicker implements Ticker {
  @override
  bool muted = false;

  @override
  void absorbTicker(Ticker originalTicker) { }

  @override
  String? get debugLabel => null;

  @override
  bool get isActive => throw UnimplementedError();

  @override
  bool get isTicking => throw UnimplementedError();

  @override
  bool get scheduled => throw UnimplementedError();

  @override
  bool get shouldScheduleTick => throw UnimplementedError();

  @override
  void dispose() { }

  @override
  void scheduleTick({ bool rescheduling = false }) { }

  @override
  TickerFuture start() {
    throw UnimplementedError();
  }

  @override
  void stop({ bool canceled = false }) { }

  @override
  void unscheduleTick() { }

  @override
  String toString({ bool debugIncludeStack = false }) => super.toString();

  @override
  DiagnosticsNode describeForError(String name) {
    return DiagnosticsProperty<Ticker>(name, this, style: DiagnosticsTreeStyle.errorProperty);
  }
}

class TestClipPaintingContext extends PaintingContext {
  TestClipPaintingContext() : super(ContainerLayer(), Rect.zero);

  @override
  ClipRectLayer? pushClipRect(
    bool needsCompositing,
    Offset offset,
    Rect clipRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.hardEdge,
    ClipRectLayer? oldLayer,
  }) {
    this.clipBehavior = clipBehavior;
    return null;
  }

  Clip clipBehavior = Clip.none;
}

class TestPushLayerPaintingContext extends PaintingContext {
  TestPushLayerPaintingContext() : super(ContainerLayer(), Rect.zero);

  final List<ContainerLayer> pushedLayers = <ContainerLayer>[];

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds
  }) {
    pushedLayers.add(childLayer);
    super.pushLayer(childLayer, painter, offset, childPaintBounds: childPaintBounds);
  }
}

// Absorbs errors that don't have "overflowed" in their error details.
void absorbOverflowedErrors() {
  final Iterable<FlutterErrorDetails> errorDetails = TestRenderingFlutterBinding.instance.takeAllFlutterErrorDetails();
  final Iterable<FlutterErrorDetails> filtered = errorDetails.where((FlutterErrorDetails details) {
    return !details.toString().contains('overflowed');
  });
  if (filtered.isNotEmpty) {
    filtered.forEach(FlutterError.reportError);
  }
}

// Reports any FlutterErrors.
void expectNoFlutterErrors() {
  final Iterable<FlutterErrorDetails> errorDetails = TestRenderingFlutterBinding.instance.takeAllFlutterErrorDetails();
  errorDetails.forEach(FlutterError.reportError);
}

RenderConstrainedBox get box200x200 =>
    RenderConstrainedBox(additionalConstraints: const BoxConstraints.tightFor(height: 200.0, width: 200.0));