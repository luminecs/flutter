
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'container.dart';
import 'framework.dart';
import 'text.dart';

export 'package:flutter/rendering.dart' show RelativeRect;

abstract class AnimatedWidget extends StatefulWidget {
  const AnimatedWidget({
    super.key,
    required this.listenable,
  });

  final Listenable listenable;

  @protected
  Widget build(BuildContext context);

  @override
  State<AnimatedWidget> createState() => _AnimatedState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Listenable>('listenable', listenable));
  }
}

class _AnimatedState extends State<AnimatedWidget> {
  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(AnimatedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listenable != oldWidget.listenable) {
      oldWidget.listenable.removeListener(_handleChange);
      widget.listenable.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    setState(() {
      // The listenable's state is our build state, and it changed already.
    });
  }

  @override
  Widget build(BuildContext context) => widget.build(context);
}

class SlideTransition extends AnimatedWidget {
  const SlideTransition({
    super.key,
    required Animation<Offset> position,
    this.transformHitTests = true,
    this.textDirection,
    this.child,
  }) : super(listenable: position);

  Animation<Offset> get position => listenable as Animation<Offset>;

  final TextDirection? textDirection;

  final bool transformHitTests;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Offset offset = position.value;
    if (textDirection == TextDirection.rtl) {
      offset = Offset(-offset.dx, offset.dy);
    }
    return FractionalTranslation(
      translation: offset,
      transformHitTests: transformHitTests,
      child: child,
    );
  }
}

typedef TransformCallback = Matrix4 Function(double animationValue);

class MatrixTransition extends AnimatedWidget {
  const MatrixTransition({
    super.key,
    required Animation<double> animation,
    required this.onTransform,
    this.alignment = Alignment.center,
    this.filterQuality,
    this.child,
  }) : super(listenable: animation);

  final TransformCallback onTransform;

  Animation<double> get animation => listenable as Animation<double>;

  final Alignment alignment;

  final FilterQuality? filterQuality;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // The ImageFilter layer created by setting filterQuality will introduce
    // a saveLayer call. This is usually worthwhile when animating the layer,
    // but leaving it in the layer tree before the animation has started or after
    // it has finished significantly hurts performance.
    final bool useFilterQuality;
    switch (animation.status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        useFilterQuality = false;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        useFilterQuality = true;
    }
    return Transform(
      transform: onTransform(animation.value),
      alignment: alignment,
      filterQuality: useFilterQuality ? filterQuality : null,
      child: child,
    );
  }
}

class ScaleTransition extends MatrixTransition {
  const ScaleTransition({
    super.key,
    required Animation<double> scale,
    super.alignment = Alignment.center,
    super.filterQuality,
    super.child,
  }) : super(animation: scale, onTransform: _handleScaleMatrix);

  Animation<double> get scale => animation;

  static Matrix4 _handleScaleMatrix(double value) => Matrix4.diagonal3Values(value, value, 1.0);
}

class RotationTransition extends MatrixTransition {
  const RotationTransition({
    super.key,
    required Animation<double> turns,
    super.alignment = Alignment.center,
    super.filterQuality,
    super.child,
  }) : super(animation: turns, onTransform: _handleTurnsMatrix);

  Animation<double> get turns => animation;

  static Matrix4 _handleTurnsMatrix(double value) => Matrix4.rotationZ(value * math.pi * 2.0);
}

class SizeTransition extends AnimatedWidget {
  const SizeTransition({
    super.key,
    this.axis = Axis.vertical,
    required Animation<double> sizeFactor,
    this.axisAlignment = 0.0,
    this.child,
  }) : super(listenable: sizeFactor);

  final Axis axis;

  Animation<double> get sizeFactor => listenable as Animation<double>;

  final double axisAlignment;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final AlignmentDirectional alignment;
    if (axis == Axis.vertical) {
      alignment = AlignmentDirectional(-1.0, axisAlignment);
    } else {
      alignment = AlignmentDirectional(axisAlignment, -1.0);
    }
    return ClipRect(
      child: Align(
        alignment: alignment,
        heightFactor: axis == Axis.vertical ? math.max(sizeFactor.value, 0.0) : null,
        widthFactor: axis == Axis.horizontal ? math.max(sizeFactor.value, 0.0) : null,
        child: child,
      ),
    );
  }
}

class FadeTransition extends SingleChildRenderObjectWidget {
  const FadeTransition({
    super.key,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    super.child,
  });

  final Animation<double> opacity;

  final bool alwaysIncludeSemantics;

