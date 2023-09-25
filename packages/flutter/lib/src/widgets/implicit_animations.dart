import 'dart:ui' as ui show TextHeightBehavior;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart';

import 'basic.dart';
import 'container.dart';
import 'debug.dart';
import 'framework.dart';
import 'text.dart';
import 'ticker_provider.dart';
import 'transitions.dart';

// Examples can assume:
// class MyWidget extends ImplicitlyAnimatedWidget {
//   const MyWidget({super.key, this.targetColor = Colors.black}) : super(duration: const Duration(seconds: 1));
//   final Color targetColor;
//   @override
//   ImplicitlyAnimatedWidgetState<MyWidget> createState() => throw UnimplementedError(); // ignore: no_logic_in_create_state
// }
// void setState(VoidCallback fn) { }

class BoxConstraintsTween extends Tween<BoxConstraints> {
  BoxConstraintsTween({ super.begin, super.end });

  @override
  BoxConstraints lerp(double t) => BoxConstraints.lerp(begin, end, t)!;
}

class DecorationTween extends Tween<Decoration> {
  DecorationTween({ super.begin, super.end });

  @override
  Decoration lerp(double t) => Decoration.lerp(begin, end, t)!;
}

class EdgeInsetsTween extends Tween<EdgeInsets> {
  EdgeInsetsTween({ super.begin, super.end });

  @override
  EdgeInsets lerp(double t) => EdgeInsets.lerp(begin, end, t)!;
}

class EdgeInsetsGeometryTween extends Tween<EdgeInsetsGeometry> {
  EdgeInsetsGeometryTween({ super.begin, super.end });

  @override
  EdgeInsetsGeometry lerp(double t) => EdgeInsetsGeometry.lerp(begin, end, t)!;
}

class BorderRadiusTween extends Tween<BorderRadius?> {
  BorderRadiusTween({ super.begin, super.end });

  @override
  BorderRadius? lerp(double t) => BorderRadius.lerp(begin, end, t);
}

class BorderTween extends Tween<Border?> {
  BorderTween({ super.begin, super.end });

  @override
  Border? lerp(double t) => Border.lerp(begin, end, t);
}

class Matrix4Tween extends Tween<Matrix4> {
  Matrix4Tween({ super.begin, super.end });

  @override
  Matrix4 lerp(double t) {
    assert(begin != null);
    assert(end != null);
    final Vector3 beginTranslation = Vector3.zero();
    final Vector3 endTranslation = Vector3.zero();
    final Quaternion beginRotation = Quaternion.identity();
    final Quaternion endRotation = Quaternion.identity();
    final Vector3 beginScale = Vector3.zero();
    final Vector3 endScale = Vector3.zero();
    begin!.decompose(beginTranslation, beginRotation, beginScale);
    end!.decompose(endTranslation, endRotation, endScale);
    final Vector3 lerpTranslation =
        beginTranslation * (1.0 - t) + endTranslation * t;
    // TODO(alangardner): Implement lerp for constant rotation
    final Quaternion lerpRotation =
        (beginRotation.scaled(1.0 - t) + endRotation.scaled(t)).normalized();
    final Vector3 lerpScale = beginScale * (1.0 - t) + endScale * t;
    return Matrix4.compose(lerpTranslation, lerpRotation, lerpScale);
  }
}

class TextStyleTween extends Tween<TextStyle> {
  TextStyleTween({ super.begin, super.end });

  @override
  TextStyle lerp(double t) => TextStyle.lerp(begin, end, t)!;
}

abstract class ImplicitlyAnimatedWidget extends StatefulWidget {
  const ImplicitlyAnimatedWidget({
    super.key,
    this.curve = Curves.linear,
    required this.duration,
    this.onEnd,
  });

  final Curve curve;

  final Duration duration;

  final VoidCallback? onEnd;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('duration', duration.inMilliseconds, unit: 'ms'));
  }
}

typedef TweenConstructor<T extends Object> = Tween<T> Function(T targetValue);

typedef TweenVisitor<T extends Object> = Tween<T>? Function(Tween<T>? tween, T targetValue, TweenConstructor<T> constructor);

