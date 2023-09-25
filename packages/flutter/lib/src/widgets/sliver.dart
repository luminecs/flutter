import 'dart:collection' show HashMap, SplayTreeMap;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'automatic_keep_alive.dart';
import 'basic.dart';
import 'framework.dart';
import 'scroll_delegate.dart';

abstract class SliverWithKeepAliveWidget extends RenderObjectWidget {
  const SliverWithKeepAliveWidget({
    super.key,
  });

  @override
  RenderSliverWithKeepAliveMixin createRenderObject(BuildContext context);
}

abstract class SliverMultiBoxAdaptorWidget extends SliverWithKeepAliveWidget {
  const SliverMultiBoxAdaptorWidget({
    super.key,
    required this.delegate,
  });

  final SliverChildDelegate delegate;

  @override
  SliverMultiBoxAdaptorElement createElement() => SliverMultiBoxAdaptorElement(this);

  @override
  RenderSliverMultiBoxAdaptor createRenderObject(BuildContext context);

  double? estimateMaxScrollOffset(
    SliverConstraints? constraints,
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    assert(lastIndex >= firstIndex);
    return delegate.estimateMaxScrollOffset(
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SliverChildDelegate>('delegate', delegate));
  }
}

class SliverList extends SliverMultiBoxAdaptorWidget {
  const SliverList({
    super.key,
    required super.delegate,
  });

  SliverList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildBuilderDelegate(
         itemBuilder,
         findChildIndexCallback: findChildIndexCallback,
         childCount: itemCount,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
       ));

  SliverList.separated({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    required NullableIndexedWidgetBuilder separatorBuilder,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildBuilderDelegate(
         (BuildContext context, int index) {
           final int itemIndex = index ~/ 2;
           final Widget? widget;
           if (index.isEven) {
             widget = itemBuilder(context, itemIndex);
           } else {
             widget = separatorBuilder(context, itemIndex);
             assert(() {
               if (widget == null) {
                 throw FlutterError('separatorBuilder cannot return null.');
               }
               return true;
             }());
           }
           return widget;
         },
         findChildIndexCallback: findChildIndexCallback,
         childCount: itemCount == null ? null : math.max(0, itemCount * 2 - 1),
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
         semanticIndexCallback: (Widget _, int index) {
           return index.isEven ? index ~/ 2 : null;
         },
       ));

  SliverList.list({
    super.key,
    required List<Widget> children,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildListDelegate(
         children,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
       ));

  @override
  SliverMultiBoxAdaptorElement createElement() => SliverMultiBoxAdaptorElement(this, replaceMovedChildren: true);

  @override
  RenderSliverList createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverList(childManager: element);
  }
}

class SliverFixedExtentList extends SliverMultiBoxAdaptorWidget {
  const SliverFixedExtentList({
    super.key,
    required super.delegate,
    required this.itemExtent,
  });

  SliverFixedExtentList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    required this.itemExtent,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildBuilderDelegate(
         itemBuilder,
         findChildIndexCallback: findChildIndexCallback,
         childCount: itemCount,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
       ));

  SliverFixedExtentList.list({
    super.key,
    required List<Widget> children,
    required this.itemExtent,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildListDelegate(
         children,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
       ));

  final double itemExtent;

  @override
  RenderSliverFixedExtentList createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverFixedExtentList(childManager: element, itemExtent: itemExtent);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverFixedExtentList renderObject) {
    renderObject.itemExtent = itemExtent;
  }
}

class SliverGrid extends SliverMultiBoxAdaptorWidget {
  const SliverGrid({
    super.key,
    required super.delegate,
    required this.gridDelegate,
  });

  SliverGrid.builder({
    super.key,
    required this.gridDelegate,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildBuilderDelegate(
         itemBuilder,
         findChildIndexCallback: findChildIndexCallback,
         childCount: itemCount,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
       ));

  SliverGrid.count({
    super.key,
    required int crossAxisCount,
    double mainAxisSpacing = 0.0,
    double crossAxisSpacing = 0.0,
    double childAspectRatio = 1.0,
    List<Widget> children = const <Widget>[],
  }) : gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
         crossAxisCount: crossAxisCount,
         mainAxisSpacing: mainAxisSpacing,
         crossAxisSpacing: crossAxisSpacing,
         childAspectRatio: childAspectRatio,
       ),
       super(delegate: SliverChildListDelegate(children));

