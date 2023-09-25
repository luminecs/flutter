import 'dart:ui' show Offset, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'constants.dart';
import 'gesture_settings.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;
export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'gesture_settings.dart' show DeviceGestureSettings;

const int kPrimaryButton = 0x01;

const int kSecondaryButton = 0x02;

const int kPrimaryMouseButton = kPrimaryButton;

const int kSecondaryMouseButton = kSecondaryButton;

const int kStylusContact = kPrimaryButton;

const int kPrimaryStylusButton = kSecondaryButton;

const int kTertiaryButton = 0x04;

const int kMiddleMouseButton = kTertiaryButton;

const int kSecondaryStylusButton = kTertiaryButton;

const int kBackMouseButton = 0x08;

const int kForwardMouseButton = 0x10;

const int kTouchContact = kPrimaryButton;

int nthMouseButton(int number) => (kPrimaryMouseButton << (number - 1)) & kMaxUnsignedSMI;

int nthStylusButton(int number) => (kPrimaryStylusButton << (number - 1)) & kMaxUnsignedSMI;

int smallestButton(int buttons) => buttons & (-buttons);

bool isSingleButton(int buttons) => buttons != 0 && (smallestButton(buttons) == buttons);

@immutable
abstract class PointerEvent with Diagnosticable {
  const PointerEvent({
    this.viewId = 0,
    this.embedderId = 0,
    this.timeStamp = Duration.zero,
    this.pointer = 0,
    this.kind = PointerDeviceKind.touch,
    this.device = 0,
    this.position = Offset.zero,
    this.delta = Offset.zero,
    this.buttons = 0,
    this.down = false,
    this.obscured = false,
    this.pressure = 1.0,
    this.pressureMin = 1.0,
    this.pressureMax = 1.0,
    this.distance = 0.0,
    this.distanceMax = 0.0,
    this.size = 0.0,
    this.radiusMajor = 0.0,
    this.radiusMinor = 0.0,
    this.radiusMin = 0.0,
    this.radiusMax = 0.0,
    this.orientation = 0.0,
    this.tilt = 0.0,
    this.platformData = 0,
    this.synthesized = false,
    this.transform,
    this.original,
  });

  final int viewId;

  final int embedderId;

  final Duration timeStamp;

  final int pointer;

  final PointerDeviceKind kind;

  final int device;

  final Offset position;

  Offset get localPosition => position;

  final Offset delta;

  Offset get localDelta => delta;

  final int buttons;

  final bool down;

  final bool obscured;

  final double pressure;

  final double pressureMin;

  final double pressureMax;

  final double distance;

  double get distanceMin => 0.0;

  final double distanceMax;

  final double size;

  final double radiusMajor;

  final double radiusMinor;

  final double radiusMin;

  final double radiusMax;

  final double orientation;

  final double tilt;

  final int platformData;

  final bool synthesized;

  final Matrix4? transform;

  final PointerEvent? original;

  PointerEvent transformed(Matrix4? transform);

  PointerEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  });

  static Offset transformPosition(Matrix4? transform, Offset position) {
    if (transform == null) {
      return position;
    }
    final Vector3 position3 = Vector3(position.dx, position.dy, 0.0);
    final Vector3 transformed3 = transform.perspectiveTransform(position3);
    return Offset(transformed3.x, transformed3.y);
  }

  static Offset transformDeltaViaPositions({
    required Offset untransformedEndPosition,
    Offset? transformedEndPosition,
    required Offset untransformedDelta,
    required Matrix4? transform,
  }) {
    if (transform == null) {
      return untransformedDelta;
    }
    // We could transform the delta directly with the transformation matrix.
    // While that is mathematically equivalent, in practice we are seeing a
    // greater precision error with that approach. Instead, we are transforming
    // start and end point of the delta separately and calculate the delta in
    // the new space for greater accuracy.
    transformedEndPosition ??= transformPosition(transform, untransformedEndPosition);
    final Offset transformedStartPosition = transformPosition(transform, untransformedEndPosition - untransformedDelta);
    return transformedEndPosition - transformedStartPosition;
  }

  static Matrix4 removePerspectiveTransform(Matrix4 transform) {
    final Vector4 vector = Vector4(0, 0, 1, 0);
    return transform.clone()
      ..setColumn(2, vector)
      ..setRow(2, vector);
  }
}

