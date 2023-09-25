// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart' show Tolerance, nearEqual;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'basic.dart';
import 'framework.dart';
import 'media_query.dart';
import 'notification_listener.dart';
import 'scroll_notification.dart';
import 'ticker_provider.dart';
import 'transitions.dart';

class GlowingOverscrollIndicator extends StatefulWidget {
  const GlowingOverscrollIndicator({
    super.key,
    this.showLeading = true,
    this.showTrailing = true,
    required this.axisDirection,
    required this.color,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.child,
  });

  final bool showLeading;

  final bool showTrailing;

  final AxisDirection axisDirection;

  Axis get axis => axisDirectionToAxis(axisDirection);

  final Color color;

  final ScrollNotificationPredicate notificationPredicate;

  final Widget? child;

  @override
  State<GlowingOverscrollIndicator> createState() => _GlowingOverscrollIndicatorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', axisDirection));
    final String showDescription;
    if (showLeading && showTrailing) {
      showDescription = 'both sides';
    } else if (showLeading) {
      showDescription = 'leading side only';
    } else if (showTrailing) {
      showDescription = 'trailing side only';
    } else {
      showDescription = 'neither side (!)';
    }
    properties.add(MessageProperty('show', showDescription));
    properties.add(ColorProperty('color', color, showName: false));
  }
}

class _GlowingOverscrollIndicatorState extends State<GlowingOverscrollIndicator> with TickerProviderStateMixin {
  _GlowController? _leadingController;
  _GlowController? _trailingController;
  Listenable? _leadingAndTrailingListener;

  @override
  void initState() {
    super.initState();
    _leadingController = _GlowController(vsync: this, color: widget.color, axis: widget.axis);
    _trailingController = _GlowController(vsync: this, color: widget.color, axis: widget.axis);
    _leadingAndTrailingListener = Listenable.merge(<Listenable>[_leadingController!, _trailingController!]);
  }

