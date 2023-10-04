import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'basic.dart';
import 'framework.dart';
import 'notification_listener.dart';
import 'page_storage.dart';
import 'scroll_activity.dart';
import 'scroll_context.dart';
import 'scroll_metrics.dart';
import 'scroll_notification.dart';
import 'scroll_physics.dart';

export 'scroll_activity.dart' show ScrollHoldController;

enum ScrollPositionAlignmentPolicy {
  explicit,

  keepVisibleAtEnd,

  keepVisibleAtStart,
}

abstract class ScrollPosition extends ViewportOffset with ScrollMetrics {
  ScrollPosition({
    required this.physics,
    required this.context,
    this.keepScrollOffset = true,
    ScrollPosition? oldPosition,
    this.debugLabel,
  }) {
    if (oldPosition != null) {
      absorb(oldPosition);
    }
    if (keepScrollOffset) {
      restoreScrollOffset();
    }
  }

  final ScrollPhysics physics;

  final ScrollContext context;

  // TODO(goderbauer): Deprecate this when state restoration supports all features of PageStorage.
  final bool keepScrollOffset;

  final String? debugLabel;

  @override
  double get minScrollExtent => _minScrollExtent!;
  double? _minScrollExtent;

  @override
  double get maxScrollExtent => _maxScrollExtent!;
  double? _maxScrollExtent;

  @override
  bool get hasContentDimensions =>
      _minScrollExtent != null && _maxScrollExtent != null;

  double _impliedVelocity = 0;

  @override
  double get pixels => _pixels!;
  double? _pixels;

  @override
  bool get hasPixels => _pixels != null;

  @override
  double get viewportDimension => _viewportDimension!;
  double? _viewportDimension;

  @override
  bool get hasViewportDimension => _viewportDimension != null;

  bool get haveDimensions => _haveDimensions;
  bool _haveDimensions = false;

  @protected
  @mustCallSuper
  void absorb(ScrollPosition other) {
    assert(other.context == context);
    assert(_pixels == null);
    if (other.hasContentDimensions) {
      _minScrollExtent = other.minScrollExtent;
      _maxScrollExtent = other.maxScrollExtent;
    }
    if (other.hasPixels) {
      _pixels = other.pixels;
    }
    if (other.hasViewportDimension) {
      _viewportDimension = other.viewportDimension;
    }

    assert(activity == null);
    assert(other.activity != null);
    _activity = other.activity;
    other._activity = null;
    if (other.runtimeType != runtimeType) {
      activity!.resetActivity();
    }
    context.setIgnorePointer(activity!.shouldIgnorePointer);
    isScrollingNotifier.value = activity!.isScrolling;
  }

  @override
  double get devicePixelRatio => context.devicePixelRatio;

  double setPixels(double newPixels) {
    assert(hasPixels);
    assert(
        SchedulerBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks,
        "A scrollable's position should not change during the build, layout, and paint phases, otherwise the rendering will be confused.");
    if (newPixels != pixels) {
      final double overscroll = applyBoundaryConditions(newPixels);
      assert(() {
        final double delta = newPixels - pixels;
        if (overscroll.abs() > delta.abs()) {
          throw FlutterError(
            '$runtimeType.applyBoundaryConditions returned invalid overscroll value.\n'
            'setPixels() was called to change the scroll offset from $pixels to $newPixels.\n'
            'That is a delta of $delta units.\n'
            '$runtimeType.applyBoundaryConditions reported an overscroll of $overscroll units.',
          );
        }
        return true;
      }());
      final double oldPixels = pixels;
      _pixels = newPixels - overscroll;
      if (_pixels != oldPixels) {
        notifyListeners();
        didUpdateScrollPositionBy(pixels - oldPixels);
      }
      if (overscroll.abs() > precisionErrorTolerance) {
        didOverscrollBy(overscroll);
        return overscroll;
      }
    }
    return 0.0;
  }

  // ignore: use_setters_to_change_properties, (API is intended to discourage setting value)
  void correctPixels(double value) {
    _pixels = value;
  }

  @override
  void correctBy(double correction) {
    assert(
      hasPixels,
      'An initial pixels value must exist by calling correctPixels on the ScrollPosition',
    );
    _pixels = _pixels! + correction;
    _didChangeViewportDimensionOrReceiveCorrection = true;
  }