  @override
  RenderAnimatedOpacity createRenderObject(BuildContext context) {
    return RenderAnimatedOpacity(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderAnimatedOpacity renderObject) {
    renderObject
      ..opacity = opacity
      ..alwaysIncludeSemantics = alwaysIncludeSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Animation<double>>('opacity', opacity));
    properties.add(FlagProperty('alwaysIncludeSemantics', value: alwaysIncludeSemantics, ifTrue: 'alwaysIncludeSemantics'));
  }
}

class SliverFadeTransition extends SingleChildRenderObjectWidget {
  const SliverFadeTransition({
    super.key,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    Widget? sliver,
  }) : super(child: sliver);

  final Animation<double> opacity;

  final bool alwaysIncludeSemantics;

  @override
  RenderSliverAnimatedOpacity createRenderObject(BuildContext context) {
    return RenderSliverAnimatedOpacity(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverAnimatedOpacity renderObject) {
    renderObject
      ..opacity = opacity
      ..alwaysIncludeSemantics = alwaysIncludeSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Animation<double>>('opacity', opacity));
    properties.add(FlagProperty('alwaysIncludeSemantics', value: alwaysIncludeSemantics, ifTrue: 'alwaysIncludeSemantics'));
  }
}

class RelativeRectTween extends Tween<RelativeRect> {
  RelativeRectTween({ super.begin, super.end });

  @override
  RelativeRect lerp(double t) => RelativeRect.lerp(begin, end, t)!;
}

class PositionedTransition extends AnimatedWidget {
  const PositionedTransition({
    super.key,
    required Animation<RelativeRect> rect,
    required this.child,
  }) : super(listenable: rect);

  Animation<RelativeRect> get rect => listenable as Animation<RelativeRect>;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRelativeRect(
      rect: rect.value,
      child: child,
    );
  }
}

class RelativePositionedTransition extends AnimatedWidget {
  const RelativePositionedTransition({
    super.key,
    required Animation<Rect?> rect,
    required this.size,
    required this.child,
  }) : super(listenable: rect);

  Animation<Rect?> get rect => listenable as Animation<Rect?>;

  final Size size;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final RelativeRect offsets = RelativeRect.fromSize(rect.value ?? Rect.zero, size);
    return Positioned(
      top: offsets.top,
      right: offsets.right,
      bottom: offsets.bottom,
      left: offsets.left,
      child: child,
    );
  }
}

class DecoratedBoxTransition extends AnimatedWidget {
  const DecoratedBoxTransition({
    super.key,
    required this.decoration,
    this.position = DecorationPosition.background,
    required this.child,
  }) : super(listenable: decoration);

  final Animation<Decoration> decoration;

  final DecorationPosition position;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: decoration.value,
      position: position,
      child: child,
    );
  }
}

class AlignTransition extends AnimatedWidget {
  const AlignTransition({
    super.key,
    required Animation<AlignmentGeometry> alignment,
    required this.child,
    this.widthFactor,
    this.heightFactor,
  }) : super(listenable: alignment);

  Animation<AlignmentGeometry> get alignment => listenable as Animation<AlignmentGeometry>;

  final double? widthFactor;

  final double? heightFactor;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment.value,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      child: child,
    );
  }
}

class DefaultTextStyleTransition extends AnimatedWidget {
  const DefaultTextStyleTransition({
    super.key,
    required Animation<TextStyle> style,
    required this.child,
    this.textAlign,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
  }) : super(listenable: style);

  Animation<TextStyle> get style => listenable as Animation<TextStyle>;

  final TextAlign? textAlign;

  final bool softWrap;

  final TextOverflow overflow;

  final int? maxLines;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: style.value,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      child: child,
    );
  }
}

class ListenableBuilder extends AnimatedWidget {
  const ListenableBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  //
  // Overridden getter to replace with documentation tailored to
  // ListenableBuilder.
  @override
  Listenable get listenable => super.listenable;

  final TransitionBuilder builder;

  final Widget? child;

  @override
  Widget build(BuildContext context) => builder(context, child);
}

class AnimatedBuilder extends ListenableBuilder {
  const AnimatedBuilder({
    super.key,
    required Listenable animation,
    required super.builder,
    super.child,
  }) : super(listenable: animation);

  Listenable get animation => super.listenable;

  //
  // Overridden getter to replace with documentation tailored to
  // ListenableBuilder.
  @override
  Listenable get listenable => super.listenable;

  //
  // Overridden getter to replace with documentation tailored to
  // AnimatedBuilder.
  @override
  TransitionBuilder get builder => super.builder;
}