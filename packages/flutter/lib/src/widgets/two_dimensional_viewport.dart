// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'scroll_delegate.dart';
import 'scroll_notification.dart';
import 'scroll_position.dart';

export 'package:flutter/rendering.dart' show AxisDirection;

// Examples can assume:
// late final RenderBox child;
// late final BoxConstraints constraints;
// class RenderSimpleTwoDimensionalViewport extends RenderTwoDimensionalViewport {
//   RenderSimpleTwoDimensionalViewport({
//     required super.horizontalOffset,
//     required super.horizontalAxisDirection,
//     required super.verticalOffset,
//     required super.verticalAxisDirection,
//     required super.delegate,
//     required super.mainAxis,
//     required super.childManager,
//     super.cacheExtent,
//     super.clipBehavior = Clip.hardEdge,
//   });
//   @override
//   void layoutChildSequence() { }
// }

typedef TwoDimensionalIndexedWidgetBuilder = Widget? Function(BuildContext, ChildVicinity vicinity);

abstract class TwoDimensionalViewport extends RenderObjectWidget {
  const TwoDimensionalViewport({
    super.key,
    required this.verticalOffset,
    required this.verticalAxisDirection,
    required this.horizontalOffset,
    required this.horizontalAxisDirection,
    required this.delegate,
    required this.mainAxis,
    this.cacheExtent,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(
         verticalAxisDirection == AxisDirection.down || verticalAxisDirection == AxisDirection.up,
         'TwoDimensionalViewport.verticalAxisDirection is not Axis.vertical.'
       ),
       assert(
         horizontalAxisDirection == AxisDirection.left || horizontalAxisDirection == AxisDirection.right,
         'TwoDimensionalViewport.horizontalAxisDirection is not Axis.horizontal.'
       );

  final ViewportOffset verticalOffset;

  final AxisDirection verticalAxisDirection;

  final ViewportOffset horizontalOffset;

  final AxisDirection horizontalAxisDirection;

  final Axis mainAxis;

  final double? cacheExtent;

  final Clip clipBehavior;

  final TwoDimensionalChildDelegate delegate;

  @override
  RenderObjectElement createElement() => _TwoDimensionalViewportElement(this);

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context);

  @override
  void updateRenderObject(BuildContext context, RenderTwoDimensionalViewport renderObject);
}

class _TwoDimensionalViewportElement extends RenderObjectElement
    with NotifiableElementMixin, ViewportElementMixin implements TwoDimensionalChildManager {
  _TwoDimensionalViewportElement(super.widget);

  @override
  RenderTwoDimensionalViewport get renderObject => super.renderObject as RenderTwoDimensionalViewport;

  // Contains all children, including those that are keyed.
  Map<ChildVicinity, Element> _vicinityToChild = <ChildVicinity, Element>{};
  Map<Key, Element> _keyToChild = <Key, Element>{};
  // Used between _startLayout() & _endLayout() to compute the new values for
  // _vicinityToChild and _keyToChild.
  Map<ChildVicinity, Element>? _newVicinityToChild;
  Map<Key, Element>? _newKeyToChild;

  @override
  void performRebuild() {
    super.performRebuild();
    // Children list is updated during layout since we only know during layout
    // which children will be visible.
    renderObject.markNeedsLayout(withDelegateRebuild: true);
  }

  @override
  void forgetChild(Element child) {
    assert(!_debugIsDoingLayout);
    super.forgetChild(child);
    _vicinityToChild.remove(child.slot);
    if (child.widget.key != null) {
      _keyToChild.remove(child.widget.key);
    }
  }

  @override
  void insertRenderObjectChild(RenderBox child, ChildVicinity slot) {
    renderObject._insertChild(child, slot);
  }

  @override
  void moveRenderObjectChild(RenderBox child, ChildVicinity oldSlot, ChildVicinity newSlot) {
    renderObject._moveChild(child, from: oldSlot, to: newSlot);
  }

  @override
  void removeRenderObjectChild(RenderBox child, ChildVicinity slot) {
    renderObject._removeChild(child, slot);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _vicinityToChild.values.forEach(visitor);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<Element> children = _vicinityToChild.values.toList()..sort(_compareChildren);
    return <DiagnosticsNode>[
      for (final Element child in children)
        child.toDiagnosticsNode(name: child.slot.toString())
    ];
  }

  static int _compareChildren(Element a, Element b) {
    final ChildVicinity aSlot = a.slot! as ChildVicinity;
    final ChildVicinity bSlot = b.slot! as ChildVicinity;
    return aSlot.compareTo(bSlot);
  }

  // ---- ChildManager implementation ----

  bool get _debugIsDoingLayout => _newKeyToChild != null && _newVicinityToChild != null;

  @override
  void _startLayout() {
    assert(!_debugIsDoingLayout);
    _newVicinityToChild = <ChildVicinity, Element>{};
    _newKeyToChild = <Key, Element>{};
  }

  @override
  void _buildChild(ChildVicinity vicinity) {
    assert(_debugIsDoingLayout);
    owner!.buildScope(this, () {
      final Widget? newWidget = (widget as TwoDimensionalViewport).delegate.build(this, vicinity);
      if (newWidget == null) {
        return;
      }
      final Element? oldElement = _retrieveOldElement(newWidget, vicinity);
      final Element? newChild = updateChild(oldElement, newWidget, vicinity);
      assert(newChild != null);
      // Ensure we are not overwriting an existing child.
      assert(_newVicinityToChild![vicinity] == null);
      _newVicinityToChild![vicinity] = newChild!;
      if (newWidget.key != null) {
        // Ensure we are not overwriting an existing key
        assert(_newKeyToChild![newWidget.key!] == null);
        _newKeyToChild![newWidget.key!] = newChild;
      }
    });
  }

  Element? _retrieveOldElement(Widget newWidget, ChildVicinity vicinity) {
    if (newWidget.key != null) {
      final Element? result = _keyToChild.remove(newWidget.key);
      if (result != null) {
        _vicinityToChild.remove(result.slot);
      }
      return result;
    }
    final Element? potentialOldElement = _vicinityToChild[vicinity];
    if (potentialOldElement != null && potentialOldElement.widget.key == null) {
      return _vicinityToChild.remove(vicinity);
    }
    return null;
  }

  @override
  void _reuseChild(ChildVicinity vicinity) {
    assert(_debugIsDoingLayout);
    final Element? elementToReuse = _vicinityToChild.remove(vicinity);
    assert(
      elementToReuse != null,
      'Expected to re-use an element at $vicinity, but none was found.'
    );
    _newVicinityToChild![vicinity] = elementToReuse!;
    if (elementToReuse.widget.key != null) {
      assert(_keyToChild.containsKey(elementToReuse.widget.key));
      assert(_keyToChild[elementToReuse.widget.key] == elementToReuse);
      _newKeyToChild![elementToReuse.widget.key!] = _keyToChild.remove(elementToReuse.widget.key)!;
    }
  }

  @override
  void _endLayout() {
    assert(_debugIsDoingLayout);

    // Unmount all elements that have not been reused in the layout cycle.
    for (final Element element in _vicinityToChild.values) {
      if (element.widget.key == null) {
        // If it has a key, we handle it below.
        updateChild(element, null, null);
      } else {
        assert(_keyToChild.containsValue(element));
      }
    }
    for (final Element element in _keyToChild.values) {
      assert(element.widget.key != null);
      updateChild(element, null, null);
    }

    _vicinityToChild = _newVicinityToChild!;
    _keyToChild = _newKeyToChild!;
    _newVicinityToChild = null;
    _newKeyToChild = null;
    assert(!_debugIsDoingLayout);
  }
}

class TwoDimensionalViewportParentData extends ParentData  with KeepAliveParentDataMixin {
  Offset? layoutOffset;