  @protected
  void forcePixels(double value) {
    assert(hasPixels);
    _impliedVelocity = value - pixels;
    _pixels = value;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      _impliedVelocity = 0;
    });
  }

  // TODO(goderbauer): Deprecate this when state restoration supports all features of PageStorage.
  @protected
  void saveScrollOffset() {
    PageStorage.maybeOf(context.storageContext)
        ?.writeState(context.storageContext, pixels);
  }

  // TODO(goderbauer): Deprecate this when state restoration supports all features of PageStorage.
  @protected
  void restoreScrollOffset() {
    if (!hasPixels) {
      final double? value = PageStorage.maybeOf(context.storageContext)
          ?.readState(context.storageContext) as double?;
      if (value != null) {
        correctPixels(value);
      }
    }
  }

  void restoreOffset(double offset, {bool initialRestore = false}) {
    if (initialRestore) {
      correctPixels(offset);
    } else {
      jumpTo(offset);
    }
  }

  @protected
  void saveOffset() {
    assert(hasPixels);
    context.saveOffset(pixels);
  }

  @protected
  double applyBoundaryConditions(double value) {
    final double result = physics.applyBoundaryConditions(this, value);
    assert(() {
      final double delta = value - pixels;
      if (result.abs() > delta.abs()) {
        throw FlutterError(
          '${physics.runtimeType}.applyBoundaryConditions returned invalid overscroll value.\n'
          'The method was called to consider a change from $pixels to $value, which is a '
          'delta of ${delta.toStringAsFixed(1)} units. However, it returned an overscroll of '
          '${result.toStringAsFixed(1)} units, which has a greater magnitude than the delta. '
          'The applyBoundaryConditions method is only supposed to reduce the possible range '
          'of movement, not increase it.\n'
          'The scroll extents are $minScrollExtent .. $maxScrollExtent, and the '
          'viewport dimension is $viewportDimension.',
        );
      }
      return true;
    }());
    return result;
  }

  bool _didChangeViewportDimensionOrReceiveCorrection = true;

  @override
  bool applyViewportDimension(double viewportDimension) {
    if (_viewportDimension != viewportDimension) {
      _viewportDimension = viewportDimension;
      _didChangeViewportDimensionOrReceiveCorrection = true;
      // If this is called, you can rely on applyContentDimensions being called
      // soon afterwards in the same layout phase. So we put all the logic that
      // relies on both values being computed into applyContentDimensions.
    }
    return true;
  }

  bool _pendingDimensions = false;
  ScrollMetrics? _lastMetrics;
  // True indicates that there is a ScrollMetrics update notification pending.
  bool _haveScheduledUpdateNotification = false;
  Axis? _lastAxis;

  bool _isMetricsChanged() {
    assert(haveDimensions);
    final ScrollMetrics currentMetrics = copyWith();

    return _lastMetrics == null ||
        !(currentMetrics.extentBefore == _lastMetrics!.extentBefore &&
            currentMetrics.extentInside == _lastMetrics!.extentInside &&
            currentMetrics.extentAfter == _lastMetrics!.extentAfter &&
            currentMetrics.axisDirection == _lastMetrics!.axisDirection);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    assert(haveDimensions == (_lastMetrics != null));
    if (!nearEqual(_minScrollExtent, minScrollExtent,
            Tolerance.defaultTolerance.distance) ||
        !nearEqual(_maxScrollExtent, maxScrollExtent,
            Tolerance.defaultTolerance.distance) ||
        _didChangeViewportDimensionOrReceiveCorrection ||
        _lastAxis != axis) {
      assert(minScrollExtent <= maxScrollExtent);
      _minScrollExtent = minScrollExtent;
      _maxScrollExtent = maxScrollExtent;
      _lastAxis = axis;
      final ScrollMetrics? currentMetrics = haveDimensions ? copyWith() : null;
      _didChangeViewportDimensionOrReceiveCorrection = false;
      _pendingDimensions = true;
      if (haveDimensions &&
          !correctForNewDimensions(_lastMetrics!, currentMetrics!)) {
        return false;
      }
      _haveDimensions = true;
    }
    assert(haveDimensions);
    if (_pendingDimensions) {
      applyNewDimensions();
      _pendingDimensions = false;
    }
    assert(!_didChangeViewportDimensionOrReceiveCorrection,
        'Use correctForNewDimensions() (and return true) to change the scroll offset during applyContentDimensions().');

    if (_isMetricsChanged()) {
      // It is too late to send useful notifications, because the potential
      // listeners have, by definition, already been built this frame. To make
      // sure the notification is sent at all, we delay it until after the frame
      // is complete.
      if (!_haveScheduledUpdateNotification) {
        scheduleMicrotask(didUpdateScrollMetrics);
        _haveScheduledUpdateNotification = true;
      }
      _lastMetrics = copyWith();
    }
    return true;
  }

  @protected
  bool correctForNewDimensions(
      ScrollMetrics oldPosition, ScrollMetrics newPosition) {
    final double newPixels = physics.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: activity!.isScrolling,
      velocity: activity!.velocity,
    );
    if (newPixels != pixels) {
      correctPixels(newPixels);
      return false;
    }
    return true;
  }

  @protected
  @mustCallSuper
  void applyNewDimensions() {
    assert(hasPixels);
    assert(_pendingDimensions);
    activity!.applyNewDimensions();
    _updateSemanticActions(); // will potentially request a semantics update.
  }

  Set<SemanticsAction>? _semanticActions;

  void _updateSemanticActions() {
    final SemanticsAction forward;
    final SemanticsAction backward;
    switch (axisDirection) {
      case AxisDirection.up:
        forward = SemanticsAction.scrollDown;
        backward = SemanticsAction.scrollUp;
      case AxisDirection.right:
        forward = SemanticsAction.scrollLeft;
        backward = SemanticsAction.scrollRight;
      case AxisDirection.down:
        forward = SemanticsAction.scrollUp;
        backward = SemanticsAction.scrollDown;
      case AxisDirection.left:
        forward = SemanticsAction.scrollRight;
        backward = SemanticsAction.scrollLeft;
    }

    final Set<SemanticsAction> actions = <SemanticsAction>{};
    if (pixels > minScrollExtent) {
      actions.add(backward);
    }
    if (pixels < maxScrollExtent) {
      actions.add(forward);
    }

    if (setEquals<SemanticsAction>(actions, _semanticActions)) {
      return;
    }

    _semanticActions = actions;
    context.setSemanticsActions(_semanticActions!);
  }

  ScrollPositionAlignmentPolicy _maybeFlipAlignment(
      ScrollPositionAlignmentPolicy alignmentPolicy) {
    return switch (alignmentPolicy) {
      // Don't flip when explicit.
      ScrollPositionAlignmentPolicy.explicit => alignmentPolicy,
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd =>
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart =>
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    };
  }

  ScrollPositionAlignmentPolicy _applyAxisDirectionToAlignmentPolicy(
      ScrollPositionAlignmentPolicy alignmentPolicy) {
    return switch (axisDirection) {
      // Start and end alignments must account for axis direction.
      // When focus is requested for example, it knows the directionality of the
      // keyboard keys initiating traversal, but not the direction of the
      // Scrollable.
      AxisDirection.up ||
      AxisDirection.left =>
        _maybeFlipAlignment(alignmentPolicy),
      AxisDirection.down || AxisDirection.right => alignmentPolicy,
    };
  }

  Future<void> ensureVisible(
    RenderObject object, {
    double alignment = 0.0,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
    ScrollPositionAlignmentPolicy alignmentPolicy =
        ScrollPositionAlignmentPolicy.explicit,
    RenderObject? targetRenderObject,
  }) {
    assert(object.attached);
    final RenderAbstractViewport viewport = RenderAbstractViewport.of(object);

    Rect? targetRect;
    if (targetRenderObject != null && targetRenderObject != object) {
      targetRect = MatrixUtils.transformRect(
        targetRenderObject.getTransformTo(object),
        object.paintBounds.intersect(targetRenderObject.paintBounds),
      );
    }

    double target;
    switch (_applyAxisDirectionToAlignmentPolicy(alignmentPolicy)) {
      case ScrollPositionAlignmentPolicy.explicit:
        target = clampDouble(
            viewport
                .getOffsetToReveal(object, alignment, rect: targetRect)
                .offset,
            minScrollExtent,
            maxScrollExtent);
      case ScrollPositionAlignmentPolicy.keepVisibleAtEnd:
        target = clampDouble(
            viewport.getOffsetToReveal(object, 1.0, rect: targetRect).offset,
            minScrollExtent,
            maxScrollExtent);
        if (target < pixels) {
          target = pixels;
        }
      case ScrollPositionAlignmentPolicy.keepVisibleAtStart:
        target = clampDouble(
            viewport.getOffsetToReveal(object, 0.0, rect: targetRect).offset,
            minScrollExtent,
            maxScrollExtent);
        if (target > pixels) {
          target = pixels;
        }
    }

    if (target == pixels) {
      return Future<void>.value();
    }

    if (duration == Duration.zero) {
      jumpTo(target);
      return Future<void>.value();
    }

    return animateTo(target, duration: duration, curve: curve);
  }

  final ValueNotifier<bool> isScrollingNotifier = ValueNotifier<bool>(false);

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  });

  @override
  void jumpTo(double value);

  void pointerScroll(double delta);

  @override
  Future<void> moveTo(
    double to, {
    Duration? duration,
    Curve? curve,
    bool? clamp = true,
  }) {
    assert(clamp != null);

    if (clamp!) {
      to = clampDouble(to, minScrollExtent, maxScrollExtent);
    }

    return super.moveTo(to, duration: duration, curve: curve);
  }

  @override
  bool get allowImplicitScrolling => physics.allowImplicitScrolling;

  @Deprecated(
      'This will lead to bugs.') // flutter_ignore: deprecation_syntax, https://github.com/flutter/flutter/issues/44609
  void jumpToWithoutSettling(double value);

  ScrollHoldController hold(VoidCallback holdCancelCallback);

  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback);

  @protected
  @visibleForTesting
  ScrollActivity? get activity => _activity;
  ScrollActivity? _activity;

  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity == null) {
      return;
    }
    bool wasScrolling, oldIgnorePointer;
    if (_activity != null) {
      oldIgnorePointer = _activity!.shouldIgnorePointer;
      wasScrolling = _activity!.isScrolling;
      if (wasScrolling && !newActivity.isScrolling) {
        // Notifies and then saves the scroll offset.
        didEndScroll();
      }
      _activity!.dispose();
    } else {
      oldIgnorePointer = false;
      wasScrolling = false;
    }
    _activity = newActivity;
    if (oldIgnorePointer != activity!.shouldIgnorePointer) {
      context.setIgnorePointer(activity!.shouldIgnorePointer);
    }
    isScrollingNotifier.value = activity!.isScrolling;
    if (!wasScrolling && _activity!.isScrolling) {
      didStartScroll();
    }
  }

  // NOTIFICATION DISPATCH

  void didStartScroll() {
    activity!.dispatchScrollStartNotification(
        copyWith(), context.notificationContext);
  }

  void didUpdateScrollPositionBy(double delta) {
    activity!.dispatchScrollUpdateNotification(
        copyWith(), context.notificationContext!, delta);
  }

  void didEndScroll() {
    activity!.dispatchScrollEndNotification(
        copyWith(), context.notificationContext!);
    saveOffset();
    if (keepScrollOffset) {
      saveScrollOffset();
    }
  }

  void didOverscrollBy(double value) {
    assert(activity!.isScrolling);
    activity!.dispatchOverscrollNotification(
        copyWith(), context.notificationContext!, value);
  }

  void didUpdateScrollDirection(ScrollDirection direction) {
    UserScrollNotification(
            metrics: copyWith(),
            context: context.notificationContext!,
            direction: direction)
        .dispatch(context.notificationContext);
  }

  void didUpdateScrollMetrics() {
    assert(SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks);
    assert(_haveScheduledUpdateNotification);
    _haveScheduledUpdateNotification = false;
    if (context.notificationContext != null) {
      ScrollMetricsNotification(
              metrics: copyWith(), context: context.notificationContext!)
          .dispatch(context.notificationContext);
    }
  }

  bool recommendDeferredLoading(BuildContext context) {
    assert(activity != null);
    return physics.recommendDeferredLoading(
      activity!.velocity + _impliedVelocity,
      copyWith(),
      context,
    );
  }

  @override
  void dispose() {
    activity
        ?.dispose(); // it will be null if it got absorbed by another ScrollPosition
    _activity = null;
    isScrollingNotifier.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    _updateSemanticActions(); // will potentially request a semantics update.
    super.notifyListeners();
  }

  @override
  void debugFillDescription(List<String> description) {
    if (debugLabel != null) {
      description.add(debugLabel!);
    }
    super.debugFillDescription(description);
    description.add(
        'range: ${_minScrollExtent?.toStringAsFixed(1)}..${_maxScrollExtent?.toStringAsFixed(1)}');
    description.add('viewport: ${_viewportDimension?.toStringAsFixed(1)}');
  }
}

class ScrollMetricsNotification extends Notification
    with ViewportNotificationMixin {
  ScrollMetricsNotification({
    required this.metrics,
    required this.context,
  });

  final ScrollMetrics metrics;

  final BuildContext context;

  ScrollUpdateNotification asScrollUpdate() {
    return ScrollUpdateNotification(
      metrics: metrics,
      context: context,
      depth: depth,
    );
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$metrics');
  }
}
