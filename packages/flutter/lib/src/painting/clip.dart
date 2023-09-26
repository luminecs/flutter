import 'dart:ui' show Canvas, Clip, Paint, Path, RRect, Rect, VoidCallback;

abstract class ClipContext {
  Canvas get canvas;

  void _clipAndPaint(void Function(bool doAntiAlias) canvasClipCall,
      Clip clipBehavior, Rect bounds, VoidCallback painter) {
    canvas.save();
    switch (clipBehavior) {
      case Clip.none:
        break;
      case Clip.hardEdge:
        canvasClipCall(false);
      case Clip.antiAlias:
        canvasClipCall(true);
      case Clip.antiAliasWithSaveLayer:
        canvasClipCall(true);
        canvas.saveLayer(bounds, Paint());
    }
    painter();
    if (clipBehavior == Clip.antiAliasWithSaveLayer) {
      canvas.restore();
    }
    canvas.restore();
  }

  void clipPathAndPaint(
      Path path, Clip clipBehavior, Rect bounds, VoidCallback painter) {
    _clipAndPaint(
        (bool doAntiAlias) => canvas.clipPath(path, doAntiAlias: doAntiAlias),
        clipBehavior,
        bounds,
        painter);
  }

  void clipRRectAndPaint(
      RRect rrect, Clip clipBehavior, Rect bounds, VoidCallback painter) {
    _clipAndPaint(
        (bool doAntiAlias) => canvas.clipRRect(rrect, doAntiAlias: doAntiAlias),
        clipBehavior,
        bounds,
        painter);
  }

  void clipRectAndPaint(
      Rect rect, Clip clipBehavior, Rect bounds, VoidCallback painter) {
    _clipAndPaint(
        (bool doAntiAlias) => canvas.clipRect(rect, doAntiAlias: doAntiAlias),
        clipBehavior,
        bounds,
        painter);
  }
}
