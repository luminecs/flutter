
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'basic.dart';
import 'display_feature_sub_screen.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'focus_traversal.dart';
import 'framework.dart';
import 'modal_barrier.dart';
import 'navigator.dart';
import 'overlay.dart';
import 'page_storage.dart';
import 'primary_scroll_controller.dart';
import 'restoration.dart';
import 'scroll_controller.dart';
import 'transitions.dart';

// Examples can assume:
// late NavigatorState navigator;
// late BuildContext context;
// Future<bool> askTheUserIfTheyAreSure() async { return true; }
// abstract class MyWidget extends StatefulWidget { const MyWidget({super.key}); }
// late dynamic _myState, newValue;
// late StateSetter setState;

abstract class OverlayRoute<T> extends Route<T> {
  OverlayRoute({
    super.settings,
  });

  @factory
  Iterable<OverlayEntry> createOverlayEntries();

  @override
  List<OverlayEntry> get overlayEntries => _overlayEntries;
  final List<OverlayEntry> _overlayEntries = <OverlayEntry>[];

  @override
  void install() {
    assert(_overlayEntries.isEmpty);
    _overlayEntries.addAll(createOverlayEntries());
    super.install();
  }

  @protected
  bool get finishedWhenPopped => true;

  @override
  bool didPop(T? result) {
    final bool returnValue = super.didPop(result);
    assert(returnValue);
    if (finishedWhenPopped) {
      navigator!.finalizeRoute(this);
    }
    return returnValue;
  }

  @override
  void dispose() {
    for (final OverlayEntry entry in _overlayEntries) {
      entry.dispose();
    }
    _overlayEntries.clear();
    super.dispose();
  }
}

abstract class TransitionRoute<T> extends OverlayRoute<T> {
  TransitionRoute({
    super.settings,
  });

  Future<T?> get completed => _transitionCompleter.future;
  final Completer<T?> _transitionCompleter = Completer<T?>();

  PerformanceModeRequestHandle? _performanceModeRequestHandle;

  Duration get transitionDuration;

  Duration get reverseTransitionDuration => transitionDuration;

  bool get opaque;

  bool get allowSnapshotting => true;

  // This ensures that if we got to the dismissed state while still current,
  // we will still be disposed when we are eventually popped.
  //
  // This situation arises when dealing with the Cupertino dismiss gesture.
  @override
  bool get finishedWhenPopped => _controller!.status == AnimationStatus.dismissed && !_popFinalized;

  bool _popFinalized = false;

  Animation<double>? get animation => _animation;
  Animation<double>? _animation;

  @protected
  AnimationController? get controller => _controller;
  AnimationController? _controller;

  Animation<double>? get secondaryAnimation => _secondaryAnimation;
  final ProxyAnimation _secondaryAnimation = ProxyAnimation(kAlwaysDismissedAnimation);

  bool willDisposeAnimationController = true;

  AnimationController createAnimationController() {
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    final Duration duration = transitionDuration;
    final Duration reverseDuration = reverseTransitionDuration;
    assert(duration >= Duration.zero);
    return AnimationController(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  Animation<double> createAnimation() {
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    assert(_controller != null);
    return _controller!.view;
  }

  T? _result;

  void _handleStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.completed:
        if (overlayEntries.isNotEmpty) {
          overlayEntries.first.opaque = opaque;
        }
        _performanceModeRequestHandle?.dispose();
        _performanceModeRequestHandle = null;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        if (overlayEntries.isNotEmpty) {
          overlayEntries.first.opaque = false;
        }
        _performanceModeRequestHandle ??=
          SchedulerBinding.instance
            .requestPerformanceMode(ui.DartPerformanceMode.latency);
      case AnimationStatus.dismissed:
        // We might still be an active route if a subclass is controlling the
        // transition and hits the dismissed status. For example, the iOS
        // back gesture drives this animation to the dismissed status before
        // removing the route and disposing it.
        if (!isActive) {
          navigator!.finalizeRoute(this);
          _popFinalized = true;
          _performanceModeRequestHandle?.dispose();
          _performanceModeRequestHandle = null;
        }
    }
  }

  @override
  void install() {
    assert(!_transitionCompleter.isCompleted, 'Cannot install a $runtimeType after disposing it.');
    _controller = createAnimationController();
    assert(_controller != null, '$runtimeType.createAnimationController() returned null.');
    _animation = createAnimation()
      ..addStatusListener(_handleStatusChanged);
    assert(_animation != null, '$runtimeType.createAnimation() returned null.');
    super.install();
    if (_animation!.isCompleted && overlayEntries.isNotEmpty) {
      overlayEntries.first.opaque = opaque;
    }
  }