  SliverGrid.extent({
    super.key,
    required double maxCrossAxisExtent,
    double mainAxisSpacing = 0.0,
    double crossAxisSpacing = 0.0,
    double childAspectRatio = 1.0,
    List<Widget> children = const <Widget>[],
  }) : gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
         maxCrossAxisExtent: maxCrossAxisExtent,
         mainAxisSpacing: mainAxisSpacing,
         crossAxisSpacing: crossAxisSpacing,
         childAspectRatio: childAspectRatio,
       ),
       super(delegate: SliverChildListDelegate(children));

  final SliverGridDelegate gridDelegate;

  @override
  RenderSliverGrid createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverGrid(childManager: element, gridDelegate: gridDelegate);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverGrid renderObject) {
    renderObject.gridDelegate = gridDelegate;
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints? constraints,
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    return super.estimateMaxScrollOffset(
      constraints,
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
    ) ?? gridDelegate.getLayout(constraints!).computeMaxScrollOffset(delegate.estimatedChildCount!);
  }
}

class SliverMultiBoxAdaptorElement extends RenderObjectElement implements RenderSliverBoxChildManager {
  SliverMultiBoxAdaptorElement(SliverMultiBoxAdaptorWidget super.widget, {bool replaceMovedChildren = false})
     : _replaceMovedChildren = replaceMovedChildren;

  final bool _replaceMovedChildren;

  @override
  RenderSliverMultiBoxAdaptor get renderObject => super.renderObject as RenderSliverMultiBoxAdaptor;

  @override
  void update(covariant SliverMultiBoxAdaptorWidget newWidget) {
    final SliverMultiBoxAdaptorWidget oldWidget = widget as SliverMultiBoxAdaptorWidget;
    super.update(newWidget);
    final SliverChildDelegate newDelegate = newWidget.delegate;
    final SliverChildDelegate oldDelegate = oldWidget.delegate;
    if (newDelegate != oldDelegate &&
        (newDelegate.runtimeType != oldDelegate.runtimeType || newDelegate.shouldRebuild(oldDelegate))) {
      performRebuild();
    }
  }

  final SplayTreeMap<int, Element?> _childElements = SplayTreeMap<int, Element?>();
  RenderBox? _currentBeforeChild;