// A mixin that adds implementation for [debugFillProperties] and [toStringFull]
// to [PointerEvent].
mixin _PointerEventDescription on PointerEvent {
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('position', position));
    properties.add(DiagnosticsProperty<Offset>('localPosition', localPosition, defaultValue: position, level: DiagnosticLevel.debug));
    properties.add(DiagnosticsProperty<Offset>('delta', delta, defaultValue: Offset.zero, level: DiagnosticLevel.debug));
    properties.add(DiagnosticsProperty<Offset>('localDelta', localDelta, defaultValue: delta, level: DiagnosticLevel.debug));
    properties.add(DiagnosticsProperty<Duration>('timeStamp', timeStamp, defaultValue: Duration.zero, level: DiagnosticLevel.debug));
    properties.add(IntProperty('pointer', pointer, level: DiagnosticLevel.debug));
    properties.add(EnumProperty<PointerDeviceKind>('kind', kind, level: DiagnosticLevel.debug));
    properties.add(IntProperty('device', device, defaultValue: 0, level: DiagnosticLevel.debug));
    properties.add(IntProperty('buttons', buttons, defaultValue: 0, level: DiagnosticLevel.debug));
    properties.add(DiagnosticsProperty<bool>('down', down, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('pressure', pressure, defaultValue: 1.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('pressureMin', pressureMin, defaultValue: 1.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('pressureMax', pressureMax, defaultValue: 1.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('distance', distance, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('distanceMin', distanceMin, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('distanceMax', distanceMax, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('size', size, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('radiusMajor', radiusMajor, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('radiusMinor', radiusMinor, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('radiusMin', radiusMin, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('radiusMax', radiusMax, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('orientation', orientation, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(DoubleProperty('tilt', tilt, defaultValue: 0.0, level: DiagnosticLevel.debug));
    properties.add(IntProperty('platformData', platformData, defaultValue: 0, level: DiagnosticLevel.debug));
    properties.add(FlagProperty('obscured', value: obscured, ifTrue: 'obscured', level: DiagnosticLevel.debug));
    properties.add(FlagProperty('synthesized', value: synthesized, ifTrue: 'synthesized', level: DiagnosticLevel.debug));
    properties.add(IntProperty('embedderId', embedderId, defaultValue: 0, level: DiagnosticLevel.debug));
    properties.add(IntProperty('viewId', viewId, defaultValue: 0, level: DiagnosticLevel.debug));
  }

  String toStringFull() {
    return toString(minLevel: DiagnosticLevel.fine);
  }
}

abstract class _AbstractPointerEvent implements PointerEvent { }

// The base class for transformed pointer event classes.
//
// A _TransformedPointerEvent stores an [original] event and the [transform]
// matrix. It defers all field getters to the original event, except for
// [localPosition] and [localDelta], which are calculated when first used.
abstract class _TransformedPointerEvent extends _AbstractPointerEvent with Diagnosticable, _PointerEventDescription {
  @override
  PointerEvent get original;

  @override
  Matrix4 get transform;

  @override
  int get embedderId => original.embedderId;

  @override
  Duration get timeStamp => original.timeStamp;

  @override
  int get pointer => original.pointer;

  @override
  PointerDeviceKind get kind => original.kind;

  @override
  int get device => original.device;

  @override
  Offset get position => original.position;

  @override
  Offset get delta => original.delta;

  @override
  int get buttons => original.buttons;

  @override
  bool get down => original.down;

  @override
  bool get obscured => original.obscured;

  @override
  double get pressure => original.pressure;

  @override
  double get pressureMin => original.pressureMin;

  @override
  double get pressureMax => original.pressureMax;

  @override
  double get distance => original.distance;

  @override
  double get distanceMin => 0.0;

  @override
  double get distanceMax => original.distanceMax;

  @override
  double get size => original.size;

  @override
  double get radiusMajor => original.radiusMajor;

  @override
  double get radiusMinor => original.radiusMinor;

  @override
  double get radiusMin => original.radiusMin;

  @override
  double get radiusMax => original.radiusMax;

  @override
  double get orientation => original.orientation;

  @override
  double get tilt => original.tilt;

  @override
  int get platformData => original.platformData;

  @override
  bool get synthesized => original.synthesized;

  @override
  late final Offset localPosition = PointerEvent.transformPosition(transform, position);

  @override
  late final Offset localDelta = PointerEvent.transformDeltaViaPositions(
    transform: transform,
    untransformedDelta: delta,
    untransformedEndPosition: position,
    transformedEndPosition: localPosition,
  );

  @override
  int get viewId => original.viewId;
}

mixin _CopyPointerAddedEvent on PointerEvent {
  @override
  PointerAddedEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerAddedEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      obscured: obscured ?? this.obscured,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distance: distance ?? this.distance,
      distanceMax: distanceMax ?? this.distanceMax,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerAddedEvent extends PointerEvent with _PointerEventDescription, _CopyPointerAddedEvent {
  const PointerAddedEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.obscured,
    super.pressureMin,
    super.pressureMax,
    super.distance,
    super.distanceMax,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.embedderId,
  }) : super(
         pressure: 0.0,
       );

  @override
  PointerAddedEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerAddedEvent(original as PointerAddedEvent? ?? this, transform);
  }
}

class _TransformedPointerAddedEvent extends _TransformedPointerEvent with _CopyPointerAddedEvent implements PointerAddedEvent {
  _TransformedPointerAddedEvent(this.original, this.transform);

  @override
  final PointerAddedEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerAddedEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerRemovedEvent on PointerEvent {
  @override
  PointerRemovedEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerRemovedEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      obscured: obscured ?? this.obscured,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distanceMax: distanceMax ?? this.distanceMax,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerRemovedEvent extends PointerEvent with _PointerEventDescription, _CopyPointerRemovedEvent {
  const PointerRemovedEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.obscured,
    super.pressureMin,
    super.pressureMax,
    super.distanceMax,
    super.radiusMin,
    super.radiusMax,
    PointerRemovedEvent? super.original,
    super.embedderId,
  }) : super(
         pressure: 0.0,
       );

  @override
  PointerRemovedEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerRemovedEvent(original as PointerRemovedEvent? ?? this, transform);
  }
}

class _TransformedPointerRemovedEvent extends _TransformedPointerEvent with _CopyPointerRemovedEvent implements PointerRemovedEvent {
  _TransformedPointerRemovedEvent(this.original, this.transform);

  @override
  final PointerRemovedEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerRemovedEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerHoverEvent on PointerEvent {
  @override
  PointerHoverEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerHoverEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      delta: delta ?? this.delta,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distance: distance ?? this.distance,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      synthesized: synthesized ?? this.synthesized,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerHoverEvent extends PointerEvent with _PointerEventDescription, _CopyPointerHoverEvent {
  const PointerHoverEvent({
    super.viewId,
    super.timeStamp,
    super.kind,
    super.pointer,
    super.device,
    super.position,
    super.delta,
    super.buttons,
    super.obscured,
    super.pressureMin,
    super.pressureMax,
    super.distance,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.synthesized,
    super.embedderId,
  }) : super(
         down: false,
         pressure: 0.0,
       );

  @override
  PointerHoverEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerHoverEvent(original as PointerHoverEvent? ?? this, transform);
  }
}

class _TransformedPointerHoverEvent extends _TransformedPointerEvent with _CopyPointerHoverEvent implements PointerHoverEvent {
  _TransformedPointerHoverEvent(this.original, this.transform);

  @override
  final PointerHoverEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerHoverEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerEnterEvent on PointerEvent {
  @override
  PointerEnterEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerEnterEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      delta: delta ?? this.delta,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distance: distance ?? this.distance,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      synthesized: synthesized ?? this.synthesized,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerEnterEvent extends PointerEvent with _PointerEventDescription, _CopyPointerEnterEvent {
  const PointerEnterEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.delta,
    super.buttons,
    super.obscured,
    super.pressureMin,
    super.pressureMax,
    super.distance,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.down,
    super.synthesized,
    super.embedderId,
  }) : // Dart doesn't support comparing enums with == in const contexts yet.
       // https://github.com/dart-lang/language/issues/1811
       assert(!identical(kind, PointerDeviceKind.trackpad)),
       super(
         pressure: 0.0,
       );

  factory PointerEnterEvent.fromMouseEvent(PointerEvent event) => PointerEnterEvent(
    viewId: event.viewId,
    timeStamp: event.timeStamp,
    pointer: event.pointer,
    kind: event.kind,
    device: event.device,
    position: event.position,
    delta: event.delta,
    buttons: event.buttons,
    obscured: event.obscured,
    pressureMin: event.pressureMin,
    pressureMax: event.pressureMax,
    distance: event.distance,
    distanceMax: event.distanceMax,
    size: event.size,
    radiusMajor: event.radiusMajor,
    radiusMinor: event.radiusMinor,
    radiusMin: event.radiusMin,
    radiusMax: event.radiusMax,
    orientation: event.orientation,
    tilt: event.tilt,
    down: event.down,
    synthesized: event.synthesized,
  ).transformed(event.transform);

  @override
  PointerEnterEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerEnterEvent(original as PointerEnterEvent? ?? this, transform);
  }
}

class _TransformedPointerEnterEvent extends _TransformedPointerEvent with _CopyPointerEnterEvent implements PointerEnterEvent {
  _TransformedPointerEnterEvent(this.original, this.transform);

  @override
  final PointerEnterEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerEnterEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerExitEvent on PointerEvent {
  @override
  PointerExitEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerExitEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      delta: delta ?? this.delta,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distance: distance ?? this.distance,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      synthesized: synthesized ?? this.synthesized,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerExitEvent extends PointerEvent with _PointerEventDescription, _CopyPointerExitEvent {
  const PointerExitEvent({
    super.viewId,
    super.timeStamp,
    super.kind,
    super.pointer,
    super.device,
    super.position,
    super.delta,
    super.buttons,
    super.obscured,
    super.pressureMin,
    super.pressureMax,
    super.distance,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.down,
    super.synthesized,
    super.embedderId,
  }) : assert(!identical(kind, PointerDeviceKind.trackpad)),
       super(
         pressure: 0.0,
       );

  factory PointerExitEvent.fromMouseEvent(PointerEvent event) => PointerExitEvent(
    viewId: event.viewId,
    timeStamp: event.timeStamp,
    pointer: event.pointer,
    kind: event.kind,
    device: event.device,
    position: event.position,
    delta: event.delta,
    buttons: event.buttons,
    obscured: event.obscured,
    pressureMin: event.pressureMin,
    pressureMax: event.pressureMax,
    distance: event.distance,
    distanceMax: event.distanceMax,
    size: event.size,
    radiusMajor: event.radiusMajor,
    radiusMinor: event.radiusMinor,
    radiusMin: event.radiusMin,
    radiusMax: event.radiusMax,
    orientation: event.orientation,
    tilt: event.tilt,
    down: event.down,
    synthesized: event.synthesized,
  ).transformed(event.transform);

  @override
  PointerExitEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerExitEvent(original as PointerExitEvent? ?? this, transform);
  }

}

class _TransformedPointerExitEvent extends _TransformedPointerEvent with _CopyPointerExitEvent implements PointerExitEvent {
  _TransformedPointerExitEvent(this.original, this.transform);

  @override
  final PointerExitEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerExitEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerDownEvent on PointerEvent {
  @override
  PointerDownEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerDownEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      pointer: pointer ?? this.pointer,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressure: pressure ?? this.pressure,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerDownEvent extends PointerEvent with _PointerEventDescription, _CopyPointerDownEvent {
  const PointerDownEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.buttons = kPrimaryButton,
    super.obscured,
    super.pressure,
    super.pressureMin,
    super.pressureMax,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.embedderId,
  }) : assert(!identical(kind, PointerDeviceKind.trackpad)),
       super(
         down: true,
         distance: 0.0,
       );

  @override
  PointerDownEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerDownEvent(original as PointerDownEvent? ?? this, transform);
  }
}

class _TransformedPointerDownEvent extends _TransformedPointerEvent with _CopyPointerDownEvent implements PointerDownEvent {
  _TransformedPointerDownEvent(this.original, this.transform);

  @override
  final PointerDownEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerDownEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerMoveEvent on PointerEvent {
  @override
  PointerMoveEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerMoveEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      pointer: pointer ?? this.pointer,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      delta: delta ?? this.delta,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressure: pressure ?? this.pressure,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      synthesized: synthesized ?? this.synthesized,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerMoveEvent extends PointerEvent with _PointerEventDescription, _CopyPointerMoveEvent {
  const PointerMoveEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.delta,
    super.buttons = kPrimaryButton,
    super.obscured,
    super.pressure,
    super.pressureMin,
    super.pressureMax,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.platformData,
    super.synthesized,
    super.embedderId,
  }) : assert(!identical(kind, PointerDeviceKind.trackpad)),
       super(
         down: true,
         distance: 0.0,
       );

  @override
  PointerMoveEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }

    return _TransformedPointerMoveEvent(original as PointerMoveEvent? ?? this, transform);
  }
}

class _TransformedPointerMoveEvent extends _TransformedPointerEvent with _CopyPointerMoveEvent implements PointerMoveEvent {
  _TransformedPointerMoveEvent(this.original, this.transform);

  @override
  final PointerMoveEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerMoveEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerUpEvent on PointerEvent {
  @override
  PointerUpEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? localPosition,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerUpEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      pointer: pointer ?? this.pointer,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressure: pressure ?? this.pressure,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distance: distance ?? this.distance,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerUpEvent extends PointerEvent with _PointerEventDescription, _CopyPointerUpEvent {
  const PointerUpEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.buttons,
    super.obscured,
    // Allow pressure customization here because PointerUpEvent can contain
    // non-zero pressure. See https://github.com/flutter/flutter/issues/31340
    super.pressure = 0.0,
    super.pressureMin,
    super.pressureMax,
    super.distance,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.embedderId,
  }) : assert(!identical(kind, PointerDeviceKind.trackpad)),
       super(
         down: false,
       );

  @override
  PointerUpEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerUpEvent(original as PointerUpEvent? ?? this, transform);
  }
}

class _TransformedPointerUpEvent extends _TransformedPointerEvent with _CopyPointerUpEvent implements PointerUpEvent {
  _TransformedPointerUpEvent(this.original, this.transform);

  @override
  final PointerUpEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerUpEvent transformed(Matrix4? transform) => original.transformed(transform);
}

abstract class PointerSignalEvent extends PointerEvent {
  const PointerSignalEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind = PointerDeviceKind.mouse,
    super.device,
    super.position,
    super.embedderId,
  });
}

mixin _CopyPointerScrollEvent on PointerEvent {
  Offset get scrollDelta;

  @override
  PointerScrollEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerScrollEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      scrollDelta: scrollDelta,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerScrollEvent extends PointerSignalEvent with _PointerEventDescription, _CopyPointerScrollEvent {
  const PointerScrollEvent({
    super.viewId,
    super.timeStamp,
    super.kind,
    super.device,
    super.position,
    this.scrollDelta = Offset.zero,
    super.embedderId,
  });

  @override
  final Offset scrollDelta;

  @override
  PointerScrollEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerScrollEvent(original as PointerScrollEvent? ?? this, transform);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('scrollDelta', scrollDelta));
  }
}

class _TransformedPointerScrollEvent extends _TransformedPointerEvent with _CopyPointerScrollEvent implements PointerScrollEvent {
  _TransformedPointerScrollEvent(this.original, this.transform);

  @override
  final PointerScrollEvent original;

  @override
  final Matrix4 transform;

  @override
  Offset get scrollDelta => original.scrollDelta;

  @override
  PointerScrollEvent transformed(Matrix4? transform) => original.transformed(transform);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('scrollDelta', scrollDelta));
  }
}

mixin _CopyPointerScrollInertiaCancelEvent on PointerEvent {
  @override
  PointerScrollInertiaCancelEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerScrollInertiaCancelEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerScrollInertiaCancelEvent extends PointerSignalEvent with _PointerEventDescription, _CopyPointerScrollInertiaCancelEvent {
  const PointerScrollInertiaCancelEvent({
    super.viewId,
    super.timeStamp,
    super.kind,
    super.device,
    super.position,
    super.embedderId,
  });

  @override
  PointerScrollInertiaCancelEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerScrollInertiaCancelEvent(original as PointerScrollInertiaCancelEvent? ?? this, transform);
  }
}

class _TransformedPointerScrollInertiaCancelEvent extends _TransformedPointerEvent with _CopyPointerScrollInertiaCancelEvent implements PointerScrollInertiaCancelEvent {
  _TransformedPointerScrollInertiaCancelEvent(this.original, this.transform);

  @override
  final PointerScrollInertiaCancelEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerScrollInertiaCancelEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerScaleEvent on PointerEvent {
  double get scale;

  @override
  PointerScaleEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
    double? scale,
  }) {
    return PointerScaleEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      embedderId: embedderId ?? this.embedderId,
      scale: scale ?? this.scale,
    ).transformed(transform);
  }
}

