import 'dart:ui' as ui show PictureRecorder;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import 'debug.dart';
import 'layer.dart';

export 'package:flutter/foundation.dart' show
  DiagnosticPropertiesBuilder,
  DiagnosticsNode,
  DiagnosticsProperty,
  DoubleProperty,
  EnumProperty,
  ErrorDescription,
  ErrorHint,
  ErrorSummary,
  FlagProperty,
  FlutterError,
  InformationCollector,
  IntProperty,
  StringProperty;
export 'package:flutter/gestures.dart' show HitTestEntry, HitTestResult;
export 'package:flutter/painting.dart';

class ParentData {
  @protected
  @mustCallSuper
  void detach() { }

  @override
  String toString() => '<none>';
}

typedef PaintingContextCallback = void Function(PaintingContext context, Offset offset);

class PaintingContext extends ClipContext {

  @protected
  PaintingContext(this._containerLayer, this.estimatedBounds);

  final ContainerLayer _containerLayer;

  final Rect estimatedBounds;

  static void repaintCompositedChild(RenderObject child, { bool debugAlsoPaintedParent = false }) {
    assert(child._needsPaint);
    _repaintCompositedChild(
      child,
      debugAlsoPaintedParent: debugAlsoPaintedParent,
    );
  }

  static void _repaintCompositedChild(
    RenderObject child, {
    bool debugAlsoPaintedParent = false,
    PaintingContext? childContext,
  }) {
    assert(child.isRepaintBoundary);
    assert(() {
      // register the call for RepaintBoundary metrics
      child.debugRegisterRepaintBoundaryPaint(
        includedParent: debugAlsoPaintedParent,
        includedChild: true,
      );
      return true;
    }());
    OffsetLayer? childLayer = child._layerHandle.layer as OffsetLayer?;
    if (childLayer == null) {
      assert(debugAlsoPaintedParent);
      assert(child._layerHandle.layer == null);

      // Not using the `layer` setter because the setter asserts that we not
      // replace the layer for repaint boundaries. That assertion does not
      // apply here because this is exactly the place designed to create a
      // layer for repaint boundaries.
      final OffsetLayer layer = child.updateCompositedLayer(oldLayer: null);
      child._layerHandle.layer = childLayer = layer;
    } else {
      assert(debugAlsoPaintedParent || childLayer.attached);
      Offset? debugOldOffset;
      assert(() {
        debugOldOffset = childLayer!.offset;
        return true;
      }());
      childLayer.removeAllChildren();
      final OffsetLayer updatedLayer = child.updateCompositedLayer(oldLayer: childLayer);
      assert(identical(updatedLayer, childLayer),
        '$child created a new layer instance $updatedLayer instead of reusing the '
        'existing layer $childLayer. See the documentation of RenderObject.updateCompositedLayer '
        'for more information on how to correctly implement this method.'
      );
      assert(debugOldOffset == updatedLayer.offset);
    }
    child._needsCompositedLayerUpdate = false;

    assert(identical(childLayer, child._layerHandle.layer));
    assert(child._layerHandle.layer is OffsetLayer);
    assert(() {
      childLayer!.debugCreator = child.debugCreator ?? child.runtimeType;
      return true;
    }());

    childContext ??= PaintingContext(childLayer, child.paintBounds);
    child._paintWithContext(childContext, Offset.zero);

    // Double-check that the paint method did not replace the layer (the first
    // check is done in the [layer] setter itself).
    assert(identical(childLayer, child._layerHandle.layer));
    childContext.stopRecordingIfNeeded();
  }

  static void updateLayerProperties(RenderObject child) {
    assert(child.isRepaintBoundary && child._wasRepaintBoundary);
    assert(!child._needsPaint);
    assert(child._layerHandle.layer != null);

    final OffsetLayer childLayer = child._layerHandle.layer! as OffsetLayer;
    Offset? debugOldOffset;
    assert(() {
      debugOldOffset = childLayer.offset;
      return true;
    }());
    final OffsetLayer updatedLayer = child.updateCompositedLayer(oldLayer: childLayer);
    assert(identical(updatedLayer, childLayer),
      '$child created a new layer instance $updatedLayer instead of reusing the '
      'existing layer $childLayer. See the documentation of RenderObject.updateCompositedLayer '
      'for more information on how to correctly implement this method.'
    );
    assert(debugOldOffset == updatedLayer.offset);
    child._needsCompositedLayerUpdate = false;
  }

  static void debugInstrumentRepaintCompositedChild(
    RenderObject child, {
    bool debugAlsoPaintedParent = false,
    required PaintingContext customContext,
  }) {
    assert(() {
      _repaintCompositedChild(
        child,
        debugAlsoPaintedParent: debugAlsoPaintedParent,
        childContext: customContext,
      );
      return true;
    }());
  }

  void paintChild(RenderObject child, Offset offset) {
    assert(() {
      debugOnProfilePaint?.call(child);
      return true;
    }());

    if (child.isRepaintBoundary) {
      stopRecordingIfNeeded();
      _compositeChild(child, offset);
    // If a render object was a repaint boundary but no longer is one, this
    // is where the framework managed layer is automatically disposed.
    } else if (child._wasRepaintBoundary) {
      assert(child._layerHandle.layer is OffsetLayer);
      child._layerHandle.layer = null;
      child._paintWithContext(this, offset);
    } else {
      child._paintWithContext(this, offset);
    }
  }

  void _compositeChild(RenderObject child, Offset offset) {
    assert(!_isRecording);
    assert(child.isRepaintBoundary);
    assert(_canvas == null || _canvas!.getSaveCount() == 1);

    // Create a layer for our child, and paint the child into it.
    if (child._needsPaint || !child._wasRepaintBoundary) {
      repaintCompositedChild(child, debugAlsoPaintedParent: true);
    } else {
      if (child._needsCompositedLayerUpdate) {
        updateLayerProperties(child);
      }
      assert(() {
        // register the call for RepaintBoundary metrics
        child.debugRegisterRepaintBoundaryPaint();
        child._layerHandle.layer!.debugCreator = child.debugCreator ?? child;
        return true;
      }());
    }
    assert(child._layerHandle.layer is OffsetLayer);
    final OffsetLayer childOffsetLayer = child._layerHandle.layer! as OffsetLayer;
    childOffsetLayer.offset = offset;
    appendLayer(childOffsetLayer);
  }

  @protected
  void appendLayer(Layer layer) {
    assert(!_isRecording);
    layer.remove();
    _containerLayer.append(layer);
  }

  bool get _isRecording {
    final bool hasCanvas = _canvas != null;
    assert(() {
      if (hasCanvas) {
        assert(_currentLayer != null);
        assert(_recorder != null);
        assert(_canvas != null);
      } else {
        assert(_currentLayer == null);
        assert(_recorder == null);
        assert(_canvas == null);
      }
      return true;
    }());
    return hasCanvas;
  }

  // Recording state
  PictureLayer? _currentLayer;
  ui.PictureRecorder? _recorder;
  Canvas? _canvas;

  @override
  Canvas get canvas {
    if (_canvas == null) {
      _startRecording();
    }
    assert(_currentLayer != null);
    return _canvas!;
  }

  void _startRecording() {
    assert(!_isRecording);
    _currentLayer = PictureLayer(estimatedBounds);
    _recorder = ui.PictureRecorder();
    _canvas = Canvas(_recorder!);
    _containerLayer.append(_currentLayer!);
  }

  VoidCallback addCompositionCallback(CompositionCallback callback) {
    return _containerLayer.addCompositionCallback(callback);
  }

  @protected
  @mustCallSuper
  void stopRecordingIfNeeded() {
    if (!_isRecording) {
      return;
    }
    assert(() {
      if (debugRepaintRainbowEnabled) {
        final Paint paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..color = debugCurrentRepaintColor.toColor();
        canvas.drawRect(estimatedBounds.deflate(3.0), paint);
      }
      if (debugPaintLayerBordersEnabled) {
        final Paint paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFFF9800);
        canvas.drawRect(estimatedBounds, paint);
      }
      return true;
    }());
    _currentLayer!.picture = _recorder!.endRecording();
    _currentLayer = null;
    _recorder = null;
    _canvas = null;
  }

  void setIsComplexHint() {
    if (_currentLayer == null) {
      _startRecording();
    }
    _currentLayer!.isComplexHint = true;
  }

  void setWillChangeHint() {
    if (_currentLayer == null) {
      _startRecording();
    }
    _currentLayer!.willChangeHint = true;
  }

  void addLayer(Layer layer) {
    stopRecordingIfNeeded();
    appendLayer(layer);
  }

  void pushLayer(ContainerLayer childLayer, PaintingContextCallback painter, Offset offset, { Rect? childPaintBounds }) {
    // If a layer is being reused, it may already contain children. We remove
    // them so that `painter` can add children that are relevant for this frame.
    if (childLayer.hasChildren) {
      childLayer.removeAllChildren();
    }
    stopRecordingIfNeeded();
    appendLayer(childLayer);
    final PaintingContext childContext = createChildContext(childLayer, childPaintBounds ?? estimatedBounds);

    painter(childContext, offset);
    childContext.stopRecordingIfNeeded();
  }

  @protected
  PaintingContext createChildContext(ContainerLayer childLayer, Rect bounds) {
    return PaintingContext(childLayer, bounds);
  }

  ClipRectLayer? pushClipRect(bool needsCompositing, Offset offset, Rect clipRect, PaintingContextCallback painter, { Clip clipBehavior = Clip.hardEdge, ClipRectLayer? oldLayer }) {
    if (clipBehavior == Clip.none) {
      painter(this, offset);
      return null;
    }
    final Rect offsetClipRect = clipRect.shift(offset);
    if (needsCompositing) {
      final ClipRectLayer layer = oldLayer ?? ClipRectLayer();
      layer
        ..clipRect = offsetClipRect
        ..clipBehavior = clipBehavior;
      pushLayer(layer, painter, offset, childPaintBounds: offsetClipRect);
      return layer;
    } else {
      clipRectAndPaint(offsetClipRect, clipBehavior, offsetClipRect, () => painter(this, offset));
      return null;
    }
  }

  ClipRRectLayer? pushClipRRect(bool needsCompositing, Offset offset, Rect bounds, RRect clipRRect, PaintingContextCallback painter, { Clip clipBehavior = Clip.antiAlias, ClipRRectLayer? oldLayer }) {
    if (clipBehavior == Clip.none) {
      painter(this, offset);
      return null;
    }
    final Rect offsetBounds = bounds.shift(offset);
    final RRect offsetClipRRect = clipRRect.shift(offset);
    if (needsCompositing) {
      final ClipRRectLayer layer = oldLayer ?? ClipRRectLayer();
      layer
        ..clipRRect = offsetClipRRect
        ..clipBehavior = clipBehavior;
      pushLayer(layer, painter, offset, childPaintBounds: offsetBounds);
      return layer;
    } else {
      clipRRectAndPaint(offsetClipRRect, clipBehavior, offsetBounds, () => painter(this, offset));
      return null;
    }
  }

  ClipPathLayer? pushClipPath(bool needsCompositing, Offset offset, Rect bounds, Path clipPath, PaintingContextCallback painter, { Clip clipBehavior = Clip.antiAlias, ClipPathLayer? oldLayer }) {
    if (clipBehavior == Clip.none) {
      painter(this, offset);
      return null;
    }
    final Rect offsetBounds = bounds.shift(offset);
    final Path offsetClipPath = clipPath.shift(offset);
    if (needsCompositing) {
      final ClipPathLayer layer = oldLayer ?? ClipPathLayer();
      layer
        ..clipPath = offsetClipPath
        ..clipBehavior = clipBehavior;
      pushLayer(layer, painter, offset, childPaintBounds: offsetBounds);
      return layer;
    } else {
      clipPathAndPaint(offsetClipPath, clipBehavior, offsetBounds, () => painter(this, offset));
      return null;
    }
  }

  ColorFilterLayer pushColorFilter(Offset offset, ColorFilter colorFilter, PaintingContextCallback painter, { ColorFilterLayer? oldLayer }) {
    final ColorFilterLayer layer = oldLayer ?? ColorFilterLayer();
    layer.colorFilter = colorFilter;
    pushLayer(layer, painter, offset);
    return layer;
  }

  TransformLayer? pushTransform(bool needsCompositing, Offset offset, Matrix4 transform, PaintingContextCallback painter, { TransformLayer? oldLayer }) {
    final Matrix4 effectiveTransform = Matrix4.translationValues(offset.dx, offset.dy, 0.0)
      ..multiply(transform)..translate(-offset.dx, -offset.dy);
    if (needsCompositing) {
      final TransformLayer layer = oldLayer ?? TransformLayer();
      layer.transform = effectiveTransform;
      pushLayer(
        layer,
        painter,
        offset,
        childPaintBounds: MatrixUtils.inverseTransformRect(effectiveTransform, estimatedBounds),
      );
      return layer;
    } else {
      canvas
        ..save()
        ..transform(effectiveTransform.storage);
      painter(this, offset);
      canvas.restore();
      return null;
    }
  }

  OpacityLayer pushOpacity(Offset offset, int alpha, PaintingContextCallback painter, { OpacityLayer? oldLayer }) {
    final OpacityLayer layer = oldLayer ?? OpacityLayer();
    layer
      ..alpha = alpha
      ..offset = offset;
    pushLayer(layer, painter, Offset.zero);
    return layer;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'PaintingContext')}#$hashCode(layer: $_containerLayer, canvas bounds: $estimatedBounds)';
}

@immutable
abstract class Constraints {
  const Constraints();

  bool get isTight;

  bool get isNormalized;

  bool debugAssertIsValid({
    bool isAppliedConstraint = false,
    InformationCollector? informationCollector,
  }) {
    assert(isNormalized);
    return isNormalized;
  }
}

typedef RenderObjectVisitor = void Function(RenderObject child);

