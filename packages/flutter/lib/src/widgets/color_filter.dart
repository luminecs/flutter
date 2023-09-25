
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';


@immutable
class ColorFiltered extends SingleChildRenderObjectWidget {
  const ColorFiltered({required this.colorFilter, super.child, super.key});

  final ColorFilter colorFilter;

  @override
  RenderObject createRenderObject(BuildContext context) => _ColorFilterRenderObject(colorFilter);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _ColorFilterRenderObject).colorFilter = colorFilter;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ColorFilter>('colorFilter', colorFilter));
  }
}

class _ColorFilterRenderObject extends RenderProxyBox {
  _ColorFilterRenderObject(this._colorFilter);

  ColorFilter get colorFilter => _colorFilter;
  ColorFilter _colorFilter;
  set colorFilter(ColorFilter value) {
    if (value != _colorFilter) {
      _colorFilter = value;
      markNeedsPaint();
    }
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    layer = context.pushColorFilter(offset, colorFilter, super.paint, oldLayer: layer as ColorFilterLayer?);
    assert(() {
      layer!.debugCreator = debugCreator;
      return true;
    }());
  }
}