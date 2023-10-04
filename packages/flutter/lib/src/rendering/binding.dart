import 'dart:ui' as ui show SemanticsUpdate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'debug.dart';
import 'mouse_tracker.dart';
import 'object.dart';
import 'service_extensions.dart';
import 'view.dart';

export 'package:flutter/gestures.dart' show HitTestResult;

// Examples can assume:
// late BuildContext context;

mixin RendererBinding
    on
        BindingBase,
        ServicesBinding,
        SchedulerBinding,
        GestureBinding,
        SemanticsBinding,
        HitTestable {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _rootPipelineOwner = createRootPipelineOwner();
    platformDispatcher
      ..onMetricsChanged = handleMetricsChanged
      ..onTextScaleFactorChanged = handleTextScaleFactorChanged
      ..onPlatformBrightnessChanged = handlePlatformBrightnessChanged;
    addPersistentFrameCallback(_handlePersistentFrameCallback);
    initMouseTracker();
    if (kIsWeb) {
      addPostFrameCallback(_handleWebFirstFrame);
    }
    rootPipelineOwner.attach(_manifold);
  }

  static RendererBinding get instance => BindingBase.checkInstance(_instance);
  static RendererBinding? _instance;

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    assert(() {
      // these service extensions only work in debug mode
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.invertOversizedImages.name,
        getter: () async => debugInvertOversizedImages,
        setter: (bool value) async {
          if (debugInvertOversizedImages != value) {
            debugInvertOversizedImages = value;
            return _forceRepaint();
          }
          return Future<void>.value();
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.debugPaint.name,
        getter: () async => debugPaintSizeEnabled,
        setter: (bool value) {
          if (debugPaintSizeEnabled == value) {
            return Future<void>.value();
          }
          debugPaintSizeEnabled = value;
          return _forceRepaint();
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.debugPaintBaselinesEnabled.name,
        getter: () async => debugPaintBaselinesEnabled,
        setter: (bool value) {
          if (debugPaintBaselinesEnabled == value) {
            return Future<void>.value();
          }
          debugPaintBaselinesEnabled = value;
          return _forceRepaint();
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.repaintRainbow.name,
        getter: () async => debugRepaintRainbowEnabled,
        setter: (bool value) {
          final bool repaint = debugRepaintRainbowEnabled && !value;
          debugRepaintRainbowEnabled = value;
          if (repaint) {
            return _forceRepaint();
          }
          return Future<void>.value();
        },
      );
      registerServiceExtension(
        name: RenderingServiceExtensions.debugDumpLayerTree.name,
        callback: (Map<String, String> parameters) async {
          return <String, Object>{
            'data': _debugCollectLayerTrees(),
          };
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.debugDisableClipLayers.name,
        getter: () async => debugDisableClipLayers,
        setter: (bool value) {
          if (debugDisableClipLayers == value) {
            return Future<void>.value();
          }
          debugDisableClipLayers = value;
          return _forceRepaint();
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.debugDisablePhysicalShapeLayers.name,
        getter: () async => debugDisablePhysicalShapeLayers,
        setter: (bool value) {
          if (debugDisablePhysicalShapeLayers == value) {
            return Future<void>.value();
          }
          debugDisablePhysicalShapeLayers = value;
          return _forceRepaint();
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.debugDisableOpacityLayers.name,
        getter: () async => debugDisableOpacityLayers,
        setter: (bool value) {
          if (debugDisableOpacityLayers == value) {
            return Future<void>.value();
          }
          debugDisableOpacityLayers = value;
          return _forceRepaint();
        },
      );
      return true;
    }());

    if (!kReleaseMode) {
      // these service extensions work in debug or profile mode
      registerServiceExtension(
        name: RenderingServiceExtensions.debugDumpRenderTree.name,
        callback: (Map<String, String> parameters) async {
          return <String, Object>{
            'data': _debugCollectRenderTrees(),
          };
        },
      );
      registerServiceExtension(
        name: RenderingServiceExtensions
            .debugDumpSemanticsTreeInTraversalOrder.name,
        callback: (Map<String, String> parameters) async {
          return <String, Object>{
            'data': _debugCollectSemanticsTrees(
                DebugSemanticsDumpOrder.traversalOrder),
          };
        },
      );
      registerServiceExtension(
        name: RenderingServiceExtensions
            .debugDumpSemanticsTreeInInverseHitTestOrder.name,
        callback: (Map<String, String> parameters) async {
          return <String, Object>{
            'data': _debugCollectSemanticsTrees(
                DebugSemanticsDumpOrder.inverseHitTest),
          };
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.profileRenderObjectPaints.name,
        getter: () async => debugProfilePaintsEnabled,
        setter: (bool value) async {
          if (debugProfilePaintsEnabled != value) {
            debugProfilePaintsEnabled = value;
          }
        },
      );
      registerBoolServiceExtension(
        name: RenderingServiceExtensions.profileRenderObjectLayouts.name,
        getter: () async => debugProfileLayoutsEnabled,
        setter: (bool value) async {
          if (debugProfileLayoutsEnabled != value) {
            debugProfileLayoutsEnabled = value;
          }
        },
      );
    }
  }

  late final PipelineManifold _manifold = _BindingPipelineManifold(this);

  MouseTracker get mouseTracker => _mouseTracker!;
  MouseTracker? _mouseTracker;

  @Deprecated(
      'Interact with the pipelineOwner tree rooted at RendererBinding.rootPipelineOwner instead. '
      'Or instead of accessing the SemanticsOwner of any PipelineOwner interact with the SemanticsBinding directly. '
      'This feature was deprecated after v3.10.0-12.0.pre.')
  late final PipelineOwner pipelineOwner =
      PipelineOwner(onSemanticsOwnerCreated: () {
    (pipelineOwner.rootNode as RenderView?)?.scheduleInitialSemantics();
  }, onSemanticsUpdate: (ui.SemanticsUpdate update) {
    (pipelineOwner.rootNode as RenderView?)?.updateSemantics(update);
  }, onSemanticsOwnerDisposed: () {
    (pipelineOwner.rootNode as RenderView?)?.clearSemantics();
  });

  @Deprecated(
      'Consider using RendererBinding.renderViews instead as the binding may manage multiple RenderViews. '
      'This feature was deprecated after v3.10.0-12.0.pre.')
  // TODO(goderbauer): When this deprecated property is removed also delete the _ReusableRenderView class.
  late final RenderView renderView = _ReusableRenderView(
    view: platformDispatcher.implicitView!,
  );

  PipelineOwner createRootPipelineOwner() {
    return _DefaultRootPipelineOwner();
  }

  PipelineOwner get rootPipelineOwner => _rootPipelineOwner;
  late PipelineOwner _rootPipelineOwner;

  Iterable<RenderView> get renderViews => _viewIdToRenderView.values;
  final Map<Object, RenderView> _viewIdToRenderView = <Object, RenderView>{};

  void addRenderView(RenderView view) {
    final Object viewId = view.flutterView.viewId;
    assert(!_viewIdToRenderView.containsValue(view));
    assert(!_viewIdToRenderView.containsKey(viewId));
    _viewIdToRenderView[viewId] = view;
    view.configuration = createViewConfigurationFor(view);
  }

  void removeRenderView(RenderView view) {
    final Object viewId = view.flutterView.viewId;
    assert(_viewIdToRenderView[viewId] == view);
    _viewIdToRenderView.remove(viewId);
  }

  @protected
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    final FlutterView view = renderView.flutterView;
    final double devicePixelRatio = view.devicePixelRatio;
    return ViewConfiguration(
      size: view.physicalSize / devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @protected
  @visibleForTesting
  void handleMetricsChanged() {
    bool forceFrame = false;
    for (final RenderView view in renderViews) {
      forceFrame = forceFrame || view.child != null;
      view.configuration = createViewConfigurationFor(view);
    }
    if (forceFrame) {
      scheduleForcedFrame();
    }
  }

  @protected
  void handleTextScaleFactorChanged() {}

  @protected
  void handlePlatformBrightnessChanged() {}

  @visibleForTesting
  void initMouseTracker([MouseTracker? tracker]) {
    _mouseTracker?.dispose();
    _mouseTracker = tracker ??
        MouseTracker((Offset position, int viewId) {
          final HitTestResult result = HitTestResult();
          hitTestInView(result, position, viewId);
          return result;
        });
  }

  @override // from GestureBinding
  void dispatchEvent(PointerEvent event, HitTestResult? hitTestResult) {
    _mouseTracker!.updateWithEvent(
      event,
      // When the button is pressed, normal hit test uses a cached
      // result, but MouseTracker requires that the hit test is re-executed to
      // update the hovering events.
      event is PointerMoveEvent ? null : hitTestResult,
    );
    super.dispatchEvent(event, hitTestResult);
  }

  @override
  void performSemanticsAction(SemanticsActionEvent action) {
    // Due to the asynchronicity in some screen readers (they may not have
    // processed the latest semantics update yet) this code is more forgiving
    // and actions for views/nodes that no longer exist are gracefully ignored.
    _viewIdToRenderView[action.viewId]
        ?.owner
        ?.semanticsOwner
        ?.performAction(action.nodeId, action.type, action.arguments);
  }

  void _handleWebFirstFrame(Duration _) {
    assert(kIsWeb);
    const MethodChannel methodChannel = MethodChannel('flutter/service_worker');
    methodChannel.invokeMethod<void>('first-frame');
  }

  void _handlePersistentFrameCallback(Duration timeStamp) {
    drawFrame();
    _scheduleMouseTrackerUpdate();
  }

  bool _debugMouseTrackerUpdateScheduled = false;
  void _scheduleMouseTrackerUpdate() {
    assert(!_debugMouseTrackerUpdateScheduled);
    assert(() {
      _debugMouseTrackerUpdateScheduled = true;
      return true;
    }());
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      assert(_debugMouseTrackerUpdateScheduled);
      assert(() {
        _debugMouseTrackerUpdateScheduled = false;
        return true;
      }());
      _mouseTracker!.updateAllDevices();
    });
  }

  int _firstFrameDeferredCount = 0;
  bool _firstFrameSent = false;

  bool get sendFramesToEngine =>
      _firstFrameSent || _firstFrameDeferredCount == 0;

  void deferFirstFrame() {
    assert(_firstFrameDeferredCount >= 0);
    _firstFrameDeferredCount += 1;
  }

  void allowFirstFrame() {
    assert(_firstFrameDeferredCount > 0);
    _firstFrameDeferredCount -= 1;
    // Always schedule a warm up frame even if the deferral count is not down to
    // zero yet since the removal of a deferral may uncover new deferrals that
    // are lower in the widget tree.
    if (!_firstFrameSent) {
      scheduleWarmUpFrame();
    }
  }

  void resetFirstFrameSent() {
    _firstFrameSent = false;
  }

  //
  // When editing the above, also update widgets/binding.dart's copy.
  @protected
  void drawFrame() {
    rootPipelineOwner.flushLayout();
    rootPipelineOwner.flushCompositingBits();
    rootPipelineOwner.flushPaint();
    if (sendFramesToEngine) {
      for (final RenderView renderView in renderViews) {
        renderView.compositeFrame(); // this sends the bits to the GPU
      }
      rootPipelineOwner.flushSemantics(); // this sends the semantics to the OS.
      _firstFrameSent = true;
    }
  }

  @override
  Future<void> performReassemble() async {
    await super.performReassemble();
    if (!kReleaseMode) {
      FlutterTimeline.startSync('Preparing Hot Reload (layout)');
    }
    try {
      for (final RenderView renderView in renderViews) {
        renderView.reassemble();
      }
    } finally {
      if (!kReleaseMode) {
        FlutterTimeline.finishSync();
      }
    }
    scheduleWarmUpFrame();
    await endOfFrame;
  }

  @override
  void hitTestInView(HitTestResult result, Offset position, int viewId) {
    _viewIdToRenderView[viewId]?.hitTest(result, position: position);
    super.hitTestInView(result, position, viewId);
  }

  Future<void> _forceRepaint() {
    late RenderObjectVisitor visitor;
    visitor = (RenderObject child) {
      child.markNeedsPaint();
      child.visitChildren(visitor);
    };
    for (final RenderView renderView in renderViews) {
      renderView.visitChildren(visitor);
    }
    return endOfFrame;
  }
}

String _debugCollectRenderTrees() {
  if (RendererBinding.instance.renderViews.isEmpty) {
    return 'No render tree root was added to the binding.';
  }
  return <String>[
    for (final RenderView renderView in RendererBinding.instance.renderViews)
      renderView.toStringDeep(),
  ].join('\n\n');
}

void debugDumpRenderTree() {
  debugPrint(_debugCollectRenderTrees());
}

String _debugCollectLayerTrees() {
  if (RendererBinding.instance.renderViews.isEmpty) {
    return 'No render tree root was added to the binding.';
  }
  return <String>[
    for (final RenderView renderView in RendererBinding.instance.renderViews)
      renderView.debugLayer?.toStringDeep() ??
          'Layer tree unavailable for $renderView.',
  ].join('\n\n');
}

void debugDumpLayerTree() {
  debugPrint(_debugCollectLayerTrees());
}

String _debugCollectSemanticsTrees(DebugSemanticsDumpOrder childOrder) {
  if (RendererBinding.instance.renderViews.isEmpty) {
    return 'No render tree root was added to the binding.';
  }
  const String explanation =
      'For performance reasons, the framework only generates semantics when asked to do so by the platform.\n'
      'Usually, platforms only ask for semantics when assistive technologies (like screen readers) are running.\n'
      'To generate semantics, try turning on an assistive technology (like VoiceOver or TalkBack) on your device.';
  final List<String> trees = <String>[];
  bool printedExplanation = false;
  for (final RenderView renderView in RendererBinding.instance.renderViews) {
    final String? tree =
        renderView.debugSemantics?.toStringDeep(childOrder: childOrder);
    if (tree != null) {
      trees.add(tree);
    } else {
      String message = 'Semantics not generated for $renderView.';
      if (!printedExplanation) {
        printedExplanation = true;
        message = '$message\n$explanation';
      }
      trees.add(message);
    }
  }
  return trees.join('\n\n');
}

void debugDumpSemanticsTree(
    [DebugSemanticsDumpOrder childOrder =
        DebugSemanticsDumpOrder.traversalOrder]) {
  debugPrint(_debugCollectSemanticsTrees(childOrder));
}

void debugDumpPipelineOwnerTree() {
  debugPrint(RendererBinding.instance.rootPipelineOwner.toStringDeep());
}

class RenderingFlutterBinding extends BindingBase
    with
        GestureBinding,
        SchedulerBinding,
        ServicesBinding,
        SemanticsBinding,
        PaintingBinding,
        RendererBinding {
  static RendererBinding ensureInitialized() {
    if (RendererBinding._instance == null) {
      RenderingFlutterBinding();
    }
    return RendererBinding.instance;
  }
}

class _BindingPipelineManifold extends ChangeNotifier
    implements PipelineManifold {
  _BindingPipelineManifold(this._binding) {
    _binding.addSemanticsEnabledListener(notifyListeners);
  }

  final RendererBinding _binding;

  @override
  void requestVisualUpdate() {
    _binding.ensureVisualUpdate();
  }

  @override
  bool get semanticsEnabled => _binding.semanticsEnabled;

  @override
  void dispose() {
    _binding.removeSemanticsEnabledListener(notifyListeners);
    super.dispose();
  }
}

// A [PipelineOwner] that cannot have a root node.
class _DefaultRootPipelineOwner extends PipelineOwner {
  _DefaultRootPipelineOwner() : super(onSemanticsUpdate: _onSemanticsUpdate);

  @override
  set rootNode(RenderObject? _) {
    assert(() {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'Cannot set a rootNode on the default root pipeline owner.',
        ),
        ErrorDescription(
          'By default, the RendererBinding.rootPipelineOwner is not configured '
          'to manage a root node because this pipeline owner does not define a '
          'proper onSemanticsUpdate callback to handle semantics for that node.',
        ),
        ErrorHint(
            'Typically, the root pipeline owner does not manage a root node. '
            'Instead, properly configured child pipeline owners (which do manage '
            'root nodes) are added to it. Alternatively, if you do want to set a '
            'root node for the root pipeline owner, override '
            'RendererBinding.createRootPipelineOwner to create a '
            'pipeline owner that is configured to properly handle semantics for '
            'the provided root node.'),
      ]);
    }());
  }

  static void _onSemanticsUpdate(ui.SemanticsUpdate _) {
    // Neve called because we don't have a root node.
    assert(false);
  }
}