  ChildVicinity vicinity = ChildVicinity.invalid;

  bool get isVisible {
    assert(() {
      if (_paintExtent == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('The paint extent of the child has not been determined yet.'),
          ErrorDescription(
            'The paint extent, and therefore the visibility, of a child of a '
            'RenderTwoDimensionalViewport is computed after '
            'RenderTwoDimensionalViewport.layoutChildSequence.'
          ),
        ]);
      }
      return true;
    }());
    return _paintExtent != Size.zero || _paintExtent!.height != 0.0 || _paintExtent!.width != 0.0;
  }

  Size? _paintExtent;

  RenderBox? _previousSibling;

  RenderBox? _nextSibling;

  Offset? paintOffset;

  @override
  bool get keptAlive => keepAlive && !isVisible;

  @override
  String toString() {
    return 'vicinity=$vicinity; '
      'layoutOffset=$layoutOffset; '
      'paintOffset=$paintOffset; '
      '${_paintExtent == null
        ? 'not visible; '
        : '${!isVisible ? 'not ' : ''}visible - paintExtent=$_paintExtent; '}'
      '${keepAlive ? "keepAlive; " : ""}';
  }
}

// TODO(Piinks): ensureVisible https://github.com/flutter/flutter/issues/126299
abstract class RenderTwoDimensionalViewport extends RenderBox implements RenderAbstractViewport {
  RenderTwoDimensionalViewport({
    required ViewportOffset horizontalOffset,
    required AxisDirection horizontalAxisDirection,
    required ViewportOffset verticalOffset,
    required AxisDirection verticalAxisDirection,
    required TwoDimensionalChildDelegate delegate,
    required Axis mainAxis,
    required TwoDimensionalChildManager childManager,
    double? cacheExtent,
    Clip clipBehavior = Clip.hardEdge,
  }) : assert(
         verticalAxisDirection == AxisDirection.down || verticalAxisDirection == AxisDirection.up,
         'TwoDimensionalViewport.verticalAxisDirection is not Axis.vertical.'
       ),
       assert(
         horizontalAxisDirection == AxisDirection.left || horizontalAxisDirection == AxisDirection.right,
         'TwoDimensionalViewport.horizontalAxisDirection is not Axis.horizontal.'
       ),
       _childManager = childManager,
       _horizontalOffset = horizontalOffset,
       _horizontalAxisDirection = horizontalAxisDirection,
       _verticalOffset = verticalOffset,
       _verticalAxisDirection = verticalAxisDirection,
       _delegate = delegate,
       _mainAxis = mainAxis,
       _cacheExtent = cacheExtent ?? RenderAbstractViewport.defaultCacheExtent,
       _clipBehavior = clipBehavior {
    assert(() {
      _debugDanglingKeepAlives = <RenderBox>[];
      return true;
    }());
  }