typedef LayoutCallback<T extends Constraints> = void Function(T constraints);

class _LocalSemanticsHandle implements SemanticsHandle {
  _LocalSemanticsHandle._(PipelineOwner owner, this.listener)
      : _owner = owner {
    if (listener != null) {
      _owner.semanticsOwner!.addListener(listener!);
    }
  }

  final PipelineOwner _owner;

  final VoidCallback? listener;

  @override
  void dispose() {
    if (listener != null) {
      _owner.semanticsOwner!.removeListener(listener!);
    }
    _owner._didDisposeSemanticsHandle();
  }
}

class PipelineOwner with DiagnosticableTreeMixin {
  PipelineOwner({
    this.onNeedVisualUpdate,
    this.onSemanticsOwnerCreated,
    this.onSemanticsUpdate,
    this.onSemanticsOwnerDisposed,
  });

  final VoidCallback? onNeedVisualUpdate;

  final VoidCallback? onSemanticsOwnerCreated;

  final SemanticsUpdateCallback? onSemanticsUpdate;

  final VoidCallback? onSemanticsOwnerDisposed;

  void requestVisualUpdate() {
    if (onNeedVisualUpdate != null) {
      onNeedVisualUpdate!();
    } else {
      _manifold?.requestVisualUpdate();
    }
  }

  RenderObject? get rootNode => _rootNode;
  RenderObject? _rootNode;
  set rootNode(RenderObject? value) {
    if (_rootNode == value) {
      return;
    }
    _rootNode?.detach();
    _rootNode = value;
    _rootNode?.attach(this);
  }

  // Whether the current [flushLayout] call should pause to incorporate the
  // [RenderObject]s in `_nodesNeedingLayout` into the current dirty list,
  // before continuing to process dirty relayout boundaries.
  //
  // This flag is set to true when a [RenderObject.invokeLayoutCallback]
  // returns, to avoid laying out dirty relayout boundaries in an incorrect
  // order and causing them to be laid out more than once per frame. See
  // layout_builder_mutations_test.dart for an example.
  //
  // The new dirty nodes are not immediately merged after a
  // [RenderObject.invokeLayoutCallback] call because we may encounter multiple
  // such calls while processing a single relayout boundary in [flushLayout].
  // Batching new dirty nodes can reduce the number of merges [flushLayout]
  // has to perform.
  bool _shouldMergeDirtyNodes = false;
  List<RenderObject> _nodesNeedingLayout = <RenderObject>[];

  bool get debugDoingLayout => _debugDoingLayout;
  bool _debugDoingLayout = false;
  bool _debugDoingChildLayout = false;

  void flushLayout() {
    if (!kReleaseMode) {
      Map<String, String>? debugTimelineArguments;
      assert(() {
        if (debugEnhanceLayoutTimelineArguments) {
          debugTimelineArguments = <String, String>{
            'dirty count': '${_nodesNeedingLayout.length}',
            'dirty list': '$_nodesNeedingLayout',
          };
        }
        return true;
      }());
      FlutterTimeline.startSync(
        'LAYOUT$_debugRootSuffixForTimelineEventNames',
        arguments: debugTimelineArguments,
      );
    }
    assert(() {
      _debugDoingLayout = true;
      return true;
    }());
    try {
      while (_nodesNeedingLayout.isNotEmpty) {
        assert(!_shouldMergeDirtyNodes);
        final List<RenderObject> dirtyNodes = _nodesNeedingLayout;
        _nodesNeedingLayout = <RenderObject>[];
        dirtyNodes.sort((RenderObject a, RenderObject b) => a.depth - b.depth);
        for (int i = 0; i < dirtyNodes.length; i++) {
          if (_shouldMergeDirtyNodes) {
            _shouldMergeDirtyNodes = false;
            if (_nodesNeedingLayout.isNotEmpty) {
              _nodesNeedingLayout.addAll(dirtyNodes.getRange(i, dirtyNodes.length));
              break;
            }
          }
          final RenderObject node = dirtyNodes[i];
          if (node._needsLayout && node.owner == this) {
            node._layoutWithoutResize();
          }
        }
        // No need to merge dirty nodes generated from processing the last
        // relayout boundary back.
        _shouldMergeDirtyNodes = false;
      }

      assert(() {
        _debugDoingChildLayout = true;
        return true;
      }());
      for (final PipelineOwner child in _children) {
        child.flushLayout();
      }
      assert(_nodesNeedingLayout.isEmpty, 'Child PipelineOwners must not dirty nodes in their parent.');
    } finally {
      _shouldMergeDirtyNodes = false;
      assert(() {
        _debugDoingLayout = false;
        _debugDoingChildLayout = false;
        return true;
      }());
      if (!kReleaseMode) {
        FlutterTimeline.finishSync();
      }
    }
  }

  // This flag is used to allow the kinds of mutations performed by GlobalKey
  // reparenting while a LayoutBuilder is being rebuilt and in so doing tries to
  // move a node from another LayoutBuilder subtree that hasn't been updated
  // yet. To set this, call [_enableMutationsToDirtySubtrees], which is called
  // by [RenderObject.invokeLayoutCallback].
  bool _debugAllowMutationsToDirtySubtrees = false;

  // See [RenderObject.invokeLayoutCallback].
  void _enableMutationsToDirtySubtrees(VoidCallback callback) {
    assert(_debugDoingLayout);
    bool? oldState;
    assert(() {
      oldState = _debugAllowMutationsToDirtySubtrees;
      _debugAllowMutationsToDirtySubtrees = true;
      return true;
    }());
    try {
      callback();
    } finally {
      _shouldMergeDirtyNodes = true;
      assert(() {
        _debugAllowMutationsToDirtySubtrees = oldState!;
        return true;
      }());
    }
  }

  final List<RenderObject> _nodesNeedingCompositingBitsUpdate = <RenderObject>[];
  void flushCompositingBits() {
    if (!kReleaseMode) {
      FlutterTimeline.startSync('UPDATING COMPOSITING BITS$_debugRootSuffixForTimelineEventNames');
    }
    _nodesNeedingCompositingBitsUpdate.sort((RenderObject a, RenderObject b) => a.depth - b.depth);
    for (final RenderObject node in _nodesNeedingCompositingBitsUpdate) {
      if (node._needsCompositingBitsUpdate && node.owner == this) {
        node._updateCompositingBits();
      }
    }
    _nodesNeedingCompositingBitsUpdate.clear();
    for (final PipelineOwner child in _children) {
      child.flushCompositingBits();
    }
    assert(_nodesNeedingCompositingBitsUpdate.isEmpty, 'Child PipelineOwners must not dirty nodes in their parent.');
    if (!kReleaseMode) {
      FlutterTimeline.finishSync();
    }
  }

  List<RenderObject> _nodesNeedingPaint = <RenderObject>[];

  bool get debugDoingPaint => _debugDoingPaint;
  bool _debugDoingPaint = false;

  void flushPaint() {
    if (!kReleaseMode) {
      Map<String, String>? debugTimelineArguments;
      assert(() {
        if (debugEnhancePaintTimelineArguments) {
          debugTimelineArguments = <String, String>{
            'dirty count': '${_nodesNeedingPaint.length}',
            'dirty list': '$_nodesNeedingPaint',
          };
        }
        return true;
      }());
      FlutterTimeline.startSync(
        'PAINT$_debugRootSuffixForTimelineEventNames',
        arguments: debugTimelineArguments,
      );
    }
    try {
      assert(() {
        _debugDoingPaint = true;
        return true;
      }());
      final List<RenderObject> dirtyNodes = _nodesNeedingPaint;
      _nodesNeedingPaint = <RenderObject>[];

      // Sort the dirty nodes in reverse order (deepest first).
      for (final RenderObject node in dirtyNodes..sort((RenderObject a, RenderObject b) => b.depth - a.depth)) {
        assert(node._layerHandle.layer != null);
        if ((node._needsPaint || node._needsCompositedLayerUpdate) && node.owner == this) {
          if (node._layerHandle.layer!.attached) {
            assert(node.isRepaintBoundary);
            if (node._needsPaint) {
              PaintingContext.repaintCompositedChild(node);
            } else {
              PaintingContext.updateLayerProperties(node);
            }
          } else {
            node._skippedPaintingOnLayer();
          }
        }
      }
      for (final PipelineOwner child in _children) {
        child.flushPaint();
      }
      assert(_nodesNeedingPaint.isEmpty, 'Child PipelineOwners must not dirty nodes in their parent.');
    } finally {
      assert(() {
        _debugDoingPaint = false;
        return true;
      }());
      if (!kReleaseMode) {
        FlutterTimeline.finishSync();
      }
    }
  }

  SemanticsOwner? get semanticsOwner => _semanticsOwner;
  SemanticsOwner? _semanticsOwner;

  int get debugOutstandingSemanticsHandles => _outstandingSemanticsHandles;
  int _outstandingSemanticsHandles = 0;

  SemanticsHandle ensureSemantics({ VoidCallback? listener }) {
    _outstandingSemanticsHandles += 1;
    _updateSemanticsOwner();
    return _LocalSemanticsHandle._(this, listener);
  }

  void _updateSemanticsOwner() {
    if ((_manifold?.semanticsEnabled ?? false) || _outstandingSemanticsHandles > 0) {
      if (_semanticsOwner == null) {
        assert(onSemanticsUpdate != null, 'Attempted to enable semantics without configuring an onSemanticsUpdate callback.');
        _semanticsOwner = SemanticsOwner(onSemanticsUpdate: onSemanticsUpdate!);
        onSemanticsOwnerCreated?.call();
      }
    } else if (_semanticsOwner != null) {
      _semanticsOwner?.dispose();
      _semanticsOwner = null;
      onSemanticsOwnerDisposed?.call();
    }
  }

  void _didDisposeSemanticsHandle() {
    assert(_semanticsOwner != null);
    _outstandingSemanticsHandles -= 1;
    _updateSemanticsOwner();
  }

  bool _debugDoingSemantics = false;
  final Set<RenderObject> _nodesNeedingSemantics = <RenderObject>{};

  void flushSemantics() {
    if (_semanticsOwner == null) {
      return;
    }
    if (!kReleaseMode) {
      FlutterTimeline.startSync('SEMANTICS$_debugRootSuffixForTimelineEventNames');
    }
    assert(_semanticsOwner != null);
    assert(() {
      _debugDoingSemantics = true;
      return true;
    }());
    try {
      final List<RenderObject> nodesToProcess = _nodesNeedingSemantics.toList()
        ..sort((RenderObject a, RenderObject b) => a.depth - b.depth);
      _nodesNeedingSemantics.clear();
      for (final RenderObject node in nodesToProcess) {
        if (node._needsSemanticsUpdate && node.owner == this) {
          node._updateSemantics();
        }
      }
      _semanticsOwner!.sendSemanticsUpdate();
      for (final PipelineOwner child in _children) {
        child.flushSemantics();
      }
      assert(_nodesNeedingSemantics.isEmpty, 'Child PipelineOwners must not dirty nodes in their parent.');
    } finally {
      assert(() {
        _debugDoingSemantics = false;
        return true;
      }());
      if (!kReleaseMode) {
        FlutterTimeline.finishSync();
      }
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      for (final PipelineOwner child in _children)
        child.toDiagnosticsNode(),
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RenderObject>('rootNode', rootNode, defaultValue: null));
  }

  // TREE MANAGEMENT

  final Set<PipelineOwner> _children = <PipelineOwner>{};
  PipelineManifold? _manifold;

  PipelineOwner? _debugParent;
  bool _debugSetParent(PipelineOwner child, PipelineOwner? parent) {
    child._debugParent = parent;
    return true;
  }

  String get _debugRootSuffixForTimelineEventNames => _debugParent == null ? ' (root)' : '';

  void attach(PipelineManifold manifold) {
    assert(_manifold == null);
    _manifold = manifold;
    _manifold!.addListener(_updateSemanticsOwner);
    _updateSemanticsOwner();

    for (final PipelineOwner child in _children) {
      child.attach(manifold);
    }
  }

  void detach() {
    assert(_manifold != null);
    _manifold!.removeListener(_updateSemanticsOwner);
    _manifold = null;
    // Not updating the semantics owner here to not disrupt any of its clients
    // in case we get re-attached. If necessary, semantics owner will be updated
    // in "attach", or disposed in "dispose", if not reattached.

    for (final PipelineOwner child in _children) {
      child.detach();
    }
  }

  // In theory, child list modifications are also disallowed between
  // _debugDoingChildrenLayout and _debugDoingPaint as well as between
  // _debugDoingPaint and _debugDoingSemantics. However, since the associated
  // flush methods are usually called back to back, this gets us close enough.
  bool get _debugAllowChildListModifications => !_debugDoingChildLayout && !_debugDoingPaint && !_debugDoingSemantics;

  void adoptChild(PipelineOwner child) {
    assert(child._debugParent == null);
    assert(!_children.contains(child));
    assert(_debugAllowChildListModifications, 'Cannot modify child list after layout.');
    _children.add(child);
    if (!kReleaseMode) {
      _debugSetParent(child, this);
    }
    if (_manifold != null) {
      child.attach(_manifold!);
    }
  }

  void dropChild(PipelineOwner child) {
    assert(child._debugParent == this);
    assert(_children.contains(child));
    assert(_debugAllowChildListModifications, 'Cannot modify child list after layout.');
    _children.remove(child);
    if (!kReleaseMode) {
      _debugSetParent(child, null);
    }
    if (_manifold != null) {
      child.detach();
    }
  }

  void visitChildren(PipelineOwnerVisitor visitor) {
    _children.forEach(visitor);
  }

  void dispose() {
    assert(_children.isEmpty);
    assert(rootNode == null);
    assert(_manifold == null);
    assert(_debugParent == null);
    _semanticsOwner?.dispose();
    _semanticsOwner = null;
    _nodesNeedingLayout.clear();
    _nodesNeedingCompositingBitsUpdate.clear();
    _nodesNeedingPaint.clear();
    _nodesNeedingSemantics.clear();
  }
}

