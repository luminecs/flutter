
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'box.dart';
import 'layer.dart';
import 'object.dart';
import 'shifted_box.dart';

@visibleForTesting
enum RenderAnimatedSizeState {
  start,

  stable,

  changed,

  unstable,
}

class RenderAnimatedSize extends RenderAligningShiftedBox {
  RenderAnimatedSize({
    required TickerProvider vsync,
    required Duration duration,
    Duration? reverseDuration,
    Curve curve = Curves.linear,
    super.alignment,
    super.textDirection,
    super.child,
    Clip clipBehavior = Clip.hardEdge,
  }) : _vsync = vsync,
       _clipBehavior = clipBehavior {
    _controller = AnimationController(
      vsync: vsync,
      duration: duration,
      reverseDuration: reverseDuration,
    )..addListener(() {
      if (_controller.value != _lastValue) {
        markNeedsLayout();
      }
    });
    _animation = CurvedAnimation(
      parent: _controller,
      curve: curve,
    );
  }

  @visibleForTesting
  AnimationController? get debugController {
    AnimationController? controller;
    assert(() {
      controller = _controller;
      return true;
    }());
    return controller;
  }

  @visibleForTesting
  CurvedAnimation? get debugAnimation {
    CurvedAnimation? animation;
    assert(() {
      animation = _animation;
      return true;
    }());
    return animation;
  }

  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  final SizeTween _sizeTween = SizeTween();
  late bool _hasVisualOverflow;
  double? _lastValue;

  @visibleForTesting
  RenderAnimatedSizeState get state => _state;
  RenderAnimatedSizeState _state = RenderAnimatedSizeState.start;

  Duration get duration => _controller.duration!;
  set duration(Duration value) {
    if (value == _controller.duration) {
      return;
    }
    _controller.duration = value;
  }

  Duration? get reverseDuration => _controller.reverseDuration;
  set reverseDuration(Duration? value) {
    if (value == _controller.reverseDuration) {
      return;
    }
    _controller.reverseDuration = value;
  }

  Curve get curve => _animation.curve;
  set curve(Curve value) {
    if (value == _animation.curve) {
      return;
    }
    _animation.curve = value;
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  bool get isAnimating => _controller.isAnimating;

  TickerProvider get vsync => _vsync;
  TickerProvider _vsync;
  set vsync(TickerProvider value) {
    if (value == _vsync) {
      return;
    }
    _vsync = value;
    _controller.resync(vsync);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    switch (state) {
      case RenderAnimatedSizeState.start:
      case RenderAnimatedSizeState.stable:
        break;
      case RenderAnimatedSizeState.changed:
      case RenderAnimatedSizeState.unstable:
        // Call markNeedsLayout in case the RenderObject isn't marked dirty
        // already, to resume interrupted resizing animation.
        markNeedsLayout();
    }
  }

  @override
  void detach() {
    _controller.stop();
    super.detach();
  }

  Size? get _animatedSize {
    return _sizeTween.evaluate(_animation);
  }

  @override
  void performLayout() {
    _lastValue = _controller.value;
    _hasVisualOverflow = false;
    final BoxConstraints constraints = this.constraints;
    if (child == null || constraints.isTight) {
      _controller.stop();
      size = _sizeTween.begin = _sizeTween.end = constraints.smallest;
      _state = RenderAnimatedSizeState.start;
      child?.layout(constraints);
      return;
    }

    child!.layout(constraints, parentUsesSize: true);

    switch (_state) {
      case RenderAnimatedSizeState.start:
        _layoutStart();
      case RenderAnimatedSizeState.stable:
        _layoutStable();
      case RenderAnimatedSizeState.changed:
        _layoutChanged();
      case RenderAnimatedSizeState.unstable:
        _layoutUnstable();
    }

    size = constraints.constrain(_animatedSize!);
    alignChild();

    if (size.width < _sizeTween.end!.width ||
        size.height < _sizeTween.end!.height) {
      _hasVisualOverflow = true;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null || constraints.isTight) {
      return constraints.smallest;
    }

    // This simplified version of performLayout only calculates the current
    // size without modifying global state. See performLayout for comments
    // explaining the rational behind the implementation.
    final Size childSize = child!.getDryLayout(constraints);
    switch (_state) {
      case RenderAnimatedSizeState.start:
        return constraints.constrain(childSize);
      case RenderAnimatedSizeState.stable:
        if (_sizeTween.end != childSize) {
          return constraints.constrain(size);
        } else if (_controller.value == _controller.upperBound) {
          return constraints.constrain(childSize);
        }
      case RenderAnimatedSizeState.unstable:
      case RenderAnimatedSizeState.changed:
        if (_sizeTween.end != childSize) {
          return constraints.constrain(childSize);
        }
    }

    return constraints.constrain(_animatedSize!);
  }

  void _restartAnimation() {
    _lastValue = 0.0;
    _controller.forward(from: 0.0);
  }

  void _layoutStart() {
    _sizeTween.begin = _sizeTween.end = debugAdoptSize(child!.size);
    _state = RenderAnimatedSizeState.stable;
  }

  void _layoutStable() {
    if (_sizeTween.end != child!.size) {
      _sizeTween.begin = size;
      _sizeTween.end = debugAdoptSize(child!.size);
      _restartAnimation();
      _state = RenderAnimatedSizeState.changed;
    } else if (_controller.value == _controller.upperBound) {
      // Animation finished. Reset target sizes.
      _sizeTween.begin = _sizeTween.end = debugAdoptSize(child!.size);
    } else if (!_controller.isAnimating) {
      _controller.forward(); // resume the animation after being detached
    }
  }

  void _layoutChanged() {
    if (_sizeTween.end != child!.size) {
      // Child size changed again. Match the child's size and restart animation.
      _sizeTween.begin = _sizeTween.end = debugAdoptSize(child!.size);
      _restartAnimation();
      _state = RenderAnimatedSizeState.unstable;
    } else {
      // Child size stabilized.
      _state = RenderAnimatedSizeState.stable;
      if (!_controller.isAnimating) {
        // Resume the animation after being detached.
        _controller.forward();
      }
    }
  }

  void _layoutUnstable() {
    if (_sizeTween.end != child!.size) {
      // Still unstable. Continue tracking the child.
      _sizeTween.begin = _sizeTween.end = debugAdoptSize(child!.size);
      _restartAnimation();
    } else {
      // Child size stabilized.
      _controller.stop();
      _state = RenderAnimatedSizeState.stable;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && _hasVisualOverflow && clipBehavior != Clip.none) {
      final Rect rect = Offset.zero & size;
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        rect,
        super.paint,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      super.paint(context, offset);
    }
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    _controller.dispose();
    _animation.dispose();
    super.dispose();
  }
}