class PointerScaleEvent extends PointerSignalEvent with _PointerEventDescription, _CopyPointerScaleEvent {
  const PointerScaleEvent({
    super.viewId,
    super.timeStamp,
    super.kind,
    super.device,
    super.position,
    super.embedderId,
    this.scale = 1.0,
  });

  @override
  final double scale;

  @override
  PointerScaleEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerScaleEvent(original as PointerScaleEvent? ?? this, transform);
  }
}

class _TransformedPointerScaleEvent extends _TransformedPointerEvent with _CopyPointerScaleEvent implements PointerScaleEvent {
  _TransformedPointerScaleEvent(this.original, this.transform);

  @override
  final PointerScaleEvent original;

  @override
  final Matrix4 transform;

  @override
  double get scale => original.scale;

  @override
  PointerScaleEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerPanZoomStartEvent on PointerEvent {
  @override
  PointerPanZoomStartEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    assert(kind == null || identical(kind, PointerDeviceKind.trackpad));
    return PointerPanZoomStartEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      device: device ?? this.device,
      position: position ?? this.position,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerPanZoomStartEvent extends PointerEvent with _PointerEventDescription, _CopyPointerPanZoomStartEvent {
  const PointerPanZoomStartEvent({
    super.viewId,
    super.timeStamp,
    super.device,
    super.pointer,
    super.position,
    super.embedderId,
    super.synthesized,
  }) : super(kind: PointerDeviceKind.trackpad);

  @override
  PointerPanZoomStartEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerPanZoomStartEvent(original as PointerPanZoomStartEvent? ?? this, transform);
  }
}

class _TransformedPointerPanZoomStartEvent extends _TransformedPointerEvent with _CopyPointerPanZoomStartEvent implements PointerPanZoomStartEvent {
  _TransformedPointerPanZoomStartEvent(this.original, this.transform);

