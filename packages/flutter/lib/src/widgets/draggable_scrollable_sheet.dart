import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'basic.dart';
import 'binding.dart';
import 'framework.dart';
import 'inherited_notifier.dart';
import 'layout_builder.dart';
import 'notification_listener.dart';
import 'scroll_activity.dart';
import 'scroll_context.dart';
import 'scroll_controller.dart';
import 'scroll_notification.dart';
import 'scroll_physics.dart';
import 'scroll_position.dart';
import 'scroll_position_with_single_context.dart';
import 'scroll_simulation.dart';
import 'value_listenable_builder.dart';

typedef ScrollableWidgetBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

class DraggableScrollableController extends ChangeNotifier {
  _DraggableScrollableSheetScrollController? _attachedController;
  final Set<AnimationController> _animationControllers = <AnimationController>{};

  double get size {
    _assertAttached();
    return _attachedController!.extent.currentSize;
  }

  double get pixels {
    _assertAttached();
    return _attachedController!.extent.currentPixels;
  }

  double sizeToPixels(double size) {
    _assertAttached();
    return _attachedController!.extent.sizeToPixels(size);
  }

  bool get isAttached => _attachedController != null && _attachedController!.hasClients;

  double pixelsToSize(double pixels) {
    _assertAttached();
    return _attachedController!.extent.pixelsToSize(pixels);
  }

  Future<void> animateTo(
    double size, {
    required Duration duration,
    required Curve curve,
  }) async {
    _assertAttached();
    assert(size >= 0 && size <= 1);
    assert(duration != Duration.zero);
    final AnimationController animationController = AnimationController.unbounded(
      vsync: _attachedController!.position.context.vsync,
      value: _attachedController!.extent.currentSize,
    );
    _animationControllers.add(animationController);
    _attachedController!.position.goIdle();
    // This disables any snapping until the next user interaction with the sheet.
    _attachedController!.extent.hasDragged = false;
    _attachedController!.extent.hasChanged = true;
    _attachedController!.extent.startActivity(onCanceled: () {
      // Don't stop the controller if it's already finished and may have been disposed.
      if (animationController.isAnimating) {
        animationController.stop();
      }
    });
    animationController.addListener(() {
      _attachedController!.extent.updateSize(
        animationController.value,
        _attachedController!.position.context.notificationContext!,
      );
    });
    await animationController.animateTo(
      clampDouble(size, _attachedController!.extent.minSize, _attachedController!.extent.maxSize),
      duration: duration,
      curve: curve,
    );
  }

  void jumpTo(double size) {
    _assertAttached();
    assert(size >= 0 && size <= 1);
    // Call start activity to interrupt any other playing activities.
    _attachedController!.extent.startActivity(onCanceled: () {});
    _attachedController!.position.goIdle();
    _attachedController!.extent.hasDragged = false;
    _attachedController!.extent.hasChanged = true;
    _attachedController!.extent.updateSize(size, _attachedController!.position.context.notificationContext!);
  }

  void reset() {
    _assertAttached();
    _attachedController!.reset();
  }

  void _assertAttached() {
    assert(
      isAttached,
      'DraggableScrollableController is not attached to a sheet. A DraggableScrollableController '
        'must be used in a DraggableScrollableSheet before any of its methods are called.',
    );
  }

  void _attach(_DraggableScrollableSheetScrollController scrollController) {
    assert(_attachedController == null, 'Draggable scrollable controller is already attached to a sheet.');
    _attachedController = scrollController;
    _attachedController!.extent._currentSize.addListener(notifyListeners);
    _attachedController!.onPositionDetached = _disposeAnimationControllers;
  }

  void _onExtentReplaced(_DraggableSheetExtent previousExtent) {
    // When the extent has been replaced, the old extent is already disposed and
    // the controller will point to a new extent. We have to add our listener to
    // the new extent.
    _attachedController!.extent._currentSize.addListener(notifyListeners);
    if (previousExtent.currentSize != _attachedController!.extent.currentSize) {
      // The listener won't fire for a change in size between two extent
      // objects so we have to fire it manually here.
      notifyListeners();
    }
  }

