import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'box.dart';
import 'debug.dart';
import 'object.dart';
import 'viewport.dart';
import 'viewport_offset.dart';

// CORE TYPES FOR SLIVERS
// The RenderSliver base class and its helper types.

typedef ItemExtentBuilder = double Function(int index, SliverLayoutDimensions dimensions);

@immutable
class SliverLayoutDimensions {
  const SliverLayoutDimensions({
    required this.scrollOffset,
    required this.precedingScrollExtent,
    required this.viewportMainAxisExtent,
    required this.crossAxisExtent
  });

  final double scrollOffset;

  final double precedingScrollExtent;

  final double viewportMainAxisExtent;

  final double crossAxisExtent;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SliverLayoutDimensions) {
      return false;
    }
    return other.scrollOffset == scrollOffset &&
      other.precedingScrollExtent == precedingScrollExtent &&
      other.viewportMainAxisExtent == viewportMainAxisExtent &&
      other.crossAxisExtent == crossAxisExtent;
  }

  @override
  String toString() {
    return 'scrollOffset: $scrollOffset'
      ' precedingScrollExtent: $precedingScrollExtent'
      ' viewportMainAxisExtent: $viewportMainAxisExtent'
      ' crossAxisExtent: $crossAxisExtent';
  }

  @override
  int get hashCode => Object.hash(
    scrollOffset,
    precedingScrollExtent,
    viewportMainAxisExtent,
    viewportMainAxisExtent
  );
}

enum GrowthDirection {
  forward,

  reverse,
}

AxisDirection applyGrowthDirectionToAxisDirection(AxisDirection axisDirection, GrowthDirection growthDirection) {
  switch (growthDirection) {
    case GrowthDirection.forward:
      return axisDirection;
    case GrowthDirection.reverse:
      return flipAxisDirection(axisDirection);
  }
}

ScrollDirection applyGrowthDirectionToScrollDirection(ScrollDirection scrollDirection, GrowthDirection growthDirection) {
  switch (growthDirection) {
    case GrowthDirection.forward:
      return scrollDirection;
    case GrowthDirection.reverse:
      return flipScrollDirection(scrollDirection);
  }
}

class SliverConstraints extends Constraints {
  const SliverConstraints({
    required this.axisDirection,
    required this.growthDirection,
    required this.userScrollDirection,
    required this.scrollOffset,
    required this.precedingScrollExtent,
    required this.overlap,
    required this.remainingPaintExtent,
    required this.crossAxisExtent,
    required this.crossAxisDirection,
    required this.viewportMainAxisExtent,
    required this.remainingCacheExtent,
    required this.cacheOrigin,
  });

  SliverConstraints copyWith({
    AxisDirection? axisDirection,
    GrowthDirection? growthDirection,
    ScrollDirection? userScrollDirection,
    double? scrollOffset,
    double? precedingScrollExtent,
    double? overlap,
    double? remainingPaintExtent,
    double? crossAxisExtent,
    AxisDirection? crossAxisDirection,
    double? viewportMainAxisExtent,
    double? remainingCacheExtent,
    double? cacheOrigin,
  }) {
    return SliverConstraints(
      axisDirection: axisDirection ?? this.axisDirection,
      growthDirection: growthDirection ?? this.growthDirection,
      userScrollDirection: userScrollDirection ?? this.userScrollDirection,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      precedingScrollExtent: precedingScrollExtent ?? this.precedingScrollExtent,
      overlap: overlap ?? this.overlap,
      remainingPaintExtent: remainingPaintExtent ?? this.remainingPaintExtent,
      crossAxisExtent: crossAxisExtent ?? this.crossAxisExtent,
      crossAxisDirection: crossAxisDirection ?? this.crossAxisDirection,
      viewportMainAxisExtent: viewportMainAxisExtent ?? this.viewportMainAxisExtent,
      remainingCacheExtent: remainingCacheExtent ?? this.remainingCacheExtent,
      cacheOrigin: cacheOrigin ?? this.cacheOrigin,
    );
  }

  final AxisDirection axisDirection;

  final GrowthDirection growthDirection;

  final ScrollDirection userScrollDirection;

  final double scrollOffset;

  final double precedingScrollExtent;

  final double overlap;

  final double remainingPaintExtent;

