
import 'dart:ui' as ui show Color, Gradient, Image, ImageFilter;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'box.dart';
import 'layer.dart';
import 'layout_helper.dart';
import 'object.dart';

export 'package:flutter/gestures.dart' show
  PointerCancelEvent,
  PointerDownEvent,
  PointerEvent,
  PointerMoveEvent,
  PointerUpEvent;

class RenderProxyBox extends RenderBox with RenderObjectWithChildMixin<RenderBox>, RenderProxyBoxMixin<RenderBox> {
  RenderProxyBox([RenderBox? child]) {
    this.child = child;
  }
}

@optionalTypeArgs
mixin RenderProxyBoxMixin<T extends RenderBox> on RenderBox, RenderObjectWithChildMixin<T> {
  @override
  void setupParentData(RenderObject child) {
    // We don't actually use the offset argument in BoxParentData, so let's
    // avoid allocating it at all.
    if (child.parentData is! ParentData) {
      child.parentData = ParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return child?.getMinIntrinsicWidth(height) ?? 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return child?.getMaxIntrinsicWidth(height) ?? 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return child?.getMinIntrinsicHeight(width) ?? 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return child?.getMaxIntrinsicHeight(width) ?? 0.0;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return child?.getDistanceToActualBaseline(baseline)
        ?? super.computeDistanceToActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return child?.getDryLayout(constraints) ?? computeSizeForNoChild(constraints);
  }

  @override
  void performLayout() {
    size = (child?..layout(constraints, parentUsesSize: true))?.size
        ?? computeSizeForNoChild(constraints);
    return;
  }

  Size computeSizeForNoChild(BoxConstraints constraints) {
    return constraints.smallest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) { }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }
    context.paintChild(child, offset);
  }
}

enum HitTestBehavior {
  deferToChild,

  opaque,

  translucent,
}

abstract class RenderProxyBoxWithHitTestBehavior extends RenderProxyBox {
  RenderProxyBoxWithHitTestBehavior({
    this.behavior = HitTestBehavior.deferToChild,
    RenderBox? child,
  }) : super(child);

  HitTestBehavior behavior;

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    bool hitTarget = false;
    if (size.contains(position)) {
      hitTarget = hitTestChildren(result, position: position) || hitTestSelf(position);
      if (hitTarget || behavior == HitTestBehavior.translucent) {
        result.add(BoxHitTestEntry(this, position));
      }
    }
    return hitTarget;
  }

  @override
  bool hitTestSelf(Offset position) => behavior == HitTestBehavior.opaque;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<HitTestBehavior>('behavior', behavior, defaultValue: null));
  }
}

class RenderConstrainedBox extends RenderProxyBox {
  RenderConstrainedBox({
    RenderBox? child,
    required BoxConstraints additionalConstraints,
  }) : assert(additionalConstraints.debugAssertIsValid()),
       _additionalConstraints = additionalConstraints,
       super(child);

  BoxConstraints get additionalConstraints => _additionalConstraints;
  BoxConstraints _additionalConstraints;
  set additionalConstraints(BoxConstraints value) {
    assert(value.debugAssertIsValid());
    if (_additionalConstraints == value) {
      return;
    }
    _additionalConstraints = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_additionalConstraints.hasBoundedWidth && _additionalConstraints.hasTightWidth) {
      return _additionalConstraints.minWidth;
    }
    final double width = super.computeMinIntrinsicWidth(height);
    assert(width.isFinite);
    if (!_additionalConstraints.hasInfiniteWidth) {
      return _additionalConstraints.constrainWidth(width);
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_additionalConstraints.hasBoundedWidth && _additionalConstraints.hasTightWidth) {
      return _additionalConstraints.minWidth;
    }
    final double width = super.computeMaxIntrinsicWidth(height);
    assert(width.isFinite);
    if (!_additionalConstraints.hasInfiniteWidth) {
      return _additionalConstraints.constrainWidth(width);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_additionalConstraints.hasBoundedHeight && _additionalConstraints.hasTightHeight) {
      return _additionalConstraints.minHeight;
    }
    final double height = super.computeMinIntrinsicHeight(width);
    assert(height.isFinite);
    if (!_additionalConstraints.hasInfiniteHeight) {
      return _additionalConstraints.constrainHeight(height);
    }
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (_additionalConstraints.hasBoundedHeight && _additionalConstraints.hasTightHeight) {
      return _additionalConstraints.minHeight;
    }
    final double height = super.computeMaxIntrinsicHeight(width);
    assert(height.isFinite);
    if (!_additionalConstraints.hasInfiniteHeight) {
      return _additionalConstraints.constrainHeight(height);
    }
    return height;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    if (child != null) {
      child!.layout(_additionalConstraints.enforce(constraints), parentUsesSize: true);
      size = child!.size;
    } else {
      size = _additionalConstraints.enforce(constraints).constrain(Size.zero);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child != null) {
      return child!.getDryLayout(_additionalConstraints.enforce(constraints));
    } else {
      return _additionalConstraints.enforce(constraints).constrain(Size.zero);
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    assert(() {
      final Paint paint;
      if (child == null || child!.size.isEmpty) {
        paint = Paint()
          ..color = const Color(0x90909090);
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BoxConstraints>('additionalConstraints', additionalConstraints));
  }
}

class RenderLimitedBox extends RenderProxyBox {
  RenderLimitedBox({
    RenderBox? child,
    double maxWidth = double.infinity,
    double maxHeight = double.infinity,
  }) : assert(maxWidth >= 0.0),
       assert(maxHeight >= 0.0),
       _maxWidth = maxWidth,
       _maxHeight = maxHeight,
       super(child);

  double get maxWidth => _maxWidth;
  double _maxWidth;
  set maxWidth(double value) {
    assert(value >= 0.0);
    if (_maxWidth == value) {
      return;
    }
    _maxWidth = value;
    markNeedsLayout();
  }

  double get maxHeight => _maxHeight;
  double _maxHeight;
  set maxHeight(double value) {
    assert(value >= 0.0);
    if (_maxHeight == value) {
      return;
    }
    _maxHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _limitConstraints(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : constraints.constrainWidth(maxWidth),
      minHeight: constraints.minHeight,
      maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.constrainHeight(maxHeight),
    );
  }

  Size _computeSize({required BoxConstraints constraints, required ChildLayouter layoutChild }) {
    if (child != null) {
      final Size childSize = layoutChild(child!, _limitConstraints(constraints));
      return constraints.constrain(childSize);
    }
    return _limitConstraints(constraints).constrain(Size.zero);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    );
  }

  @override
  void performLayout() {
    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('maxWidth', maxWidth, defaultValue: double.infinity));
    properties.add(DoubleProperty('maxHeight', maxHeight, defaultValue: double.infinity));
  }
}

class RenderAspectRatio extends RenderProxyBox {
  RenderAspectRatio({
    RenderBox? child,
    required double aspectRatio,
  }) : assert(aspectRatio > 0.0),
       assert(aspectRatio.isFinite),
       _aspectRatio = aspectRatio,
       super(child);

  double get aspectRatio => _aspectRatio;
  double _aspectRatio;
  set aspectRatio(double value) {
    assert(value > 0.0);
    assert(value.isFinite);
    if (_aspectRatio == value) {
      return;
    }
    _aspectRatio = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (height.isFinite) {
      return height * _aspectRatio;
    }
    if (child != null) {
      return child!.getMinIntrinsicWidth(height);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (height.isFinite) {
      return height * _aspectRatio;
    }
    if (child != null) {
      return child!.getMaxIntrinsicWidth(height);
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (width.isFinite) {
      return width / _aspectRatio;
    }
    if (child != null) {
      return child!.getMinIntrinsicHeight(width);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (width.isFinite) {
      return width / _aspectRatio;
    }
    if (child != null) {
      return child!.getMaxIntrinsicHeight(width);
    }
    return 0.0;
  }

  Size _applyAspectRatio(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    assert(() {
      if (!constraints.hasBoundedWidth && !constraints.hasBoundedHeight) {
        throw FlutterError(
          '$runtimeType has unbounded constraints.\n'
          'This $runtimeType was given an aspect ratio of $aspectRatio but was given '
          'both unbounded width and unbounded height constraints. Because both '
          "constraints were unbounded, this render object doesn't know how much "
          'size to consume.',
        );
      }
      return true;
    }());

    if (constraints.isTight) {
      return constraints.smallest;
    }

    double width = constraints.maxWidth;
    double height;

    // We default to picking the height based on the width, but if the width
    // would be infinite, that's not sensible so we try to infer the height
    // from the width.
    if (width.isFinite) {
      height = width / _aspectRatio;
    } else {
      height = constraints.maxHeight;
      width = height * _aspectRatio;
    }

    // Similar to RenderImage, we iteratively attempt to fit within the given
    // constraints while maintaining the given aspect ratio. The order of
    // applying the constraints is also biased towards inferring the height
    // from the width.

    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / _aspectRatio;
    }

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * _aspectRatio;
    }

    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / _aspectRatio;
    }

    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * _aspectRatio;
    }

    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _applyAspectRatio(constraints);
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    if (child != null) {
      child!.layout(BoxConstraints.tight(size));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('aspectRatio', aspectRatio));
  }
}

class RenderIntrinsicWidth extends RenderProxyBox {
  RenderIntrinsicWidth({
    double? stepWidth,
    double? stepHeight,
    RenderBox? child,
  }) : assert(stepWidth == null || stepWidth > 0.0),
       assert(stepHeight == null || stepHeight > 0.0),
       _stepWidth = stepWidth,
       _stepHeight = stepHeight,
       super(child);

  double? get stepWidth => _stepWidth;
  double? _stepWidth;
  set stepWidth(double? value) {
    assert(value == null || value > 0.0);
    if (value == _stepWidth) {
      return;
    }
    _stepWidth = value;
    markNeedsLayout();
  }

  double? get stepHeight => _stepHeight;
  double? _stepHeight;
  set stepHeight(double? value) {
    assert(value == null || value > 0.0);
    if (value == _stepHeight) {
      return;
    }
    _stepHeight = value;
    markNeedsLayout();
  }

  static double _applyStep(double input, double? step) {
    assert(input.isFinite);
    if (step == null) {
      return input;
    }
    return (input / step).ceil() * step;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    final double width = child!.getMaxIntrinsicWidth(height);
    return _applyStep(width, _stepWidth);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null) {
      return 0.0;
    }
    if (!width.isFinite) {
      width = computeMaxIntrinsicWidth(double.infinity);
    }
    assert(width.isFinite);
    final double height = child!.getMinIntrinsicHeight(width);
    return _applyStep(height, _stepHeight);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null) {
      return 0.0;
    }
    if (!width.isFinite) {
      width = computeMaxIntrinsicWidth(double.infinity);
    }
    assert(width.isFinite);
    final double height = child!.getMaxIntrinsicHeight(width);
    return _applyStep(height, _stepHeight);
  }

  Size _computeSize({required ChildLayouter layoutChild, required BoxConstraints constraints}) {
    if (child != null) {
      if (!constraints.hasTightWidth) {
        final double width = child!.getMaxIntrinsicWidth(constraints.maxHeight);
        assert(width.isFinite);
        constraints = constraints.tighten(width: _applyStep(width, _stepWidth));
      }
      if (_stepHeight != null) {
        final double height = child!.getMaxIntrinsicHeight(constraints.maxWidth);
        assert(height.isFinite);
        constraints = constraints.tighten(height: _applyStep(height, _stepHeight));
      }
      return layoutChild(child!, constraints);
    } else {
      return constraints.smallest;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      constraints: constraints,
    );
  }

  @override
  void performLayout() {
    size = _computeSize(
      layoutChild: ChildLayoutHelper.layoutChild,
      constraints: constraints,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('stepWidth', stepWidth));
    properties.add(DoubleProperty('stepHeight', stepHeight));
  }
}