  @override
  final PointerPanZoomStartEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerPanZoomStartEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerPanZoomUpdateEvent on PointerEvent {
  Offset get pan;
  Offset get localPan;
  Offset get panDelta;
  Offset get localPanDelta;
  double get scale;
  double get rotation;

  @override
  PointerPanZoomUpdateEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
    Offset? pan,
    Offset? localPan,
    Offset? panDelta,
    Offset? localPanDelta,
    double? scale,
    double? rotation,
  }) {
    assert(kind == null || identical(kind, PointerDeviceKind.trackpad));
    return PointerPanZoomUpdateEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      device: device ?? this.device,
      position: position ?? this.position,
      embedderId: embedderId ?? this.embedderId,
      pan: pan ?? this.pan,
      panDelta: panDelta ?? this.panDelta,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    ).transformed(transform);
  }
}

class PointerPanZoomUpdateEvent extends PointerEvent with _PointerEventDescription, _CopyPointerPanZoomUpdateEvent {
  const PointerPanZoomUpdateEvent({
    super.viewId,
    super.timeStamp,
    super.device,
    super.pointer,
    super.position,
    super.embedderId,
    this.pan = Offset.zero,
    this.panDelta = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    super.synthesized,
  }) : super(kind: PointerDeviceKind.trackpad);

