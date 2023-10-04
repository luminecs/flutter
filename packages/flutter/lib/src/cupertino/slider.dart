import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';
import 'thumb_painter.dart';

// Examples can assume:
// int _cupertinoSliderValue = 1;
// void setState(VoidCallback fn) { }

class CupertinoSlider extends StatefulWidget {
  const CupertinoSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.thumbColor = CupertinoColors.white,
  })  : assert(value >= min && value <= max),
        assert(divisions == null || divisions > 0);

  final double value;

  final ValueChanged<double>? onChanged;

  final ValueChanged<double>? onChangeStart;

  final ValueChanged<double>? onChangeEnd;

  final double min;

  final double max;

  final int? divisions;

  final Color? activeColor;

  final Color thumbColor;

  @override
  State<CupertinoSlider> createState() => _CupertinoSliderState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('value', value));
    properties.add(DoubleProperty('min', min));
    properties.add(DoubleProperty('max', max));
  }
}

class _CupertinoSliderState extends State<CupertinoSlider>
    with TickerProviderStateMixin {
  void _handleChanged(double value) {
    assert(widget.onChanged != null);
    final double lerpValue = lerpDouble(widget.min, widget.max, value)!;
    if (lerpValue != widget.value) {
      widget.onChanged!(lerpValue);
    }
  }

  void _handleDragStart(double value) {
    assert(widget.onChangeStart != null);
    widget.onChangeStart!(lerpDouble(widget.min, widget.max, value)!);
  }

  void _handleDragEnd(double value) {
    assert(widget.onChangeEnd != null);
    widget.onChangeEnd!(lerpDouble(widget.min, widget.max, value)!);
  }

  @override
  Widget build(BuildContext context) {
    return _CupertinoSliderRenderObjectWidget(
      value: (widget.value - widget.min) / (widget.max - widget.min),
      divisions: widget.divisions,
      activeColor: CupertinoDynamicColor.resolve(
        widget.activeColor ?? CupertinoTheme.of(context).primaryColor,
        context,
      ),
      thumbColor: widget.thumbColor,
      onChanged: widget.onChanged != null ? _handleChanged : null,
      onChangeStart: widget.onChangeStart != null ? _handleDragStart : null,
      onChangeEnd: widget.onChangeEnd != null ? _handleDragEnd : null,
      vsync: this,
    );
  }
}

class _CupertinoSliderRenderObjectWidget extends LeafRenderObjectWidget {
  const _CupertinoSliderRenderObjectWidget({
    required this.value,
    this.divisions,
    required this.activeColor,
    required this.thumbColor,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    required this.vsync,
  });

  final double value;
  final int? divisions;
  final Color activeColor;
  final Color thumbColor;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final TickerProvider vsync;