  final double crossAxisExtent;

  final AxisDirection crossAxisDirection;

  final double viewportMainAxisExtent;

  final double cacheOrigin;


  final double remainingCacheExtent;

  Axis get axis => axisDirectionToAxis(axisDirection);

  GrowthDirection get normalizedGrowthDirection {
    switch (axisDirection) {
      case AxisDirection.down:
      case AxisDirection.right:
        return growthDirection;
      case AxisDirection.up:
      case AxisDirection.left:
        switch (growthDirection) {
          case GrowthDirection.forward:
            return GrowthDirection.reverse;
          case GrowthDirection.reverse:
            return GrowthDirection.forward;
        }
    }
  }

  @override
  bool get isTight => false;

  @override
  bool get isNormalized {
    return scrollOffset >= 0.0
        && crossAxisExtent >= 0.0
        && axisDirectionToAxis(axisDirection) != axisDirectionToAxis(crossAxisDirection)
        && viewportMainAxisExtent >= 0.0
        && remainingPaintExtent >= 0.0;
  }

  BoxConstraints asBoxConstraints({
    double minExtent = 0.0,
    double maxExtent = double.infinity,
    double? crossAxisExtent,
  }) {
    crossAxisExtent ??= this.crossAxisExtent;
    switch (axis) {
      case Axis.horizontal:
        return BoxConstraints(
          minHeight: crossAxisExtent,
          maxHeight: crossAxisExtent,
          minWidth: minExtent,
          maxWidth: maxExtent,
        );
      case Axis.vertical:
        return BoxConstraints(
          minWidth: crossAxisExtent,
          maxWidth: crossAxisExtent,
          minHeight: minExtent,
          maxHeight: maxExtent,
        );
    }
  }

  @override
  bool debugAssertIsValid({
    bool isAppliedConstraint = false,
    InformationCollector? informationCollector,
  }) {
    assert(() {
      bool hasErrors = false;
      final StringBuffer errorMessage = StringBuffer('\n');
      void verify(bool check, String message) {
        if (check) {
          return;
        }
        hasErrors = true;
        errorMessage.writeln('  $message');
      }
      void verifyDouble(double property, String name, {bool mustBePositive = false, bool mustBeNegative = false}) {
        if (property.isNaN) {
          String additional = '.';
          if (mustBePositive) {
            additional = ', expected greater than or equal to zero.';
          } else if (mustBeNegative) {
            additional = ', expected less than or equal to zero.';
          }
          verify(false, 'The "$name" is NaN$additional');
        } else if (mustBePositive) {
          verify(property >= 0.0, 'The "$name" is negative.');
        } else if (mustBeNegative) {
          verify(property <= 0.0, 'The "$name" is positive.');
        }
      }
      verifyDouble(scrollOffset, 'scrollOffset');
      verifyDouble(overlap, 'overlap');
      verifyDouble(crossAxisExtent, 'crossAxisExtent');
      verifyDouble(scrollOffset, 'scrollOffset', mustBePositive: true);
      verify(axisDirectionToAxis(axisDirection) != axisDirectionToAxis(crossAxisDirection), 'The "axisDirection" and the "crossAxisDirection" are along the same axis.');
      verifyDouble(viewportMainAxisExtent, 'viewportMainAxisExtent', mustBePositive: true);
      verifyDouble(remainingPaintExtent, 'remainingPaintExtent', mustBePositive: true);
      verifyDouble(remainingCacheExtent, 'remainingCacheExtent', mustBePositive: true);
      verifyDouble(cacheOrigin, 'cacheOrigin', mustBeNegative: true);
      verifyDouble(precedingScrollExtent, 'precedingScrollExtent', mustBePositive: true);
      verify(isNormalized, 'The constraints are not normalized.'); // should be redundant with earlier checks
      if (hasErrors) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType is not valid: $errorMessage'),
          if (informationCollector != null)
            ...informationCollector(),
          DiagnosticsProperty<SliverConstraints>('The offending constraints were', this, style: DiagnosticsTreeStyle.errorProperty),
        ]);
      }
      return true;
    }());
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SliverConstraints) {
      return false;
    }
    assert(other.debugAssertIsValid());
    return other.axisDirection == axisDirection
        && other.growthDirection == growthDirection
        && other.scrollOffset == scrollOffset
        && other.overlap == overlap
        && other.remainingPaintExtent == remainingPaintExtent
        && other.crossAxisExtent == crossAxisExtent
        && other.crossAxisDirection == crossAxisDirection
        && other.viewportMainAxisExtent == viewportMainAxisExtent
        && other.remainingCacheExtent == remainingCacheExtent
        && other.cacheOrigin == cacheOrigin;
  }

  @override
  int get hashCode => Object.hash(
    axisDirection,
    growthDirection,
    scrollOffset,
    overlap,
    remainingPaintExtent,
    crossAxisExtent,
    crossAxisDirection,
    viewportMainAxisExtent,
    remainingCacheExtent,
    cacheOrigin,
  );

  @override
  String toString() {
    final List<String> properties = <String>[
      '$axisDirection',
      '$growthDirection',
      '$userScrollDirection',
      'scrollOffset: ${scrollOffset.toStringAsFixed(1)}',
      'remainingPaintExtent: ${remainingPaintExtent.toStringAsFixed(1)}',
      if (overlap != 0.0) 'overlap: ${overlap.toStringAsFixed(1)}',
      'crossAxisExtent: ${crossAxisExtent.toStringAsFixed(1)}',
      'crossAxisDirection: $crossAxisDirection',
      'viewportMainAxisExtent: ${viewportMainAxisExtent.toStringAsFixed(1)}',
      'remainingCacheExtent: ${remainingCacheExtent.toStringAsFixed(1)}',
      'cacheOrigin: ${cacheOrigin.toStringAsFixed(1)}',
    ];
    return 'SliverConstraints(${properties.join(', ')})';
  }
}