  @override
  void didUpdateWidget(GlowingOverscrollIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color || oldWidget.axis != widget.axis) {
      _leadingController!.color = widget.color;
      _leadingController!.axis = widget.axis;
      _trailingController!.color = widget.color;
      _trailingController!.axis = widget.axis;
    }
  }

  Type? _lastNotificationType;
  final Map<bool, bool> _accepted = <bool, bool>{false: true, true: true};

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }
    if (notification.metrics.axis != widget.axis) {
      // This widget is explicitly configured to one axis. If a notification
      // from a different axis bubbles up, do nothing.
      return false;
    }

    // Update the paint offset with the current scroll position. This makes
    // sure that the glow effect correctly scrolls in line with the current
    // scroll, e.g. when scrolling in the opposite direction again to hide
    // the glow. Otherwise, the glow would always stay in a fixed position,
    // even if the top of the content already scrolled away.
    // For example (CustomScrollView with sliver before center), the scroll
    // extent is [-200.0, 300.0], scroll in the opposite direction with 10.0 pixels
    // before glow disappears, so the current pixels is -190.0,
    // in this case, we should move the glow up 10.0 pixels and should not
    // overflow the scrollable widget's edge. https://github.com/flutter/flutter/issues/64149.
    _leadingController!._paintOffsetScrollPixels =
      -math.min(notification.metrics.pixels - notification.metrics.minScrollExtent, _leadingController!._paintOffset);
    _trailingController!._paintOffsetScrollPixels =
      -math.min(notification.metrics.maxScrollExtent - notification.metrics.pixels, _trailingController!._paintOffset);

    if (notification is OverscrollNotification) {
      _GlowController? controller;
      if (notification.overscroll < 0.0) {
        controller = _leadingController;
      } else if (notification.overscroll > 0.0) {
        controller = _trailingController;
      } else {
        assert(false);
      }
      final bool isLeading = controller == _leadingController;
      if (_lastNotificationType is! OverscrollNotification) {
        final OverscrollIndicatorNotification confirmationNotification = OverscrollIndicatorNotification(leading: isLeading);
        confirmationNotification.dispatch(context);
        _accepted[isLeading] = confirmationNotification.accepted;
        if (_accepted[isLeading]!) {
          controller!._paintOffset = confirmationNotification.paintOffset;
        }
      }
      assert(controller != null);
      if (_accepted[isLeading]!) {
        if (notification.velocity != 0.0) {
          assert(notification.dragDetails == null);
          controller!.absorbImpact(notification.velocity.abs());
        } else {
          assert(notification.overscroll != 0.0);
          if (notification.dragDetails != null) {
            final RenderBox renderer = notification.context!.findRenderObject()! as RenderBox;
            assert(renderer.hasSize);
            final Size size = renderer.size;
            final Offset position = renderer.globalToLocal(notification.dragDetails!.globalPosition);
            switch (notification.metrics.axis) {
              case Axis.horizontal:
                controller!.pull(notification.overscroll.abs(), size.width, clampDouble(position.dy, 0.0, size.height), size.height);
              case Axis.vertical:
                controller!.pull(notification.overscroll.abs(), size.height, clampDouble(position.dx, 0.0, size.width), size.width);
            }
          }
        }
      }
    } else if ((notification is ScrollEndNotification && notification.dragDetails != null) ||
               (notification is ScrollUpdateNotification && notification.dragDetails != null)) {
      _leadingController!.scrollEnd();
      _trailingController!.scrollEnd();
    }
    _lastNotificationType = notification.runtimeType;
    return false;
  }

  @override
  void dispose() {
    _leadingController!.dispose();
    _trailingController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: _GlowingOverscrollIndicatorPainter(
            leadingController: widget.showLeading ? _leadingController : null,
            trailingController: widget.showTrailing ? _trailingController : null,
            axisDirection: widget.axisDirection,
            repaint: _leadingAndTrailingListener,
          ),
          child: RepaintBoundary(
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// The Glow logic is a port of the logic in the following file:
// https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/widget/EdgeEffect.java
// as of December 2016.

enum _GlowState { idle, absorb, pull, recede }

class _GlowController extends ChangeNotifier {
  _GlowController({
    required TickerProvider vsync,
    required Color color,
    required Axis axis,
  }) : _color = color,
       _axis = axis {
    _glowController = AnimationController(vsync: vsync)
      ..addStatusListener(_changePhase);
    final Animation<double> decelerator = CurvedAnimation(
      parent: _glowController,
      curve: Curves.decelerate,
    )..addListener(notifyListeners);
    _glowOpacity = decelerator.drive(_glowOpacityTween);
    _glowSize = decelerator.drive(_glowSizeTween);
    _displacementTicker = vsync.createTicker(_tickDisplacement);
  }

  // animation of the main axis direction
  _GlowState _state = _GlowState.idle;
  late final AnimationController _glowController;
  Timer? _pullRecedeTimer;
  double _paintOffset = 0.0;
  double _paintOffsetScrollPixels = 0.0;

  // animation values
  final Tween<double> _glowOpacityTween = Tween<double>(begin: 0.0, end: 0.0);
  late final Animation<double> _glowOpacity;
  final Tween<double> _glowSizeTween = Tween<double>(begin: 0.0, end: 0.0);
  late final Animation<double> _glowSize;

  // animation of the cross axis position
  late final Ticker _displacementTicker;
  Duration? _displacementTickerLastElapsed;
  double _displacementTarget = 0.5;
  double _displacement = 0.5;

  // tracking the pull distance
  double _pullDistance = 0.0;

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (color == value) {
      return;
    }
    _color = value;
    notifyListeners();
  }

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    if (axis == value) {
      return;
    }
    _axis = value;
    notifyListeners();
  }

  static const Duration _recedeTime = Duration(milliseconds: 600);
  static const Duration _pullTime = Duration(milliseconds: 167);
  static const Duration _pullHoldTime = Duration(milliseconds: 167);
  static const Duration _pullDecayTime = Duration(milliseconds: 2000);
  static final Duration _crossAxisHalfTime = Duration(microseconds: (Duration.microsecondsPerSecond / 60.0).round());

  static const double _maxOpacity = 0.5;
  static const double _pullOpacityGlowFactor = 0.8;
  static const double _velocityGlowFactor = 0.00006;
  static const double _sqrt3 = 1.73205080757; // const math.sqrt(3)
  static const double _widthToHeightFactor = (3.0 / 4.0) * (2.0 - _sqrt3);

  // absorbed velocities are clamped to the range _minVelocity.._maxVelocity
  static const double _minVelocity = 100.0; // logical pixels per second
  static const double _maxVelocity = 10000.0; // logical pixels per second

  @override
  void dispose() {
    _glowController.dispose();
    _displacementTicker.dispose();
    _pullRecedeTimer?.cancel();
    super.dispose();
  }

  void absorbImpact(double velocity) {
    assert(velocity >= 0.0);
    _pullRecedeTimer?.cancel();
    _pullRecedeTimer = null;
    velocity = clampDouble(velocity, _minVelocity, _maxVelocity);
    _glowOpacityTween.begin = _state == _GlowState.idle ? 0.3 : _glowOpacity.value;
    _glowOpacityTween.end = clampDouble(velocity * _velocityGlowFactor, _glowOpacityTween.begin!, _maxOpacity);
    _glowSizeTween.begin = _glowSize.value;
    _glowSizeTween.end = math.min(0.025 + 7.5e-7 * velocity * velocity, 1.0);
    _glowController.duration = Duration(milliseconds: (0.15 + velocity * 0.02).round());
    _glowController.forward(from: 0.0);
    _displacement = 0.5;
    _state = _GlowState.absorb;
  }

  void pull(double overscroll, double extent, double crossAxisOffset, double crossExtent) {
    _pullRecedeTimer?.cancel();
    _pullDistance += overscroll / 200.0; // This factor is magic. Not clear why we need it to match Android.
    _glowOpacityTween.begin = _glowOpacity.value;
    _glowOpacityTween.end = math.min(_glowOpacity.value + overscroll / extent * _pullOpacityGlowFactor, _maxOpacity);
    final double height = math.min(extent, crossExtent * _widthToHeightFactor);
    _glowSizeTween.begin = _glowSize.value;
    _glowSizeTween.end = math.max(1.0 - 1.0 / (0.7 * math.sqrt(_pullDistance * height)), _glowSize.value);
    _displacementTarget = crossAxisOffset / crossExtent;
    if (_displacementTarget != _displacement) {
      if (!_displacementTicker.isTicking) {
        assert(_displacementTickerLastElapsed == null);
        _displacementTicker.start();
      }
    } else {
      _displacementTicker.stop();
      _displacementTickerLastElapsed = null;
    }
    _glowController.duration = _pullTime;
    if (_state != _GlowState.pull) {
      _glowController.forward(from: 0.0);
      _state = _GlowState.pull;
    } else {
      if (!_glowController.isAnimating) {
        assert(_glowController.value == 1.0);
        notifyListeners();
      }
    }
    _pullRecedeTimer = Timer(_pullHoldTime, () => _recede(_pullDecayTime));
  }

  void scrollEnd() {
    if (_state == _GlowState.pull) {
      _recede(_recedeTime);
    }
  }

  void _changePhase(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    switch (_state) {
      case _GlowState.absorb:
        _recede(_recedeTime);
      case _GlowState.recede:
        _state = _GlowState.idle;
        _pullDistance = 0.0;
      case _GlowState.pull:
      case _GlowState.idle:
        break;
    }
  }

  void _recede(Duration duration) {
    if (_state == _GlowState.recede || _state == _GlowState.idle) {
      return;
    }
    _pullRecedeTimer?.cancel();
    _pullRecedeTimer = null;
    _glowOpacityTween.begin = _glowOpacity.value;
    _glowOpacityTween.end = 0.0;
    _glowSizeTween.begin = _glowSize.value;
    _glowSizeTween.end = 0.0;
    _glowController.duration = duration;
    _glowController.forward(from: 0.0);
    _state = _GlowState.recede;
  }

  void _tickDisplacement(Duration elapsed) {
    if (_displacementTickerLastElapsed != null) {
      final double t = (elapsed.inMicroseconds - _displacementTickerLastElapsed!.inMicroseconds).toDouble();
      _displacement = _displacementTarget - (_displacementTarget - _displacement) * math.pow(2.0, -t / _crossAxisHalfTime.inMicroseconds);
      notifyListeners();
    }
    if (nearEqual(_displacementTarget, _displacement, Tolerance.defaultTolerance.distance)) {
      _displacementTicker.stop();
      _displacementTickerLastElapsed = null;
    } else {
      _displacementTickerLastElapsed = elapsed;
    }
  }

  void paint(Canvas canvas, Size size) {
    if (_glowOpacity.value == 0.0) {
      return;
    }
    final double baseGlowScale = size.width > size.height ? size.height / size.width : 1.0;
    final double radius = size.width * 3.0 / 2.0;
    final double height = math.min(size.height, size.width * _widthToHeightFactor);
    final double scaleY = _glowSize.value * baseGlowScale;
    final Rect rect = Rect.fromLTWH(0.0, 0.0, size.width, height);
    final Offset center = Offset((size.width / 2.0) * (0.5 + _displacement), height - radius);
    final Paint paint = Paint()..color = color.withOpacity(_glowOpacity.value);
    canvas.save();
    canvas.translate(0.0, _paintOffset + _paintOffsetScrollPixels);
    canvas.scale(1.0, scaleY);
    canvas.clipRect(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }

  @override
  String toString() {
    return '_GlowController(color: $color, axis: ${axis.name})';
  }
}

class _GlowingOverscrollIndicatorPainter extends CustomPainter {
  _GlowingOverscrollIndicatorPainter({
    this.leadingController,
    this.trailingController,
    required this.axisDirection,
    super.repaint,
  });

  final _GlowController? leadingController;

  final _GlowController? trailingController;

  final AxisDirection axisDirection;

  static const double piOver2 = math.pi / 2.0;

  void _paintSide(Canvas canvas, Size size, _GlowController? controller, AxisDirection axisDirection, GrowthDirection growthDirection) {
    if (controller == null) {
      return;
    }
    switch (applyGrowthDirectionToAxisDirection(axisDirection, growthDirection)) {
      case AxisDirection.up:
        controller.paint(canvas, size);
      case AxisDirection.down:
        canvas.save();
        canvas.translate(0.0, size.height);
        canvas.scale(1.0, -1.0);
        controller.paint(canvas, size);
        canvas.restore();
      case AxisDirection.left:
        canvas.save();
        canvas.rotate(piOver2);
        canvas.scale(1.0, -1.0);
        controller.paint(canvas, Size(size.height, size.width));
        canvas.restore();
      case AxisDirection.right:
        canvas.save();
        canvas.translate(size.width, 0.0);
        canvas.rotate(piOver2);
        controller.paint(canvas, Size(size.height, size.width));
        canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintSide(canvas, size, leadingController, axisDirection, GrowthDirection.reverse);
    _paintSide(canvas, size, trailingController, axisDirection, GrowthDirection.forward);
  }

  @override
  bool shouldRepaint(_GlowingOverscrollIndicatorPainter oldDelegate) {
    return oldDelegate.leadingController != leadingController
        || oldDelegate.trailingController != trailingController;
  }

  @override
  String toString() {
    return '_GlowingOverscrollIndicatorPainter($leadingController, $trailingController)';
  }
}

enum _StretchDirection {
  trailing,
  leading,
}

class StretchingOverscrollIndicator extends StatefulWidget {
  const StretchingOverscrollIndicator({
    super.key,
    required this.axisDirection,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.clipBehavior = Clip.hardEdge,
    this.child,
  });

  final AxisDirection axisDirection;

  Axis get axis => axisDirectionToAxis(axisDirection);

  final ScrollNotificationPredicate notificationPredicate;

  final Clip clipBehavior;

  final Widget? child;

  @override
  State<StretchingOverscrollIndicator> createState() => _StretchingOverscrollIndicatorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', axisDirection));
  }
}

class _StretchingOverscrollIndicatorState extends State<StretchingOverscrollIndicator> with TickerProviderStateMixin {
  late final _StretchController _stretchController = _StretchController(vsync: this);
  ScrollNotification? _lastNotification;
  OverscrollNotification? _lastOverscrollNotification;

  double _totalOverscroll = 0.0;

  bool _accepted = true;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }
    if (notification.metrics.axis != widget.axis) {
      // This widget is explicitly configured to one axis. If a notification
      // from a different axis bubbles up, do nothing.
      return false;
    }

    if (notification is OverscrollNotification) {
      _lastOverscrollNotification = notification;
      if (_lastNotification.runtimeType is! OverscrollNotification) {
        final OverscrollIndicatorNotification confirmationNotification = OverscrollIndicatorNotification(leading: notification.overscroll < 0.0);
        confirmationNotification.dispatch(context);
        _accepted = confirmationNotification.accepted;
      }

      if (_accepted) {
        _totalOverscroll += notification.overscroll;

        if (notification.velocity != 0.0) {
          assert(notification.dragDetails == null);
          _stretchController.absorbImpact(notification.velocity.abs(), _totalOverscroll);
        } else {
          assert(notification.overscroll != 0.0);
          if (notification.dragDetails != null) {
            // We clamp the overscroll amount relative to the length of the viewport,
            // which is the furthest distance a single pointer could pull on the
            // screen. This is because more than one pointer will multiply the
            // amount of overscroll - https://github.com/flutter/flutter/issues/11884

            final double viewportDimension = notification.metrics.viewportDimension;
            final double distanceForPull = _totalOverscroll.abs() / viewportDimension;
            final double clampedOverscroll = clampDouble(distanceForPull, 0, 1.0);
            _stretchController.pull(clampedOverscroll, _totalOverscroll);
          }
        }
      }
    } else if (notification is ScrollEndNotification || notification is ScrollUpdateNotification) {
      // Since the overscrolling ended, we reset the total overscroll amount.
      _totalOverscroll = 0;
      _stretchController.scrollEnd();
    }
    _lastNotification = notification;
    return false;
  }

  AlignmentGeometry _getAlignmentForAxisDirection(_StretchDirection stretchDirection) {
    // Accounts for reversed scrollables by checking the AxisDirection
    switch (widget.axisDirection) {
      case AxisDirection.up:
        return stretchDirection == _StretchDirection.trailing
            ? AlignmentDirectional.topCenter
            : AlignmentDirectional.bottomCenter;
      case AxisDirection.right:
        return stretchDirection == _StretchDirection.trailing
            ? Alignment.centerRight
            : Alignment.centerLeft;
      case AxisDirection.down:
        return stretchDirection == _StretchDirection.trailing
            ? AlignmentDirectional.bottomCenter
            : AlignmentDirectional.topCenter;
      case AxisDirection.left:
        return stretchDirection == _StretchDirection.trailing
            ? Alignment.centerLeft
            : Alignment.centerRight;
    }
  }

  @override
  void dispose() {
    _stretchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    double mainAxisSize;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: AnimatedBuilder(
        animation: _stretchController,
        builder: (BuildContext context, Widget? child) {
          final double stretch = _stretchController.value;
          double x = 1.0;
          double y = 1.0;

          switch (widget.axis) {
            case Axis.horizontal:
              x += stretch;
              mainAxisSize = size.width;
            case Axis.vertical:
              y += stretch;
              mainAxisSize = size.height;
          }

          final AlignmentGeometry alignment = _getAlignmentForAxisDirection(
            _stretchController.stretchDirection,
          );

          final double viewportDimension = _lastOverscrollNotification?.metrics.viewportDimension ?? mainAxisSize;
          final Widget transform = Transform(
            alignment: alignment,
            transform: Matrix4.diagonal3Values(x, y, 1.0),
            filterQuality: stretch == 0 ? null : FilterQuality.low,
            child: widget.child,
          );

          // Only clip if the viewport dimension is smaller than that of the
          // screen size in the main axis. If the viewport takes up the whole
          // screen, overflow from transforming the viewport is irrelevant.
          return ClipRect(
            clipBehavior: stretch != 0.0 && viewportDimension != mainAxisSize
              ? widget.clipBehavior
              : Clip.none,
            child: transform,
          );
        },
      ),
    );
  }
}

