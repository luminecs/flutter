import 'dart:math' as math;
import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'package:vector_math/vector_math_64.dart';

import 'debug.dart';
import 'object.dart';

// Examples can assume:
// abstract class RenderBar extends RenderBox { }
// late RenderBox firstChild;
// void markNeedsLayout() { }

// This class should only be used in debug builds.
class _DebugSize extends Size {
  _DebugSize(super.source, this._owner, this._canBeUsedByParent) : super.copy();
  final RenderBox _owner;
  final bool _canBeUsedByParent;
}

class BoxConstraints extends Constraints {
  const BoxConstraints({
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
  });

  BoxConstraints.tight(Size size)
    : minWidth = size.width,
      maxWidth = size.width,
      minHeight = size.height,
      maxHeight = size.height;

  const BoxConstraints.tightFor({
    double? width,
    double? height,
  }) : minWidth = width ?? 0.0,
       maxWidth = width ?? double.infinity,
       minHeight = height ?? 0.0,
       maxHeight = height ?? double.infinity;

  const BoxConstraints.tightForFinite({
    double width = double.infinity,
    double height = double.infinity,
  }) : minWidth = width != double.infinity ? width : 0.0,
       maxWidth = width != double.infinity ? width : double.infinity,
       minHeight = height != double.infinity ? height : 0.0,
       maxHeight = height != double.infinity ? height : double.infinity;

  BoxConstraints.loose(Size size)
    : minWidth = 0.0,
      maxWidth = size.width,
      minHeight = 0.0,
      maxHeight = size.height;

  const BoxConstraints.expand({
    double? width,
    double? height,
  }) : minWidth = width ?? double.infinity,
       maxWidth = width ?? double.infinity,
       minHeight = height ?? double.infinity,
       maxHeight = height ?? double.infinity;

  final double minWidth;

  final double maxWidth;

  final double minHeight;

  final double maxHeight;

  BoxConstraints copyWith({
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    return BoxConstraints(
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
    );
  }

  BoxConstraints deflate(EdgeInsets edges) {
    assert(debugAssertIsValid());
    final double horizontal = edges.horizontal;
    final double vertical = edges.vertical;
    final double deflatedMinWidth = math.max(0.0, minWidth - horizontal);
    final double deflatedMinHeight = math.max(0.0, minHeight - vertical);
    return BoxConstraints(
      minWidth: deflatedMinWidth,
      maxWidth: math.max(deflatedMinWidth, maxWidth - horizontal),
      minHeight: deflatedMinHeight,
      maxHeight: math.max(deflatedMinHeight, maxHeight - vertical),
    );
  }

  BoxConstraints loosen() {
    assert(debugAssertIsValid());
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  BoxConstraints enforce(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: clampDouble(minWidth, constraints.minWidth, constraints.maxWidth),
      maxWidth: clampDouble(maxWidth, constraints.minWidth, constraints.maxWidth),
      minHeight: clampDouble(minHeight, constraints.minHeight, constraints.maxHeight),
      maxHeight: clampDouble(maxHeight, constraints.minHeight, constraints.maxHeight),
    );
  }

  BoxConstraints tighten({ double? width, double? height }) {
    return BoxConstraints(
      minWidth: width == null ? minWidth : clampDouble(width, minWidth, maxWidth),
      maxWidth: width == null ? maxWidth : clampDouble(width, minWidth, maxWidth),
      minHeight: height == null ? minHeight : clampDouble(height, minHeight, maxHeight),
      maxHeight: height == null ? maxHeight : clampDouble(height, minHeight, maxHeight),
    );
  }

  BoxConstraints get flipped {
    return BoxConstraints(
      minWidth: minHeight,
      maxWidth: maxHeight,
      minHeight: minWidth,
      maxHeight: maxWidth,
    );
  }

  BoxConstraints widthConstraints() => BoxConstraints(minWidth: minWidth, maxWidth: maxWidth);

  BoxConstraints heightConstraints() => BoxConstraints(minHeight: minHeight, maxHeight: maxHeight);

  double constrainWidth([ double width = double.infinity ]) {
    assert(debugAssertIsValid());
    return clampDouble(width, minWidth, maxWidth);
  }

  double constrainHeight([ double height = double.infinity ]) {
    assert(debugAssertIsValid());
    return clampDouble(height, minHeight, maxHeight);
  }

  Size _debugPropagateDebugSize(Size size, Size result) {
    assert(() {
      if (size is _DebugSize) {
        result = _DebugSize(result, size._owner, size._canBeUsedByParent);
      }
      return true;
    }());
    return result;
  }

  Size constrain(Size size) {
    Size result = Size(constrainWidth(size.width), constrainHeight(size.height));
    assert(() {
      result = _debugPropagateDebugSize(size, result);
      return true;
    }());
    return result;
  }

  Size constrainDimensions(double width, double height) {
    return Size(constrainWidth(width), constrainHeight(height));
  }

  Size constrainSizeAndAttemptToPreserveAspectRatio(Size size) {
    if (isTight) {
      Size result = smallest;
      assert(() {
        result = _debugPropagateDebugSize(size, result);
        return true;
      }());
      return result;
    }

    double width = size.width;
    double height = size.height;
    assert(width > 0.0);
    assert(height > 0.0);
    final double aspectRatio = width / height;

    if (width > maxWidth) {
      width = maxWidth;
      height = width / aspectRatio;
    }

    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }

    if (width < minWidth) {
      width = minWidth;
      height = width / aspectRatio;
    }

    if (height < minHeight) {
      height = minHeight;
      width = height * aspectRatio;
    }

    Size result = Size(constrainWidth(width), constrainHeight(height));
    assert(() {
      result = _debugPropagateDebugSize(size, result);
      return true;
    }());
    return result;
  }

  Size get biggest => Size(constrainWidth(), constrainHeight());

  Size get smallest => Size(constrainWidth(0.0), constrainHeight(0.0));

  bool get hasTightWidth => minWidth >= maxWidth;

  bool get hasTightHeight => minHeight >= maxHeight;