  @override
  void performRebuild() {
    super.performRebuild();
    _currentBeforeChild = null;
    bool childrenUpdated = false;
    assert(_currentlyUpdatingChildIndex == null);
    try {
      final SplayTreeMap<int, Element?> newChildren = SplayTreeMap<int, Element?>();
      final Map<int, double> indexToLayoutOffset = HashMap<int, double>();
      final SliverMultiBoxAdaptorWidget adaptorWidget = widget as SliverMultiBoxAdaptorWidget;
      void processElement(int index) {
        _currentlyUpdatingChildIndex = index;
        if (_childElements[index] != null && _childElements[index] != newChildren[index]) {
          // This index has an old child that isn't used anywhere and should be deactivated.
          _childElements[index] = updateChild(_childElements[index], null, index);
          childrenUpdated = true;
        }
        final Element? newChild = updateChild(newChildren[index], _build(index, adaptorWidget), index);
        if (newChild != null) {
          childrenUpdated = childrenUpdated || _childElements[index] != newChild;
          _childElements[index] = newChild;
          final SliverMultiBoxAdaptorParentData parentData = newChild.renderObject!.parentData! as SliverMultiBoxAdaptorParentData;
          if (index == 0) {
            parentData.layoutOffset = 0.0;
          } else if (indexToLayoutOffset.containsKey(index)) {
            parentData.layoutOffset = indexToLayoutOffset[index];
          }
          if (!parentData.keptAlive) {
            _currentBeforeChild = newChild.renderObject as RenderBox?;
          }
        } else {
          childrenUpdated = true;
          _childElements.remove(index);
        }
      }
      for (final int index in _childElements.keys.toList()) {
        final Key? key = _childElements[index]!.widget.key;
        final int? newIndex = key == null ? null : adaptorWidget.delegate.findIndexByKey(key);
        final SliverMultiBoxAdaptorParentData? childParentData =
          _childElements[index]!.renderObject?.parentData as SliverMultiBoxAdaptorParentData?;

        if (childParentData != null && childParentData.layoutOffset != null) {
          indexToLayoutOffset[index] = childParentData.layoutOffset!;
        }

        if (newIndex != null && newIndex != index) {
          // The layout offset of the child being moved is no longer accurate.
          if (childParentData != null) {
            childParentData.layoutOffset = null;
          }

          newChildren[newIndex] = _childElements[index];
          if (_replaceMovedChildren) {
            // We need to make sure the original index gets processed.
            newChildren.putIfAbsent(index, () => null);
          }
          // We do not want the remapped child to get deactivated during processElement.
          _childElements.remove(index);
        } else {
          newChildren.putIfAbsent(index, () => _childElements[index]);
        }
      }

      renderObject.debugChildIntegrityEnabled = false; // Moving children will temporary violate the integrity.
      newChildren.keys.forEach(processElement);
      // An element rebuild only updates existing children. The underflow check
      // is here to make sure we look ahead one more child if we were at the end
      // of the child list before the update. By doing so, we can update the max
      // scroll offset during the layout phase. Otherwise, the layout phase may
      // be skipped, and the scroll view may be stuck at the previous max
      // scroll offset.
      //
      // This logic is not needed if any existing children has been updated,
      // because we will not skip the layout phase if that happens.
      if (!childrenUpdated && _didUnderflow) {
        final int lastKey = _childElements.lastKey() ?? -1;
        final int rightBoundary = lastKey + 1;
        newChildren[rightBoundary] = _childElements[rightBoundary];
        processElement(rightBoundary);
      }
    } finally {
      _currentlyUpdatingChildIndex = null;
      renderObject.debugChildIntegrityEnabled = true;
    }
  }

  Widget? _build(int index, SliverMultiBoxAdaptorWidget widget) {
    return widget.delegate.build(this, index);
  }