class RenderIntrinsicHeight extends RenderProxyBox {
  RenderIntrinsicHeight({
    RenderBox? child,
  }) : super(child);

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    if (!height.isFinite) {
      height = child!.getMaxIntrinsicHeight(double.infinity);
    }
    assert(height.isFinite);
    return child!.getMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    if (!height.isFinite) {
      height = child!.getMaxIntrinsicHeight(double.infinity);
    }
    assert(height.isFinite);
    return child!.getMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  Size _computeSize({required ChildLayouter layoutChild, required BoxConstraints constraints}) {
    if (child != null) {
      if (!constraints.hasTightHeight) {
        final double height = child!.getMaxIntrinsicHeight(constraints.maxWidth);
        assert(height.isFinite);
        constraints = constraints.tighten(height: height);
      }
      return layoutChild(child!, constraints);
    } else {
      return constraints.smallest;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      constraints: constraints,
    );
  }

  @override
  void performLayout() {
    size = _computeSize(
      layoutChild: ChildLayoutHelper.layoutChild,
      constraints: constraints,
    );
  }
}

class RenderIgnoreBaseline extends RenderProxyBox {
  RenderIgnoreBaseline({
    RenderBox? child,
  }) : super(child);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return null;
  }
}

class RenderOpacity extends RenderProxyBox {
  RenderOpacity({
    double opacity = 1.0,
    bool alwaysIncludeSemantics = false,
    RenderBox? child,
  }) : assert(opacity >= 0.0 && opacity <= 1.0),
       _opacity = opacity,
       _alwaysIncludeSemantics = alwaysIncludeSemantics,
       _alpha = ui.Color.getAlphaFromOpacity(opacity),
       super(child);

  @override
  bool get alwaysNeedsCompositing => child != null && _alpha > 0;

  @override
  bool get isRepaintBoundary => alwaysNeedsCompositing;

  int _alpha;

  double get opacity => _opacity;
  double _opacity;
  set opacity(double value) {
    assert(value >= 0.0 && value <= 1.0);
    if (_opacity == value) {
      return;
    }
    final bool didNeedCompositing = alwaysNeedsCompositing;
    final bool wasVisible = _alpha != 0;
    _opacity = value;
    _alpha = ui.Color.getAlphaFromOpacity(_opacity);
    if (didNeedCompositing != alwaysNeedsCompositing) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsCompositedLayerUpdate();
    if (wasVisible != (_alpha != 0) && !alwaysIncludeSemantics) {
      markNeedsSemanticsUpdate();
    }
  }

  bool get alwaysIncludeSemantics => _alwaysIncludeSemantics;
  bool _alwaysIncludeSemantics;
  set alwaysIncludeSemantics(bool value) {
    if (value == _alwaysIncludeSemantics) {
      return;
    }
    _alwaysIncludeSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  bool paintsChild(RenderBox child) {
    assert(child.parent == this);
    return _alpha > 0;
  }

  @override
  OffsetLayer updateCompositedLayer({required covariant OpacityLayer? oldLayer}) {
    final OpacityLayer layer = oldLayer ?? OpacityLayer();
    layer.alpha = _alpha;
    return layer;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _alpha == 0) {
      return;
    }
    super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && (_alpha != 0 || alwaysIncludeSemantics)) {
      visitor(child!);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('opacity', opacity));
    properties.add(FlagProperty('alwaysIncludeSemantics', value: alwaysIncludeSemantics, ifTrue: 'alwaysIncludeSemantics'));
  }
}

mixin RenderAnimatedOpacityMixin<T extends RenderObject> on RenderObjectWithChildMixin<T> {
  int? _alpha;

  @override
  bool get isRepaintBoundary => child != null && _currentlyIsRepaintBoundary!;
  bool? _currentlyIsRepaintBoundary;

  @override
  OffsetLayer updateCompositedLayer({required covariant OpacityLayer? oldLayer}) {
    final OpacityLayer updatedLayer = oldLayer ?? OpacityLayer();
    updatedLayer.alpha = _alpha;
    return updatedLayer;
  }

  Animation<double> get opacity => _opacity!;
  Animation<double>? _opacity;
  set opacity(Animation<double> value) {
    if (_opacity == value) {
      return;
    }
    if (attached && _opacity != null) {
      opacity.removeListener(_updateOpacity);
    }
    _opacity = value;
    if (attached) {
      opacity.addListener(_updateOpacity);
    }
    _updateOpacity();
  }

  bool get alwaysIncludeSemantics => _alwaysIncludeSemantics!;
  bool? _alwaysIncludeSemantics;
  set alwaysIncludeSemantics(bool value) {
    if (value == _alwaysIncludeSemantics) {
      return;
    }
    _alwaysIncludeSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    opacity.addListener(_updateOpacity);
    _updateOpacity(); // in case it changed while we weren't listening
  }

  @override
  void detach() {
    opacity.removeListener(_updateOpacity);
    super.detach();
  }

  void _updateOpacity() {
    final int? oldAlpha = _alpha;
    _alpha = ui.Color.getAlphaFromOpacity(opacity.value);
    if (oldAlpha != _alpha) {
      final bool? wasRepaintBoundary = _currentlyIsRepaintBoundary;
      _currentlyIsRepaintBoundary = _alpha! > 0;
      if (child != null && wasRepaintBoundary != _currentlyIsRepaintBoundary) {
        markNeedsCompositingBitsUpdate();
      }
      markNeedsCompositedLayerUpdate();
      if (oldAlpha == 0 || _alpha == 0) {
        markNeedsSemanticsUpdate();
      }
    }
  }

  @override
  bool paintsChild(RenderObject child) {
    assert(child.parent == this);
    return opacity.value > 0;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_alpha == 0) {
      return;
    }
    super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && (_alpha != 0 || alwaysIncludeSemantics)) {
      visitor(child!);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Animation<double>>('opacity', opacity));
    properties.add(FlagProperty('alwaysIncludeSemantics', value: alwaysIncludeSemantics, ifTrue: 'alwaysIncludeSemantics'));
  }
}

class RenderAnimatedOpacity extends RenderProxyBox with RenderAnimatedOpacityMixin<RenderBox> {
  RenderAnimatedOpacity({
    required Animation<double> opacity,
    bool alwaysIncludeSemantics = false,
    RenderBox? child,
  }) : super(child) {
    this.opacity = opacity;
    this.alwaysIncludeSemantics = alwaysIncludeSemantics;
  }
}

typedef ShaderCallback = Shader Function(Rect bounds);

class RenderShaderMask extends RenderProxyBox {
  RenderShaderMask({
    RenderBox? child,
    required ShaderCallback shaderCallback,
    BlendMode blendMode = BlendMode.modulate,
  }) : _shaderCallback = shaderCallback,
       _blendMode = blendMode,
       super(child);

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  // TODO(abarth): Use the delegate pattern here to avoid generating spurious
  // repaints when the ShaderCallback changes identity.
  ShaderCallback get shaderCallback => _shaderCallback;
  ShaderCallback _shaderCallback;
  set shaderCallback(ShaderCallback value) {
    if (_shaderCallback == value) {
      return;
    }
    _shaderCallback = value;
    markNeedsPaint();
  }

  BlendMode get blendMode => _blendMode;
  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) {
      return;
    }
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      layer ??= ShaderMaskLayer();
      layer!
        ..shader = _shaderCallback(Offset.zero & size)
        ..maskRect = offset & size
        ..blendMode = _blendMode;
      context.pushLayer(layer!, super.paint, offset);
      assert(() {
        layer!.debugCreator = debugCreator;
        return true;
      }());
    } else {
      layer = null;
    }
  }
}

class RenderBackdropFilter extends RenderProxyBox {
  //
  RenderBackdropFilter({ RenderBox? child, required ui.ImageFilter filter, BlendMode blendMode = BlendMode.srcOver })
    : _filter = filter,
      _blendMode = blendMode,
      super(child);

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  ui.ImageFilter get filter => _filter;
  ui.ImageFilter _filter;
  set filter(ui.ImageFilter value) {
    if (_filter == value) {
      return;
    }
    _filter = value;
    markNeedsPaint();
  }

  BlendMode get blendMode => _blendMode;
  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) {
      return;
    }
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      assert(needsCompositing);
      layer ??= BackdropFilterLayer();
      layer!.filter = _filter;
      layer!.blendMode = _blendMode;
      context.pushLayer(layer!, super.paint, offset);
      assert(() {
        layer!.debugCreator = debugCreator;
        return true;
      }());
    } else {
      layer = null;
    }
  }
}

abstract class CustomClipper<T> extends Listenable {
  const CustomClipper({ Listenable? reclip }) : _reclip = reclip;

  final Listenable? _reclip;

  @override
  void addListener(VoidCallback listener) => _reclip?.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _reclip?.removeListener(listener);

  T getClip(Size size);

  Rect getApproximateClipRect(Size size) => Offset.zero & size;

  bool shouldReclip(covariant CustomClipper<T> oldClipper);

  @override
  String toString() => objectRuntimeType(this, 'CustomClipper');
}

class ShapeBorderClipper extends CustomClipper<Path> {
  const ShapeBorderClipper({
    required this.shape,
    this.textDirection,
  });

  final ShapeBorder shape;

  final TextDirection? textDirection;

  @override
  Path getClip(Size size) {
    return shape.getOuterPath(Offset.zero & size, textDirection: textDirection);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    if (oldClipper.runtimeType != ShapeBorderClipper) {
      return true;
    }
    final ShapeBorderClipper typedOldClipper = oldClipper as ShapeBorderClipper;
    return typedOldClipper.shape != shape
        || typedOldClipper.textDirection != textDirection;
  }
}

abstract class _RenderCustomClip<T> extends RenderProxyBox {
  _RenderCustomClip({
    RenderBox? child,
    CustomClipper<T>? clipper,
    Clip clipBehavior = Clip.antiAlias,
  }) : _clipper = clipper,
       _clipBehavior = clipBehavior,
       super(child);