abstract class ImplicitlyAnimatedWidgetState<T extends ImplicitlyAnimatedWidget> extends State<T> with SingleTickerProviderStateMixin<T> {
  @protected
  AnimationController get controller => _controller;
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    debugLabel: kDebugMode ? widget.toStringShort() : null,
    vsync: this,
  );

  Animation<double> get animation => _animation;
  late CurvedAnimation _animation = _createCurve();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((AnimationStatus status) {
      switch (status) {
        case AnimationStatus.completed:
          widget.onEnd?.call();
        case AnimationStatus.dismissed:
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
      }
    });
    _constructTweens();
    didUpdateTweens();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = _createCurve();
    }
    _controller.duration = widget.duration;
    if (_constructTweens()) {
      forEachTween((Tween<dynamic>? tween, dynamic targetValue, TweenConstructor<dynamic> constructor) {
        _updateTween(tween, targetValue);
        return tween;
      });
      _controller
        ..value = 0.0
        ..forward();
      didUpdateTweens();
    }
  }

  CurvedAnimation _createCurve() {
    return CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAnimateTween(Tween<dynamic> tween, dynamic targetValue) {
    return targetValue != (tween.end ?? tween.begin);
  }

  void _updateTween(Tween<dynamic>? tween, dynamic targetValue) {
    if (tween == null) {
      return;
    }
    tween
      ..begin = tween.evaluate(_animation)
      ..end = targetValue;
  }

  bool _constructTweens() {
    bool shouldStartAnimation = false;
    forEachTween((Tween<dynamic>? tween, dynamic targetValue, TweenConstructor<dynamic> constructor) {
      if (targetValue != null) {
        tween ??= constructor(targetValue);
        if (_shouldAnimateTween(tween, targetValue)) {
          shouldStartAnimation = true;
        } else {
          tween.end ??= tween.begin;
        }
      } else {
        tween = null;
      }
      return tween;
    });
    return shouldStartAnimation;
  }

  @protected
  void forEachTween(TweenVisitor<dynamic> visitor);

  @protected
  void didUpdateTweens() { }
}

abstract class AnimatedWidgetBaseState<T extends ImplicitlyAnimatedWidget> extends ImplicitlyAnimatedWidgetState<T> {
  @override
  void initState() {
    super.initState();
    controller.addListener(_handleAnimationChanged);
  }

  void _handleAnimationChanged() {
    setState(() { /* The animation ticked. Rebuild with new animation value */ });
  }
}

class AnimatedContainer extends ImplicitlyAnimatedWidget {
  AnimatedContainer({
    super.key,
    this.alignment,
    this.padding,
    Color? color,
    Decoration? decoration,
    this.foregroundDecoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.child,
    this.clipBehavior = Clip.none,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(margin == null || margin.isNonNegative),
       assert(padding == null || padding.isNonNegative),
       assert(decoration == null || decoration.debugAssertIsValid()),
       assert(constraints == null || constraints.debugAssertIsValid()),
       assert(color == null || decoration == null,
         'Cannot provide both a color and a decoration\n'
         'The color argument is just a shorthand for "decoration: BoxDecoration(color: color)".',
       ),
       decoration = decoration ?? (color != null ? BoxDecoration(color: color) : null),
       constraints =
        (width != null || height != null)
          ? constraints?.tighten(width: width, height: height)
            ?? BoxConstraints.tightFor(width: width, height: height)
          : constraints;

  final Widget? child;

  final AlignmentGeometry? alignment;

  final EdgeInsetsGeometry? padding;

  final Decoration? decoration;

  final Decoration? foregroundDecoration;

  final BoxConstraints? constraints;

  final EdgeInsetsGeometry? margin;

  final Matrix4? transform;

  final AlignmentGeometry? transformAlignment;

  final Clip clipBehavior;

  @override
  AnimatedWidgetBaseState<AnimatedContainer> createState() => _AnimatedContainerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment, showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<Decoration>('bg', decoration, defaultValue: null));
    properties.add(DiagnosticsProperty<Decoration>('fg', foregroundDecoration, defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>('constraints', constraints, defaultValue: null, showName: false));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('margin', margin, defaultValue: null));
    properties.add(ObjectFlagProperty<Matrix4>.has('transform', transform));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('transformAlignment', transformAlignment, defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior));
  }
}