@immutable
class SliverGeometry with Diagnosticable {
  const SliverGeometry({
    this.scrollExtent = 0.0,
    this.paintExtent = 0.0,
    this.paintOrigin = 0.0,
    double? layoutExtent,
    this.maxPaintExtent = 0.0,
    this.maxScrollObstructionExtent = 0.0,
    this.crossAxisExtent,
    double? hitTestExtent,
    bool? visible,
    this.hasVisualOverflow = false,
    this.scrollOffsetCorrection,
    double? cacheExtent,
  }) : assert(scrollOffsetCorrection != 0.0),
       layoutExtent = layoutExtent ?? paintExtent,
       hitTestExtent = hitTestExtent ?? paintExtent,
       cacheExtent = cacheExtent ?? layoutExtent ?? paintExtent,
       visible = visible ?? paintExtent > 0.0;

  SliverGeometry copyWith({
    double? scrollExtent,
    double? paintExtent,
    double? paintOrigin,
    double? layoutExtent,
    double? maxPaintExtent,
    double? maxScrollObstructionExtent,
    double? crossAxisExtent,
    double? hitTestExtent,
    bool? visible,
    bool? hasVisualOverflow,
    double? cacheExtent,
  }) {
    return SliverGeometry(
      scrollExtent: scrollExtent ?? this.scrollExtent,
      paintExtent: paintExtent ?? this.paintExtent,
      paintOrigin: paintOrigin ?? this.paintOrigin,
      layoutExtent: layoutExtent ?? this.layoutExtent,
      maxPaintExtent: maxPaintExtent ?? this.maxPaintExtent,
      maxScrollObstructionExtent: maxScrollObstructionExtent ?? this.maxScrollObstructionExtent,
      crossAxisExtent: crossAxisExtent ?? this.crossAxisExtent,
      hitTestExtent: hitTestExtent ?? this.hitTestExtent,
      visible: visible ?? this.visible,
      hasVisualOverflow: hasVisualOverflow ?? this.hasVisualOverflow,
      cacheExtent: cacheExtent ?? this.cacheExtent,
    );
  }

  static const SliverGeometry zero = SliverGeometry();

  final double scrollExtent;

  final double paintOrigin;

  final double paintExtent;

  final double layoutExtent;

  final double maxPaintExtent;

  final double maxScrollObstructionExtent;

  final double hitTestExtent;

  final bool visible;

  final bool hasVisualOverflow;

  final double? scrollOffsetCorrection;

  final double cacheExtent;

  final double? crossAxisExtent;