  CustomClipper<T>? get clipper => _clipper;
  CustomClipper<T>? _clipper;
  set clipper(CustomClipper<T>? newClipper) {
    if (_clipper == newClipper) {
      return;
    }
    final CustomClipper<T>? oldClipper = _clipper;
    _clipper = newClipper;
    assert(newClipper != null || oldClipper != null);
    if (newClipper == null || oldClipper == null ||
        newClipper.runtimeType != oldClipper.runtimeType ||
        newClipper.shouldReclip(oldClipper)) {
      _markNeedsClip();
    }
    if (attached) {
      oldClipper?.removeListener(_markNeedsClip);
      newClipper?.addListener(_markNeedsClip);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clipper?.addListener(_markNeedsClip);
  }

  @override
  void detach() {
    _clipper?.removeListener(_markNeedsClip);
    super.detach();
  }

  void _markNeedsClip() {
    _clip = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  T get _defaultClip;
  T? _clip;

  Clip get clipBehavior => _clipBehavior;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
    }
  }
  Clip _clipBehavior;

  @override
  void performLayout() {
    final Size? oldSize = hasSize ? size : null;
    super.performLayout();
    if (oldSize != size) {
      _clip = null;
    }
  }

  void _updateClip() {
    _clip ??= _clipper?.getClip(size) ?? _defaultClip;
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    switch (clipBehavior) {
      case Clip.none:
        return null;
      case Clip.hardEdge:
      case Clip.antiAlias:
      case Clip.antiAliasWithSaveLayer:
        return _clipper?.getApproximateClipRect(size) ?? Offset.zero & size;
    }
  }

  Paint? _debugPaint;
  TextPainter? _debugText;
  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      _debugPaint ??= Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(10.0, 10.0),
          <Color>[const Color(0x00000000), const Color(0xFFFF00FF), const Color(0xFFFF00FF), const Color(0x00000000)],
          <double>[0.25, 0.25, 0.75, 0.75],
          TileMode.repeated,
        )
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      _debugText ??= TextPainter(
        text: const TextSpan(
          text: '✂',
          style: TextStyle(
            color: Color(0xFFFF00FF),
              fontSize: 14.0,
            ),
          ),
          textDirection: TextDirection.rtl, // doesn't matter, it's one character
        )
        ..layout();
      return true;
    }());
  }

  @override
  void dispose() {
    _debugText?.dispose();
    _debugText = null;
    super.dispose();
  }
}

class RenderClipRect extends _RenderCustomClip<Rect> {
  RenderClipRect({
    super.child,
    super.clipper,
    super.clipBehavior,
  });

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (clipBehavior != Clip.none) {
        _updateClip();
        layer = context.pushClipRect(
          needsCompositing,
          offset,
          _clip!,
          super.paint,
          clipBehavior: clipBehavior,
          oldLayer: layer as ClipRectLayer?,
        );
      } else {
        context.paintChild(child!, offset);
        layer = null;
      }
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        if (clipBehavior != Clip.none) {
          context.canvas.drawRect(_clip!.shift(offset), _debugPaint!);
          _debugText!.paint(context.canvas, offset + Offset(_clip!.width / 8.0, -_debugText!.text!.style!.fontSize! * 1.1));
        }
      }
      return true;
    }());
  }
}

class RenderClipRRect extends _RenderCustomClip<RRect> {
  RenderClipRRect({
    super.child,
    BorderRadiusGeometry borderRadius = BorderRadius.zero,
    super.clipper,
    super.clipBehavior,
    TextDirection? textDirection,
  }) : _borderRadius = borderRadius,
       _textDirection = textDirection;

  BorderRadiusGeometry get borderRadius => _borderRadius;
  BorderRadiusGeometry _borderRadius;
  set borderRadius(BorderRadiusGeometry value) {
    if (_borderRadius == value) {
      return;
    }
    _borderRadius = value;
    _markNeedsClip();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    _markNeedsClip();
  }

  @override
  RRect get _defaultClip => _borderRadius.resolve(textDirection).toRRect(Offset.zero & size);

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (clipBehavior != Clip.none) {
        _updateClip();
        layer = context.pushClipRRect(
          needsCompositing,
          offset,
          _clip!.outerRect,
          _clip!,
          super.paint,
          clipBehavior: clipBehavior,
          oldLayer: layer as ClipRRectLayer?,
        );
      } else {
        context.paintChild(child!, offset);
        layer = null;
      }
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        if (clipBehavior != Clip.none) {
          context.canvas.drawRRect(_clip!.shift(offset), _debugPaint!);
          _debugText!.paint(context.canvas, offset + Offset(_clip!.tlRadiusX, -_debugText!.text!.style!.fontSize! * 1.1));
        }
      }
      return true;
    }());
  }
}

class RenderClipOval extends _RenderCustomClip<Rect> {
  RenderClipOval({
    super.child,
    super.clipper,
    super.clipBehavior,
  });

  Rect? _cachedRect;
  late Path _cachedPath;

  Path _getClipPath(Rect rect) {
    if (rect != _cachedRect) {
      _cachedRect = rect;
      _cachedPath = Path()..addOval(_cachedRect!);
    }
    return _cachedPath;
  }

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    _updateClip();
    assert(_clip != null);
    final Offset center = _clip!.center;
    // convert the position to an offset from the center of the unit circle
    final Offset offset = Offset(
      (position.dx - center.dx) / _clip!.width,
      (position.dy - center.dy) / _clip!.height,
    );
    // check if the point is outside the unit circle
    if (offset.distanceSquared > 0.25) { // x^2 + y^2 > r^2
      return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (clipBehavior != Clip.none) {
        _updateClip();
        layer = context.pushClipPath(
          needsCompositing,
          offset,
          _clip!,
          _getClipPath(_clip!),
          super.paint,
          clipBehavior: clipBehavior,
          oldLayer: layer as ClipPathLayer?,
        );
      } else {
        context.paintChild(child!, offset);
        layer = null;
      }
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        if (clipBehavior != Clip.none) {
          context.canvas.drawPath(_getClipPath(_clip!).shift(offset), _debugPaint!);
          _debugText!.paint(context.canvas, offset + Offset((_clip!.width - _debugText!.width) / 2.0, -_debugText!.text!.style!.fontSize! * 1.1));
        }
      }
      return true;
    }());
  }
}

class RenderClipPath extends _RenderCustomClip<Path> {
  RenderClipPath({
    super.child,
    super.clipper,
    super.clipBehavior,
  });

  @override
  Path get _defaultClip => Path()..addRect(Offset.zero & size);

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (clipBehavior != Clip.none) {
        _updateClip();
        layer = context.pushClipPath(
          needsCompositing,
          offset,
          Offset.zero & size,
          _clip!,
          super.paint,
          clipBehavior: clipBehavior,
          oldLayer: layer as ClipPathLayer?,
        );
      } else {
        context.paintChild(child!, offset);
        layer = null;
      }
    } else {
      layer = null;
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      if (child != null) {
        super.debugPaintSize(context, offset);
        if (clipBehavior != Clip.none) {
          context.canvas.drawPath(_clip!.shift(offset), _debugPaint!);
          _debugText!.paint(context.canvas, offset);
        }
      }
      return true;
    }());
  }
}

abstract class _RenderPhysicalModelBase<T> extends _RenderCustomClip<T> {
  _RenderPhysicalModelBase({
    required super.child,
    required double elevation,
    required Color color,
    required Color shadowColor,
    super.clipBehavior = Clip.none,
    super.clipper,
  }) : assert(elevation >= 0.0),
       _elevation = elevation,
       _color = color,
       _shadowColor = shadowColor;

  double get elevation => _elevation;
  double _elevation;
  set elevation(double value) {
    assert(value >= 0.0);
    if (elevation == value) {
      return;
    }
    final bool didNeedCompositing = alwaysNeedsCompositing;
    _elevation = value;
    if (didNeedCompositing != alwaysNeedsCompositing) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  Color get shadowColor => _shadowColor;
  Color _shadowColor;
  set shadowColor(Color value) {
    if (shadowColor == value) {
      return;
    }
    _shadowColor = value;
    markNeedsPaint();
  }

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (color == value) {
      return;
    }
    _color = value;
    markNeedsPaint();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.elevation = elevation;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DoubleProperty('elevation', elevation));
    description.add(ColorProperty('color', color));
    description.add(ColorProperty('shadowColor', color));
  }
}

class RenderPhysicalModel extends _RenderPhysicalModelBase<RRect> {
  RenderPhysicalModel({
    super.child,
    BoxShape shape = BoxShape.rectangle,
    super.clipBehavior,
    BorderRadius? borderRadius,
    super.elevation = 0.0,
    required super.color,
    super.shadowColor = const Color(0xFF000000),
  }) : assert(elevation >= 0.0),
       _shape = shape,
       _borderRadius = borderRadius;

  BoxShape get shape => _shape;
  BoxShape _shape;
  set shape(BoxShape value) {
    if (shape == value) {
      return;
    }
    _shape = value;
    _markNeedsClip();
  }

  BorderRadius? get borderRadius => _borderRadius;
  BorderRadius? _borderRadius;
  set borderRadius(BorderRadius? value) {
    if (borderRadius == value) {
      return;
    }
    _borderRadius = value;
    _markNeedsClip();
  }

  @override
  RRect get _defaultClip {
    assert(hasSize);
    final Rect rect = Offset.zero & size;
    switch (_shape) {
      case BoxShape.rectangle:
        return (borderRadius ?? BorderRadius.zero).toRRect(rect);
      case BoxShape.circle:
        return RRect.fromRectXY(rect, rect.width / 2, rect.height / 2);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }

    _updateClip();
    final RRect offsetRRect = _clip!.shift(offset);
    final Path offsetRRectAsPath = Path()..addRRect(offsetRRect);
    bool paintShadows = true;
    assert(() {
      if (debugDisableShadows) {
        if (elevation > 0.0) {
          context.canvas.drawRRect(
            offsetRRect,
            Paint()
              ..color = shadowColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = elevation * 2.0,
          );
        }
        paintShadows = false;
      }
      return true;
    }());

    final Canvas canvas = context.canvas;
    if (elevation != 0.0 && paintShadows) {
      canvas.drawShadow(
        offsetRRectAsPath,
        shadowColor,
        elevation,
        color.alpha != 0xFF,
      );
    }
    final bool usesSaveLayer = clipBehavior == Clip.antiAliasWithSaveLayer;
    if (!usesSaveLayer) {
      canvas.drawRRect(
        offsetRRect,
        Paint()..color = color
      );
    }
    layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _clip!,
      (PaintingContext context, Offset offset) {
        if (usesSaveLayer) {
          // If we want to avoid the bleeding edge artifact
          // (https://github.com/flutter/flutter/issues/18057#issue-328003931)
          // using saveLayer, we have to call drawPaint instead of drawPath as
          // anti-aliased drawPath will always have such artifacts.
          context.canvas.drawPaint( Paint()..color = color);
        }
        super.paint(context, offset);
      },
      oldLayer: layer as ClipRRectLayer?,
      clipBehavior: clipBehavior,
    );

    assert(() {
      layer?.debugCreator = debugCreator;
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<BoxShape>('shape', shape));
    description.add(DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius));
  }
}

