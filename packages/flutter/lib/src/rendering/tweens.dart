import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

class FractionalOffsetTween extends Tween<FractionalOffset?> {
  FractionalOffsetTween({ super.begin, super.end });

  @override
  FractionalOffset? lerp(double t) => FractionalOffset.lerp(begin, end, t);
}

class AlignmentTween extends Tween<Alignment> {
  AlignmentTween({ super.begin, super.end });

  @override
  Alignment lerp(double t) => Alignment.lerp(begin, end, t)!;
}

class AlignmentGeometryTween extends Tween<AlignmentGeometry?> {
  AlignmentGeometryTween({
    super.begin,
    super.end,
  });

  @override
  AlignmentGeometry? lerp(double t) => AlignmentGeometry.lerp(begin, end, t);
}