  ViewportOffset get horizontalOffset => _horizontalOffset;
  ViewportOffset _horizontalOffset;
  set horizontalOffset(ViewportOffset value) {
    if (_horizontalOffset == value) {
      return;
    }
    if (attached) {
      _horizontalOffset.removeListener(markNeedsLayout);
    }
    _horizontalOffset = value;
    if (attached) {
      _horizontalOffset.addListener(markNeedsLayout);
    }
    markNeedsLayout();
  }

  AxisDirection get horizontalAxisDirection => _horizontalAxisDirection;
  AxisDirection _horizontalAxisDirection;
  set horizontalAxisDirection(AxisDirection value) {
    if (_horizontalAxisDirection == value) {
      return;
    }
    _horizontalAxisDirection = value;
    markNeedsLayout();
  }

  ViewportOffset get verticalOffset => _verticalOffset;
  ViewportOffset _verticalOffset;
  set verticalOffset(ViewportOffset value) {
    if (_verticalOffset == value) {
      return;
    }
    if (attached) {
      _verticalOffset.removeListener(markNeedsLayout);
    }
    _verticalOffset = value;
    if (attached) {
      _verticalOffset.addListener(markNeedsLayout);
    }
    markNeedsLayout();
  }

  AxisDirection get verticalAxisDirection => _verticalAxisDirection;
  AxisDirection _verticalAxisDirection;
  set verticalAxisDirection(AxisDirection value) {
    if (_verticalAxisDirection == value) {
      return;
    }
    _verticalAxisDirection = value;
    markNeedsLayout();
  }

  TwoDimensionalChildDelegate get delegate => _delegate;
  TwoDimensionalChildDelegate _delegate;
  set delegate(covariant TwoDimensionalChildDelegate value) {
    if (_delegate == value) {
      return;
    }
    if (attached) {
      _delegate.removeListener(_handleDelegateNotification);
    }
    final TwoDimensionalChildDelegate oldDelegate = _delegate;
    _delegate = value;
    if (attached) {
      _delegate.addListener(_handleDelegateNotification);
    }
    if (_delegate.runtimeType != oldDelegate.runtimeType || _delegate.shouldRebuild(oldDelegate)) {
      _handleDelegateNotification();
    }
  }