class RenderPhysicalShape extends _RenderPhysicalModelBase<Path> {
  RenderPhysicalShape({
    super.child,
    required CustomClipper<Path> super.clipper,
    super.clipBehavior,
    super.elevation = 0.0,
    required super.color,
    super.shadowColor = const Color(0xFF000000),
  }) : assert(elevation >= 0.0);

  @override
  Path get _defaultClip => Path()..addRect(Offset.zero & size);

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (_clipper != null) {
      _updateClip();
      assert(_clip != null);
      if (!_clip!.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }

    _updateClip();
    final Path offsetPath = _clip!.shift(offset);
    bool paintShadows = true;
    assert(() {
      if (debugDisableShadows) {
        if (elevation > 0.0) {
          context.canvas.drawPath(
            offsetPath,
            Paint()
              ..color = shadowColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = elevation * 2.0,
          );
        }
        paintShadows = false;
      }
      return true;
    }());

    final Canvas canvas = context.canvas;
    if (elevation != 0.0 && paintShadows) {
      canvas.drawShadow(
        offsetPath,
        shadowColor,
        elevation,
        color.alpha != 0xFF,
      );
    }
    final bool usesSaveLayer = clipBehavior == Clip.antiAliasWithSaveLayer;
    if (!usesSaveLayer) {
      canvas.drawPath(
        offsetPath,
        Paint()..color = color
      );
    }
    layer = context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      _clip!,
      (PaintingContext context, Offset offset) {
        if (usesSaveLayer) {
          // If we want to avoid the bleeding edge artifact
          // (https://github.com/flutter/flutter/issues/18057#issue-328003931)
          // using saveLayer, we have to call drawPaint instead of drawPath as
          // anti-aliased drawPath will always have such artifacts.
          context.canvas.drawPaint( Paint()..color = color);
        }
        super.paint(context, offset);
      },
      oldLayer: layer as ClipPathLayer?,
      clipBehavior: clipBehavior,
    );

    assert(() {
      layer?.debugCreator = debugCreator;
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<CustomClipper<Path>>('clipper', clipper));
  }
}

enum DecorationPosition {
  background,

  foreground,
}

class RenderDecoratedBox extends RenderProxyBox {
  RenderDecoratedBox({
    required Decoration decoration,
    DecorationPosition position = DecorationPosition.background,
    ImageConfiguration configuration = ImageConfiguration.empty,
    RenderBox? child,
  }) : _decoration = decoration,
       _position = position,
       _configuration = configuration,
       super(child);

  BoxPainter? _painter;

  Decoration get decoration => _decoration;
  Decoration _decoration;
  set decoration(Decoration value) {
    if (value == _decoration) {
      return;
    }
    _painter?.dispose();
    _painter = null;
    _decoration = value;
    markNeedsPaint();
  }

  DecorationPosition get position => _position;
  DecorationPosition _position;
  set position(DecorationPosition value) {
    if (value == _position) {
      return;
    }
    _position = value;
    markNeedsPaint();
  }

  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == _configuration) {
      return;
    }
    _configuration = value;
    markNeedsPaint();
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
    // Since we're disposing of our painter, we won't receive change
    // notifications. We mark ourselves as needing paint so that we will
    // resubscribe to change notifications. If we didn't do this, then, for
    // example, animated GIFs would stop animating when a DecoratedBox gets
    // moved around the tree due to GlobalKey reparenting.
    markNeedsPaint();
  }

  @override
  bool hitTestSelf(Offset position) {
    return _decoration.hitTest(size, position, textDirection: configuration.textDirection);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    final ImageConfiguration filledConfiguration = configuration.copyWith(size: size);
    if (position == DecorationPosition.background) {
      int? debugSaveCount;
      assert(() {
        debugSaveCount = context.canvas.getSaveCount();
        return true;
      }());
      _painter!.paint(context.canvas, offset, filledConfiguration);
      assert(() {
        if (debugSaveCount != context.canvas.getSaveCount()) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('${_decoration.runtimeType} painter had mismatching save and restore calls.'),
            ErrorDescription(
              'Before painting the decoration, the canvas save count was $debugSaveCount. '
              'After painting it, the canvas save count was ${context.canvas.getSaveCount()}. '
              'Every call to save() or saveLayer() must be matched by a call to restore().',
            ),
            DiagnosticsProperty<Decoration>('The decoration was', decoration, style: DiagnosticsTreeStyle.errorProperty),
            DiagnosticsProperty<BoxPainter>('The painter was', _painter, style: DiagnosticsTreeStyle.errorProperty),
          ]);
        }
        return true;
      }());
      if (decoration.isComplex) {
        context.setIsComplexHint();
      }
    }
    super.paint(context, offset);
    if (position == DecorationPosition.foreground) {
      _painter!.paint(context.canvas, offset, filledConfiguration);
      if (decoration.isComplex) {
        context.setIsComplexHint();
      }
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(_decoration.toDiagnosticsNode(name: 'decoration'));
    properties.add(DiagnosticsProperty<ImageConfiguration>('configuration', configuration));
  }
}

class RenderTransform extends RenderProxyBox {
  RenderTransform({
    required Matrix4 transform,
    Offset? origin,
    AlignmentGeometry? alignment,
    TextDirection? textDirection,
    this.transformHitTests = true,
    FilterQuality? filterQuality,
    RenderBox? child,
  }) : super(child) {
    this.transform = transform;
    this.alignment = alignment;
    this.textDirection = textDirection;
    this.filterQuality = filterQuality;
    this.origin = origin;
  }