enum _StretchState {
  idle,
  absorb,
  pull,
  recede,
}

class _StretchController extends ChangeNotifier {
  _StretchController({ required TickerProvider vsync }) {
    _stretchController = AnimationController(vsync: vsync)
      ..addStatusListener(_changePhase);
    final Animation<double> decelerator = CurvedAnimation(
      parent: _stretchController,
      curve: Curves.decelerate,
    )..addListener(notifyListeners);
    _stretchSize = decelerator.drive(_stretchSizeTween);
  }

  late final AnimationController _stretchController;
  late final Animation<double> _stretchSize;
  final Tween<double> _stretchSizeTween = Tween<double>(begin: 0.0, end: 0.0);
  _StretchState _state = _StretchState.idle;

  double get pullDistance => _pullDistance;
  double _pullDistance = 0.0;

  _StretchDirection get stretchDirection => _stretchDirection;
  _StretchDirection _stretchDirection = _StretchDirection.trailing;

  // Constants from Android.
  static const double _exponentialScalar = math.e / 0.33;
  static const double _stretchIntensity = 0.016;
  static const double _flingFriction = 1.01;
  static const Duration _stretchDuration = Duration(milliseconds: 400);

  double get value => _stretchSize.value;

  void absorbImpact(double velocity, double totalOverscroll) {
    assert(velocity >= 0.0);
    velocity = clampDouble(velocity, 1, 10000);
    _stretchSizeTween.begin = _stretchSize.value;
    _stretchSizeTween.end = math.min(_stretchIntensity + (_flingFriction / velocity), 1.0);
    _stretchController.duration = Duration(milliseconds: (velocity * 0.02).round());
    _stretchController.forward(from: 0.0);
    _state = _StretchState.absorb;
    _stretchDirection = totalOverscroll > 0 ? _StretchDirection.trailing : _StretchDirection.leading;
  }

