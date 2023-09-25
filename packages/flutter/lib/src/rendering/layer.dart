// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart';

import 'debug.dart';

@immutable
class AnnotationEntry<T> {
  const AnnotationEntry({
    required this.annotation,
    required this.localPosition,
  });

  final T annotation;

  final Offset localPosition;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'AnnotationEntry')}(annotation: $annotation, localPosition: $localPosition)';
  }
}

class AnnotationResult<T> {
  final List<AnnotationEntry<T>> _entries = <AnnotationEntry<T>>[];

  void add(AnnotationEntry<T> entry) => _entries.add(entry);

  Iterable<AnnotationEntry<T>> get entries => _entries;

  Iterable<T> get annotations {
    return _entries.map((AnnotationEntry<T> entry) => entry.annotation);
  }
}

const String _flutterRenderingLibrary = 'package:flutter/rendering.dart';

abstract class Layer with DiagnosticableTreeMixin {
  Layer() {
    if (kFlutterMemoryAllocationsEnabled) {
      MemoryAllocations.instance.dispatchObjectCreated(
        library: _flutterRenderingLibrary,
        className: '$Layer',
        object: this,
      );
    }
  }

  final Map<int, VoidCallback> _callbacks = <int, VoidCallback>{};
  static int _nextCallbackId = 0;

  bool get subtreeHasCompositionCallbacks => _compositionCallbackCount > 0;

  int _compositionCallbackCount = 0;
  void _updateSubtreeCompositionObserverCount(int delta) {
    assert(delta != 0);
    _compositionCallbackCount += delta;
    assert(_compositionCallbackCount >= 0);
    parent?._updateSubtreeCompositionObserverCount(delta);
  }

  void _fireCompositionCallbacks({required bool includeChildren}) {
    if (_callbacks.isEmpty) {
      return;
    }
    for (final VoidCallback callback in List<VoidCallback>.of(_callbacks.values)) {
      callback();
    }
  }

  bool _debugMutationsLocked = false;

  bool supportsRasterization() {
    return true;
  }

  Rect? describeClipBounds() => null;

  VoidCallback addCompositionCallback(CompositionCallback callback) {
    _updateSubtreeCompositionObserverCount(1);
    final int callbackId = _nextCallbackId += 1;
    _callbacks[callbackId] = () {
      assert(() {
        _debugMutationsLocked = true;
        return true;
      }());
      callback(this);
      assert(() {
        _debugMutationsLocked = false;
        return true;
      }());
    };
    return () {
      assert(debugDisposed || _callbacks.containsKey(callbackId));
      _callbacks.remove(callbackId);
      _updateSubtreeCompositionObserverCount(-1);
    };
  }

  bool get debugDisposed {
    late bool disposed;
    assert(() {
      disposed = _debugDisposed;
      return true;
    }());
    return disposed;
  }
  bool _debugDisposed = false;

  final LayerHandle<Layer> _parentHandle = LayerHandle<Layer>();

  int _refCount = 0;

  void _unref() {
    assert(!_debugMutationsLocked);
    assert(_refCount > 0);
    _refCount -= 1;
    if (_refCount == 0) {
      dispose();
    }
  }

  int get debugHandleCount {
    late int count;
    assert(() {
      count = _refCount;
      return true;
    }());
    return count;
  }

  @mustCallSuper
  @protected
  @visibleForTesting
  void dispose() {
    assert(!_debugMutationsLocked);
    assert(
      !_debugDisposed,
      'Layers must only be disposed once. This is typically handled by '
      'LayerHandle and createHandle. Subclasses should not directly call '
      'dispose, except to call super.dispose() in an overridden dispose  '
      'method. Tests must only call dispose once.',
    );
    assert(() {
      assert(
        _refCount == 0,
        'Do not directly call dispose on a $runtimeType. Instead, '
        'use createHandle and LayerHandle.dispose.',
      );
      _debugDisposed = true;
      return true;
    }());
    if (kFlutterMemoryAllocationsEnabled) {
      MemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }
    _engineLayer?.dispose();
    _engineLayer = null;
  }

  ContainerLayer? get parent => _parent;
  ContainerLayer? _parent;

  // Whether this layer has any changes since its last call to [addToScene].
  //
  // Initialized to true as a new layer has never called [addToScene], and is
  // set to false after calling [addToScene]. The value can become true again
  // if [markNeedsAddToScene] is called, or when [updateSubtreeNeedsAddToScene]
  // is called on this layer or on an ancestor layer.
  //
  // The values of [_needsAddToScene] in a tree of layers are said to be
  // _consistent_ if every layer in the tree satisfies the following:
  //
  // - If [alwaysNeedsAddToScene] is true, then [_needsAddToScene] is also true.
  // - If [_needsAddToScene] is true and [parent] is not null, then
  //   `parent._needsAddToScene` is true.
  //
  // Typically, this value is set during the paint phase and during compositing.
  // During the paint phase render objects create new layers and call
  // [markNeedsAddToScene] on existing layers, causing this value to become
  // true. After the paint phase the tree may be in an inconsistent state.
  // During compositing [ContainerLayer.buildScene] first calls
  // [updateSubtreeNeedsAddToScene] to bring this tree to a consistent state,
  // then it calls [addToScene], and finally sets this field to false.
  bool _needsAddToScene = true;

  @protected
  @visibleForTesting
  void markNeedsAddToScene() {
    assert(!_debugMutationsLocked);
    assert(
      !alwaysNeedsAddToScene,
      '$runtimeType with alwaysNeedsAddToScene set called markNeedsAddToScene.\n'
      "The layer's alwaysNeedsAddToScene is set to true, and therefore it should not call markNeedsAddToScene.",
    );
    assert(!_debugDisposed);

    // Already marked. Short-circuit.
    if (_needsAddToScene) {
      return;
    }

    _needsAddToScene = true;
  }

