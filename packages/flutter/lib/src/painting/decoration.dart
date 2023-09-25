import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'edge_insets.dart';
import 'image_provider.dart';

// Examples can assume:
// late Decoration myDecoration;

// This group of classes is intended for painting in cartesian coordinates.

@immutable
abstract class Decoration with Diagnosticable {
  const Decoration();

  @override
  String toStringShort() => objectRuntimeType(this, 'Decoration');

  bool debugAssertIsValid() => true;

  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  bool get isComplex => false;

  @protected
  Decoration? lerpFrom(Decoration? a, double t) => null;

  @protected
  Decoration? lerpTo(Decoration? b, double t) => null;

  static Decoration? lerp(Decoration? a, Decoration? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.lerpFrom(null, t) ?? b;
    }
    if (b == null) {
      return a.lerpTo(null, t) ?? a;
    }
    if (t == 0.0) {
      return a;
    }
    if (t == 1.0) {
      return b;
    }
    return b.lerpFrom(a, t)
        ?? a.lerpTo(b, t)
        ?? (t < 0.5 ? (a.lerpTo(null, t * 2.0) ?? a) : (b.lerpFrom(null, (t - 0.5) * 2.0) ?? b));
  }

  bool hitTest(Size size, Offset position, { TextDirection? textDirection }) => true;

  @factory
  BoxPainter createBoxPainter([ VoidCallback onChanged ]);

  Path getClipPath(Rect rect, TextDirection textDirection) {
    throw UnsupportedError('${objectRuntimeType(this, 'This Decoration subclass')} does not expect to be used for clipping.');
  }
}

abstract class BoxPainter {
  const BoxPainter([this.onChanged]);

  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration);

  final VoidCallback? onChanged;

  @mustCallSuper
  void dispose() { }
}