  bool debugAssertIsValid({
    InformationCollector? informationCollector,
  }) {
    assert(() {
      void verify(bool check, String summary, {List<DiagnosticsNode>? details}) {
        if (check) {
          return;
        }
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('${objectRuntimeType(this, 'SliverGeometry')} is not valid: $summary'),
          ...?details,
          if (informationCollector != null)
            ...informationCollector(),
        ]);
      }

      verify(scrollExtent >= 0.0, 'The "scrollExtent" is negative.');
      verify(paintExtent >= 0.0, 'The "paintExtent" is negative.');
      verify(layoutExtent >= 0.0, 'The "layoutExtent" is negative.');
      verify(cacheExtent >= 0.0, 'The "cacheExtent" is negative.');
      if (layoutExtent > paintExtent) {
        verify(false,
          'The "layoutExtent" exceeds the "paintExtent".',
          details: _debugCompareFloats('paintExtent', paintExtent, 'layoutExtent', layoutExtent),
        );
      }
      // If the paintExtent is slightly more than the maxPaintExtent, but the difference is still less
      // than precisionErrorTolerance, we will not throw the assert below.
      if (paintExtent - maxPaintExtent > precisionErrorTolerance) {
        verify(false,
          'The "maxPaintExtent" is less than the "paintExtent".',
          details:
            _debugCompareFloats('maxPaintExtent', maxPaintExtent, 'paintExtent', paintExtent)
              ..add(ErrorDescription("By definition, a sliver can't paint more than the maximum that it can paint!")),
        );
      }
      verify(hitTestExtent >= 0.0, 'The "hitTestExtent" is negative.');
      verify(scrollOffsetCorrection != 0.0, 'The "scrollOffsetCorrection" is zero.');
      return true;
    }());
    return true;
  }

  @override
  String toStringShort() => objectRuntimeType(this, 'SliverGeometry');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('scrollExtent', scrollExtent));
    if (paintExtent > 0.0) {
      properties.add(DoubleProperty('paintExtent', paintExtent, unit : visible ? null : ' but not painting'));
    } else if (paintExtent == 0.0) {
      if (visible) {
        properties.add(DoubleProperty('paintExtent', paintExtent, unit: visible ? null : ' but visible'));
      }
      properties.add(FlagProperty('visible', value: visible, ifFalse: 'hidden'));
    } else {
      // Negative paintExtent!
      properties.add(DoubleProperty('paintExtent', paintExtent, tooltip: '!'));
    }
    properties.add(DoubleProperty('paintOrigin', paintOrigin, defaultValue: 0.0));
    properties.add(DoubleProperty('layoutExtent', layoutExtent, defaultValue: paintExtent));
    properties.add(DoubleProperty('maxPaintExtent', maxPaintExtent));
    properties.add(DoubleProperty('hitTestExtent', hitTestExtent, defaultValue: paintExtent));
    properties.add(DiagnosticsProperty<bool>('hasVisualOverflow', hasVisualOverflow, defaultValue: false));
    properties.add(DoubleProperty('scrollOffsetCorrection', scrollOffsetCorrection, defaultValue: null));
    properties.add(DoubleProperty('cacheExtent', cacheExtent, defaultValue: 0.0));
  }
}

typedef SliverHitTest = bool Function(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition });

class SliverHitTestResult extends HitTestResult {
  SliverHitTestResult() : super();

  SliverHitTestResult.wrap(super.result) : super.wrap();

  bool addWithAxisOffset({
    required Offset? paintOffset,
    required double mainAxisOffset,
    required double crossAxisOffset,
    required double mainAxisPosition,
    required double crossAxisPosition,
    required SliverHitTest hitTest,
  }) {
    if (paintOffset != null) {
      pushOffset(-paintOffset);
    }
    final bool isHit = hitTest(
      this,
      mainAxisPosition: mainAxisPosition - mainAxisOffset,
      crossAxisPosition: crossAxisPosition - crossAxisOffset,
    );
    if (paintOffset != null) {
      popTransform();
    }
    return isHit;
  }
}

class SliverHitTestEntry extends HitTestEntry<RenderSliver> {
  SliverHitTestEntry(
    super.target, {
    required this.mainAxisPosition,
    required this.crossAxisPosition,
  });

  final double mainAxisPosition;

  final double crossAxisPosition;

