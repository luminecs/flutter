import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';

import 'app_bar.dart';
import 'banner.dart';
import 'banner_theme.dart';
import 'bottom_sheet.dart';
import 'colors.dart';
import 'curves.dart';
import 'debug.dart';
import 'divider.dart';
import 'drawer.dart';
import 'flexible_space_bar.dart';
import 'floating_action_button.dart';
import 'floating_action_button_location.dart';
import 'material.dart';
import 'snack_bar.dart';
import 'snack_bar_theme.dart';
import 'theme.dart';

// Examples can assume:
// late TabController tabController;
// void setState(VoidCallback fn) { }
// late String appBarTitle;
// late int tabCount;
// late TickerProvider tickerProvider;

const FloatingActionButtonLocation _kDefaultFloatingActionButtonLocation = FloatingActionButtonLocation.endFloat;
const FloatingActionButtonAnimator _kDefaultFloatingActionButtonAnimator = FloatingActionButtonAnimator.scaling;

const Curve _standardBottomSheetCurve = standardEasing;
// When the top of the BottomSheet crosses this threshold, it will start to
// shrink the FAB and show a scrim.
const double _kBottomSheetDominatesPercentage = 0.3;
const double _kMinBottomSheetScrimOpacity = 0.1;
const double _kMaxBottomSheetScrimOpacity = 0.6;

enum _ScaffoldSlot {
  body,
  appBar,
  bodyScrim,
  bottomSheet,
  snackBar,
  materialBanner,
  persistentFooter,
  bottomNavigationBar,
  floatingActionButton,
  drawer,
  endDrawer,
  statusBar,
}

class ScaffoldMessenger extends StatefulWidget {
  const ScaffoldMessenger({
    super.key,
    required this.child,
  });

  final Widget child;

  static ScaffoldMessengerState of(BuildContext context) {
    assert(debugCheckHasScaffoldMessenger(context));

    final _ScaffoldMessengerScope scope = context.dependOnInheritedWidgetOfExactType<_ScaffoldMessengerScope>()!;
    return scope._scaffoldMessengerState;
  }

  static ScaffoldMessengerState? maybeOf(BuildContext context) {

    final _ScaffoldMessengerScope? scope = context.dependOnInheritedWidgetOfExactType<_ScaffoldMessengerScope>();
    return scope?._scaffoldMessengerState;
  }

  @override
  ScaffoldMessengerState createState() => ScaffoldMessengerState();
}

class ScaffoldMessengerState extends State<ScaffoldMessenger> with TickerProviderStateMixin {
  final LinkedHashSet<ScaffoldState> _scaffolds = LinkedHashSet<ScaffoldState>();
  final Queue<ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>> _materialBanners = Queue<ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>>();
  AnimationController? _materialBannerController;
  final Queue<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>> _snackBars = Queue<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>>();
  AnimationController? _snackBarController;
  Timer? _snackBarTimer;
  bool? _accessibleNavigation;

  @override
  void didChangeDependencies() {
    final bool accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    // If we transition from accessible navigation to non-accessible navigation
    // and there is a SnackBar that would have timed out that has already
    // completed its timer, dismiss that SnackBar. If the timer hasn't finished
    // yet, let it timeout as normal.
    if ((_accessibleNavigation ?? false)
        && !accessibleNavigation
        && _snackBarTimer != null
        && !_snackBarTimer!.isActive) {
      hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    }
    _accessibleNavigation = accessibleNavigation;
    super.didChangeDependencies();
  }

  void _register(ScaffoldState scaffold) {
    _scaffolds.add(scaffold);

    if (_isRoot(scaffold)) {
      if (_snackBars.isNotEmpty) {
        scaffold._updateSnackBar();
      }

      if (_materialBanners.isNotEmpty) {
        scaffold._updateMaterialBanner();
      }
    }
  }

  void _unregister(ScaffoldState scaffold) {
    final bool removed = _scaffolds.remove(scaffold);
    // ScaffoldStates should only be removed once.
    assert(removed);
  }

  void _updateScaffolds() {
    for (final ScaffoldState scaffold in _scaffolds) {
      if (_isRoot(scaffold)) {
        scaffold._updateSnackBar();
        scaffold._updateMaterialBanner();
      }
    }
  }

  // Nested Scaffolds are handled by the ScaffoldMessenger by only presenting a
  // MaterialBanner or SnackBar in the root Scaffold of the nested set.
  bool _isRoot(ScaffoldState scaffold) {
    final ScaffoldState? parent = scaffold.context.findAncestorStateOfType<ScaffoldState>();
    return parent == null || !_scaffolds.contains(parent);
  }

  // SNACKBAR API

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(SnackBar snackBar) {
    assert(
      _scaffolds.isNotEmpty,
      'ScaffoldMessenger.showSnackBar was called, but there are currently no '
      'descendant Scaffolds to present to.',
    );
    _snackBarController ??= SnackBar.createAnimationController(vsync: this)
      ..addStatusListener(_handleSnackBarStatusChanged);
    if (_snackBars.isEmpty) {
      assert(_snackBarController!.isDismissed);
      _snackBarController!.forward();
    }
    late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
    controller = ScaffoldFeatureController<SnackBar, SnackBarClosedReason>._(
      // We provide a fallback key so that if back-to-back snackbars happen to
      // match in structure, material ink splashes and highlights don't survive
      // from one to the next.
      snackBar.withAnimation(_snackBarController!, fallbackKey: UniqueKey()),
      Completer<SnackBarClosedReason>(),
        () {
          assert(_snackBars.first == controller);
          hideCurrentSnackBar();
        },
      null, // SnackBar doesn't use a builder function so setState() wouldn't rebuild it
    );
    try {
      setState(() {
        _snackBars.addLast(controller);
      });
      _updateScaffolds();
    } catch (exception) {
      assert (() {
        if (exception is FlutterError) {
          final String summary = exception.diagnostics.first.toDescription();
          if (summary == 'setState() or markNeedsBuild() called during build.') {
            final List<DiagnosticsNode> information = <DiagnosticsNode>[
              ErrorSummary('The showSnackBar() method cannot be called during build.'),
              ErrorDescription(
                'The showSnackBar() method was called during build, which is '
                'prohibited as showing snack bars requires updating state. Updating '
                'state is not possible during build.',
              ),
              ErrorHint(
                'Instead of calling showSnackBar() during build, call it directly '
                'in your on tap (and related) callbacks. If you need to immediately '
                'show a snack bar, make the call in initState() or '
                'didChangeDependencies() instead. Otherwise, you can also schedule a '
                'post-frame callback using SchedulerBinding.addPostFrameCallback to '
                'show the snack bar after the current frame.',
              ),
              context.describeOwnershipChain(
                'The ownership chain for the particular ScaffoldMessenger is',
              ),
            ];
            throw FlutterError.fromParts(information);
          }
        }
        return true;
      }());
      rethrow;
    }

    return controller;
  }

  void _handleSnackBarStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
        assert(_snackBars.isNotEmpty);
        setState(() {
          _snackBars.removeFirst();
        });
        _updateScaffolds();
        if (_snackBars.isNotEmpty) {
          _snackBarController!.forward();
        }
      case AnimationStatus.completed:
        setState(() {
          assert(_snackBarTimer == null);
          // build will create a new timer if necessary to dismiss the snackBar.
        });
        _updateScaffolds();
      case AnimationStatus.forward:
        break;
      case AnimationStatus.reverse:
        break;
    }
  }

  void removeCurrentSnackBar({ SnackBarClosedReason reason = SnackBarClosedReason.remove }) {
    if (_snackBars.isEmpty) {
      return;
    }
    final Completer<SnackBarClosedReason> completer = _snackBars.first._completer;
    if (!completer.isCompleted) {
      completer.complete(reason);
    }
    _snackBarTimer?.cancel();
    _snackBarTimer = null;
    // This will trigger the animation's status callback.
    _snackBarController!.value = 0.0;
  }

  void hideCurrentSnackBar({ SnackBarClosedReason reason = SnackBarClosedReason.hide }) {
    if (_snackBars.isEmpty || _snackBarController!.status == AnimationStatus.dismissed) {
      return;
    }
    final Completer<SnackBarClosedReason> completer = _snackBars.first._completer;
    if (_accessibleNavigation!) {
      _snackBarController!.value = 0.0;
      completer.complete(reason);
    } else {
      _snackBarController!.reverse().then<void>((void value) {
        assert(mounted);
        if (!completer.isCompleted) {
          completer.complete(reason);
        }
      });
    }
    _snackBarTimer?.cancel();
    _snackBarTimer = null;
  }

  void clearSnackBars() {
    if (_snackBars.isEmpty || _snackBarController!.status == AnimationStatus.dismissed) {
      return;
    }
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> currentSnackbar = _snackBars.first;
    _snackBars.clear();
    _snackBars.add(currentSnackbar);
    hideCurrentSnackBar();
  }

  // MATERIAL BANNER API

  ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason> showMaterialBanner(MaterialBanner materialBanner) {
    assert(
      _scaffolds.isNotEmpty,
      'ScaffoldMessenger.showMaterialBanner was called, but there are currently no '
      'descendant Scaffolds to present to.',
    );
    _materialBannerController ??= MaterialBanner.createAnimationController(vsync: this)
      ..addStatusListener(_handleMaterialBannerStatusChanged);
    if (_materialBanners.isEmpty) {
      assert(_materialBannerController!.isDismissed);
      _materialBannerController!.forward();
    }
    late ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason> controller;
    controller = ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>._(
      // We provide a fallback key so that if back-to-back material banners happen to
      // match in structure, material ink splashes and highlights don't survive
      // from one to the next.
      materialBanner.withAnimation(_materialBannerController!, fallbackKey: UniqueKey()),
      Completer<MaterialBannerClosedReason>(),
          () {
        assert(_materialBanners.first == controller);
        hideCurrentMaterialBanner();
      },
      null, // MaterialBanner doesn't use a builder function so setState() wouldn't rebuild it
    );
    setState(() {
      _materialBanners.addLast(controller);
    });
    _updateScaffolds();
    return controller;
  }

  void _handleMaterialBannerStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
        assert(_materialBanners.isNotEmpty);
        setState(() {
          _materialBanners.removeFirst();
        });
        _updateScaffolds();
        if (_materialBanners.isNotEmpty) {
          _materialBannerController!.forward();
        }
      case AnimationStatus.completed:
        _updateScaffolds();
      case AnimationStatus.forward:
        break;
      case AnimationStatus.reverse:
        break;
    }
  }

  void removeCurrentMaterialBanner({ MaterialBannerClosedReason reason = MaterialBannerClosedReason.remove }) {
    if (_materialBanners.isEmpty) {
      return;
    }
    final Completer<MaterialBannerClosedReason> completer = _materialBanners.first._completer;
    if (!completer.isCompleted) {
      completer.complete(reason);
    }

    // This will trigger the animation's status callback.
    _materialBannerController!.value = 0.0;
  }

  void hideCurrentMaterialBanner({ MaterialBannerClosedReason reason = MaterialBannerClosedReason.hide }) {
    if (_materialBanners.isEmpty || _materialBannerController!.status == AnimationStatus.dismissed) {
      return;
    }
    final Completer<MaterialBannerClosedReason> completer = _materialBanners.first._completer;
    if (_accessibleNavigation!) {
      _materialBannerController!.value = 0.0;
      completer.complete(reason);
    } else {
      _materialBannerController!.reverse().then<void>((void value) {
        assert(mounted);
        if (!completer.isCompleted) {
          completer.complete(reason);
        }
      });
    }
  }

  void clearMaterialBanners() {
    if (_materialBanners.isEmpty || _materialBannerController!.status == AnimationStatus.dismissed) {
      return;
    }
    final ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason> currentMaterialBanner = _materialBanners.first;
    _materialBanners.clear();
    _materialBanners.add(currentMaterialBanner);
    hideCurrentMaterialBanner();
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    _accessibleNavigation = MediaQuery.accessibleNavigationOf(context);

    if (_snackBars.isNotEmpty) {
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route == null || route.isCurrent) {
        if (_snackBarController!.isCompleted && _snackBarTimer == null) {
          final SnackBar snackBar = _snackBars.first._widget;
          _snackBarTimer = Timer(snackBar.duration, () {
            assert(
              _snackBarController!.status == AnimationStatus.forward ||
                _snackBarController!.status == AnimationStatus.completed,
            );
            // Look up MediaQuery again in case the setting changed.
            if (snackBar.action != null && MediaQuery.accessibleNavigationOf(context)) {
              return;
            }
            hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
          });
        }
      }
    }

    return _ScaffoldMessengerScope(
      scaffoldMessengerState: this,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _snackBarController?.dispose();
    _snackBarTimer?.cancel();
    _snackBarTimer = null;
    super.dispose();
  }
}