typedef PipelineOwnerVisitor = void Function(PipelineOwner child);

abstract class PipelineManifold implements Listenable {
  bool get semanticsEnabled;

  void requestVisualUpdate();
}

const String _flutterRenderingLibrary = 'package:flutter/rendering.dart';

abstract class RenderObject with DiagnosticableTreeMixin implements HitTestTarget {
  RenderObject() {
    if (kFlutterMemoryAllocationsEnabled) {
      MemoryAllocations.instance.dispatchObjectCreated(
        library: _flutterRenderingLibrary,
        className: '$RenderObject',
        object: this,
      );
    }
    _needsCompositing = isRepaintBoundary || alwaysNeedsCompositing;
    _wasRepaintBoundary = isRepaintBoundary;
  }

  void reassemble() {
    markNeedsLayout();
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    visitChildren((RenderObject child) {
      child.reassemble();
    });
  }

  bool? get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _debugDisposed;
      return true;
    }());
    return disposed;
  }

  bool _debugDisposed = false;

  @mustCallSuper
  void dispose() {
    assert(!_debugDisposed);
    if (kFlutterMemoryAllocationsEnabled) {
      MemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }
    _layerHandle.layer = null;
    assert(() {
      // TODO(dnfield): Enable this assert once clients have had a chance to
      // migrate.
      // visitChildren((RenderObject child) {
      //   assert(
      //     child.debugDisposed!,
      //     '${child.runtimeType} (child of $runtimeType) must be disposed before calling super.dispose().',
      //   );
      // });
      _debugDisposed = true;
      return true;
    }());
  }

  // LAYOUT

  ParentData? parentData;

  void setupParentData(covariant RenderObject child) {
    assert(_debugCanPerformMutations);
    if (child.parentData is! ParentData) {
      child.parentData = ParentData();
    }
  }

  int get depth => _depth;
  int _depth = 0;

  @protected
  void redepthChild(RenderObject child) {
    assert(child.owner == owner);
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child.redepthChildren();
    }
  }

  @protected
  void redepthChildren() { }

  RenderObject? get parent => _parent;
  RenderObject? _parent;

  @mustCallSuper
  @protected
  void adoptChild(RenderObject child) {
    assert(child._parent == null);
    assert(() {
      RenderObject node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());

    setupParentData(child);
    markNeedsLayout();
    markNeedsCompositingBitsUpdate();
    markNeedsSemanticsUpdate();
    child._parent = this;
    if (attached) {
      child.attach(_owner!);
    }
    redepthChild(child);
  }

  @mustCallSuper
  @protected
  void dropChild(RenderObject child) {
    assert(child._parent == this);
    assert(child.attached == attached);
    assert(child.parentData != null);
    child._cleanRelayoutBoundary();
    child.parentData!.detach();
    child.parentData = null;
    child._parent = null;
    if (attached) {
      child.detach();
    }
    markNeedsLayout();
    markNeedsCompositingBitsUpdate();
    markNeedsSemanticsUpdate();
  }

  void visitChildren(RenderObjectVisitor visitor) { }

  Object? debugCreator;

  void _reportException(String method, Object exception, StackTrace stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'rendering library',
      context: ErrorDescription('during $method()'),
      informationCollector: () => <DiagnosticsNode>[
        // debugCreator should always be null outside of debugMode, but we want
        // the tree shaker to notice this.
        if (kDebugMode && debugCreator != null)
          DiagnosticsDebugCreator(debugCreator!),
        describeForError('The following RenderObject was being processed when the exception was fired'),
        // TODO(jacobr): this error message has a code smell. Consider whether
        // displaying the truncated children is really useful for command line
        // users. Inspector users can see the full tree by clicking on the
        // render object so this may not be that useful.
        describeForError('RenderObject', style: DiagnosticsTreeStyle.truncateChildren),
      ],
    ));
  }

  bool get debugDoingThisResize => _debugDoingThisResize;
  bool _debugDoingThisResize = false;

  bool get debugDoingThisLayout => _debugDoingThisLayout;
  bool _debugDoingThisLayout = false;

  static RenderObject? get debugActiveLayout => _debugActiveLayout;
  static RenderObject? _debugActiveLayout;

  @pragma('vm:prefer-inline')
  static T _withDebugActiveLayoutCleared<T>(T Function() inner) {
    RenderObject? debugPreviousActiveLayout;
    assert(() {
      debugPreviousActiveLayout = _debugActiveLayout;
      _debugActiveLayout = null;
      return true;
    }());
    final T result = inner();
    assert(() {
      _debugActiveLayout = debugPreviousActiveLayout;
      return true;
    }());
    return result;
  }

  bool get debugCanParentUseSize => _debugCanParentUseSize!;
  bool? _debugCanParentUseSize;

  bool _debugMutationsLocked = false;

  bool get _debugCanPerformMutations {
    late bool result;
    assert(() {
      if (_debugDisposed) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A disposed RenderObject was mutated.'),
          DiagnosticsProperty<RenderObject>(
            'The disposed RenderObject was',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }

      final PipelineOwner? owner = this.owner;
      // Detached nodes are allowed to mutate and the "can perform mutations"
      // check will be performed when they re-attach. This assert is only useful
      // during layout.
      if (owner == null || !owner.debugDoingLayout) {
        result = true;
        return true;
      }

      RenderObject? activeLayoutRoot = this;
      while (activeLayoutRoot != null) {
        final bool mutationsToDirtySubtreesAllowed = activeLayoutRoot.owner?._debugAllowMutationsToDirtySubtrees ?? false;
        final bool doingLayoutWithCallback = activeLayoutRoot._doingThisLayoutWithCallback;
        // Mutations on this subtree is allowed when:
        // - the "activeLayoutRoot" subtree is being mutated in a layout callback.
        // - a different part of the render tree is doing a layout callback,
        //   and this subtree is being reparented to that subtree, as a result
        //   of global key reparenting.
        if (doingLayoutWithCallback || mutationsToDirtySubtreesAllowed && activeLayoutRoot._needsLayout) {
          result = true;
          return true;
        }

        if (!activeLayoutRoot._debugMutationsLocked) {
          final RenderObject? p = activeLayoutRoot.debugLayoutParent;
          activeLayoutRoot = p is RenderObject ? p : null;
        } else {
          // activeLayoutRoot found.
          break;
        }
      }

      final RenderObject debugActiveLayout = RenderObject.debugActiveLayout!;
      final String culpritMethodName = debugActiveLayout.debugDoingThisLayout ? 'performLayout' : 'performResize';
      final String culpritFullMethodName = '${debugActiveLayout.runtimeType}.$culpritMethodName';
      result = false;

      if (activeLayoutRoot == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A $runtimeType was mutated in $culpritFullMethodName.'),
          ErrorDescription(
            'The RenderObject was mutated when none of its ancestors is actively performing layout.',
          ),
          DiagnosticsProperty<RenderObject>(
            'The RenderObject being mutated was',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          DiagnosticsProperty<RenderObject>(
            'The RenderObject that was mutating the said $runtimeType was',
            debugActiveLayout,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }

      if (activeLayoutRoot == this) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A $runtimeType was mutated in its own $culpritMethodName implementation.'),
          ErrorDescription('A RenderObject must not re-dirty itself while still being laid out.'),
          DiagnosticsProperty<RenderObject>(
            'The RenderObject being mutated was',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          ErrorHint('Consider using the LayoutBuilder widget to dynamically change a subtree during layout.'),
        ]);
      }

      final ErrorSummary summary = ErrorSummary('A $runtimeType was mutated in $culpritFullMethodName.');
      final bool isMutatedByAncestor = activeLayoutRoot == debugActiveLayout;
      final String description = isMutatedByAncestor
        ? 'A RenderObject must not mutate its descendants in its $culpritMethodName method.'
        : 'A RenderObject must not mutate another RenderObject from a different render subtree '
          'in its $culpritMethodName method.';

      throw FlutterError.fromParts(<DiagnosticsNode>[
        summary,
        ErrorDescription(description),
        DiagnosticsProperty<RenderObject>(
          'The RenderObject being mutated was',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        ),
        DiagnosticsProperty<RenderObject>(
          'The ${isMutatedByAncestor ? 'ancestor ' : ''}RenderObject that was mutating the said $runtimeType was',
          debugActiveLayout,
          style: DiagnosticsTreeStyle.errorProperty,
        ),
        if (!isMutatedByAncestor) DiagnosticsProperty<RenderObject>(
          'Their common ancestor was',
          activeLayoutRoot,
          style: DiagnosticsTreeStyle.errorProperty,
        ),
        ErrorHint(
          'Mutating the layout of another RenderObject may cause some RenderObjects in its subtree to be laid out more than once. '
          'Consider using the LayoutBuilder widget to dynamically mutate a subtree during layout.'
        ),
      ]);
    }());
    return result;
  }

  @protected
  RenderObject? get debugLayoutParent {
    RenderObject? layoutParent;
    assert(() {
      layoutParent = parent;
      return true;
    }());
    return layoutParent;
  }

  PipelineOwner? get owner => _owner;
  PipelineOwner? _owner;

  bool get attached => _owner != null;

  @mustCallSuper
  void attach(PipelineOwner owner) {
    assert(!_debugDisposed);
    assert(_owner == null);
    _owner = owner;
    // If the node was dirtied in some way while unattached, make sure to add
    // it to the appropriate dirty list now that an owner is available
    if (_needsLayout && _relayoutBoundary != null) {
      // Don't enter this block if we've never laid out at all;
      // scheduleInitialLayout() will handle it
      _needsLayout = false;
      markNeedsLayout();
    }
    if (_needsCompositingBitsUpdate) {
      _needsCompositingBitsUpdate = false;
      markNeedsCompositingBitsUpdate();
    }
    if (_needsPaint && _layerHandle.layer != null) {
      // Don't enter this block if we've never painted at all;
      // scheduleInitialPaint() will handle it
      _needsPaint = false;
      markNeedsPaint();
    }
    if (_needsSemanticsUpdate && _semanticsConfiguration.isSemanticBoundary) {
      // Don't enter this block if we've never updated semantics at all;
      // scheduleInitialSemantics() will handle it
      _needsSemanticsUpdate = false;
      markNeedsSemanticsUpdate();
    }
  }

  @mustCallSuper
  void detach() {
    assert(_owner != null);
    _owner = null;
    assert(parent == null || attached == parent!.attached);
  }

  bool get debugNeedsLayout {
    late bool result;
    assert(() {
      result = _needsLayout;
      return true;
    }());
    return result;
  }
  bool _needsLayout = true;

  RenderObject? _relayoutBoundary;

  bool get debugDoingThisLayoutWithCallback => _doingThisLayoutWithCallback;
  bool _doingThisLayoutWithCallback = false;

  @protected
  Constraints get constraints {
    if (_constraints == null) {
      throw StateError('A RenderObject does not have any constraints before it has been laid out.');
    }
    return _constraints!;
  }
  Constraints? _constraints;

  @protected
  void debugAssertDoesMeetConstraints();

  static bool debugCheckingIntrinsics = false;
  bool _debugSubtreeRelayoutRootAlreadyMarkedNeedsLayout() {
    if (_relayoutBoundary == null) {
      // We don't know where our relayout boundary is yet.
      return true;
    }
    RenderObject node = this;
    while (node != _relayoutBoundary) {
      assert(node._relayoutBoundary == _relayoutBoundary);
      assert(node.parent != null);
      node = node.parent!;
      if ((!node._needsLayout) && (!node._debugDoingThisLayout)) {
        return false;
      }
    }
    assert(node._relayoutBoundary == node);
    return true;
  }

  void markNeedsLayout() {
    assert(_debugCanPerformMutations);
    if (_needsLayout) {
      assert(_debugSubtreeRelayoutRootAlreadyMarkedNeedsLayout());
      return;
    }
    if (_relayoutBoundary == null) {
      _needsLayout = true;
      if (parent != null) {
        // _relayoutBoundary is cleaned by an ancestor in RenderObject.layout.
        // Conservatively mark everything dirty until it reaches the closest
        // known relayout boundary.
        markParentNeedsLayout();
      }
      return;
    }
    if (_relayoutBoundary != this) {
      markParentNeedsLayout();
    } else {
      _needsLayout = true;
      if (owner != null) {
        assert(() {
          if (debugPrintMarkNeedsLayoutStacks) {
            debugPrintStack(label: 'markNeedsLayout() called for $this');
          }
          return true;
        }());
        owner!._nodesNeedingLayout.add(this);
        owner!.requestVisualUpdate();
      }
    }
  }

  @protected
  void markParentNeedsLayout() {
    assert(_debugCanPerformMutations);
    _needsLayout = true;
    assert(this.parent != null);
    final RenderObject parent = this.parent!;
    if (!_doingThisLayoutWithCallback) {
      parent.markNeedsLayout();
    } else {
      assert(parent._debugDoingThisLayout);
    }
    assert(parent == this.parent);
  }

  void markNeedsLayoutForSizedByParentChange() {
    markNeedsLayout();
    markParentNeedsLayout();
  }

  void _cleanRelayoutBoundary() {
    if (_relayoutBoundary != this) {
      _relayoutBoundary = null;
      visitChildren(_cleanChildRelayoutBoundary);
    }
  }

  void _propagateRelayoutBoundary() {
    if (_relayoutBoundary == this) {
      return;
    }
    final RenderObject? parentRelayoutBoundary = parent?._relayoutBoundary;
    assert(parentRelayoutBoundary != null);
    if (parentRelayoutBoundary != _relayoutBoundary) {
      _relayoutBoundary = parentRelayoutBoundary;
      visitChildren(_propagateRelayoutBoundaryToChild);
    }
  }

  // Reduces closure allocation for visitChildren use cases.
  static void _cleanChildRelayoutBoundary(RenderObject child) {
    child._cleanRelayoutBoundary();
  }

  static void _propagateRelayoutBoundaryToChild(RenderObject child) {
    child._propagateRelayoutBoundary();
  }

  void scheduleInitialLayout() {
    assert(!_debugDisposed);
    assert(attached);
    assert(parent is! RenderObject);
    assert(!owner!._debugDoingLayout);
    assert(_relayoutBoundary == null);
    _relayoutBoundary = this;
    assert(() {
      _debugCanParentUseSize = false;
      return true;
    }());
    owner!._nodesNeedingLayout.add(this);
  }

  @pragma('vm:notify-debugger-on-exception')
  void _layoutWithoutResize() {
    assert(_relayoutBoundary == this);
    RenderObject? debugPreviousActiveLayout;
    assert(!_debugMutationsLocked);
    assert(!_doingThisLayoutWithCallback);
    assert(_debugCanParentUseSize != null);
    assert(() {
      _debugMutationsLocked = true;
      _debugDoingThisLayout = true;
      debugPreviousActiveLayout = _debugActiveLayout;
      _debugActiveLayout = this;
      if (debugPrintLayouts) {
        debugPrint('Laying out (without resize) $this');
      }
      return true;
    }());
    try {
      performLayout();
      markNeedsSemanticsUpdate();
    } catch (e, stack) {
      _reportException('performLayout', e, stack);
    }
    assert(() {
      _debugActiveLayout = debugPreviousActiveLayout;
      _debugDoingThisLayout = false;
      _debugMutationsLocked = false;
      return true;
    }());
    _needsLayout = false;
    markNeedsPaint();
  }

  @pragma('vm:notify-debugger-on-exception')
  void layout(Constraints constraints, { bool parentUsesSize = false }) {
    assert(!_debugDisposed);
    if (!kReleaseMode && debugProfileLayoutsEnabled) {
      Map<String, String>? debugTimelineArguments;
      assert(() {
        if (debugEnhanceLayoutTimelineArguments) {
          debugTimelineArguments = toDiagnosticsNode().toTimelineArguments();
        }
        return true;
      }());
      FlutterTimeline.startSync(
        '$runtimeType',
        arguments: debugTimelineArguments,
      );
    }
    assert(constraints.debugAssertIsValid(
      isAppliedConstraint: true,
      informationCollector: () {
        final List<String> stack = StackTrace.current.toString().split('\n');
        int? targetFrame;
        final Pattern layoutFramePattern = RegExp(r'^#[0-9]+ +Render(?:Object|Box).layout \(');
        for (int i = 0; i < stack.length; i += 1) {
          if (layoutFramePattern.matchAsPrefix(stack[i]) != null) {
            targetFrame = i + 1;
          } else if (targetFrame != null) {
            break;
          }
        }
        if (targetFrame != null && targetFrame < stack.length) {
          final Pattern targetFramePattern = RegExp(r'^#[0-9]+ +(.+)$');
          final Match? targetFrameMatch = targetFramePattern.matchAsPrefix(stack[targetFrame]);
          final String? problemFunction = (targetFrameMatch != null && targetFrameMatch.groupCount > 0) ? targetFrameMatch.group(1) : stack[targetFrame].trim();
          return <DiagnosticsNode>[
            ErrorDescription(
              "These invalid constraints were provided to $runtimeType's layout() "
              'function by the following function, which probably computed the '
              'invalid constraints in question:\n'
              '  $problemFunction',
            ),
          ];
        }
        return <DiagnosticsNode>[];
      },
    ));
    assert(!_debugDoingThisResize);
    assert(!_debugDoingThisLayout);
    final bool isRelayoutBoundary = !parentUsesSize || sizedByParent || constraints.isTight || parent is! RenderObject;
    final RenderObject relayoutBoundary = isRelayoutBoundary ? this : parent!._relayoutBoundary!;
    assert(() {
      _debugCanParentUseSize = parentUsesSize;
      return true;
    }());

    if (!_needsLayout && constraints == _constraints) {
      assert(() {
        // in case parentUsesSize changed since the last invocation, set size
        // to itself, so it has the right internal debug values.
        _debugDoingThisResize = sizedByParent;
        _debugDoingThisLayout = !sizedByParent;
        final RenderObject? debugPreviousActiveLayout = _debugActiveLayout;
        _debugActiveLayout = this;
        debugResetSize();
        _debugActiveLayout = debugPreviousActiveLayout;
        _debugDoingThisLayout = false;
        _debugDoingThisResize = false;
        return true;
      }());

      if (relayoutBoundary != _relayoutBoundary) {
        _relayoutBoundary = relayoutBoundary;
        visitChildren(_propagateRelayoutBoundaryToChild);
      }

      if (!kReleaseMode && debugProfileLayoutsEnabled) {
        FlutterTimeline.finishSync();
      }
      return;
    }
    _constraints = constraints;
    if (_relayoutBoundary != null && relayoutBoundary != _relayoutBoundary) {
      // The local relayout boundary has changed, must notify children in case
      // they also need updating. Otherwise, they will be confused about what
      // their actual relayout boundary is later.
      visitChildren(_cleanChildRelayoutBoundary);
    }
    _relayoutBoundary = relayoutBoundary;
    assert(!_debugMutationsLocked);
    assert(!_doingThisLayoutWithCallback);
    assert(() {
      _debugMutationsLocked = true;
      if (debugPrintLayouts) {
        debugPrint('Laying out (${sizedByParent ? "with separate resize" : "with resize allowed"}) $this');
      }
      return true;
    }());
    if (sizedByParent) {
      assert(() {
        _debugDoingThisResize = true;
        return true;
      }());
      try {
        performResize();
        assert(() {
          debugAssertDoesMeetConstraints();
          return true;
        }());
      } catch (e, stack) {
        _reportException('performResize', e, stack);
      }
      assert(() {
        _debugDoingThisResize = false;
        return true;
      }());
    }
    RenderObject? debugPreviousActiveLayout;
    assert(() {
      _debugDoingThisLayout = true;
      debugPreviousActiveLayout = _debugActiveLayout;
      _debugActiveLayout = this;
      return true;
    }());
    try {
      performLayout();
      markNeedsSemanticsUpdate();
      assert(() {
        debugAssertDoesMeetConstraints();
        return true;
      }());
    } catch (e, stack) {
      _reportException('performLayout', e, stack);
    }
    assert(() {
      _debugActiveLayout = debugPreviousActiveLayout;
      _debugDoingThisLayout = false;
      _debugMutationsLocked = false;
      return true;
    }());
    _needsLayout = false;
    markNeedsPaint();

    if (!kReleaseMode && debugProfileLayoutsEnabled) {
      FlutterTimeline.finishSync();
    }
  }

  @protected
  void debugResetSize() { }

  @protected
  bool get sizedByParent => false;

  @protected
  void performResize();

  @protected
  void performLayout();

  @protected
  void invokeLayoutCallback<T extends Constraints>(LayoutCallback<T> callback) {
    assert(_debugMutationsLocked);
    assert(_debugDoingThisLayout);
    assert(!_doingThisLayoutWithCallback);
    _doingThisLayoutWithCallback = true;
    try {
      owner!._enableMutationsToDirtySubtrees(() { callback(constraints as T); });
    } finally {
      _doingThisLayoutWithCallback = false;
    }
  }

  // PAINTING

  bool get debugDoingThisPaint => _debugDoingThisPaint;
  bool _debugDoingThisPaint = false;

  static RenderObject? get debugActivePaint => _debugActivePaint;
  static RenderObject? _debugActivePaint;

  bool get isRepaintBoundary => false;

  void debugRegisterRepaintBoundaryPaint({ bool includedParent = true, bool includedChild = false }) { }

  @protected
  bool get alwaysNeedsCompositing => false;

  late bool _wasRepaintBoundary;

  // TODO(jonahwilliams): https://github.com/flutter/flutter/issues/102102 revisit the
  // constraint that the instance/type of layer cannot be changed at runtime.
  OffsetLayer updateCompositedLayer({required covariant OffsetLayer? oldLayer}) {
    assert(isRepaintBoundary);
    return oldLayer ?? OffsetLayer();
  }

  @protected
  ContainerLayer? get layer {
    assert(!isRepaintBoundary || _layerHandle.layer == null || _layerHandle.layer is OffsetLayer);
    return _layerHandle.layer;
  }

  @protected
  set layer(ContainerLayer? newLayer) {
    assert(
      !isRepaintBoundary,
      'Attempted to set a layer to a repaint boundary render object.\n'
      'The framework creates and assigns an OffsetLayer to a repaint '
      'boundary automatically.',
    );
    _layerHandle.layer = newLayer;
  }

  final LayerHandle<ContainerLayer> _layerHandle = LayerHandle<ContainerLayer>();

  ContainerLayer? get debugLayer {
    ContainerLayer? result;
    assert(() {
      result = _layerHandle.layer;
      return true;
    }());
    return result;
  }

  bool _needsCompositingBitsUpdate = false; // set to true when a child is added
  void markNeedsCompositingBitsUpdate() {
    assert(!_debugDisposed);
    if (_needsCompositingBitsUpdate) {
      return;
    }
    _needsCompositingBitsUpdate = true;
    if (parent is RenderObject) {
      final RenderObject parent = this.parent!;
      if (parent._needsCompositingBitsUpdate) {
        return;
      }

      if ((!_wasRepaintBoundary || !isRepaintBoundary) && !parent.isRepaintBoundary) {
        parent.markNeedsCompositingBitsUpdate();
        return;
      }
    }
    // parent is fine (or there isn't one), but we are dirty
    if (owner != null) {
      owner!._nodesNeedingCompositingBitsUpdate.add(this);
    }
  }

  late bool _needsCompositing; // initialized in the constructor
  bool get needsCompositing {
    assert(!_needsCompositingBitsUpdate); // make sure we don't use this bit when it is dirty
    return _needsCompositing;
  }

  void _updateCompositingBits() {
    if (!_needsCompositingBitsUpdate) {
      return;
    }
    final bool oldNeedsCompositing = _needsCompositing;
    _needsCompositing = false;
    visitChildren((RenderObject child) {
      child._updateCompositingBits();
      if (child.needsCompositing) {
        _needsCompositing = true;
      }
    });
    if (isRepaintBoundary || alwaysNeedsCompositing) {
      _needsCompositing = true;
    }
    // If a node was previously a repaint boundary, but no longer is one, then
    // regardless of its compositing state we need to find a new parent to
    // paint from. To do this, we mark it clean again so that the traversal
    // in markNeedsPaint is not short-circuited. It is removed from _nodesNeedingPaint
    // so that we do not attempt to paint from it after locating a parent.
    if (!isRepaintBoundary && _wasRepaintBoundary) {
      _needsPaint = false;
      _needsCompositedLayerUpdate = false;
      owner?._nodesNeedingPaint.remove(this);
      _needsCompositingBitsUpdate = false;
      markNeedsPaint();
    } else if (oldNeedsCompositing != _needsCompositing) {
      _needsCompositingBitsUpdate = false;
      markNeedsPaint();
    } else {
      _needsCompositingBitsUpdate = false;
    }
  }

  bool get debugNeedsPaint {
    late bool result;
    assert(() {
      result = _needsPaint;
      return true;
    }());
    return result;
  }
  bool _needsPaint = true;

  bool get debugNeedsCompositedLayerUpdate {
    late bool result;
    assert(() {
      result = _needsCompositedLayerUpdate;
      return true;
    }());
    return result;
  }
  bool _needsCompositedLayerUpdate = false;

  void markNeedsPaint() {
    assert(!_debugDisposed);
    assert(owner == null || !owner!.debugDoingPaint);
    if (_needsPaint) {
      return;
    }
    _needsPaint = true;
    // If this was not previously a repaint boundary it will not have
    // a layer we can paint from.
    if (isRepaintBoundary && _wasRepaintBoundary) {
      assert(() {
        if (debugPrintMarkNeedsPaintStacks) {
          debugPrintStack(label: 'markNeedsPaint() called for $this');
        }
        return true;
      }());
      // If we always have our own layer, then we can just repaint
      // ourselves without involving any other nodes.
      assert(_layerHandle.layer is OffsetLayer);
      if (owner != null) {
        owner!._nodesNeedingPaint.add(this);
        owner!.requestVisualUpdate();
      }
    } else if (parent is RenderObject) {
      parent!.markNeedsPaint();
    } else {
      assert(() {
        if (debugPrintMarkNeedsPaintStacks) {
          debugPrintStack(label: 'markNeedsPaint() called for $this (root of render tree)');
        }
        return true;
      }());
      // If we are the root of the render tree and not a repaint boundary
      // then we have to paint ourselves, since nobody else can paint us.
      // We don't add ourselves to _nodesNeedingPaint in this case,
      // because the root is always told to paint regardless.
      //
      // Trees rooted at a RenderView do not go through this
      // code path because RenderViews are repaint boundaries.
      if (owner != null) {
        owner!.requestVisualUpdate();
      }
    }
  }

  void markNeedsCompositedLayerUpdate() {
    assert(!_debugDisposed);
    assert(owner == null || !owner!.debugDoingPaint);
    if (_needsCompositedLayerUpdate || _needsPaint) {
      return;
    }
    _needsCompositedLayerUpdate = true;
    // If this was not previously a repaint boundary it will not have
    // a layer we can paint from.
    if (isRepaintBoundary && _wasRepaintBoundary) {
      // If we always have our own layer, then we can just repaint
      // ourselves without involving any other nodes.
      assert(_layerHandle.layer != null);
      if (owner != null) {
        owner!._nodesNeedingPaint.add(this);
        owner!.requestVisualUpdate();
      }
    } else {
      markNeedsPaint();
    }
  }

  // Called when flushPaint() tries to make us paint but our layer is detached.
  // To make sure that our subtree is repainted when it's finally reattached,
  // even in the case where some ancestor layer is itself never marked dirty, we
  // have to mark our entire detached subtree as dirty and needing to be
  // repainted. That way, we'll eventually be repainted.
  void _skippedPaintingOnLayer() {
    assert(attached);
    assert(isRepaintBoundary);
    assert(_needsPaint || _needsCompositedLayerUpdate);
    assert(_layerHandle.layer != null);
    assert(!_layerHandle.layer!.attached);
    RenderObject? node = parent;
    while (node is RenderObject) {
      if (node.isRepaintBoundary) {
        if (node._layerHandle.layer == null) {
          // Looks like the subtree here has never been painted. Let it handle itself.
          break;
        }
        if (node._layerHandle.layer!.attached) {
          // It's the one that detached us, so it's the one that will decide to repaint us.
          break;
        }
        node._needsPaint = true;
      }
      node = node.parent;
    }
  }

  void scheduleInitialPaint(ContainerLayer rootLayer) {
    assert(rootLayer.attached);
    assert(attached);
    assert(parent is! RenderObject);
    assert(!owner!._debugDoingPaint);
    assert(isRepaintBoundary);
    assert(_layerHandle.layer == null);
    _layerHandle.layer = rootLayer;
    assert(_needsPaint);
    owner!._nodesNeedingPaint.add(this);
  }

  void replaceRootLayer(OffsetLayer rootLayer) {
    assert(!_debugDisposed);
    assert(rootLayer.attached);
    assert(attached);
    assert(parent is! RenderObject);
    assert(!owner!._debugDoingPaint);
    assert(isRepaintBoundary);
    assert(_layerHandle.layer != null); // use scheduleInitialPaint the first time
    _layerHandle.layer!.detach();
    _layerHandle.layer = rootLayer;
    markNeedsPaint();
  }

  void _paintWithContext(PaintingContext context, Offset offset) {
    assert(!_debugDisposed);
    assert(() {
      if (_debugDoingThisPaint) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Tried to paint a RenderObject reentrantly.'),
          describeForError(
            'The following RenderObject was already being painted when it was '
            'painted again',
          ),
          ErrorDescription(
            'Since this typically indicates an infinite recursion, it is '
            'disallowed.',
          ),
        ]);
      }
      return true;
    }());
    // If we still need layout, then that means that we were skipped in the
    // layout phase and therefore don't need painting. We might not know that
    // yet (that is, our layer might not have been detached yet), because the
    // same node that skipped us in layout is above us in the tree (obviously)
    // and therefore may not have had a chance to paint yet (since the tree
    // paints in reverse order). In particular this will happen if they have
    // a different layer, because there's a repaint boundary between us.
    if (_needsLayout) {
      return;
    }
    if (!kReleaseMode && debugProfilePaintsEnabled) {
      Map<String, String>? debugTimelineArguments;
      assert(() {
        if (debugEnhancePaintTimelineArguments) {
          debugTimelineArguments = toDiagnosticsNode().toTimelineArguments();
        }
        return true;
      }());
      FlutterTimeline.startSync(
        '$runtimeType',
        arguments: debugTimelineArguments,
      );
    }
    assert(() {
      if (_needsCompositingBitsUpdate) {
        if (parent is RenderObject) {
          final RenderObject parent = this.parent!;
          bool visitedByParent = false;
          parent.visitChildren((RenderObject child) {
            if (child == this) {
              visitedByParent = true;
            }
          });
          if (!visitedByParent) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary(
                "A RenderObject was not visited by the parent's visitChildren "
                'during paint.',
              ),
              parent.describeForError(
                'The parent was',
              ),
              describeForError(
                'The child that was not visited was',
              ),
              ErrorDescription(
                'A RenderObject with children must implement visitChildren and '
                'call the visitor exactly once for each child; it also should not '
                'paint children that were removed with dropChild.',
              ),
              ErrorHint(
                'This usually indicates an error in the Flutter framework itself.',
              ),
            ]);
          }
        }
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'Tried to paint a RenderObject before its compositing bits were '
            'updated.',
          ),
          describeForError(
            'The following RenderObject was marked as having dirty compositing '
            'bits at the time that it was painted',
          ),
          ErrorDescription(
            'A RenderObject that still has dirty compositing bits cannot be '
            'painted because this indicates that the tree has not yet been '
            'properly configured for creating the layer tree.',
          ),
          ErrorHint(
            'This usually indicates an error in the Flutter framework itself.',
          ),
        ]);
      }
      return true;
    }());
    RenderObject? debugLastActivePaint;
    assert(() {
      _debugDoingThisPaint = true;
      debugLastActivePaint = _debugActivePaint;
      _debugActivePaint = this;
      assert(!isRepaintBoundary || _layerHandle.layer != null);
      return true;
    }());
    _needsPaint = false;
    _needsCompositedLayerUpdate = false;
    _wasRepaintBoundary = isRepaintBoundary;
    try {
      paint(context, offset);
      assert(!_needsLayout); // check that the paint() method didn't mark us dirty again
      assert(!_needsPaint); // check that the paint() method didn't mark us dirty again
    } catch (e, stack) {
      _reportException('paint', e, stack);
    }
    assert(() {
      debugPaint(context, offset);
      _debugActivePaint = debugLastActivePaint;
      _debugDoingThisPaint = false;
      return true;
    }());
    if (!kReleaseMode && debugProfilePaintsEnabled) {
      FlutterTimeline.finishSync();
    }
  }

  Rect get paintBounds;

  void debugPaint(PaintingContext context, Offset offset) { }

  void paint(PaintingContext context, Offset offset) { }

  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    assert(child.parent == this);
  }

  bool paintsChild(covariant RenderObject child) {
    assert(child.parent == this);
    return true;
  }

  Matrix4 getTransformTo(RenderObject? ancestor) {
    final bool ancestorSpecified = ancestor != null;
    assert(attached);
    if (ancestor == null) {
      final RenderObject? rootNode = owner!.rootNode;
      if (rootNode is RenderObject) {
        ancestor = rootNode;
      }
    }
    final List<RenderObject> renderers = <RenderObject>[];
    for (RenderObject renderer = this; renderer != ancestor; renderer = renderer.parent!) {
      renderers.add(renderer);
      assert(renderer.parent != null); // Failed to find ancestor in parent chain.
    }
    if (ancestorSpecified) {
      renderers.add(ancestor!);
    }
    final Matrix4 transform = Matrix4.identity();
    for (int index = renderers.length - 1; index > 0; index -= 1) {
      renderers[index].applyPaintTransform(renderers[index - 1], transform);
    }
    return transform;
  }


  Rect? describeApproximatePaintClip(covariant RenderObject child) => null;

  Rect? describeSemanticsClip(covariant RenderObject? child) => null;

  // SEMANTICS

  void scheduleInitialSemantics() {
    assert(!_debugDisposed);
    assert(attached);
    assert(parent is! RenderObject);
    assert(!owner!._debugDoingSemantics);
    assert(_semantics == null);
    assert(_needsSemanticsUpdate);
    assert(owner!._semanticsOwner != null);
    owner!._nodesNeedingSemantics.add(this);
    owner!.requestVisualUpdate();
  }

  @protected
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    // Nothing to do by default.
  }

  void sendSemanticsEvent(SemanticsEvent semanticsEvent) {
    if (owner!.semanticsOwner == null) {
      return;
    }
    if (_semantics != null && !_semantics!.isMergedIntoParent) {
      _semantics!.sendEvent(semanticsEvent);
    } else if (parent != null) {
      parent!.sendSemanticsEvent(semanticsEvent);
    }
  }

  // Use [_semanticsConfiguration] to access.
  SemanticsConfiguration? _cachedSemanticsConfiguration;

  SemanticsConfiguration get _semanticsConfiguration {
    if (_cachedSemanticsConfiguration == null) {
      _cachedSemanticsConfiguration = SemanticsConfiguration();
      describeSemanticsConfiguration(_cachedSemanticsConfiguration!);
      assert(
        !_cachedSemanticsConfiguration!.explicitChildNodes || _cachedSemanticsConfiguration!.childConfigurationsDelegate == null,
        'A SemanticsConfiguration with explicitChildNode set to true cannot have a non-null childConfigsDelegate.',
      );
    }
    return _cachedSemanticsConfiguration!;
  }

  Rect get semanticBounds;

  bool _needsSemanticsUpdate = true;
  SemanticsNode? _semantics;

  SemanticsNode? get debugSemantics {
    if (!kReleaseMode) {
      return _semantics;
    }
    return null;
  }

  @mustCallSuper
  void clearSemantics() {
    _needsSemanticsUpdate = true;
    _semantics = null;
    visitChildren((RenderObject child) {
      child.clearSemantics();
    });
  }

  void markNeedsSemanticsUpdate() {
    assert(!_debugDisposed);
    assert(!attached || !owner!._debugDoingSemantics);
    if (!attached || owner!._semanticsOwner == null) {
      _cachedSemanticsConfiguration = null;
      return;
    }

    // Dirty the semantics tree starting at `this` until we have reached a
    // RenderObject that is a semantics boundary. All semantics past this
    // RenderObject are still up-to date. Therefore, we will later only rebuild
    // the semantics subtree starting at the identified semantics boundary.

    final bool wasSemanticsBoundary = _semantics != null && (_cachedSemanticsConfiguration?.isSemanticBoundary ?? false);

    bool mayProduceSiblingNodes =
      _cachedSemanticsConfiguration?.childConfigurationsDelegate != null ||
      _semanticsConfiguration.childConfigurationsDelegate != null;
    _cachedSemanticsConfiguration = null;

    bool isEffectiveSemanticsBoundary = _semanticsConfiguration.isSemanticBoundary && wasSemanticsBoundary;
    RenderObject node = this;

    // The sibling nodes will be attached to the parent of immediate semantics
    // node, thus marking this semantics boundary dirty is not enough, it needs
    // to find the first parent semantics boundary that does not have any
    // possible sibling node.
    while (node.parent is RenderObject && (mayProduceSiblingNodes || !isEffectiveSemanticsBoundary)) {
      if (node != this && node._needsSemanticsUpdate) {
        break;
      }
      node._needsSemanticsUpdate = true;
      // Since this node is a semantics boundary, the produced sibling nodes will
      // be attached to the parent semantics boundary. Thus, these sibling nodes
      // will not be carried to the next loop.
      if (isEffectiveSemanticsBoundary) {
        mayProduceSiblingNodes = false;
      }

      node = node.parent!;
      isEffectiveSemanticsBoundary = node._semanticsConfiguration.isSemanticBoundary;
      if (isEffectiveSemanticsBoundary && node._semantics == null) {
        // We have reached a semantics boundary that doesn't own a semantics node.
        // That means the semantics of this branch are currently blocked and will
        // not appear in the semantics tree. We can abort the walk here.
        return;
      }
    }
    if (node != this && _semantics != null && _needsSemanticsUpdate) {
      // If `this` node has already been added to [owner._nodesNeedingSemantics]
      // remove it as it is no longer guaranteed that its semantics
      // node will continue to be in the tree. If it still is in the tree, the
      // ancestor `node` added to [owner._nodesNeedingSemantics] at the end of
      // this block will ensure that the semantics of `this` node actually gets
      // updated.
      // (See semantics_10_test.dart for an example why this is required).
      owner!._nodesNeedingSemantics.remove(this);
    }
    if (!node._needsSemanticsUpdate) {
      node._needsSemanticsUpdate = true;
      if (owner != null) {
        assert(node._semanticsConfiguration.isSemanticBoundary || node.parent is! RenderObject);
        owner!._nodesNeedingSemantics.add(node);
        owner!.requestVisualUpdate();
      }
    }
  }

  void _updateSemantics() {
    assert(_semanticsConfiguration.isSemanticBoundary || parent is! RenderObject);
    if (_needsLayout) {
      // There's not enough information in this subtree to compute semantics.
      // The subtree is probably being kept alive by a viewport but not laid out.
      return;
    }
    if (!kReleaseMode) {
      FlutterTimeline.startSync('Semantics.GetFragment');
    }
    final _SemanticsFragment fragment = _getSemanticsForParent(
      mergeIntoParent: _semantics?.parent?.isPartOfNodeMerging ?? false,
      blockUserActions: _semantics?.areUserActionsBlocked ?? false,
    );
    if (!kReleaseMode) {
      FlutterTimeline.finishSync();
    }
    assert(fragment is _InterestingSemanticsFragment);
    final _InterestingSemanticsFragment interestingFragment = fragment as _InterestingSemanticsFragment;
    final List<SemanticsNode> result = <SemanticsNode>[];
    final List<SemanticsNode> siblingNodes = <SemanticsNode>[];

    if (!kReleaseMode) {
      FlutterTimeline.startSync('Semantics.compileChildren');
    }
    interestingFragment.compileChildren(
      parentSemanticsClipRect: _semantics?.parentSemanticsClipRect,
      parentPaintClipRect: _semantics?.parentPaintClipRect,
      elevationAdjustment: _semantics?.elevationAdjustment ?? 0.0,
      result: result,
      siblingNodes: siblingNodes,
    );
    if (!kReleaseMode) {
      FlutterTimeline.finishSync();
    }
    // Result may contain sibling nodes that are irrelevant for this update.
    assert(interestingFragment.config == null && result.any((SemanticsNode node) => node == _semantics));
  }

  _SemanticsFragment _getSemanticsForParent({
    required bool mergeIntoParent,
    required bool blockUserActions,
  }) {
    assert(!_needsLayout, 'Updated layout information required for $this to calculate semantics.');

    final SemanticsConfiguration config = _semanticsConfiguration;
    bool dropSemanticsOfPreviousSiblings = config.isBlockingSemanticsOfPreviouslyPaintedNodes;
    bool producesForkingFragment = !config.hasBeenAnnotated && !config.isSemanticBoundary;
    final bool blockChildInteractions = blockUserActions || config.isBlockingUserActions;
    final bool childrenMergeIntoParent = mergeIntoParent || config.isMergingSemanticsOfDescendants;
    final List<SemanticsConfiguration> childConfigurations = <SemanticsConfiguration>[];
    final bool explicitChildNode = config.explicitChildNodes || parent is! RenderObject;
    final bool hasChildConfigurationsDelegate = config.childConfigurationsDelegate != null;
    final Map<SemanticsConfiguration, _InterestingSemanticsFragment> configToFragment = <SemanticsConfiguration, _InterestingSemanticsFragment>{};
    final List<_InterestingSemanticsFragment> mergeUpFragments = <_InterestingSemanticsFragment>[];
    final List<List<_InterestingSemanticsFragment>> siblingMergeFragmentGroups = <List<_InterestingSemanticsFragment>>[];
    final bool hasTags = config.tagsForChildren?.isNotEmpty ?? false;
    visitChildrenForSemantics((RenderObject renderChild) {
      assert(!_needsLayout);
      final _SemanticsFragment parentFragment = renderChild._getSemanticsForParent(
        mergeIntoParent: childrenMergeIntoParent,
        blockUserActions: blockChildInteractions,
      );
      if (parentFragment.dropsSemanticsOfPreviousSiblings) {
        childConfigurations.clear();
        mergeUpFragments.clear();
        siblingMergeFragmentGroups.clear();
        if (!config.isSemanticBoundary) {
          dropSemanticsOfPreviousSiblings = true;
        }
      }
      for (final _InterestingSemanticsFragment fragment in parentFragment.mergeUpFragments) {
        fragment.addAncestor(this);
        if (hasTags) {
          fragment.addTags(config.tagsForChildren!);
        }
        if (hasChildConfigurationsDelegate && fragment.config != null) {
          // This fragment need to go through delegate to determine whether it
          // merge up or not.
          childConfigurations.add(fragment.config!);
          configToFragment[fragment.config!] = fragment;
        } else {
          mergeUpFragments.add(fragment);
        }
      }
      if (parentFragment is _ContainerSemanticsFragment) {
        // Container fragments needs to propagate sibling merge group to be
        // compiled by _SwitchableSemanticsFragment.
        for (final List<_InterestingSemanticsFragment> siblingMergeGroup in parentFragment.siblingMergeGroups) {
          for (final _InterestingSemanticsFragment siblingMergingFragment in siblingMergeGroup) {
            siblingMergingFragment.addAncestor(this);
            if (hasTags) {
              siblingMergingFragment.addTags(config.tagsForChildren!);
            }
          }
          siblingMergeFragmentGroups.add(siblingMergeGroup);
        }
      }
    });

    assert(hasChildConfigurationsDelegate || configToFragment.isEmpty);

    if (explicitChildNode) {
      for (final _InterestingSemanticsFragment fragment in mergeUpFragments) {
        fragment.markAsExplicit();
      }
    } else if (hasChildConfigurationsDelegate) {
      final ChildSemanticsConfigurationsResult result = config.childConfigurationsDelegate!(childConfigurations);
      mergeUpFragments.addAll(
        result.mergeUp.map<_InterestingSemanticsFragment>((SemanticsConfiguration config) {
          final _InterestingSemanticsFragment? fragment = configToFragment[config];
          if (fragment == null) {
            // Parent fragment of Incomplete fragments can't be a forking
            // fragment since they need to be merged.
            producesForkingFragment = false;
            return _IncompleteSemanticsFragment(config: config, owner: this);
          }
          return fragment;
        }),
      );
      for (final Iterable<SemanticsConfiguration> group in result.siblingMergeGroups) {
        siblingMergeFragmentGroups.add(
          group.map<_InterestingSemanticsFragment>((SemanticsConfiguration config) {
            return configToFragment[config] ?? _IncompleteSemanticsFragment(config: config, owner: this);
          }).toList(),
        );
      }
    }

    _needsSemanticsUpdate = false;

    final _SemanticsFragment result;
    if (parent is! RenderObject) {
      assert(!config.hasBeenAnnotated);
      assert(!mergeIntoParent);
      assert(siblingMergeFragmentGroups.isEmpty);
      _marksExplicitInMergeGroup(mergeUpFragments, isMergeUp: true);
      siblingMergeFragmentGroups.forEach(_marksExplicitInMergeGroup);
      result = _RootSemanticsFragment(
        owner: this,
        dropsSemanticsOfPreviousSiblings: dropSemanticsOfPreviousSiblings,
      );
    } else if (producesForkingFragment) {
      result = _ContainerSemanticsFragment(
        siblingMergeGroups: siblingMergeFragmentGroups,
        dropsSemanticsOfPreviousSiblings: dropSemanticsOfPreviousSiblings,
      );
    } else {
      _marksExplicitInMergeGroup(mergeUpFragments, isMergeUp: true);
      siblingMergeFragmentGroups.forEach(_marksExplicitInMergeGroup);
      result = _SwitchableSemanticsFragment(
        config: config,
        blockUserActions: blockUserActions,
        mergeIntoParent: mergeIntoParent,
        siblingMergeGroups: siblingMergeFragmentGroups,
        owner: this,
        dropsSemanticsOfPreviousSiblings: dropSemanticsOfPreviousSiblings,
      );
      if (config.isSemanticBoundary) {
        final _SwitchableSemanticsFragment fragment = result as _SwitchableSemanticsFragment;
        fragment.markAsExplicit();
      }
    }
    result.addAll(mergeUpFragments);
    return result;
  }

  void _marksExplicitInMergeGroup(List<_InterestingSemanticsFragment> mergeGroup, {bool isMergeUp = false}) {
    final Set<_InterestingSemanticsFragment> toBeExplicit = <_InterestingSemanticsFragment>{};
    for (int i = 0; i < mergeGroup.length; i += 1) {
      final _InterestingSemanticsFragment fragment = mergeGroup[i];
      if (!fragment.hasConfigForParent) {
        continue;
      }
      if (isMergeUp && !_semanticsConfiguration.isCompatibleWith(fragment.config)) {
        toBeExplicit.add(fragment);
      }
      final int siblingLength = i;
      for (int j = 0; j < siblingLength; j += 1) {
        final _InterestingSemanticsFragment siblingFragment = mergeGroup[j];
        if (!fragment.config!.isCompatibleWith(siblingFragment.config)) {
          toBeExplicit.add(fragment);
          toBeExplicit.add(siblingFragment);
        }
      }
    }
    for (final _InterestingSemanticsFragment fragment in toBeExplicit) {
      fragment.markAsExplicit();
    }
  }

  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren(visitor);
  }

  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    assert(node == _semantics);
    // TODO(a14n): remove the following cast by updating type of parameter in either updateWith or assembleSemanticsNode
    node.updateWith(config: config, childrenInInversePaintOrder: children as List<SemanticsNode>);
  }

  // EVENTS

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) { }


  // HIT TESTING

  // RenderObject subclasses are expected to have a method like the following
  // (with the signature being whatever passes for coordinates for this
  // particular class):
  //
  // bool hitTest(HitTestResult result, { Offset position }) {
  //   // If the given position is not inside this node, then return false.
  //   // Otherwise:
  //   // For each child that intersects the position, in z-order starting from
  //   // the top, call hitTest() for that child, passing it /result/, and the
  //   // coordinates converted to the child's coordinate origin, and stop at
  //   // the first child that returns true.
  //   // Then, add yourself to /result/, and return true.
  // }
  //
  // If you add yourself to /result/ and still return false, then that means you
  // will see events but so will objects below you.


  @override
  String toStringShort() {
    String header = describeIdentity(this);
    if (!kReleaseMode) {
      if (_debugDisposed) {
        header += ' DISPOSED';
        return header;
      }
      if (_relayoutBoundary != null && _relayoutBoundary != this) {
        int count = 1;
        RenderObject? target = parent;
        while (target != null && target != _relayoutBoundary) {
          target = target.parent;
          count += 1;
        }
        header += ' relayoutBoundary=up$count';
      }
      if (_needsLayout) {
        header += ' NEEDS-LAYOUT';
      }
      if (_needsPaint) {
        header += ' NEEDS-PAINT';
      }
      if (_needsCompositingBitsUpdate) {
        header += ' NEEDS-COMPOSITING-BITS-UPDATE';
      }
      if (!attached) {
        header += ' DETACHED';
      }
    }
    return header;
  }

  @override
  String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) => toStringShort();

  @override
  String toStringDeep({
    String prefixLineOne = '',
    String? prefixOtherLines = '',
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    return _withDebugActiveLayoutCleared(() => super.toStringDeep(
          prefixLineOne: prefixLineOne,
          prefixOtherLines: prefixOtherLines,
          minLevel: minLevel,
        ));
  }

  @override
  String toStringShallow({
    String joiner = ', ',
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    return _withDebugActiveLayoutCleared(() => super.toStringShallow(joiner: joiner, minLevel: minLevel));
  }

  @protected
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('needsCompositing', value: _needsCompositing, ifTrue: 'needs compositing'));
    properties.add(DiagnosticsProperty<Object?>('creator', debugCreator, defaultValue: null, level: DiagnosticLevel.debug));
    properties.add(DiagnosticsProperty<ParentData>('parentData', parentData, tooltip: (_debugCanParentUseSize ?? false) ? 'can use size' : null, missingIfNull: true));
    properties.add(DiagnosticsProperty<Constraints>('constraints', _constraints, missingIfNull: true));
    // don't access it via the "layer" getter since that's only valid when we don't need paint
    properties.add(DiagnosticsProperty<ContainerLayer>('layer', _layerHandle.layer, defaultValue: null));
    properties.add(DiagnosticsProperty<SemanticsNode>('semantics node', _semantics, defaultValue: null));
    properties.add(FlagProperty(
      'isBlockingSemanticsOfPreviouslyPaintedNodes',
      value: _semanticsConfiguration.isBlockingSemanticsOfPreviouslyPaintedNodes,
      ifTrue: 'blocks semantics of earlier render objects below the common boundary',
    ));
    properties.add(FlagProperty('isSemanticBoundary', value: _semanticsConfiguration.isSemanticBoundary, ifTrue: 'semantic boundary'));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => <DiagnosticsNode>[];

  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (parent is RenderObject) {
      parent!.showOnScreen(
        descendant: descendant ?? this,
        rect: rect,
        duration: duration,
        curve: curve,
      );
    }
  }

  DiagnosticsNode describeForError(String name, { DiagnosticsTreeStyle style = DiagnosticsTreeStyle.shallow }) {
    return toDiagnosticsNode(name: name, style: style);
  }
}

