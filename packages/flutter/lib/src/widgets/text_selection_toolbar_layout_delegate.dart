import 'dart:math' as math;

import 'package:flutter/rendering.dart';

class TextSelectionToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  TextSelectionToolbarLayoutDelegate({
    required this.anchorAbove,
    required this.anchorBelow,
    this.fitsAbove,
  });

  final Offset anchorAbove;

  final Offset anchorBelow;

  final bool? fitsAbove;

  static double centerOn(double position, double width, double max) {
    // If it overflows on the left, put it as far left as possible.
    if (position - width / 2.0 < 0.0) {
      return 0.0;
    }

    // If it overflows on the right, put it as far right as possible.
    if (position + width / 2.0 > max) {
      return max - width;
    }

    // Otherwise it fits while perfectly centered.
    return position - width / 2.0;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bool fitsAbove = this.fitsAbove ?? anchorAbove.dy >= childSize.height;
    final Offset anchor = fitsAbove ? anchorAbove : anchorBelow;

    return Offset(
      centerOn(
        anchor.dx,
        childSize.width,
        size.width,
      ),
      fitsAbove ? math.max(0.0, anchor.dy - childSize.height) : anchor.dy,
    );
  }

  @override
  bool shouldRelayout(TextSelectionToolbarLayoutDelegate oldDelegate) {
    return anchorAbove != oldDelegate.anchorAbove ||
        anchorBelow != oldDelegate.anchorBelow ||
        fitsAbove != oldDelegate.fitsAbove;
  }
}