  void _detach({bool disposeExtent = false}) {
    if (disposeExtent) {
      _attachedController?.extent.dispose();
    } else {
      _attachedController?.extent._currentSize.removeListener(notifyListeners);
    }
    _disposeAnimationControllers();
    _attachedController = null;
  }

  void _disposeAnimationControllers() {
    for (final AnimationController animationController in _animationControllers) {
      animationController.dispose();
    }
    _animationControllers.clear();
  }
}

class DraggableScrollableSheet extends StatefulWidget {
  const DraggableScrollableSheet({
    super.key,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 1.0,
    this.expand = true,
    this.snap = false,
    this.snapSizes,
    this.snapAnimationDuration,
    this.controller,
    this.shouldCloseOnMinExtent = true,
    required this.builder,
  })  : assert(minChildSize >= 0.0),
        assert(maxChildSize <= 1.0),
        assert(minChildSize <= initialChildSize),
        assert(initialChildSize <= maxChildSize),
        assert(snapAnimationDuration == null || snapAnimationDuration > Duration.zero);

  final double initialChildSize;

  final double minChildSize;

  final double maxChildSize;

  final bool expand;

  final bool snap;

  final List<double>? snapSizes;

  final Duration? snapAnimationDuration;

  final DraggableScrollableController? controller;

  final bool shouldCloseOnMinExtent;

  final ScrollableWidgetBuilder builder;

  @override
  State<DraggableScrollableSheet> createState() => _DraggableScrollableSheetState();
}

class DraggableScrollableNotification extends Notification with ViewportNotificationMixin {
  DraggableScrollableNotification({
    required this.extent,
    required this.minExtent,
    required this.maxExtent,
    required this.initialExtent,
    required this.context,
    this.shouldCloseOnMinExtent = true,
  }) : assert(0.0 <= minExtent),
       assert(maxExtent <= 1.0),
       assert(minExtent <= extent),
       assert(minExtent <= initialExtent),
       assert(extent <= maxExtent),
       assert(initialExtent <= maxExtent);

  final double extent;

  final double minExtent;

  final double maxExtent;

  final double initialExtent;

  final BuildContext context;

  final bool shouldCloseOnMinExtent;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('minExtent: $minExtent, extent: $extent, maxExtent: $maxExtent, initialExtent: $initialExtent');
  }
}

class _DraggableSheetExtent {
  _DraggableSheetExtent({
    required this.minSize,
    required this.maxSize,
    required this.snap,
    required this.snapSizes,
    required this.initialSize,
    this.snapAnimationDuration,
    ValueNotifier<double>? currentSize,
    bool? hasDragged,
    bool? hasChanged,
    this.shouldCloseOnMinExtent = true,
  })  : assert(minSize >= 0),
        assert(maxSize <= 1),
        assert(minSize <= initialSize),
        assert(initialSize <= maxSize),
        _currentSize = currentSize ?? ValueNotifier<double>(initialSize),
        availablePixels = double.infinity,
        hasDragged = hasDragged ?? false,
        hasChanged = hasChanged ?? false;

  VoidCallback? _cancelActivity;

  final double minSize;
  final double maxSize;
  final bool snap;
  final List<double> snapSizes;
  final Duration? snapAnimationDuration;
  final double initialSize;
  final bool shouldCloseOnMinExtent;
  final ValueNotifier<double> _currentSize;
  double availablePixels;

  // Used to disable snapping until the user has dragged on the sheet.
  bool hasDragged;

  // Used to determine if the sheet should move to a new initial size when it
  // changes.
  // We need both `hasChanged` and `hasDragged` to achieve the following
  // behavior:
  //   1. The sheet should only snap following user drags (as opposed to
  //      programmatic sheet changes). See docs for `animateTo` and `jumpTo`.
  //   2. The sheet should move to a new initial child size on rebuild iff the
  //      sheet has not changed, either by drag or programmatic control. See
  //      docs for `initialChildSize`.
  bool hasChanged;

  bool get isAtMin => minSize >= _currentSize.value;
  bool get isAtMax => maxSize <= _currentSize.value;

  double get currentSize => _currentSize.value;
  double get currentPixels => sizeToPixels(_currentSize.value);

  List<double> get pixelSnapSizes => snapSizes.map(sizeToPixels).toList();

  void startActivity({required VoidCallback onCanceled}) {
    _cancelActivity?.call();
    _cancelActivity = onCanceled;
  }