  @override
  bool get isTight => hasTightWidth && hasTightHeight;

  bool get hasBoundedWidth => maxWidth < double.infinity;

  bool get hasBoundedHeight => maxHeight < double.infinity;

  bool get hasInfiniteWidth => minWidth >= double.infinity;

  bool get hasInfiniteHeight => minHeight >= double.infinity;

  bool isSatisfiedBy(Size size) {
    assert(debugAssertIsValid());
    return (minWidth <= size.width) && (size.width <= maxWidth) &&
           (minHeight <= size.height) && (size.height <= maxHeight);
  }

  BoxConstraints operator*(double factor) {
    return BoxConstraints(
      minWidth: minWidth * factor,
      maxWidth: maxWidth * factor,
      minHeight: minHeight * factor,
      maxHeight: maxHeight * factor,
    );
  }

  BoxConstraints operator/(double factor) {
    return BoxConstraints(
      minWidth: minWidth / factor,
      maxWidth: maxWidth / factor,
      minHeight: minHeight / factor,
      maxHeight: maxHeight / factor,
    );
  }

  BoxConstraints operator~/(double factor) {
    return BoxConstraints(
      minWidth: (minWidth ~/ factor).toDouble(),
      maxWidth: (maxWidth ~/ factor).toDouble(),
      minHeight: (minHeight ~/ factor).toDouble(),
      maxHeight: (maxHeight ~/ factor).toDouble(),
    );
  }

  BoxConstraints operator%(double value) {
    return BoxConstraints(
      minWidth: minWidth % value,
      maxWidth: maxWidth % value,
      minHeight: minHeight % value,
      maxHeight: maxHeight % value,
    );
  }

  static BoxConstraints? lerp(BoxConstraints? a, BoxConstraints? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    assert(a.debugAssertIsValid());
    assert(b.debugAssertIsValid());
    assert((a.minWidth.isFinite && b.minWidth.isFinite) || (a.minWidth == double.infinity && b.minWidth == double.infinity), 'Cannot interpolate between finite constraints and unbounded constraints.');
    assert((a.maxWidth.isFinite && b.maxWidth.isFinite) || (a.maxWidth == double.infinity && b.maxWidth == double.infinity), 'Cannot interpolate between finite constraints and unbounded constraints.');
    assert((a.minHeight.isFinite && b.minHeight.isFinite) || (a.minHeight == double.infinity && b.minHeight == double.infinity), 'Cannot interpolate between finite constraints and unbounded constraints.');
    assert((a.maxHeight.isFinite && b.maxHeight.isFinite) || (a.maxHeight == double.infinity && b.maxHeight == double.infinity), 'Cannot interpolate between finite constraints and unbounded constraints.');
    return BoxConstraints(
      minWidth: a.minWidth.isFinite ? ui.lerpDouble(a.minWidth, b.minWidth, t)! : double.infinity,
      maxWidth: a.maxWidth.isFinite ? ui.lerpDouble(a.maxWidth, b.maxWidth, t)! : double.infinity,
      minHeight: a.minHeight.isFinite ? ui.lerpDouble(a.minHeight, b.minHeight, t)! : double.infinity,
      maxHeight: a.maxHeight.isFinite ? ui.lerpDouble(a.maxHeight, b.maxHeight, t)! : double.infinity,
    );
  }

  @override
  bool get isNormalized {
    return minWidth >= 0.0 &&
           minWidth <= maxWidth &&
           minHeight >= 0.0 &&
           minHeight <= maxHeight;
  }

  @override
  bool debugAssertIsValid({
    bool isAppliedConstraint = false,
    InformationCollector? informationCollector,
  }) {
    assert(() {
      void throwError(DiagnosticsNode message) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          message,
          if (informationCollector != null) ...informationCollector(),
          DiagnosticsProperty<BoxConstraints>('The offending constraints were', this, style: DiagnosticsTreeStyle.errorProperty),
        ]);
      }
      if (minWidth.isNaN || maxWidth.isNaN || minHeight.isNaN || maxHeight.isNaN) {
        final List<String> affectedFieldsList = <String>[
          if (minWidth.isNaN) 'minWidth',
          if (maxWidth.isNaN) 'maxWidth',
          if (minHeight.isNaN) 'minHeight',
          if (maxHeight.isNaN) 'maxHeight',
        ];
        assert(affectedFieldsList.isNotEmpty);
        if (affectedFieldsList.length > 1) {
          affectedFieldsList.add('and ${affectedFieldsList.removeLast()}');
        }
        String whichFields = '';
        if (affectedFieldsList.length > 2) {
          whichFields = affectedFieldsList.join(', ');
        } else if (affectedFieldsList.length == 2) {
          whichFields = affectedFieldsList.join(' ');
        } else {
          whichFields = affectedFieldsList.single;
        }
        throwError(ErrorSummary('BoxConstraints has ${affectedFieldsList.length == 1 ? 'a NaN value' : 'NaN values' } in $whichFields.'));
      }
      if (minWidth < 0.0 && minHeight < 0.0) {
        throwError(ErrorSummary('BoxConstraints has both a negative minimum width and a negative minimum height.'));
      }
      if (minWidth < 0.0) {
        throwError(ErrorSummary('BoxConstraints has a negative minimum width.'));
      }
      if (minHeight < 0.0) {
        throwError(ErrorSummary('BoxConstraints has a negative minimum height.'));
      }
      if (maxWidth < minWidth && maxHeight < minHeight) {
        throwError(ErrorSummary('BoxConstraints has both width and height constraints non-normalized.'));
      }
      if (maxWidth < minWidth) {
        throwError(ErrorSummary('BoxConstraints has non-normalized width constraints.'));
      }
      if (maxHeight < minHeight) {
        throwError(ErrorSummary('BoxConstraints has non-normalized height constraints.'));
      }
      if (isAppliedConstraint) {
        if (minWidth.isInfinite && minHeight.isInfinite) {
          throwError(ErrorSummary('BoxConstraints forces an infinite width and infinite height.'));
        }
        if (minWidth.isInfinite) {
          throwError(ErrorSummary('BoxConstraints forces an infinite width.'));
        }
        if (minHeight.isInfinite) {
          throwError(ErrorSummary('BoxConstraints forces an infinite height.'));
        }
      }
      assert(isNormalized);
      return true;
    }());
    return isNormalized;
  }

  BoxConstraints normalize() {
    if (isNormalized) {
      return this;
    }
    final double minWidth = this.minWidth >= 0.0 ? this.minWidth : 0.0;
    final double minHeight = this.minHeight >= 0.0 ? this.minHeight : 0.0;
    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: minWidth > maxWidth ? minWidth : maxWidth,
      minHeight: minHeight,
      maxHeight: minHeight > maxHeight ? minHeight : maxHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    assert(debugAssertIsValid());
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    assert(other is BoxConstraints && other.debugAssertIsValid());
    return other is BoxConstraints
        && other.minWidth == minWidth
        && other.maxWidth == maxWidth
        && other.minHeight == minHeight
        && other.maxHeight == maxHeight;
  }

  @override
  int get hashCode {
    assert(debugAssertIsValid());
    return Object.hash(minWidth, maxWidth, minHeight, maxHeight);
  }

  @override
  String toString() {
    final String annotation = isNormalized ? '' : '; NOT NORMALIZED';
    if (minWidth == double.infinity && minHeight == double.infinity) {
      return 'BoxConstraints(biggest$annotation)';
    }
    if (minWidth == 0 && maxWidth == double.infinity &&
        minHeight == 0 && maxHeight == double.infinity) {
      return 'BoxConstraints(unconstrained$annotation)';
    }
    String describe(double min, double max, String dim) {
      if (min == max) {
        return '$dim=${min.toStringAsFixed(1)}';
      }
      return '${min.toStringAsFixed(1)}<=$dim<=${max.toStringAsFixed(1)}';
    }
    final String width = describe(minWidth, maxWidth, 'w');
    final String height = describe(minHeight, maxHeight, 'h');
    return 'BoxConstraints($width, $height$annotation)';
  }
}