  @override
  String toString() => '${target.runtimeType}@(mainAxis: $mainAxisPosition, crossAxis: $crossAxisPosition)';
}

class SliverLogicalParentData extends ParentData {
  double? layoutOffset;

  @override
  String toString() => 'layoutOffset=${layoutOffset == null ? 'None': layoutOffset!.toStringAsFixed(1)}';
}

class SliverLogicalContainerParentData extends SliverLogicalParentData with ContainerParentDataMixin<RenderSliver> { }

class SliverPhysicalParentData extends ParentData {
  Offset paintOffset = Offset.zero;

  int? crossAxisFlex;

  void applyPaintTransform(Matrix4 transform) {
    // Hit test logic relies on this always providing an invertible matrix.
    transform.translate(paintOffset.dx, paintOffset.dy);
  }

  @override
  String toString() => 'paintOffset=$paintOffset';
}

class SliverPhysicalContainerParentData extends SliverPhysicalParentData with ContainerParentDataMixin<RenderSliver> { }

List<DiagnosticsNode> _debugCompareFloats(String labelA, double valueA, String labelB, double valueB) {
  return <DiagnosticsNode>[
    if (valueA.toStringAsFixed(1) != valueB.toStringAsFixed(1))
      ErrorDescription(
        'The $labelA is ${valueA.toStringAsFixed(1)}, but '
        'the $labelB is ${valueB.toStringAsFixed(1)}.',
      )
    else ...<DiagnosticsNode>[
      ErrorDescription('The $labelA is $valueA, but the $labelB is $valueB.'),
      ErrorHint(
        'Maybe you have fallen prey to floating point rounding errors, and should explicitly '
        'apply the min() or max() functions, or the clamp() method, to the $labelB?',
      ),
    ],
  ];
}

abstract class RenderSliver extends RenderObject {
  // layout input
  @override
  SliverConstraints get constraints => super.constraints as SliverConstraints;

  SliverGeometry? get geometry => _geometry;
  SliverGeometry? _geometry;
  set geometry(SliverGeometry? value) {
    assert(!(debugDoingThisResize && debugDoingThisLayout));
    assert(sizedByParent || !debugDoingThisResize);
    assert(() {
      if ((sizedByParent && debugDoingThisResize) ||
          (!sizedByParent && debugDoingThisLayout)) {
        return true;
      }
      assert(!debugDoingThisResize);
      DiagnosticsNode? contract, violation, hint;
      if (debugDoingThisLayout) {
        assert(sizedByParent);
        violation = ErrorDescription('It appears that the geometry setter was called from performLayout().');
      } else {
        violation = ErrorDescription('The geometry setter was called from outside layout (neither performResize() nor performLayout() were being run for this object).');
        if (owner != null && owner!.debugDoingLayout) {
          hint = ErrorDescription('Only the object itself can set its geometry. It is a contract violation for other objects to set it.');
        }
      }
      if (sizedByParent) {
        contract = ErrorDescription('Because this RenderSliver has sizedByParent set to true, it must set its geometry in performResize().');
      } else {
        contract = ErrorDescription('Because this RenderSliver has sizedByParent set to false, it must set its geometry in performLayout().');
      }

      final List<DiagnosticsNode> information = <DiagnosticsNode>[
        ErrorSummary('RenderSliver geometry setter called incorrectly.'),
        violation,
        if (hint != null) hint,
        contract,
        describeForError('The RenderSliver in question is'),
      ];
      throw FlutterError.fromParts(information);
    }());
    _geometry = value;
  }

  @override
  Rect get semanticBounds => paintBounds;

  @override
  Rect get paintBounds {
    switch (constraints.axis) {
      case Axis.horizontal:
        return Rect.fromLTWH(
          0.0, 0.0,
          geometry!.paintExtent,
          constraints.crossAxisExtent,
        );
      case Axis.vertical:
        return Rect.fromLTWH(
          0.0, 0.0,
          constraints.crossAxisExtent,
          geometry!.paintExtent,
        );
    }
  }

  @override
  void debugResetSize() { }