  Offset? get origin => _origin;
  Offset? _origin;
  set origin(Offset? value) {
    if (_origin == value) {
      return;
    }
    _origin = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  AlignmentGeometry? get alignment => _alignment;
  AlignmentGeometry? _alignment;
  set alignment(AlignmentGeometry? value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _filterQuality != null;

  bool transformHitTests;

  Matrix4? _transform;
  set transform(Matrix4 value) { // ignore: avoid_setters_without_getters
    if (_transform == value) {
      return;
    }
    _transform = Matrix4.copy(value);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  FilterQuality? get filterQuality => _filterQuality;
  FilterQuality? _filterQuality;
  set filterQuality(FilterQuality? value) {
    if (_filterQuality == value) {
      return;
    }
    final bool didNeedCompositing = alwaysNeedsCompositing;
    _filterQuality = value;
    if (didNeedCompositing != alwaysNeedsCompositing) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  void setIdentity() {
    _transform!.setIdentity();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void rotateX(double radians) {
    _transform!.rotateX(radians);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void rotateY(double radians) {
    _transform!.rotateY(radians);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void rotateZ(double radians) {
    _transform!.rotateZ(radians);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void translate(double x, [ double y = 0.0, double z = 0.0 ]) {
    _transform!.translate(x, y, z);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void scale(double x, [ double? y, double? z ]) {
    _transform!.scale(x, y, z);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Matrix4? get _effectiveTransform {
    final Alignment? resolvedAlignment = alignment?.resolve(textDirection);
    if (_origin == null && resolvedAlignment == null) {
      return _transform;
    }
    final Matrix4 result = Matrix4.identity();
    if (_origin != null) {
      result.translate(_origin!.dx, _origin!.dy);
    }
    Offset? translation;
    if (resolvedAlignment != null) {
      translation = resolvedAlignment.alongSize(size);
      result.translate(translation.dx, translation.dy);
    }
    result.multiply(_transform!);
    if (resolvedAlignment != null) {
      result.translate(-translation!.dx, -translation.dy);
    }
    if (_origin != null) {
      result.translate(-_origin!.dx, -_origin!.dy);
    }
    return result;
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    // RenderTransform objects don't check if they are
    // themselves hit, because it's confusing to think about
    // how the untransformed size and the child's transformed
    // position interact.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    assert(!transformHitTests || _effectiveTransform != null);
    return result.addWithPaintTransform(
      transform: transformHitTests ? _effectiveTransform : null,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final Matrix4 transform = _effectiveTransform!;
      if (filterQuality == null) {
        final Offset? childOffset = MatrixUtils.getAsTranslation(transform);
        if (childOffset == null) {
          // if the matrix is singular the children would be compressed to a line or
          // single point, instead short-circuit and paint nothing.
          final double det = transform.determinant();
          if (det == 0 || !det.isFinite) {
            layer = null;
            return;
          }
          layer = context.pushTransform(
            needsCompositing,
            offset,
            transform,
            super.paint,
            oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
          );
        } else {
          super.paint(context, offset + childOffset);
          layer = null;
        }
      } else {
        final Matrix4 effectiveTransform = Matrix4.translationValues(offset.dx, offset.dy, 0.0)
          ..multiply(transform)..translate(-offset.dx, -offset.dy);
        final ui.ImageFilter filter = ui.ImageFilter.matrix(
          effectiveTransform.storage,
          filterQuality: filterQuality!,
        );
        if (layer is ImageFilterLayer) {
          final ImageFilterLayer filterLayer = layer! as ImageFilterLayer;
          filterLayer.imageFilter = filter;
        } else {
          layer = ImageFilterLayer(imageFilter: filter);
        }
        context.pushLayer(layer!, super.paint, offset);
        assert(() {
          layer!.debugCreator = debugCreator;
          return true;
        }());
      }
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_effectiveTransform!);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(TransformProperty('transform matrix', _transform));
    properties.add(DiagnosticsProperty<Offset>('origin', origin));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('transformHitTests', transformHitTests));
  }
}

class RenderFittedBox extends RenderProxyBox {
  RenderFittedBox({
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    TextDirection? textDirection,
    RenderBox? child,
    Clip clipBehavior = Clip.none,
  }) : _fit = fit,
       _alignment = alignment,
       _textDirection = textDirection,
       _clipBehavior = clipBehavior,
       super(child);

  Alignment? _resolvedAlignment;

  void _resolve() {
    if (_resolvedAlignment != null) {
      return;
    }
    _resolvedAlignment = alignment.resolve(textDirection);
  }

  void _markNeedResolution() {
    _resolvedAlignment = null;
    markNeedsPaint();
  }

  bool _fitAffectsLayout(BoxFit fit) {
    switch (fit) {
      case BoxFit.scaleDown:
        return true;
      case BoxFit.contain:
      case BoxFit.cover:
      case BoxFit.fill:
      case BoxFit.fitHeight:
      case BoxFit.fitWidth:
      case BoxFit.none:
        return false;
    }
  }

  BoxFit get fit => _fit;
  BoxFit _fit;
  set fit(BoxFit value) {
    if (_fit == value) {
      return;
    }
    final BoxFit lastFit = _fit;
    _fit = value;
    if (_fitAffectsLayout(lastFit) || _fitAffectsLayout(value)) {
      markNeedsLayout();
    } else {
      _clearPaintData();
      markNeedsPaint();
    }
  }

  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    _clearPaintData();
    _markNeedResolution();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    _clearPaintData();
    _markNeedResolution();
  }

  // TODO(ianh): The intrinsic dimensions of this box are wrong.

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child != null) {
      final Size childSize = child!.getDryLayout(const BoxConstraints());

      // During [RenderObject.debugCheckingIntrinsics] a child that doesn't
      // support dry layout may provide us with an invalid size that triggers
      // assertions if we try to work with it. Instead of throwing, we bail
      // out early in that case.
      bool invalidChildSize = false;
      assert(() {
        if (RenderObject.debugCheckingIntrinsics && childSize.width * childSize.height == 0.0) {
          invalidChildSize = true;
        }
        return true;
      }());
      if (invalidChildSize) {
        assert(debugCannotComputeDryLayout(
          reason: 'Child provided invalid size of $childSize.',
        ));
        return Size.zero;
      }

      switch (fit) {
        case BoxFit.scaleDown:
          final BoxConstraints sizeConstraints = constraints.loosen();
          final Size unconstrainedSize = sizeConstraints.constrainSizeAndAttemptToPreserveAspectRatio(childSize);
          return constraints.constrain(unconstrainedSize);
        case BoxFit.contain:
        case BoxFit.cover:
        case BoxFit.fill:
        case BoxFit.fitHeight:
        case BoxFit.fitWidth:
        case BoxFit.none:
          return constraints.constrainSizeAndAttemptToPreserveAspectRatio(childSize);
      }
    } else {
      return constraints.smallest;
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(const BoxConstraints(), parentUsesSize: true);
      switch (fit) {
        case BoxFit.scaleDown:
          final BoxConstraints sizeConstraints = constraints.loosen();
          final Size unconstrainedSize = sizeConstraints.constrainSizeAndAttemptToPreserveAspectRatio(child!.size);
          size = constraints.constrain(unconstrainedSize);
        case BoxFit.contain:
        case BoxFit.cover:
        case BoxFit.fill:
        case BoxFit.fitHeight:
        case BoxFit.fitWidth:
        case BoxFit.none:
          size = constraints.constrainSizeAndAttemptToPreserveAspectRatio(child!.size);
      }
      _clearPaintData();
    } else {
      size = constraints.smallest;
    }
  }

  bool? _hasVisualOverflow;
  Matrix4? _transform;

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.none;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _clearPaintData() {
    _hasVisualOverflow = null;
    _transform = null;
  }

  void _updatePaintData() {
    if (_transform != null) {
      return;
    }

    if (child == null) {
      _hasVisualOverflow = false;
      _transform = Matrix4.identity();
    } else {
      _resolve();
      final Size childSize = child!.size;
      final FittedSizes sizes = applyBoxFit(_fit, childSize, size);
      final double scaleX = sizes.destination.width / sizes.source.width;
      final double scaleY = sizes.destination.height / sizes.source.height;
      final Rect sourceRect = _resolvedAlignment!.inscribe(sizes.source, Offset.zero & childSize);
      final Rect destinationRect = _resolvedAlignment!.inscribe(sizes.destination, Offset.zero & size);
      _hasVisualOverflow = sourceRect.width < childSize.width || sourceRect.height < childSize.height;
      assert(scaleX.isFinite && scaleY.isFinite);
      _transform = Matrix4.translationValues(destinationRect.left, destinationRect.top, 0.0)
        ..scale(scaleX, scaleY, 1.0)
        ..translate(-sourceRect.left, -sourceRect.top);
      assert(_transform!.storage.every((double value) => value.isFinite));
    }
  }

  TransformLayer? _paintChildWithTransform(PaintingContext context, Offset offset) {
    final Offset? childOffset = MatrixUtils.getAsTranslation(_transform!);
    if (childOffset == null) {
      return context.pushTransform(
        needsCompositing,
        offset,
        _transform!,
        super.paint,
        oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
      );
    } else {
      super.paint(context, offset + childOffset);
    }
    return null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty || child!.size.isEmpty) {
      return;
    }
    _updatePaintData();
    assert(child != null);
    if (_hasVisualOverflow! && clipBehavior != Clip.none) {
      layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChildWithTransform,
        oldLayer: layer is ClipRectLayer ? layer! as ClipRectLayer : null,
        clipBehavior: clipBehavior,
      );
    } else {
      layer = _paintChildWithTransform(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    if (size.isEmpty || (child?.size.isEmpty ?? false)) {
      return false;
    }
    _updatePaintData();
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  bool paintsChild(RenderBox child) {
    assert(child.parent == this);
    return !size.isEmpty && !child.size.isEmpty;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (!paintsChild(child)) {
      transform.setZero();
    } else {
      _updatePaintData();
      transform.multiply(_transform!);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<BoxFit>('fit', fit));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
  }
}

class RenderFractionalTranslation extends RenderProxyBox {
  RenderFractionalTranslation({
    required Offset translation,
    this.transformHitTests = true,
    RenderBox? child,
  }) : _translation = translation,
       super(child);

  Offset get translation => _translation;
  Offset _translation;
  set translation(Offset value) {
    if (_translation == value) {
      return;
    }
    _translation = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    // RenderFractionalTranslation objects don't check if they are
    // themselves hit, because it's confusing to think about
    // how the untransformed size and the child's transformed
    // position interact.
    return hitTestChildren(result, position: position);
  }

  bool transformHitTests;

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    assert(!debugNeedsLayout);
    return result.addWithPaintOffset(
      offset: transformHitTests
          ? Offset(translation.dx * size.width, translation.dy * size.height)
          : null,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(!debugNeedsLayout);
    if (child != null) {
      super.paint(context, Offset(
        offset.dx + translation.dx * size.width,
        offset.dy + translation.dy * size.height,
      ));
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translate(
      translation.dx * size.width,
      translation.dy * size.height,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('translation', translation));
    properties.add(DiagnosticsProperty<bool>('transformHitTests', transformHitTests));
  }
}

typedef PointerDownEventListener = void Function(PointerDownEvent event);

typedef PointerMoveEventListener = void Function(PointerMoveEvent event);

typedef PointerUpEventListener = void Function(PointerUpEvent event);

typedef PointerCancelEventListener = void Function(PointerCancelEvent event);

typedef PointerPanZoomStartEventListener = void Function(PointerPanZoomStartEvent event);

typedef PointerPanZoomUpdateEventListener = void Function(PointerPanZoomUpdateEvent event);

typedef PointerPanZoomEndEventListener = void Function(PointerPanZoomEndEvent event);

typedef PointerSignalEventListener = void Function(PointerSignalEvent event);

class RenderPointerListener extends RenderProxyBoxWithHitTestBehavior {
  RenderPointerListener({
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerHover,
    this.onPointerCancel,
    this.onPointerPanZoomStart,
    this.onPointerPanZoomUpdate,
    this.onPointerPanZoomEnd,
    this.onPointerSignal,
    super.behavior,
    super.child,
  });

  PointerDownEventListener? onPointerDown;

  PointerMoveEventListener? onPointerMove;

  PointerUpEventListener? onPointerUp;

  PointerHoverEventListener? onPointerHover;

  PointerCancelEventListener? onPointerCancel;

  PointerPanZoomStartEventListener? onPointerPanZoomStart;

  PointerPanZoomUpdateEventListener? onPointerPanZoomUpdate;

  PointerPanZoomEndEventListener? onPointerPanZoomEnd;

  PointerSignalEventListener? onPointerSignal;

  @override
  Size computeSizeForNoChild(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent) {
      return onPointerDown?.call(event);
    }
    if (event is PointerMoveEvent) {
      return onPointerMove?.call(event);
    }
    if (event is PointerUpEvent) {
      return onPointerUp?.call(event);
    }
    if (event is PointerHoverEvent) {
      return onPointerHover?.call(event);
    }
    if (event is PointerCancelEvent) {
      return onPointerCancel?.call(event);
    }
    if (event is PointerPanZoomStartEvent) {
      return onPointerPanZoomStart?.call(event);
    }
    if (event is PointerPanZoomUpdateEvent) {
      return onPointerPanZoomUpdate?.call(event);
    }
    if (event is PointerPanZoomEndEvent) {
      return onPointerPanZoomEnd?.call(event);
    }
    if (event is PointerSignalEvent) {
      return onPointerSignal?.call(event);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagsSummary<Function?>(
      'listeners',
      <String, Function?>{
        'down': onPointerDown,
        'move': onPointerMove,
        'up': onPointerUp,
        'hover': onPointerHover,
        'cancel': onPointerCancel,
        'panZoomStart': onPointerPanZoomStart,
        'panZoomUpdate': onPointerPanZoomUpdate,
        'panZoomEnd': onPointerPanZoomEnd,
        'signal': onPointerSignal,
      },
      ifEmpty: '<none>',
    ));
  }
}

class RenderMouseRegion extends RenderProxyBoxWithHitTestBehavior implements MouseTrackerAnnotation {
  RenderMouseRegion({
    this.onEnter,
    this.onHover,
    this.onExit,
    MouseCursor cursor = MouseCursor.defer,
    bool validForMouseTracker = true,
    bool opaque = true,
    super.child,
    HitTestBehavior? hitTestBehavior = HitTestBehavior.opaque,
  }) : _cursor = cursor,
       _validForMouseTracker = validForMouseTracker,
       _opaque = opaque,
       super(behavior: hitTestBehavior ?? HitTestBehavior.opaque);

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    return super.hitTest(result, position: position) && _opaque;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (onHover != null && event is PointerHoverEvent) {
      return onHover!(event);
    }
  }

  bool get opaque => _opaque;
  bool _opaque;
  set opaque(bool value) {
    if (_opaque != value) {
      _opaque = value;
      // Trigger [MouseTracker]'s device update to recalculate mouse states.
      markNeedsPaint();
    }
  }

  HitTestBehavior? get hitTestBehavior => behavior;
  set hitTestBehavior(HitTestBehavior? value) {
    final HitTestBehavior newValue = value ?? HitTestBehavior.opaque;
    if (behavior != newValue) {
      behavior = newValue;
      // Trigger [MouseTracker]'s device update to recalculate mouse states.
      markNeedsPaint();
    }
  }

  @override
  PointerEnterEventListener? onEnter;

  PointerHoverEventListener? onHover;

  @override
  PointerExitEventListener? onExit;

  @override
  MouseCursor get cursor => _cursor;
  MouseCursor _cursor;
  set cursor(MouseCursor value) {
    if (_cursor != value) {
      _cursor = value;
      // A repaint is needed in order to trigger a device update of
      // [MouseTracker] so that this new value can be found.
      markNeedsPaint();
    }
  }

  @override
  bool get validForMouseTracker => _validForMouseTracker;
  bool _validForMouseTracker;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _validForMouseTracker = true;
  }

  @override
  void detach() {
    // It's possible that the renderObject be detached during mouse events
    // dispatching, set the [MouseTrackerAnnotation.validForMouseTracker] false to prevent
    // the callbacks from being called.
    _validForMouseTracker = false;
    super.detach();
  }

  @override
  Size computeSizeForNoChild(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagsSummary<Function?>(
      'listeners',
      <String, Function?>{
        'enter': onEnter,
        'hover': onHover,
        'exit': onExit,
      },
      ifEmpty: '<none>',
    ));
    properties.add(DiagnosticsProperty<MouseCursor>('cursor', cursor, defaultValue: MouseCursor.defer));
    properties.add(DiagnosticsProperty<bool>('opaque', opaque, defaultValue: true));
    properties.add(FlagProperty('validForMouseTracker', value: validForMouseTracker, defaultValue: true, ifFalse: 'invalid for MouseTracker'));
  }
}

class RenderRepaintBoundary extends RenderProxyBox {
  RenderRepaintBoundary({ RenderBox? child }) : super(child);

  @override
  bool get isRepaintBoundary => true;

  Future<ui.Image> toImage({ double pixelRatio = 1.0 }) {
    assert(!debugNeedsPaint);
    final OffsetLayer offsetLayer = layer! as OffsetLayer;
    return offsetLayer.toImage(Offset.zero & size, pixelRatio: pixelRatio);
  }

  ui.Image toImageSync({ double pixelRatio = 1.0 }) {
    assert(!debugNeedsPaint);
    final OffsetLayer offsetLayer = layer! as OffsetLayer;
    return offsetLayer.toImageSync(Offset.zero & size, pixelRatio: pixelRatio);
  }

  int get debugSymmetricPaintCount => _debugSymmetricPaintCount;
  int _debugSymmetricPaintCount = 0;

  int get debugAsymmetricPaintCount => _debugAsymmetricPaintCount;
  int _debugAsymmetricPaintCount = 0;

  void debugResetMetrics() {
    assert(() {
      _debugSymmetricPaintCount = 0;
      _debugAsymmetricPaintCount = 0;
      return true;
    }());
  }

  @override
  void debugRegisterRepaintBoundaryPaint({ bool includedParent = true, bool includedChild = false }) {
    assert(() {
      if (includedParent && includedChild) {
        _debugSymmetricPaintCount += 1;
      } else {
        _debugAsymmetricPaintCount += 1;
      }
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    bool inReleaseMode = true;
    assert(() {
      inReleaseMode = false;
      if (debugSymmetricPaintCount + debugAsymmetricPaintCount == 0) {
        properties.add(MessageProperty('usefulness ratio', 'no metrics collected yet (never painted)'));
      } else {
        final double fraction = debugAsymmetricPaintCount / (debugSymmetricPaintCount + debugAsymmetricPaintCount);
        final String diagnosis;
        if (debugSymmetricPaintCount + debugAsymmetricPaintCount < 5) {
          diagnosis = 'insufficient data to draw conclusion (less than five repaints)';
        } else if (fraction > 0.9) {
          diagnosis = 'this is an outstandingly useful repaint boundary and should definitely be kept';
        } else if (fraction > 0.5) {
          diagnosis = 'this is a useful repaint boundary and should be kept';
        } else if (fraction > 0.30) {
          diagnosis = 'this repaint boundary is probably useful, but maybe it would be more useful in tandem with adding more repaint boundaries elsewhere';
        } else if (fraction > 0.1) {
          diagnosis = 'this repaint boundary does sometimes show value, though currently not that often';
        } else if (debugAsymmetricPaintCount == 0) {
          diagnosis = 'this repaint boundary is astoundingly ineffectual and should be removed';
        } else {
          diagnosis = 'this repaint boundary is not very effective and should probably be removed';
        }
        properties.add(PercentProperty('metrics', fraction, unit: 'useful', tooltip: '$debugSymmetricPaintCount bad vs $debugAsymmetricPaintCount good'));
        properties.add(MessageProperty('diagnosis', diagnosis));
      }
      return true;
    }());
    if (inReleaseMode) {
      properties.add(DiagnosticsNode.message('(run in debug mode to collect repaint boundary statistics)'));
    }
  }
}

class RenderIgnorePointer extends RenderProxyBox {
  RenderIgnorePointer({
    RenderBox? child,
    bool ignoring = true,
    @Deprecated(
      'Use ExcludeSemantics or create a custom ignore pointer widget instead. '
      'This feature was deprecated after v3.8.0-12.0.pre.'
    )
    bool? ignoringSemantics,
  }) : _ignoring = ignoring,
       _ignoringSemantics = ignoringSemantics,
       super(child);

  bool get ignoring => _ignoring;
  bool _ignoring;
  set ignoring(bool value) {
    if (value == _ignoring) {
      return;
    }
    _ignoring = value;
    if (ignoringSemantics == null) {
      markNeedsSemanticsUpdate();
    }
  }

  @Deprecated(
    'Use ExcludeSemantics or create a custom ignore pointer widget instead. '
    'This feature was deprecated after v3.8.0-12.0.pre.'
  )
  bool? get ignoringSemantics => _ignoringSemantics;
  bool? _ignoringSemantics;
  set ignoringSemantics(bool? value) {
    if (value == _ignoringSemantics) {
      return;
    }
    _ignoringSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    return !ignoring && super.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_ignoringSemantics ?? false) {
      return;
    }
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // Do not block user interactions if _ignoringSemantics is false; otherwise,
    // delegate to _ignoring
    config.isBlockingUserActions = _ignoring && (_ignoringSemantics ?? true);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('ignoring', _ignoring));
    properties.add(
      DiagnosticsProperty<bool>(
        'ignoringSemantics',
        _ignoringSemantics,
        description: _ignoringSemantics == null ? null : 'implicitly $_ignoringSemantics',
      ),
    );
  }
}

class RenderOffstage extends RenderProxyBox {
  RenderOffstage({
    bool offstage = true,
    RenderBox? child,
  }) : _offstage = offstage,
       super(child);

  bool get offstage => _offstage;
  bool _offstage;
  set offstage(bool value) {
    if (value == _offstage) {
      return;
    }
    _offstage = value;
    markNeedsLayoutForSizedByParentChange();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (offstage) {
      return 0.0;
    }
    return super.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (offstage) {
      return 0.0;
    }
    return super.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (offstage) {
      return 0.0;
    }
    return super.computeMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (offstage) {
      return 0.0;
    }
    return super.computeMaxIntrinsicHeight(width);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (offstage) {
      return null;
    }
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool get sizedByParent => offstage;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (offstage) {
      return constraints.smallest;
    }
    return super.computeDryLayout(constraints);
  }

  @override
  void performResize() {
    assert(offstage);
    super.performResize();
  }

  @override
  void performLayout() {
    if (offstage) {
      child?.layout(constraints);
    } else {
      super.performLayout();
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    return !offstage && super.hitTest(result, position: position);
  }

  @override
  bool paintsChild(RenderBox child) {
    assert(child.parent == this);
    return !offstage;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (offstage) {
      return;
    }
    super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (offstage) {
      return;
    }
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('offstage', offstage));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    if (child == null) {
      return <DiagnosticsNode>[];
    }
    return <DiagnosticsNode>[
      child!.toDiagnosticsNode(
        name: 'child',
        style: offstage ? DiagnosticsTreeStyle.offstage : DiagnosticsTreeStyle.sparse,
      ),
    ];
  }
}

class RenderAbsorbPointer extends RenderProxyBox {
  RenderAbsorbPointer({
    RenderBox? child,
    bool absorbing = true,
    @Deprecated(
      'Use ExcludeSemantics or create a custom absorb pointer widget instead. '
      'This feature was deprecated after v3.8.0-12.0.pre.'
    )
    bool? ignoringSemantics,
  }) : _absorbing = absorbing,
       _ignoringSemantics = ignoringSemantics,
       super(child);

  bool get absorbing => _absorbing;
  bool _absorbing;
  set absorbing(bool value) {
    if (_absorbing == value) {
      return;
    }
    _absorbing = value;
    if (ignoringSemantics == null) {
      markNeedsSemanticsUpdate();
    }
  }

  @Deprecated(
    'Use ExcludeSemantics or create a custom absorb pointer widget instead. '
    'This feature was deprecated after v3.8.0-12.0.pre.'
  )
  bool? get ignoringSemantics => _ignoringSemantics;
  bool? _ignoringSemantics;
  set ignoringSemantics(bool? value) {
    if (value == _ignoringSemantics) {
      return;
    }
    _ignoringSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    return absorbing
        ? size.contains(position)
        : super.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_ignoringSemantics ?? false) {
      return;
    }
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // Do not block user interactions if _ignoringSemantics is false; otherwise,
    // delegate to absorbing
    config.isBlockingUserActions = absorbing && (_ignoringSemantics ?? true);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('absorbing', absorbing));
    properties.add(
      DiagnosticsProperty<bool>(
        'ignoringSemantics',
        ignoringSemantics,
        description: ignoringSemantics == null ? null : 'implicitly $ignoringSemantics',
      ),
    );
  }
}

class RenderMetaData extends RenderProxyBoxWithHitTestBehavior {
  RenderMetaData({
    this.metaData,
    super.behavior,
    super.child,
  });

  dynamic metaData;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<dynamic>('metaData', metaData));
  }
}