  @visibleForTesting
  void debugMarkClean() {
    assert(!_debugMutationsLocked);
    assert(() {
      _needsAddToScene = false;
      return true;
    }());
  }

  @protected
  bool get alwaysNeedsAddToScene => false;

  @visibleForTesting
  bool? get debugSubtreeNeedsAddToScene {
    bool? result;
    assert(() {
      result = _needsAddToScene;
      return true;
    }());
    return result;
  }

  @protected
  @visibleForTesting
  ui.EngineLayer? get engineLayer => _engineLayer;

  @protected
  @visibleForTesting
  set engineLayer(ui.EngineLayer? value) {
    assert(!_debugMutationsLocked);
    assert(!_debugDisposed);

    _engineLayer?.dispose();
    _engineLayer = value;
    if (!alwaysNeedsAddToScene) {
      // The parent must construct a new engine layer to add this layer to, and
      // so we mark it as needing [addToScene].
      //
      // This is designed to handle two situations:
      //
      // 1. When rendering the complete layer tree as normal. In this case we
      // call child `addToScene` methods first, then we call `set engineLayer`
      // for the parent. The children will call `markNeedsAddToScene` on the
      // parent to signal that they produced new engine layers and therefore
      // the parent needs to update. In this case, the parent is already adding
      // itself to the scene via [addToScene], and so after it's done, its
      // `set engineLayer` is called and it clears the `_needsAddToScene` flag.
      //
      // 2. When rendering an interior layer (e.g. `OffsetLayer.toImage`). In
      // this case we call `addToScene` for one of the children but not the
      // parent, i.e. we produce new engine layers for children but not for the
      // parent. Here the children will mark the parent as needing
      // `addToScene`, but the parent does not clear the flag until some future
      // frame decides to render it, at which point the parent knows that it
      // cannot retain its engine layer and will call `addToScene` again.
      if (parent != null && !parent!.alwaysNeedsAddToScene) {
        parent!.markNeedsAddToScene();
      }
    }
  }
  ui.EngineLayer? _engineLayer;

  @protected
  @visibleForTesting
  void updateSubtreeNeedsAddToScene() {
    assert(!_debugMutationsLocked);
    _needsAddToScene = _needsAddToScene || alwaysNeedsAddToScene;
  }

  Object? get owner => _owner;
  Object? _owner;

  bool get attached => _owner != null;

  @mustCallSuper
  void attach(covariant Object owner) {
    assert(_owner == null);
    _owner = owner;
  }

  @mustCallSuper
  void detach() {
    assert(_owner != null);
    _owner = null;
    assert(parent == null || attached == parent!.attached);
  }

  int get depth => _depth;
  int _depth = 0;

  @protected
  void redepthChildren() {
    // ContainerLayer provides an implementation since its the only one that
    // can actually have children.
  }

  Layer? get nextSibling => _nextSibling;
  Layer? _nextSibling;

  Layer? get previousSibling => _previousSibling;
  Layer? _previousSibling;

  @mustCallSuper
  void remove() {
    assert(!_debugMutationsLocked);
    parent?._removeChild(this);
  }

  @protected
  bool findAnnotations<S extends Object>(
    AnnotationResult<S> result,
    Offset localPosition, {
    required bool onlyFirst,
  }) {
    return false;
  }

  S? find<S extends Object>(Offset localPosition) {
    final AnnotationResult<S> result = AnnotationResult<S>();
    findAnnotations<S>(result, localPosition, onlyFirst: true);
    return result.entries.isEmpty ? null : result.entries.first.annotation;
  }

  AnnotationResult<S> findAllAnnotations<S extends Object>(Offset localPosition) {
    final AnnotationResult<S> result = AnnotationResult<S>();
    findAnnotations<S>(result, localPosition, onlyFirst: false);
    return result;
  }

  @protected
  void addToScene(ui.SceneBuilder builder);

  void _addToSceneWithRetainedRendering(ui.SceneBuilder builder) {
    assert(!_debugMutationsLocked);
    // There can't be a loop by adding a retained layer subtree whose
    // _needsAddToScene is false.
    //
    // Proof by contradiction:
    //
    // If we introduce a loop, this retained layer must be appended to one of
    // its descendant layers, say A. That means the child structure of A has
    // changed so A's _needsAddToScene is true. This contradicts
    // _needsAddToScene being false.
    if (!_needsAddToScene && _engineLayer != null) {
      builder.addRetained(_engineLayer!);
      return;
    }
    addToScene(builder);
    // Clearing the flag _after_ calling `addToScene`, not _before_. This is
    // because `addToScene` calls children's `addToScene` methods, which may
    // mark this layer as dirty.
    _needsAddToScene = false;
  }

  Object? debugCreator;

  @override
  String toStringShort() => '${super.toStringShort()}${ owner == null ? " DETACHED" : ""}';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('owner', owner, level: parent != null ? DiagnosticLevel.hidden : DiagnosticLevel.info, defaultValue: null));
    properties.add(DiagnosticsProperty<Object?>('creator', debugCreator, defaultValue: null, level: DiagnosticLevel.debug));
    if (_engineLayer != null) {
      properties.add(DiagnosticsProperty<String>('engine layer', describeIdentity(_engineLayer)));
    }
    properties.add(DiagnosticsProperty<int>('handles', debugHandleCount));
  }
}

class LayerHandle<T extends Layer> {
  LayerHandle([this._layer]) {
    if (_layer != null) {
      _layer!._refCount += 1;
    }
  }

  T? _layer;

  T? get layer => _layer;

  set layer(T? layer) {
    assert(
      layer?.debugDisposed != true,
      'Attempted to create a handle to an already disposed layer: $layer.',
    );
    if (identical(layer, _layer)) {
      return;
    }
    _layer?._unref();
    _layer = layer;
    if (_layer != null) {
      _layer!._refCount += 1;
    }
  }