  @override
  final Offset pan;
  @override
  Offset get localPan => pan;
  @override
  final Offset panDelta;
  @override
  Offset get localPanDelta => panDelta;
  @override
  final double scale;
  @override
  final double rotation;

  @override
  PointerPanZoomUpdateEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerPanZoomUpdateEvent(original as PointerPanZoomUpdateEvent? ?? this, transform);
  }
}

class _TransformedPointerPanZoomUpdateEvent extends _TransformedPointerEvent with _CopyPointerPanZoomUpdateEvent implements PointerPanZoomUpdateEvent {
  _TransformedPointerPanZoomUpdateEvent(this.original, this.transform);

  @override
  Offset get pan => original.pan;

  @override
  late final Offset localPan = PointerEvent.transformPosition(transform, pan);

  @override
  Offset get panDelta => original.panDelta;

  @override
  late final Offset localPanDelta = PointerEvent.transformDeltaViaPositions(
    transform: transform,
    untransformedDelta: panDelta,
    untransformedEndPosition: pan,
    transformedEndPosition: localPan,
  );

  @override
  double get scale => original.scale;

  @override
  double get rotation => original.rotation;

  @override
  final PointerPanZoomUpdateEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerPanZoomUpdateEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerPanZoomEndEvent on PointerEvent {
  @override
  PointerPanZoomEndEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    assert(kind == null || identical(kind, PointerDeviceKind.trackpad));
    return PointerPanZoomEndEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      device: device ?? this.device,
      position: position ?? this.position,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerPanZoomEndEvent extends PointerEvent with _PointerEventDescription, _CopyPointerPanZoomEndEvent {
  const PointerPanZoomEndEvent({
    super.viewId,
    super.timeStamp,
    super.device,
    super.pointer,
    super.position,
    super.embedderId,
    super.synthesized,
  }) : super(kind: PointerDeviceKind.trackpad);

  @override
  PointerPanZoomEndEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerPanZoomEndEvent(original as PointerPanZoomEndEvent? ?? this, transform);
  }
}

class _TransformedPointerPanZoomEndEvent extends _TransformedPointerEvent with _CopyPointerPanZoomEndEvent implements PointerPanZoomEndEvent {
  _TransformedPointerPanZoomEndEvent(this.original, this.transform);

