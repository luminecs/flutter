import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'scroll_delegate.dart';
import 'sliver.dart';

class SliverPrototypeExtentList extends SliverMultiBoxAdaptorWidget {
  const SliverPrototypeExtentList({
    super.key,
    required super.delegate,
    required this.prototypeItem,
  });

  SliverPrototypeExtentList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    required this.prototypeItem,
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

  SliverPrototypeExtentList.list({
    super.key,
    required List<Widget> children,
    required this.prototypeItem,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildListDelegate(
         children,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,
         addSemanticIndexes: addSemanticIndexes,
       ));

  final Widget prototypeItem;

  @override
  RenderSliverMultiBoxAdaptor createRenderObject(BuildContext context) {
    final _SliverPrototypeExtentListElement element = context as _SliverPrototypeExtentListElement;
    return _RenderSliverPrototypeExtentList(childManager: element);
  }

  @override
  SliverMultiBoxAdaptorElement createElement() => _SliverPrototypeExtentListElement(this);
}

class _SliverPrototypeExtentListElement extends SliverMultiBoxAdaptorElement {
  _SliverPrototypeExtentListElement(SliverPrototypeExtentList super.widget);

  @override
  _RenderSliverPrototypeExtentList get renderObject => super.renderObject as _RenderSliverPrototypeExtentList;

  Element? _prototype;
  static final Object _prototypeSlot = Object();

  @override
  void insertRenderObjectChild(covariant RenderObject child, covariant Object slot) {
    if (slot == _prototypeSlot) {
      assert(child is RenderBox);
      renderObject.child = child as RenderBox;
    } else {
      super.insertRenderObjectChild(child, slot as int);
    }
  }

  @override
  void didAdoptChild(RenderBox child) {
    if (child != renderObject.child) {
      super.didAdoptChild(child);
    }
  }

  @override
  void moveRenderObjectChild(RenderBox child, Object oldSlot, Object newSlot) {
    if (newSlot == _prototypeSlot) {
      // There's only one prototype child so it cannot be moved.
      assert(false);
    } else {
      super.moveRenderObjectChild(child, oldSlot as int, newSlot as int);
    }
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object slot) {
    if (renderObject.child == child) {
      renderObject.child = null;
    } else {
      super.removeRenderObjectChild(child, slot as int);
    }
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_prototype != null) {
      visitor(_prototype!);
    }
    super.visitChildren(visitor);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _prototype = updateChild(_prototype, (widget as SliverPrototypeExtentList).prototypeItem, _prototypeSlot);
  }

  @override
  void update(SliverPrototypeExtentList newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _prototype = updateChild(_prototype, (widget as SliverPrototypeExtentList).prototypeItem, _prototypeSlot);
  }
}

class _RenderSliverPrototypeExtentList extends RenderSliverFixedExtentBoxAdaptor {
  _RenderSliverPrototypeExtentList({
    required _SliverPrototypeExtentListElement childManager,
  }) : super(childManager: childManager);

  RenderBox? _child;
  RenderBox? get child => _child;
  set child(RenderBox? value) {
    if (_child != null) {
      dropChild(_child!);
    }
    _child = value;
    if (_child != null) {
      adoptChild(_child!);
    }
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    super.performLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_child != null) {
      _child!.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    if (_child != null) {
      _child!.detach();
    }
  }

  @override
  void redepthChildren() {
    if (_child != null) {
      redepthChild(_child!);
    }
    super.redepthChildren();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
    super.visitChildren(visitor);
  }

  @override
  double get itemExtent {
    assert(child != null && child!.hasSize);
    return constraints.axis == Axis.vertical ? child!.size.height : child!.size.width;
  }
}