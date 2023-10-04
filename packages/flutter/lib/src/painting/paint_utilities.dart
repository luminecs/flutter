import 'dart:math' as math;

import 'basic_types.dart';

void paintZigZag(Canvas canvas, Paint paint, Offset start, Offset end, int zigs,
    double width) {
  assert(zigs.isFinite);
  assert(zigs > 0);
  canvas.save();
  canvas.translate(start.dx, start.dy);
  end = end - start;
  canvas.rotate(math.atan2(end.dy, end.dx));
  final double length = end.distance;
  final double spacing = length / (zigs * 2.0);
  final Path path = Path()..moveTo(0.0, 0.0);
  for (int index = 0; index < zigs; index += 1) {
    final double x = (index * 2.0 + 1.0) * spacing;
    final double y = width * ((index % 2.0) * 2.0 - 1.0);
    path.lineTo(x, y);
  }
  path.lineTo(length, 0.0);
  canvas.drawPath(path, paint);
  canvas.restore();
}