  void addPixelDelta(double delta, BuildContext context) {
    // Stop any playing sheet animations.
    _cancelActivity?.call();
    _cancelActivity = null;
    // The user has interacted with the sheet, set `hasDragged` to true so that
    // we'll snap if applicable.
    hasDragged = true;
    hasChanged = true;
    if (availablePixels == 0) {
      return;
    }
    updateSize(currentSize + pixelsToSize(delta), context);
  }

  void updateSize(double newSize, BuildContext context) {
    final double clampedSize = clampDouble(newSize, minSize, maxSize);
    if (_currentSize.value == clampedSize) {
      return;
    }
    _currentSize.value = clampedSize;
    DraggableScrollableNotification(
      minExtent: minSize,
      maxExtent: maxSize,
      extent: currentSize,
      initialExtent: initialSize,
      context: context,
      shouldCloseOnMinExtent: shouldCloseOnMinExtent,
    ).dispatch(context);
  }

  double pixelsToSize(double pixels) {
    return pixels / availablePixels * maxSize;
  }

  double sizeToPixels(double size) {
    return size / maxSize * availablePixels;
  }

  void dispose() {
    _currentSize.dispose();
  }

  _DraggableSheetExtent copyWith({
    required double minSize,
    required double maxSize,
    required bool snap,
    required List<double> snapSizes,
    required double initialSize,
    Duration? snapAnimationDuration,
    bool shouldCloseOnMinExtent = true,
  }) {
    return _DraggableSheetExtent(
      minSize: minSize,
      maxSize: maxSize,
      snap: snap,
      snapSizes: snapSizes,
      snapAnimationDuration: snapAnimationDuration,
      initialSize: initialSize,
      // Set the current size to the possibly updated initial size if the sheet
      // hasn't changed yet.
      currentSize: ValueNotifier<double>(hasChanged
          ? clampDouble(_currentSize.value, minSize, maxSize)
          : initialSize),
      hasDragged: hasDragged,
      hasChanged: hasChanged,
      shouldCloseOnMinExtent: shouldCloseOnMinExtent,
    );
  }
}

class _DraggableScrollableSheetState extends State<DraggableScrollableSheet> {
  late _DraggableScrollableSheetScrollController _scrollController;
  late _DraggableSheetExtent _extent;

  @override
  void initState() {
    super.initState();
    _extent = _DraggableSheetExtent(
      minSize: widget.minChildSize,
      maxSize: widget.maxChildSize,
      snap: widget.snap,
      snapSizes: _impliedSnapSizes(),
      snapAnimationDuration: widget.snapAnimationDuration,
      initialSize: widget.initialChildSize,
      shouldCloseOnMinExtent: widget.shouldCloseOnMinExtent,
    );
    _scrollController = _DraggableScrollableSheetScrollController(extent: _extent);
    widget.controller?._attach(_scrollController);
  }

  List<double> _impliedSnapSizes() {
    for (int index = 0; index < (widget.snapSizes?.length ?? 0); index += 1) {
      final double snapSize = widget.snapSizes![index];
      assert(snapSize >= widget.minChildSize && snapSize <= widget.maxChildSize,
        '${_snapSizeErrorMessage(index)}\nSnap sizes must be between `minChildSize` and `maxChildSize`. ');
      assert(index == 0 || snapSize > widget.snapSizes![index - 1],
        '${_snapSizeErrorMessage(index)}\nSnap sizes must be in ascending order. ');
    }
    // Ensure the snap sizes start and end with the min and max child sizes.
    if (widget.snapSizes == null || widget.snapSizes!.isEmpty) {
      return <double>[
        widget.minChildSize,
        widget.maxChildSize,
      ];
    }
    return <double>[
      if (widget.snapSizes!.first != widget.minChildSize) widget.minChildSize,
      ...widget.snapSizes!,
      if (widget.snapSizes!.last != widget.maxChildSize) widget.maxChildSize,
    ];
  }