  Axis  get mainAxis => _mainAxis;
  Axis _mainAxis;
  set mainAxis(Axis value) {
    if (_mainAxis == value) {
      return;
    }
    _mainAxis = value;
    // Child order needs to be resorted, which happens in performLayout.
    markNeedsLayout();
  }

  double  get cacheExtent => _cacheExtent ?? RenderAbstractViewport.defaultCacheExtent;
  double? _cacheExtent;
  set cacheExtent(double? value) {
    if (_cacheExtent == value) {
      return;
    }
    _cacheExtent = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (_clipBehavior == value) {
      return;
    }
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  final TwoDimensionalChildManager _childManager;
  final Map<ChildVicinity, RenderBox> _children = <ChildVicinity, RenderBox>{};
  final Map<ChildVicinity, RenderBox> _activeChildrenForLayoutPass = <ChildVicinity, RenderBox>{};
  final Map<ChildVicinity, RenderBox> _keepAliveBucket = <ChildVicinity, RenderBox>{};

  late List<RenderBox> _debugDanglingKeepAlives;

  bool _hasVisualOverflow = false;
  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  // Keeps track of the upper and lower bounds of ChildVicinity indices when
  // subclasses call buildOrObtainChildFor during layoutChildSequence. These
  // values are used to sort children in accordance with the mainAxis for
  // paint order.
  int? _leadingXIndex;
  int? _trailingXIndex;
  int? _leadingYIndex;
  int? _trailingYIndex;

  RenderBox? get firstChild => _firstChild;
  RenderBox? _firstChild;

  RenderBox? get lastChild => _lastChild;
  RenderBox? _lastChild;

  RenderBox? childBefore(RenderBox child) {
    assert(child.parent == this);
    return parentDataOf(child)._previousSibling;
  }

  RenderBox? childAfter(RenderBox child) {
    assert(child.parent == this);
    return parentDataOf(child)._nextSibling;
  }

  void _handleDelegateNotification() {
    return markNeedsLayout(withDelegateRebuild: true);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TwoDimensionalViewportParentData) {
      child.parentData = TwoDimensionalViewportParentData();
    }
  }

  @protected
  TwoDimensionalViewportParentData parentDataOf(RenderBox child) {
    assert(_children.containsValue(child));
    return child.parentData! as TwoDimensionalViewportParentData;
  }

