import 'package:flutter/rendering.dart';

class DesktopTextSelectionToolbarLayoutDelegate
    extends SingleChildLayoutDelegate {
  DesktopTextSelectionToolbarLayoutDelegate({
    required this.anchor,
  });

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Offset overhang = Offset(
      anchor.dx + childSize.width - size.width,
      anchor.dy + childSize.height - size.height,
    );
    return Offset(
      overhang.dx > 0.0 ? anchor.dx - overhang.dx : anchor.dx,
      overhang.dy > 0.0 ? anchor.dy - overhang.dy : anchor.dy,
    );
  }

  @override
  bool shouldRelayout(DesktopTextSelectionToolbarLayoutDelegate oldDelegate) {
    return anchor != oldDelegate.anchor;
  }
}