typedef BoxHitTest = bool Function(BoxHitTestResult result, Offset position);

typedef BoxHitTestWithOutOfBandPosition = bool Function(BoxHitTestResult result);

class BoxHitTestResult extends HitTestResult {
  BoxHitTestResult() : super();

  BoxHitTestResult.wrap(super.result) : super.wrap();

  bool addWithPaintTransform({
    required Matrix4? transform,
    required Offset position,
    required BoxHitTest hitTest,
  }) {
    if (transform != null) {
      transform = Matrix4.tryInvert(PointerEvent.removePerspectiveTransform(transform));
      if (transform == null) {
        // Objects are not visible on screen and cannot be hit-tested.
        return false;
      }
    }
    return addWithRawTransform(
      transform: transform,
      position: position,
      hitTest: hitTest,
    );
  }

  bool addWithPaintOffset({
    required Offset? offset,
    required Offset position,
    required BoxHitTest hitTest,
  }) {
    final Offset transformedPosition = offset == null ? position : position - offset;
    if (offset != null) {
      pushOffset(-offset);
    }
    final bool isHit = hitTest(this, transformedPosition);
    if (offset != null) {
      popTransform();
    }
    return isHit;
  }

  bool addWithRawTransform({
    required Matrix4? transform,
    required Offset position,
    required BoxHitTest hitTest,
  }) {
    final Offset transformedPosition = transform == null ?
        position : MatrixUtils.transformPoint(transform, position);
    if (transform != null) {
      pushTransform(transform);
    }
    final bool isHit = hitTest(this, transformedPosition);
    if (transform != null) {
      popTransform();
    }
    return isHit;
  }

  bool addWithOutOfBandPosition({
    Offset? paintOffset,
    Matrix4? paintTransform,
    Matrix4? rawTransform,
    required BoxHitTestWithOutOfBandPosition hitTest,
  }) {
    assert(
      (paintOffset == null && paintTransform == null && rawTransform != null) ||
      (paintOffset == null && paintTransform != null && rawTransform == null) ||
      (paintOffset != null && paintTransform == null && rawTransform == null),
      'Exactly one transform or offset argument must be provided.',
    );
    if (paintOffset != null) {
      pushOffset(-paintOffset);
    } else if (rawTransform != null) {
      pushTransform(rawTransform);
    } else {
      assert(paintTransform != null);
      paintTransform = Matrix4.tryInvert(PointerEvent.removePerspectiveTransform(paintTransform!));
      assert(paintTransform != null, 'paintTransform must be invertible.');
      pushTransform(paintTransform!);
    }
    final bool isHit = hitTest(this);
    popTransform();
    return isHit;
  }
}

class BoxHitTestEntry extends HitTestEntry<RenderBox> {
  BoxHitTestEntry(super.target, this.localPosition);

  final Offset localPosition;

  @override
  String toString() => '${describeIdentity(target)}@$localPosition';
}

class BoxParentData extends ParentData {
  Offset offset = Offset.zero;

  @override
  String toString() => 'offset=$offset';
}

abstract class ContainerBoxParentData<ChildType extends RenderObject> extends BoxParentData with ContainerParentDataMixin<ChildType> { }

enum _IntrinsicDimension { minWidth, maxWidth, minHeight, maxHeight }

@immutable
class _IntrinsicDimensionsCacheEntry {
  const _IntrinsicDimensionsCacheEntry(this.dimension, this.argument);

  final _IntrinsicDimension dimension;
  final double argument;

  @override
  bool operator ==(Object other) {
    return other is _IntrinsicDimensionsCacheEntry
        && other.dimension == dimension
        && other.argument == argument;
  }

  @override
  int get hashCode => Object.hash(dimension, argument);
}

abstract class RenderBox extends RenderObject {
  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  Map<_IntrinsicDimensionsCacheEntry, double>? _cachedIntrinsicDimensions;
  static int _debugIntrinsicsDepth = 0;

