import 'box.dart';
import 'object.dart';

export 'package:flutter/foundation.dart' show debugPrint;

// Any changes to this file should be reflected in the debugAssertAllRenderVarsUnset()
// function below.

const HSVColor _kDebugDefaultRepaintColor =
    HSVColor.fromAHSV(0.4, 60.0, 1.0, 1.0);

bool debugPaintSizeEnabled = false;

bool debugPaintBaselinesEnabled = false;

bool debugPaintLayerBordersEnabled = false;

bool debugPaintPointersEnabled = false;

bool debugRepaintRainbowEnabled = false;

bool debugRepaintTextRainbowEnabled = false;

HSVColor debugCurrentRepaintColor = _kDebugDefaultRepaintColor;

bool debugPrintMarkNeedsLayoutStacks = false;

bool debugPrintMarkNeedsPaintStacks = false;

bool debugPrintLayouts = false;

bool debugCheckIntrinsicSizes = false;

bool debugProfileLayoutsEnabled = false;

bool debugProfilePaintsEnabled = false;

bool debugEnhanceLayoutTimelineArguments = false;

bool debugEnhancePaintTimelineArguments = false;

typedef ProfilePaintCallback = void Function(RenderObject renderObject);

ProfilePaintCallback? debugOnProfilePaint;

bool debugDisableClipLayers = false;

bool debugDisablePhysicalShapeLayers = false;

bool debugDisableOpacityLayers = false;

void _debugDrawDoubleRect(
    Canvas canvas, Rect outerRect, Rect innerRect, Color color) {
  final Path path = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(outerRect)
    ..addRect(innerRect);
  final Paint paint = Paint()..color = color;
  canvas.drawPath(path, paint);
}

void debugPaintPadding(Canvas canvas, Rect outerRect, Rect? innerRect,
    {double outlineWidth = 2.0}) {
  assert(() {
    if (innerRect != null && !innerRect.isEmpty) {
      _debugDrawDoubleRect(
          canvas, outerRect, innerRect, const Color(0x900090FF));
      _debugDrawDoubleRect(
          canvas,
          innerRect.inflate(outlineWidth).intersect(outerRect),
          innerRect,
          const Color(0xFF0090FF));
    } else {
      final Paint paint = Paint()..color = const Color(0x90909090);
      canvas.drawRect(outerRect, paint);
    }
    return true;
  }());
}

bool debugAssertAllRenderVarsUnset(String reason,
    {bool debugCheckIntrinsicSizesOverride = false}) {
  assert(() {
    if (debugPaintSizeEnabled ||
        debugPaintBaselinesEnabled ||
        debugPaintLayerBordersEnabled ||
        debugPaintPointersEnabled ||
        debugRepaintRainbowEnabled ||
        debugRepaintTextRainbowEnabled ||
        debugCurrentRepaintColor != _kDebugDefaultRepaintColor ||
        debugPrintMarkNeedsLayoutStacks ||
        debugPrintMarkNeedsPaintStacks ||
        debugPrintLayouts ||
        debugCheckIntrinsicSizes != debugCheckIntrinsicSizesOverride ||
        debugProfileLayoutsEnabled ||
        debugProfilePaintsEnabled ||
        debugOnProfilePaint != null ||
        debugDisableClipLayers ||
        debugDisablePhysicalShapeLayers ||
        debugDisableOpacityLayers) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}

bool debugCheckHasBoundedAxis(Axis axis, BoxConstraints constraints) {
  assert(() {
    if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
      switch (axis) {
        case Axis.vertical:
          if (!constraints.hasBoundedHeight) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('Vertical viewport was given unbounded height.'),
              ErrorDescription(
                'Viewports expand in the scrolling direction to fill their container. '
                'In this case, a vertical viewport was given an unlimited amount of '
                'vertical space in which to expand. This situation typically happens '
                'when a scrollable widget is nested inside another scrollable widget.',
              ),
              ErrorHint(
                'If this widget is always nested in a scrollable widget there '
                'is no need to use a viewport because there will always be enough '
                'vertical space for the children. In this case, consider using a '
                'Column or Wrap instead. Otherwise, consider using a '
                'CustomScrollView to concatenate arbitrary slivers into a '
                'single scrollable.',
              ),
            ]);
          }
          if (!constraints.hasBoundedWidth) {
            throw FlutterError(
              'Vertical viewport was given unbounded width.\n'
              'Viewports expand in the cross axis to fill their container and '
              'constrain their children to match their extent in the cross axis. '
              'In this case, a vertical viewport was given an unlimited amount of '
              'horizontal space in which to expand.',
            );
          }
        case Axis.horizontal:
          if (!constraints.hasBoundedWidth) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('Horizontal viewport was given unbounded width.'),
              ErrorDescription(
                'Viewports expand in the scrolling direction to fill their container. '
                'In this case, a horizontal viewport was given an unlimited amount of '
                'horizontal space in which to expand. This situation typically happens '
                'when a scrollable widget is nested inside another scrollable widget.',
              ),
              ErrorHint(
                'If this widget is always nested in a scrollable widget there '
                'is no need to use a viewport because there will always be enough '
                'horizontal space for the children. In this case, consider using a '
                'Row or Wrap instead. Otherwise, consider using a '
                'CustomScrollView to concatenate arbitrary slivers into a '
                'single scrollable.',
              ),
            ]);
          }
          if (!constraints.hasBoundedHeight) {
            throw FlutterError(
              'Horizontal viewport was given unbounded height.\n'
              'Viewports expand in the cross axis to fill their container and '
              'constrain their children to match their extent in the cross axis. '
              'In this case, a horizontal viewport was given an unlimited amount of '
              'vertical space in which to expand.',
            );
          }
      }
    }
    return true;
  }());
  return true;
}