  @override
  String toString() => 'LayerHandle(${_layer != null ? _layer.toString() : 'DISPOSED'})';
}

class PictureLayer extends Layer {
  PictureLayer(this.canvasBounds);

  final Rect canvasBounds;

  ui.Picture? get picture => _picture;
  ui.Picture? _picture;
  set picture(ui.Picture? picture) {
    assert(!_debugDisposed);
    markNeedsAddToScene();
    _picture?.dispose();
    _picture = picture;
  }

  bool get isComplexHint => _isComplexHint;
  bool _isComplexHint = false;
  set isComplexHint(bool value) {
    if (value != _isComplexHint) {
      _isComplexHint = value;
      markNeedsAddToScene();
    }
  }

  bool get willChangeHint => _willChangeHint;
  bool _willChangeHint = false;
  set willChangeHint(bool value) {
    if (value != _willChangeHint) {
      _willChangeHint = value;
      markNeedsAddToScene();
    }
  }

  @override
  void dispose() {
    picture = null; // Will dispose _picture.
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(picture != null);
    builder.addPicture(Offset.zero, picture!, isComplexHint: isComplexHint, willChangeHint: willChangeHint);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('paint bounds', canvasBounds));
    properties.add(DiagnosticsProperty<String>('picture', describeIdentity(_picture)));
    properties.add(DiagnosticsProperty<String>(
      'raster cache hints',
      'isComplex = $isComplexHint, willChange = $willChangeHint',
    ));
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return false;
  }
}

class TextureLayer extends Layer {
  TextureLayer({
    required this.rect,
    required this.textureId,
    this.freeze = false,
    this.filterQuality = ui.FilterQuality.low,
  });

  final Rect rect;

  final int textureId;

  final bool freeze;

  final ui.FilterQuality filterQuality;

  @override
  void addToScene(ui.SceneBuilder builder) {
    builder.addTexture(
      textureId,
      offset: rect.topLeft,
      width: rect.width,
      height: rect.height,
      freeze: freeze,
      filterQuality: filterQuality,
    );
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return false;
  }
}

class PlatformViewLayer extends Layer {
  PlatformViewLayer({
    required this.rect,
    required this.viewId,
  });

  final Rect rect;

  final int viewId;

  @override
  bool supportsRasterization() {
    return false;
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    builder.addPlatformView(
      viewId,
      offset: rect.topLeft,
      width: rect.width,
      height: rect.height,
    );
  }
}

class PerformanceOverlayLayer extends Layer {
  PerformanceOverlayLayer({
    required Rect overlayRect,
    required this.optionsMask,
    required this.rasterizerThreshold,
    required this.checkerboardRasterCacheImages,
    required this.checkerboardOffscreenLayers,
  }) : _overlayRect = overlayRect;

  Rect get overlayRect => _overlayRect;
  Rect _overlayRect;
  set overlayRect(Rect value) {
    if (value != _overlayRect) {
      _overlayRect = value;
      markNeedsAddToScene();
    }
  }

  final int optionsMask;

  final int rasterizerThreshold;

  final bool checkerboardRasterCacheImages;

  final bool checkerboardOffscreenLayers;

  @override
  void addToScene(ui.SceneBuilder builder) {
    builder.addPerformanceOverlay(optionsMask, overlayRect);
    builder.setRasterizerTracingThreshold(rasterizerThreshold);
    builder.setCheckerboardRasterCacheImages(checkerboardRasterCacheImages);
    builder.setCheckerboardOffscreenLayers(checkerboardOffscreenLayers);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return false;
  }
}

typedef CompositionCallback = void Function(Layer);

class ContainerLayer extends Layer {
  @override
  void _fireCompositionCallbacks({required bool includeChildren}) {
    super._fireCompositionCallbacks(includeChildren: includeChildren);
    if (!includeChildren) {
      return;
    }
    Layer? child = firstChild;
    while (child != null) {
      child._fireCompositionCallbacks(includeChildren: includeChildren);
      child = child.nextSibling;
    }
  }

  Layer? get firstChild => _firstChild;
  Layer? _firstChild;

  Layer? get lastChild => _lastChild;
  Layer? _lastChild;

  bool get hasChildren => _firstChild != null;

  @override
  bool supportsRasterization() {
    for (Layer? child = lastChild; child != null; child = child.previousSibling) {
      if (!child.supportsRasterization()) {
        return false;
      }
    }
    return true;
  }

  // The reason this method is in the `ContainerLayer` class rather than
  // `PipelineOwner` or other singleton level is because this method can be used
  // both to render the whole layer tree (e.g. a normal application frame) and
  // to render a subtree (e.g. `OffsetLayer.toImage`).
  ui.Scene buildScene(ui.SceneBuilder builder) {
    updateSubtreeNeedsAddToScene();
    addToScene(builder);
    if (subtreeHasCompositionCallbacks) {
      _fireCompositionCallbacks(includeChildren: true);
    }
    // Clearing the flag _after_ calling `addToScene`, not _before_. This is
    // because `addToScene` calls children's `addToScene` methods, which may
    // mark this layer as dirty.
    _needsAddToScene = false;
    final ui.Scene scene = builder.build();
    return scene;
  }

  bool _debugUltimatePreviousSiblingOf(Layer child, { Layer? equals }) {
    assert(child.attached == attached);
    while (child.previousSibling != null) {
      assert(child.previousSibling != child);
      child = child.previousSibling!;
      assert(child.attached == attached);
    }
    return child == equals;
  }

  bool _debugUltimateNextSiblingOf(Layer child, { Layer? equals }) {
    assert(child.attached == attached);
    while (child._nextSibling != null) {
      assert(child._nextSibling != child);
      child = child._nextSibling!;
      assert(child.attached == attached);
    }
    return child == equals;
  }

