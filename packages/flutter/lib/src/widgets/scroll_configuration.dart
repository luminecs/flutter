import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'framework.dart';
import 'overscroll_indicator.dart';
import 'scroll_physics.dart';
import 'scrollable.dart';
import 'scrollable_helpers.dart';
import 'scrollbar.dart';

const Color _kDefaultGlowColor = Color(0xFFFFFFFF);

const Set<PointerDeviceKind> _kTouchLikeDeviceTypes = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  // The VoiceAccess sends pointer events with unknown type when scrolling
  // scrollables.
  PointerDeviceKind.unknown,
};

enum AndroidOverscrollIndicator {
  stretch,

  glow,
}

@immutable
class ScrollBehavior {
  const ScrollBehavior();

  ScrollBehavior copyWith({
    bool? scrollbars,
    bool? overscroll,
    Set<PointerDeviceKind>? dragDevices,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    ScrollPhysics? physics,
    TargetPlatform? platform,
  }) {
    return _WrappedScrollBehavior(
      delegate: this,
      scrollbars: scrollbars ?? true,
      overscroll: overscroll ?? true,
      dragDevices: dragDevices,
      pointerAxisModifiers: pointerAxisModifiers,
      physics: physics,
      platform: platform,
    );
  }

  TargetPlatform getPlatform(BuildContext context) => defaultTargetPlatform;

  Set<PointerDeviceKind> get dragDevices => _kTouchLikeDeviceTypes;

  Set<LogicalKeyboardKey> get pointerAxisModifiers => <LogicalKeyboardKey>{
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
      };

  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // When modifying this function, consider modifying the implementation in
    // the Material and Cupertino subclasses as well.
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        assert(details.controller != null);
        return RawScrollbar(
          controller: details.controller,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }

  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // When modifying this function, consider modifying the implementation in
    // the Material and Cupertino subclasses as well.
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return child;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return GlowingOverscrollIndicator(
          axisDirection: details.direction,
          color: _kDefaultGlowColor,
          child: child,
        );
    }
  }

  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
        return (PointerEvent event) =>
            IOSScrollViewFlingVelocityTracker(event.kind);
      case TargetPlatform.macOS:
        return (PointerEvent event) =>
            MacOSScrollViewFlingVelocityTracker(event.kind);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return (PointerEvent event) => VelocityTracker.withKind(event.kind);
    }
  }

  static const ScrollPhysics _bouncingPhysics =
      BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());
  static const ScrollPhysics _bouncingDesktopPhysics = BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
      parent: RangeMaintainingScrollPhysics());
  static const ScrollPhysics _clampingPhysics =
      ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());

  ScrollPhysics getScrollPhysics(BuildContext context) {
    // When modifying this function, consider modifying the implementation in
    // the Material and Cupertino subclasses as well.
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
        return _bouncingPhysics;
      case TargetPlatform.macOS:
        return _bouncingDesktopPhysics;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _clampingPhysics;
    }
  }

  bool shouldNotify(covariant ScrollBehavior oldDelegate) => false;

  @override
  String toString() => objectRuntimeType(this, 'ScrollBehavior');
}

class _WrappedScrollBehavior implements ScrollBehavior {
  const _WrappedScrollBehavior({
    required this.delegate,
    this.scrollbars = true,
    this.overscroll = true,
    Set<PointerDeviceKind>? dragDevices,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    this.physics,
    this.platform,
  })  : _dragDevices = dragDevices,
        _pointerAxisModifiers = pointerAxisModifiers;

  final ScrollBehavior delegate;
  final bool scrollbars;
  final bool overscroll;
  final ScrollPhysics? physics;
  final TargetPlatform? platform;
  final Set<PointerDeviceKind>? _dragDevices;
  final Set<LogicalKeyboardKey>? _pointerAxisModifiers;

  @override
  Set<PointerDeviceKind> get dragDevices =>
      _dragDevices ?? delegate.dragDevices;

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      _pointerAxisModifiers ?? delegate.pointerAxisModifiers;

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    if (overscroll) {
      return delegate.buildOverscrollIndicator(context, child, details);
    }
    return child;
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    if (scrollbars) {
      return delegate.buildScrollbar(context, child, details);
    }
    return child;
  }

  @override
  ScrollBehavior copyWith({
    bool? scrollbars,
    bool? overscroll,
    Set<PointerDeviceKind>? dragDevices,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    ScrollPhysics? physics,
    TargetPlatform? platform,
  }) {
    return delegate.copyWith(
      scrollbars: scrollbars ?? this.scrollbars,
      overscroll: overscroll ?? this.overscroll,
      dragDevices: dragDevices ?? this.dragDevices,
      pointerAxisModifiers: pointerAxisModifiers ?? this.pointerAxisModifiers,
      physics: physics ?? this.physics,
      platform: platform ?? this.platform,
    );
  }

  @override
  TargetPlatform getPlatform(BuildContext context) {
    return platform ?? delegate.getPlatform(context);
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return physics ?? delegate.getScrollPhysics(context);
  }

  @override
  bool shouldNotify(_WrappedScrollBehavior oldDelegate) {
    return oldDelegate.delegate.runtimeType != delegate.runtimeType ||
        oldDelegate.scrollbars != scrollbars ||
        oldDelegate.overscroll != overscroll ||
        !setEquals<PointerDeviceKind>(oldDelegate.dragDevices, dragDevices) ||
        !setEquals<LogicalKeyboardKey>(
            oldDelegate.pointerAxisModifiers, pointerAxisModifiers) ||
        oldDelegate.physics != physics ||
        oldDelegate.platform != platform ||
        delegate.shouldNotify(oldDelegate.delegate);
  }

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    return delegate.velocityTrackerBuilder(context);
  }

  @override
  String toString() => objectRuntimeType(this, '_WrappedScrollBehavior');
}

class ScrollConfiguration extends InheritedWidget {
  const ScrollConfiguration({
    super.key,
    required this.behavior,
    required super.child,
  });

  final ScrollBehavior behavior;

  static ScrollBehavior of(BuildContext context) {
    final ScrollConfiguration? configuration =
        context.dependOnInheritedWidgetOfExactType<ScrollConfiguration>();
    return configuration?.behavior ?? const ScrollBehavior();
  }

  @override
  bool updateShouldNotify(ScrollConfiguration oldWidget) {
    return behavior.runtimeType != oldWidget.behavior.runtimeType ||
        (behavior != oldWidget.behavior &&
            behavior.shouldNotify(oldWidget.behavior));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollBehavior>('behavior', behavior));
  }
}