  @override
  void debugAssertDoesMeetConstraints() {
    assert(geometry!.debugAssertIsValid(
      informationCollector: () => <DiagnosticsNode>[
        describeForError('The RenderSliver that returned the offending geometry was'),
      ],
    ));
    assert(() {
      if (geometry!.paintOrigin + geometry!.paintExtent > constraints.remainingPaintExtent) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('SliverGeometry has a paintOffset that exceeds the remainingPaintExtent from the constraints.'),
          describeForError('The render object whose geometry violates the constraints is the following'),
          ..._debugCompareFloats(
            'remainingPaintExtent', constraints.remainingPaintExtent,
            'paintOrigin + paintExtent', geometry!.paintOrigin + geometry!.paintExtent,
          ),
          ErrorDescription(
            'The paintOrigin and paintExtent must cause the child sliver to paint '
            'within the viewport, and so cannot exceed the remainingPaintExtent.',
          ),
        ]);
      }
      return true;
    }());
  }

  @override
  void performResize() {
    assert(false);
  }

  double get centerOffsetAdjustment => 0.0;

  bool hitTest(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition }) {
    if (mainAxisPosition >= 0.0 && mainAxisPosition < geometry!.hitTestExtent &&
        crossAxisPosition >= 0.0 && crossAxisPosition < constraints.crossAxisExtent) {
      if (hitTestChildren(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition) ||
          hitTestSelf(mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition)) {
        result.add(SliverHitTestEntry(
          this,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        ));
        return true;
      }
    }
    return false;
  }

  @protected
  bool hitTestSelf({ required double mainAxisPosition, required double crossAxisPosition }) => false;

  @protected
  bool hitTestChildren(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition }) => false;

  // This could be a static method but isn't, because it would be less convenient
  // to call it from subclasses if it was.
  double calculatePaintOffset(SliverConstraints constraints, { required double from, required double to }) {
    assert(from <= to);
    final double a = constraints.scrollOffset;
    final double b = constraints.scrollOffset + constraints.remainingPaintExtent;
    // the clamp on the next line is to avoid floating point rounding errors
    return clampDouble(clampDouble(to, a, b) - clampDouble(from, a, b), 0.0, constraints.remainingPaintExtent);
  }

  double calculateCacheOffset(SliverConstraints constraints, { required double from, required double to }) {
    assert(from <= to);
    final double a = constraints.scrollOffset + constraints.cacheOrigin;
    final double b = constraints.scrollOffset + constraints.remainingCacheExtent;
    // the clamp on the next line is to avoid floating point rounding errors
    return clampDouble(clampDouble(to, a, b) - clampDouble(from, a, b), 0.0, constraints.remainingCacheExtent);
  }

  @protected
  double childMainAxisPosition(covariant RenderObject child) {
    assert(() {
      throw FlutterError('${objectRuntimeType(this, 'RenderSliver')} does not implement childPosition.');
    }());
    return 0.0;
  }

  @protected
  double childCrossAxisPosition(covariant RenderObject child) => 0.0;

  double? childScrollOffset(covariant RenderObject child) {
    assert(child.parent == this);
    return 0.0;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(() {
      throw FlutterError('${objectRuntimeType(this, 'RenderSliver')} does not implement applyPaintTransform.');
    }());
  }

  @protected
  Size getAbsoluteSizeRelativeToOrigin() {
    assert(geometry != null);
    assert(!debugNeedsLayout);
    switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
      case AxisDirection.up:
        return Size(constraints.crossAxisExtent, -geometry!.paintExtent);
      case AxisDirection.right:
        return Size(geometry!.paintExtent, constraints.crossAxisExtent);
      case AxisDirection.down:
        return Size(constraints.crossAxisExtent, geometry!.paintExtent);
      case AxisDirection.left:
        return Size(-geometry!.paintExtent, constraints.crossAxisExtent);
    }
  }

  @protected
  Size getAbsoluteSize() {
    assert(geometry != null);
    assert(!debugNeedsLayout);
    switch (constraints.axisDirection) {
      case AxisDirection.up:
      case AxisDirection.down:
        return Size(constraints.crossAxisExtent, geometry!.paintExtent);
      case AxisDirection.right:
      case AxisDirection.left:
        return Size(geometry!.paintExtent, constraints.crossAxisExtent);
    }
  }

  void _debugDrawArrow(Canvas canvas, Paint paint, Offset p0, Offset p1, GrowthDirection direction) {
    assert(() {
      if (p0 == p1) {
        return true;
      }
      assert(p0.dx == p1.dx || p0.dy == p1.dy); // must be axis-aligned
      final double d = (p1 - p0).distance * 0.2;
      final Offset temp;
      double dx1, dx2, dy1, dy2;
      switch (direction) {
        case GrowthDirection.forward:
          dx1 = dx2 = dy1 = dy2 = d;
        case GrowthDirection.reverse:
          temp = p0;
          p0 = p1;
          p1 = temp;
          dx1 = dx2 = dy1 = dy2 = -d;
      }
      if (p0.dx == p1.dx) {
        dx2 = -dx2;
      } else {
        dy2 = -dy2;
      }
      canvas.drawPath(
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..moveTo(p1.dx - dx1, p1.dy - dy1)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p1.dx - dx2, p1.dy - dy2),
        paint,
      );
      return true;
    }());
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    assert(() {
      if (debugPaintSizeEnabled) {
        final double strokeWidth = math.min(4.0, geometry!.paintExtent / 30.0);
        final Paint paint = Paint()
          ..color = const Color(0xFF33CC33)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.solid, strokeWidth);
        final double arrowExtent = geometry!.paintExtent;
        final double padding = math.max(2.0, strokeWidth);
        final Canvas canvas = context.canvas;
        canvas.drawCircle(
          offset.translate(padding, padding),
          padding * 0.5,
          paint,
        );
        switch (constraints.axis) {
          case Axis.vertical:
            canvas.drawLine(
              offset,
              offset.translate(constraints.crossAxisExtent, 0.0),
              paint,
            );
            _debugDrawArrow(
              canvas,
              paint,
              offset.translate(constraints.crossAxisExtent * 1.0 / 4.0, padding),
              offset.translate(constraints.crossAxisExtent * 1.0 / 4.0, arrowExtent - padding),
              constraints.normalizedGrowthDirection,
            );
            _debugDrawArrow(
              canvas,
              paint,
              offset.translate(constraints.crossAxisExtent * 3.0 / 4.0, padding),
              offset.translate(constraints.crossAxisExtent * 3.0 / 4.0, arrowExtent - padding),
              constraints.normalizedGrowthDirection,
            );
          case Axis.horizontal:
            canvas.drawLine(
              offset,
              offset.translate(0.0, constraints.crossAxisExtent),
              paint,
            );
            _debugDrawArrow(
              canvas,
              paint,
              offset.translate(padding, constraints.crossAxisExtent * 1.0 / 4.0),
              offset.translate(arrowExtent - padding, constraints.crossAxisExtent * 1.0 / 4.0),
              constraints.normalizedGrowthDirection,
            );
            _debugDrawArrow(
              canvas,
              paint,
              offset.translate(padding, constraints.crossAxisExtent * 3.0 / 4.0),
              offset.translate(arrowExtent - padding, constraints.crossAxisExtent * 3.0 / 4.0),
              constraints.normalizedGrowthDirection,
            );
        }
      }
      return true;
    }());
  }

  // This override exists only to change the type of the second argument.
  @override
  void handleEvent(PointerEvent event, SliverHitTestEntry entry) { }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SliverGeometry>('geometry', geometry));
  }
}