  @protected
  RenderBox? getChildFor(ChildVicinity vicinity) => _children[vicinity];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _horizontalOffset.addListener(markNeedsLayout);
    _verticalOffset.addListener(markNeedsLayout);
    _delegate.addListener(_handleDelegateNotification);
    for (final RenderBox child in _children.values) {
      child.attach(owner);
    }
    for (final RenderBox child in _keepAliveBucket.values) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    _horizontalOffset.removeListener(markNeedsLayout);
    _verticalOffset.removeListener(markNeedsLayout);
    _delegate.removeListener(_handleDelegateNotification);
    for (final RenderBox child in _children.values) {
      child.detach();
    }
    for (final RenderBox child in _keepAliveBucket.values) {
      child.detach();
    }
  }

  @override
  void redepthChildren() {
    for (final RenderBox child in _children.values) {
      child.redepthChildren();
    }
    _keepAliveBucket.values.forEach(redepthChild);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    RenderBox? child = _firstChild;
    while (child != null) {
      visitor(child);
      child = parentDataOf(child)._nextSibling;
    }
    _keepAliveBucket.values.forEach(visitor);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // Only children that are visible should be visited, and they must be in
    // paint order.
    RenderBox? child = _firstChild;
    while (child != null) {
      final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
      // TODO(Piinks): When ensure visible is supported, remove this isVisible
      //  condition.
      if (childParentData.isVisible) {
        visitor(child);
      }
      child = childParentData._nextSibling;
    }
    // Do not visit children in [_keepAliveBucket].
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> debugChildren = <DiagnosticsNode>[
      ..._children.keys.map<DiagnosticsNode>((ChildVicinity vicinity) {
        return _children[vicinity]!.toDiagnosticsNode(name: vicinity.toString());
      })
    ];
    return debugChildren;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCheckHasBoundedAxis(Axis.vertical, constraints));
    assert(debugCheckHasBoundedAxis(Axis.horizontal, constraints));
    return constraints.biggest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    for (final RenderBox child in _children.values) {
      final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
      if (!childParentData.isVisible) {
        // Can't hit a child that is not visible.
        continue;
      }
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.paintOffset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.paintOffset!);
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }

  Size get viewportDimension {
    assert(hasSize);
    return size;
  }

  @override
  void performResize() {
    final Size? oldSize = hasSize ? size : null;
    super.performResize();
    // Ignoring return value since we are doing a layout either way
    // (performLayout will be invoked next).
    horizontalOffset.applyViewportDimension(size.width);
    verticalOffset.applyViewportDimension(size.height);
    if (oldSize != size) {
      // Specs can depend on viewport size.
      _didResize = true;
    }
  }

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, { Rect? rect }) {
    // TODO(Piinks): Add this back in follow up change (ensureVisible), https://github.com/flutter/flutter/issues/126299
    return const RevealedOffset(offset: 0.0, rect: Rect.zero);
  }

  bool get didResize => _didResize;
  bool _didResize = true;

  @protected
  bool get needsDelegateRebuild => _needsDelegateRebuild;
  bool _needsDelegateRebuild = true;

  @override
  void markNeedsLayout({ bool withDelegateRebuild = false }) {
    _needsDelegateRebuild = _needsDelegateRebuild || withDelegateRebuild;
    super.markNeedsLayout();
  }

  void layoutChildSequence();

  @override
  void performLayout() {
    _firstChild = null;
    _lastChild = null;
    _activeChildrenForLayoutPass.clear();
    _childManager._startLayout();

    // Subclass lays out children.
    layoutChildSequence();

    assert(_debugCheckContentDimensions());
    _didResize = false;
    _needsDelegateRebuild = false;
    _cacheKeepAlives();
    invokeLayoutCallback<BoxConstraints>((BoxConstraints _) {
      _childManager._endLayout();
      assert(_debugOrphans?.isEmpty ?? true);
      assert(_debugDanglingKeepAlives.isEmpty);
      // Ensure we are not keeping anything alive that should not be any longer.
      assert(_keepAliveBucket.values.where((RenderBox child) {
        return !parentDataOf(child).keepAlive;
      }).isEmpty);
      // Organize children in paint order and complete parent data after
      // un-used children are disposed of by the childManager.
      _reifyChildren();
    });
  }

  void _cacheKeepAlives() {
    final List<RenderBox> remainingChildren = _children.values.toSet().difference(
      _activeChildrenForLayoutPass.values.toSet()
    ).toList();
    for (final RenderBox child in remainingChildren) {
      final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
      if (childParentData.keepAlive) {
        _keepAliveBucket[childParentData.vicinity] = child;
        // Let the child manager know we intend to keep this.
        _childManager._reuseChild(childParentData.vicinity);
      }
    }
  }

  // Ensures all children have a layoutOffset, sets paintExtent & paintOffset,
  // and arranges children in paint order.
  void _reifyChildren() {
    assert(_leadingXIndex != null);
    assert(_trailingXIndex != null);
    assert(_leadingYIndex != null);
    assert(_trailingYIndex != null);
    assert(_firstChild == null);
    assert(_lastChild == null);
    RenderBox? previousChild;
    switch (mainAxis) {
      case Axis.vertical:
        // Row major traversal.
        // This seems backwards, but the vertical axis is the typical default
        // axis for scrolling in Flutter, while Row-major ordering is the
        // typical default for matrices, which is why the inverse follows
        // through in the horizontal case below.
        // Minor
        for (int minorIndex = _leadingYIndex!; minorIndex <= _trailingYIndex!; minorIndex++) {
          // Major
          for (int majorIndex = _leadingXIndex!; majorIndex <= _trailingXIndex!; majorIndex++) {
            final ChildVicinity vicinity = ChildVicinity(xIndex: majorIndex, yIndex: minorIndex);
            previousChild = _completeChildParentData(
              vicinity,
              previousChild: previousChild,
            ) ?? previousChild;
          }
        }
      case Axis.horizontal:
        // Column major traversal
        // Minor
        for (int minorIndex = _leadingXIndex!; minorIndex <= _trailingXIndex!; minorIndex++) {
          // Major
          for (int majorIndex = _leadingYIndex!; majorIndex <= _trailingYIndex!; majorIndex++) {
            final ChildVicinity vicinity = ChildVicinity(xIndex: minorIndex, yIndex: majorIndex);
            previousChild = _completeChildParentData(
              vicinity,
              previousChild: previousChild,
            ) ?? previousChild;
          }
        }
    }
    _lastChild = previousChild;
    parentDataOf(_lastChild!)._nextSibling = null;
    // Reset for next layout pass.
    _leadingXIndex = null;
    _trailingXIndex = null;
    _leadingYIndex = null;
    _trailingYIndex = null;
  }

  RenderBox? _completeChildParentData(ChildVicinity vicinity, { RenderBox? previousChild }) {
    assert(vicinity != ChildVicinity.invalid);
    // It is possible and valid for a vicinity to be skipped.
    // For example, a table can have merged cells, spanning multiple
    // indices, but only represented by one RenderBox and ChildVicinity.
    if (_children.containsKey(vicinity)) {
      final RenderBox child = _children[vicinity]!;
      assert(parentDataOf(child).vicinity == vicinity);
      updateChildPaintData(child);
      if (previousChild == null) {
        // _firstChild is only set once.
        assert(_firstChild == null);
        _firstChild = child;
      } else {
        parentDataOf(previousChild)._nextSibling = child;
        parentDataOf(child)._previousSibling = previousChild;
      }
      return child;
    }
    return null;
  }

  bool _debugCheckContentDimensions() {
    const  String hint = 'Subclasses should call applyContentDimensions on the '
      'verticalOffset and horizontalOffset to set the min and max scroll offset. '
      'If the contents exceed one or both sides of the viewportDimension, '
      'ensure the viewportDimension height or width is subtracted in that axis '
      'for the correct extent.';
    assert(() {
      if (!(verticalOffset as ScrollPosition).hasContentDimensions) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'The verticalOffset was not given content dimensions during '
            'layoutChildSequence.'
          ),
          ErrorHint(hint),
        ]);
      }
      return true;
    }());
    assert(() {
      if (!(horizontalOffset as ScrollPosition).hasContentDimensions) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'The horizontalOffset was not given content dimensions during '
            'layoutChildSequence.'
          ),
          ErrorHint(hint),
        ]);
      }
      return true;
    }());
    return true;
  }

  RenderBox? buildOrObtainChildFor(ChildVicinity vicinity) {
    assert(vicinity != ChildVicinity.invalid);
    // This should only be called during layout.
    assert(debugDoingThisLayout);
    if (_leadingXIndex == null || _trailingXIndex == null || _leadingXIndex == null || _trailingYIndex == null) {
      // First child of this layout pass. Set leading and trailing trackers.
      _leadingXIndex = vicinity.xIndex;
      _trailingXIndex = vicinity.xIndex;
      _leadingYIndex = vicinity.yIndex;
      _trailingYIndex = vicinity.yIndex;
    } else {
      // If any of these are still null, we missed a child.
      assert(_leadingXIndex != null);
      assert(_trailingXIndex != null);
      assert(_leadingYIndex != null);
      assert(_trailingYIndex != null);

      // Update as we go.
      _leadingXIndex = math.min(vicinity.xIndex, _leadingXIndex!);
      _trailingXIndex = math.max(vicinity.xIndex, _trailingXIndex!);
      _leadingYIndex = math.min(vicinity.yIndex, _leadingYIndex!);
      _trailingYIndex = math.max(vicinity.yIndex, _trailingYIndex!);
    }
    if (_needsDelegateRebuild || (!_children.containsKey(vicinity) && !_keepAliveBucket.containsKey(vicinity))) {
      invokeLayoutCallback<BoxConstraints>((BoxConstraints _) {
        _childManager._buildChild(vicinity);
      });
    } else {
      _keepAliveBucket.remove(vicinity);
      _childManager._reuseChild(vicinity);
    }
    if (!_children.containsKey(vicinity)) {
      // There is no child for this vicinity, we may have reached the end of the
      // children in one or both of the x/y indices.
      return null;
    }

    assert(_children.containsKey(vicinity));
    final RenderBox child = _children[vicinity]!;
    _activeChildrenForLayoutPass[vicinity] = child;
    parentDataOf(child).vicinity = vicinity;
    return child;
  }

  void updateChildPaintData(RenderBox child) {
    final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
    assert(
      childParentData.layoutOffset != null,
      'The child with ChildVicinity(xIndex: ${childParentData.vicinity.xIndex}, '
      'yIndex: ${childParentData.vicinity.yIndex}) was not provided a '
      'layoutOffset. This should be set during layoutChildSequence, '
      'representing the position of the child.'
    );
    assert(child.hasSize); // Child must have been laid out by now.

    // Set paintExtent (and visibility)
    childParentData._paintExtent = computeChildPaintExtent(
      childParentData.layoutOffset!,
      child.size,
    );
    // Set paintOffset
    childParentData.paintOffset = computeAbsolutePaintOffsetFor(
      child,
      layoutOffset: childParentData.layoutOffset!,
    );
    // If the child is partially visible, or not visible at all, there is
    // visual overflow.
    _hasVisualOverflow = _hasVisualOverflow
      || childParentData.layoutOffset != childParentData._paintExtent
      || !childParentData.isVisible;
  }

  Size computeChildPaintExtent(Offset layoutOffset, Size childSize) {
    if (childSize == Size.zero || childSize.height == 0.0 || childSize.width == 0.0) {
      return Size.zero;
    }
    // Horizontal extent
    final double width;
    if (layoutOffset.dx < 0.0) {
      // The child is positioned beyond the leading edge of the viewport.
      if (layoutOffset.dx + childSize.width <= 0.0) {
        // The child does not extend into the viewable area, it is not visible.
        return Size.zero;
      }
      // If the child is positioned starting at -50, then the paint extent is
      // the width + (-50).
      width = layoutOffset.dx + childSize.width;
    } else if (layoutOffset.dx >= viewportDimension.width) {
      // The child is positioned after the trailing edge of the viewport, also
      // not visible.
      return Size.zero;
    } else {
      // The child is positioned within the viewport bounds, but may extend
      // beyond it.
      assert(layoutOffset.dx >= 0 && layoutOffset.dx < viewportDimension.width);
      if (layoutOffset.dx + childSize.width > viewportDimension.width) {
        width = viewportDimension.width - layoutOffset.dx;
      } else {
        assert(layoutOffset.dx + childSize.width <= viewportDimension.width);
        width = childSize.width;
      }
    }

    // Vertical extent
    final double height;
    if (layoutOffset.dy < 0.0) {
      // The child is positioned beyond the leading edge of the viewport.
      if (layoutOffset.dy + childSize.height <= 0.0) {
        // The child does not extend into the viewable area, it is not visible.
        return Size.zero;
      }
      // If the child is positioned starting at -50, then the paint extent is
      // the width + (-50).
      height = layoutOffset.dy + childSize.height;
    } else if (layoutOffset.dy >= viewportDimension.height) {
      // The child is positioned after the trailing edge of the viewport, also
      // not visible.
      return Size.zero;
    } else {
      // The child is positioned within the viewport bounds, but may extend
      // beyond it.
      assert(layoutOffset.dy >= 0 && layoutOffset.dy < viewportDimension.height);
      if (layoutOffset.dy + childSize.height > viewportDimension.height) {
        height = viewportDimension.height - layoutOffset.dy;
      } else {
        assert(layoutOffset.dy + childSize.height <= viewportDimension.height);
        height = childSize.height;
      }
    }

    return Size(width, height);
  }

  @protected
  Offset computeAbsolutePaintOffsetFor(
    RenderBox child, {
    required Offset layoutOffset,
  }) {
    // This is only usable once we have sizes.
    assert(hasSize);
    assert(child.hasSize);
    final double xOffset;
    final double yOffset;
    switch (verticalAxisDirection) {
      case AxisDirection.up:
        yOffset = viewportDimension.height - (layoutOffset.dy + child.size.height);
      case AxisDirection.down:
        yOffset = layoutOffset.dy;
      case AxisDirection.right:
      case AxisDirection.left:
        throw Exception('This should not happen');
    }
    switch (horizontalAxisDirection) {
      case AxisDirection.right:
        xOffset = layoutOffset.dx;
      case AxisDirection.left:
        xOffset = viewportDimension.width - (layoutOffset.dx + child.size.width);
      case AxisDirection.up:
      case AxisDirection.down:
        throw Exception('This should not happen');
    }
    return Offset(xOffset, yOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_children.isEmpty) {
      return;
    }
    if (_hasVisualOverflow && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & viewportDimension,
        _paintChildren,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      _paintChildren(context, offset);
    }
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    RenderBox? child = _firstChild;
    while (child != null) {
      final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
      if (childParentData.isVisible) {
        context.paintChild(child, offset + childParentData.paintOffset!);
      }
      child = childParentData._nextSibling;
    }
  }

  // ---- Called from _TwoDimensionalViewportElement ----

  void _insertChild(RenderBox child, ChildVicinity slot) {
    assert(_debugTrackOrphans(newOrphan: _children[slot]));
    assert(!_keepAliveBucket.containsValue(child));
    _children[slot] = child;
    adoptChild(child);
  }

  void _moveChild(RenderBox child, {required ChildVicinity from, required ChildVicinity to}) {
    final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
    if (!childParentData.keptAlive) {
      if (_children[from] == child) {
        _children.remove(from);
      }
      assert(_debugTrackOrphans(newOrphan: _children[to], noLongerOrphan: child));
      _children[to] = child;
      return;
    }
    // If the child in the bucket is not current child, that means someone has
    // already moved and replaced current child, and we cannot remove this
    // child.
    if (_keepAliveBucket[childParentData.vicinity] == child) {
      _keepAliveBucket.remove(childParentData.vicinity);
    }
    assert(() {
      _debugDanglingKeepAlives.remove(child);
      return true;
    }());
    // If there is an existing child in the new slot, that mean that child
    // will be moved to other index. In other cases, the existing child should
    // have been removed by _removeChild. Thus, it is ok to overwrite it.
    assert(() {
      if (_keepAliveBucket.containsKey(childParentData.vicinity)) {
        _debugDanglingKeepAlives.add(_keepAliveBucket[childParentData.vicinity]!);
      }
      return true;
    }());
    _keepAliveBucket[childParentData.vicinity] = child;
  }

  void _removeChild(RenderBox child, ChildVicinity slot) {
    final TwoDimensionalViewportParentData childParentData = parentDataOf(child);
    if (!childParentData.keptAlive) {
      if (_children[slot] == child) {
        _children.remove(slot);
      }
      assert(_debugTrackOrphans(noLongerOrphan: child));
      dropChild(child);
      return;
    }
    assert(_keepAliveBucket[childParentData.vicinity] == child);
    assert(() {
      _debugDanglingKeepAlives.remove(child);
      return true;
    }());
    _keepAliveBucket.remove(childParentData.vicinity);
    dropChild(child);
  }

  List<RenderBox>? _debugOrphans;

  // When a child is inserted into a slot currently occupied by another child,
  // it becomes an orphan until it is either moved to another slot or removed.
  bool _debugTrackOrphans({RenderBox? newOrphan, RenderBox? noLongerOrphan}) {
    assert(() {
      _debugOrphans ??= <RenderBox>[];
      if (newOrphan != null) {
        _debugOrphans!.add(newOrphan);
      }
      if (noLongerOrphan != null) {
        _debugOrphans!.remove(noLongerOrphan);
      }
      return true;
    }());
    return true;
  }

  @protected
  bool debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType does not support returning intrinsic dimensions.'),
          ErrorDescription(
            'Calculating the intrinsic dimensions would require instantiating every child of '
            'the viewport, which defeats the point of viewports being lazy.',
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset paintOffset = parentDataOf(child).paintOffset!;
    transform.translate(paintOffset.dx, paintOffset.dy);
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }
}

abstract class TwoDimensionalChildManager {
  void _startLayout();
  void _buildChild(ChildVicinity vicinity);
  void _reuseChild(ChildVicinity vicinity);
  void _endLayout();
}

@immutable
class ChildVicinity implements Comparable<ChildVicinity> {
  const ChildVicinity({
    required this.xIndex,
    required this.yIndex,
  }) : assert(xIndex >= -1),
       assert(yIndex >= -1);

  static const ChildVicinity invalid = ChildVicinity(xIndex: -1, yIndex: -1);

  final int xIndex;

  final int yIndex;

  @override
  bool operator ==(Object other) {
    return other is ChildVicinity
      && other.xIndex == xIndex
      && other.yIndex == yIndex;
  }

  @override
  int get hashCode => Object.hash(xIndex, yIndex);

  @override
  int compareTo(ChildVicinity other) {
    if (xIndex == other.xIndex) {
      return yIndex - other.yIndex;
    }
    return xIndex - other.xIndex;
  }

  @override
  String toString() {
    return '(xIndex: $xIndex, yIndex: $yIndex)';
  }
}