  void pull(double normalizedOverscroll, double totalOverscroll) {
    assert(normalizedOverscroll >= 0.0);

    final _StretchDirection newStretchDirection = totalOverscroll > 0 ? _StretchDirection.trailing : _StretchDirection.leading;
    if (_stretchDirection != newStretchDirection && _state == _StretchState.recede) {
      // When the stretch direction changes while we are in the recede state, we need to ignore the change.
      // If we don't, the stretch will instantly jump to the new direction with the recede animation still playing, which causes
      // a unwanted visual abnormality (https://github.com/flutter/flutter/pull/116548#issuecomment-1414872567).
      // By ignoring the directional change until the recede state is finished, we can avoid this.
      return;
    }

    _stretchDirection = newStretchDirection;
    _pullDistance = normalizedOverscroll;
    _stretchSizeTween.begin = _stretchSize.value;
    final double linearIntensity =_stretchIntensity * _pullDistance;
    final double exponentialIntensity = _stretchIntensity * (1 - math.exp(-_pullDistance * _exponentialScalar));
    _stretchSizeTween.end = linearIntensity + exponentialIntensity;
    _stretchController.duration = _stretchDuration;
    if (_state != _StretchState.pull) {
      _stretchController.forward(from: 0.0);
      _state = _StretchState.pull;
    } else {
      if (!_stretchController.isAnimating) {
        assert(_stretchController.value == 1.0);
        notifyListeners();
      }
    }
  }

