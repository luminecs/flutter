import 'object.dart';
import 'proxy_box.dart';
import 'proxy_sliver.dart';
import 'sliver.dart';

class RenderDecoratedSliver extends RenderProxySliver {
  RenderDecoratedSliver({
    required Decoration decoration,
    DecorationPosition position = DecorationPosition.background,
    ImageConfiguration configuration = ImageConfiguration.empty,
  })  : _decoration = decoration,
        _position = position,
        _configuration = configuration;

  Decoration get decoration => _decoration;
  Decoration _decoration;
  set decoration(Decoration value) {
    if (value == decoration) {
      return;
    }
    _decoration = value;
    _painter?.dispose();
    _painter = decoration.createBoxPainter(markNeedsPaint);
    markNeedsPaint();
  }

  DecorationPosition get position => _position;
  DecorationPosition _position;
  set position(DecorationPosition value) {
    if (value == position) {
      return;
    }
    _position = value;
    markNeedsPaint();
  }

  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == configuration) {
      return;
    }
    _configuration = value;
    markNeedsPaint();
  }

  BoxPainter? _painter;

  @override
  void attach(covariant PipelineOwner owner) {
    _painter = decoration.createBoxPainter(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && child!.geometry!.visible) {
      final SliverPhysicalParentData childParentData =
          child!.parentData! as SliverPhysicalParentData;
      final Size childSize;
      final Offset scrollOffset;

      // In the case where the child sliver has infinite scroll extent, the decoration
      // should only extend down to the bottom cache extent.
      final double cappedMainAxisExtent =
          child!.geometry!.scrollExtent.isInfinite
              ? constraints.scrollOffset +
                  child!.geometry!.cacheExtent +
                  constraints.cacheOrigin
              : child!.geometry!.scrollExtent;
      switch (constraints.axis) {
        case Axis.vertical:
          childSize = Size(constraints.crossAxisExtent, cappedMainAxisExtent);
          scrollOffset = Offset(0.0, -constraints.scrollOffset);
        case Axis.horizontal:
          childSize = Size(cappedMainAxisExtent, constraints.crossAxisExtent);
          scrollOffset = Offset(-constraints.scrollOffset, 0.0);
      }
      final Offset childOffset = offset + childParentData.paintOffset;
      if (position == DecorationPosition.background) {
        _painter!.paint(context.canvas, childOffset + scrollOffset,
            configuration.copyWith(size: childSize));
      }
      context.paintChild(child!, childOffset);
      if (position == DecorationPosition.foreground) {
        _painter!.paint(context.canvas, childOffset + scrollOffset,
            configuration.copyWith(size: childSize));
      }
    }
  }
}