  @override
  void createChild(int index, { required RenderBox? after }) {
    assert(_currentlyUpdatingChildIndex == null);
    owner!.buildScope(this, () {
      final bool insertFirst = after == null;
      assert(insertFirst || _childElements[index-1] != null);
      _currentBeforeChild = insertFirst ? null : (_childElements[index-1]!.renderObject as RenderBox?);
      Element? newChild;
      try {
        final SliverMultiBoxAdaptorWidget adaptorWidget = widget as SliverMultiBoxAdaptorWidget;
        _currentlyUpdatingChildIndex = index;
        newChild = updateChild(_childElements[index], _build(index, adaptorWidget), index);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
    });
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    final SliverMultiBoxAdaptorParentData? oldParentData = child?.renderObject?.parentData as SliverMultiBoxAdaptorParentData?;
    final Element? newChild = super.updateChild(child, newWidget, newSlot);
    final SliverMultiBoxAdaptorParentData? newParentData = newChild?.renderObject?.parentData as SliverMultiBoxAdaptorParentData?;

    // Preserve the old layoutOffset if the renderObject was swapped out.
    if (oldParentData != newParentData && oldParentData != null && newParentData != null) {
      newParentData.layoutOffset = oldParentData.layoutOffset;
    }
    return newChild;
  }

  @override
  void forgetChild(Element child) {
    assert(child.slot != null);
    assert(_childElements.containsKey(child.slot));
    _childElements.remove(child.slot);
    super.forgetChild(child);
  }

  @override
  void removeChild(RenderBox child) {
    final int index = renderObject.indexOf(child);
    assert(_currentlyUpdatingChildIndex == null);
    assert(index >= 0);
    owner!.buildScope(this, () {
      assert(_childElements.containsKey(index));
      try {
        _currentlyUpdatingChildIndex = index;
        final Element? result = updateChild(_childElements[index], null, index);
        assert(result == null);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      _childElements.remove(index);
      assert(!_childElements.containsKey(index));
    });
  }

  static double _extrapolateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
    int childCount,
  ) {
    if (lastIndex == childCount - 1) {
      return trailingScrollOffset;
    }
    final int reifiedCount = lastIndex - firstIndex + 1;
    final double averageExtent = (trailingScrollOffset - leadingScrollOffset) / reifiedCount;
    final int remainingCount = childCount - lastIndex - 1;
    return trailingScrollOffset + averageExtent * remainingCount;
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints? constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    final int? childCount = estimatedChildCount;
    if (childCount == null) {
      return double.infinity;
    }
    return (widget as SliverMultiBoxAdaptorWidget).estimateMaxScrollOffset(
      constraints,
      firstIndex!,
      lastIndex!,
      leadingScrollOffset!,
      trailingScrollOffset!,
    ) ?? _extrapolateMaxScrollOffset(
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
      childCount,
    );
  }

  int? get estimatedChildCount => (widget as SliverMultiBoxAdaptorWidget).delegate.estimatedChildCount;

  @override
  int get childCount {
    int? result = estimatedChildCount;
    if (result == null) {
      // Since childCount was called, we know that we reached the end of
      // the list (as in, _build return null once), so we know that the
      // list is finite.
      // Let's do an open-ended binary search to find the end of the list
      // manually.
      int lo = 0;
      int hi = 1;
      final SliverMultiBoxAdaptorWidget adaptorWidget = widget as SliverMultiBoxAdaptorWidget;
      const int max = kIsWeb
        ? 9007199254740992 // max safe integer on JS (from 0 to this number x != x+1)
        : ((1 << 63) - 1);
      while (_build(hi - 1, adaptorWidget) != null) {
        lo = hi - 1;
        if (hi < max ~/ 2) {
          hi *= 2;
        } else if (hi < max) {
          hi = max;
        } else {
          throw FlutterError(
            'Could not find the number of children in ${adaptorWidget.delegate}.\n'
            "The childCount getter was called (implying that the delegate's builder returned null "
            'for a positive index), but even building the child with index $hi (the maximum '
            'possible integer) did not return null. Consider implementing childCount to avoid '
            'the cost of searching for the final child.',
          );
        }
      }
      while (hi - lo > 1) {
        final int mid = (hi - lo) ~/ 2 + lo;
        if (_build(mid - 1, adaptorWidget) == null) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      result = lo;
    }
    return result;
  }

  @override
  void didStartLayout() {
    assert(debugAssertChildListLocked());
  }

  @override
  void didFinishLayout() {
    assert(debugAssertChildListLocked());
    final int firstIndex = _childElements.firstKey() ?? 0;
    final int lastIndex = _childElements.lastKey() ?? 0;
    (widget as SliverMultiBoxAdaptorWidget).delegate.didFinishLayout(firstIndex, lastIndex);
  }

  int? _currentlyUpdatingChildIndex;

  @override
  bool debugAssertChildListLocked() {
    assert(_currentlyUpdatingChildIndex == null);
    return true;
  }

  @override
  void didAdoptChild(RenderBox child) {
    assert(_currentlyUpdatingChildIndex != null);
    final SliverMultiBoxAdaptorParentData childParentData = child.parentData! as SliverMultiBoxAdaptorParentData;
    childParentData.index = _currentlyUpdatingChildIndex;
  }

  bool _didUnderflow = false;

  @override
  void setDidUnderflow(bool value) {
    _didUnderflow = value;
  }

  @override
  void insertRenderObjectChild(covariant RenderObject child, int slot) {
    assert(_currentlyUpdatingChildIndex == slot);
    assert(renderObject.debugValidateChild(child));
    renderObject.insert(child as RenderBox, after: _currentBeforeChild);
    assert(() {
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData! as SliverMultiBoxAdaptorParentData;
      assert(slot == childParentData.index);
      return true;
    }());
  }

  @override
  void moveRenderObjectChild(covariant RenderObject child, int oldSlot, int newSlot) {
    assert(_currentlyUpdatingChildIndex == newSlot);
    renderObject.move(child as RenderBox, after: _currentBeforeChild);
  }

  @override
  void removeRenderObjectChild(covariant RenderObject child, int slot) {
    assert(_currentlyUpdatingChildIndex != null);
    renderObject.remove(child as RenderBox);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    // The toList() is to make a copy so that the underlying list can be modified by
    // the visitor:
    assert(!_childElements.values.any((Element? child) => child == null));
    _childElements.values.cast<Element>().toList().forEach(visitor);
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    _childElements.values.cast<Element>().where((Element child) {
      final SliverMultiBoxAdaptorParentData parentData = child.renderObject!.parentData! as SliverMultiBoxAdaptorParentData;
      final double itemExtent;
      switch (renderObject.constraints.axis) {
        case Axis.horizontal:
          itemExtent = child.renderObject!.paintBounds.width;
        case Axis.vertical:
          itemExtent = child.renderObject!.paintBounds.height;
      }

      return parentData.layoutOffset != null &&
          parentData.layoutOffset! < renderObject.constraints.scrollOffset + renderObject.constraints.remainingPaintExtent &&
          parentData.layoutOffset! + itemExtent > renderObject.constraints.scrollOffset;
    }).forEach(visitor);
  }
}

class SliverOpacity extends SingleChildRenderObjectWidget {
  const SliverOpacity({
    super.key,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    Widget? sliver,
  }) : assert(opacity >= 0.0 && opacity <= 1.0),
       super(child: sliver);

  final double opacity;

  final bool alwaysIncludeSemantics;

  @override
  RenderSliverOpacity createRenderObject(BuildContext context) {
    return RenderSliverOpacity(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverOpacity renderObject) {
    renderObject
      ..opacity = opacity
      ..alwaysIncludeSemantics = alwaysIncludeSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<double>('opacity', opacity));
    properties.add(FlagProperty(
      'alwaysIncludeSemantics',
      value: alwaysIncludeSemantics,
      ifTrue: 'alwaysIncludeSemantics',
    ));
  }
}

class SliverIgnorePointer extends SingleChildRenderObjectWidget {
  const SliverIgnorePointer({
    super.key,
    this.ignoring = true,
    @Deprecated(
      'Create a custom sliver ignore pointer widget instead. '
      'This feature was deprecated after v3.8.0-12.0.pre.'
    )
    this.ignoringSemantics,
    Widget? sliver,
  }) : super(child: sliver);

  final bool ignoring;

  @Deprecated(
    'Create a custom sliver ignore pointer widget instead. '
    'This feature was deprecated after v3.8.0-12.0.pre.'
  )
  final bool? ignoringSemantics;

  @override
  RenderSliverIgnorePointer createRenderObject(BuildContext context) {
    return RenderSliverIgnorePointer(
      ignoring: ignoring,
      ignoringSemantics: ignoringSemantics,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverIgnorePointer renderObject) {
    renderObject
      ..ignoring = ignoring
      ..ignoringSemantics = ignoringSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('ignoring', ignoring));
    properties.add(DiagnosticsProperty<bool>('ignoringSemantics', ignoringSemantics, defaultValue: null));
  }
}

class SliverOffstage extends SingleChildRenderObjectWidget {
  const SliverOffstage({
    super.key,
    this.offstage = true,
    Widget? sliver,
  }) : super(child: sliver);

  final bool offstage;

  @override
  RenderSliverOffstage createRenderObject(BuildContext context) => RenderSliverOffstage(offstage: offstage);

  @override
  void updateRenderObject(BuildContext context, RenderSliverOffstage renderObject) {
    renderObject.offstage = offstage;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('offstage', offstage));
  }

  @override
  SingleChildRenderObjectElement createElement() => _SliverOffstageElement(this);
}

class _SliverOffstageElement extends SingleChildRenderObjectElement {
  _SliverOffstageElement(SliverOffstage super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if (!(widget as SliverOffstage).offstage) {
      super.debugVisitOnstageChildren(visitor);
    }
  }
}

class KeepAlive extends ParentDataWidget<KeepAliveParentDataMixin> {
  const KeepAlive({
    super.key,
    required this.keepAlive,
    required super.child,
  });