class _AnimatedContainerState extends AnimatedWidgetBaseState<AnimatedContainer> {
  AlignmentGeometryTween? _alignment;
  EdgeInsetsGeometryTween? _padding;
  DecorationTween? _decoration;
  DecorationTween? _foregroundDecoration;
  BoxConstraintsTween? _constraints;
  EdgeInsetsGeometryTween? _margin;
  Matrix4Tween? _transform;
  AlignmentGeometryTween? _transformAlignment;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _alignment = visitor(_alignment, widget.alignment, (dynamic value) => AlignmentGeometryTween(begin: value as AlignmentGeometry)) as AlignmentGeometryTween?;
    _padding = visitor(_padding, widget.padding, (dynamic value) => EdgeInsetsGeometryTween(begin: value as EdgeInsetsGeometry)) as EdgeInsetsGeometryTween?;
    _decoration = visitor(_decoration, widget.decoration, (dynamic value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
    _foregroundDecoration = visitor(_foregroundDecoration, widget.foregroundDecoration, (dynamic value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
    _constraints = visitor(_constraints, widget.constraints, (dynamic value) => BoxConstraintsTween(begin: value as BoxConstraints)) as BoxConstraintsTween?;
    _margin = visitor(_margin, widget.margin, (dynamic value) => EdgeInsetsGeometryTween(begin: value as EdgeInsetsGeometry)) as EdgeInsetsGeometryTween?;
    _transform = visitor(_transform, widget.transform, (dynamic value) => Matrix4Tween(begin: value as Matrix4)) as Matrix4Tween?;
    _transformAlignment = visitor(_transformAlignment, widget.transformAlignment, (dynamic value) => AlignmentGeometryTween(begin: value as AlignmentGeometry)) as AlignmentGeometryTween?;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = this.animation;
    return Container(
      alignment: _alignment?.evaluate(animation),
      padding: _padding?.evaluate(animation),
      decoration: _decoration?.evaluate(animation),
      foregroundDecoration: _foregroundDecoration?.evaluate(animation),
      constraints: _constraints?.evaluate(animation),
      margin: _margin?.evaluate(animation),
      transform: _transform?.evaluate(animation),
      transformAlignment: _transformAlignment?.evaluate(animation),
      clipBehavior: widget.clipBehavior,
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<AlignmentGeometryTween>('alignment', _alignment, showName: false, defaultValue: null));
    description.add(DiagnosticsProperty<EdgeInsetsGeometryTween>('padding', _padding, defaultValue: null));
    description.add(DiagnosticsProperty<DecorationTween>('bg', _decoration, defaultValue: null));
    description.add(DiagnosticsProperty<DecorationTween>('fg', _foregroundDecoration, defaultValue: null));
    description.add(DiagnosticsProperty<BoxConstraintsTween>('constraints', _constraints, showName: false, defaultValue: null));
    description.add(DiagnosticsProperty<EdgeInsetsGeometryTween>('margin', _margin, defaultValue: null));
    description.add(ObjectFlagProperty<Matrix4Tween>.has('transform', _transform));
    description.add(DiagnosticsProperty<AlignmentGeometryTween>('transformAlignment', _transformAlignment, defaultValue: null));
  }
}

class AnimatedPadding extends ImplicitlyAnimatedWidget {
  AnimatedPadding({
    super.key,
    required this.padding,
    this.child,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(padding.isNonNegative);

  final EdgeInsetsGeometry padding;

  final Widget? child;

  @override
  AnimatedWidgetBaseState<AnimatedPadding> createState() => _AnimatedPaddingState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
  }
}

class _AnimatedPaddingState extends AnimatedWidgetBaseState<AnimatedPadding> {
  EdgeInsetsGeometryTween? _padding;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _padding = visitor(_padding, widget.padding, (dynamic value) => EdgeInsetsGeometryTween(begin: value as EdgeInsetsGeometry)) as EdgeInsetsGeometryTween?;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _padding!
        .evaluate(animation)
        .clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity), // ignore_clamp_double_lint
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<EdgeInsetsGeometryTween>('padding', _padding, defaultValue: null));
  }
}

class AnimatedAlign extends ImplicitlyAnimatedWidget {
  const AnimatedAlign({
    super.key,
    required this.alignment,
    this.child,
    this.heightFactor,
    this.widthFactor,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(widthFactor == null || widthFactor >= 0.0),
       assert(heightFactor == null || heightFactor >= 0.0);

  final AlignmentGeometry alignment;

  final Widget? child;

  final double? heightFactor;

  final double? widthFactor;

  @override
  AnimatedWidgetBaseState<AnimatedAlign> createState() => _AnimatedAlignState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
  }
}

class _AnimatedAlignState extends AnimatedWidgetBaseState<AnimatedAlign> {
  AlignmentGeometryTween? _alignment;
  Tween<double>? _heightFactorTween;
  Tween<double>? _widthFactorTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _alignment = visitor(_alignment, widget.alignment, (dynamic value) => AlignmentGeometryTween(begin: value as AlignmentGeometry)) as AlignmentGeometryTween?;
    if (widget.heightFactor != null) {
      _heightFactorTween = visitor(_heightFactorTween, widget.heightFactor, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    }
    if (widget.widthFactor != null) {
      _widthFactorTween = visitor(_widthFactorTween, widget.widthFactor, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignment!.evaluate(animation)!,
      heightFactor: _heightFactorTween?.evaluate(animation),
      widthFactor: _widthFactorTween?.evaluate(animation),
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<AlignmentGeometryTween>('alignment', _alignment, defaultValue: null));
    description.add(DiagnosticsProperty<Tween<double>>('widthFactor', _widthFactorTween, defaultValue: null));
    description.add(DiagnosticsProperty<Tween<double>>('heightFactor', _heightFactorTween, defaultValue: null));
  }
}

class AnimatedPositioned extends ImplicitlyAnimatedWidget {
  const AnimatedPositioned({
    super.key,
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(left == null || right == null || width == null),
       assert(top == null || bottom == null || height == null);

  AnimatedPositioned.fromRect({
    super.key,
    required this.child,
    required Rect rect,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : left = rect.left,
       top = rect.top,
       width = rect.width,
       height = rect.height,
       right = null,
       bottom = null;

  final Widget child;

  final double? left;

  final double? top;

  final double? right;

  final double? bottom;

  final double? width;

  final double? height;

  @override
  AnimatedWidgetBaseState<AnimatedPositioned> createState() => _AnimatedPositionedState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('left', left, defaultValue: null));
    properties.add(DoubleProperty('top', top, defaultValue: null));
    properties.add(DoubleProperty('right', right, defaultValue: null));
    properties.add(DoubleProperty('bottom', bottom, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
  }
}

class _AnimatedPositionedState extends AnimatedWidgetBaseState<AnimatedPositioned> {
  Tween<double>? _left;
  Tween<double>? _top;
  Tween<double>? _right;
  Tween<double>? _bottom;
  Tween<double>? _width;
  Tween<double>? _height;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _left = visitor(_left, widget.left, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _top = visitor(_top, widget.top, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _right = visitor(_right, widget.right, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _bottom = visitor(_bottom, widget.bottom, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _width = visitor(_width, widget.width, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _height = visitor(_height, widget.height, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left?.evaluate(animation),
      top: _top?.evaluate(animation),
      right: _right?.evaluate(animation),
      bottom: _bottom?.evaluate(animation),
      width: _width?.evaluate(animation),
      height: _height?.evaluate(animation),
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(ObjectFlagProperty<Tween<double>>.has('left', _left));
    description.add(ObjectFlagProperty<Tween<double>>.has('top', _top));
    description.add(ObjectFlagProperty<Tween<double>>.has('right', _right));
    description.add(ObjectFlagProperty<Tween<double>>.has('bottom', _bottom));
    description.add(ObjectFlagProperty<Tween<double>>.has('width', _width));
    description.add(ObjectFlagProperty<Tween<double>>.has('height', _height));
  }
}

class AnimatedPositionedDirectional extends ImplicitlyAnimatedWidget {
  const AnimatedPositionedDirectional({
    super.key,
    required this.child,
    this.start,
    this.top,
    this.end,
    this.bottom,
    this.width,
    this.height,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(start == null || end == null || width == null),
       assert(top == null || bottom == null || height == null);

  final Widget child;

  final double? start;

  final double? top;

  final double? end;

  final double? bottom;

  final double? width;

  final double? height;

  @override
  AnimatedWidgetBaseState<AnimatedPositionedDirectional> createState() => _AnimatedPositionedDirectionalState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('start', start, defaultValue: null));
    properties.add(DoubleProperty('top', top, defaultValue: null));
    properties.add(DoubleProperty('end', end, defaultValue: null));
    properties.add(DoubleProperty('bottom', bottom, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
  }
}

class _AnimatedPositionedDirectionalState extends AnimatedWidgetBaseState<AnimatedPositionedDirectional> {
  Tween<double>? _start;
  Tween<double>? _top;
  Tween<double>? _end;
  Tween<double>? _bottom;
  Tween<double>? _width;
  Tween<double>? _height;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _start = visitor(_start, widget.start, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _top = visitor(_top, widget.top, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _end = visitor(_end, widget.end, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _bottom = visitor(_bottom, widget.bottom, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _width = visitor(_width, widget.width, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _height = visitor(_height, widget.height, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: _start?.evaluate(animation),
      top: _top?.evaluate(animation),
      end: _end?.evaluate(animation),
      bottom: _bottom?.evaluate(animation),
      width: _width?.evaluate(animation),
      height: _height?.evaluate(animation),
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(ObjectFlagProperty<Tween<double>>.has('start', _start));
    description.add(ObjectFlagProperty<Tween<double>>.has('top', _top));
    description.add(ObjectFlagProperty<Tween<double>>.has('end', _end));
    description.add(ObjectFlagProperty<Tween<double>>.has('bottom', _bottom));
    description.add(ObjectFlagProperty<Tween<double>>.has('width', _width));
    description.add(ObjectFlagProperty<Tween<double>>.has('height', _height));
  }
}

class AnimatedScale extends ImplicitlyAnimatedWidget {
  const AnimatedScale({
    super.key,
    this.child,
    required this.scale,
    this.alignment = Alignment.center,
    this.filterQuality,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  final Widget? child;

  final double scale;

  final Alignment alignment;

  final FilterQuality? filterQuality;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedScale> createState() => _AnimatedScaleState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('scale', scale));
    properties.add(DiagnosticsProperty<Alignment>('alignment', alignment, defaultValue: Alignment.center));
    properties.add(EnumProperty<FilterQuality>('filterQuality', filterQuality, defaultValue: null));
  }
}

class _AnimatedScaleState extends ImplicitlyAnimatedWidgetState<AnimatedScale> {
  Tween<double>? _scale;
  late Animation<double> _scaleAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _scale = visitor(_scale, widget.scale, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _scaleAnimation = animation.drive(_scale!);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      child: widget.child,
    );
  }
}

class AnimatedRotation extends ImplicitlyAnimatedWidget {
  const AnimatedRotation({
    super.key,
    this.child,
    required this.turns,
    this.alignment = Alignment.center,
    this.filterQuality,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  final Widget? child;

  final double turns;

  final Alignment alignment;

  final FilterQuality? filterQuality;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedRotation> createState() => _AnimatedRotationState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('turns', turns));
    properties.add(DiagnosticsProperty<Alignment>('alignment', alignment, defaultValue: Alignment.center));
    properties.add(EnumProperty<FilterQuality>('filterQuality', filterQuality, defaultValue: null));
  }
}

class _AnimatedRotationState extends ImplicitlyAnimatedWidgetState<AnimatedRotation> {
  Tween<double>? _turns;
  late Animation<double> _turnsAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _turns = visitor(_turns, widget.turns, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _turnsAnimation = animation.drive(_turns!);
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _turnsAnimation,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      child: widget.child,
    );
  }
}

class AnimatedSlide extends ImplicitlyAnimatedWidget {
  const AnimatedSlide({
    super.key,
    this.child,
    required this.offset,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  final Widget? child;

  final Offset offset;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedSlide> createState() => _AnimatedSlideState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
  }
}

class _AnimatedSlideState extends ImplicitlyAnimatedWidgetState<AnimatedSlide> {
  Tween<Offset>? _offset;
  late Animation<Offset> _offsetAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _offset = visitor(_offset, widget.offset, (dynamic value) => Tween<Offset>(begin: value as Offset)) as Tween<Offset>?;
  }

  @override
  void didUpdateTweens() {
    _offsetAnimation = animation.drive(_offset!);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.child,
    );
  }
}

class AnimatedOpacity extends ImplicitlyAnimatedWidget {
  const AnimatedOpacity({
    super.key,
    this.child,
    required this.opacity,
    super.curve,
    required super.duration,
    super.onEnd,
    this.alwaysIncludeSemantics = false,
  }) : assert(opacity >= 0.0 && opacity <= 1.0);

  final Widget? child;

  final double opacity;

  final bool alwaysIncludeSemantics;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedOpacity> createState() => _AnimatedOpacityState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('opacity', opacity));
  }
}

class _AnimatedOpacityState extends ImplicitlyAnimatedWidgetState<AnimatedOpacity> {
  Tween<double>? _opacity;
  late Animation<double> _opacityAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _opacity = visitor(_opacity, widget.opacity, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _opacityAnimation = animation.drive(_opacity!);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      alwaysIncludeSemantics: widget.alwaysIncludeSemantics,
      child: widget.child,
    );
  }
}

class SliverAnimatedOpacity extends ImplicitlyAnimatedWidget {
  const SliverAnimatedOpacity({
    super.key,
    this.sliver,
    required this.opacity,
    super.curve,
    required super.duration,
    super.onEnd,
    this.alwaysIncludeSemantics = false,
  }) : assert(opacity >= 0.0 && opacity <= 1.0);

  final Widget? sliver;

  final double opacity;

  final bool alwaysIncludeSemantics;

  @override
  ImplicitlyAnimatedWidgetState<SliverAnimatedOpacity> createState() => _SliverAnimatedOpacityState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('opacity', opacity));
  }
}

class _SliverAnimatedOpacityState extends ImplicitlyAnimatedWidgetState<SliverAnimatedOpacity> {
  Tween<double>? _opacity;
  late Animation<double> _opacityAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _opacity = visitor(_opacity, widget.opacity, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _opacityAnimation = animation.drive(_opacity!);
  }

  @override
  Widget build(BuildContext context) {
    return SliverFadeTransition(
      opacity: _opacityAnimation,
      sliver: widget.sliver,
      alwaysIncludeSemantics: widget.alwaysIncludeSemantics,
    );
  }
}

class AnimatedDefaultTextStyle extends ImplicitlyAnimatedWidget {
  const AnimatedDefaultTextStyle({
    super.key,
    required this.child,
    required this.style,
    this.textAlign,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(maxLines == null || maxLines > 0);

  final Widget child;

  final TextStyle style;

  final TextAlign? textAlign;

  final bool softWrap;

  final TextOverflow overflow;

  final int? maxLines;

  final TextWidthBasis textWidthBasis;

  final ui.TextHeightBehavior? textHeightBehavior;

  @override
  AnimatedWidgetBaseState<AnimatedDefaultTextStyle> createState() => _AnimatedDefaultTextStyleState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    style.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: null));
    properties.add(FlagProperty('softWrap', value: softWrap, ifTrue: 'wrapping at box width', ifFalse: 'no wrapping except at line break characters', showName: true));
    properties.add(EnumProperty<TextOverflow>('overflow', overflow, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: null));
    properties.add(EnumProperty<TextWidthBasis>('textWidthBasis', textWidthBasis, defaultValue: TextWidthBasis.parent));
    properties.add(DiagnosticsProperty<ui.TextHeightBehavior>('textHeightBehavior', textHeightBehavior, defaultValue: null));
  }
}

class _AnimatedDefaultTextStyleState extends AnimatedWidgetBaseState<AnimatedDefaultTextStyle> {
  TextStyleTween? _style;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _style = visitor(_style, widget.style, (dynamic value) => TextStyleTween(begin: value as TextStyle)) as TextStyleTween?;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: _style!.evaluate(animation),
      textAlign: widget.textAlign,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      maxLines: widget.maxLines,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      child: widget.child,
    );
  }
}

class AnimatedPhysicalModel extends ImplicitlyAnimatedWidget {
  const AnimatedPhysicalModel({
    super.key,
    required this.child,
    required this.shape,
    this.clipBehavior = Clip.none,
    this.borderRadius = BorderRadius.zero,
    required this.elevation,
    required this.color,
    this.animateColor = true,
    required this.shadowColor,
    this.animateShadowColor = true,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(elevation >= 0.0);

  final Widget child;

  final BoxShape shape;

  final Clip clipBehavior;

  final BorderRadius borderRadius;

  final double elevation;

  final Color color;

  final bool animateColor;

  final Color shadowColor;

  final bool animateShadowColor;

  @override
  AnimatedWidgetBaseState<AnimatedPhysicalModel> createState() => _AnimatedPhysicalModelState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<BoxShape>('shape', shape));
    properties.add(DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius));
    properties.add(DoubleProperty('elevation', elevation));
    properties.add(ColorProperty('color', color));
    properties.add(DiagnosticsProperty<bool>('animateColor', animateColor));
    properties.add(ColorProperty('shadowColor', shadowColor));
    properties.add(DiagnosticsProperty<bool>('animateShadowColor', animateShadowColor));
  }
}

class _AnimatedPhysicalModelState extends AnimatedWidgetBaseState<AnimatedPhysicalModel> {
  BorderRadiusTween? _borderRadius;
  Tween<double>? _elevation;
  ColorTween? _color;
  ColorTween? _shadowColor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _borderRadius = visitor(_borderRadius, widget.borderRadius, (dynamic value) => BorderRadiusTween(begin: value as BorderRadius)) as BorderRadiusTween?;
    _elevation = visitor(_elevation, widget.elevation, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    _color = visitor(_color, widget.color, (dynamic value) => ColorTween(begin: value as Color)) as ColorTween?;
    _shadowColor = visitor(_shadowColor, widget.shadowColor, (dynamic value) => ColorTween(begin: value as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    return PhysicalModel(
      shape: widget.shape,
      clipBehavior: widget.clipBehavior,
      borderRadius: _borderRadius!.evaluate(animation),
      elevation: _elevation!.evaluate(animation),
      color: widget.animateColor ? _color!.evaluate(animation)! : widget.color,
      shadowColor: widget.animateShadowColor
          ? _shadowColor!.evaluate(animation)!
          : widget.shadowColor,
      child: widget.child,
    );
  }
}

class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  const AnimatedFractionallySizedBox({
    super.key,
    this.alignment = Alignment.center,
    this.child,
    this.heightFactor,
    this.widthFactor,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(widthFactor == null || widthFactor >= 0.0),
       assert(heightFactor == null || heightFactor >= 0.0);

  final Widget? child;

  final double? heightFactor;

  final double? widthFactor;

  final AlignmentGeometry alignment;

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() => _AnimatedFractionallySizedBoxState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(DiagnosticsProperty<double>('widthFactor', widthFactor));
    properties.add(DiagnosticsProperty<double>('heightFactor', heightFactor));
  }
}

class _AnimatedFractionallySizedBoxState extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  AlignmentGeometryTween? _alignment;
  Tween<double>? _heightFactorTween;
  Tween<double>? _widthFactorTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _alignment = visitor(_alignment, widget.alignment, (dynamic value) => AlignmentGeometryTween(begin: value as AlignmentGeometry)) as AlignmentGeometryTween?;
    if (widget.heightFactor != null) {
      _heightFactorTween = visitor(_heightFactorTween, widget.heightFactor, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    }
    if (widget.widthFactor != null) {
      _widthFactorTween = visitor(_widthFactorTween, widget.widthFactor, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: _alignment!.evaluate(animation)!,
      heightFactor: _heightFactorTween?.evaluate(animation),
      widthFactor: _widthFactorTween?.evaluate(animation),
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<AlignmentGeometryTween>('alignment', _alignment, defaultValue: null));
    description.add(DiagnosticsProperty<Tween<double>>('widthFactor', _widthFactorTween, defaultValue: null));
    description.add(DiagnosticsProperty<Tween<double>>('heightFactor', _heightFactorTween, defaultValue: null));
  }
}