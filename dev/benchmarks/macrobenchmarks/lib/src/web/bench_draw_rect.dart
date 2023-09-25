
import 'dart:ui';

import 'recorder.dart';

class BenchDrawRect extends SceneBuilderRecorder {
  BenchDrawRect.staticPaint() : benchmarkPaint = false, super(name: benchmarkName);

  BenchDrawRect.variablePaint() : benchmarkPaint = true, super(name: variablePaintBenchmarkName);

  static const String benchmarkName = 'draw_rect';
  static const String variablePaintBenchmarkName = 'draw_rect_variable_paint';

  static const int kRows = 25;

  static const int kColumns = 40;

  final bool benchmarkPaint;

  double wobbleCounter = 0;

  static final Paint _staticPaint = Paint()..color = const Color.fromARGB(255, 255, 0, 0);

  Paint makePaint(int row, int col) {
    if (benchmarkPaint) {
      final Paint paint = Paint();
      final double rowRatio = row / kRows;
      paint.color = Color.fromARGB(255, (255 * rowRatio).floor(), (255 * col / kColumns).floor(), 255);
      paint.filterQuality = FilterQuality.values[(FilterQuality.values.length * rowRatio).floor()];
      paint.strokeCap = StrokeCap.values[(StrokeCap.values.length * rowRatio).floor()];
      paint.strokeJoin = StrokeJoin.values[(StrokeJoin.values.length * rowRatio).floor()];
      paint.blendMode = BlendMode.values[(BlendMode.values.length * rowRatio).floor()];
      paint.style = PaintingStyle.values[(PaintingStyle.values.length * rowRatio).floor()];
      paint.strokeWidth = 1.0 + rowRatio;
      paint.strokeMiterLimit = rowRatio;
      return paint;
    } else {
      return _staticPaint;
    }
  }

  @override
  void onDrawFrame(SceneBuilder sceneBuilder) {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Size viewSize = view.physicalSize;

    final Size cellSize = Size(
      viewSize.width / kColumns,
      viewSize.height / kRows,
    );
    final Size rectSize = cellSize * 0.8;

    for (int row = 0; row < kRows; row++) {
      canvas.save();
      for (int col = 0; col < kColumns; col++) {
        canvas.drawRect(
          Offset((wobbleCounter - 5).abs(), 0) & rectSize,
          makePaint(row, col),
        );
        canvas.translate(cellSize.width, 0);
      }
      canvas.restore();
      canvas.translate(0, cellSize.height);
    }

    wobbleCounter += 1;
    wobbleCounter = wobbleCounter % 10;
    final Picture picture = pictureRecorder.endRecording();
    sceneBuilder.pushOffset(0.0, 0.0);
    sceneBuilder.addPicture(Offset.zero, picture);
    sceneBuilder.pop();
  }
}