mixin RenderSliverHelpers implements RenderSliver {
  bool _getRightWayUp(SliverConstraints constraints) {
    bool rightWayUp;
    switch (constraints.axisDirection) {
      case AxisDirection.up:
      case AxisDirection.left:
        rightWayUp = false;
      case AxisDirection.down:
      case AxisDirection.right:
        rightWayUp = true;
    }
    switch (constraints.growthDirection) {
      case GrowthDirection.forward:
        break;
      case GrowthDirection.reverse:
        rightWayUp = !rightWayUp;
    }
    return rightWayUp;
  }

  @protected
  bool hitTestBoxChild(BoxHitTestResult result, RenderBox child, { required double mainAxisPosition, required double crossAxisPosition }) {
    final bool rightWayUp = _getRightWayUp(constraints);
    double delta = childMainAxisPosition(child);
    final double crossAxisDelta = childCrossAxisPosition(child);
    double absolutePosition = mainAxisPosition - delta;
    final double absoluteCrossAxisPosition = crossAxisPosition - crossAxisDelta;
    Offset paintOffset, transformedPosition;
    switch (constraints.axis) {
      case Axis.horizontal:
        if (!rightWayUp) {
          absolutePosition = child.size.width - absolutePosition;
          delta = geometry!.paintExtent - child.size.width - delta;
        }
        paintOffset = Offset(delta, crossAxisDelta);
        transformedPosition = Offset(absolutePosition, absoluteCrossAxisPosition);
      case Axis.vertical:
        if (!rightWayUp) {
          absolutePosition = child.size.height - absolutePosition;
          delta = geometry!.paintExtent - child.size.height - delta;
        }
        paintOffset = Offset(crossAxisDelta, delta);
        transformedPosition = Offset(absoluteCrossAxisPosition, absolutePosition);
    }
    return result.addWithOutOfBandPosition(
      paintOffset: paintOffset,
      hitTest: (BoxHitTestResult result) {
        return child.hitTest(result, position: transformedPosition);
      },
    );
  }

  @protected
  void applyPaintTransformForBoxChild(RenderBox child, Matrix4 transform) {
    final bool rightWayUp = _getRightWayUp(constraints);
    double delta = childMainAxisPosition(child);
    final double crossAxisDelta = childCrossAxisPosition(child);
    switch (constraints.axis) {
      case Axis.horizontal:
        if (!rightWayUp) {
          delta = geometry!.paintExtent - child.size.width - delta;
        }
        transform.translate(delta, crossAxisDelta);
      case Axis.vertical:
        if (!rightWayUp) {
          delta = geometry!.paintExtent - child.size.height - delta;
        }
        transform.translate(crossAxisDelta, delta);
    }
  }
}

