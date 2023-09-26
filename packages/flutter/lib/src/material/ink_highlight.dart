import 'package:flutter/widgets.dart';

import 'ink_well.dart' show InteractiveInkFeature;
import 'material.dart';

const Duration _kDefaultHighlightFadeDuration = Duration(milliseconds: 200);

class InkHighlight extends InteractiveInkFeature {
  InkHighlight({
    required super.controller,
    required super.referenceBox,
    required super.color,
    required TextDirection textDirection,
    BoxShape shape = BoxShape.rectangle,
    double? radius,
    BorderRadius? borderRadius,
    super.customBorder,
    RectCallback? rectCallback,
    super.onRemoved,
    Duration fadeDuration = _kDefaultHighlightFadeDuration,
  })  : _shape = shape,
        _radius = radius,
        _borderRadius = borderRadius ?? BorderRadius.zero,
        _textDirection = textDirection,
        _rectCallback = rectCallback {
    _alphaController =
        AnimationController(duration: fadeDuration, vsync: controller.vsync)
          ..addListener(controller.markNeedsPaint)
          ..addStatusListener(_handleAlphaStatusChanged)
          ..forward();
    _alpha = _alphaController.drive(IntTween(
      begin: 0,
      end: color.alpha,
    ));

    controller.addInkFeature(this);
  }

  final BoxShape _shape;
  final double? _radius;
  final BorderRadius _borderRadius;
  final RectCallback? _rectCallback;
  final TextDirection _textDirection;

  late Animation<int> _alpha;
  late AnimationController _alphaController;

  bool get active => _active;
  bool _active = true;

  void activate() {
    _active = true;
    _alphaController.forward();
  }

  void deactivate() {
    _active = false;
    _alphaController.reverse();
  }

  void _handleAlphaStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_active) {
      dispose();
    }
  }

  @override
  void dispose() {
    _alphaController.dispose();
    super.dispose();
  }

  void _paintHighlight(Canvas canvas, Rect rect, Paint paint) {
    canvas.save();
    if (customBorder != null) {
      canvas.clipPath(
          customBorder!.getOuterPath(rect, textDirection: _textDirection));
    }
    switch (_shape) {
      case BoxShape.circle:
        canvas.drawCircle(
            rect.center, _radius ?? Material.defaultSplashRadius, paint);
      case BoxShape.rectangle:
        if (_borderRadius != BorderRadius.zero) {
          final RRect clipRRect = RRect.fromRectAndCorners(
            rect,
            topLeft: _borderRadius.topLeft,
            topRight: _borderRadius.topRight,
            bottomLeft: _borderRadius.bottomLeft,
            bottomRight: _borderRadius.bottomRight,
          );
          canvas.drawRRect(clipRRect, paint);
        } else {
          canvas.drawRect(rect, paint);
        }
    }
    canvas.restore();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final Paint paint = Paint()..color = color.withAlpha(_alpha.value);
    final Offset? originOffset = MatrixUtils.getAsTranslation(transform);
    final Rect rect = _rectCallback != null
        ? _rectCallback()
        : Offset.zero & referenceBox.size;
    if (originOffset == null) {
      canvas.save();
      canvas.transform(transform.storage);
      _paintHighlight(canvas, rect, paint);
      canvas.restore();
    } else {
      _paintHighlight(canvas, rect.shift(originOffset), paint);
    }
  }
}