class _ScaffoldMessengerScope extends InheritedWidget {
  const _ScaffoldMessengerScope({
    required super.child,
    required ScaffoldMessengerState scaffoldMessengerState,
  }) : _scaffoldMessengerState = scaffoldMessengerState;

  final ScaffoldMessengerState _scaffoldMessengerState;

  @override
  bool updateShouldNotify(_ScaffoldMessengerScope old) => _scaffoldMessengerState != old._scaffoldMessengerState;
}

@immutable
class ScaffoldPrelayoutGeometry {
  const ScaffoldPrelayoutGeometry({
    required this.bottomSheetSize,
    required this.contentBottom,
    required this.contentTop,
    required this.floatingActionButtonSize,
    required this.minInsets,
    required this.minViewPadding,
    required this.scaffoldSize,
    required this.snackBarSize,
    required this.materialBannerSize,
    required this.textDirection,
  });

  final Size floatingActionButtonSize;

  final Size bottomSheetSize;

  final double contentBottom;

  final double contentTop;

  final EdgeInsets minInsets;

  final EdgeInsets minViewPadding;

  final Size scaffoldSize;

  final Size snackBarSize;

  final Size materialBannerSize;

  final TextDirection textDirection;
}

@immutable
class _TransitionSnapshotFabLocation extends FloatingActionButtonLocation {

  const _TransitionSnapshotFabLocation(this.begin, this.end, this.animator, this.progress);

  final FloatingActionButtonLocation begin;
  final FloatingActionButtonLocation end;
  final FloatingActionButtonAnimator animator;
  final double progress;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    return animator.getOffset(
      begin: begin.getOffset(scaffoldGeometry),
      end: end.getOffset(scaffoldGeometry),
      progress: progress,
    );
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, '_TransitionSnapshotFabLocation')}(begin: $begin, end: $end, progress: $progress)';
  }
}

@immutable
class ScaffoldGeometry {
  const ScaffoldGeometry({
    this.bottomNavigationBarTop,
    this.floatingActionButtonArea,
  });

  final double? bottomNavigationBarTop;

  final Rect? floatingActionButtonArea;

  ScaffoldGeometry _scaleFloatingActionButton(double scaleFactor) {
    if (scaleFactor == 1.0) {
      return this;
    }

    if (scaleFactor == 0.0) {
      return ScaffoldGeometry(
        bottomNavigationBarTop: bottomNavigationBarTop,
      );
    }

    final Rect scaledButton = Rect.lerp(
      floatingActionButtonArea!.center & Size.zero,
      floatingActionButtonArea,
      scaleFactor,
    )!;
    return copyWith(floatingActionButtonArea: scaledButton);
  }

  ScaffoldGeometry copyWith({
    double? bottomNavigationBarTop,
    Rect? floatingActionButtonArea,
  }) {
    return ScaffoldGeometry(
      bottomNavigationBarTop: bottomNavigationBarTop ?? this.bottomNavigationBarTop,
      floatingActionButtonArea: floatingActionButtonArea ?? this.floatingActionButtonArea,
    );
  }
}

class _ScaffoldGeometryNotifier extends ChangeNotifier implements ValueListenable<ScaffoldGeometry> {
  _ScaffoldGeometryNotifier(this.geometry, this.context);

  final BuildContext context;
  double? floatingActionButtonScale;
  ScaffoldGeometry geometry;

  @override
  ScaffoldGeometry get value {
    assert(() {
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.owner!.debugDoingPaint) {
        throw FlutterError(
            'Scaffold.geometryOf() must only be accessed during the paint phase.\n'
            'The ScaffoldGeometry is only available during the paint phase, because '
            'its value is computed during the animation and layout phases prior to painting.',
        );
      }
      return true;
    }());
    return geometry._scaleFloatingActionButton(floatingActionButtonScale!);
  }

  void _updateWith({
    double? bottomNavigationBarTop,
    Rect? floatingActionButtonArea,
    double? floatingActionButtonScale,
  }) {
    this.floatingActionButtonScale = floatingActionButtonScale ?? this.floatingActionButtonScale;
    geometry = geometry.copyWith(
      bottomNavigationBarTop: bottomNavigationBarTop,
      floatingActionButtonArea: floatingActionButtonArea,
    );
    notifyListeners();
  }
}

// Used to communicate the height of the Scaffold's bottomNavigationBar and
// persistentFooterButtons to the LayoutBuilder which builds the Scaffold's body.
//
// Scaffold expects a _BodyBoxConstraints to be passed to the _BodyBuilder
// widget's LayoutBuilder, see _ScaffoldLayout.performLayout(). The BoxConstraints
// methods that construct new BoxConstraints objects, like copyWith() have not
// been overridden here because we expect the _BodyBoxConstraintsObject to be
// passed along unmodified to the LayoutBuilder. If that changes in the future
// then _BodyBuilder will assert.
class _BodyBoxConstraints extends BoxConstraints {
  const _BodyBoxConstraints({
    super.maxWidth,
    super.maxHeight,
    required this.bottomWidgetsHeight,
    required this.appBarHeight,
    required this.materialBannerHeight,
  }) : assert(bottomWidgetsHeight >= 0),
       assert(appBarHeight >= 0),
       assert(materialBannerHeight >= 0);

  final double bottomWidgetsHeight;
  final double appBarHeight;
  final double materialBannerHeight;

  // RenderObject.layout() will only short-circuit its call to its performLayout
  // method if the new layout constraints are not == to the current constraints.
  // If the height of the bottom widgets has changed, even though the constraints'
  // min and max values have not, we still want performLayout to happen.
  @override
  bool operator ==(Object other) {
    if (super != other) {
      return false;
    }
    return other is _BodyBoxConstraints
        && other.materialBannerHeight == materialBannerHeight
        && other.bottomWidgetsHeight == bottomWidgetsHeight
        && other.appBarHeight == appBarHeight;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, materialBannerHeight, bottomWidgetsHeight, appBarHeight);
}

// Used when Scaffold.extendBody is true to wrap the scaffold's body in a MediaQuery
// whose padding accounts for the height of the bottomNavigationBar and/or the
// persistentFooterButtons.
//
// The bottom widgets' height is passed along via the _BodyBoxConstraints parameter.
// The constraints parameter is constructed in_ScaffoldLayout.performLayout().
class _BodyBuilder extends StatelessWidget {
  const _BodyBuilder({
    required this.extendBody,
    required this.extendBodyBehindAppBar,
    required this.body,
  });

  final Widget body;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    if (!extendBody && !extendBodyBehindAppBar) {
      return body;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _BodyBoxConstraints bodyConstraints = constraints as _BodyBoxConstraints;
        final MediaQueryData metrics = MediaQuery.of(context);

        final double bottom = extendBody
          ? math.max(metrics.padding.bottom, bodyConstraints.bottomWidgetsHeight)
          : metrics.padding.bottom;

        final double top = extendBodyBehindAppBar
          ? math.max(metrics.padding.top,
              bodyConstraints.appBarHeight + bodyConstraints.materialBannerHeight)
          : metrics.padding.top;

        return MediaQuery(
          data: metrics.copyWith(
            padding: metrics.padding.copyWith(
              top: top,
              bottom: bottom,
            ),
          ),
          child: body,
        );
      },
    );
  }
}

