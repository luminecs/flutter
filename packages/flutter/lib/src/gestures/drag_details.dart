
import 'package:flutter/foundation.dart';

import 'velocity_tracker.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'velocity_tracker.dart' show Velocity;

class DragDownDetails {
  DragDownDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;

  @override
  String toString() => '${objectRuntimeType(this, 'DragDownDetails')}($globalPosition)';
}

typedef GestureDragDownCallback = void Function(DragDownDetails details);

class DragStartDetails {
  DragStartDetails({
    this.sourceTimeStamp,
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.kind,
  }) : localPosition = localPosition ?? globalPosition;

  final Duration? sourceTimeStamp;

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind? kind;

  // TODO(ianh): Expose the current position, so that you can have a no-jump
  // drag even when disambiguating (though of course it would lag the finger
  // instead).

  @override
  String toString() => '${objectRuntimeType(this, 'DragStartDetails')}($globalPosition)';
}

typedef GestureDragStartCallback = void Function(DragStartDetails details);

class DragUpdateDetails {
  DragUpdateDetails({
    this.sourceTimeStamp,
    this.delta = Offset.zero,
    this.primaryDelta,
    required this.globalPosition,
    Offset? localPosition,
  }) : assert(
         primaryDelta == null
           || (primaryDelta == delta.dx && delta.dy == 0.0)
           || (primaryDelta == delta.dy && delta.dx == 0.0),
       ),
       localPosition = localPosition ?? globalPosition;

  final Duration? sourceTimeStamp;

  final Offset delta;

  final double? primaryDelta;

  final Offset globalPosition;

  final Offset localPosition;

  @override
  String toString() => '${objectRuntimeType(this, 'DragUpdateDetails')}($delta)';
}

typedef GestureDragUpdateCallback = void Function(DragUpdateDetails details);

class DragEndDetails {
  DragEndDetails({
    this.velocity = Velocity.zero,
    this.primaryVelocity,
  }) : assert(
         primaryVelocity == null
           || (primaryVelocity == velocity.pixelsPerSecond.dx && velocity.pixelsPerSecond.dy == 0)
           || (primaryVelocity == velocity.pixelsPerSecond.dy && velocity.pixelsPerSecond.dx == 0),
       );

  final Velocity velocity;

  final double? primaryVelocity;

  @override
  String toString() => '${objectRuntimeType(this, 'DragEndDetails')}($velocity)';
}