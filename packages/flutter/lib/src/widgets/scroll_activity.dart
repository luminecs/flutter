import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'scroll_metrics.dart';
import 'scroll_notification.dart';

abstract class ScrollActivityDelegate {
  AxisDirection get axisDirection;

  double setPixels(double pixels);

  void applyUserOffset(double delta);

  void goIdle();

  void goBallistic(double velocity);
}

abstract class ScrollActivity {
  ScrollActivity(this._delegate);

  ScrollActivityDelegate get delegate => _delegate;
  ScrollActivityDelegate _delegate;

  bool _isDisposed = false;

  void updateDelegate(ScrollActivityDelegate value) {
    assert(_delegate != value);
    _delegate = value;
  }

  void resetActivity() {}

  void dispatchScrollStartNotification(
      ScrollMetrics metrics, BuildContext? context) {
    ScrollStartNotification(metrics: metrics, context: context)
        .dispatch(context);
  }

  void dispatchScrollUpdateNotification(
      ScrollMetrics metrics, BuildContext context, double scrollDelta) {
    ScrollUpdateNotification(
            metrics: metrics, context: context, scrollDelta: scrollDelta)
        .dispatch(context);
  }

  void dispatchOverscrollNotification(
      ScrollMetrics metrics, BuildContext context, double overscroll) {
    OverscrollNotification(
            metrics: metrics, context: context, overscroll: overscroll)
        .dispatch(context);
  }

  void dispatchScrollEndNotification(
      ScrollMetrics metrics, BuildContext context) {
    ScrollEndNotification(metrics: metrics, context: context).dispatch(context);
  }

  void applyNewDimensions() {}

  bool get shouldIgnorePointer;

  bool get isScrolling;

  double get velocity;

  @mustCallSuper
  void dispose() {
    _isDisposed = true;
  }

  @override
  String toString() => describeIdentity(this);
}

class IdleScrollActivity extends ScrollActivity {
  IdleScrollActivity(super.delegate);

  @override
  void applyNewDimensions() {
    delegate.goBallistic(0.0);
  }

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => false;

  @override
  double get velocity => 0.0;
}

abstract class ScrollHoldController {
  void cancel();
}

class HoldScrollActivity extends ScrollActivity
    implements ScrollHoldController {
  HoldScrollActivity({
    required ScrollActivityDelegate delegate,
    this.onHoldCanceled,
  }) : super(delegate);

  final VoidCallback? onHoldCanceled;

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => false;

  @override
  double get velocity => 0.0;

  @override
  void cancel() {
    delegate.goBallistic(0.0);
  }

  @override
  void dispose() {
    onHoldCanceled?.call();
    super.dispose();
  }
}

class ScrollDragController implements Drag {
  ScrollDragController({
    required ScrollActivityDelegate delegate,
    required DragStartDetails details,
    this.onDragCanceled,
    this.carriedVelocity,
    this.motionStartDistanceThreshold,
  })  : assert(
          motionStartDistanceThreshold == null ||
              motionStartDistanceThreshold > 0.0,
          'motionStartDistanceThreshold must be a positive number or null',
        ),
        _delegate = delegate,
        _lastDetails = details,
        _retainMomentum = carriedVelocity != null && carriedVelocity != 0.0,
        _lastNonStationaryTimestamp = details.sourceTimeStamp,
        _kind = details.kind,
        _offsetSinceLastStop =
            motionStartDistanceThreshold == null ? null : 0.0;

  ScrollActivityDelegate get delegate => _delegate;
  ScrollActivityDelegate _delegate;

  final VoidCallback? onDragCanceled;

  final double? carriedVelocity;

  final double? motionStartDistanceThreshold;

  Duration? _lastNonStationaryTimestamp;
  bool _retainMomentum;
  double? _offsetSinceLastStop;

  static const Duration momentumRetainStationaryDurationThreshold =
      Duration(milliseconds: 20);

  static const double momentumRetainVelocityThresholdFactor = 0.5;

  static const Duration motionStoppedDurationThreshold =
      Duration(milliseconds: 50);

  static const double _bigThresholdBreakDistance = 24.0;

  bool get _reversed => axisDirectionIsReversed(delegate.axisDirection);

  void updateDelegate(ScrollActivityDelegate value) {
    assert(_delegate != value);
    _delegate = value;
  }

  void _maybeLoseMomentum(double offset, Duration? timestamp) {
    if (_retainMomentum &&
        offset == 0.0 &&
        (timestamp ==
                null || // If drag event has no timestamp, we lose momentum.
            timestamp - _lastNonStationaryTimestamp! >
                momentumRetainStationaryDurationThreshold)) {
      // If pointer is stationary for too long, we lose momentum.
      _retainMomentum = false;
    }
  }