class _ScaffoldLayout extends MultiChildLayoutDelegate {
  _ScaffoldLayout({
    required this.minInsets,
    required this.minViewPadding,
    required this.textDirection,
    required this.geometryNotifier,
    // for floating action button
    required this.previousFloatingActionButtonLocation,
    required this.currentFloatingActionButtonLocation,
    required this.floatingActionButtonMoveAnimationProgress,
    required this.floatingActionButtonMotionAnimator,
    required this.isSnackBarFloating,
    required this.snackBarWidth,
    required this.extendBody,
    required this.extendBodyBehindAppBar,
    required this.extendBodyBehindMaterialBanner,
  });

  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final EdgeInsets minInsets;
  final EdgeInsets minViewPadding;
  final TextDirection textDirection;
  final _ScaffoldGeometryNotifier geometryNotifier;

  final FloatingActionButtonLocation previousFloatingActionButtonLocation;
  final FloatingActionButtonLocation currentFloatingActionButtonLocation;
  final double floatingActionButtonMoveAnimationProgress;
  final FloatingActionButtonAnimator floatingActionButtonMotionAnimator;

  final bool isSnackBarFloating;
  final double? snackBarWidth;

  final bool extendBodyBehindMaterialBanner;

  @override
  void performLayout(Size size) {
    final BoxConstraints looseConstraints = BoxConstraints.loose(size);

    // This part of the layout has the same effect as putting the app bar and
    // body in a column and making the body flexible. What's different is that
    // in this case the app bar appears _after_ the body in the stacking order,
    // so the app bar's shadow is drawn on top of the body.

    final BoxConstraints fullWidthConstraints = looseConstraints.tighten(width: size.width);
    final double bottom = size.height;
    double contentTop = 0.0;
    double bottomWidgetsHeight = 0.0;
    double appBarHeight = 0.0;

    if (hasChild(_ScaffoldSlot.appBar)) {
      appBarHeight = layoutChild(_ScaffoldSlot.appBar, fullWidthConstraints).height;
      contentTop = extendBodyBehindAppBar ? 0.0 : appBarHeight;
      positionChild(_ScaffoldSlot.appBar, Offset.zero);
    }

    double? bottomNavigationBarTop;
    if (hasChild(_ScaffoldSlot.bottomNavigationBar)) {
      final double bottomNavigationBarHeight = layoutChild(_ScaffoldSlot.bottomNavigationBar, fullWidthConstraints).height;
      bottomWidgetsHeight += bottomNavigationBarHeight;
      bottomNavigationBarTop = math.max(0.0, bottom - bottomWidgetsHeight);
      positionChild(_ScaffoldSlot.bottomNavigationBar, Offset(0.0, bottomNavigationBarTop));
    }

    if (hasChild(_ScaffoldSlot.persistentFooter)) {
      final BoxConstraints footerConstraints = BoxConstraints(
        maxWidth: fullWidthConstraints.maxWidth,
        maxHeight: math.max(0.0, bottom - bottomWidgetsHeight - contentTop),
      );
      final double persistentFooterHeight = layoutChild(_ScaffoldSlot.persistentFooter, footerConstraints).height;
      bottomWidgetsHeight += persistentFooterHeight;
      positionChild(_ScaffoldSlot.persistentFooter, Offset(0.0, math.max(0.0, bottom - bottomWidgetsHeight)));
    }

    Size materialBannerSize = Size.zero;
    if (hasChild(_ScaffoldSlot.materialBanner)) {
      materialBannerSize = layoutChild(_ScaffoldSlot.materialBanner, fullWidthConstraints);
      positionChild(_ScaffoldSlot.materialBanner, Offset(0.0, appBarHeight));

      // Push content down only if elevation is 0.
      if (!extendBodyBehindMaterialBanner) {
        contentTop += materialBannerSize.height;
      }
    }

    // Set the content bottom to account for the greater of the height of any
    // bottom-anchored material widgets or of the keyboard or other
    // bottom-anchored system UI.
    final double contentBottom = math.max(0.0, bottom - math.max(minInsets.bottom, bottomWidgetsHeight));

    if (hasChild(_ScaffoldSlot.body)) {
      double bodyMaxHeight = math.max(0.0, contentBottom - contentTop);

      if (extendBody) {
        bodyMaxHeight += bottomWidgetsHeight;
        bodyMaxHeight = clampDouble(bodyMaxHeight, 0.0, looseConstraints.maxHeight - contentTop);
        assert(bodyMaxHeight <= math.max(0.0, looseConstraints.maxHeight - contentTop));
      }

      final BoxConstraints bodyConstraints = _BodyBoxConstraints(
        maxWidth: fullWidthConstraints.maxWidth,
        maxHeight: bodyMaxHeight,
        materialBannerHeight: materialBannerSize.height,
        bottomWidgetsHeight: extendBody ? bottomWidgetsHeight : 0.0,
        appBarHeight: appBarHeight,
      );
      layoutChild(_ScaffoldSlot.body, bodyConstraints);
      positionChild(_ScaffoldSlot.body, Offset(0.0, contentTop));
    }

    // The BottomSheet and the SnackBar are anchored to the bottom of the parent,
    // they're as wide as the parent and are given their intrinsic height. The
    // only difference is that SnackBar appears on the top side of the
    // BottomNavigationBar while the BottomSheet is stacked on top of it.
    //
    // If all three elements are present then either the center of the FAB straddles
    // the top edge of the BottomSheet or the bottom of the FAB is
    // kFloatingActionButtonMargin above the SnackBar, whichever puts the FAB
    // the farthest above the bottom of the parent. If only the FAB is has a
    // non-zero height then it's inset from the parent's right and bottom edges
    // by kFloatingActionButtonMargin.

    Size bottomSheetSize = Size.zero;
    Size snackBarSize = Size.zero;
    if (hasChild(_ScaffoldSlot.bodyScrim)) {
      final BoxConstraints bottomSheetScrimConstraints = BoxConstraints(
        maxWidth: fullWidthConstraints.maxWidth,
        maxHeight: contentBottom,
      );
      layoutChild(_ScaffoldSlot.bodyScrim, bottomSheetScrimConstraints);
      positionChild(_ScaffoldSlot.bodyScrim, Offset.zero);
    }

    // Set the size of the SnackBar early if the behavior is fixed so
    // the FAB can be positioned correctly.
    if (hasChild(_ScaffoldSlot.snackBar) && !isSnackBarFloating) {
      snackBarSize = layoutChild(_ScaffoldSlot.snackBar, fullWidthConstraints);
    }

    if (hasChild(_ScaffoldSlot.bottomSheet)) {
      final BoxConstraints bottomSheetConstraints = BoxConstraints(
        maxWidth: fullWidthConstraints.maxWidth,
        maxHeight: math.max(0.0, contentBottom - contentTop),
      );
      bottomSheetSize = layoutChild(_ScaffoldSlot.bottomSheet, bottomSheetConstraints);
      positionChild(_ScaffoldSlot.bottomSheet, Offset((size.width - bottomSheetSize.width) / 2.0, contentBottom - bottomSheetSize.height));
    }

    late Rect floatingActionButtonRect;
    if (hasChild(_ScaffoldSlot.floatingActionButton)) {
      final Size fabSize = layoutChild(_ScaffoldSlot.floatingActionButton, looseConstraints);

      // To account for the FAB position being changed, we'll animate between
      // the old and new positions.
      final ScaffoldPrelayoutGeometry currentGeometry = ScaffoldPrelayoutGeometry(
        bottomSheetSize: bottomSheetSize,
        contentBottom: contentBottom,
        contentTop: appBarHeight,
        floatingActionButtonSize: fabSize,
        minInsets: minInsets,
        scaffoldSize: size,
        snackBarSize: snackBarSize,
        materialBannerSize: materialBannerSize,
        textDirection: textDirection,
        minViewPadding: minViewPadding,
      );
      final Offset currentFabOffset = currentFloatingActionButtonLocation.getOffset(currentGeometry);
      final Offset previousFabOffset = previousFloatingActionButtonLocation.getOffset(currentGeometry);
      final Offset fabOffset = floatingActionButtonMotionAnimator.getOffset(
        begin: previousFabOffset,
        end: currentFabOffset,
        progress: floatingActionButtonMoveAnimationProgress,
      );
      positionChild(_ScaffoldSlot.floatingActionButton, fabOffset);
      floatingActionButtonRect = fabOffset & fabSize;
    }

    if (hasChild(_ScaffoldSlot.snackBar)) {
      final bool hasCustomWidth = snackBarWidth != null && snackBarWidth! < size.width;
      if (snackBarSize == Size.zero) {
        snackBarSize = layoutChild(
          _ScaffoldSlot.snackBar,
          hasCustomWidth ? looseConstraints : fullWidthConstraints,
        );
      }

      final double snackBarYOffsetBase;
      final bool showAboveFab = switch (currentFloatingActionButtonLocation) {
        FloatingActionButtonLocation.startTop
        || FloatingActionButtonLocation.centerTop
        || FloatingActionButtonLocation.endTop
        || FloatingActionButtonLocation.miniStartTop
        || FloatingActionButtonLocation.miniCenterTop
        || FloatingActionButtonLocation.miniEndTop => false,
        FloatingActionButtonLocation.startDocked
        || FloatingActionButtonLocation.startFloat
        || FloatingActionButtonLocation.centerDocked
        || FloatingActionButtonLocation.centerFloat
        || FloatingActionButtonLocation.endContained
        || FloatingActionButtonLocation.endDocked
        || FloatingActionButtonLocation.endFloat
        || FloatingActionButtonLocation.miniStartDocked
        || FloatingActionButtonLocation.miniStartFloat
        || FloatingActionButtonLocation.miniCenterDocked
        || FloatingActionButtonLocation.miniCenterFloat
        || FloatingActionButtonLocation.miniEndDocked
        || FloatingActionButtonLocation.miniEndFloat => true,
        FloatingActionButtonLocation() => true,
      };
      if (floatingActionButtonRect.size != Size.zero && isSnackBarFloating && showAboveFab) {
        snackBarYOffsetBase = floatingActionButtonRect.top;
      } else {
        // SnackBarBehavior.fixed applies a SafeArea automatically.
        // SnackBarBehavior.floating does not since the positioning is affected
        // if there is a FloatingActionButton (see condition above). If there is
        // no FAB, make sure we account for safe space when the SnackBar is
        // floating.
        final double safeYOffsetBase = size.height - minViewPadding.bottom;
        snackBarYOffsetBase = isSnackBarFloating
          ? math.min(contentBottom, safeYOffsetBase)
          : contentBottom;
      }

      final double xOffset = hasCustomWidth ? (size.width - snackBarWidth!) / 2 : 0.0;
      positionChild(_ScaffoldSlot.snackBar, Offset(xOffset, snackBarYOffsetBase - snackBarSize.height));

      assert((){
        // Whether a floating SnackBar has been offset too high.
        //
        // To improve the developer experience, this assert is done after the call to positionChild.
        // if we assert sooner the SnackBar is visible because its defaults position is (0,0) and
        // it can cause confusion to the user as the error message states that the SnackBar is off screen.
        if (isSnackBarFloating) {
          final bool snackBarVisible = (snackBarYOffsetBase - snackBarSize.height) >= 0;
          if (!snackBarVisible) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('Floating SnackBar presented off screen.'),
              ErrorDescription(
                'A SnackBar with behavior property set to SnackBarBehavior.floating is fully '
                'or partially off screen because some or all the widgets provided to '
                'Scaffold.floatingActionButton, Scaffold.persistentFooterButtons and '
                'Scaffold.bottomNavigationBar take up too much vertical space.\n'
              ),
              ErrorHint(
                'Consider constraining the size of these widgets to allow room for the SnackBar to be visible.',
              ),
            ]);
          }
        }
        return true;
      }());
    }

    if (hasChild(_ScaffoldSlot.statusBar)) {
      layoutChild(_ScaffoldSlot.statusBar, fullWidthConstraints.tighten(height: minInsets.top));
      positionChild(_ScaffoldSlot.statusBar, Offset.zero);
    }

    if (hasChild(_ScaffoldSlot.drawer)) {
      layoutChild(_ScaffoldSlot.drawer, BoxConstraints.tight(size));
      positionChild(_ScaffoldSlot.drawer, Offset.zero);
    }

    if (hasChild(_ScaffoldSlot.endDrawer)) {
      layoutChild(_ScaffoldSlot.endDrawer, BoxConstraints.tight(size));
      positionChild(_ScaffoldSlot.endDrawer, Offset.zero);
    }

    geometryNotifier._updateWith(
      bottomNavigationBarTop: bottomNavigationBarTop,
      floatingActionButtonArea: floatingActionButtonRect,
    );
  }

  @override
  bool shouldRelayout(_ScaffoldLayout oldDelegate) {
    return oldDelegate.minInsets != minInsets
      || oldDelegate.minViewPadding != minViewPadding
      || oldDelegate.textDirection != textDirection
      || oldDelegate.floatingActionButtonMoveAnimationProgress != floatingActionButtonMoveAnimationProgress
      || oldDelegate.previousFloatingActionButtonLocation != previousFloatingActionButtonLocation
      || oldDelegate.currentFloatingActionButtonLocation != currentFloatingActionButtonLocation
      || oldDelegate.extendBody != extendBody
      || oldDelegate.extendBodyBehindAppBar != extendBodyBehindAppBar;
  }
}