// ADAPTER FOR RENDER BOXES INSIDE SLIVERS
// Transitions from the RenderSliver world to the RenderBox world.

abstract class RenderSliverSingleBoxAdapter extends RenderSliver with RenderObjectWithChildMixin<RenderBox>, RenderSliverHelpers {
  RenderSliverSingleBoxAdapter({
    RenderBox? child,
  }) {
    this.child = child;
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) {
      child.parentData = SliverPhysicalParentData();
    }
  }

  @protected
  void setChildParentData(RenderObject child, SliverConstraints constraints, SliverGeometry geometry) {
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
      case AxisDirection.up:
        childParentData.paintOffset = Offset(0.0, -(geometry.scrollExtent - (geometry.paintExtent + constraints.scrollOffset)));
      case AxisDirection.right:
        childParentData.paintOffset = Offset(-constraints.scrollOffset, 0.0);
      case AxisDirection.down:
        childParentData.paintOffset = Offset(0.0, -constraints.scrollOffset);
      case AxisDirection.left:
        childParentData.paintOffset = Offset(-(geometry.scrollExtent - (geometry.paintExtent + constraints.scrollOffset)), 0.0);
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition }) {
    assert(geometry!.hitTestExtent > 0.0);
    if (child != null) {
      return hitTestBoxChild(BoxHitTestResult.wrap(result), child!, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
    }
    return false;
  }

  @override
  double childMainAxisPosition(RenderBox child) {
    return -constraints.scrollOffset;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child == this.child);
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    childParentData.applyPaintTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && geometry!.visible) {
      final SliverPhysicalParentData childParentData = child!.parentData! as SliverPhysicalParentData;
      context.paintChild(child!, offset + childParentData.paintOffset);
    }
  }
}

class RenderSliverToBoxAdapter extends RenderSliverSingleBoxAdapter {
  RenderSliverToBoxAdapter({
    super.child,
  });

  @override
  void performLayout() {
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    final SliverConstraints constraints = this.constraints;
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final double childExtent;
    switch (constraints.axis) {
      case Axis.horizontal:
        childExtent = child!.size.width;
      case Axis.vertical:
        childExtent = child!.size.height;
    }
    final double paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: childExtent);
    final double cacheExtent = calculateCacheOffset(constraints, from: 0.0, to: childExtent);

    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      scrollExtent: childExtent,
      paintExtent: paintedChildSize,
      cacheExtent: cacheExtent,
      maxPaintExtent: childExtent,
      hitTestExtent: paintedChildSize,
      hasVisualOverflow: childExtent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0,
    );
    setChildParentData(child!, constraints, geometry!);
  }
}