  @override
  TickerFuture didPush() {
    assert(_controller != null, '$runtimeType.didPush called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    super.didPush();
    return _controller!.forward();
  }

  @override
  void didAdd() {
    assert(_controller != null, '$runtimeType.didPush called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    super.didAdd();
    _controller!.value = _controller!.upperBound;
  }

  @override
  void didReplace(Route<dynamic>? oldRoute) {
    assert(_controller != null, '$runtimeType.didReplace called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    if (oldRoute is TransitionRoute) {
      _controller!.value = oldRoute._controller!.value;
    }
    super.didReplace(oldRoute);
  }

  @override
  bool didPop(T? result) {
    assert(_controller != null, '$runtimeType.didPop called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    _result = result;
    _controller!.reverse();
    return super.didPop(result);
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    assert(_controller != null, '$runtimeType.didPopNext called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    _updateSecondaryAnimation(nextRoute);
    super.didPopNext(nextRoute);
  }

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    assert(_controller != null, '$runtimeType.didChangeNext called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    _updateSecondaryAnimation(nextRoute);
    super.didChangeNext(nextRoute);
  }

  // A callback method that disposes existing train hopping animation and
  // removes its listener.
  //
  // This property is non-null if there is a train hopping in progress, and the
  // caller must reset this property to null after it is called.
  VoidCallback? _trainHoppingListenerRemover;

  void _updateSecondaryAnimation(Route<dynamic>? nextRoute) {
    // There is an existing train hopping in progress. Unfortunately, we cannot
    // dispose current train hopping animation until we replace it with a new
    // animation.
    final VoidCallback? previousTrainHoppingListenerRemover = _trainHoppingListenerRemover;
    _trainHoppingListenerRemover = null;

    if (nextRoute is TransitionRoute<dynamic> && canTransitionTo(nextRoute) && nextRoute.canTransitionFrom(this)) {
      final Animation<double>? current = _secondaryAnimation.parent;
      if (current != null) {
        final Animation<double> currentTrain = (current is TrainHoppingAnimation ? current.currentTrain : current)!;
        final Animation<double> nextTrain = nextRoute._animation!;
        if (
          currentTrain.value == nextTrain.value ||
          nextTrain.status == AnimationStatus.completed ||
          nextTrain.status == AnimationStatus.dismissed
        ) {
          _setSecondaryAnimation(nextTrain, nextRoute.completed);
        } else {
          // Two trains animate at different values. We have to do train hopping.
          // There are three possibilities of train hopping:
          //  1. We hop on the nextTrain when two trains meet in the middle using
          //     TrainHoppingAnimation.
          //  2. There is no chance to hop on nextTrain because two trains never
          //     cross each other. We have to directly set the animation to
          //     nextTrain once the nextTrain stops animating.
          //  3. A new _updateSecondaryAnimation is called before train hopping
          //     finishes. We leave a listener remover for the next call to
          //     properly clean up the existing train hopping.
          TrainHoppingAnimation? newAnimation;
          void jumpOnAnimationEnd(AnimationStatus status) {
            switch (status) {
              case AnimationStatus.completed:
              case AnimationStatus.dismissed:
                // The nextTrain has stopped animating without train hopping.
                // Directly sets the secondary animation and disposes the
                // TrainHoppingAnimation.
                _setSecondaryAnimation(nextTrain, nextRoute.completed);
                if (_trainHoppingListenerRemover != null) {
                  _trainHoppingListenerRemover!();
                  _trainHoppingListenerRemover = null;
                }
              case AnimationStatus.forward:
              case AnimationStatus.reverse:
                break;
            }
          }
          _trainHoppingListenerRemover = () {
            nextTrain.removeStatusListener(jumpOnAnimationEnd);
            newAnimation?.dispose();
          };
          nextTrain.addStatusListener(jumpOnAnimationEnd);
          newAnimation = TrainHoppingAnimation(
            currentTrain,
            nextTrain,
            onSwitchedTrain: () {
              assert(_secondaryAnimation.parent == newAnimation);
              assert(newAnimation!.currentTrain == nextRoute._animation);
              // We can hop on the nextTrain, so we don't need to listen to
              // whether the nextTrain has stopped.
              _setSecondaryAnimation(newAnimation!.currentTrain, nextRoute.completed);
              if (_trainHoppingListenerRemover != null) {
                _trainHoppingListenerRemover!();
                _trainHoppingListenerRemover = null;
              }
            },
          );
          _setSecondaryAnimation(newAnimation, nextRoute.completed);
        }
      } else {
        _setSecondaryAnimation(nextRoute._animation, nextRoute.completed);
      }
    } else {
      _setSecondaryAnimation(kAlwaysDismissedAnimation);
    }
    // Finally, we dispose any previous train hopping animation because it
    // has been successfully updated at this point.
    if (previousTrainHoppingListenerRemover != null) {
      previousTrainHoppingListenerRemover();
    }
  }

  void _setSecondaryAnimation(Animation<double>? animation, [Future<dynamic>? disposed]) {
    _secondaryAnimation.parent = animation;
    // Releases the reference to the next route's animation when that route
    // is disposed.
    disposed?.then((dynamic _) {
      if (_secondaryAnimation.parent == animation) {
        _secondaryAnimation.parent = kAlwaysDismissedAnimation;
        if (animation is TrainHoppingAnimation) {
          animation.dispose();
        }
      }
    });
  }

  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => true;

  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => true;

  @override
  void dispose() {
    assert(!_transitionCompleter.isCompleted, 'Cannot dispose a $runtimeType twice.');
    _animation?.removeStatusListener(_handleStatusChanged);
    _performanceModeRequestHandle?.dispose();
    _performanceModeRequestHandle = null;
    if (willDisposeAnimationController) {
      _controller?.dispose();
    }
    _transitionCompleter.complete(_result);
    super.dispose();
  }

  String get debugLabel => objectRuntimeType(this, 'TransitionRoute');

  @override
  String toString() => '${objectRuntimeType(this, 'TransitionRoute')}(animation: $_controller)';
}

class LocalHistoryEntry {
  LocalHistoryEntry({ this.onRemove, this.impliesAppBarDismissal = true });

  final VoidCallback? onRemove;

  LocalHistoryRoute<dynamic>? _owner;

  final bool impliesAppBarDismissal;

  void remove() {
    _owner?.removeLocalHistoryEntry(this);
    assert(_owner == null);
  }

  void _notifyRemoved() {
    onRemove?.call();
  }
}

mixin LocalHistoryRoute<T> on Route<T> {
  List<LocalHistoryEntry>? _localHistory;
  int _entriesImpliesAppBarDismissal = 0;
  void addLocalHistoryEntry(LocalHistoryEntry entry) {
    assert(entry._owner == null);
    entry._owner = this;
    _localHistory ??= <LocalHistoryEntry>[];
    final bool wasEmpty = _localHistory!.isEmpty;
    _localHistory!.add(entry);
    bool internalStateChanged = false;
    if (entry.impliesAppBarDismissal) {
      internalStateChanged = _entriesImpliesAppBarDismissal == 0;
      _entriesImpliesAppBarDismissal += 1;
    }
    if (wasEmpty || internalStateChanged) {
      changedInternalState();
    }
  }

  void removeLocalHistoryEntry(LocalHistoryEntry entry) {
    assert(entry._owner == this);
    assert(_localHistory!.contains(entry));
    bool internalStateChanged = false;
    if (_localHistory!.remove(entry) && entry.impliesAppBarDismissal) {
      _entriesImpliesAppBarDismissal -= 1;
      internalStateChanged = _entriesImpliesAppBarDismissal == 0;
    }
    entry._owner = null;
    entry._notifyRemoved();
    if (_localHistory!.isEmpty || internalStateChanged) {
      assert(_entriesImpliesAppBarDismissal == 0);
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        // The local history might be removed as a result of disposing inactive
        // elements during finalizeTree. The state is locked at this moment, and
        // we can only notify state has changed in the next frame.
        SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
          if (isActive) {
            changedInternalState();
          }
        });
      } else {
        changedInternalState();
      }
    }
  }

  @Deprecated(
    'Use popDisposition instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  @override
  Future<RoutePopDisposition> willPop() async {
    if (willHandlePopInternally) {
      return RoutePopDisposition.pop;
    }
    return super.willPop();
  }

  @override
  RoutePopDisposition get popDisposition {
    if (willHandlePopInternally) {
      return RoutePopDisposition.pop;
    }
    return super.popDisposition;
  }

  @override
  bool didPop(T? result) {
    if (_localHistory != null && _localHistory!.isNotEmpty) {
      final LocalHistoryEntry entry = _localHistory!.removeLast();
      assert(entry._owner == this);
      entry._owner = null;
      entry._notifyRemoved();
      bool internalStateChanged = false;
      if (entry.impliesAppBarDismissal) {
        _entriesImpliesAppBarDismissal -= 1;
        internalStateChanged = _entriesImpliesAppBarDismissal == 0;
      }
      if (_localHistory!.isEmpty || internalStateChanged) {
        changedInternalState();
      }
      return false;
    }
    return super.didPop(result);
  }

  @override
  bool get willHandlePopInternally {
    return _localHistory != null && _localHistory!.isNotEmpty;
  }
}

class _DismissModalAction extends DismissAction {
  _DismissModalAction(this.context);

  final BuildContext context;

  @override
  bool isEnabled(DismissIntent intent) {
    final ModalRoute<dynamic> route = ModalRoute.of<dynamic>(context)!;
    return route.barrierDismissible;
  }

  @override
  Object invoke(DismissIntent intent) {
    return Navigator.of(context).maybePop();
  }
}

class _ModalScopeStatus extends InheritedWidget {
  const _ModalScopeStatus({
    required this.isCurrent,
    required this.canPop,
    required this.impliesAppBarDismissal,
    required this.route,
    required super.child,
  });

  final bool isCurrent;
  final bool canPop;
  final bool impliesAppBarDismissal;
  final Route<dynamic> route;

  @override
  bool updateShouldNotify(_ModalScopeStatus old) {
    return isCurrent != old.isCurrent ||
           canPop != old.canPop ||
           impliesAppBarDismissal != old.impliesAppBarDismissal ||
           route != old.route;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(FlagProperty('isCurrent', value: isCurrent, ifTrue: 'active', ifFalse: 'inactive'));
    description.add(FlagProperty('canPop', value: canPop, ifTrue: 'can pop'));
    description.add(FlagProperty('impliesAppBarDismissal', value: impliesAppBarDismissal, ifTrue: 'implies app bar dismissal'));
  }
}

class _ModalScope<T> extends StatefulWidget {
  const _ModalScope({
    super.key,
    required this.route,
  });

  final ModalRoute<T> route;

  @override
  _ModalScopeState<T> createState() => _ModalScopeState<T>();
}

class _ModalScopeState<T> extends State<_ModalScope<T>> {
  // We cache the result of calling the route's buildPage, and clear the cache
  // whenever the dependencies change. This implements the contract described in
  // the documentation for buildPage, namely that it gets called once, unless
  // something like a ModalRoute.of() dependency triggers an update.
  Widget? _page;

  // This is the combination of the two animations for the route.
  late Listenable _listenable;

  final FocusScopeNode focusScopeNode = FocusScopeNode(debugLabel: '$_ModalScopeState Focus Scope');
  final ScrollController primaryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final List<Listenable> animations = <Listenable>[
      if (widget.route.animation != null) widget.route.animation!,
      if (widget.route.secondaryAnimation != null) widget.route.secondaryAnimation!,
    ];
    _listenable = Listenable.merge(animations);
  }

  @override
  void didUpdateWidget(_ModalScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.route == oldWidget.route);
    _updateFocusScopeNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _page = null;
    _updateFocusScopeNode();
  }