class _FloatingActionButtonTransition extends StatefulWidget {
  const _FloatingActionButtonTransition({
    required this.child,
    required this.fabMoveAnimation,
    required this.fabMotionAnimator,
    required this.geometryNotifier,
    required this.currentController,
  });

  final Widget? child;
  final Animation<double> fabMoveAnimation;
  final FloatingActionButtonAnimator fabMotionAnimator;
  final _ScaffoldGeometryNotifier geometryNotifier;

  final AnimationController currentController;

  @override
  _FloatingActionButtonTransitionState createState() => _FloatingActionButtonTransitionState();
}

class _FloatingActionButtonTransitionState extends State<_FloatingActionButtonTransition> with TickerProviderStateMixin {
  // The animations applied to the Floating Action Button when it is entering or exiting.
  // Controls the previous widget.child as it exits.
  late AnimationController _previousController;
  late Animation<double> _previousScaleAnimation;
  late Animation<double> _previousRotationAnimation;
  // The animations to run, considering the widget's fabMoveAnimation and the current/previous entrance/exit animations.
  late Animation<double> _currentScaleAnimation;
  late Animation<double> _extendedCurrentScaleAnimation;
  late Animation<double> _currentRotationAnimation;
  Widget? _previousChild;

  @override
  void initState() {
    super.initState();

    _previousController = AnimationController(
      duration: kFloatingActionButtonSegue,
      vsync: this,
    )..addStatusListener(_handlePreviousAnimationStatusChanged);
    _updateAnimations();

    if (widget.child != null) {
      // If we start out with a child, have the child appear fully visible instead
      // of animating in.
      widget.currentController.value = 1.0;
    } else {
      // If we start without a child we update the geometry object with a
      // floating action button scale of 0, as it is not showing on the screen.
      _updateGeometryScale(0.0);
    }
  }

  @override
  void dispose() {
    _previousController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_FloatingActionButtonTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fabMotionAnimator != widget.fabMotionAnimator || oldWidget.fabMoveAnimation != widget.fabMoveAnimation) {
      // Get the right scale and rotation animations to use for this widget.
      _updateAnimations();
    }
    final bool oldChildIsNull = oldWidget.child == null;
    final bool newChildIsNull = widget.child == null;
    if (oldChildIsNull == newChildIsNull && oldWidget.child?.key == widget.child?.key) {
      return;
    }
    if (_previousController.status == AnimationStatus.dismissed) {
      final double currentValue = widget.currentController.value;
      if (currentValue == 0.0 || oldWidget.child == null) {
        // The current child hasn't started its entrance animation yet. We can
        // just skip directly to the new child's entrance.
        _previousChild = null;
        if (widget.child != null) {
          widget.currentController.forward();
        }
      } else {
        // Otherwise, we need to copy the state from the current controller to
        // the previous controller and run an exit animation for the previous
        // widget before running the entrance animation for the new child.
        _previousChild = oldWidget.child;
        _previousController
          ..value = currentValue
          ..reverse();
        widget.currentController.value = 0.0;
      }
    }
  }

  static final Animatable<double> _entranceTurnTween = Tween<double>(
    begin: 1.0 - kFloatingActionButtonTurnInterval,
    end: 1.0,
  ).chain(CurveTween(curve: Curves.easeIn));

  void _updateAnimations() {
    // Get the animations for exit and entrance.
    final CurvedAnimation previousExitScaleAnimation = CurvedAnimation(
      parent: _previousController,
      curve: Curves.easeIn,
    );
    final Animation<double> previousExitRotationAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _previousController,
        curve: Curves.easeIn,
      ),
    );

    final CurvedAnimation currentEntranceScaleAnimation = CurvedAnimation(
      parent: widget.currentController,
      curve: Curves.easeIn,
    );
    final Animation<double> currentEntranceRotationAnimation = widget.currentController.drive(_entranceTurnTween);

    // Get the animations for when the FAB is moving.
    final Animation<double> moveScaleAnimation = widget.fabMotionAnimator.getScaleAnimation(parent: widget.fabMoveAnimation);
    final Animation<double> moveRotationAnimation = widget.fabMotionAnimator.getRotationAnimation(parent: widget.fabMoveAnimation);

    // Aggregate the animations.
    _previousScaleAnimation = AnimationMin<double>(moveScaleAnimation, previousExitScaleAnimation);
    _currentScaleAnimation = AnimationMin<double>(moveScaleAnimation, currentEntranceScaleAnimation);
    _extendedCurrentScaleAnimation = _currentScaleAnimation.drive(CurveTween(curve: const Interval(0.0, 0.1)));

    _previousRotationAnimation = TrainHoppingAnimation(previousExitRotationAnimation, moveRotationAnimation);
    _currentRotationAnimation = TrainHoppingAnimation(currentEntranceRotationAnimation, moveRotationAnimation);

    _currentScaleAnimation.addListener(_onProgressChanged);
    _previousScaleAnimation.addListener(_onProgressChanged);
  }

  void _handlePreviousAnimationStatusChanged(AnimationStatus status) {
    setState(() {
      if (widget.child != null && status == AnimationStatus.dismissed) {
        assert(widget.currentController.status == AnimationStatus.dismissed);
        widget.currentController.forward();
      }
    });
  }

  bool _isExtendedFloatingActionButton(Widget? widget) {
    return widget is FloatingActionButton
        && widget.isExtended;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: <Widget>[
        if (_previousController.status != AnimationStatus.dismissed)
          if (_isExtendedFloatingActionButton(_previousChild))
            FadeTransition(
              opacity: _previousScaleAnimation,
              child: _previousChild,
            )
          else
            ScaleTransition(
              scale: _previousScaleAnimation,
              child: RotationTransition(
                turns: _previousRotationAnimation,
                child: _previousChild,
              ),
            ),
        if (_isExtendedFloatingActionButton(widget.child))
          ScaleTransition(
            scale: _extendedCurrentScaleAnimation,
            child: FadeTransition(
              opacity: _currentScaleAnimation,
              child: widget.child,
            ),
          )
        else
          ScaleTransition(
            scale: _currentScaleAnimation,
            child: RotationTransition(
              turns: _currentRotationAnimation,
              child: widget.child,
            ),
          ),
      ],
    );
  }

  void _onProgressChanged() {
    _updateGeometryScale(math.max(_previousScaleAnimation.value, _currentScaleAnimation.value));
  }

  void _updateGeometryScale(double scale) {
    widget.geometryNotifier._updateWith(
      floatingActionButtonScale: scale,
    );
  }
}