  double _computeIntrinsicDimension(_IntrinsicDimension dimension, double argument, double Function(double argument) computer) {
    assert(RenderObject.debugCheckingIntrinsics || !debugDoingThisResize); // performResize should not depend on anything except the incoming constraints
    bool shouldCache = true;
    assert(() {
      // we don't want the checked-mode intrinsic tests to affect
      // who gets marked dirty, etc.
      if (RenderObject.debugCheckingIntrinsics) {
        shouldCache = false;
      }
      return true;
    }());
    if (shouldCache) {
      Map<String, String>? debugTimelineArguments;
      assert(() {
        if (debugEnhanceLayoutTimelineArguments) {
          debugTimelineArguments = toDiagnosticsNode().toTimelineArguments();
        } else {
          debugTimelineArguments = <String, String>{};
        }
        debugTimelineArguments!['intrinsics dimension'] = dimension.name;
        debugTimelineArguments!['intrinsics argument'] = '$argument';
        return true;
      }());
      if (!kReleaseMode) {
        if (debugProfileLayoutsEnabled || _debugIntrinsicsDepth == 0) {
          FlutterTimeline.startSync(
            '$runtimeType intrinsics',
            arguments: debugTimelineArguments,
          );
        }
        _debugIntrinsicsDepth += 1;
      }
      _cachedIntrinsicDimensions ??= <_IntrinsicDimensionsCacheEntry, double>{};
      final double result = _cachedIntrinsicDimensions!.putIfAbsent(
        _IntrinsicDimensionsCacheEntry(dimension, argument),
        () => computer(argument),
      );
      if (!kReleaseMode) {
        _debugIntrinsicsDepth -= 1;
        if (debugProfileLayoutsEnabled || _debugIntrinsicsDepth == 0) {
          FlutterTimeline.finishSync();
        }
      }
      return result;
    }
    return computer(argument);
  }

