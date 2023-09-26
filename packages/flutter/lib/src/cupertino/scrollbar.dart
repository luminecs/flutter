import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';

// All values eyeballed.
const double _kScrollbarMinLength = 36.0;
const double _kScrollbarMinOverscrollLength = 8.0;
const Duration _kScrollbarTimeToFade = Duration(milliseconds: 1200);
const Duration _kScrollbarFadeDuration = Duration(milliseconds: 250);
const Duration _kScrollbarResizeDuration = Duration(milliseconds: 100);

// Extracted from iOS 13.1 beta using Debug View Hierarchy.
const Color _kScrollbarColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x59000000),
  darkColor: Color(0x80FFFFFF),
);

// This is the amount of space from the top of a vertical scrollbar to the
// top edge of the scrollable, measured when the vertical scrollbar overscrolls
// to the top.
// TODO(LongCatIsLooong): fix https://github.com/flutter/flutter/issues/32175
const double _kScrollbarMainAxisMargin = 3.0;
const double _kScrollbarCrossAxisMargin = 3.0;

class CupertinoScrollbar extends RawScrollbar {
  const CupertinoScrollbar({
    super.key,
    required super.child,
    super.controller,
    bool? thumbVisibility,
    double super.thickness = defaultThickness,
    this.thicknessWhileDragging = defaultThicknessWhileDragging,
    Radius super.radius = defaultRadius,
    this.radiusWhileDragging = defaultRadiusWhileDragging,
    ScrollNotificationPredicate? notificationPredicate,
    super.scrollbarOrientation,
  })  : assert(thickness < double.infinity),
        assert(thicknessWhileDragging < double.infinity),
        super(
          thumbVisibility: thumbVisibility ?? false,
          fadeDuration: _kScrollbarFadeDuration,
          timeToFade: _kScrollbarTimeToFade,
          pressDuration: const Duration(milliseconds: 100),
          notificationPredicate:
              notificationPredicate ?? defaultScrollNotificationPredicate,
        );

  static const double defaultThickness = 3;

  static const double defaultThicknessWhileDragging = 8.0;

  static const Radius defaultRadius = Radius.circular(1.5);

  static const Radius defaultRadiusWhileDragging = Radius.circular(4.0);

  final double thicknessWhileDragging;

  final Radius radiusWhileDragging;

  @override
  RawScrollbarState<CupertinoScrollbar> createState() =>
      _CupertinoScrollbarState();
}

class _CupertinoScrollbarState extends RawScrollbarState<CupertinoScrollbar> {
  late AnimationController _thicknessAnimationController;

  double get _thickness {
    return widget.thickness! +
        _thicknessAnimationController.value *
            (widget.thicknessWhileDragging - widget.thickness!);
  }

  Radius get _radius {
    return Radius.lerp(widget.radius, widget.radiusWhileDragging,
        _thicknessAnimationController.value)!;
  }

  @override
  void initState() {
    super.initState();
    _thicknessAnimationController = AnimationController(
      vsync: this,
      duration: _kScrollbarResizeDuration,
    );
    _thicknessAnimationController.addListener(() {
      updateScrollbarPainter();
    });
  }

  @override
  void updateScrollbarPainter() {
    scrollbarPainter
      ..color = CupertinoDynamicColor.resolve(_kScrollbarColor, context)
      ..textDirection = Directionality.of(context)
      ..thickness = _thickness
      ..mainAxisMargin = _kScrollbarMainAxisMargin
      ..crossAxisMargin = _kScrollbarCrossAxisMargin
      ..radius = _radius
      ..padding = MediaQuery.paddingOf(context)
      ..minLength = _kScrollbarMinLength
      ..minOverscrollLength = _kScrollbarMinOverscrollLength
      ..scrollbarOrientation = widget.scrollbarOrientation;
  }

  double _pressStartAxisPosition = 0.0;

  // Long press event callbacks handle the gesture where the user long presses
  // on the scrollbar thumb and then drags the scrollbar without releasing.

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    final Axis? direction = getScrollbarDirection();
    if (direction == null) {
      return;
    }
    switch (direction) {
      case Axis.vertical:
        _pressStartAxisPosition = localPosition.dy;
      case Axis.horizontal:
        _pressStartAxisPosition = localPosition.dx;
    }
  }

  @override
  void handleThumbPress() {
    if (getScrollbarDirection() == null) {
      return;
    }
    super.handleThumbPress();
    _thicknessAnimationController.forward().then<void>(
          (_) => HapticFeedback.mediumImpact(),
        );
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    final Axis? direction = getScrollbarDirection();
    if (direction == null) {
      return;
    }
    _thicknessAnimationController.reverse();
    super.handleThumbPressEnd(localPosition, velocity);
    switch (direction) {
      case Axis.vertical:
        if (velocity.pixelsPerSecond.dy.abs() < 10 &&
            (localPosition.dy - _pressStartAxisPosition).abs() > 0) {
          HapticFeedback.mediumImpact();
        }
      case Axis.horizontal:
        if (velocity.pixelsPerSecond.dx.abs() < 10 &&
            (localPosition.dx - _pressStartAxisPosition).abs() > 0) {
          HapticFeedback.mediumImpact();
        }
    }
  }

  @override
  void dispose() {
    _thicknessAnimationController.dispose();
    super.dispose();
  }
}