  @override
  final PointerPanZoomEndEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerPanZoomEndEvent transformed(Matrix4? transform) => original.transformed(transform);
}

mixin _CopyPointerCancelEvent on PointerEvent {
  @override
  PointerCancelEvent copyWith({
    int? viewId,
    Duration? timeStamp,
    int? pointer,
    PointerDeviceKind? kind,
    int? device,
    Offset? position,
    Offset? delta,
    int? buttons,
    bool? obscured,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? distance,
    double? distanceMax,
    double? size,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    double? orientation,
    double? tilt,
    bool? synthesized,
    int? embedderId,
  }) {
    return PointerCancelEvent(
      viewId: viewId ?? this.viewId,
      timeStamp: timeStamp ?? this.timeStamp,
      pointer: pointer ?? this.pointer,
      kind: kind ?? this.kind,
      device: device ?? this.device,
      position: position ?? this.position,
      buttons: buttons ?? this.buttons,
      obscured: obscured ?? this.obscured,
      pressureMin: pressureMin ?? this.pressureMin,
      pressureMax: pressureMax ?? this.pressureMax,
      distance: distance ?? this.distance,
      distanceMax: distanceMax ?? this.distanceMax,
      size: size ?? this.size,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
      radiusMin: radiusMin ?? this.radiusMin,
      radiusMax: radiusMax ?? this.radiusMax,
      orientation: orientation ?? this.orientation,
      tilt: tilt ?? this.tilt,
      embedderId: embedderId ?? this.embedderId,
    ).transformed(transform);
  }
}

class PointerCancelEvent extends PointerEvent with _PointerEventDescription, _CopyPointerCancelEvent {
  const PointerCancelEvent({
    super.viewId,
    super.timeStamp,
    super.pointer,
    super.kind,
    super.device,
    super.position,
    super.buttons,
    super.obscured,
    super.pressureMin,
    super.pressureMax,
    super.distance,
    super.distanceMax,
    super.size,
    super.radiusMajor,
    super.radiusMinor,
    super.radiusMin,
    super.radiusMax,
    super.orientation,
    super.tilt,
    super.embedderId,
  }) : assert(!identical(kind, PointerDeviceKind.trackpad)),
       super(
         down: false,
         pressure: 0.0,
       );