  @mustCallSuper
  double getMinIntrinsicWidth(double height) {
    assert(() {
      if (height < 0.0) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('The height argument to getMinIntrinsicWidth was negative.'),
          ErrorDescription('The argument to getMinIntrinsicWidth must not be negative or null.'),
          ErrorHint(
            'If you perform computations on another height before passing it to '
            'getMinIntrinsicWidth, consider using math.max() or double.clamp() '
            'to force the value into the valid range.',
          ),
        ]);
      }
      return true;
    }());
    return _computeIntrinsicDimension(_IntrinsicDimension.minWidth, height, computeMinIntrinsicWidth);
  }

  @protected
  double computeMinIntrinsicWidth(double height) {
    return 0.0;
  }

  @mustCallSuper
  double getMaxIntrinsicWidth(double height) {
    assert(() {
      if (height < 0.0) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('The height argument to getMaxIntrinsicWidth was negative.'),
          ErrorDescription('The argument to getMaxIntrinsicWidth must not be negative or null.'),
          ErrorHint(
            'If you perform computations on another height before passing it to '
            'getMaxIntrinsicWidth, consider using math.max() or double.clamp() '
            'to force the value into the valid range.',
          ),
        ]);
      }
      return true;
    }());
    return _computeIntrinsicDimension(_IntrinsicDimension.maxWidth, height, computeMaxIntrinsicWidth);
  }

  @protected
  double computeMaxIntrinsicWidth(double height) {
    return 0.0;
  }

  @mustCallSuper
  double getMinIntrinsicHeight(double width) {
    assert(() {
      if (width < 0.0) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('The width argument to getMinIntrinsicHeight was negative.'),
          ErrorDescription('The argument to getMinIntrinsicHeight must not be negative or null.'),
          ErrorHint(
            'If you perform computations on another width before passing it to '
            'getMinIntrinsicHeight, consider using math.max() or double.clamp() '
            'to force the value into the valid range.',
          ),
        ]);
      }
      return true;
    }());
    return _computeIntrinsicDimension(_IntrinsicDimension.minHeight, width, computeMinIntrinsicHeight);
  }

  @protected
  double computeMinIntrinsicHeight(double width) {
    return 0.0;
  }

  @mustCallSuper
  double getMaxIntrinsicHeight(double width) {
    assert(() {
      if (width < 0.0) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('The width argument to getMaxIntrinsicHeight was negative.'),
          ErrorDescription('The argument to getMaxIntrinsicHeight must not be negative or null.'),
          ErrorHint(
            'If you perform computations on another width before passing it to '
            'getMaxIntrinsicHeight, consider using math.max() or double.clamp() '
            'to force the value into the valid range.',
          ),
        ]);
      }
      return true;
    }());
    return _computeIntrinsicDimension(_IntrinsicDimension.maxHeight, width, computeMaxIntrinsicHeight);
  }

  @protected
  double computeMaxIntrinsicHeight(double width) {
    return 0.0;
  }

  Map<BoxConstraints, Size>? _cachedDryLayoutSizes;
  bool _computingThisDryLayout = false;

  @mustCallSuper
  Size getDryLayout(BoxConstraints constraints) {
    bool shouldCache = true;
    assert(() {
      // we don't want the checked-mode intrinsic tests to affect
      // who gets marked dirty, etc.
      if (RenderObject.debugCheckingIntrinsics) {
        shouldCache = false;
      }
      return true;
    }());
    if (shouldCache) {
      Map<String, String>? debugTimelineArguments;
      assert(() {
        if (debugEnhanceLayoutTimelineArguments) {
          debugTimelineArguments = toDiagnosticsNode().toTimelineArguments();
        } else {
          debugTimelineArguments = <String, String>{};
        }
        debugTimelineArguments!['getDryLayout constraints'] = '$constraints';
        return true;
      }());
      if (!kReleaseMode) {
        if (debugProfileLayoutsEnabled || _debugIntrinsicsDepth == 0) {
          FlutterTimeline.startSync(
            '$runtimeType.getDryLayout',
            arguments: debugTimelineArguments,
          );
        }
        _debugIntrinsicsDepth += 1;
      }
      _cachedDryLayoutSizes ??= <BoxConstraints, Size>{};
      final Size result = _cachedDryLayoutSizes!.putIfAbsent(constraints, () => _computeDryLayout(constraints));
      if (!kReleaseMode) {
        _debugIntrinsicsDepth -= 1;
        if (debugProfileLayoutsEnabled || _debugIntrinsicsDepth == 0) {
          FlutterTimeline.finishSync();
        }
      }
      return result;
    }
    return _computeDryLayout(constraints);
  }

  Size _computeDryLayout(BoxConstraints constraints) {
    assert(() {
      assert(!_computingThisDryLayout);
      _computingThisDryLayout = true;
      return true;
    }());
    final Size result = computeDryLayout(constraints);
    assert(() {
      assert(_computingThisDryLayout);
      _computingThisDryLayout = false;
      return true;
    }());
    return result;
  }

  @protected
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      error: FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('The ${objectRuntimeType(this, 'RenderBox')} class does not implement "computeDryLayout".'),
        ErrorHint(
          'If you are not writing your own RenderBox subclass, then this is not\n'
          'your fault. Contact support: https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
        ),
      ]),
    ));
    return Size.zero;
  }

  static bool _dryLayoutCalculationValid = true;

  bool debugCannotComputeDryLayout({String? reason, FlutterError? error}) {
    assert((reason == null) != (error == null));
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        if (reason != null) {
          assert(error ==null);
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('The ${objectRuntimeType(this, 'RenderBox')} class does not support dry layout.'),
            if (reason.isNotEmpty) ErrorDescription(reason),
          ]);
        }
        assert(error != null);
        throw error!;
      }
      _dryLayoutCalculationValid = false;
      return true;
    }());
    return true;
  }

  bool get hasSize => _size != null;

  Size get size {
    assert(hasSize, 'RenderBox was not laid out: $this');
    assert(() {
      final Size? size = _size;
      if (size is _DebugSize) {
        assert(size._owner == this);
        if (RenderObject.debugActiveLayout != null &&
            !RenderObject.debugActiveLayout!.debugDoingThisLayoutWithCallback) {
          assert(
            debugDoingThisResize || debugDoingThisLayout || _computingThisDryLayout ||
              (RenderObject.debugActiveLayout == parent && size._canBeUsedByParent),
            'RenderBox.size accessed beyond the scope of resize, layout, or '
            'permitted parent access. RenderBox can always access its own size, '
            'otherwise, the only object that is allowed to read RenderBox.size '
            'is its parent, if they have said they will. It you hit this assert '
            'trying to access a child\'s size, pass "parentUsesSize: true" to '
            "that child's layout().",
          );
        }
        assert(size == _size);
      }
      return true;
    }());
    return _size ?? (throw StateError('RenderBox was not laid out: $runtimeType#${shortHash(this)}'));
  }
  Size? _size;
  @protected
  set size(Size value) {
    assert(!(debugDoingThisResize && debugDoingThisLayout));
    assert(sizedByParent || !debugDoingThisResize);
    assert(() {
      if ((sizedByParent && debugDoingThisResize) ||
          (!sizedByParent && debugDoingThisLayout)) {
        return true;
      }
      assert(!debugDoingThisResize);
      final List<DiagnosticsNode> information = <DiagnosticsNode>[
        ErrorSummary('RenderBox size setter called incorrectly.'),
      ];
      if (debugDoingThisLayout) {
        assert(sizedByParent);
        information.add(ErrorDescription('It appears that the size setter was called from performLayout().'));
      } else {
        information.add(ErrorDescription(
          'The size setter was called from outside layout (neither performResize() nor performLayout() were being run for this object).',
        ));
        if (owner != null && owner!.debugDoingLayout) {
          information.add(ErrorDescription('Only the object itself can set its size. It is a contract violation for other objects to set it.'));
        }
      }
      if (sizedByParent) {
        information.add(ErrorDescription('Because this RenderBox has sizedByParent set to true, it must set its size in performResize().'));
      } else {
        information.add(ErrorDescription('Because this RenderBox has sizedByParent set to false, it must set its size in performLayout().'));
      }
      throw FlutterError.fromParts(information);
    }());
    assert(() {
      value = debugAdoptSize(value);
      return true;
    }());
    _size = value;
    assert(() {
      debugAssertDoesMeetConstraints();
      return true;
    }());
  }

  Size debugAdoptSize(Size value) {
    Size result = value;
    assert(() {
      if (value is _DebugSize) {
        if (value._owner != this) {
          if (value._owner.parent != this) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('The size property was assigned a size inappropriately.'),
              describeForError('The following render object'),
              value._owner.describeForError('...was assigned a size obtained from'),
              ErrorDescription(
                'However, this second render object is not, or is no longer, a '
                'child of the first, and it is therefore a violation of the '
                'RenderBox layout protocol to use that size in the layout of the '
                'first render object.',
              ),
              ErrorHint(
                'If the size was obtained at a time where it was valid to read '
                'the size (because the second render object above was a child '
                'of the first at the time), then it should be adopted using '
                'debugAdoptSize at that time.',
              ),
              ErrorHint(
                'If the size comes from a grandchild or a render object from an '
                'entirely different part of the render tree, then there is no '
                'way to be notified when the size changes and therefore attempts '
                'to read that size are almost certainly a source of bugs. A different '
                'approach should be used.',
              ),
            ]);
          }
          if (!value._canBeUsedByParent) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary("A child's size was used without setting parentUsesSize."),
              describeForError('The following render object'),
              value._owner.describeForError('...was assigned a size obtained from its child'),
              ErrorDescription(
                'However, when the child was laid out, the parentUsesSize argument '
                'was not set or set to false. Subsequently this transpired to be '
                'inaccurate: the size was nonetheless used by the parent.\n'
                'It is important to tell the framework if the size will be used or not '
                'as several important performance optimizations can be made if the '
                'size will not be used by the parent.',
              ),
            ]);
          }
        }
      }
      result = _DebugSize(value, this, debugCanParentUseSize);
      return true;
    }());
    return result;
  }

  @override
  Rect get semanticBounds => Offset.zero & size;

  @override
  void debugResetSize() {
    // updates the value of size._canBeUsedByParent if necessary
    size = size; // ignore: no_self_assignments
  }

  Map<TextBaseline, double?>? _cachedBaselines;
  static bool _debugDoingBaseline = false;
  static bool _debugSetDoingBaseline(bool value) {
    _debugDoingBaseline = value;
    return true;
  }

  double? getDistanceToBaseline(TextBaseline baseline, { bool onlyReal = false }) {
    assert(!_debugDoingBaseline, 'Please see the documentation for computeDistanceToActualBaseline for the required calling conventions of this method.');
    assert(!debugNeedsLayout);
    assert(() {
      if (owner!.debugDoingLayout) {
        return (RenderObject.debugActiveLayout == parent) && parent!.debugDoingThisLayout;
      }
      if (owner!.debugDoingPaint) {
        return ((RenderObject.debugActivePaint == parent) && parent!.debugDoingThisPaint) ||
               ((RenderObject.debugActivePaint == this) && debugDoingThisPaint);
      }
      return false;
    }());
    assert(_debugSetDoingBaseline(true));
    final double? result;
    try {
      result = getDistanceToActualBaseline(baseline);
    } finally {
      assert(_debugSetDoingBaseline(false));
    }
    if (result == null && !onlyReal) {
      return size.height;
    }
    return result;
  }

  @protected
  @mustCallSuper
  double? getDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugDoingBaseline, 'Please see the documentation for computeDistanceToActualBaseline for the required calling conventions of this method.');
    _cachedBaselines ??= <TextBaseline, double?>{};
    return _cachedBaselines!.putIfAbsent(baseline, () => computeDistanceToActualBaseline(baseline));
  }

  @protected
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugDoingBaseline, 'Please see the documentation for computeDistanceToActualBaseline for the required calling conventions of this method.');
    return null;
  }

  @override
  BoxConstraints get constraints => super.constraints as BoxConstraints;

  @override
  void debugAssertDoesMeetConstraints() {
    assert(() {
      if (!hasSize) {
        final DiagnosticsNode contract;
        if (sizedByParent) {
          contract = ErrorDescription('Because this RenderBox has sizedByParent set to true, it must set its size in performResize().');
        } else {
          contract = ErrorDescription('Because this RenderBox has sizedByParent set to false, it must set its size in performLayout().');
        }
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('RenderBox did not set its size during layout.'),
          contract,
          ErrorDescription('It appears that this did not happen; layout completed, but the size property is still null.'),
          DiagnosticsProperty<RenderBox>('The RenderBox in question is', this, style: DiagnosticsTreeStyle.errorProperty),
        ]);
      }
      // verify that the size is not infinite
      if (!_size!.isFinite) {
        final List<DiagnosticsNode> information = <DiagnosticsNode>[
          ErrorSummary('$runtimeType object was given an infinite size during layout.'),
          ErrorDescription(
            'This probably means that it is a render object that tries to be '
            'as big as possible, but it was put inside another render object '
            'that allows its children to pick their own size.',
          ),
        ];
        if (!constraints.hasBoundedWidth) {
          RenderBox node = this;
          while (!node.constraints.hasBoundedWidth && node.parent is RenderBox) {
            node = node.parent! as RenderBox;
          }

          information.add(node.describeForError('The nearest ancestor providing an unbounded width constraint is'));
        }
        if (!constraints.hasBoundedHeight) {
          RenderBox node = this;
          while (!node.constraints.hasBoundedHeight && node.parent is RenderBox) {
            node = node.parent! as RenderBox;
          }

          information.add(node.describeForError('The nearest ancestor providing an unbounded height constraint is'));
        }
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ...information,
          DiagnosticsProperty<BoxConstraints>('The constraints that applied to the $runtimeType were', constraints, style: DiagnosticsTreeStyle.errorProperty),
          DiagnosticsProperty<Size>('The exact size it was given was', _size, style: DiagnosticsTreeStyle.errorProperty),
          ErrorHint('See https://flutter.dev/docs/development/ui/layout/box-constraints for more information.'),
        ]);
      }
      // verify that the size is within the constraints
      if (!constraints.isSatisfiedBy(_size!)) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType does not meet its constraints.'),
          DiagnosticsProperty<BoxConstraints>('Constraints', constraints, style: DiagnosticsTreeStyle.errorProperty),
          DiagnosticsProperty<Size>('Size', _size, style: DiagnosticsTreeStyle.errorProperty),
          ErrorHint(
            'If you are not writing your own RenderBox subclass, then this is not '
            'your fault. Contact support: https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
          ),
        ]);
      }
      if (debugCheckIntrinsicSizes) {
        // verify that the intrinsics are sane
        assert(!RenderObject.debugCheckingIntrinsics);
        RenderObject.debugCheckingIntrinsics = true;
        final List<DiagnosticsNode> failures = <DiagnosticsNode>[];

        double testIntrinsic(double Function(double extent) function, String name, double constraint) {
          final double result = function(constraint);
          if (result < 0) {
            failures.add(ErrorDescription(' * $name($constraint) returned a negative value: $result'));
          }
          if (!result.isFinite) {
            failures.add(ErrorDescription(' * $name($constraint) returned a non-finite value: $result'));
          }
          return result;
        }

        void testIntrinsicsForValues(double Function(double extent) getMin, double Function(double extent) getMax, String name, double constraint) {
          final double min = testIntrinsic(getMin, 'getMinIntrinsic$name', constraint);
          final double max = testIntrinsic(getMax, 'getMaxIntrinsic$name', constraint);
          if (min > max) {
            failures.add(ErrorDescription(' * getMinIntrinsic$name($constraint) returned a larger value ($min) than getMaxIntrinsic$name($constraint) ($max)'));
          }
        }

        testIntrinsicsForValues(getMinIntrinsicWidth, getMaxIntrinsicWidth, 'Width', double.infinity);
        testIntrinsicsForValues(getMinIntrinsicHeight, getMaxIntrinsicHeight, 'Height', double.infinity);
        if (constraints.hasBoundedWidth) {
          testIntrinsicsForValues(getMinIntrinsicWidth, getMaxIntrinsicWidth, 'Width', constraints.maxHeight);
        }
        if (constraints.hasBoundedHeight) {
          testIntrinsicsForValues(getMinIntrinsicHeight, getMaxIntrinsicHeight, 'Height', constraints.maxWidth);
        }

        // TODO(ianh): Test that values are internally consistent in more ways than the above.

        RenderObject.debugCheckingIntrinsics = false;
        if (failures.isNotEmpty) {
          // TODO(jacobr): consider nesting the failures object so it is collapsible.
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('The intrinsic dimension methods of the $runtimeType class returned values that violate the intrinsic protocol contract.'),
            ErrorDescription('The following ${failures.length > 1 ? "failures" : "failure"} was detected:'), // should this be tagged as an error or not?
            ...failures,
            ErrorHint(
              'If you are not writing your own RenderBox subclass, then this is not\n'
              'your fault. Contact support: https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
            ),
          ]);
        }

        // Checking that getDryLayout computes the same size.
        _dryLayoutCalculationValid = true;
        RenderObject.debugCheckingIntrinsics = true;
        final Size dryLayoutSize;
        try {
          dryLayoutSize = getDryLayout(constraints);
        } finally {
          RenderObject.debugCheckingIntrinsics = false;
        }
        if (_dryLayoutCalculationValid && dryLayoutSize != size) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('The size given to the ${objectRuntimeType(this, 'RenderBox')} class differs from the size computed by computeDryLayout.'),
            ErrorDescription(
              'The size computed in ${sizedByParent ? 'performResize' : 'performLayout'} '
              'is $size, which is different from $dryLayoutSize, which was computed by computeDryLayout.',
            ),
            ErrorDescription(
              'The constraints used were $constraints.',
            ),
            ErrorHint(
              'If you are not writing your own RenderBox subclass, then this is not\n'
              'your fault. Contact support: https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
            ),
          ]);
        }
      }
      return true;
    }());
  }

  bool _clearCachedData() {
    if ((_cachedBaselines != null && _cachedBaselines!.isNotEmpty) ||
        (_cachedIntrinsicDimensions != null && _cachedIntrinsicDimensions!.isNotEmpty) ||
        (_cachedDryLayoutSizes != null && _cachedDryLayoutSizes!.isNotEmpty)) {
      // If we have cached data, then someone must have used our data.
      // Since the parent will shortly be marked dirty, we can forget that they
      // used the baseline and/or intrinsic dimensions. If they use them again,
      // then we'll fill the cache again, and if we get dirty again, we'll
      // notify them again.
      _cachedBaselines?.clear();
      _cachedIntrinsicDimensions?.clear();
      _cachedDryLayoutSizes?.clear();
      return true;
    }
    return false;
  }

  @override
  void markNeedsLayout() {
    if (_clearCachedData() && parent is RenderObject) {
      markParentNeedsLayout();
      return;
    }
    super.markNeedsLayout();
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    if (hasSize && constraints != this.constraints &&
        _cachedBaselines != null && _cachedBaselines!.isNotEmpty) {
      // The cached baselines data may need update if the constraints change.
      _cachedBaselines?.clear();
    }
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  @override
  void performResize() {
    // default behavior for subclasses that have sizedByParent = true
    size = computeDryLayout(constraints);
    assert(size.isFinite);
  }

  @override
  void performLayout() {
    assert(() {
      if (!sizedByParent) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType did not implement performLayout().'),
          ErrorHint(
            'RenderBox subclasses need to either override performLayout() to '
            'set a size and lay out any children, or, set sizedByParent to true '
            'so that performResize() sizes the render object.',
          ),
        ]);
      }
      return true;
    }());
  }

  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    assert(() {
      if (!hasSize) {
        if (debugNeedsLayout) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Cannot hit test a render box that has never been laid out.'),
            describeForError('The hitTest() method was called on this RenderBox'),
            ErrorDescription(
              "Unfortunately, this object's geometry is not known at this time, "
              'probably because it has never been laid out. '
              'This means it cannot be accurately hit-tested.',
            ),
            ErrorHint(
              'If you are trying '
              'to perform a hit test during the layout phase itself, make sure '
              "you only hit test nodes that have completed layout (e.g. the node's "
              'children, after their layout() method has been called).',
            ),
          ]);
        }
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Cannot hit test a render box with no size.'),
          describeForError('The hitTest() method was called on this RenderBox'),
          ErrorDescription(
            'Although this node is not marked as needing layout, '
            'its size is not set.',
          ),
          ErrorHint(
            'A RenderBox object must have an '
            'explicit size before it can be hit-tested. Make sure '
            'that the RenderBox in question sets its size during layout.',
          ),
        ]);
      }
      return true;
    }());
    if (_size!.contains(position)) {
      if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return false;
  }

  @protected
  bool hitTestSelf(Offset position) => false;

  @protected
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) => false;

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child.parent == this);
    assert(() {
      if (child.parentData is! BoxParentData) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType does not implement applyPaintTransform.'),
          describeForError('The following $runtimeType object'),
          child.describeForError('...did not use a BoxParentData class for the parentData field of the following child'),
          ErrorDescription('The $runtimeType class inherits from RenderBox.'),
          ErrorHint(
            'The default applyPaintTransform implementation provided by RenderBox assumes that the '
            'children all use BoxParentData objects for their parentData field. '
            'Since $runtimeType does not in fact use that ParentData class for its children, it must '
            'provide an implementation of applyPaintTransform that supports the specific ParentData '
            'subclass used by its children (which apparently is ${child.parentData.runtimeType}).',
          ),
        ]);
      }
      return true;
    }());
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    final Offset offset = childParentData.offset;
    transform.translate(offset.dx, offset.dy);
  }

  Offset globalToLocal(Offset point, { RenderObject? ancestor }) {
    // We want to find point (p) that corresponds to a given point on the
    // screen (s), but that also physically resides on the local render plane,
    // so that it is useful for visually accurate gesture processing in the
    // local space. For that, we can't simply transform 2D screen point to
    // the 3D local space since the screen space lacks the depth component |z|,
    // and so there are many 3D points that correspond to the screen point.
    // We must first unproject the screen point onto the render plane to find
    // the true 3D point that corresponds to the screen point.
    // We do orthogonal unprojection after undoing perspective, in local space.
    // The render plane is specified by renderBox offset (o) and Z axis (n).
    // Unprojection is done by finding the intersection of the view vector (d)
    // with the local X-Y plane: (o-s).dot(n) == (p-s).dot(n), (p-s) == |z|*d.
    final Matrix4 transform = getTransformTo(ancestor);
    final double det = transform.invert();
    if (det == 0.0) {
      return Offset.zero;
    }
    final Vector3 n = Vector3(0.0, 0.0, 1.0);
    final Vector3 i = transform.perspectiveTransform(Vector3(0.0, 0.0, 0.0));
    final Vector3 d = transform.perspectiveTransform(Vector3(0.0, 0.0, 1.0)) - i;
    final Vector3 s = transform.perspectiveTransform(Vector3(point.dx, point.dy, 0.0));
    final Vector3 p = s - d * (n.dot(s) / n.dot(d));
    return Offset(p.x, p.y);
  }

  Offset localToGlobal(Offset point, { RenderObject? ancestor }) {
    return MatrixUtils.transformPoint(getTransformTo(ancestor), point);
  }

  @override
  Rect get paintBounds => Offset.zero & size;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
  }

  int _debugActivePointers = 0;

  bool debugHandleEvent(PointerEvent event, HitTestEntry entry) {
    assert(() {
      if (debugPaintPointersEnabled) {
        if (event is PointerDownEvent) {
          _debugActivePointers += 1;
        } else if (event is PointerUpEvent || event is PointerCancelEvent) {
          _debugActivePointers -= 1;
        }
        markNeedsPaint();
      }
      return true;
    }());
    return true;
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    assert(() {
      if (debugPaintSizeEnabled) {
        debugPaintSize(context, offset);
      }
      if (debugPaintBaselinesEnabled) {
        debugPaintBaselines(context, offset);
      }
      if (debugPaintPointersEnabled) {
        debugPaintPointers(context, offset);
      }
      return true;
    }());
  }

  @protected
  @visibleForTesting
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      final Paint paint = Paint()
       ..style = PaintingStyle.stroke
       ..strokeWidth = 1.0
       ..color = const Color(0xFF00FFFF);
      context.canvas.drawRect((offset & size).deflate(0.5), paint);
      return true;
    }());
  }

  @protected
  void debugPaintBaselines(PaintingContext context, Offset offset) {
    assert(() {
      final Paint paint = Paint()
       ..style = PaintingStyle.stroke
       ..strokeWidth = 0.25;
      Path path;
      // ideographic baseline
      final double? baselineI = getDistanceToBaseline(TextBaseline.ideographic, onlyReal: true);
      if (baselineI != null) {
        paint.color = const Color(0xFFFFD000);
        path = Path();
        path.moveTo(offset.dx, offset.dy + baselineI);
        path.lineTo(offset.dx + size.width, offset.dy + baselineI);
        context.canvas.drawPath(path, paint);
      }
      // alphabetic baseline
      final double? baselineA = getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
      if (baselineA != null) {
        paint.color = const Color(0xFF00FF00);
        path = Path();
        path.moveTo(offset.dx, offset.dy + baselineA);
        path.lineTo(offset.dx + size.width, offset.dy + baselineA);
        context.canvas.drawPath(path, paint);
      }
      return true;
    }());
  }

  @protected
  void debugPaintPointers(PaintingContext context, Offset offset) {
    assert(() {
      if (_debugActivePointers > 0) {
        final Paint paint = Paint()
         ..color = Color(0x00BBBB | ((0x04000000 * depth) & 0xFF000000));
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Size>('size', _size, missingIfNull: true));
  }
}

mixin RenderBoxContainerDefaultsMixin<ChildType extends RenderBox, ParentDataType extends ContainerBoxParentData<ChildType>> implements ContainerRenderObjectMixin<ChildType, ParentDataType> {
  double? defaultComputeDistanceToFirstActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    ChildType? child = firstChild;
    while (child != null) {
      final ParentDataType? childParentData = child.parentData as ParentDataType?;
      final double? result = child.getDistanceToActualBaseline(baseline);
      if (result != null) {
        return result + childParentData!.offset.dy;
      }
      child = childParentData!.nextSibling;
    }
    return null;
  }

  double? defaultComputeDistanceToHighestActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    double? result;
    ChildType? child = firstChild;
    while (child != null) {
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      double? candidate = child.getDistanceToActualBaseline(baseline);
      if (candidate != null) {
        candidate += childParentData.offset.dy;
        if (result != null) {
          result = math.min(result, candidate);
        } else {
          result = candidate;
        }
      }
      child = childParentData.nextSibling;
    }
    return result;
  }

  bool defaultHitTestChildren(BoxHitTestResult result, { required Offset position }) {
    ChildType? child = lastChild;
    while (child != null) {
      // The x, y parameters have the top left of the node's box as the origin.
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child!.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
      child = childParentData.previousSibling;
    }
    return false;
  }

  void defaultPaint(PaintingContext context, Offset offset) {
    ChildType? child = firstChild;
    while (child != null) {
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      context.paintChild(child, childParentData.offset + offset);
      child = childParentData.nextSibling;
    }
  }

  List<ChildType> getChildrenAsList() {
    final List<ChildType> result = <ChildType>[];
    RenderBox? child = firstChild;
    while (child != null) {
      final ParentDataType childParentData = child.parentData! as ParentDataType;
      result.add(child as ChildType);
      child = childParentData.nextSibling;
    }
    return result;
  }
}