  @override
  void didUpdateWidget(covariant DraggableScrollableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_scrollController);
    }
    _replaceExtent(oldWidget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_InheritedResetNotifier.shouldReset(context)) {
      _scrollController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _extent._currentSize,
      builder: (BuildContext context, double currentSize, Widget? child) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _extent.availablePixels = widget.maxChildSize * constraints.biggest.height;
          final Widget sheet = FractionallySizedBox(
            heightFactor: currentSize,
            alignment: Alignment.bottomCenter,
            child: child,
          );
          return widget.expand ? SizedBox.expand(child: sheet) : sheet;
        },
      ),
      child: widget.builder(context, _scrollController),
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _extent.dispose();
    } else {
      widget.controller!._detach(disposeExtent: true);
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _replaceExtent(covariant DraggableScrollableSheet oldWidget) {
    final _DraggableSheetExtent previousExtent = _extent;
    _extent = previousExtent.copyWith(
      minSize: widget.minChildSize,
      maxSize: widget.maxChildSize,
      snap: widget.snap,
      snapSizes: _impliedSnapSizes(),
      snapAnimationDuration: widget.snapAnimationDuration,
      initialSize: widget.initialChildSize,
    );
    // Modify the existing scroll controller instead of replacing it so that
    // developers listening to the controller do not have to rebuild their listeners.
    _scrollController.extent = _extent;
    // If an external facing controller was provided, let it know that the
    // extent has been replaced.
    widget.controller?._onExtentReplaced(previousExtent);
    previousExtent.dispose();
    if (widget.snap
        && (widget.snap != oldWidget.snap || widget.snapSizes != oldWidget.snapSizes)
        && _scrollController.hasClients
    ) {
      // Trigger a snap in case snap or snapSizes has changed and there is a
      // scroll position currently attached. We put this in a post frame
      // callback so that `build` can update `_extent.availablePixels` before
      // this runs-we can't use the previous extent's available pixels as it may
      // have changed when the widget was updated.
      WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
        for (int index = 0; index < _scrollController.positions.length; index++) {
          final _DraggableScrollableSheetScrollPosition position =
            _scrollController.positions.elementAt(index) as _DraggableScrollableSheetScrollPosition;
          position.goBallistic(0);
        }
      });
    }
  }

  String _snapSizeErrorMessage(int invalidIndex) {
    final List<String> snapSizesWithIndicator = widget.snapSizes!.asMap().keys.map(
      (int index) {
        final String snapSizeString = widget.snapSizes![index].toString();
        if (index == invalidIndex) {
          return '>>> $snapSizeString <<<';
        }
        return snapSizeString;
      },
    ).toList();
    return "Invalid snapSize '${widget.snapSizes![invalidIndex]}' at index $invalidIndex of:\n"
        '  $snapSizesWithIndicator';
  }
}

class _DraggableScrollableSheetScrollController extends ScrollController {
  _DraggableScrollableSheetScrollController({
    required this.extent,
  });

  _DraggableSheetExtent extent;
  VoidCallback? onPositionDetached;

  @override
  _DraggableScrollableSheetScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _DraggableScrollableSheetScrollPosition(
      physics: physics.applyTo(const AlwaysScrollableScrollPhysics()),
      context: context,
      oldPosition: oldPosition,
      getExtent: () => extent,
    );
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('extent: $extent');
  }

  @override
  _DraggableScrollableSheetScrollPosition get position =>
      super.position as _DraggableScrollableSheetScrollPosition;

  void reset() {
    extent._cancelActivity?.call();
    extent.hasDragged = false;
    extent.hasChanged = false;
    // jumpTo can result in trying to replace semantics during build.
    // Just animate really fast.
    // Avoid doing it at all if the offset is already 0.0.
    if (offset != 0.0) {
      animateTo(
        0.0,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
    }
    extent.updateSize(extent.initialSize, position.context.notificationContext!);
  }

  @override
  void detach(ScrollPosition position) {
    onPositionDetached?.call();
    super.detach(position);
  }
}