mixin RenderObjectWithChildMixin<ChildType extends RenderObject> on RenderObject {
  bool debugValidateChild(RenderObject child) {
    assert(() {
      if (child is! ChildType) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'A $runtimeType expected a child of type $ChildType but received a '
            'child of type ${child.runtimeType}.',
          ),
          ErrorDescription(
            'RenderObjects expect specific types of children because they '
            'coordinate with their children during layout and paint. For '
            'example, a RenderSliver cannot be the child of a RenderBox because '
            'a RenderSliver does not understand the RenderBox layout protocol.',
          ),
          ErrorSpacer(),
          DiagnosticsProperty<Object?>(
            'The $runtimeType that expected a $ChildType child was created by',
            debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          ErrorSpacer(),
          DiagnosticsProperty<Object?>(
            'The ${child.runtimeType} that did not match the expected child type '
            'was created by',
            child.debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  ChildType? _child;
  ChildType? get child => _child;
  set child(ChildType? value) {
    if (_child != null) {
      dropChild(_child!);
    }
    _child = value;
    if (_child != null) {
      adoptChild(_child!);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _child?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _child?.detach();
  }

  @override
  void redepthChildren() {
    if (_child != null) {
      redepthChild(_child!);
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return child != null ? <DiagnosticsNode>[child!.toDiagnosticsNode(name: 'child')] : <DiagnosticsNode>[];
  }
}

mixin ContainerParentDataMixin<ChildType extends RenderObject> on ParentData {
  ChildType? previousSibling;
  ChildType? nextSibling;

  @override
  void detach() {
    assert(previousSibling == null, 'Pointers to siblings must be nulled before detaching ParentData.');
    assert(nextSibling == null, 'Pointers to siblings must be nulled before detaching ParentData.');
    super.detach();
  }
}

mixin ContainerRenderObjectMixin<ChildType extends RenderObject, ParentDataType extends ContainerParentDataMixin<ChildType>> on RenderObject {
  bool _debugUltimatePreviousSiblingOf(ChildType child, { ChildType? equals }) {
    ParentDataType childParentData = child.parentData! as ParentDataType;
    while (childParentData.previousSibling != null) {
      assert(childParentData.previousSibling != child);
      child = childParentData.previousSibling!;
      childParentData = child.parentData! as ParentDataType;
    }
    return child == equals;
  }
  bool _debugUltimateNextSiblingOf(ChildType child, { ChildType? equals }) {
    ParentDataType childParentData = child.parentData! as ParentDataType;
    while (childParentData.nextSibling != null) {
      assert(childParentData.nextSibling != child);
      child = childParentData.nextSibling!;
      childParentData = child.parentData! as ParentDataType;
    }
    return child == equals;
  }

  int _childCount = 0;
  int get childCount => _childCount;

  bool debugValidateChild(RenderObject child) {
    assert(() {
      if (child is! ChildType) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'A $runtimeType expected a child of type $ChildType but received a '
            'child of type ${child.runtimeType}.',
          ),
          ErrorDescription(
            'RenderObjects expect specific types of children because they '
            'coordinate with their children during layout and paint. For '
            'example, a RenderSliver cannot be the child of a RenderBox because '
            'a RenderSliver does not understand the RenderBox layout protocol.',
          ),
          ErrorSpacer(),
          DiagnosticsProperty<Object?>(
            'The $runtimeType that expected a $ChildType child was created by',
            debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          ErrorSpacer(),
          DiagnosticsProperty<Object?>(
            'The ${child.runtimeType} that did not match the expected child type '
            'was created by',
            child.debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  ChildType? _firstChild;
  ChildType? _lastChild;
  void _insertIntoChildList(ChildType child, { ChildType? after }) {
    final ParentDataType childParentData = child.parentData! as ParentDataType;
    assert(childParentData.nextSibling == null);
    assert(childParentData.previousSibling == null);
    _childCount += 1;
    assert(_childCount > 0);
    if (after == null) {
      // insert at the start (_firstChild)
      childParentData.nextSibling = _firstChild;
      if (_firstChild != null) {
        final ParentDataType firstChildParentData = _firstChild!.parentData! as ParentDataType;
        firstChildParentData.previousSibling = child;
      }
      _firstChild = child;
      _lastChild ??= child;
    } else {
      assert(_firstChild != null);
      assert(_lastChild != null);
      assert(_debugUltimatePreviousSiblingOf(after, equals: _firstChild));
      assert(_debugUltimateNextSiblingOf(after, equals: _lastChild));
      final ParentDataType afterParentData = after.parentData! as ParentDataType;
      if (afterParentData.nextSibling == null) {
        // insert at the end (_lastChild); we'll end up with two or more children
        assert(after == _lastChild);
        childParentData.previousSibling = after;
        afterParentData.nextSibling = child;
        _lastChild = child;
      } else {
        // insert in the middle; we'll end up with three or more children
        // set up links from child to siblings
        childParentData.nextSibling = afterParentData.nextSibling;
        childParentData.previousSibling = after;
        // set up links from siblings to child
        final ParentDataType childPreviousSiblingParentData = childParentData.previousSibling!.parentData! as ParentDataType;
        final ParentDataType childNextSiblingParentData = childParentData.nextSibling!.parentData! as ParentDataType;
        childPreviousSiblingParentData.nextSibling = child;
        childNextSiblingParentData.previousSibling = child;
        assert(afterParentData.nextSibling == child);
      }
    }
  }

  void insert(ChildType child, { ChildType? after }) {
    assert(child != this, 'A RenderObject cannot be inserted into itself.');
    assert(after != this, 'A RenderObject cannot simultaneously be both the parent and the sibling of another RenderObject.');
    assert(child != after, 'A RenderObject cannot be inserted after itself.');
    assert(child != _firstChild);
    assert(child != _lastChild);
    adoptChild(child);
    _insertIntoChildList(child, after: after);
  }

  void add(ChildType child) {
    insert(child, after: _lastChild);
  }

  void addAll(List<ChildType>? children) {
    children?.forEach(add);
  }

  void _removeFromChildList(ChildType child) {
    final ParentDataType childParentData = child.parentData! as ParentDataType;
    assert(_debugUltimatePreviousSiblingOf(child, equals: _firstChild));
    assert(_debugUltimateNextSiblingOf(child, equals: _lastChild));
    assert(_childCount >= 0);
    if (childParentData.previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = childParentData.nextSibling;
    } else {
      final ParentDataType childPreviousSiblingParentData = childParentData.previousSibling!.parentData! as ParentDataType;
      childPreviousSiblingParentData.nextSibling = childParentData.nextSibling;
    }
    if (childParentData.nextSibling == null) {
      assert(_lastChild == child);
      _lastChild = childParentData.previousSibling;
    } else {
      final ParentDataType childNextSiblingParentData = childParentData.nextSibling!.parentData! as ParentDataType;
      childNextSiblingParentData.previousSibling = childParentData.previousSibling;
    }
    childParentData.previousSibling = null;
    childParentData.nextSibling = null;
    _childCount -= 1;
  }

  void remove(ChildType child) {
    _removeFromChildList(child);
    dropChild(child);
  }

  void removeAll() {
    ChildType? child = _firstChild;
    while (child != null) {
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      final ChildType? next = childParentData.nextSibling;
      childParentData.previousSibling = null;
      childParentData.nextSibling = null;
      dropChild(child);
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
    _childCount = 0;
  }

  void move(ChildType child, { ChildType? after }) {
    assert(child != this);
    assert(after != this);
    assert(child != after);
    assert(child.parent == this);
    final ParentDataType childParentData = child.parentData! as ParentDataType;
    if (childParentData.previousSibling == after) {
      return;
    }
    _removeFromChildList(child);
    _insertIntoChildList(child, after: after);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ChildType? child = _firstChild;
    while (child != null) {
      child.attach(owner);
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    ChildType? child = _firstChild;
    while (child != null) {
      child.detach();
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void redepthChildren() {
    ChildType? child = _firstChild;
    while (child != null) {
      redepthChild(child);
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    ChildType? child = _firstChild;
    while (child != null) {
      visitor(child);
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  ChildType? get firstChild => _firstChild;

  ChildType? get lastChild => _lastChild;

  ChildType? childBefore(ChildType child) {
    assert(child.parent == this);
    final ParentDataType childParentData = child.parentData! as ParentDataType;
    return childParentData.previousSibling;
  }

  ChildType? childAfter(ChildType child) {
    assert(child.parent == this);
    final ParentDataType childParentData = child.parentData! as ParentDataType;
    return childParentData.nextSibling;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (firstChild != null) {
      ChildType child = firstChild!;
      int count = 1;
      while (true) {
        children.add(child.toDiagnosticsNode(name: 'child $count'));
        if (child == lastChild) {
          break;
        }
        count += 1;
        final ParentDataType childParentData = child.parentData! as ParentDataType;
        child = childParentData.nextSibling!;
      }
    }
    return children;
  }
}

mixin RelayoutWhenSystemFontsChangeMixin on RenderObject {

  @protected
  @mustCallSuper
  void systemFontsDidChange() {
    markNeedsLayout();
  }

  bool _hasPendingSystemFontsDidChangeCallBack = false;
  void _scheduleSystemFontsUpdate() {
    assert(
      SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle,
      '${objectRuntimeType(this, "RelayoutWhenSystemFontsChangeMixin")}._scheduleSystemFontsUpdate() '
      'called during ${SchedulerBinding.instance.schedulerPhase}.',
    );
    if (_hasPendingSystemFontsDidChangeCallBack) {
      return;
    }
    _hasPendingSystemFontsDidChangeCallBack = true;
    SchedulerBinding.instance.scheduleFrameCallback((Duration timeStamp) {
      assert(_hasPendingSystemFontsDidChangeCallBack);
      _hasPendingSystemFontsDidChangeCallBack = false;
      assert(
        attached || (debugDisposed ?? true),
        '$this is detached during ${SchedulerBinding.instance.schedulerPhase} but is not disposed.',
      );
      if (attached) {
        systemFontsDidChange();
      }
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // If there's a pending callback that would imply this node was detached
    // between the idle phase and the next transientCallbacks phase. The tree
    // can not be mutated between those two phases so that should never happen.
    assert(!_hasPendingSystemFontsDidChangeCallBack);
    PaintingBinding.instance.systemFonts.addListener(_scheduleSystemFontsUpdate);
  }

  @override
  void detach() {
    assert(!_hasPendingSystemFontsDidChangeCallBack);
    PaintingBinding.instance.systemFonts.removeListener(_scheduleSystemFontsUpdate);
    super.detach();
  }
}

abstract class _SemanticsFragment {
  _SemanticsFragment({
    required this.dropsSemanticsOfPreviousSiblings,
  });

  void addAll(Iterable<_InterestingSemanticsFragment> fragments);

  final bool dropsSemanticsOfPreviousSiblings;

  List<_InterestingSemanticsFragment> get mergeUpFragments;
}

class _ContainerSemanticsFragment extends _SemanticsFragment {
  _ContainerSemanticsFragment({
    required super.dropsSemanticsOfPreviousSiblings,
    required this.siblingMergeGroups,
  });

  final List<List<_InterestingSemanticsFragment>> siblingMergeGroups;

  @override
  void addAll(Iterable<_InterestingSemanticsFragment> fragments) {
    mergeUpFragments.addAll(fragments);
  }

  @override
  final List<_InterestingSemanticsFragment> mergeUpFragments = <_InterestingSemanticsFragment>[];
}

abstract class _InterestingSemanticsFragment extends _SemanticsFragment {
  _InterestingSemanticsFragment({
    required RenderObject owner,
    required super.dropsSemanticsOfPreviousSiblings,
  }) : _ancestorChain = <RenderObject>[owner];

  RenderObject get owner => _ancestorChain.first;

  final List<RenderObject> _ancestorChain;

  void compileChildren({
    required Rect? parentSemanticsClipRect,
    required Rect? parentPaintClipRect,
    required double elevationAdjustment,
    required List<SemanticsNode> result,
    required List<SemanticsNode> siblingNodes,
  });

  SemanticsConfiguration? get config;

  void markAsExplicit();

  @override
  void addAll(Iterable<_InterestingSemanticsFragment> fragments);

  bool get hasConfigForParent => config != null;

  @override
  List<_InterestingSemanticsFragment> get mergeUpFragments => <_InterestingSemanticsFragment>[this];

  Set<SemanticsTag>? _tagsForChildren;

  void addTags(Iterable<SemanticsTag> tags) {
    assert(tags.isNotEmpty);
    _tagsForChildren ??= <SemanticsTag>{};
    _tagsForChildren!.addAll(tags);
  }

  void addAncestor(RenderObject ancestor) {
    _ancestorChain.add(ancestor);
  }
}

class _RootSemanticsFragment extends _InterestingSemanticsFragment {
  _RootSemanticsFragment({
    required super.owner,
    required super.dropsSemanticsOfPreviousSiblings,
  });

  @override
  void compileChildren({
    Rect? parentSemanticsClipRect,
    Rect? parentPaintClipRect,
    required double elevationAdjustment,
    required List<SemanticsNode> result,
    required List<SemanticsNode> siblingNodes,
  }) {
    assert(_tagsForChildren == null || _tagsForChildren!.isEmpty);
    assert(parentSemanticsClipRect == null);
    assert(parentPaintClipRect == null);
    assert(_ancestorChain.length == 1);
    assert(elevationAdjustment == 0.0);

    owner._semantics ??= SemanticsNode.root(
      showOnScreen: owner.showOnScreen,
      owner: owner.owner!.semanticsOwner!,
    );
    final SemanticsNode node = owner._semantics!;
    assert(MatrixUtils.matrixEquals(node.transform, Matrix4.identity()));
    assert(node.parentSemanticsClipRect == null);
    assert(node.parentPaintClipRect == null);

    node.rect = owner.semanticBounds;

    final List<SemanticsNode> children = <SemanticsNode>[];
    for (final _InterestingSemanticsFragment fragment in _children) {
      assert(fragment.config == null);
      fragment.compileChildren(
        parentSemanticsClipRect: parentSemanticsClipRect,
        parentPaintClipRect: parentPaintClipRect,
        elevationAdjustment: 0.0,
        result: children,
        siblingNodes: siblingNodes,
      );
    }
    // Root node does not have a parent and thus can't attach sibling nodes.
    assert(siblingNodes.isEmpty);
    node.updateWith(config: null, childrenInInversePaintOrder: children);

    // The root node is the only semantics node allowed to be invisible. This
    // can happen when the canvas the app is drawn on has a size of 0 by 0
    // pixel. If this happens, the root node must not have any children (because
    // these would be invisible as well and are therefore excluded from the
    // tree).
    assert(!node.isInvisible || children.isEmpty);
    result.add(node);
  }

  @override
  SemanticsConfiguration? get config => null;

  final List<_InterestingSemanticsFragment> _children = <_InterestingSemanticsFragment>[];

  @override
  void markAsExplicit() {
    // nothing to do, we are always explicit.
  }

  @override
  void addAll(Iterable<_InterestingSemanticsFragment> fragments) {
    _children.addAll(fragments);
  }
}

class _IncompleteSemanticsFragment extends _InterestingSemanticsFragment {
  _IncompleteSemanticsFragment({
    required this.config,
    required super.owner,
  }) : super(dropsSemanticsOfPreviousSiblings: false);

  @override
  void addAll(Iterable<_InterestingSemanticsFragment> fragments) {
    assert(false, 'This fragment must be a leaf node');
  }

  @override
  void compileChildren({
    required Rect? parentSemanticsClipRect,
    required Rect? parentPaintClipRect,
    required double elevationAdjustment,
    required List<SemanticsNode> result,
    required List<SemanticsNode> siblingNodes,
  }) {
    // There is nothing to do because this fragment must be a leaf node and
    // must not be explicit.
  }

  @override
  final SemanticsConfiguration config;

  @override
  void markAsExplicit() {
    assert(
      false,
      'SemanticsConfiguration created in '
      'SemanticsConfiguration.childConfigurationsDelegate must not produce '
      'its own semantics node'
    );
  }
}

class _SwitchableSemanticsFragment extends _InterestingSemanticsFragment {
  _SwitchableSemanticsFragment({
    required bool mergeIntoParent,
    required bool blockUserActions,
    required SemanticsConfiguration config,
    required List<List<_InterestingSemanticsFragment>> siblingMergeGroups,
    required super.owner,
    required super.dropsSemanticsOfPreviousSiblings,
  }) : _siblingMergeGroups = siblingMergeGroups,
       _mergeIntoParent = mergeIntoParent,
       _config = config {
    if (blockUserActions && !_config.isBlockingUserActions) {
      _ensureConfigIsWritable();
      _config.isBlockingUserActions = true;
    }
  }

  final bool _mergeIntoParent;
  SemanticsConfiguration _config;
  bool _isConfigWritable = false;
  bool _mergesToSibling = false;

  final List<List<_InterestingSemanticsFragment>> _siblingMergeGroups;

  void _mergeSiblingGroup(Rect? parentSemanticsClipRect, Rect? parentPaintClipRect, List<SemanticsNode> result, Set<int> usedSemanticsIds) {
    for (final List<_InterestingSemanticsFragment> group in _siblingMergeGroups) {
      Rect? rect;
      Rect? semanticsClipRect;
      Rect? paintClipRect;
      SemanticsConfiguration? configuration;
      // Use empty set because the _tagsForChildren may not contains all of the
      // tags if this fragment is not explicit. The _tagsForChildren are added
      // to sibling nodes at the end of compileChildren if this fragment is
      // explicit.
      final Set<SemanticsTag> tags = <SemanticsTag>{};
      SemanticsNode? node;
      for (final _InterestingSemanticsFragment fragment in group) {
        if (fragment.config != null) {
          final _SwitchableSemanticsFragment switchableFragment = fragment as _SwitchableSemanticsFragment;
          switchableFragment._mergesToSibling = true;
          node ??= fragment.owner._semantics;
          configuration ??= SemanticsConfiguration();
          configuration.absorb(switchableFragment.config!);
          // It is a child fragment of a _SwitchableFragment, it must have a
          // geometry.
          final _SemanticsGeometry geometry = switchableFragment._computeSemanticsGeometry(
            parentSemanticsClipRect: parentSemanticsClipRect,
            parentPaintClipRect: parentPaintClipRect,
          )!;
          final Rect fragmentRect = MatrixUtils.transformRect(geometry.transform, geometry.rect);
          if (rect == null) {
            rect = fragmentRect;
          } else {
            rect = rect.expandToInclude(fragmentRect);
          }
          if (geometry.semanticsClipRect != null) {
            final Rect rect = MatrixUtils.transformRect(geometry.transform, geometry.semanticsClipRect!);
            if (semanticsClipRect == null) {
              semanticsClipRect = rect;
            } else {
              semanticsClipRect = semanticsClipRect.intersect(rect);
            }
          }
          if (geometry.paintClipRect != null) {
            final Rect rect = MatrixUtils.transformRect(geometry.transform, geometry.paintClipRect!);
            if (paintClipRect == null) {
              paintClipRect = rect;
            } else {
              paintClipRect = paintClipRect.intersect(rect);
            }
          }
          if (switchableFragment._tagsForChildren != null) {
            tags.addAll(switchableFragment._tagsForChildren!);
          }
        }
      }
      // Can be null if all fragments in group are marked as explicit.
      if (configuration != null && !rect!.isEmpty) {
        if (node == null || usedSemanticsIds.contains(node.id)) {
          node = SemanticsNode(showOnScreen: owner.showOnScreen);
        }
        usedSemanticsIds.add(node.id);
        node
          ..tags = tags
          ..rect = rect
          ..transform = null // Will be set when compiling immediate parent node.
          ..parentSemanticsClipRect = semanticsClipRect
          ..parentPaintClipRect = paintClipRect;
        for (final _InterestingSemanticsFragment fragment in group) {
          if (fragment.config != null) {
            fragment.owner._semantics = node;
          }
        }
        node.updateWith(config: configuration);
        result.add(node);
      }
    }
  }

  final List<_InterestingSemanticsFragment> _children = <_InterestingSemanticsFragment>[];

  @override
  void compileChildren({
    Rect? parentSemanticsClipRect,
    Rect? parentPaintClipRect,
    required double elevationAdjustment,
    required List<SemanticsNode> result,
    required List<SemanticsNode> siblingNodes,
  }) {
    final Set<int> usedSemanticsIds = <int>{};
    Iterable<_InterestingSemanticsFragment> compilingFragments = _children;
    for (final List<_InterestingSemanticsFragment> siblingGroup in _siblingMergeGroups) {
      compilingFragments = compilingFragments.followedBy(siblingGroup);
    }
    if (!_isExplicit) {
      if (!_mergesToSibling) {
        owner._semantics = null;
      }
      _mergeSiblingGroup(
        parentSemanticsClipRect,
        parentPaintClipRect,
        siblingNodes,
        usedSemanticsIds,
      );
      for (final _InterestingSemanticsFragment fragment in compilingFragments) {
        assert(_ancestorChain.first == fragment._ancestorChain.last);
        if (fragment is _SwitchableSemanticsFragment) {
          // Cached semantics node may be part of sibling merging group prior
          // to this update. In this case, the semantics node may continue to
          // be reused in that sibling merging group.
          if (fragment._isExplicit &&
              fragment.owner._semantics != null &&
              usedSemanticsIds.contains(fragment.owner._semantics!.id)) {
            fragment.owner._semantics = null;
          }
        }
        fragment._ancestorChain.addAll(_ancestorChain.skip(1));
        fragment.compileChildren(
          parentSemanticsClipRect: parentSemanticsClipRect,
          parentPaintClipRect: parentPaintClipRect,
          // The fragment is not explicit, its elevation has been absorbed by
          // the parent config (as thickness). We still need to make sure that
          // its children are placed at the elevation dictated by this config.
          elevationAdjustment: elevationAdjustment + _config.elevation,
          result: result,
          siblingNodes: siblingNodes,
        );
      }
      return;
    }

    final _SemanticsGeometry? geometry = _computeSemanticsGeometry(
      parentSemanticsClipRect: parentSemanticsClipRect,
      parentPaintClipRect: parentPaintClipRect,
    );

    if (!_mergeIntoParent && (geometry?.dropFromTree ?? false)) {
      return; // Drop the node, it's not going to be visible.
    }

    owner._semantics ??= SemanticsNode(showOnScreen: owner.showOnScreen);
    final SemanticsNode node = owner._semantics!
      ..isMergedIntoParent = _mergeIntoParent
      ..tags = _tagsForChildren;

    node.elevationAdjustment = elevationAdjustment;
    if (elevationAdjustment != 0.0) {
      _ensureConfigIsWritable();
      _config.elevation += elevationAdjustment;
    }

    if (geometry != null) {
      assert(_needsGeometryUpdate);
      node
        ..rect = geometry.rect
        ..transform = geometry.transform
        ..parentSemanticsClipRect = geometry.semanticsClipRect
        ..parentPaintClipRect = geometry.paintClipRect;
      if (!_mergeIntoParent && geometry.markAsHidden) {
        _ensureConfigIsWritable();
        _config.isHidden = true;
      }
    }
    final List<SemanticsNode> children = <SemanticsNode>[];
    _mergeSiblingGroup(
      node.parentSemanticsClipRect,
      node.parentPaintClipRect,
      siblingNodes,
      usedSemanticsIds,
    );
    for (final _InterestingSemanticsFragment fragment in compilingFragments) {
      if (fragment is _SwitchableSemanticsFragment) {
        // Cached semantics node may be part of sibling merging group prior
        // to this update. In this case, the semantics node may continue to
        // be reused in that sibling merging group.
        if (fragment._isExplicit &&
            fragment.owner._semantics != null &&
            usedSemanticsIds.contains(fragment.owner._semantics!.id)) {
          fragment.owner._semantics = null;
        }
      }
      final List<SemanticsNode> childSiblingNodes = <SemanticsNode>[];
      fragment.compileChildren(
        parentSemanticsClipRect: node.parentSemanticsClipRect,
        parentPaintClipRect: node.parentPaintClipRect,
        elevationAdjustment: 0.0,
        result: children,
        siblingNodes: childSiblingNodes,
      );
      siblingNodes.addAll(childSiblingNodes);
    }

    if (_config.isSemanticBoundary) {
      owner.assembleSemanticsNode(node, _config, children);
    } else {
      node.updateWith(config: _config, childrenInInversePaintOrder: children);
    }
    result.add(node);
    // Sibling node needs to attach to the parent of an explicit node.
    for (final SemanticsNode siblingNode in siblingNodes) {
      // sibling nodes are in the same coordinate of the immediate explicit node.
      // They need to share the same transform if they are going to attach to the
      // parent of the immediate explicit node.
      assert(siblingNode.transform == null);
      siblingNode
        ..transform = node.transform
        ..isMergedIntoParent = node.isMergedIntoParent;
      if (_tagsForChildren != null) {
        siblingNode.tags ??= <SemanticsTag>{};
        siblingNode.tags!.addAll(_tagsForChildren!);
      }
    }
    result.addAll(siblingNodes);
    siblingNodes.clear();
  }

  _SemanticsGeometry? _computeSemanticsGeometry({
    required Rect? parentSemanticsClipRect,
    required Rect? parentPaintClipRect,
  }) {
    return _needsGeometryUpdate
      ? _SemanticsGeometry(parentSemanticsClipRect: parentSemanticsClipRect, parentPaintClipRect: parentPaintClipRect, ancestors: _ancestorChain)
      : null;
  }

  @override
  SemanticsConfiguration? get config {
    return _isExplicit ? null : _config;
  }

  @override
  void addAll(Iterable<_InterestingSemanticsFragment> fragments) {
    for (final _InterestingSemanticsFragment fragment in fragments) {
      _children.add(fragment);
      if (fragment.config == null) {
        continue;
      }
      _ensureConfigIsWritable();
      _config.absorb(fragment.config!);
    }
  }

  @override
  void addTags(Iterable<SemanticsTag> tags) {
    super.addTags(tags);
    // _ContainerSemanticsFragments add their tags to child fragments through
    // this method. This fragment must make sure its _config is in sync.
    if (tags.isNotEmpty) {
      _ensureConfigIsWritable();
      tags.forEach(_config.addTagForChildren);
    }
  }

  void _ensureConfigIsWritable() {
    if (!_isConfigWritable) {
      _config = _config.copy();
      _isConfigWritable = true;
    }
  }

  bool _isExplicit = false;

  @override
  void markAsExplicit() {
    _isExplicit = true;
  }

  bool get _needsGeometryUpdate => _ancestorChain.length > 1;
}

class _SemanticsGeometry {

  _SemanticsGeometry({
    required Rect? parentSemanticsClipRect,
    required Rect? parentPaintClipRect,
    required List<RenderObject> ancestors,
  }) {
    _computeValues(parentSemanticsClipRect, parentPaintClipRect, ancestors);
  }

  Rect? _paintClipRect;
  Rect? _semanticsClipRect;
  late Matrix4 _transform;
  late Rect _rect;

  Matrix4 get transform => _transform;

  Rect? get semanticsClipRect => _semanticsClipRect;

  Rect? get paintClipRect => _paintClipRect;

  Rect get rect => _rect;

  void _computeValues(Rect? parentSemanticsClipRect, Rect? parentPaintClipRect, List<RenderObject> ancestors) {
    assert(ancestors.length > 1);

    _transform = Matrix4.identity();
    _semanticsClipRect = parentSemanticsClipRect;
    _paintClipRect = parentPaintClipRect;
    for (int index = ancestors.length-1; index > 0; index -= 1) {
      final RenderObject parent = ancestors[index];
      final RenderObject child = ancestors[index-1];
      final Rect? parentSemanticsClipRect = parent.describeSemanticsClip(child);
      if (parentSemanticsClipRect != null) {
        _semanticsClipRect = parentSemanticsClipRect;
        _paintClipRect = _intersectRects(_paintClipRect, parent.describeApproximatePaintClip(child));
      } else {
        _semanticsClipRect = _intersectRects(_semanticsClipRect, parent.describeApproximatePaintClip(child));
      }
      _temporaryTransformHolder.setIdentity(); // clears data from previous call(s)
      _applyIntermediatePaintTransforms(parent, child, _transform, _temporaryTransformHolder);
      _semanticsClipRect = _transformRect(_semanticsClipRect, _temporaryTransformHolder);
      _paintClipRect = _transformRect(_paintClipRect, _temporaryTransformHolder);
    }

    final RenderObject owner = ancestors.first;
    _rect = _semanticsClipRect == null ? owner.semanticBounds : _semanticsClipRect!.intersect(owner.semanticBounds);
    if (_paintClipRect != null) {
      final Rect paintRect = _paintClipRect!.intersect(_rect);
      _markAsHidden = paintRect.isEmpty && !_rect.isEmpty;
      if (!_markAsHidden) {
        _rect = paintRect;
      }
    }
  }

  // A matrix used to store transient transform data.
  //
  // Reusing this matrix avoids allocating a new matrix every time a temporary
  // matrix is needed.
  //
  // This instance should never be returned to the caller. Otherwise, the data
  // stored in it will be overwritten unpredictably by subsequent reuses.
  static final Matrix4 _temporaryTransformHolder = Matrix4.zero();

  static Rect? _transformRect(Rect? rect, Matrix4 transform) {
    if (rect == null) {
      return null;
    }
    if (rect.isEmpty || transform.isZero()) {
      return Rect.zero;
    }
    return MatrixUtils.inverseTransformRect(transform, rect);
  }

  // Calls applyPaintTransform on all of the render objects between [child] and
  // [ancestor]. This method handles cases where the immediate semantic parent
  // is not the immediate render object parent of the child.
  //
  // It will mutate both transform and clipRectTransform.
  static void _applyIntermediatePaintTransforms(
    RenderObject ancestor,
    RenderObject child,
    Matrix4 transform,
    Matrix4 clipRectTransform,
  ) {
    assert(clipRectTransform.isIdentity());
    RenderObject intermediateParent = child.parent!;
    while (intermediateParent != ancestor) {
      intermediateParent.applyPaintTransform(child, transform);
      intermediateParent = intermediateParent.parent!;
      child = child.parent!;
    }
    ancestor.applyPaintTransform(child, transform);
    ancestor.applyPaintTransform(child, clipRectTransform);
  }

  static Rect? _intersectRects(Rect? a, Rect? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.intersect(b);
  }

  bool get dropFromTree {
    return _rect.isEmpty || _transform.isZero();
  }

  bool get markAsHidden => _markAsHidden;
  bool _markAsHidden = false;
}

class DiagnosticsDebugCreator extends DiagnosticsProperty<Object> {
  DiagnosticsDebugCreator(Object value)
    : super(
        'debugCreator',
        value,
        level: DiagnosticLevel.hidden,
      );
}