  double _adjustForScrollStartThreshold(double offset, Duration? timestamp) {
    if (timestamp == null) {
      // If we can't track time, we can't apply thresholds.
      // May be null for proxied drags like via accessibility.
      return offset;
    }
    if (offset == 0.0) {
      if (motionStartDistanceThreshold != null &&
          _offsetSinceLastStop == null &&
          timestamp - _lastNonStationaryTimestamp! >
              motionStoppedDurationThreshold) {
        // Enforce a new threshold.
        _offsetSinceLastStop = 0.0;
      }
      // Not moving can't break threshold.
      return 0.0;
    } else {
      if (_offsetSinceLastStop == null) {
        // Already in motion or no threshold behavior configured such as for
        // Android. Allow transparent offset transmission.
        return offset;
      } else {
        _offsetSinceLastStop = _offsetSinceLastStop! + offset;
        if (_offsetSinceLastStop!.abs() > motionStartDistanceThreshold!) {
          // Threshold broken.
          _offsetSinceLastStop = null;
          if (offset.abs() > _bigThresholdBreakDistance) {
            // This is heuristically a very deliberate fling. Leave the motion
            // unaffected.
            return offset;
          } else {
            // This is a normal speed threshold break.
            return math.min(
                  // Ease into the motion when the threshold is initially broken
                  // to avoid a visible jump.
                  motionStartDistanceThreshold! / 3.0,
                  offset.abs(),
                ) *
                offset.sign;
          }
        } else {
          return 0.0;
        }
      }
    }
  }

  @override
  void update(DragUpdateDetails details) {
    assert(details.primaryDelta != null);
    _lastDetails = details;
    double offset = details.primaryDelta!;
    if (offset != 0.0) {
      _lastNonStationaryTimestamp = details.sourceTimeStamp;
    }
    // By default, iOS platforms carries momentum and has a start threshold
    // (configured in [BouncingScrollPhysics]). The 2 operations below are
    // no-ops on Android.
    _maybeLoseMomentum(offset, details.sourceTimeStamp);
    offset = _adjustForScrollStartThreshold(offset, details.sourceTimeStamp);
    if (offset == 0.0) {
      return;
    }
    if (_reversed) {
      offset = -offset;
    }
    delegate.applyUserOffset(offset);
  }

  @override
  void end(DragEndDetails details) {
    assert(details.primaryVelocity != null);
    // We negate the velocity here because if the touch is moving downwards,
    // the scroll has to move upwards. It's the same reason that update()
    // above negates the delta before applying it to the scroll offset.
    double velocity = -details.primaryVelocity!;
    if (_reversed) {
      velocity = -velocity;
    }
    _lastDetails = details;

    if (_retainMomentum) {
      // Build momentum only if dragging in the same direction.
      final bool isFlingingInSameDirection =
          velocity.sign == carriedVelocity!.sign;
      // Build momentum only if the velocity of the last drag was not
      // substantially lower than the carried momentum.
      final bool isVelocityNotSubstantiallyLessThanCarriedMomentum =
          velocity.abs() >
              carriedVelocity!.abs() * momentumRetainVelocityThresholdFactor;
      if (isFlingingInSameDirection &&
          isVelocityNotSubstantiallyLessThanCarriedMomentum) {
        velocity += carriedVelocity!;
      }
    }
    delegate.goBallistic(velocity);
  }

  @override
  void cancel() {
    delegate.goBallistic(0.0);
  }

  @mustCallSuper
  void dispose() {
    _lastDetails = null;
    onDragCanceled?.call();
  }

  final PointerDeviceKind? _kind;
  dynamic get lastDetails => _lastDetails;
  dynamic _lastDetails;

  @override
  String toString() => describeIdentity(this);
}

class DragScrollActivity extends ScrollActivity {
  DragScrollActivity(
    super.delegate,
    ScrollDragController controller,
  ) : _controller = controller;

  ScrollDragController? _controller;

  @override
  void dispatchScrollStartNotification(
      ScrollMetrics metrics, BuildContext? context) {
    final dynamic lastDetails = _controller!.lastDetails;
    assert(lastDetails is DragStartDetails);
    ScrollStartNotification(
            metrics: metrics,
            context: context,
            dragDetails: lastDetails as DragStartDetails)
        .dispatch(context);
  }

  @override
  void dispatchScrollUpdateNotification(
      ScrollMetrics metrics, BuildContext context, double scrollDelta) {
    final dynamic lastDetails = _controller!.lastDetails;
    assert(lastDetails is DragUpdateDetails);
    ScrollUpdateNotification(
            metrics: metrics,
            context: context,
            scrollDelta: scrollDelta,
            dragDetails: lastDetails as DragUpdateDetails)
        .dispatch(context);
  }