  @override
  void dispose() {
    removeAllChildren();
    _callbacks.clear();
    super.dispose();
  }

  @override
  void updateSubtreeNeedsAddToScene() {
    super.updateSubtreeNeedsAddToScene();
    Layer? child = firstChild;
    while (child != null) {
      child.updateSubtreeNeedsAddToScene();
      _needsAddToScene = _needsAddToScene || child._needsAddToScene;
      child = child.nextSibling;
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    for (Layer? child = lastChild; child != null; child = child.previousSibling) {
      final bool isAbsorbed = child.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
      if (isAbsorbed) {
        return true;
      }
      if (onlyFirst && result.entries.isNotEmpty) {
        return isAbsorbed;
      }
    }
    return false;
  }

  @override
  void attach(Object owner) {
    assert(!_debugMutationsLocked);
    super.attach(owner);
    Layer? child = firstChild;
    while (child != null) {
      child.attach(owner);
      child = child.nextSibling;
    }
  }

  @override
  void detach() {
    assert(!_debugMutationsLocked);
    super.detach();
    Layer? child = firstChild;
    while (child != null) {
      child.detach();
      child = child.nextSibling;
    }
    // Detach indicates that we may never be composited again. Clients
    // interested in observing composition need to get an update here because
    // they might otherwise never get another one even though the layer is no
    // longer visible.
    //
    // Children fired them already in child.detach().
    _fireCompositionCallbacks(includeChildren: false);
  }

  void append(Layer child) {
    assert(!_debugMutationsLocked);
    assert(child != this);
    assert(child != firstChild);
    assert(child != lastChild);
    assert(child.parent == null);
    assert(!child.attached);
    assert(child.nextSibling == null);
    assert(child.previousSibling == null);
    assert(child._parentHandle.layer == null);
    assert(() {
      Layer node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    _adoptChild(child);
    child._previousSibling = lastChild;
    if (lastChild != null) {
      lastChild!._nextSibling = child;
    }
    _lastChild = child;
    _firstChild ??= child;
    child._parentHandle.layer = child;
    assert(child.attached == attached);
  }

  void _adoptChild(Layer child) {
    assert(!_debugMutationsLocked);
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
    if (child._compositionCallbackCount != 0) {
      _updateSubtreeCompositionObserverCount(child._compositionCallbackCount);
    }
    assert(child._parent == null);
    assert(() {
      Layer node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    child._parent = this;
    if (attached) {
      child.attach(_owner!);
    }
    redepthChild(child);
  }

  @override
  void redepthChildren() {
    Layer? child = firstChild;
    while (child != null) {
      redepthChild(child);
      child = child.nextSibling;
    }
  }

  @protected
  void redepthChild(Layer child) {
    assert(child.owner == owner);
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child.redepthChildren();
    }
  }

  // Implementation of [Layer.remove].
  void _removeChild(Layer child) {
    assert(child.parent == this);
    assert(child.attached == attached);
    assert(_debugUltimatePreviousSiblingOf(child, equals: firstChild));
    assert(_debugUltimateNextSiblingOf(child, equals: lastChild));
    assert(child._parentHandle.layer != null);
    if (child._previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = child._nextSibling;
    } else {
      child._previousSibling!._nextSibling = child.nextSibling;
    }
    if (child._nextSibling == null) {
      assert(lastChild == child);
      _lastChild = child.previousSibling;
    } else {
      child.nextSibling!._previousSibling = child.previousSibling;
    }
    assert((firstChild == null) == (lastChild == null));
    assert(firstChild == null || firstChild!.attached == attached);
    assert(lastChild == null || lastChild!.attached == attached);
    assert(firstChild == null || _debugUltimateNextSiblingOf(firstChild!, equals: lastChild));
    assert(lastChild == null || _debugUltimatePreviousSiblingOf(lastChild!, equals: firstChild));
    child._previousSibling = null;
    child._nextSibling = null;
    _dropChild(child);
    child._parentHandle.layer = null;
    assert(!child.attached);
  }

  void _dropChild(Layer child) {
    assert(!_debugMutationsLocked);
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
    if (child._compositionCallbackCount != 0) {
      _updateSubtreeCompositionObserverCount(-child._compositionCallbackCount);
    }
    assert(child._parent == this);
    assert(child.attached == attached);
    child._parent = null;
    if (attached) {
      child.detach();
    }
  }

  void removeAllChildren() {
    assert(!_debugMutationsLocked);
    Layer? child = firstChild;
    while (child != null) {
      final Layer? next = child.nextSibling;
      child._previousSibling = null;
      child._nextSibling = null;
      assert(child.attached == attached);
      _dropChild(child);
      child._parentHandle.layer = null;
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    addChildrenToScene(builder);
  }

  void addChildrenToScene(ui.SceneBuilder builder) {
    Layer? child = firstChild;
    while (child != null) {
      child._addToSceneWithRetainedRendering(builder);
      child = child.nextSibling;
    }
  }

  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
  }

  @visibleForTesting
  List<Layer> depthFirstIterateChildren() {
    if (firstChild == null) {
      return <Layer>[];
    }
    final List<Layer> children = <Layer>[];
    Layer? child = firstChild;
    while (child != null) {
      children.add(child);
      if (child is ContainerLayer) {
        children.addAll(child.depthFirstIterateChildren());
      }
      child = child.nextSibling;
    }
    return children;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (firstChild == null) {
      return children;
    }
    Layer? child = firstChild;
    int count = 1;
    while (true) {
      children.add(child!.toDiagnosticsNode(name: 'child $count'));
      if (child == lastChild) {
        break;
      }
      count += 1;
      child = child.nextSibling;
    }
    return children;
  }
}

class OffsetLayer extends ContainerLayer {
  OffsetLayer({ Offset offset = Offset.zero }) : _offset = offset;

  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    if (value != _offset) {
      markNeedsAddToScene();
    }
    _offset = value;
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return super.findAnnotations<S>(result, localPosition - offset, onlyFirst: onlyFirst);
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    transform.translate(offset.dx, offset.dy);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    // Skia has a fast path for concatenating scale/translation only matrices.
    // Hence pushing a translation-only transform layer should be fast. For
    // retained rendering, we don't want to push the offset down to each leaf
    // node. Otherwise, changing an offset layer on the very high level could
    // cascade the change to too many leaves.
    engineLayer = builder.pushOffset(
      offset.dx,
      offset.dy,
      oldLayer: _engineLayer as ui.OffsetEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
  }

  ui.Scene _createSceneForImage(Rect bounds, { double pixelRatio = 1.0 }) {
    final ui.SceneBuilder builder = ui.SceneBuilder();
    final Matrix4 transform = Matrix4.diagonal3Values(pixelRatio, pixelRatio, 1);
    transform.translate(-(bounds.left + offset.dx), -(bounds.top + offset.dy));
    builder.pushTransform(transform.storage);
    return buildScene(builder);
  }

  Future<ui.Image> toImage(Rect bounds, { double pixelRatio = 1.0 }) async {
    final ui.Scene scene = _createSceneForImage(bounds, pixelRatio: pixelRatio);

    try {
      // Size is rounded up to the next pixel to make sure we don't clip off
      // anything.
      return await scene.toImage(
        (pixelRatio * bounds.width).ceil(),
        (pixelRatio * bounds.height).ceil(),
      );
    } finally {
      scene.dispose();
    }
  }

  ui.Image toImageSync(Rect bounds, { double pixelRatio = 1.0 }) {
    final ui.Scene scene = _createSceneForImage(bounds, pixelRatio: pixelRatio);

    try {
      // Size is rounded up to the next pixel to make sure we don't clip off
      // anything.
      return scene.toImageSync(
        (pixelRatio * bounds.width).ceil(),
        (pixelRatio * bounds.height).ceil(),
      );
    } finally {
      scene.dispose();
    }
  }
}

class ClipRectLayer extends ContainerLayer {
  ClipRectLayer({
    Rect? clipRect,
    Clip clipBehavior = Clip.hardEdge,
  }) : _clipRect = clipRect,
       _clipBehavior = clipBehavior,
       assert(clipBehavior != Clip.none);

  Rect? get clipRect => _clipRect;
  Rect? _clipRect;
  set clipRect(Rect? value) {
    if (value != _clipRect) {
      _clipRect = value;
      markNeedsAddToScene();
    }
  }

  @override
  Rect? describeClipBounds() => clipRect;

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != Clip.none);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipRect!.contains(localPosition)) {
      return false;
    }
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipRect != null);
    bool enabled = true;
    assert(() {
      enabled = !debugDisableClipLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushClipRect(
        clipRect!,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.ClipRectEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled) {
      builder.pop();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('clipRect', clipRect));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

class ClipRRectLayer extends ContainerLayer {
  ClipRRectLayer({
    RRect? clipRRect,
    Clip clipBehavior = Clip.antiAlias,
  }) : _clipRRect = clipRRect,
       _clipBehavior = clipBehavior,
       assert(clipBehavior != Clip.none);

  RRect? get clipRRect => _clipRRect;
  RRect? _clipRRect;
  set clipRRect(RRect? value) {
    if (value != _clipRRect) {
      _clipRRect = value;
      markNeedsAddToScene();
    }
  }

  @override
  Rect? describeClipBounds() => clipRRect?.outerRect;

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != Clip.none);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipRRect!.contains(localPosition)) {
      return false;
    }
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipRRect != null);
    bool enabled = true;
    assert(() {
      enabled = !debugDisableClipLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushClipRRect(
        clipRRect!,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.ClipRRectEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled) {
      builder.pop();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RRect>('clipRRect', clipRRect));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

class ClipPathLayer extends ContainerLayer {
  ClipPathLayer({
    Path? clipPath,
    Clip clipBehavior = Clip.antiAlias,
  }) : _clipPath = clipPath,
       _clipBehavior = clipBehavior,
       assert(clipBehavior != Clip.none);

  Path? get clipPath => _clipPath;
  Path? _clipPath;
  set clipPath(Path? value) {
    if (value != _clipPath) {
      _clipPath = value;
      markNeedsAddToScene();
    }
  }

  @override
  Rect? describeClipBounds() => clipPath?.getBounds();

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    assert(value != Clip.none);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsAddToScene();
    }
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (!clipPath!.contains(localPosition)) {
      return false;
    }
    return super.findAnnotations<S>(result, localPosition, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(clipPath != null);
    bool enabled = true;
    assert(() {
      enabled = !debugDisableClipLayers;
      return true;
    }());
    if (enabled) {
      engineLayer = builder.pushClipPath(
        clipPath!,
        clipBehavior: clipBehavior,
        oldLayer: _engineLayer as ui.ClipPathEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (enabled) {
      builder.pop();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

class ColorFilterLayer extends ContainerLayer {
  ColorFilterLayer({
    ColorFilter? colorFilter,
  }) : _colorFilter = colorFilter;

  ColorFilter? get colorFilter => _colorFilter;
  ColorFilter? _colorFilter;
  set colorFilter(ColorFilter? value) {
    assert(value != null);
    if (value != _colorFilter) {
      _colorFilter = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(colorFilter != null);
    engineLayer = builder.pushColorFilter(
      colorFilter!,
      oldLayer: _engineLayer as ui.ColorFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ColorFilter>('colorFilter', colorFilter));
  }
}

class ImageFilterLayer extends OffsetLayer {
  ImageFilterLayer({
    ui.ImageFilter? imageFilter,
    super.offset,
  }) : _imageFilter = imageFilter;

  ui.ImageFilter? get imageFilter => _imageFilter;
  ui.ImageFilter? _imageFilter;
  set imageFilter(ui.ImageFilter? value) {
    assert(value != null);
    if (value != _imageFilter) {
      _imageFilter = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(imageFilter != null);
    engineLayer = builder.pushImageFilter(
      imageFilter!,
      offset: offset,
      oldLayer: _engineLayer as ui.ImageFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ui.ImageFilter>('imageFilter', imageFilter));
  }
}

class TransformLayer extends OffsetLayer {
  TransformLayer({ Matrix4? transform, super.offset })
    : _transform = transform;

  Matrix4? get transform => _transform;
  Matrix4? _transform;
  set transform(Matrix4? value) {
    assert(value != null);
    assert(value!.storage.every((double component) => component.isFinite));
    if (value == _transform) {
      return;
    }
    _transform = value;
    _inverseDirty = true;
    markNeedsAddToScene();
  }

  Matrix4? _lastEffectiveTransform;
  Matrix4? _invertedTransform;
  bool _inverseDirty = true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(transform != null);
    _lastEffectiveTransform = transform;
    if (offset != Offset.zero) {
      _lastEffectiveTransform = Matrix4.translationValues(offset.dx, offset.dy, 0.0)
        ..multiply(_lastEffectiveTransform!);
    }
    engineLayer = builder.pushTransform(
      _lastEffectiveTransform!.storage,
      oldLayer: _engineLayer as ui.TransformEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  Offset? _transformOffset(Offset localPosition) {
    if (_inverseDirty) {
      _invertedTransform = Matrix4.tryInvert(
        PointerEvent.removePerspectiveTransform(transform!),
      );
      _inverseDirty = false;
    }
    if (_invertedTransform == null) {
      return null;
    }

    return MatrixUtils.transformPoint(_invertedTransform!, localPosition);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    final Offset? transformedOffset = _transformOffset(localPosition);
    if (transformedOffset == null) {
      return false;
    }
    return super.findAnnotations<S>(result, transformedOffset, onlyFirst: onlyFirst);
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    assert(_lastEffectiveTransform != null || this.transform != null);
    if (_lastEffectiveTransform == null) {
      transform.multiply(this.transform!);
    } else {
      transform.multiply(_lastEffectiveTransform!);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(TransformProperty('transform', transform));
  }
}

class OpacityLayer extends OffsetLayer {
  OpacityLayer({
    int? alpha,
    super.offset,
  }) : _alpha = alpha;

  int? get alpha => _alpha;
  int? _alpha;
  set alpha(int? value) {
    assert(value != null);
    if (value != _alpha) {
      if (value == 255 || _alpha == 255) {
        engineLayer = null;
      }
      _alpha = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(alpha != null);

    // Don't add this layer if there's no child.
    bool enabled = firstChild != null;
    if (!enabled) {
      // Ensure the engineLayer is disposed.
      engineLayer = null;
      // TODO(dnfield): Remove this if/when we can fix https://github.com/flutter/flutter/issues/90004
      return;
    }

    assert(() {
      enabled = enabled && !debugDisableOpacityLayers;
      return true;
    }());

    final int realizedAlpha = alpha!;
    // The type assertions work because the [alpha] setter nulls out the
    // engineLayer if it would have changed type (i.e. changed to or from 255).
    if (enabled && realizedAlpha < 255) {
      assert(_engineLayer is ui.OpacityEngineLayer?);
      engineLayer = builder.pushOpacity(
        realizedAlpha,
        offset: offset,
        oldLayer: _engineLayer as ui.OpacityEngineLayer?,
      );
    } else {
      assert(_engineLayer is ui.OffsetEngineLayer?);
      engineLayer = builder.pushOffset(
        offset.dx,
        offset.dy,
        oldLayer: _engineLayer as ui.OffsetEngineLayer?,
      );
    }
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('alpha', alpha));
  }
}

class ShaderMaskLayer extends ContainerLayer {
  ShaderMaskLayer({
    Shader? shader,
    Rect? maskRect,
    BlendMode? blendMode,
  }) : _shader = shader,
       _maskRect = maskRect,
       _blendMode = blendMode;

  Shader? get shader => _shader;
  Shader? _shader;
  set shader(Shader? value) {
    if (value != _shader) {
      _shader = value;
      markNeedsAddToScene();
    }
  }

  Rect? get maskRect => _maskRect;
  Rect? _maskRect;
  set maskRect(Rect? value) {
    if (value != _maskRect) {
      _maskRect = value;
      markNeedsAddToScene();
    }
  }

  BlendMode? get blendMode => _blendMode;
  BlendMode? _blendMode;
  set blendMode(BlendMode? value) {
    if (value != _blendMode) {
      _blendMode = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(shader != null);
    assert(maskRect != null);
    assert(blendMode != null);
    engineLayer = builder.pushShaderMask(
      shader!,
      maskRect! ,
      blendMode!,
      oldLayer: _engineLayer as ui.ShaderMaskEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Shader>('shader', shader));
    properties.add(DiagnosticsProperty<Rect>('maskRect', maskRect));
    properties.add(EnumProperty<BlendMode>('blendMode', blendMode));
  }
}

class BackdropFilterLayer extends ContainerLayer {
  BackdropFilterLayer({
    ui.ImageFilter? filter,
    BlendMode blendMode = BlendMode.srcOver,
  }) : _filter = filter,
       _blendMode = blendMode;

  ui.ImageFilter? get filter => _filter;
  ui.ImageFilter? _filter;
  set filter(ui.ImageFilter? value) {
    if (value != _filter) {
      _filter = value;
      markNeedsAddToScene();
    }
  }

  BlendMode get blendMode => _blendMode;
  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (value != _blendMode) {
      _blendMode = value;
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(filter != null);
    engineLayer = builder.pushBackdropFilter(
      filter!,
      blendMode: blendMode,
      oldLayer: _engineLayer as ui.BackdropFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ui.ImageFilter>('filter', filter));
    properties.add(EnumProperty<BlendMode>('blendMode', blendMode));
  }
}

class LayerLink {
  LeaderLayer? get leader => _leader;
  LeaderLayer? _leader;

  void _registerLeader(LeaderLayer leader) {
    assert(_leader != leader);
    assert((){
      if (_leader != null) {
        _debugPreviousLeaders ??= <LeaderLayer>{};
        _debugScheduleLeadersCleanUpCheck();
        return _debugPreviousLeaders!.add(_leader!);
      }
      return true;
    }());
    _leader = leader;
  }

  void _unregisterLeader(LeaderLayer leader) {
    if (_leader == leader) {
      _leader = null;
    } else {
      assert(_debugPreviousLeaders!.remove(leader));
    }
  }

  Set<LeaderLayer>? _debugPreviousLeaders;
  bool _debugLeaderCheckScheduled = false;

  void _debugScheduleLeadersCleanUpCheck() {
    assert(_debugPreviousLeaders != null);
    assert(() {
      if (_debugLeaderCheckScheduled) {
        return true;
      }
      _debugLeaderCheckScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _debugLeaderCheckScheduled = false;
        assert(_debugPreviousLeaders!.isEmpty);
      });
      return true;
    }());
  }

  Size? leaderSize;

  @override
  String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return '${describeIdentity(this)}(${ _leader != null ? "<linked>" : "<dangling>" })';
  }
}

class LeaderLayer extends ContainerLayer {
  LeaderLayer({ required LayerLink link, Offset offset = Offset.zero }) : _link = link, _offset = offset;

  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    if (_link == value) {
      return;
    }
    if (attached) {
      _link._unregisterLeader(this);
      value._registerLeader(this);
    }
    _link = value;
  }

  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    if (value == _offset) {
      return;
    }
    _offset = value;
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
  }

  @override
  void attach(Object owner) {
    super.attach(owner);
    _link._registerLeader(this);
  }

  @override
  void detach() {
    _link._unregisterLeader(this);
    super.detach();
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    return super.findAnnotations<S>(result, localPosition - offset, onlyFirst: onlyFirst);
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (offset != Offset.zero) {
      engineLayer = builder.pushTransform(
        Matrix4.translationValues(offset.dx, offset.dy, 0.0).storage,
        oldLayer: _engineLayer as ui.TransformEngineLayer?,
      );
    } else {
      engineLayer = null;
    }
    addChildrenToScene(builder);
    if (offset != Offset.zero) {
      builder.pop();
    }
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    if (offset != Offset.zero) {
      transform.translate(offset.dx, offset.dy);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
  }
}

class FollowerLayer extends ContainerLayer {
  FollowerLayer({
    required this.link,
    this.showWhenUnlinked = true,
    this.unlinkedOffset = Offset.zero,
    this.linkedOffset = Offset.zero,
  });

  LayerLink link;

  bool? showWhenUnlinked;

  Offset? unlinkedOffset;

  Offset? linkedOffset;

  Offset? _lastOffset;
  Matrix4? _lastTransform;
  Matrix4? _invertedTransform;
  bool _inverseDirty = true;

  Offset? _transformOffset(Offset localPosition) {
    if (_inverseDirty) {
      _invertedTransform = Matrix4.tryInvert(getLastTransform()!);
      _inverseDirty = false;
    }
    if (_invertedTransform == null) {
      return null;
    }
    final Vector4 vector = Vector4(localPosition.dx, localPosition.dy, 0.0, 1.0);
    final Vector4 result = _invertedTransform!.transform(vector);
    return Offset(result[0] - linkedOffset!.dx, result[1] - linkedOffset!.dy);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    if (link.leader == null) {
      if (showWhenUnlinked!) {
        return super.findAnnotations(result, localPosition - unlinkedOffset!, onlyFirst: onlyFirst);
      }
      return false;
    }
    final Offset? transformedOffset = _transformOffset(localPosition);
    if (transformedOffset == null) {
      return false;
    }
    return super.findAnnotations<S>(result, transformedOffset, onlyFirst: onlyFirst);
  }

  Matrix4? getLastTransform() {
    if (_lastTransform == null) {
      return null;
    }
    final Matrix4 result = Matrix4.translationValues(-_lastOffset!.dx, -_lastOffset!.dy, 0.0);
    result.multiply(_lastTransform!);
    return result;
  }

  static Matrix4 _collectTransformForLayerChain(List<ContainerLayer?> layers) {
    // Initialize our result matrix.
    final Matrix4 result = Matrix4.identity();
    // Apply each layer to the matrix in turn, starting from the last layer,
    // and providing the previous layer as the child.
    for (int index = layers.length - 1; index > 0; index -= 1) {
      layers[index]?.applyTransform(layers[index - 1], result);
    }
    return result;
  }

  static Layer? _pathsToCommonAncestor(
    Layer? a,
    Layer? b,
    List<ContainerLayer?> ancestorsA,
    List<ContainerLayer?> ancestorsB,
  ) {
    // No common ancestor found.
    if (a == null || b == null) {
      return null;
    }

    if (identical(a, b)) {
      return a;
    }

    if (a.depth < b.depth) {
      ancestorsB.add(b.parent);
      return _pathsToCommonAncestor(a, b.parent, ancestorsA, ancestorsB);
    } else if (a.depth > b.depth) {
      ancestorsA.add(a.parent);
      return _pathsToCommonAncestor(a.parent, b, ancestorsA, ancestorsB);
    }

    ancestorsA.add(a.parent);
    ancestorsB.add(b.parent);
    return _pathsToCommonAncestor(a.parent, b.parent, ancestorsA, ancestorsB);
  }

  bool _debugCheckLeaderBeforeFollower(
    List<ContainerLayer> leaderToCommonAncestor,
    List<ContainerLayer> followerToCommonAncestor,
  ) {
    if (followerToCommonAncestor.length <= 1) {
      // Follower is the common ancestor, ergo the leader must come AFTER the follower.
      return false;
    }
    if (leaderToCommonAncestor.length <= 1) {
      // Leader is the common ancestor, ergo the leader must come BEFORE the follower.
      return true;
    }

    // Common ancestor is neither the leader nor the follower.
    final ContainerLayer leaderSubtreeBelowAncestor = leaderToCommonAncestor[leaderToCommonAncestor.length - 2];
    final ContainerLayer followerSubtreeBelowAncestor = followerToCommonAncestor[followerToCommonAncestor.length - 2];

    Layer? sibling = leaderSubtreeBelowAncestor;
    while (sibling != null) {
      if (sibling == followerSubtreeBelowAncestor) {
        return true;
      }
      sibling = sibling.nextSibling;
    }
    // The follower subtree didn't come after the leader subtree.
    return false;
  }

  void _establishTransform() {
    _lastTransform = null;
    final LeaderLayer? leader = link.leader;
    // Check to see if we are linked.
    if (leader == null) {
      return;
    }
    // If we're linked, check the link is valid.
    assert(
      leader.owner == owner,
      'Linked LeaderLayer anchor is not in the same layer tree as the FollowerLayer.',
    );

    // Stores [leader, ..., commonAncestor] after calling _pathsToCommonAncestor.
    final List<ContainerLayer> forwardLayers = <ContainerLayer>[leader];
    // Stores [this (follower), ..., commonAncestor] after calling
    // _pathsToCommonAncestor.
    final List<ContainerLayer> inverseLayers = <ContainerLayer>[this];

    final Layer? ancestor = _pathsToCommonAncestor(
      leader, this,
      forwardLayers, inverseLayers,
    );
    assert(
      ancestor != null,
      'LeaderLayer and FollowerLayer do not have a common ancestor.',
    );
    assert(
      _debugCheckLeaderBeforeFollower(forwardLayers, inverseLayers),
      'LeaderLayer anchor must come before FollowerLayer in paint order, but the reverse was true.',
    );

    final Matrix4 forwardTransform = _collectTransformForLayerChain(forwardLayers);
    // Further transforms the coordinate system to a hypothetical child (null)
    // of the leader layer, to account for the leader's additional paint offset
    // and layer offset (LeaderLayer.offset).
    leader.applyTransform(null, forwardTransform);
    forwardTransform.translate(linkedOffset!.dx, linkedOffset!.dy);

    final Matrix4 inverseTransform = _collectTransformForLayerChain(inverseLayers);

    if (inverseTransform.invert() == 0.0) {
      // We are in a degenerate transform, so there's not much we can do.
      return;
    }
    // Combine the matrices and store the result.
    inverseTransform.multiply(forwardTransform);
    _lastTransform = inverseTransform;
    _inverseDirty = true;
  }

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(showWhenUnlinked != null);
    if (link.leader == null && !showWhenUnlinked!) {
      _lastTransform = null;
      _lastOffset = null;
      _inverseDirty = true;
      engineLayer = null;
      return;
    }
    _establishTransform();
    if (_lastTransform != null) {
      _lastOffset = unlinkedOffset;
      engineLayer = builder.pushTransform(
        _lastTransform!.storage,
        oldLayer: _engineLayer as ui.TransformEngineLayer?,
      );
      addChildrenToScene(builder);
      builder.pop();
    } else {
      _lastOffset = null;
      final Matrix4 matrix = Matrix4.translationValues(unlinkedOffset!.dx, unlinkedOffset!.dy, .0);
      engineLayer = builder.pushTransform(
        matrix.storage,
        oldLayer: _engineLayer as ui.TransformEngineLayer?,
      );
      addChildrenToScene(builder);
      builder.pop();
    }
    _inverseDirty = true;
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    if (_lastTransform != null) {
      transform.multiply(_lastTransform!);
    } else {
      transform.multiply(Matrix4.translationValues(unlinkedOffset!.dx, unlinkedOffset!.dy, 0));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
    properties.add(TransformProperty('transform', getLastTransform(), defaultValue: null));
  }
}

class AnnotatedRegionLayer<T extends Object> extends ContainerLayer {
  AnnotatedRegionLayer(
    this.value, {
    this.size,
    Offset? offset,
    this.opaque = false,
  }) : offset = offset ?? Offset.zero;

  final T value;

  final Size? size;

  final Offset offset;

  final bool opaque;

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, { required bool onlyFirst }) {
    bool isAbsorbed = super.findAnnotations(result, localPosition, onlyFirst: onlyFirst);
    if (result.entries.isNotEmpty && onlyFirst) {
      return isAbsorbed;
    }
    if (size != null && !(offset & size!).contains(localPosition)) {
      return isAbsorbed;
    }
    if (T == S) {
      isAbsorbed = isAbsorbed || opaque;
      final Object untypedValue = value;
      final S typedValue = untypedValue as S;
      result.add(AnnotationEntry<S>(
        annotation: typedValue,
        localPosition: localPosition - offset,
      ));
    }
    return isAbsorbed;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('value', value));
    properties.add(DiagnosticsProperty<Size>('size', size, defaultValue: null));
    properties.add(DiagnosticsProperty<Offset>('offset', offset, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('opaque', opaque, defaultValue: false));
  }
}