class RenderSemanticsGestureHandler extends RenderProxyBoxWithHitTestBehavior {
  RenderSemanticsGestureHandler({
    super.child,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    GestureDragUpdateCallback? onHorizontalDragUpdate,
    GestureDragUpdateCallback? onVerticalDragUpdate,
    this.scrollFactor = 0.8,
    super.behavior,
  }) : _onTap = onTap,
       _onLongPress = onLongPress,
       _onHorizontalDragUpdate = onHorizontalDragUpdate,
       _onVerticalDragUpdate = onVerticalDragUpdate;

  Set<SemanticsAction>? get validActions => _validActions;
  Set<SemanticsAction>? _validActions;
  set validActions(Set<SemanticsAction>? value) {
    if (setEquals<SemanticsAction>(value, _validActions)) {
      return;
    }
    _validActions = value;
    markNeedsSemanticsUpdate();
  }

  GestureTapCallback? get onTap => _onTap;
  GestureTapCallback? _onTap;
  set onTap(GestureTapCallback? value) {
    if (_onTap == value) {
      return;
    }
    final bool hadHandler = _onTap != null;
    _onTap = value;
    if ((value != null) != hadHandler) {
      markNeedsSemanticsUpdate();
    }
  }

  GestureLongPressCallback? get onLongPress => _onLongPress;
  GestureLongPressCallback? _onLongPress;
  set onLongPress(GestureLongPressCallback? value) {
    if (_onLongPress == value) {
      return;
    }
    final bool hadHandler = _onLongPress != null;
    _onLongPress = value;
    if ((value != null) != hadHandler) {
      markNeedsSemanticsUpdate();
    }
  }

  GestureDragUpdateCallback? get onHorizontalDragUpdate => _onHorizontalDragUpdate;
  GestureDragUpdateCallback? _onHorizontalDragUpdate;
  set onHorizontalDragUpdate(GestureDragUpdateCallback? value) {
    if (_onHorizontalDragUpdate == value) {
      return;
    }
    final bool hadHandler = _onHorizontalDragUpdate != null;
    _onHorizontalDragUpdate = value;
    if ((value != null) != hadHandler) {
      markNeedsSemanticsUpdate();
    }
  }