  void _updateFocusScopeNode() {
    final TraversalEdgeBehavior traversalEdgeBehavior;
    final ModalRoute<T> route = widget.route;
    if (route.traversalEdgeBehavior != null) {
      traversalEdgeBehavior = route.traversalEdgeBehavior!;
    } else {
      traversalEdgeBehavior = route.navigator!.widget.routeTraversalEdgeBehavior;
    }
    focusScopeNode.traversalEdgeBehavior = traversalEdgeBehavior;
    if (route.isCurrent && _shouldRequestFocus) {
      route.navigator!.focusNode.enclosingScope?.setFirstFocus(focusScopeNode);
    }
  }

  void _forceRebuildPage() {
    setState(() {
      _page = null;
    });
  }

  @override
  void dispose() {
    focusScopeNode.dispose();
    primaryScrollController.dispose();
    super.dispose();
  }

  bool get _shouldIgnoreFocusRequest {
    return widget.route.animation?.status == AnimationStatus.reverse ||
      (widget.route.navigator?.userGestureInProgress ?? false);
  }

  bool get _shouldRequestFocus {
    return widget.route.navigator!.widget.requestFocus;
  }

  // This should be called to wrap any changes to route.isCurrent, route.canPop,
  // and route.offstage.
  void _routeSetState(VoidCallback fn) {
    if (widget.route.isCurrent && !_shouldIgnoreFocusRequest && _shouldRequestFocus) {
      widget.route.navigator!.focusNode.enclosingScope?.setFirstFocus(focusScopeNode);
    }
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.route.restorationScopeId,
      builder: (BuildContext context, Widget? child) {
        assert(child != null);
        return RestorationScope(
          restorationId: widget.route.restorationScopeId.value,
          child: child!,
        );
      },
      child: _ModalScopeStatus(
        route: widget.route,
        isCurrent: widget.route.isCurrent, // _routeSetState is called if this updates
        canPop: widget.route.canPop, // _routeSetState is called if this updates
        impliesAppBarDismissal: widget.route.impliesAppBarDismissal,
        child: Offstage(
          offstage: widget.route.offstage, // _routeSetState is called if this updates
          child: PageStorage(
            bucket: widget.route._storageBucket, // immutable
            child: Builder(
              builder: (BuildContext context) {
                return Actions(
                  actions: <Type, Action<Intent>>{
                    DismissIntent: _DismissModalAction(context),
                  },
                  child: PrimaryScrollController(
                    controller: primaryScrollController,
                    child: FocusScope(
                      node: focusScopeNode, // immutable
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _listenable, // immutable
                          builder: (BuildContext context, Widget? child) {
                            return widget.route.buildTransitions(
                              context,
                              widget.route.animation!,
                              widget.route.secondaryAnimation!,
                              // This additional AnimatedBuilder is include because if the
                              // value of the userGestureInProgressNotifier changes, it's
                              // only necessary to rebuild the IgnorePointer widget and set
                              // the focus node's ability to focus.
                              AnimatedBuilder(
                                animation: widget.route.navigator?.userGestureInProgressNotifier ?? ValueNotifier<bool>(false),
                                builder: (BuildContext context, Widget? child) {
                                  final bool ignoreEvents = _shouldIgnoreFocusRequest;
                                  focusScopeNode.canRequestFocus = !ignoreEvents;
                                  return IgnorePointer(
                                    ignoring: ignoreEvents,
                                    child: child,
                                  );
                                },
                                child: child,
                              ),
                            );
                          },
                          child: _page ??= RepaintBoundary(
                            key: widget.route._subtreeKey, // immutable
                            child: Builder(
                              builder: (BuildContext context) {
                                return widget.route.buildPage(
                                  context,
                                  widget.route.animation!,
                                  widget.route.secondaryAnimation!,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

abstract class ModalRoute<T> extends TransitionRoute<T> with LocalHistoryRoute<T> {
  ModalRoute({
    super.settings,
    this.filter,
    this.traversalEdgeBehavior,
  });

  final ui.ImageFilter? filter;

  final TraversalEdgeBehavior? traversalEdgeBehavior;

  // The API for general users of this class

  @optionalTypeArgs
  static ModalRoute<T>? of<T extends Object?>(BuildContext context) {
    final _ModalScopeStatus? widget = context.dependOnInheritedWidgetOfExactType<_ModalScopeStatus>();
    return widget?.route as ModalRoute<T>?;
  }

  @protected
  void setState(VoidCallback fn) {
    if (_scopeKey.currentState != null) {
      _scopeKey.currentState!._routeSetState(fn);
    } else {
      // The route isn't currently visible, so we don't have to call its setState
      // method, but we do still need to call the fn callback, otherwise the state
      // in the route won't be updated!
      fn();
    }
  }

  static RoutePredicate withName(String name) {
    return (Route<dynamic> route) {
      return !route.willHandlePopInternally
          && route is ModalRoute
          && route.settings.name == name;
    };
  }

  // The API for subclasses to override - used by _ModalScope

  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation);

  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  @override
  void install() {
    super.install();
    _animationProxy = ProxyAnimation(super.animation);
    _secondaryAnimationProxy = ProxyAnimation(super.secondaryAnimation);
  }

  @override
  TickerFuture didPush() {
    if (_scopeKey.currentState != null && navigator!.widget.requestFocus) {
      navigator!.focusNode.enclosingScope?.setFirstFocus(_scopeKey.currentState!.focusScopeNode);
    }
    return super.didPush();
  }

  @override
  void didAdd() {
    if (_scopeKey.currentState != null && navigator!.widget.requestFocus) {
      navigator!.focusNode.enclosingScope?.setFirstFocus(_scopeKey.currentState!.focusScopeNode);
    }
    super.didAdd();
  }

  // The API for subclasses to override - used by this class

  bool get barrierDismissible;

  bool get semanticsDismissible => true;

  Color? get barrierColor;

  String? get barrierLabel;

  Curve get barrierCurve => Curves.ease;

  bool get maintainState;


  // The API for _ModalScope and HeroController

  bool get offstage => _offstage;
  bool _offstage = false;
  set offstage(bool value) {
    if (_offstage == value) {
      return;
    }
    setState(() {
      _offstage = value;
    });
    _animationProxy!.parent = _offstage ? kAlwaysCompleteAnimation : super.animation;
    _secondaryAnimationProxy!.parent = _offstage ? kAlwaysDismissedAnimation : super.secondaryAnimation;
    changedInternalState();
  }

  BuildContext? get subtreeContext => _subtreeKey.currentContext;

  @override
  Animation<double>? get animation => _animationProxy;
  ProxyAnimation? _animationProxy;

  @override
  Animation<double>? get secondaryAnimation => _secondaryAnimationProxy;
  ProxyAnimation? _secondaryAnimationProxy;

  final List<WillPopCallback> _willPopCallbacks = <WillPopCallback>[];

  final Set<PopEntry> _popEntries = <PopEntry>{};

  @Deprecated(
    'Use popDisposition instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  @override
  Future<RoutePopDisposition> willPop() async {
    final _ModalScopeState<T>? scope = _scopeKey.currentState;
    assert(scope != null);
    for (final WillPopCallback callback in List<WillPopCallback>.of(_willPopCallbacks)) {
      if (!await callback()) {
        return RoutePopDisposition.doNotPop;
      }
    }
    return super.willPop();
  }

  @override
  RoutePopDisposition get popDisposition {
    final bool canPop = _popEntries.every((PopEntry popEntry) {
      return popEntry.canPopNotifier.value;
    });

    if (!canPop) {
      return RoutePopDisposition.doNotPop;
    }
    return super.popDisposition;
  }

  @override
  void onPopInvoked(bool didPop) {
    for (final PopEntry popEntry in _popEntries) {
      popEntry.onPopInvoked?.call(didPop);
    }
  }

  @Deprecated(
    'Use registerPopEntry or PopScope instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  void addScopedWillPopCallback(WillPopCallback callback) {
    assert(_scopeKey.currentState != null, 'Tried to add a willPop callback to a route that is not currently in the tree.');
    _willPopCallbacks.add(callback);
  }

  @Deprecated(
    'Use unregisterPopEntry or PopScope instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  void removeScopedWillPopCallback(WillPopCallback callback) {
    assert(_scopeKey.currentState != null, 'Tried to remove a willPop callback from a route that is not currently in the tree.');
    _willPopCallbacks.remove(callback);
  }

  void registerPopEntry(PopEntry popEntry) {
    _popEntries.add(popEntry);
    popEntry.canPopNotifier.addListener(_handlePopEntryChange);
    _handlePopEntryChange();
  }

  void unregisterPopEntry(PopEntry popEntry) {
    _popEntries.remove(popEntry);
    popEntry.canPopNotifier.removeListener(_handlePopEntryChange);
    _handlePopEntryChange();
  }

  void _handlePopEntryChange() {
    if (!isCurrent) {
      return;
    }
    final NavigationNotification notification = NavigationNotification(
      // canPop indicates that the originator of the Notification can handle a
      // pop. In the case of PopScope, it handles pops when canPop is
      // false. Hence the seemingly backward logic here.
      canHandlePop: popDisposition == RoutePopDisposition.doNotPop,
    );
    // Avoid dispatching a notification in the middle of a build.
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.postFrameCallbacks:
        notification.dispatch(subtreeContext);
      case SchedulerPhase.idle:
      case SchedulerPhase.midFrameMicrotasks:
      case SchedulerPhase.persistentCallbacks:
      case SchedulerPhase.transientCallbacks:
        SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
          if (!(subtreeContext?.mounted ?? false)) {
            return;
          }
          notification.dispatch(subtreeContext);
        });
    }
  }

  @Deprecated(
    'Use popDisposition instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  @protected
  bool get hasScopedWillPopCallback {
    return _willPopCallbacks.isNotEmpty;
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    super.didChangePrevious(previousRoute);
    changedInternalState();
  }

  @override
  void changedInternalState() {
    super.changedInternalState();
    setState(() { /* internal state already changed */ });
    _modalBarrier.markNeedsBuild();
    _modalScope.maintainState = maintainState;
  }

  @override
  void changedExternalState() {
    super.changedExternalState();
    _modalBarrier.markNeedsBuild();
    if (_scopeKey.currentState != null) {
      _scopeKey.currentState!._forceRebuildPage();
    }
  }

  bool get canPop => hasActiveRouteBelow || willHandlePopInternally;

  bool get impliesAppBarDismissal => hasActiveRouteBelow || _entriesImpliesAppBarDismissal > 0;

  // Internals

  final GlobalKey<_ModalScopeState<T>> _scopeKey = GlobalKey<_ModalScopeState<T>>();
  final GlobalKey _subtreeKey = GlobalKey();
  final PageStorageBucket _storageBucket = PageStorageBucket();

  // one of the builders
  late OverlayEntry _modalBarrier;
  Widget _buildModalBarrier(BuildContext context) {
    Widget barrier = buildModalBarrier();
    if (filter != null) {
      barrier = BackdropFilter(
        filter: filter!,
        child: barrier,
      );
    }
    barrier = IgnorePointer(
      ignoring: animation!.status == AnimationStatus.reverse || // changedInternalState is called when animation.status updates
                animation!.status == AnimationStatus.dismissed, // dismissed is possible when doing a manual pop gesture
      child: barrier,
    );
    if (semanticsDismissible && barrierDismissible) {
      // To be sorted after the _modalScope.
      barrier = Semantics(
        sortKey: const OrdinalSortKey(1.0),
        child: barrier,
      );
    }
    return barrier;
  }

  Widget buildModalBarrier() {
    Widget barrier;
    if (barrierColor != null && barrierColor!.alpha != 0 && !offstage) { // changedInternalState is called if barrierColor or offstage updates
      assert(barrierColor != barrierColor!.withOpacity(0.0));
      final Animation<Color?> color = animation!.drive(
        ColorTween(
          begin: barrierColor!.withOpacity(0.0),
          end: barrierColor, // changedInternalState is called if barrierColor updates
        ).chain(CurveTween(curve: barrierCurve)), // changedInternalState is called if barrierCurve updates
      );
      barrier = AnimatedModalBarrier(
        color: color,
        dismissible: barrierDismissible, // changedInternalState is called if barrierDismissible updates
        semanticsLabel: barrierLabel, // changedInternalState is called if barrierLabel updates
        barrierSemanticsDismissible: semanticsDismissible,
      );
    } else {
      barrier = ModalBarrier(
        dismissible: barrierDismissible, // changedInternalState is called if barrierDismissible updates
        semanticsLabel: barrierLabel, // changedInternalState is called if barrierLabel updates
        barrierSemanticsDismissible: semanticsDismissible,
      );
    }

    return barrier;
  }

  // We cache the part of the modal scope that doesn't change from frame to
  // frame so that we minimize the amount of building that happens.
  Widget? _modalScopeCache;

  // one of the builders
  Widget _buildModalScope(BuildContext context) {
    // To be sorted before the _modalBarrier.
    return _modalScopeCache ??= Semantics(
      sortKey: const OrdinalSortKey(0.0),
      child: _ModalScope<T>(
        key: _scopeKey,
        route: this,
        // _ModalScope calls buildTransitions() and buildChild(), defined above
      ),
    );
  }

  late OverlayEntry _modalScope;

  @override
  Iterable<OverlayEntry> createOverlayEntries() {
    return <OverlayEntry>[
      _modalBarrier = OverlayEntry(builder: _buildModalBarrier),
      _modalScope = OverlayEntry(builder: _buildModalScope, maintainState: maintainState),
    ];
  }

  @override
  String toString() => '${objectRuntimeType(this, 'ModalRoute')}($settings, animation: $_animation)';
}

abstract class PopupRoute<T> extends ModalRoute<T> {
  PopupRoute({
    super.settings,
    super.filter,
    super.traversalEdgeBehavior,
  });

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  bool get allowSnapshotting => false;
}

class RouteObserver<R extends Route<dynamic>> extends NavigatorObserver {
  final Map<R, Set<RouteAware>> _listeners = <R, Set<RouteAware>>{};

  @visibleForTesting
  bool debugObservingRoute(R route) {
    late bool contained;
    assert(() {
      contained = _listeners.containsKey(route);
      return true;
    }());
    return contained;
  }

  void subscribe(RouteAware routeAware, R route) {
    final Set<RouteAware> subscribers = _listeners.putIfAbsent(route, () => <RouteAware>{});
    if (subscribers.add(routeAware)) {
      routeAware.didPush();
    }
  }

  void unsubscribe(RouteAware routeAware) {
    final List<R> routes = _listeners.keys.toList();
    for (final R route in routes) {
      final Set<RouteAware>? subscribers = _listeners[route];
      if (subscribers != null) {
        subscribers.remove(routeAware);
        if (subscribers.isEmpty) {
          _listeners.remove(route);
        }
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is R && previousRoute is R) {
      final List<RouteAware>? previousSubscribers = _listeners[previousRoute]?.toList();

      if (previousSubscribers != null) {
        for (final RouteAware routeAware in previousSubscribers) {
          routeAware.didPopNext();
        }
      }

      final List<RouteAware>? subscribers = _listeners[route]?.toList();

      if (subscribers != null) {
        for (final RouteAware routeAware in subscribers) {
          routeAware.didPop();
        }
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is R && previousRoute is R) {
      final Set<RouteAware>? previousSubscribers = _listeners[previousRoute];

      if (previousSubscribers != null) {
        for (final RouteAware routeAware in previousSubscribers) {
          routeAware.didPushNext();
        }
      }
    }
  }
}

abstract mixin class RouteAware {
  void didPopNext() { }

  void didPush() { }

  void didPop() { }

  void didPushNext() { }
}

class RawDialogRoute<T> extends PopupRoute<T> {
  RawDialogRoute({
    required RoutePageBuilder pageBuilder,
    bool barrierDismissible = true,
    Color? barrierColor = const Color(0x80000000),
    String? barrierLabel,
    Duration transitionDuration = const Duration(milliseconds: 200),
    RouteTransitionsBuilder? transitionBuilder,
    super.settings,
    this.anchorPoint,
    super.traversalEdgeBehavior,
  }) : _pageBuilder = pageBuilder,
       _barrierDismissible = barrierDismissible,
       _barrierLabel = barrierLabel,
       _barrierColor = barrierColor,
       _transitionDuration = transitionDuration,
       _transitionBuilder = transitionBuilder;

  final RoutePageBuilder _pageBuilder;

  @override
  bool get barrierDismissible => _barrierDismissible;
  final bool _barrierDismissible;

  @override
  String? get barrierLabel => _barrierLabel;
  final String? _barrierLabel;

  @override
  Color? get barrierColor => _barrierColor;
  final Color? _barrierColor;

  @override
  Duration get transitionDuration => _transitionDuration;
  final Duration _transitionDuration;

  final RouteTransitionsBuilder? _transitionBuilder;

  final Offset? anchorPoint;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: DisplayFeatureSubScreen(
        anchorPoint: anchorPoint,
        child: _pageBuilder(context, animation, secondaryAnimation),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_transitionBuilder == null) {
      // Some default transition.
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.linear,
        ),
        child: child,
      );
    }
    return _transitionBuilder(context, animation, secondaryAnimation, child);
  }
}

Future<T?> showGeneralDialog<T extends Object?>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  bool barrierDismissible = false,
  String? barrierLabel,
  Color barrierColor = const Color(0x80000000),
  Duration transitionDuration = const Duration(milliseconds: 200),
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  assert(!barrierDismissible || barrierLabel != null);
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(RawDialogRoute<T>(
    pageBuilder: pageBuilder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    transitionBuilder: transitionBuilder,
    settings: routeSettings,
    anchorPoint: anchorPoint,
  ));
}

typedef RoutePageBuilder = Widget Function(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation);

typedef RouteTransitionsBuilder = Widget Function(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child);

typedef PopInvokedCallback = void Function(bool didPop);

abstract class PopEntry {
  PopInvokedCallback? get onPopInvoked;

  ValueListenable<bool> get canPopNotifier;

  @override
  String toString() {
    return 'PopEntry canPop: ${canPopNotifier.value}, onPopInvoked: $onPopInvoked';
  }
}