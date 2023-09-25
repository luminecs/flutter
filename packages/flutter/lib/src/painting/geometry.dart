import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'basic_types.dart';

Offset positionDependentBox({
  required Size size,
  required Size childSize,
  required Offset target,
  required bool preferBelow,
  double verticalOffset = 0.0,
  double margin = 10.0,
}) {
  // VERTICAL DIRECTION
  final bool fitsBelow = target.dy + verticalOffset + childSize.height <= size.height - margin;
  final bool fitsAbove = target.dy - verticalOffset - childSize.height >= margin;
  final bool tooltipBelow = fitsAbove == fitsBelow ? preferBelow : fitsBelow;
  final double y;
  if (tooltipBelow) {
    y = math.min(target.dy + verticalOffset, size.height - margin);
  } else {
    y = math.max(target.dy - verticalOffset - childSize.height, margin);
  }
  // HORIZONTAL DIRECTION
  final double flexibleSpace = size.width - childSize.width;
  final double x = flexibleSpace <= 2 * margin
    // If there's not enough horizontal space for margin + child, center the
    // child.
    ? flexibleSpace / 2.0
    : clampDouble(target.dx - childSize.width / 2, margin, flexibleSpace - margin);
  return Offset(x, y);
}