  final bool keepAlive;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is KeepAliveParentDataMixin);
    final KeepAliveParentDataMixin parentData = renderObject.parentData! as KeepAliveParentDataMixin;
    if (parentData.keepAlive != keepAlive) {
      // No need to redo layout if it became true.
      parentData.keepAlive = keepAlive;
      final RenderObject? targetParent = renderObject.parent;
      if (targetParent is RenderObject && !keepAlive) {
        targetParent.markNeedsLayout();
      }
    }
  }

  // We only return true if [keepAlive] is true, because turning _off_ keep
  // alive requires a layout to do the garbage collection (but turning it on
  // requires nothing, since by definition the widget is already alive and won't
  // go away _unless_ we do a layout).
  @override
  bool debugCanApplyOutOfTurn() => keepAlive;

  @override
  Type get debugTypicalAncestorWidgetClass => throw FlutterError('Multiple Types are supported, use debugTypicalAncestorWidgetDescription.');

  @override
  String get debugTypicalAncestorWidgetDescription => 'SliverWithKeepAliveWidget or TwoDimensionalViewport';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('keepAlive', keepAlive));
  }
}

class SliverConstrainedCrossAxis extends StatelessWidget {
  const SliverConstrainedCrossAxis({
    super.key,
    required this.maxExtent,
    required this.sliver,
  });