  @override
  _RenderCupertinoSlider createRenderObject(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    return _RenderCupertinoSlider(
      value: value,
      divisions: divisions,
      activeColor: activeColor,
      thumbColor: CupertinoDynamicColor.resolve(thumbColor, context),
      trackColor:
          CupertinoDynamicColor.resolve(CupertinoColors.systemFill, context),
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      vsync: vsync,
      textDirection: Directionality.of(context),
      cursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderCupertinoSlider renderObject) {
    assert(debugCheckHasDirectionality(context));
    renderObject
      ..value = value
      ..divisions = divisions
      ..activeColor = activeColor
      ..thumbColor = CupertinoDynamicColor.resolve(thumbColor, context)
      ..trackColor =
          CupertinoDynamicColor.resolve(CupertinoColors.systemFill, context)
      ..onChanged = onChanged
      ..onChangeStart = onChangeStart
      ..onChangeEnd = onChangeEnd
      ..textDirection = Directionality.of(context);
    // Ticker provider cannot change since there's a 1:1 relationship between
    // the _SliderRenderObjectWidget object and the _SliderState object.
  }
}

const double _kPadding = 8.0;
const double _kSliderHeight = 2.0 * (CupertinoThumbPainter.radius + _kPadding);
const double _kSliderWidth = 176.0; // Matches Material Design slider.
const Duration _kDiscreteTransitionDuration = Duration(milliseconds: 500);

const double _kAdjustmentUnit =
    0.1; // Matches iOS implementation of material slider.

class _RenderCupertinoSlider extends RenderConstrainedBox
    implements MouseTrackerAnnotation {
  _RenderCupertinoSlider({
    required double value,
    int? divisions,
    required Color activeColor,
    required Color thumbColor,
    required Color trackColor,
    ValueChanged<double>? onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    required TickerProvider vsync,
    required TextDirection textDirection,
    MouseCursor cursor = MouseCursor.defer,
  })  : assert(value >= 0.0 && value <= 1.0),
        _cursor = cursor,
        _value = value,
        _divisions = divisions,
        _activeColor = activeColor,
        _thumbColor = thumbColor,
        _trackColor = trackColor,
        _onChanged = onChanged,
        _textDirection = textDirection,
        super(
            additionalConstraints: const BoxConstraints.tightFor(
                width: _kSliderWidth, height: _kSliderHeight)) {
    _drag = HorizontalDragGestureRecognizer()
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd;
    _position = AnimationController(
      value: value,
      duration: _kDiscreteTransitionDuration,
      vsync: vsync,
    )..addListener(markNeedsPaint);
  }

  double get value => _value;
  double _value;
  set value(double newValue) {
    assert(newValue >= 0.0 && newValue <= 1.0);
    if (newValue == _value) {
      return;
    }
    _value = newValue;
    if (divisions != null) {
      _position.animateTo(newValue, curve: Curves.fastOutSlowIn);
    } else {
      _position.value = newValue;
    }
    markNeedsSemanticsUpdate();
  }

  int? get divisions => _divisions;
  int? _divisions;
  set divisions(int? value) {
    if (value == _divisions) {
      return;
    }
    _divisions = value;
    markNeedsPaint();
  }

  Color get activeColor => _activeColor;
  Color _activeColor;
  set activeColor(Color value) {
    if (value == _activeColor) {
      return;
    }
    _activeColor = value;
    markNeedsPaint();
  }

  Color get thumbColor => _thumbColor;
  Color _thumbColor;
  set thumbColor(Color value) {
    if (value == _thumbColor) {
      return;
    }
    _thumbColor = value;
    markNeedsPaint();
  }

  Color get trackColor => _trackColor;
  Color _trackColor;
  set trackColor(Color value) {
    if (value == _trackColor) {
      return;
    }
    _trackColor = value;
    markNeedsPaint();
  }

  ValueChanged<double>? get onChanged => _onChanged;
  ValueChanged<double>? _onChanged;
  set onChanged(ValueChanged<double>? value) {
    if (value == _onChanged) {
      return;
    }
    final bool wasInteractive = isInteractive;
    _onChanged = value;
    if (wasInteractive != isInteractive) {
      markNeedsSemanticsUpdate();
    }
  }

  ValueChanged<double>? onChangeStart;
  ValueChanged<double>? onChangeEnd;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsPaint();
  }

  late AnimationController _position;

  late HorizontalDragGestureRecognizer _drag;
  double _currentDragValue = 0.0;

  double get _discretizedCurrentDragValue {
    double dragValue = clampDouble(_currentDragValue, 0.0, 1.0);
    if (divisions != null) {
      dragValue = (dragValue * divisions!).round() / divisions!;
    }
    return dragValue;
  }

  double get _trackLeft => _kPadding;
  double get _trackRight => size.width - _kPadding;
  double get _thumbCenter {
    final double visualPosition;
    switch (textDirection) {
      case TextDirection.rtl:
        visualPosition = 1.0 - _value;
      case TextDirection.ltr:
        visualPosition = _value;
    }
    return lerpDouble(_trackLeft + CupertinoThumbPainter.radius,
        _trackRight - CupertinoThumbPainter.radius, visualPosition)!;
  }

  bool get isInteractive => onChanged != null;