class _DraggableScrollableSheetScrollPosition extends ScrollPositionWithSingleContext {
  _DraggableScrollableSheetScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.getExtent,
  });

  VoidCallback? _dragCancelCallback;
  final _DraggableSheetExtent Function() getExtent;
  final Set<AnimationController> _ballisticControllers = <AnimationController>{};
  bool get listShouldScroll => pixels > 0.0;

  _DraggableSheetExtent get extent => getExtent();

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    assert(_dragCancelCallback == null);

    if (other is! _DraggableScrollableSheetScrollPosition) {
      return;
    }

    if (other._dragCancelCallback != null) {
      _dragCancelCallback = other._dragCancelCallback;
      other._dragCancelCallback = null;
    }
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // Cancel the running ballistic simulations
    for (final AnimationController ballisticController in _ballisticControllers) {
      ballisticController.stop();
    }
    super.beginActivity(newActivity);
  }

  @override
  void applyUserOffset(double delta) {
    if (!listShouldScroll &&
        (!(extent.isAtMin || extent.isAtMax) ||
          (extent.isAtMin && delta < 0) ||
          (extent.isAtMax && delta > 0))) {
      extent.addPixelDelta(-delta, context.notificationContext!);
    } else {
      super.applyUserOffset(delta);
    }
  }

  bool get _isAtSnapSize {
    return extent.snapSizes.any(
      (double snapSize) {
        return (extent.currentSize - snapSize).abs() <= extent.pixelsToSize(physics.toleranceFor(this).distance);
      },
    );
  }
  bool get _shouldSnap => extent.snap && extent.hasDragged && !_isAtSnapSize;

  @override
  void dispose() {
    for (final AnimationController ballisticController in _ballisticControllers) {
      ballisticController.dispose();
    }
    _ballisticControllers.clear();
    super.dispose();
  }

  @override
  void goBallistic(double velocity) {
    if ((velocity == 0.0 && !_shouldSnap) ||
        (velocity < 0.0 && listShouldScroll) ||
        (velocity > 0.0 && extent.isAtMax)) {
      super.goBallistic(velocity);
      return;
    }
    // Scrollable expects that we will dispose of its current _dragCancelCallback
    _dragCancelCallback?.call();
    _dragCancelCallback = null;

    late final Simulation simulation;
    if (extent.snap) {
      // Snap is enabled, simulate snapping instead of clamping scroll.
      simulation = _SnappingSimulation(
        position: extent.currentPixels,
        initialVelocity: velocity,
        pixelSnapSize: extent.pixelSnapSizes,
        snapAnimationDuration: extent.snapAnimationDuration,
        tolerance: physics.toleranceFor(this),
      );
    } else {
      // The iOS bouncing simulation just isn't right here - once we delegate
      // the ballistic back to the ScrollView, it will use the right simulation.
      simulation = ClampingScrollSimulation(
        // Run the simulation in terms of pixels, not extent.
        position: extent.currentPixels,
        velocity: velocity,
        tolerance: physics.toleranceFor(this),
      );
    }

    final AnimationController ballisticController = AnimationController.unbounded(
      debugLabel: objectRuntimeType(this, '_DraggableScrollableSheetPosition'),
      vsync: context.vsync,
    );
    _ballisticControllers.add(ballisticController);

    double lastPosition = extent.currentPixels;
    void tick() {
      final double delta = ballisticController.value - lastPosition;
      lastPosition = ballisticController.value;
      extent.addPixelDelta(delta, context.notificationContext!);
      if ((velocity > 0 && extent.isAtMax) || (velocity < 0 && extent.isAtMin)) {
        // Make sure we pass along enough velocity to keep scrolling - otherwise
        // we just "bounce" off the top making it look like the list doesn't
        // have more to scroll.
        velocity = ballisticController.velocity + (physics.toleranceFor(this).velocity * ballisticController.velocity.sign);
        super.goBallistic(velocity);
        ballisticController.stop();
      } else if (ballisticController.isCompleted) {
        super.goBallistic(0);
      }
    }

    ballisticController
      ..addListener(tick)
      ..animateWith(simulation).whenCompleteOrCancel(
        () {
          if (_ballisticControllers.contains(ballisticController)) {
            _ballisticControllers.remove(ballisticController);
            ballisticController.dispose();
          }
        },
      );
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    // Save this so we can call it later if we have to [goBallistic] on our own.
    _dragCancelCallback = dragCancelCallback;
    return super.drag(details, dragCancelCallback);
  }
}

class DraggableScrollableActuator extends StatefulWidget {
  const DraggableScrollableActuator({
    super.key,
    required this.child,
  });

  final Widget child;


