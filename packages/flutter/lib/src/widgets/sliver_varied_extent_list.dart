
import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'scroll_delegate.dart';
import 'sliver.dart';

class SliverVariedExtentList extends SliverMultiBoxAdaptorWidget {
  const SliverVariedExtentList({
    super.key,
    required super.delegate,
    required this.itemExtentBuilder,
  });

  SliverVariedExtentList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    required this.itemExtentBuilder,
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

  SliverVariedExtentList.list({
    super.key,
    required List<Widget> children,
    required this.itemExtentBuilder,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  }) : super(delegate: SliverChildListDelegate(
    children,
    addAutomaticKeepAlives: addAutomaticKeepAlives,
    addRepaintBoundaries: addRepaintBoundaries,
    addSemanticIndexes: addSemanticIndexes,
  ));

  final ItemExtentBuilder itemExtentBuilder;

  @override
  RenderSliverVariedExtentList createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverVariedExtentList(childManager: element, itemExtentBuilder: itemExtentBuilder);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverVariedExtentList renderObject) {
    renderObject.itemExtentBuilder = itemExtentBuilder;
  }
}

class RenderSliverVariedExtentList extends RenderSliverFixedExtentBoxAdaptor {
  RenderSliverVariedExtentList({
    required super.childManager,
    required ItemExtentBuilder itemExtentBuilder,
  }) : _itemExtentBuilder = itemExtentBuilder;

  @override
  ItemExtentBuilder get itemExtentBuilder => _itemExtentBuilder;
  ItemExtentBuilder _itemExtentBuilder;
  set itemExtentBuilder(ItemExtentBuilder value) {
    if (_itemExtentBuilder == value) {
      return;
    }
    _itemExtentBuilder = value;
    markNeedsLayout();
  }

  @override
  double? get itemExtent => null;
}