// Prior to multi view support, the [RendererBinding] would own a long-lived
// [RenderView], that was never disposed (see [RendererBinding.renderView]).
// With multi view support, the [RendererBinding] no longer owns a [RenderView]
// and instead higher level abstractions (like the [View] widget) can add/remove
// multiple [RenderView]s to the binding as needed. When the [View] widget is no
// longer needed, it expects to dispose its [RenderView].
//
// This special version of a [RenderView] now exists as a bridge between those
// worlds to continue supporting the [RendererBinding.renderView] property
// through its deprecation period. Per the property's contract, it is supposed
// to be long-lived, but it is also managed by a [View] widget (introduced by
// [WidgetsBinding.wrapWithDefaultView]), that expects to dispose its render
// object at the end of the widget's life time. This special version now
// implements logic to reset the [RenderView] when it is "disposed" so it can be
// reused by another [View] widget.
//
// Once the deprecated [RendererBinding.renderView] property is removed, this
// class is no longer necessary.
class _ReusableRenderView extends RenderView {
  _ReusableRenderView({required super.view});

  bool _initialFramePrepared = false;

  @override
  void prepareInitialFrame() {
    if (_initialFramePrepared) {
      return;
    }
    super.prepareInitialFrame();
    _initialFramePrepared = true;
  }

  @override
  void scheduleInitialSemantics() {
    clearSemantics();
    super.scheduleInitialSemantics();
  }

  @override
  void dispose() {
    // ignore: must_call_super
    child = null;
  }
}