  final double maxExtent;

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return _SliverZeroFlexParentDataWidget(
      sliver: _SliverConstrainedCrossAxis(
        maxExtent: maxExtent,
        sliver: sliver,
      )
    );
  }
}
class _SliverZeroFlexParentDataWidget extends ParentDataWidget<SliverPhysicalParentData> {
  const _SliverZeroFlexParentDataWidget({
    required Widget sliver,
  }) : super(child: sliver);

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is SliverPhysicalParentData);
    final SliverPhysicalParentData parentData = renderObject.parentData! as SliverPhysicalParentData;
    bool needsLayout = false;
    if (parentData.crossAxisFlex != 0) {
      parentData.crossAxisFlex = 0;
      needsLayout = true;
    }

    if (needsLayout) {
      final RenderObject? targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }

    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => SliverCrossAxisGroup;
}

class _SliverConstrainedCrossAxis extends SingleChildRenderObjectWidget {
  const _SliverConstrainedCrossAxis({
    required this.maxExtent,
    required Widget sliver,
  }) : assert(maxExtent >= 0.0),
       super(child: sliver);

  final double maxExtent;

  @override
  RenderSliverConstrainedCrossAxis createRenderObject(BuildContext context) {
    return RenderSliverConstrainedCrossAxis(maxExtent: maxExtent);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverConstrainedCrossAxis renderObject) {
    renderObject.maxExtent = maxExtent;
  }
}

class SliverCrossAxisExpanded extends ParentDataWidget<SliverPhysicalContainerParentData> {
  const SliverCrossAxisExpanded({
    super.key,
    required this.flex,
    required Widget sliver,
  }): assert(flex > 0 && flex < double.infinity),
      super(child: sliver);

  final int flex;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is SliverPhysicalContainerParentData);
    assert(renderObject.parent is RenderSliverCrossAxisGroup);
    final SliverPhysicalParentData parentData = renderObject.parentData! as SliverPhysicalParentData;
    bool needsLayout = false;

    if (parentData.crossAxisFlex != flex) {
      parentData.crossAxisFlex = flex;
      needsLayout = true;
    }

    if (needsLayout) {
      final RenderObject? targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => SliverCrossAxisGroup;
}


class SliverCrossAxisGroup extends MultiChildRenderObjectWidget {
  const SliverCrossAxisGroup({
    super.key,
    required List<Widget> slivers,
  }): super(children: slivers);

  @override
  RenderSliverCrossAxisGroup createRenderObject(BuildContext context) {
    return RenderSliverCrossAxisGroup();
  }
}

class SliverMainAxisGroup extends MultiChildRenderObjectWidget {
  const SliverMainAxisGroup({
    super.key,
    required List<Widget> slivers,
  }) : super(children: slivers);

  @override
  RenderSliverMainAxisGroup createRenderObject(BuildContext context) {
    return RenderSliverMainAxisGroup();
  }
}