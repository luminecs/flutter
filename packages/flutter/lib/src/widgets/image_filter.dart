import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';

@immutable
class ImageFiltered extends SingleChildRenderObjectWidget {
  const ImageFiltered({
    super.key,
    required this.imageFilter,
    super.child,
    this.enabled = true,
  });

  final ImageFilter imageFilter;

  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) => _ImageFilterRenderObject(imageFilter, enabled);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _ImageFilterRenderObject)
      ..enabled = enabled
      ..imageFilter = imageFilter;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageFilter>('imageFilter', imageFilter));
  }
}

class _ImageFilterRenderObject extends RenderProxyBox {
  _ImageFilterRenderObject(this._imageFilter, this._enabled);

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (enabled == value) {
      return;
    }
    final bool wasRepaintBoundary = isRepaintBoundary;
    _enabled = value;
    if (isRepaintBoundary != wasRepaintBoundary) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  ImageFilter get imageFilter => _imageFilter;
  ImageFilter _imageFilter;
  set imageFilter(ImageFilter value) {
    if (value != _imageFilter) {
      _imageFilter = value;
      markNeedsCompositedLayerUpdate();
    }
  }

  @override
  bool get alwaysNeedsCompositing => child != null && enabled;

   @override
  bool get isRepaintBoundary => alwaysNeedsCompositing;

  @override
  OffsetLayer updateCompositedLayer({required covariant ImageFilterLayer? oldLayer}) {
    final ImageFilterLayer layer = oldLayer ?? ImageFilterLayer();
    layer.imageFilter = imageFilter;
    return layer;
  }
}