  GestureDragUpdateCallback? get onVerticalDragUpdate => _onVerticalDragUpdate;
  GestureDragUpdateCallback? _onVerticalDragUpdate;
  set onVerticalDragUpdate(GestureDragUpdateCallback? value) {
    if (_onVerticalDragUpdate == value) {
      return;
    }
    final bool hadHandler = _onVerticalDragUpdate != null;
    _onVerticalDragUpdate = value;
    if ((value != null) != hadHandler) {
      markNeedsSemanticsUpdate();
    }
  }

  double scrollFactor;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    if (onTap != null && _isValidAction(SemanticsAction.tap)) {
      config.onTap = onTap;
    }
    if (onLongPress != null && _isValidAction(SemanticsAction.longPress)) {
      config.onLongPress = onLongPress;
    }
    if (onHorizontalDragUpdate != null) {
      if (_isValidAction(SemanticsAction.scrollRight)) {
        config.onScrollRight = _performSemanticScrollRight;
      }
      if (_isValidAction(SemanticsAction.scrollLeft)) {
        config.onScrollLeft = _performSemanticScrollLeft;
      }
    }
    if (onVerticalDragUpdate != null) {
      if (_isValidAction(SemanticsAction.scrollUp)) {
        config.onScrollUp = _performSemanticScrollUp;
      }
      if (_isValidAction(SemanticsAction.scrollDown)) {
        config.onScrollDown = _performSemanticScrollDown;
      }
    }
  }

  bool _isValidAction(SemanticsAction action) {
    return validActions == null || validActions!.contains(action);
  }

  void _performSemanticScrollLeft() {
    if (onHorizontalDragUpdate != null) {
      final double primaryDelta = size.width * -scrollFactor;
      onHorizontalDragUpdate!(DragUpdateDetails(
        delta: Offset(primaryDelta, 0.0), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  void _performSemanticScrollRight() {
    if (onHorizontalDragUpdate != null) {
      final double primaryDelta = size.width * scrollFactor;
      onHorizontalDragUpdate!(DragUpdateDetails(
        delta: Offset(primaryDelta, 0.0), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  void _performSemanticScrollUp() {
    if (onVerticalDragUpdate != null) {
      final double primaryDelta = size.height * -scrollFactor;
      onVerticalDragUpdate!(DragUpdateDetails(
        delta: Offset(0.0, primaryDelta), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  void _performSemanticScrollDown() {
    if (onVerticalDragUpdate != null) {
      final double primaryDelta = size.height * scrollFactor;
      onVerticalDragUpdate!(DragUpdateDetails(
        delta: Offset(0.0, primaryDelta), primaryDelta: primaryDelta,
        globalPosition: localToGlobal(size.center(Offset.zero)),
      ));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final List<String> gestures = <String>[
      if (onTap != null) 'tap',
      if (onLongPress != null) 'long press',
      if (onHorizontalDragUpdate != null) 'horizontal scroll',
      if (onVerticalDragUpdate != null) 'vertical scroll',
    ];
    if (gestures.isEmpty) {
      gestures.add('<none>');
    }
    properties.add(IterableProperty<String>('gestures', gestures));
  }
}

class RenderSemanticsAnnotations extends RenderProxyBox {
  RenderSemanticsAnnotations({
    RenderBox? child,
    required SemanticsProperties properties,
    bool container = false,
    bool explicitChildNodes = false,
    bool excludeSemantics = false,
    bool blockUserActions = false,
    TextDirection? textDirection,
  })  : _container = container,
        _explicitChildNodes = explicitChildNodes,
        _excludeSemantics = excludeSemantics,
        _blockUserActions = blockUserActions,
        _textDirection = textDirection,
        _properties = properties,
        super(child) {
    _updateAttributedFields(_properties);
  }

  SemanticsProperties get properties => _properties;
  SemanticsProperties _properties;
  set properties(SemanticsProperties value) {
    if (_properties == value) {
      return;
    }
    _properties = value;
    _updateAttributedFields(_properties);
    markNeedsSemanticsUpdate();
  }

  bool get container => _container;
  bool _container;
  set container(bool value) {
    if (container == value) {
      return;
    }
    _container = value;
    markNeedsSemanticsUpdate();
  }

  bool get explicitChildNodes => _explicitChildNodes;
  bool _explicitChildNodes;
  set explicitChildNodes(bool value) {
    if (_explicitChildNodes == value) {
      return;
    }
    _explicitChildNodes = value;
    markNeedsSemanticsUpdate();
  }

  bool get excludeSemantics => _excludeSemantics;
  bool _excludeSemantics;
  set excludeSemantics(bool value) {
    if (_excludeSemantics == value) {
      return;
    }
    _excludeSemantics = value;
    markNeedsSemanticsUpdate();
  }

  bool get blockUserActions => _blockUserActions;
  bool _blockUserActions;
  set blockUserActions(bool value) {
    if (_blockUserActions == value) {
      return;
    }
    _blockUserActions = value;
    markNeedsSemanticsUpdate();
  }

  void _updateAttributedFields(SemanticsProperties value) {
    _attributedLabel = _effectiveAttributedLabel(value);
    _attributedValue = _effectiveAttributedValue(value);
    _attributedIncreasedValue = _effectiveAttributedIncreasedValue(value);
    _attributedDecreasedValue = _effectiveAttributedDecreasedValue(value);
    _attributedHint = _effectiveAttributedHint(value);
  }

  AttributedString? _effectiveAttributedLabel(SemanticsProperties value) {
    return value.attributedLabel ??
        (value.label == null ? null : AttributedString(value.label!));
  }

  AttributedString? _effectiveAttributedValue(SemanticsProperties value) {
    return value.attributedValue ??
        (value.value == null ? null : AttributedString(value.value!));
  }

  AttributedString? _effectiveAttributedIncreasedValue(
      SemanticsProperties value) {
    return value.attributedIncreasedValue ??
        (value.increasedValue == null
            ? null
            : AttributedString(value.increasedValue!));
  }

  AttributedString? _effectiveAttributedDecreasedValue(
      SemanticsProperties value) {
    return properties.attributedDecreasedValue ??
        (value.decreasedValue == null
            ? null
            : AttributedString(value.decreasedValue!));
  }

  AttributedString? _effectiveAttributedHint(SemanticsProperties value) {
    return value.attributedHint ??
        (value.hint == null ? null : AttributedString(value.hint!));
  }

  AttributedString? _attributedLabel;
  AttributedString? _attributedValue;
  AttributedString? _attributedIncreasedValue;
  AttributedString? _attributedDecreasedValue;
  AttributedString? _attributedHint;

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (excludeSemantics) {
      return;
    }
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = container;
    config.explicitChildNodes = explicitChildNodes;
    config.isBlockingUserActions = blockUserActions;
    assert(
      ((_properties.scopesRoute ?? false) && explicitChildNodes) || !(_properties.scopesRoute ?? false),
      'explicitChildNodes must be set to true if scopes route is true',
    );
    assert(
      !((_properties.toggled ?? false) && (_properties.checked ?? false)),
      'A semantics node cannot be toggled and checked at the same time',
    );

    if (_properties.enabled != null) {
      config.isEnabled = _properties.enabled;
    }
    if (_properties.checked != null) {
      config.isChecked = _properties.checked;
    }
    if (_properties.mixed != null) {
      config.isCheckStateMixed = _properties.mixed;
    }
    if (_properties.toggled != null) {
      config.isToggled = _properties.toggled;
    }
    if (_properties.selected != null) {
      config.isSelected = _properties.selected!;
    }
    if (_properties.button != null) {
      config.isButton = _properties.button!;
    }
    if (_properties.expanded != null) {
      config.isExpanded = _properties.expanded;
    }
    if (_properties.link != null) {
      config.isLink = _properties.link!;
    }
    if (_properties.slider != null) {
      config.isSlider = _properties.slider!;
    }
    if (_properties.keyboardKey != null) {
      config.isKeyboardKey = _properties.keyboardKey!;
    }
    if (_properties.header != null) {
      config.isHeader = _properties.header!;
    }
    if (_properties.textField != null) {
      config.isTextField = _properties.textField!;
    }
    if (_properties.readOnly != null) {
      config.isReadOnly = _properties.readOnly!;
    }
    if (_properties.focusable != null) {
      config.isFocusable = _properties.focusable!;
    }
    if (_properties.focused != null) {
      config.isFocused = _properties.focused!;
    }
    if (_properties.inMutuallyExclusiveGroup != null) {
      config.isInMutuallyExclusiveGroup = _properties.inMutuallyExclusiveGroup!;
    }
    if (_properties.obscured != null) {
      config.isObscured = _properties.obscured!;
    }
    if (_properties.multiline != null) {
      config.isMultiline = _properties.multiline!;
    }
    if (_properties.hidden != null) {
      config.isHidden = _properties.hidden!;
    }
    if (_properties.image != null) {
      config.isImage = _properties.image!;
    }
    if (_attributedLabel != null) {
      config.attributedLabel = _attributedLabel!;
    }
    if (_attributedValue != null) {
      config.attributedValue = _attributedValue!;
    }
    if (_attributedIncreasedValue != null) {
      config.attributedIncreasedValue = _attributedIncreasedValue!;
    }
    if (_attributedDecreasedValue != null) {
      config.attributedDecreasedValue = _attributedDecreasedValue!;
    }
    if (_attributedHint != null) {
      config.attributedHint = _attributedHint!;
    }
    if (_properties.tooltip != null) {
      config.tooltip = _properties.tooltip!;
    }
    if (_properties.hintOverrides != null && _properties.hintOverrides!.isNotEmpty) {
      config.hintOverrides = _properties.hintOverrides;
    }
    if (_properties.scopesRoute != null) {
      config.scopesRoute = _properties.scopesRoute!;
    }
    if (_properties.namesRoute != null) {
      config.namesRoute = _properties.namesRoute!;
    }
    if (_properties.liveRegion != null) {
      config.liveRegion = _properties.liveRegion!;
    }
    if (_properties.maxValueLength != null) {
      config.maxValueLength = _properties.maxValueLength;
    }
    if (_properties.currentValueLength != null) {
      config.currentValueLength = _properties.currentValueLength;
    }
    if (textDirection != null) {
      config.textDirection = textDirection;
    }
    if (_properties.sortKey != null) {
      config.sortKey = _properties.sortKey;
    }
    if (_properties.tagForChildren != null) {
      config.addTagForChildren(_properties.tagForChildren!);
    }
    // Registering _perform* as action handlers instead of the user provided
    // ones to ensure that changing a user provided handler from a non-null to
    // another non-null value doesn't require a semantics update.
    if (_properties.onTap != null) {
      config.onTap = _performTap;
    }
    if (_properties.onLongPress != null) {
      config.onLongPress = _performLongPress;
    }
    if (_properties.onDismiss != null) {
      config.onDismiss = _performDismiss;
    }
    if (_properties.onScrollLeft != null) {
      config.onScrollLeft = _performScrollLeft;
    }
    if (_properties.onScrollRight != null) {
      config.onScrollRight = _performScrollRight;
    }
    if (_properties.onScrollUp != null) {
      config.onScrollUp = _performScrollUp;
    }
    if (_properties.onScrollDown != null) {
      config.onScrollDown = _performScrollDown;
    }
    if (_properties.onIncrease != null) {
      config.onIncrease = _performIncrease;
    }
    if (_properties.onDecrease != null) {
      config.onDecrease = _performDecrease;
    }
    if (_properties.onCopy != null) {
      config.onCopy = _performCopy;
    }
    if (_properties.onCut != null) {
      config.onCut = _performCut;
    }
    if (_properties.onPaste != null) {
      config.onPaste = _performPaste;
    }
    if (_properties.onMoveCursorForwardByCharacter != null) {
      config.onMoveCursorForwardByCharacter = _performMoveCursorForwardByCharacter;
    }
    if (_properties.onMoveCursorBackwardByCharacter != null) {
      config.onMoveCursorBackwardByCharacter = _performMoveCursorBackwardByCharacter;
    }
    if (_properties.onMoveCursorForwardByWord != null) {
      config.onMoveCursorForwardByWord = _performMoveCursorForwardByWord;
    }
    if (_properties.onMoveCursorBackwardByWord != null) {
      config.onMoveCursorBackwardByWord = _performMoveCursorBackwardByWord;
    }
    if (_properties.onSetSelection != null) {
      config.onSetSelection = _performSetSelection;
    }
    if (_properties.onSetText != null) {
      config.onSetText = _performSetText;
    }
    if (_properties.onDidGainAccessibilityFocus != null) {
      config.onDidGainAccessibilityFocus = _performDidGainAccessibilityFocus;
    }
    if (_properties.onDidLoseAccessibilityFocus != null) {
      config.onDidLoseAccessibilityFocus = _performDidLoseAccessibilityFocus;
    }
    if (_properties.customSemanticsActions != null) {
      config.customSemanticsActions = _properties.customSemanticsActions!;
    }
  }

  void _performTap() {
    _properties.onTap?.call();
  }

  void _performLongPress() {
    _properties.onLongPress?.call();
  }

  void _performDismiss() {
    _properties.onDismiss?.call();
  }

  void _performScrollLeft() {
    _properties.onScrollLeft?.call();
  }

  void _performScrollRight() {
    _properties.onScrollRight?.call();
  }

  void _performScrollUp() {
    _properties.onScrollUp?.call();
  }

  void _performScrollDown() {
    _properties.onScrollDown?.call();
  }

  void _performIncrease() {
    _properties.onIncrease?.call();
  }

  void _performDecrease() {
    _properties.onDecrease?.call();
  }

  void _performCopy() {
    _properties.onCopy?.call();
  }

  void _performCut() {
    _properties.onCut?.call();
  }

  void _performPaste() {
    _properties.onPaste?.call();
  }

  void _performMoveCursorForwardByCharacter(bool extendSelection) {
    _properties.onMoveCursorForwardByCharacter?.call(extendSelection);
  }

  void _performMoveCursorBackwardByCharacter(bool extendSelection) {
    _properties.onMoveCursorBackwardByCharacter?.call(extendSelection);
  }

  void _performMoveCursorForwardByWord(bool extendSelection) {
    _properties.onMoveCursorForwardByWord?.call(extendSelection);
  }

  void _performMoveCursorBackwardByWord(bool extendSelection) {
    _properties.onMoveCursorBackwardByWord?.call(extendSelection);
  }

  void _performSetSelection(TextSelection selection) {
    _properties.onSetSelection?.call(selection);
  }

  void _performSetText(String text) {
    _properties.onSetText?.call(text);
  }

  void _performDidGainAccessibilityFocus() {
    _properties.onDidGainAccessibilityFocus?.call();
  }

  void _performDidLoseAccessibilityFocus() {
    _properties.onDidLoseAccessibilityFocus?.call();
  }
}

class RenderBlockSemantics extends RenderProxyBox {
  RenderBlockSemantics({
    RenderBox? child,
    bool blocking = true,
  }) : _blocking = blocking,
       super(child);

  bool get blocking => _blocking;
  bool _blocking;
  set blocking(bool value) {
    if (value == _blocking) {
      return;
    }
    _blocking = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isBlockingSemanticsOfPreviouslyPaintedNodes = blocking;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('blocking', blocking));
  }
}

class RenderMergeSemantics extends RenderProxyBox {
  RenderMergeSemantics({ RenderBox? child }) : super(child);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isMergingSemanticsOfDescendants = true;
  }
}

class RenderExcludeSemantics extends RenderProxyBox {
  RenderExcludeSemantics({
    RenderBox? child,
    bool excluding = true,
  }) : _excluding = excluding,
       super(child);

  bool get excluding => _excluding;
  bool _excluding;
  set excluding(bool value) {
    if (value == _excluding) {
      return;
    }
    _excluding = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (excluding) {
      return;
    }
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('excluding', excluding));
  }
}

class RenderIndexedSemantics extends RenderProxyBox {
  RenderIndexedSemantics({
    RenderBox? child,
    required int index,
  }) : _index = index,
       super(child);

  int get index => _index;
  int _index;
  set index(int value) {
    if (value == index) {
      return;
    }
    _index = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.indexInParent = index;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<int>('index', index));
  }
}

class RenderLeaderLayer extends RenderProxyBox {
  RenderLeaderLayer({
    required LayerLink link,
    RenderBox? child,
  }) : _link = link,
       super(child);

  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    if (_link == value) {
      return;
    }
    _link.leaderSize = null;
    _link = value;
    if (_previousLayoutSize != null) {
      _link.leaderSize = _previousLayoutSize;
    }
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  // The latest size of this [RenderBox], computed during the previous layout
  // pass. It should always be equal to [size], but can be accessed even when
  // [debugDoingThisResize] and [debugDoingThisLayout] are false.
  Size? _previousLayoutSize;

  @override
  void performLayout() {
    super.performLayout();
    _previousLayoutSize = size;
    link.leaderSize = size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (layer == null) {
      layer = LeaderLayer(link: link, offset: offset);
    } else {
      final LeaderLayer leaderLayer = layer! as LeaderLayer;
      leaderLayer
        ..link = link
        ..offset = offset;
    }
    context.pushLayer(layer!, super.paint, Offset.zero);
    assert(() {
      layer!.debugCreator = debugCreator;
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
  }
}

class RenderFollowerLayer extends RenderProxyBox {
  RenderFollowerLayer({
    required LayerLink link,
    bool showWhenUnlinked = true,
    Offset offset = Offset.zero,
    Alignment leaderAnchor = Alignment.topLeft,
    Alignment followerAnchor = Alignment.topLeft,
    RenderBox? child,
  }) : _link = link,
       _showWhenUnlinked = showWhenUnlinked,
       _offset = offset,
       _leaderAnchor = leaderAnchor,
       _followerAnchor = followerAnchor,
       super(child);

  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    if (_link == value) {
      return;
    }
    _link = value;
    markNeedsPaint();
  }

  bool get showWhenUnlinked => _showWhenUnlinked;
  bool _showWhenUnlinked;
  set showWhenUnlinked(bool value) {
    if (_showWhenUnlinked == value) {
      return;
    }
    _showWhenUnlinked = value;
    markNeedsPaint();
  }

  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    if (_offset == value) {
      return;
    }
    _offset = value;
    markNeedsPaint();
  }

  Alignment get leaderAnchor => _leaderAnchor;
  Alignment _leaderAnchor;
  set leaderAnchor(Alignment value) {
    if (_leaderAnchor == value) {
      return;
    }
    _leaderAnchor = value;
    markNeedsPaint();
  }

  Alignment get followerAnchor => _followerAnchor;
  Alignment _followerAnchor;
  set followerAnchor(Alignment value) {
    if (_followerAnchor == value) {
      return;
    }
    _followerAnchor = value;
    markNeedsPaint();
  }

  @override
  void detach() {
    layer = null;
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  FollowerLayer? get layer => super.layer as FollowerLayer?;

  Matrix4 getCurrentTransform() {
    return layer?.getLastTransform() ?? Matrix4.identity();
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    // Disables the hit testing if this render object is hidden.
    if (link.leader == null && !showWhenUnlinked) {
      return false;
    }
    // RenderFollowerLayer objects don't check if they are
    // themselves hit, because it's confusing to think about
    // how the untransformed size and the child's transformed
    // position interact.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return result.addWithPaintTransform(
      transform: getCurrentTransform(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Size? leaderSize = link.leaderSize;
    assert(
      link.leaderSize != null || link.leader == null || leaderAnchor == Alignment.topLeft,
      '$link: layer is linked to ${link.leader} but a valid leaderSize is not set. '
      'leaderSize is required when leaderAnchor is not Alignment.topLeft '
      '(current value is $leaderAnchor).',
    );
    final Offset effectiveLinkedOffset = leaderSize == null
      ? this.offset
      : leaderAnchor.alongSize(leaderSize) - followerAnchor.alongSize(size) + this.offset;
    if (layer == null) {
      layer = FollowerLayer(
        link: link,
        showWhenUnlinked: showWhenUnlinked,
        linkedOffset: effectiveLinkedOffset,
        unlinkedOffset: offset,
      );
    } else {
      layer
        ?..link = link
        ..showWhenUnlinked = showWhenUnlinked
        ..linkedOffset = effectiveLinkedOffset
        ..unlinkedOffset = offset;
    }
    context.pushLayer(
      layer!,
      super.paint,
      Offset.zero,
      childPaintBounds: const Rect.fromLTRB(
        // We don't know where we'll end up, so we have no idea what our cull rect should be.
        double.negativeInfinity,
        double.negativeInfinity,
        double.infinity,
        double.infinity,
      ),
    );
    assert(() {
      layer!.debugCreator = debugCreator;
      return true;
    }());
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(getCurrentTransform());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
    properties.add(DiagnosticsProperty<bool>('showWhenUnlinked', showWhenUnlinked));
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
    properties.add(TransformProperty('current transform matrix', getCurrentTransform()));
  }
}

class RenderAnnotatedRegion<T extends Object> extends RenderProxyBox {

  RenderAnnotatedRegion({
    required T value,
    required bool sized,
    RenderBox? child,
  }) : _value = value,
       _sized = sized,
       super(child);

  T get value => _value;
  T _value;
  set value (T newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    markNeedsPaint();
  }

  bool get sized => _sized;
  bool _sized;
  set sized(bool value) {
    if (_sized == value) {
      return;
    }
    _sized = value;
    markNeedsPaint();
  }

  @override
  final bool alwaysNeedsCompositing = true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Annotated region layers are not retained because they do not create engine layers.
    final AnnotatedRegionLayer<T> layer = AnnotatedRegionLayer<T>(
      value,
      size: sized ? size : null,
      offset: sized ? offset : null,
    );
    context.pushLayer(layer, super.paint, offset);
  }
}