  @override
  void dispatchOverscrollNotification(
      ScrollMetrics metrics, BuildContext context, double overscroll) {
    final dynamic lastDetails = _controller!.lastDetails;
    assert(lastDetails is DragUpdateDetails);
    OverscrollNotification(
            metrics: metrics,
            context: context,
            overscroll: overscroll,
            dragDetails: lastDetails as DragUpdateDetails)
        .dispatch(context);
  }

  @override
  void dispatchScrollEndNotification(
      ScrollMetrics metrics, BuildContext context) {
    // We might not have DragEndDetails yet if we're being called from beginActivity.
    final dynamic lastDetails = _controller!.lastDetails;
    ScrollEndNotification(
      metrics: metrics,
      context: context,
      dragDetails: lastDetails is DragEndDetails ? lastDetails : null,
    ).dispatch(context);
  }

  @override
  bool get shouldIgnorePointer =>
      _controller?._kind != PointerDeviceKind.trackpad;

  @override
  bool get isScrolling => true;

  // DragScrollActivity is not independently changing velocity yet
  // until the drag is ended.
  @override
  double get velocity => 0.0;

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  String toString() {
    return '${describeIdentity(this)}($_controller)';
  }
}

class BallisticScrollActivity extends ScrollActivity {
  BallisticScrollActivity(
    super.delegate,
    Simulation simulation,
    TickerProvider vsync,
    this.shouldIgnorePointer,
  ) {
    _controller = AnimationController.unbounded(
      debugLabel: kDebugMode
          ? objectRuntimeType(this, 'BallisticScrollActivity')
          : null,
      vsync: vsync,
    )
      ..addListener(_tick)
      ..animateWith(simulation).whenComplete(
          _end); // won't trigger if we dispose _controller before it completes.
  }

  late AnimationController _controller;

  @override
  void resetActivity() {
    delegate.goBallistic(velocity);
  }

  @override
  void applyNewDimensions() {
    delegate.goBallistic(velocity);
  }

  void _tick() {
    if (!applyMoveTo(_controller.value)) {
      delegate.goIdle();
    }
  }

  @protected
  bool applyMoveTo(double value) {
    return delegate.setPixels(value).abs() < precisionErrorTolerance;
  }

  void _end() {
    // Check if the activity was disposed before going ballistic because _end might be called
    // if _controller is disposed just after completion.
    if (!_isDisposed) {
      delegate.goBallistic(0.0);
    }
  }

  @override
  void dispatchOverscrollNotification(
      ScrollMetrics metrics, BuildContext context, double overscroll) {
    OverscrollNotification(
            metrics: metrics,
            context: context,
            overscroll: overscroll,
            velocity: velocity)
        .dispatch(context);
  }

  @override
  final bool shouldIgnorePointer;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _controller.velocity;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  String toString() {
    return '${describeIdentity(this)}($_controller)';
  }
}

class DrivenScrollActivity extends ScrollActivity {
  DrivenScrollActivity(
    super.delegate, {
    required double from,
    required double to,
    required Duration duration,
    required Curve curve,
    required TickerProvider vsync,
  }) : assert(duration > Duration.zero) {
    _completer = Completer<void>();
    _controller = AnimationController.unbounded(
      value: from,
      debugLabel: objectRuntimeType(this, 'DrivenScrollActivity'),
      vsync: vsync,
    )
      ..addListener(_tick)
      ..animateTo(to, duration: duration, curve: curve).whenComplete(
          _end); // won't trigger if we dispose _controller before it completes.
  }

  late final Completer<void> _completer;
  late final AnimationController _controller;

  Future<void> get done => _completer.future;

  void _tick() {
    if (delegate.setPixels(_controller.value) != 0.0) {
      delegate.goIdle();
    }
  }

  void _end() {
    // Check if the activity was disposed before going ballistic because _end might be called
    // if _controller is disposed just after completion.
    if (!_isDisposed) {
      delegate.goBallistic(velocity);
    }
  }

  @override
  void dispatchOverscrollNotification(
      ScrollMetrics metrics, BuildContext context, double overscroll) {
    OverscrollNotification(
            metrics: metrics,
            context: context,
            overscroll: overscroll,
            velocity: velocity)
        .dispatch(context);
  }

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _controller.velocity;

  @override
  void dispose() {
    _completer.complete();
    _controller.dispose();
    super.dispose();
  }

  @override
  String toString() {
    return '${describeIdentity(this)}($_controller)';
  }
}