  void scrollEnd() {
    if (_state == _StretchState.pull) {
      _recede(_stretchDuration);
    }
  }

  void _changePhase(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    switch (_state) {
      case _StretchState.absorb:
        _recede(_stretchDuration);
      case _StretchState.recede:
        _state = _StretchState.idle;
        _pullDistance = 0.0;
      case _StretchState.pull:
      case _StretchState.idle:
        break;
    }
  }

  void _recede(Duration duration) {
    if (_state == _StretchState.recede || _state == _StretchState.idle) {
      return;
    }
    _stretchSizeTween.begin = _stretchSize.value;
    _stretchSizeTween.end = 0.0;
    _stretchController.duration = duration;
    _stretchController.forward(from: 0.0);
    _state = _StretchState.recede;
  }

  @override
  void dispose() {
    _stretchController.dispose();
    super.dispose();
  }

  @override
  String toString() => '_StretchController()';
}

class OverscrollIndicatorNotification extends Notification with ViewportNotificationMixin {
  OverscrollIndicatorNotification({
    required this.leading,
  });

  final bool leading;

  double paintOffset = 0.0;

  @protected
  @visibleForTesting
  bool accepted = true;

  void disallowIndicator() {
    accepted = false;
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('side: ${leading ? "leading edge" : "trailing edge"}');
  }
}