  static bool reset(BuildContext context) {
    final _InheritedResetNotifier? notifier = context.dependOnInheritedWidgetOfExactType<_InheritedResetNotifier>();
    if (notifier == null) {
      return false;
    }
    return notifier._sendReset();
  }

  @override
  State<DraggableScrollableActuator> createState() => _DraggableScrollableActuatorState();
}

class _DraggableScrollableActuatorState extends State<DraggableScrollableActuator> {
  final _ResetNotifier _notifier = _ResetNotifier();

  @override
  Widget build(BuildContext context) {
    return _InheritedResetNotifier(notifier: _notifier, child: widget.child);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }
}

class _ResetNotifier extends ChangeNotifier {
  _ResetNotifier() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }
  bool _wasCalled = false;

  bool sendReset() {
    if (!hasListeners) {
      return false;
    }
    _wasCalled = true;
    notifyListeners();
    return true;
  }
}

class _InheritedResetNotifier extends InheritedNotifier<_ResetNotifier> {
  const _InheritedResetNotifier({
    required super.child,
    required _ResetNotifier super.notifier,
  });

  bool _sendReset() => notifier!.sendReset();

  static bool shouldReset(BuildContext context) {
    final InheritedWidget? widget = context.dependOnInheritedWidgetOfExactType<_InheritedResetNotifier>();
    if (widget == null) {
      return false;
    }
    assert(widget is _InheritedResetNotifier);
    final _InheritedResetNotifier inheritedNotifier = widget as _InheritedResetNotifier;
    final bool wasCalled = inheritedNotifier.notifier!._wasCalled;
    inheritedNotifier.notifier!._wasCalled = false;
    return wasCalled;
  }
}

class _SnappingSimulation extends Simulation {
  _SnappingSimulation({
    required this.position,
    required double initialVelocity,
    required List<double> pixelSnapSize,
    Duration? snapAnimationDuration,
    super.tolerance,
  }) {
    _pixelSnapSize = _getSnapSize(initialVelocity, pixelSnapSize);

    if (snapAnimationDuration != null && snapAnimationDuration.inMilliseconds > 0) {
       velocity = (_pixelSnapSize - position) * 1000 / snapAnimationDuration.inMilliseconds;
    }
    // Check the direction of the target instead of the sign of the velocity because
    // we may snap in the opposite direction of velocity if velocity is very low.
    else if (_pixelSnapSize < position) {
      velocity = math.min(-minimumSpeed, initialVelocity);
    } else {
      velocity = math.max(minimumSpeed, initialVelocity);
    }
  }

  final double position;
  late final double velocity;

  // A minimum speed to snap at. Used to ensure that the snapping animation
  // does not play too slowly.
  static const double minimumSpeed = 1600.0;

  late final double _pixelSnapSize;

  @override
  double dx(double time) {
    if (isDone(time)) {
      return 0;
    }
    return velocity;
  }

  @override
  bool isDone(double time) {
    return x(time) == _pixelSnapSize;
  }

  @override
  double x(double time) {
    final double newPosition = position + velocity * time;
    if ((velocity >= 0 && newPosition > _pixelSnapSize) ||
        (velocity < 0 && newPosition < _pixelSnapSize)) {
      // We're passed the snap size, return it instead.
      return _pixelSnapSize;
    }
    return newPosition;
  }

  // Find the two closest snap sizes to the position. If the velocity is
  // non-zero, select the size in the velocity's direction. Otherwise,
  // the nearest snap size.
  double _getSnapSize(double initialVelocity, List<double> pixelSnapSizes) {
    final int indexOfNextSize = pixelSnapSizes
        .indexWhere((double size) => size >= position);
    if (indexOfNextSize == 0) {
      return pixelSnapSizes.first;
    }
    final double nextSize = pixelSnapSizes[indexOfNextSize];
    final double previousSize = pixelSnapSizes[indexOfNextSize - 1];
    if (initialVelocity.abs() <= tolerance.velocity) {
      // If velocity is zero, snap to the nearest snap size with the minimum velocity.
      if (position - previousSize < nextSize - position) {
        return previousSize;
      } else {
        return nextSize;
      }
    }
    // Snap forward or backward depending on current velocity.
    if (initialVelocity < 0.0) {
      return pixelSnapSizes[indexOfNextSize - 1];
    }
    return pixelSnapSizes[indexOfNextSize];
  }
}