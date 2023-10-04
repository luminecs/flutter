import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'layout_builder.dart';

typedef SliverLayoutWidgetBuilder = Widget Function(
    BuildContext context, SliverConstraints constraints);

class SliverLayoutBuilder extends ConstrainedLayoutBuilder<SliverConstraints> {
  const SliverLayoutBuilder({
    super.key,
    required super.builder,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverLayoutBuilder();
}

class _RenderSliverLayoutBuilder extends RenderSliver
    with
        RenderObjectWithChildMixin<RenderSliver>,
        RenderConstrainedLayoutBuilder<SliverConstraints, RenderSliver> {
  @override
  double childMainAxisPosition(RenderObject child) {
    assert(child == this.child);
    return 0;
  }

  @override
  void performLayout() {
    rebuildIfNecessary();
    child?.layout(constraints, parentUsesSize: true);
    geometry = child?.geometry ?? SliverGeometry.zero;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child == this.child);
    // child's offset is always (0, 0), transform.translate(0, 0) does not mutate the transform.
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // This renderObject does not introduce additional offset to child's position.
    if (child?.geometry?.visible ?? false) {
      context.paintChild(child!, offset);
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    return child != null &&
        child!.geometry!.hitTestExtent > 0 &&
        child!.hitTest(result,
            mainAxisPosition: mainAxisPosition,
            crossAxisPosition: crossAxisPosition);
  }
}
