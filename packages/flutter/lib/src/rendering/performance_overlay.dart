import 'box.dart';
import 'layer.dart';
import 'object.dart';

enum PerformanceOverlayOption {
  // these must be in the order needed for their index values to match the
  // constants in //engine/src/sky/compositor/performance_overlay_layer.h

  displayRasterizerStatistics,

  visualizeRasterizerStatistics,

  displayEngineStatistics,

  visualizeEngineStatistics,
}

class RenderPerformanceOverlay extends RenderBox {
  RenderPerformanceOverlay({
    int optionsMask = 0,
    int rasterizerThreshold = 0,
    bool checkerboardRasterCacheImages = false,
    bool checkerboardOffscreenLayers = false,
  }) : _optionsMask = optionsMask,
       _rasterizerThreshold = rasterizerThreshold,
       _checkerboardRasterCacheImages = checkerboardRasterCacheImages,
       _checkerboardOffscreenLayers = checkerboardOffscreenLayers;

  int get optionsMask => _optionsMask;
  int _optionsMask;
  set optionsMask(int value) {
    if (value == _optionsMask) {
      return;
    }
    _optionsMask = value;
    markNeedsPaint();
  }

  int get rasterizerThreshold => _rasterizerThreshold;
  int _rasterizerThreshold;
  set rasterizerThreshold(int value) {
    if (value == _rasterizerThreshold) {
      return;
    }
    _rasterizerThreshold = value;
    markNeedsPaint();
  }

  bool get checkerboardRasterCacheImages => _checkerboardRasterCacheImages;
  bool _checkerboardRasterCacheImages;
  set checkerboardRasterCacheImages(bool value) {
    if (value == _checkerboardRasterCacheImages) {
      return;
    }
    _checkerboardRasterCacheImages = value;
    markNeedsPaint();
  }

  bool get checkerboardOffscreenLayers => _checkerboardOffscreenLayers;
  bool _checkerboardOffscreenLayers;
  set checkerboardOffscreenLayers(bool value) {
    if (value == _checkerboardOffscreenLayers) {
      return;
    }
    _checkerboardOffscreenLayers = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  double computeMinIntrinsicWidth(double height) {
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return 0.0;
  }

  double get _intrinsicHeight {
    const double kDefaultGraphHeight = 80.0;
    double result = 0.0;
    if ((optionsMask | (1 << PerformanceOverlayOption.displayRasterizerStatistics.index) > 0) ||
        (optionsMask | (1 << PerformanceOverlayOption.visualizeRasterizerStatistics.index) > 0)) {
      result += kDefaultGraphHeight;
    }
    if ((optionsMask | (1 << PerformanceOverlayOption.displayEngineStatistics.index) > 0) ||
        (optionsMask | (1 << PerformanceOverlayOption.visualizeEngineStatistics.index) > 0)) {
      result += kDefaultGraphHeight;
    }
    return result;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _intrinsicHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _intrinsicHeight;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(Size(double.infinity, _intrinsicHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(needsCompositing);
    context.addLayer(PerformanceOverlayLayer(
      overlayRect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
      optionsMask: optionsMask,
      rasterizerThreshold: rasterizerThreshold,
      checkerboardRasterCacheImages: checkerboardRasterCacheImages,
      checkerboardOffscreenLayers: checkerboardOffscreenLayers,
    ));
  }
}