class Scaffold extends StatefulWidget {
  const Scaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.persistentFooterAlignment = AlignmentDirectional.centerEnd,
    this.drawer,
    this.onDrawerChanged,
    this.endDrawer,
    this.onEndDrawerChanged,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.drawerDragStartBehavior = DragStartBehavior.start,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerScrimColor,
    this.drawerEdgeDragWidth,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    this.restorationId,
  });

  final bool extendBody;

  final bool extendBodyBehindAppBar;

  final PreferredSizeWidget? appBar;

  final Widget? body;

  final Widget? floatingActionButton;

  final FloatingActionButtonLocation? floatingActionButtonLocation;

  final FloatingActionButtonAnimator? floatingActionButtonAnimator;

  final List<Widget>? persistentFooterButtons;

  final AlignmentDirectional persistentFooterAlignment;

  final Widget? drawer;

  final DrawerCallback? onDrawerChanged;

  final Widget? endDrawer;

  final DrawerCallback? onEndDrawerChanged;

  final Color? drawerScrimColor;

  final Color? backgroundColor;

  final Widget? bottomNavigationBar;

  final Widget? bottomSheet;

  final bool? resizeToAvoidBottomInset;

  final bool primary;

  final DragStartBehavior drawerDragStartBehavior;

  final double? drawerEdgeDragWidth;

  final bool drawerEnableOpenDragGesture;

  final bool endDrawerEnableOpenDragGesture;

  final String? restorationId;

  static ScaffoldState of(BuildContext context) {
    final ScaffoldState? result = context.findAncestorStateOfType<ScaffoldState>();
    if (result != null) {
      return result;
    }
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
        'Scaffold.of() called with a context that does not contain a Scaffold.',
      ),
      ErrorDescription(
        'No Scaffold ancestor could be found starting from the context that was passed to Scaffold.of(). '
        'This usually happens when the context provided is from the same StatefulWidget as that '
        'whose build function actually creates the Scaffold widget being sought.',
      ),
      ErrorHint(
        'There are several ways to avoid this problem. The simplest is to use a Builder to get a '
        'context that is "under" the Scaffold. For an example of this, please see the '
        'documentation for Scaffold.of():\n'
        '  https://api.flutter.dev/flutter/material/Scaffold/of.html',
      ),
      ErrorHint(
        'A more efficient solution is to split your build function into several widgets. This '
        'introduces a new context from which you can obtain the Scaffold. In this solution, '
        'you would have an outer widget that creates the Scaffold populated by instances of '
        'your new inner widgets, and then in these inner widgets you would use Scaffold.of().\n'
        'A less elegant but more expedient solution is assign a GlobalKey to the Scaffold, '
        'then use the key.currentState property to obtain the ScaffoldState rather than '
        'using the Scaffold.of() function.',
      ),
      context.describeElement('The context used was'),
    ]);
  }

  static ScaffoldState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ScaffoldState>();
  }

  static ValueListenable<ScaffoldGeometry> geometryOf(BuildContext context) {
    final _ScaffoldScope? scaffoldScope = context.dependOnInheritedWidgetOfExactType<_ScaffoldScope>();
    if (scaffoldScope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'Scaffold.geometryOf() called with a context that does not contain a Scaffold.',
        ),
        ErrorDescription(
          'This usually happens when the context provided is from the same StatefulWidget as that '
          'whose build function actually creates the Scaffold widget being sought.',
        ),
        ErrorHint(
          'There are several ways to avoid this problem. The simplest is to use a Builder to get a '
          'context that is "under" the Scaffold. For an example of this, please see the '
          'documentation for Scaffold.of():\n'
          '  https://api.flutter.dev/flutter/material/Scaffold/of.html',
        ),
        ErrorHint(
          'A more efficient solution is to split your build function into several widgets. This '
          'introduces a new context from which you can obtain the Scaffold. In this solution, '
          'you would have an outer widget that creates the Scaffold populated by instances of '
          'your new inner widgets, and then in these inner widgets you would use Scaffold.geometryOf().',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scaffoldScope.geometryNotifier;
  }

  static bool hasDrawer(BuildContext context, { bool registerForUpdates = true }) {
    if (registerForUpdates) {
      final _ScaffoldScope? scaffold = context.dependOnInheritedWidgetOfExactType<_ScaffoldScope>();
      return scaffold?.hasDrawer ?? false;
    } else {
      final ScaffoldState? scaffold = context.findAncestorStateOfType<ScaffoldState>();
      return scaffold?.hasDrawer ?? false;
    }
  }

  @override
  ScaffoldState createState() => ScaffoldState();
}

