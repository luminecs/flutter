import 'package:flutter/rendering.dart';

import 'framework.dart';

class PerformanceOverlay extends LeafRenderObjectWidget {
  // TODO(abarth): We should have a page on the web site with a screenshot and
  // an explanation of all the various readouts.

  const PerformanceOverlay({
    super.key,
    this.optionsMask = 0,
    this.rasterizerThreshold = 0,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
  });

  PerformanceOverlay.allEnabled({
    super.key,
    this.rasterizerThreshold = 0,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
  }) : optionsMask = 1 <<
                PerformanceOverlayOption.displayRasterizerStatistics.index |
            1 << PerformanceOverlayOption.visualizeRasterizerStatistics.index |
            1 << PerformanceOverlayOption.displayEngineStatistics.index |
            1 << PerformanceOverlayOption.visualizeEngineStatistics.index;

  final int optionsMask;

  final int rasterizerThreshold;

  final bool checkerboardRasterCacheImages;

  final bool checkerboardOffscreenLayers;

  @override
  RenderPerformanceOverlay createRenderObject(BuildContext context) =>
      RenderPerformanceOverlay(
        optionsMask: optionsMask,
        rasterizerThreshold: rasterizerThreshold,
        checkerboardRasterCacheImages: checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: checkerboardOffscreenLayers,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderPerformanceOverlay renderObject) {
    renderObject
      ..optionsMask = optionsMask
      ..rasterizerThreshold = rasterizerThreshold
      ..checkerboardRasterCacheImages = checkerboardRasterCacheImages
      ..checkerboardOffscreenLayers = checkerboardOffscreenLayers;
  }
}
