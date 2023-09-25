
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

@immutable
class BottomSheetThemeData with Diagnosticable {
  const BottomSheetThemeData({
    this.backgroundColor,
    this.surfaceTintColor,
    this.elevation,
    this.modalBackgroundColor,
    this.modalBarrierColor,
    this.shadowColor,
    this.modalElevation,
    this.shape,
    this.showDragHandle,
    this.dragHandleColor,
    this.dragHandleSize,
    this.clipBehavior,
    this.constraints,
  });

  final Color? backgroundColor;

  final Color? surfaceTintColor;

  final double? elevation;

  final Color? modalBackgroundColor;

  final Color? modalBarrierColor;

  final Color? shadowColor;

  final double? modalElevation;

  final ShapeBorder? shape;

  final bool? showDragHandle;

  final Color? dragHandleColor;

  final Size? dragHandleSize;

  final Clip? clipBehavior;

  final BoxConstraints? constraints;

  BottomSheetThemeData copyWith({
    Color? backgroundColor,
    Color? surfaceTintColor,
    double? elevation,
    Color? modalBackgroundColor,
    Color? modalBarrierColor,
    Color? shadowColor,
    double? modalElevation,
    ShapeBorder? shape,
    bool? showDragHandle,
    Color? dragHandleColor,
    Size? dragHandleSize,
    Clip? clipBehavior,
    BoxConstraints? constraints,
  }) {
    return BottomSheetThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      elevation: elevation ?? this.elevation,
      modalBackgroundColor: modalBackgroundColor ?? this.modalBackgroundColor,
      modalBarrierColor: modalBarrierColor ?? this.modalBarrierColor,
      shadowColor: shadowColor ?? this.shadowColor,
      modalElevation: modalElevation ?? this.modalElevation,
      shape: shape ?? this.shape,
      showDragHandle: showDragHandle ?? this.showDragHandle,
      dragHandleColor: dragHandleColor ?? this.dragHandleColor,
      dragHandleSize: dragHandleSize ?? this.dragHandleSize,
      clipBehavior: clipBehavior ?? this.clipBehavior,
      constraints: constraints ?? this.constraints,
    );
  }

  static BottomSheetThemeData? lerp(BottomSheetThemeData? a, BottomSheetThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return BottomSheetThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      modalBackgroundColor: Color.lerp(a?.modalBackgroundColor, b?.modalBackgroundColor, t),
      modalBarrierColor: Color.lerp(a?.modalBarrierColor, b?.modalBarrierColor, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      modalElevation: lerpDouble(a?.modalElevation, b?.modalElevation, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      showDragHandle: t < 0.5 ? a?.showDragHandle : b?.showDragHandle,
      dragHandleColor: Color.lerp(a?.dragHandleColor, b?.dragHandleColor, t),
      dragHandleSize: Size.lerp(a?.dragHandleSize, b?.dragHandleSize, t),
      clipBehavior: t < 0.5 ? a?.clipBehavior : b?.clipBehavior,
      constraints: BoxConstraints.lerp(a?.constraints, b?.constraints, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    surfaceTintColor,
    elevation,
    modalBackgroundColor,
    modalBarrierColor,
    shadowColor,
    modalElevation,
    shape,
    showDragHandle,
    dragHandleColor,
    dragHandleSize,
    clipBehavior,
    constraints,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BottomSheetThemeData
        && other.backgroundColor == backgroundColor
        && other.surfaceTintColor == surfaceTintColor
        && other.elevation == elevation
        && other.modalBackgroundColor == modalBackgroundColor
        && other.shadowColor == shadowColor
        && other.modalBarrierColor == modalBarrierColor
        && other.modalElevation == modalElevation
        && other.shape == shape
        && other.showDragHandle == showDragHandle
        && other.dragHandleColor == dragHandleColor
        && other.dragHandleSize == dragHandleSize
        && other.clipBehavior == clipBehavior
        && other.constraints == constraints;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(ColorProperty('modalBackgroundColor', modalBackgroundColor, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('modalBarrierColor', modalBarrierColor, defaultValue: null));
    properties.add(DoubleProperty('modalElevation', modalElevation, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('showDragHandle', showDragHandle, defaultValue: null));
    properties.add(ColorProperty('dragHandleColor', dragHandleColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Size>('dragHandleSize', dragHandleSize, defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior, defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>('constraints', constraints, defaultValue: null));
  }
}