class ScaffoldState extends State<Scaffold> with TickerProviderStateMixin, RestorationMixin {
  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_drawerOpened, 'drawer_open');
    registerForRestoration(_endDrawerOpened, 'end_drawer_open');
  }

  // DRAWER API

  final GlobalKey<DrawerControllerState> _drawerKey = GlobalKey<DrawerControllerState>();
  final GlobalKey<DrawerControllerState> _endDrawerKey = GlobalKey<DrawerControllerState>();

  final GlobalKey _bodyKey = GlobalKey();

  bool get hasAppBar => widget.appBar != null;
  bool get hasDrawer => widget.drawer != null;
  bool get hasEndDrawer => widget.endDrawer != null;
  bool get hasFloatingActionButton => widget.floatingActionButton != null;

  double? _appBarMaxHeight;
  double? get appBarMaxHeight => _appBarMaxHeight;
  final RestorableBool _drawerOpened = RestorableBool(false);
  final RestorableBool _endDrawerOpened = RestorableBool(false);

  bool get isDrawerOpen => _drawerOpened.value;

  bool get isEndDrawerOpen => _endDrawerOpened.value;

  void _drawerOpenedCallback(bool isOpened) {
    if (_drawerOpened.value != isOpened && _drawerKey.currentState != null) {
      setState(() {
        _drawerOpened.value = isOpened;
      });
      widget.onDrawerChanged?.call(isOpened);
    }
  }

  void _endDrawerOpenedCallback(bool isOpened) {
    if (_endDrawerOpened.value != isOpened && _endDrawerKey.currentState != null) {
      setState(() {
        _endDrawerOpened.value = isOpened;
      });
      widget.onEndDrawerChanged?.call(isOpened);
    }
  }

  void openDrawer() {
    if (_endDrawerKey.currentState != null && _endDrawerOpened.value) {
      _endDrawerKey.currentState!.close();
    }
    _drawerKey.currentState?.open();
  }

  void openEndDrawer() {
    if (_drawerKey.currentState != null && _drawerOpened.value) {
      _drawerKey.currentState!.close();
    }
    _endDrawerKey.currentState?.open();
  }

  // Used for both the snackbar and material banner APIs
  ScaffoldMessengerState? _scaffoldMessenger;

  // SNACKBAR API
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _messengerSnackBar;

  // This is used to update the _messengerSnackBar by the ScaffoldMessenger.
  void _updateSnackBar() {
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? messengerSnackBar = _scaffoldMessenger!._snackBars.isNotEmpty
        ? _scaffoldMessenger!._snackBars.first
        : null;

    if (_messengerSnackBar != messengerSnackBar) {
      setState(() {
        _messengerSnackBar = messengerSnackBar;
      });
    }
  }

  // MATERIAL BANNER API

  // The _messengerMaterialBanner represents the current MaterialBanner being managed by
  // the ScaffoldMessenger, instead of the Scaffold.
  ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>? _messengerMaterialBanner;

  // This is used to update the _messengerMaterialBanner by the ScaffoldMessenger.
  void _updateMaterialBanner() {
    final ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>? messengerMaterialBanner = _scaffoldMessenger!._materialBanners.isNotEmpty
        ? _scaffoldMessenger!._materialBanners.first
        : null;

    if (_messengerMaterialBanner != messengerMaterialBanner) {
      setState(() {
        _messengerMaterialBanner = messengerMaterialBanner;
      });
    }
  }

  // PERSISTENT BOTTOM SHEET API

  // Contains bottom sheets that may still be animating out of view.
  // Important if the app/user takes an action that could repeatedly show a
  // bottom sheet.
  final List<_StandardBottomSheet> _dismissedBottomSheets = <_StandardBottomSheet>[];
  PersistentBottomSheetController<dynamic>? _currentBottomSheet;
  final GlobalKey _currentBottomSheetKey = GlobalKey();
  LocalHistoryEntry? _persistentSheetHistoryEntry;

  void _maybeBuildPersistentBottomSheet() {
    if (widget.bottomSheet != null && _currentBottomSheet == null) {
      // The new _currentBottomSheet is not a local history entry so a "back" button
      // will not be added to the Scaffold's appbar and the bottom sheet will not
      // support drag or swipe to dismiss.
      final AnimationController animationController = BottomSheet.createAnimationController(this)..value = 1.0;
      bool persistentBottomSheetExtentChanged(DraggableScrollableNotification notification) {
        if (notification.extent - notification.initialExtent > precisionErrorTolerance) {
          if (_persistentSheetHistoryEntry == null) {
            _persistentSheetHistoryEntry = LocalHistoryEntry(onRemove: () {
              DraggableScrollableActuator.reset(notification.context);
              showBodyScrim(false, 0.0);
              _floatingActionButtonVisibilityValue = 1.0;
              _persistentSheetHistoryEntry = null;
            });
            ModalRoute.of(context)!.addLocalHistoryEntry(_persistentSheetHistoryEntry!);
          }
        } else if (_persistentSheetHistoryEntry != null) {
          _persistentSheetHistoryEntry!.remove();
        }
        return false;
      }

      // Stop the animation and unmount the dismissed sheets from the tree immediately,
      // otherwise may cause duplicate GlobalKey assertion if the sheet sub-tree contains
      // GlobalKey widgets.
      if (_dismissedBottomSheets.isNotEmpty) {
        final List<_StandardBottomSheet> sheets = List<_StandardBottomSheet>.of(_dismissedBottomSheets, growable: false);
        for (final _StandardBottomSheet sheet in sheets) {
          sheet.animationController.reset();
        }
        assert(_dismissedBottomSheets.isEmpty);
      }

      _currentBottomSheet = _buildBottomSheet<void>(
        (BuildContext context) {
          return NotificationListener<DraggableScrollableNotification>(
            onNotification: persistentBottomSheetExtentChanged,
            child: DraggableScrollableActuator(
              child: StatefulBuilder(
                key: _currentBottomSheetKey,
                builder: (BuildContext context, StateSetter setState) {
                  return widget.bottomSheet ?? const SizedBox.shrink();
                },
              ),
            ),
          );
        },
        isPersistent: true,
        animationController: animationController,
      );
    }
  }

  void _closeCurrentBottomSheet() {
    if (_currentBottomSheet != null) {
      if (!_currentBottomSheet!._isLocalHistoryEntry) {
        _currentBottomSheet!.close();
      }
      assert(() {
        _currentBottomSheet?._completer.future.whenComplete(() {
          assert(_currentBottomSheet == null);
        });
        return true;
      }());
    }
  }

  void closeDrawer() {
   if (hasDrawer && isDrawerOpen) {
     _drawerKey.currentState!.close();
   }
  }

  void closeEndDrawer() {
    if (hasEndDrawer && isEndDrawerOpen) {
      _endDrawerKey.currentState!.close();
    }
  }

  void _updatePersistentBottomSheet() {
    _currentBottomSheetKey.currentState!.setState(() {});
  }

  PersistentBottomSheetController<T> _buildBottomSheet<T>(
    WidgetBuilder builder, {
    required bool isPersistent,
    required AnimationController animationController,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool? enableDrag,
    bool shouldDisposeAnimationController = true,
  }) {
    assert(() {
      if (widget.bottomSheet != null && isPersistent && _currentBottomSheet != null) {
        throw FlutterError(
          'Scaffold.bottomSheet cannot be specified while a bottom sheet '
          'displayed with showBottomSheet() is still visible.\n'
          'Rebuild the Scaffold with a null bottomSheet before calling showBottomSheet().',
        );
      }
      return true;
    }());

    final Completer<T> completer = Completer<T>();
    final GlobalKey<_StandardBottomSheetState> bottomSheetKey = GlobalKey<_StandardBottomSheetState>();
    late _StandardBottomSheet bottomSheet;

    bool removedEntry = false;
    bool doingDispose = false;

    void removePersistentSheetHistoryEntryIfNeeded() {
      assert(isPersistent);
      if (_persistentSheetHistoryEntry != null) {
        _persistentSheetHistoryEntry!.remove();
        _persistentSheetHistoryEntry = null;
      }
    }

    void removeCurrentBottomSheet() {
      removedEntry = true;
      if (_currentBottomSheet == null) {
        return;
      }
      assert(_currentBottomSheet!._widget == bottomSheet);
      assert(bottomSheetKey.currentState != null);
      _showFloatingActionButton();

      if (isPersistent) {
        removePersistentSheetHistoryEntryIfNeeded();
      }

      bottomSheetKey.currentState!.close();
      setState(() {
        _showBodyScrim = false;
        _bodyScrimColor = Colors.black.withOpacity(0.0);
        _currentBottomSheet = null;
      });

      if (animationController.status != AnimationStatus.dismissed) {
        _dismissedBottomSheets.add(bottomSheet);
      }
      completer.complete();
    }

    final LocalHistoryEntry? entry = isPersistent
      ? null
      : LocalHistoryEntry(onRemove: () {
          if (!removedEntry && _currentBottomSheet?._widget == bottomSheet && !doingDispose) {
            removeCurrentBottomSheet();
          }
        });

    void removeEntryIfNeeded() {
      if (!isPersistent && !removedEntry) {
        assert(entry != null);
        entry!.remove();
        removedEntry = true;
      }
    }

    bottomSheet = _StandardBottomSheet(
      key: bottomSheetKey,
      animationController: animationController,
      enableDrag: enableDrag ?? !isPersistent,
      onClosing: () {
        if (_currentBottomSheet == null) {
          return;
        }
        assert(_currentBottomSheet!._widget == bottomSheet);
        removeEntryIfNeeded();
      },
      onDismissed: () {
        if (_dismissedBottomSheets.contains(bottomSheet)) {
          setState(() {
            _dismissedBottomSheets.remove(bottomSheet);
          });
        }
      },
      onDispose: () {
        doingDispose = true;
        removeEntryIfNeeded();
        if (shouldDisposeAnimationController) {
          animationController.dispose();
        }
      },
      builder: builder,
      isPersistent: isPersistent,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
    );

    if (!isPersistent) {
      ModalRoute.of(context)!.addLocalHistoryEntry(entry!);
    }

    return PersistentBottomSheetController<T>._(
      bottomSheet,
      completer,
      entry != null
        ? entry.remove
        : removeCurrentBottomSheet,
      (VoidCallback fn) { bottomSheetKey.currentState?.setState(fn); },
      !isPersistent,
    );
  }

  PersistentBottomSheetController<T> showBottomSheet<T>(
    WidgetBuilder builder, {
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool? enableDrag,
    AnimationController? transitionAnimationController,
  }) {
    assert(() {
      if (widget.bottomSheet != null) {
        throw FlutterError(
          'Scaffold.bottomSheet cannot be specified while a bottom sheet '
          'displayed with showBottomSheet() is still visible.\n'
          'Rebuild the Scaffold with a null bottomSheet before calling showBottomSheet().',
        );
      }
      return true;
    }());
    assert(debugCheckHasMediaQuery(context));

    _closeCurrentBottomSheet();
    final AnimationController controller = (transitionAnimationController ?? BottomSheet.createAnimationController(this))..forward();
    setState(() {
      _currentBottomSheet = _buildBottomSheet<T>(
        builder,
        isPersistent: false,
        animationController: controller,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
        enableDrag: enableDrag,
        shouldDisposeAnimationController: transitionAnimationController == null,
      );
    });
    return _currentBottomSheet! as PersistentBottomSheetController<T>;
  }

  // Floating Action Button API
  late AnimationController _floatingActionButtonMoveController;
  late FloatingActionButtonAnimator _floatingActionButtonAnimator;
  FloatingActionButtonLocation? _previousFloatingActionButtonLocation;
  FloatingActionButtonLocation? _floatingActionButtonLocation;

  late AnimationController _floatingActionButtonVisibilityController;

  double get _floatingActionButtonVisibilityValue => _floatingActionButtonVisibilityController.value;

  set _floatingActionButtonVisibilityValue(double newValue) {
    _floatingActionButtonVisibilityController.value = clampDouble(newValue,
      _floatingActionButtonVisibilityController.lowerBound,
      _floatingActionButtonVisibilityController.upperBound,
    );
  }

  TickerFuture _showFloatingActionButton() {
    return _floatingActionButtonVisibilityController.forward();
  }

  // Moves the Floating Action Button to the new Floating Action Button Location.
  void _moveFloatingActionButton(final FloatingActionButtonLocation newLocation) {
    FloatingActionButtonLocation? previousLocation = _floatingActionButtonLocation;
    double restartAnimationFrom = 0.0;
    // If the Floating Action Button is moving right now, we need to start from a snapshot of the current transition.
    if (_floatingActionButtonMoveController.isAnimating) {
      previousLocation = _TransitionSnapshotFabLocation(_previousFloatingActionButtonLocation!, _floatingActionButtonLocation!, _floatingActionButtonAnimator, _floatingActionButtonMoveController.value);
      restartAnimationFrom = _floatingActionButtonAnimator.getAnimationRestart(_floatingActionButtonMoveController.value);
    }

    setState(() {
      _previousFloatingActionButtonLocation = previousLocation;
      _floatingActionButtonLocation = newLocation;
    });

    // Animate the motion even when the fab is null so that if the exit animation is running,
    // the old fab will start the motion transition while it exits instead of jumping to the
    // new position.
    _floatingActionButtonMoveController.forward(from: restartAnimationFrom);
  }

  // iOS FEATURES - status bar tap, back gesture

  // On iOS, tapping the status bar scrolls the app's primary scrollable to the
  // top. We implement this by looking up the primary scroll controller and
  // scrolling it to the top when tapped.
  void _handleStatusBarTap() {
    final ScrollController? primaryScrollController = PrimaryScrollController.maybeOf(context);
    if (primaryScrollController != null && primaryScrollController.hasClients) {
      primaryScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCirc,
      );
    }
  }

  // INTERNALS

  late _ScaffoldGeometryNotifier _geometryNotifier;

  bool get _resizeToAvoidBottomInset {
    return widget.resizeToAvoidBottomInset ?? true;
  }

  @override
  void initState() {
    super.initState();
    _geometryNotifier = _ScaffoldGeometryNotifier(const ScaffoldGeometry(), context);
    _floatingActionButtonLocation = widget.floatingActionButtonLocation ?? _kDefaultFloatingActionButtonLocation;
    _floatingActionButtonAnimator = widget.floatingActionButtonAnimator ?? _kDefaultFloatingActionButtonAnimator;
    _previousFloatingActionButtonLocation = _floatingActionButtonLocation;
    _floatingActionButtonMoveController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: kFloatingActionButtonSegue * 2,
    );

    _floatingActionButtonVisibilityController = AnimationController(
      duration: kFloatingActionButtonSegue,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(Scaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the Floating Action Button Animator, and then schedule the Floating Action Button for repositioning.
    if (widget.floatingActionButtonAnimator != oldWidget.floatingActionButtonAnimator) {
      _floatingActionButtonAnimator = widget.floatingActionButtonAnimator ?? _kDefaultFloatingActionButtonAnimator;
    }
    if (widget.floatingActionButtonLocation != oldWidget.floatingActionButtonLocation) {
      _moveFloatingActionButton(widget.floatingActionButtonLocation ?? _kDefaultFloatingActionButtonLocation);
    }
    if (widget.bottomSheet != oldWidget.bottomSheet) {
      assert(() {
        if (widget.bottomSheet != null && (_currentBottomSheet?._isLocalHistoryEntry ?? false)) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'Scaffold.bottomSheet cannot be specified while a bottom sheet displayed '
              'with showBottomSheet() is still visible.',
            ),
            ErrorHint(
              'Use the PersistentBottomSheetController '
              'returned by showBottomSheet() to close the old bottom sheet before creating '
              'a Scaffold with a (non null) bottomSheet.',
            ),
          ]);
        }
        return true;
      }());
      if (widget.bottomSheet == null) {
        _closeCurrentBottomSheet();
      } else if (widget.bottomSheet != null && oldWidget.bottomSheet == null) {
        _maybeBuildPersistentBottomSheet();
      } else {
        _updatePersistentBottomSheet();
      }
    }
  }

  @override
  void didChangeDependencies() {
    // Using maybeOf is valid here since both the Scaffold and ScaffoldMessenger
    // are currently available for managing SnackBars.
    final ScaffoldMessengerState? currentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    // If our ScaffoldMessenger has changed, unregister with the old one first.
    if (_scaffoldMessenger != null &&
      (currentScaffoldMessenger == null || _scaffoldMessenger != currentScaffoldMessenger)) {
      _scaffoldMessenger?._unregister(this);
    }
    // Register with the current ScaffoldMessenger, if there is one.
    _scaffoldMessenger = currentScaffoldMessenger;
    _scaffoldMessenger?._register(this);

    _maybeBuildPersistentBottomSheet();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _geometryNotifier.dispose();
    _floatingActionButtonMoveController.dispose();
    _floatingActionButtonVisibilityController.dispose();
    _scaffoldMessenger?._unregister(this);
    _drawerOpened.dispose();
    _endDrawerOpened.dispose();
    super.dispose();
  }

  void _addIfNonNull(
    List<LayoutId> children,
    Widget? child,
    Object childId, {
    required bool removeLeftPadding,
    required bool removeTopPadding,
    required bool removeRightPadding,
    required bool removeBottomPadding,
    bool removeBottomInset = false,
    bool maintainBottomViewPadding = false,
  }) {
    MediaQueryData data = MediaQuery.of(context).removePadding(
      removeLeft: removeLeftPadding,
      removeTop: removeTopPadding,
      removeRight: removeRightPadding,
      removeBottom: removeBottomPadding,
    );
    if (removeBottomInset) {
      data = data.removeViewInsets(removeBottom: true);
    }

    if (maintainBottomViewPadding && data.viewInsets.bottom != 0.0) {
      data = data.copyWith(
        padding: data.padding.copyWith(bottom: data.viewPadding.bottom),
      );
    }

    if (child != null) {
      children.add(
        LayoutId(
          id: childId,
          child: MediaQuery(data: data, child: child),
        ),
      );
    }
  }

  void _buildEndDrawer(List<LayoutId> children, TextDirection textDirection) {
    if (widget.endDrawer != null) {
      assert(hasEndDrawer);
      _addIfNonNull(
        children,
        DrawerController(
          key: _endDrawerKey,
          alignment: DrawerAlignment.end,
          drawerCallback: _endDrawerOpenedCallback,
          dragStartBehavior: widget.drawerDragStartBehavior,
          scrimColor: widget.drawerScrimColor,
          edgeDragWidth: widget.drawerEdgeDragWidth,
          enableOpenDragGesture: widget.endDrawerEnableOpenDragGesture,
          isDrawerOpen: _endDrawerOpened.value,
          child: widget.endDrawer!,
        ),
        _ScaffoldSlot.endDrawer,
        // remove the side padding from the side we're not touching
        removeLeftPadding: textDirection == TextDirection.ltr,
        removeTopPadding: false,
        removeRightPadding: textDirection == TextDirection.rtl,
        removeBottomPadding: false,
      );
    }
  }

  void _buildDrawer(List<LayoutId> children, TextDirection textDirection) {
    if (widget.drawer != null) {
      assert(hasDrawer);
      _addIfNonNull(
        children,
        DrawerController(
          key: _drawerKey,
          alignment: DrawerAlignment.start,
          drawerCallback: _drawerOpenedCallback,
          dragStartBehavior: widget.drawerDragStartBehavior,
          scrimColor: widget.drawerScrimColor,
          edgeDragWidth: widget.drawerEdgeDragWidth,
          enableOpenDragGesture: widget.drawerEnableOpenDragGesture,
          isDrawerOpen: _drawerOpened.value,
          child: widget.drawer!,
        ),
        _ScaffoldSlot.drawer,
        // remove the side padding from the side we're not touching
        removeLeftPadding: textDirection == TextDirection.rtl,
        removeTopPadding: false,
        removeRightPadding: textDirection == TextDirection.ltr,
        removeBottomPadding: false,
      );
    }
  }

  bool _showBodyScrim = false;
  Color _bodyScrimColor = Colors.black;

  void showBodyScrim(bool value, double opacity) {
    if (_showBodyScrim == value && _bodyScrimColor.opacity == opacity) {
      return;
    }
    setState(() {
      _showBodyScrim = value;
      _bodyScrimColor = Colors.black.withOpacity(opacity);
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasDirectionality(context));
    final ThemeData themeData = Theme.of(context);
    final TextDirection textDirection = Directionality.of(context);

    final List<LayoutId> children = <LayoutId>[];
    _addIfNonNull(
      children,
      widget.body == null ? null : _BodyBuilder(
        extendBody: widget.extendBody,
        extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
        body: KeyedSubtree(key: _bodyKey, child: widget.body!),
      ),
      _ScaffoldSlot.body,
      removeLeftPadding: false,
      removeTopPadding: widget.appBar != null,
      removeRightPadding: false,
      removeBottomPadding: widget.bottomNavigationBar != null || widget.persistentFooterButtons != null,
      removeBottomInset: _resizeToAvoidBottomInset,
    );
    if (_showBodyScrim) {
      _addIfNonNull(
        children,
        ModalBarrier(
          dismissible: false,
          color: _bodyScrimColor,
        ),
        _ScaffoldSlot.bodyScrim,
        removeLeftPadding: true,
        removeTopPadding: true,
        removeRightPadding: true,
        removeBottomPadding: true,
      );
    }

    if (widget.appBar != null) {
      final double topPadding = widget.primary ? MediaQuery.paddingOf(context).top : 0.0;
      _appBarMaxHeight = AppBar.preferredHeightFor(context, widget.appBar!.preferredSize) + topPadding;
      assert(_appBarMaxHeight! >= 0.0 && _appBarMaxHeight!.isFinite);
      _addIfNonNull(
        children,
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: _appBarMaxHeight!),
          child: FlexibleSpaceBar.createSettings(
            currentExtent: _appBarMaxHeight!,
            child: widget.appBar!,
          ),
        ),
        _ScaffoldSlot.appBar,
        removeLeftPadding: false,
        removeTopPadding: false,
        removeRightPadding: false,
        removeBottomPadding: true,
      );
    }

    bool isSnackBarFloating = false;
    double? snackBarWidth;

    if (_currentBottomSheet != null || _dismissedBottomSheets.isNotEmpty) {
      final Widget stack = Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          ..._dismissedBottomSheets,
          if (_currentBottomSheet != null) _currentBottomSheet!._widget,
        ],
      );
      _addIfNonNull(
        children,
        stack,
        _ScaffoldSlot.bottomSheet,
        removeLeftPadding: false,
        removeTopPadding: true,
        removeRightPadding: false,
        removeBottomPadding: _resizeToAvoidBottomInset,
      );
    }

    // SnackBar set by ScaffoldMessenger
    if (_messengerSnackBar != null) {
      final SnackBarBehavior snackBarBehavior = _messengerSnackBar?._widget.behavior
        ?? themeData.snackBarTheme.behavior
        ?? SnackBarBehavior.fixed;
      isSnackBarFloating = snackBarBehavior == SnackBarBehavior.floating;
      snackBarWidth = _messengerSnackBar?._widget.width ?? themeData.snackBarTheme.width;

      _addIfNonNull(
        children,
        _messengerSnackBar?._widget,
        _ScaffoldSlot.snackBar,
        removeLeftPadding: false,
        removeTopPadding: true,
        removeRightPadding: false,
        removeBottomPadding: widget.bottomNavigationBar != null || widget.persistentFooterButtons != null,
        maintainBottomViewPadding: !_resizeToAvoidBottomInset,
      );
    }

    bool extendBodyBehindMaterialBanner = false;
    // MaterialBanner set by ScaffoldMessenger
    if (_messengerMaterialBanner != null) {
      final MaterialBannerThemeData bannerTheme = MaterialBannerTheme.of(context);
      final double elevation = _messengerMaterialBanner?._widget.elevation ?? bannerTheme.elevation ?? 0.0;
      extendBodyBehindMaterialBanner = elevation != 0.0;

      _addIfNonNull(
        children,
        _messengerMaterialBanner?._widget,
        _ScaffoldSlot.materialBanner,
        removeLeftPadding: false,
        removeTopPadding: widget.appBar != null,
        removeRightPadding: false,
        removeBottomPadding: true,
        maintainBottomViewPadding: !_resizeToAvoidBottomInset,
      );
    }

    if (widget.persistentFooterButtons != null) {
      _addIfNonNull(
        children,
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: Divider.createBorderSide(context, width: 1.0),
            ),
          ),
          child: SafeArea(
            top: false,
            child: IntrinsicHeight(
              child: Container(
                alignment: widget.persistentFooterAlignment,
                padding: const EdgeInsets.all(8),
                child: OverflowBar(
                  spacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: widget.persistentFooterButtons!,
                ),
              ),
            ),
          ),
        ),
        _ScaffoldSlot.persistentFooter,
        removeLeftPadding: false,
        removeTopPadding: true,
        removeRightPadding: false,
        removeBottomPadding: widget.bottomNavigationBar != null,
        maintainBottomViewPadding: !_resizeToAvoidBottomInset,
      );
    }

    if (widget.bottomNavigationBar != null) {
      _addIfNonNull(
        children,
        widget.bottomNavigationBar,
        _ScaffoldSlot.bottomNavigationBar,
        removeLeftPadding: false,
        removeTopPadding: true,
        removeRightPadding: false,
        removeBottomPadding: false,
        maintainBottomViewPadding: !_resizeToAvoidBottomInset,
      );
    }

    _addIfNonNull(
      children,
      _FloatingActionButtonTransition(
        fabMoveAnimation: _floatingActionButtonMoveController,
        fabMotionAnimator: _floatingActionButtonAnimator,
        geometryNotifier: _geometryNotifier,
        currentController: _floatingActionButtonVisibilityController,
        child: widget.floatingActionButton,
      ),
      _ScaffoldSlot.floatingActionButton,
      removeLeftPadding: true,
      removeTopPadding: true,
      removeRightPadding: true,
      removeBottomPadding: true,
    );

    switch (themeData.platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        _addIfNonNull(
          children,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleStatusBarTap,
            // iOS accessibility automatically adds scroll-to-top to the clock in the status bar
            excludeFromSemantics: true,
          ),
          _ScaffoldSlot.statusBar,
          removeLeftPadding: false,
          removeTopPadding: true,
          removeRightPadding: false,
          removeBottomPadding: true,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        break;
    }

    if (_endDrawerOpened.value) {
      _buildDrawer(children, textDirection);
      _buildEndDrawer(children, textDirection);
    } else {
      _buildEndDrawer(children, textDirection);
      _buildDrawer(children, textDirection);
    }

    // The minimum insets for contents of the Scaffold to keep visible.
    final EdgeInsets minInsets = MediaQuery.paddingOf(context).copyWith(
      bottom: _resizeToAvoidBottomInset ? MediaQuery.viewInsetsOf(context).bottom : 0.0,
    );

    // The minimum viewPadding for interactive elements positioned by the
    // Scaffold to keep within safe interactive areas.
    final EdgeInsets minViewPadding = MediaQuery.viewPaddingOf(context).copyWith(
      bottom: _resizeToAvoidBottomInset && MediaQuery.viewInsetsOf(context).bottom != 0.0 ? 0.0 : null,
    );

    // extendBody locked when keyboard is open
    final bool extendBody = minInsets.bottom <= 0 && widget.extendBody;

    return _ScaffoldScope(
      hasDrawer: hasDrawer,
      geometryNotifier: _geometryNotifier,
      child: ScrollNotificationObserver(
        child: Material(
          color: widget.backgroundColor ?? themeData.scaffoldBackgroundColor,
          child: AnimatedBuilder(animation: _floatingActionButtonMoveController, builder: (BuildContext context, Widget? child) {
            return Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: _DismissDrawerAction(context),
              },
              child: CustomMultiChildLayout(
                delegate: _ScaffoldLayout(
                  extendBody: extendBody,
                  extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
                  minInsets: minInsets,
                  minViewPadding: minViewPadding,
                  currentFloatingActionButtonLocation: _floatingActionButtonLocation!,
                  floatingActionButtonMoveAnimationProgress: _floatingActionButtonMoveController.value,
                  floatingActionButtonMotionAnimator: _floatingActionButtonAnimator,
                  geometryNotifier: _geometryNotifier,
                  previousFloatingActionButtonLocation: _previousFloatingActionButtonLocation!,
                  textDirection: textDirection,
                  isSnackBarFloating: isSnackBarFloating,
                  extendBodyBehindMaterialBanner: extendBodyBehindMaterialBanner,
                  snackBarWidth: snackBarWidth,
                ),
                children: children,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DismissDrawerAction extends DismissAction {
  _DismissDrawerAction(this.context);

  final BuildContext context;

  @override
  bool isEnabled(DismissIntent intent) {
    return Scaffold.of(context).isDrawerOpen || Scaffold.of(context).isEndDrawerOpen;
  }

  @override
  void invoke(DismissIntent intent) {
    Scaffold.of(context).closeDrawer();
    Scaffold.of(context).closeEndDrawer();
  }
}

class ScaffoldFeatureController<T extends Widget, U> {
  const ScaffoldFeatureController._(this._widget, this._completer, this.close, this.setState);
  final T _widget;
  final Completer<U> _completer;

  Future<U> get closed => _completer.future;

  final VoidCallback close;

  final StateSetter? setState;
}

// TODO(guidezpl): Look into making this public. A copy of this class is in
//  bottom_sheet.dart, for now, https://github.com/flutter/flutter/issues/51627
class _BottomSheetSuspendedCurve extends ParametricCurve<double> {
  const _BottomSheetSuspendedCurve(
      this.startingPoint, {
        this.curve = Curves.easeOutCubic,
      });

  final double startingPoint;

  final Curve curve;

  @override
  double transform(double t) {
    assert(t >= 0.0 && t <= 1.0);
    assert(startingPoint >= 0.0 && startingPoint <= 1.0);

    if (t < startingPoint) {
      return t;
    }

    if (t == 1.0) {
      return t;
    }

    final double curveProgress = (t - startingPoint) / (1 - startingPoint);
    final double transformed = curve.transform(curveProgress);
    return lerpDouble(startingPoint, 1, transformed)!;
  }

  @override
  String toString() {
    return '${describeIdentity(this)}($startingPoint, $curve)';
  }
}

class _StandardBottomSheet extends StatefulWidget {
  const _StandardBottomSheet({
    super.key,
    required this.animationController,
    this.enableDrag = true,
    required this.onClosing,
    required this.onDismissed,
    required this.builder,
    this.isPersistent = false,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.onDispose,
  });

  final AnimationController animationController; // we control it, but it must be disposed by whoever created it.
  final bool enableDrag;
  final VoidCallback? onClosing;
  final VoidCallback? onDismissed;
  final VoidCallback? onDispose;
  final WidgetBuilder builder;
  final bool isPersistent;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;

  @override
  _StandardBottomSheetState createState() => _StandardBottomSheetState();
}

class _StandardBottomSheetState extends State<_StandardBottomSheet> {
  ParametricCurve<double> animationCurve = _standardBottomSheetCurve;

  @override
  void initState() {
    super.initState();
    assert(
      widget.animationController.status == AnimationStatus.forward
        || widget.animationController.status == AnimationStatus.completed,
    );
    widget.animationController.addStatusListener(_handleStatusChange);
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  void didUpdateWidget(_StandardBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.animationController == oldWidget.animationController);
  }

  void close() {
    widget.animationController.reverse();
    widget.onClosing?.call();
  }

  void _handleDragStart(DragStartDetails details) {
    // Allow the bottom sheet to track the user's finger accurately.
    animationCurve = Curves.linear;
  }

  void _handleDragEnd(DragEndDetails details, { bool? isClosing }) {
    // Allow the bottom sheet to animate smoothly from its current position.
    animationCurve = _BottomSheetSuspendedCurve(
      widget.animationController.value,
      curve: _standardBottomSheetCurve,
    );
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      widget.onDismissed?.call();
    }
  }

  bool extentChanged(DraggableScrollableNotification notification) {
    final double extentRemaining = 1.0 - notification.extent;
    final ScaffoldState scaffold = Scaffold.of(context);
    if (extentRemaining < _kBottomSheetDominatesPercentage) {
      scaffold._floatingActionButtonVisibilityValue = extentRemaining * _kBottomSheetDominatesPercentage * 10;
      scaffold.showBodyScrim(true,  math.max(
        _kMinBottomSheetScrimOpacity,
        _kMaxBottomSheetScrimOpacity - scaffold._floatingActionButtonVisibilityValue,
      ));
    } else {
      scaffold._floatingActionButtonVisibilityValue = 1.0;
      scaffold.showBodyScrim(false, 0.0);
    }
    // If the Scaffold.bottomSheet != null, we're a persistent bottom sheet.
    if (notification.extent == notification.minExtent &&
        scaffold.widget.bottomSheet == null &&
        notification.shouldCloseOnMinExtent) {
      close();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (BuildContext context, Widget? child) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: animationCurve.transform(widget.animationController.value),
          child: child,
        );
      },
      child: Semantics(
        container: true,
        onDismiss: !widget.isPersistent ? close : null,
        child:  NotificationListener<DraggableScrollableNotification>(
          onNotification: extentChanged,
          child: BottomSheet(
            animationController: widget.animationController,
            enableDrag: widget.enableDrag,
            onDragStart: _handleDragStart,
            onDragEnd: _handleDragEnd,
            onClosing: widget.onClosing!,
            builder: widget.builder,
            backgroundColor: widget.backgroundColor,
            elevation: widget.elevation,
            shape: widget.shape,
            clipBehavior: widget.clipBehavior,
            constraints: widget.constraints,
          ),
        ),
      ),
    );
  }

}

class PersistentBottomSheetController<T> extends ScaffoldFeatureController<_StandardBottomSheet, T> {
  const PersistentBottomSheetController._(
    super.widget,
    super.completer,
    super.close,
    StateSetter super.setState,
    this._isLocalHistoryEntry,
  ) : super._();

  final bool _isLocalHistoryEntry;
}

class _ScaffoldScope extends InheritedWidget {
  const _ScaffoldScope({
    required this.hasDrawer,
    required this.geometryNotifier,
    required super.child,
  });

  final bool hasDrawer;
  final _ScaffoldGeometryNotifier geometryNotifier;

  @override
  bool updateShouldNotify(_ScaffoldScope oldWidget) {
    return hasDrawer != oldWidget.hasDrawer;
  }
}