  @override
  PointerCancelEvent transformed(Matrix4? transform) {
    if (transform == null || transform == this.transform) {
      return this;
    }
    return _TransformedPointerCancelEvent(original as PointerCancelEvent? ?? this, transform);
  }
}

double computeHitSlop(PointerDeviceKind kind, DeviceGestureSettings? settings) {
  switch (kind) {
    case PointerDeviceKind.mouse:
      return kPrecisePointerHitSlop;
    case PointerDeviceKind.stylus:
    case PointerDeviceKind.invertedStylus:
    case PointerDeviceKind.unknown:
    case PointerDeviceKind.touch:
    case PointerDeviceKind.trackpad:
      return settings?.touchSlop ?? kTouchSlop;
  }
}

double computePanSlop(PointerDeviceKind kind, DeviceGestureSettings? settings) {
  switch (kind) {
    case PointerDeviceKind.mouse:
      return kPrecisePointerPanSlop;
    case PointerDeviceKind.stylus:
    case PointerDeviceKind.invertedStylus:
    case PointerDeviceKind.unknown:
    case PointerDeviceKind.touch:
    case PointerDeviceKind.trackpad:
      return settings?.panSlop ?? kPanSlop;
  }
}

double computeScaleSlop(PointerDeviceKind kind) {
  switch (kind) {
    case PointerDeviceKind.mouse:
      return kPrecisePointerScaleSlop;
    case PointerDeviceKind.stylus:
    case PointerDeviceKind.invertedStylus:
    case PointerDeviceKind.unknown:
    case PointerDeviceKind.touch:
    case PointerDeviceKind.trackpad:
      return kScaleSlop;
  }
}

class _TransformedPointerCancelEvent extends _TransformedPointerEvent with _CopyPointerCancelEvent implements PointerCancelEvent {
  _TransformedPointerCancelEvent(this.original, this.transform);

  @override
  final PointerCancelEvent original;

  @override
  final Matrix4 transform;

  @override
  PointerCancelEvent transformed(Matrix4? transform) => original.transformed(transform);
}