  void _handleDragStart(DragStartDetails details) =>
      _startInteraction(details.globalPosition);

  void _handleDragUpdate(DragUpdateDetails details) {
    if (isInteractive) {
      final double extent = math.max(_kPadding,
          size.width - 2.0 * (_kPadding + CupertinoThumbPainter.radius));
      final double valueDelta = details.primaryDelta! / extent;
      switch (textDirection) {
        case TextDirection.rtl:
          _currentDragValue -= valueDelta;
        case TextDirection.ltr:
          _currentDragValue += valueDelta;
      }
      onChanged!(_discretizedCurrentDragValue);
    }
  }

  void _handleDragEnd(DragEndDetails details) => _endInteraction();

  void _startInteraction(Offset globalPosition) {
    if (isInteractive) {
      onChangeStart?.call(_discretizedCurrentDragValue);
      _currentDragValue = _value;
      onChanged!(_discretizedCurrentDragValue);
    }
  }

  void _endInteraction() {
    onChangeEnd?.call(_discretizedCurrentDragValue);
    _currentDragValue = 0.0;
  }

  @override
  bool hitTestSelf(Offset position) {
    return (position.dx - _thumbCenter).abs() <
        CupertinoThumbPainter.radius + _kPadding;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent && isInteractive) {
      _drag.addPointer(event);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final double visualPosition;
    final Color leftColor;
    final Color rightColor;
    switch (textDirection) {
      case TextDirection.rtl:
        visualPosition = 1.0 - _position.value;
        leftColor = _activeColor;
        rightColor = trackColor;
      case TextDirection.ltr:
        visualPosition = _position.value;
        leftColor = trackColor;
        rightColor = _activeColor;
    }

    final double trackCenter = offset.dy + size.height / 2.0;
    final double trackLeft = offset.dx + _trackLeft;
    final double trackTop = trackCenter - 1.0;
    final double trackBottom = trackCenter + 1.0;
    final double trackRight = offset.dx + _trackRight;
    final double trackActive = offset.dx + _thumbCenter;

    final Canvas canvas = context.canvas;

    if (visualPosition > 0.0) {
      final Paint paint = Paint()..color = rightColor;
      canvas.drawRRect(
          RRect.fromLTRBXY(
              trackLeft, trackTop, trackActive, trackBottom, 1.0, 1.0),
          paint);
    }

    if (visualPosition < 1.0) {
      final Paint paint = Paint()..color = leftColor;
      canvas.drawRRect(
          RRect.fromLTRBXY(
              trackActive, trackTop, trackRight, trackBottom, 1.0, 1.0),
          paint);
    }

    final Offset thumbCenter = Offset(trackActive, trackCenter);
    CupertinoThumbPainter(color: thumbColor).paint(
        canvas,
        Rect.fromCircle(
            center: thumbCenter, radius: CupertinoThumbPainter.radius));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config.isSemanticBoundary = isInteractive;
    config.isSlider = true;
    if (isInteractive) {
      config.textDirection = textDirection;
      config.onIncrease = _increaseAction;
      config.onDecrease = _decreaseAction;
      config.value = '${(value * 100).round()}%';
      config.increasedValue =
          '${(clampDouble(value + _semanticActionUnit, 0.0, 1.0) * 100).round()}%';
      config.decreasedValue =
          '${(clampDouble(value - _semanticActionUnit, 0.0, 1.0) * 100).round()}%';
    }
  }

  double get _semanticActionUnit =>
      divisions != null ? 1.0 / divisions! : _kAdjustmentUnit;

  void _increaseAction() {
    if (isInteractive) {
      onChanged!(clampDouble(value + _semanticActionUnit, 0.0, 1.0));
    }
  }

  void _decreaseAction() {
    if (isInteractive) {
      onChanged!(clampDouble(value - _semanticActionUnit, 0.0, 1.0));
    }
  }

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
  PointerEnterEventListener? onEnter;

  PointerHoverEventListener? onHover;

  @override
  PointerExitEventListener? onExit;

  @override
  bool get validForMouseTracker => false;
}
