// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'feedback.dart';
import 'ink_highlight.dart';
import 'material.dart';
import 'material_state.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

abstract class InteractiveInkFeature extends InkFeature {
  InteractiveInkFeature({
    required super.controller,
    required super.referenceBox,
    required Color color,
    ShapeBorder? customBorder,
    super.onRemoved,
  }) : _color = color,
       _customBorder = customBorder;

  void confirm() { }

  void cancel() { }

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) {
      return;
    }
    _color = value;
    controller.markNeedsPaint();
  }

  ShapeBorder? get customBorder => _customBorder;
  ShapeBorder? _customBorder;
  set customBorder(ShapeBorder? value) {
    if (value == _customBorder) {
      return;
    }
    _customBorder = value;
    controller.markNeedsPaint();
  }

  @protected
  void paintInkCircle({
    required Canvas canvas,
    required Matrix4 transform,
    required Paint paint,
    required Offset center,
    required double radius,
    TextDirection? textDirection,
    ShapeBorder? customBorder,
    BorderRadius borderRadius = BorderRadius.zero,
    RectCallback? clipCallback,
  }) {

    final Offset? originOffset = MatrixUtils.getAsTranslation(transform);
    canvas.save();
    if (originOffset == null) {
      canvas.transform(transform.storage);
    } else {
      canvas.translate(originOffset.dx, originOffset.dy);
    }
    if (clipCallback != null) {
      final Rect rect = clipCallback();
      if (customBorder != null) {
        canvas.clipPath(customBorder.getOuterPath(rect, textDirection: textDirection));
      } else if (borderRadius != BorderRadius.zero) {
        canvas.clipRRect(RRect.fromRectAndCorners(
          rect,
          topLeft: borderRadius.topLeft, topRight: borderRadius.topRight,
          bottomLeft: borderRadius.bottomLeft, bottomRight: borderRadius.bottomRight,
        ));
      } else {
        canvas.clipRect(rect);
      }
    }
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }
}

abstract class InteractiveInkFeatureFactory {
  const InteractiveInkFeatureFactory();

  @factory
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  });
}

abstract class _ParentInkResponseState {
  void markChildInkResponsePressed(_ParentInkResponseState childState, bool value);
}

class _ParentInkResponseProvider extends InheritedWidget {
  const _ParentInkResponseProvider({
    required this.state,
    required super.child,
  });

  final _ParentInkResponseState state;

  @override
  bool updateShouldNotify(_ParentInkResponseProvider oldWidget) => state != oldWidget.state;

  static _ParentInkResponseState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ParentInkResponseProvider>()?.state;
  }
}

typedef _GetRectCallback = RectCallback? Function(RenderBox referenceBox);
typedef _CheckContext = bool Function(BuildContext context);

class InkResponse extends StatelessWidget {
  const InkResponse({
    super.key,
    this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapCancel,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.containedInkWell = false,
    this.highlightShape = BoxShape.circle,
    this.radius,
    this.borderRadius,
    this.customBorder,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.overlayColor,
    this.splashColor,
    this.splashFactory,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.statesController,
    this.hoverDuration,
  });

  final Widget? child;

  final GestureTapCallback? onTap;

  final GestureTapDownCallback? onTapDown;

  final GestureTapUpCallback? onTapUp;

  final GestureTapCallback? onTapCancel;

  final GestureTapCallback? onDoubleTap;

  final GestureLongPressCallback? onLongPress;

  final GestureTapCallback? onSecondaryTap;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapCallback? onSecondaryTapCancel;

  final ValueChanged<bool>? onHighlightChanged;

  final ValueChanged<bool>? onHover;

  final MouseCursor? mouseCursor;

  final bool containedInkWell;

  final BoxShape highlightShape;

  final double? radius;

  final BorderRadius? borderRadius;

  final ShapeBorder? customBorder;

  final Color? focusColor;

  final Color? hoverColor;

  final Color? highlightColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final Color? splashColor;

  final InteractiveInkFeatureFactory? splashFactory;

  final bool enableFeedback;

  final bool excludeFromSemantics;

  final ValueChanged<bool>? onFocusChange;

  final bool autofocus;

  final FocusNode? focusNode;

  final bool canRequestFocus;

  RectCallback? getRectCallback(RenderBox referenceBox) => null;

  final MaterialStatesController? statesController;

  final Duration? hoverDuration;

  @override
  Widget build(BuildContext context) {
    final _ParentInkResponseState? parentState = _ParentInkResponseProvider.maybeOf(context);
    return _InkResponseStateWidget(
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapUp: onSecondaryTapUp,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapCancel: onSecondaryTapCancel,
      onHighlightChanged: onHighlightChanged,
      onHover: onHover,
      mouseCursor: mouseCursor,
      containedInkWell: containedInkWell,
      highlightShape: highlightShape,
      radius: radius,
      borderRadius: borderRadius,
      customBorder: customBorder,
      focusColor: focusColor,
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      overlayColor: overlayColor,
      splashColor: splashColor,
      splashFactory: splashFactory,
      enableFeedback: enableFeedback,
      excludeFromSemantics: excludeFromSemantics,
      focusNode: focusNode,
      canRequestFocus: canRequestFocus,
      onFocusChange: onFocusChange,
      autofocus: autofocus,
      parentState: parentState,
      getRectCallback: getRectCallback,
      debugCheckContext: debugCheckContext,
      statesController: statesController,
      hoverDuration: hoverDuration,
      child: child,
    );
  }

  @mustCallSuper
  bool debugCheckContext(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasDirectionality(context));
    return true;
  }
}

class _InkResponseStateWidget extends StatefulWidget {
  const _InkResponseStateWidget({
    this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapCancel,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.containedInkWell = false,
    this.highlightShape = BoxShape.circle,
    this.radius,
    this.borderRadius,
    this.customBorder,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.overlayColor,
    this.splashColor,
    this.splashFactory,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.parentState,
    this.getRectCallback,
    required this.debugCheckContext,
    this.statesController,
    this.hoverDuration,
  });

  final Widget? child;
  final GestureTapCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCallback? onTapCancel;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final GestureTapDownCallback? onSecondaryTapDown;
  final GestureTapCallback? onSecondaryTapCancel;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool containedInkWell;
  final BoxShape highlightShape;
  final double? radius;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final MaterialStateProperty<Color?>? overlayColor;
  final Color? splashColor;
  final InteractiveInkFeatureFactory? splashFactory;
  final bool enableFeedback;
  final bool excludeFromSemantics;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool canRequestFocus;
  final _ParentInkResponseState? parentState;
  final _GetRectCallback? getRectCallback;
  final _CheckContext debugCheckContext;
  final MaterialStatesController? statesController;
  final Duration? hoverDuration;

  @override
  _InkResponseState createState() => _InkResponseState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final List<String> gestures = <String>[
      if (onTap != null) 'tap',
      if (onDoubleTap != null) 'double tap',
      if (onLongPress != null) 'long press',
      if (onTapDown != null) 'tap down',
      if (onTapUp != null) 'tap up',
      if (onTapCancel != null) 'tap cancel',
      if (onSecondaryTap != null) 'secondary tap',
      if (onSecondaryTapUp != null) 'secondary tap up',
      if (onSecondaryTapDown != null) 'secondary tap down',
      if (onSecondaryTapCancel != null) 'secondary tap cancel'
    ];
    properties.add(IterableProperty<String>('gestures', gestures, ifEmpty: '<none>'));
    properties.add(DiagnosticsProperty<MouseCursor>('mouseCursor', mouseCursor));
    properties.add(DiagnosticsProperty<bool>('containedInkWell', containedInkWell, level: DiagnosticLevel.fine));
    properties.add(DiagnosticsProperty<BoxShape>(
      'highlightShape',
      highlightShape,
      description: '${containedInkWell ? "clipped to " : ""}$highlightShape',
      showName: false,
    ));
  }
}

enum _HighlightType {
  pressed,
  hover,
  focus,
}

class _InkResponseState extends State<_InkResponseStateWidget>
  with AutomaticKeepAliveClientMixin<_InkResponseStateWidget>
  implements _ParentInkResponseState
{
  Set<InteractiveInkFeature>? _splashes;
  InteractiveInkFeature? _currentSplash;
  bool _hovering = false;
  final Map<_HighlightType, InkHighlight?> _highlights = <_HighlightType, InkHighlight?>{};
  late final Map<Type, Action<Intent>> _actionMap = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: activateOnIntent),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: activateOnIntent),
  };
  MaterialStatesController? internalStatesController;

  bool get highlightsExist => _highlights.values.where((InkHighlight? highlight) => highlight != null).isNotEmpty;

  final ObserverList<_ParentInkResponseState> _activeChildren = ObserverList<_ParentInkResponseState>();

  static const Duration _activationDuration = Duration(milliseconds: 100);
  Timer? _activationTimer;

  @override
  void markChildInkResponsePressed(_ParentInkResponseState childState, bool value) {
    final bool lastAnyPressed = _anyChildInkResponsePressed;
    if (value) {
      _activeChildren.add(childState);
    } else {
      _activeChildren.remove(childState);
    }
    final bool nowAnyPressed = _anyChildInkResponsePressed;
    if (nowAnyPressed != lastAnyPressed) {
      widget.parentState?.markChildInkResponsePressed(this, nowAnyPressed);
    }
  }
  bool get _anyChildInkResponsePressed => _activeChildren.isNotEmpty;

  void activateOnIntent(Intent? intent) {
    _activationTimer?.cancel();
    _activationTimer = null;
    _startNewSplash(context: context);
    _currentSplash?.confirm();
    _currentSplash = null;
    if (widget.onTap != null) {
      if (widget.enableFeedback) {
        Feedback.forTap(context);
      }
      widget.onTap?.call();
    }
    // Delay the call to `updateHighlight` to simulate a pressed delay
    // and give MaterialStatesController listeners a chance to react.
    _activationTimer = Timer(_activationDuration, () {
      updateHighlight(_HighlightType.pressed, value: false);
    });
  }

  void simulateTap([Intent? intent]) {
    _startNewSplash(context: context);
    handleTap();
  }

  void simulateLongPress() {
    _startNewSplash(context: context);
    handleLongPress();
  }

  void handleStatesControllerChange() {
    // Force a rebuild to resolve widget.overlayColor, widget.mouseCursor
    setState(() { });
  }

  MaterialStatesController get statesController => widget.statesController ?? internalStatesController!;

  void initStatesController() {
    if (widget.statesController == null) {
      internalStatesController = MaterialStatesController();
    }
    statesController.update(MaterialState.disabled, !enabled);
    statesController.addListener(handleStatesControllerChange);
  }

  @override
  void initState() {
    super.initState();
    initStatesController();
    FocusManager.instance.addHighlightModeListener(handleFocusHighlightModeChange);
  }

  @override
  void didUpdateWidget(_InkResponseStateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      oldWidget.statesController?.removeListener(handleStatesControllerChange);
      if (widget.statesController != null) {
        internalStatesController?.dispose();
        internalStatesController = null;
      }
      initStatesController();
    }
    if (widget.radius != oldWidget.radius ||
        widget.highlightShape != oldWidget.highlightShape ||
        widget.borderRadius != oldWidget.borderRadius) {
      final InkHighlight? hoverHighlight = _highlights[_HighlightType.hover];
      if (hoverHighlight != null) {
        hoverHighlight.dispose();
        updateHighlight(_HighlightType.hover, value: _hovering, callOnHover: false);
      }
      final InkHighlight? focusHighlight = _highlights[_HighlightType.focus];
      if (focusHighlight != null) {
        focusHighlight.dispose();
        // Do not call updateFocusHighlights() here because it is called below
      }
    }
    if (widget.customBorder != oldWidget.customBorder) {
      _updateHighlightsAndSplashes();
    }
    if (enabled != isWidgetEnabled(oldWidget)) {
      statesController.update(MaterialState.disabled, !enabled);
      if (!enabled) {
        statesController.update(MaterialState.pressed, false);
        // Remove the existing hover highlight immediately when enabled is false.
        // Do not rely on updateHighlight or InkHighlight.deactivate to not break
        // the expected lifecycle which is updating _hovering when the mouse exit.
        // Manually updating _hovering here or calling InkHighlight.deactivate
        // will lead to onHover not being called or call when it is not allowed.
        final InkHighlight? hoverHighlight = _highlights[_HighlightType.hover];
        hoverHighlight?.dispose();
      }
      // Don't call widget.onHover because many widgets, including the button
      // widgets, apply setState to an ancestor context from onHover.
      updateHighlight(_HighlightType.hover, value: _hovering, callOnHover: false);
    }
    updateFocusHighlights();
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(handleFocusHighlightModeChange);
    statesController.removeListener(handleStatesControllerChange);
    internalStatesController?.dispose();
    _activationTimer?.cancel();
    _activationTimer = null;
    super.dispose();
  }

  @override
  bool get wantKeepAlive => highlightsExist || (_splashes != null && _splashes!.isNotEmpty);

  Duration getFadeDurationForType(_HighlightType type) {
    switch (type) {
      case _HighlightType.pressed:
        return const Duration(milliseconds: 200);
      case _HighlightType.hover:
      case _HighlightType.focus:
        return widget.hoverDuration ?? const Duration(milliseconds: 50);
    }
  }

  void updateHighlight(_HighlightType type, { required bool value, bool callOnHover = true }) {
    final InkHighlight? highlight = _highlights[type];
    void handleInkRemoval() {
      assert(_highlights[type] != null);
      _highlights[type] = null;
      updateKeepAlive();
    }

    switch (type) {
      case _HighlightType.pressed:
        statesController.update(MaterialState.pressed, value);
      case _HighlightType.hover:
        if (callOnHover) {
          statesController.update(MaterialState.hovered, value);
        }
      case _HighlightType.focus:
        // see handleFocusUpdate()
        break;
    }

    if (type == _HighlightType.pressed) {
      widget.parentState?.markChildInkResponsePressed(this, value);
    }
    if (value == (highlight != null && highlight.active)) {
      return;
    }

    if (value) {
      if (highlight == null) {
        Color? resolvedOverlayColor = widget.overlayColor?.resolve(statesController.value);
        if (resolvedOverlayColor == null) {
          // Use the backwards compatible defaults
          final ThemeData theme = Theme.of(context);
          switch (type) {
            case _HighlightType.pressed:
              resolvedOverlayColor = widget.highlightColor ?? theme.highlightColor;
            case _HighlightType.focus:
              resolvedOverlayColor = widget.focusColor ?? theme.focusColor;
            case _HighlightType.hover:
              resolvedOverlayColor = widget.hoverColor ?? theme.hoverColor;
          }
        }
        final RenderBox referenceBox = context.findRenderObject()! as RenderBox;
        _highlights[type] = InkHighlight(
          controller: Material.of(context),
          referenceBox: referenceBox,
          color: enabled ? resolvedOverlayColor : resolvedOverlayColor.withAlpha(0),
          shape: widget.highlightShape,
          radius: widget.radius,
          borderRadius: widget.borderRadius,
          customBorder: widget.customBorder,
          rectCallback: widget.getRectCallback!(referenceBox),
          onRemoved: handleInkRemoval,
          textDirection: Directionality.of(context),
          fadeDuration: getFadeDurationForType(type),
        );
        updateKeepAlive();
      } else {
        highlight.activate();
      }
    } else {
      highlight!.deactivate();
    }
    assert(value == (_highlights[type] != null && _highlights[type]!.active));

    switch (type) {
      case _HighlightType.pressed:
        widget.onHighlightChanged?.call(value);
      case _HighlightType.hover:
        if (callOnHover) {
          widget.onHover?.call(value);
        }
      case _HighlightType.focus:
        break;
    }
  }

  void _updateHighlightsAndSplashes() {
    for (final InkHighlight? highlight in _highlights.values) {
      if (highlight != null) {
        highlight.customBorder = widget.customBorder;
      }
    }
    if (_currentSplash != null) {
      _currentSplash!.customBorder = widget.customBorder;
    }
    if (_splashes != null && _splashes!.isNotEmpty) {
      for (final InteractiveInkFeature inkFeature in _splashes!) {
        inkFeature.customBorder = widget.customBorder;
      }
    }
  }

  InteractiveInkFeature _createSplash(Offset globalPosition) {
    final MaterialInkController inkController = Material.of(context);
    final RenderBox referenceBox = context.findRenderObject()! as RenderBox;
    final Offset position = referenceBox.globalToLocal(globalPosition);
    final Color color =  widget.overlayColor?.resolve(statesController.value) ?? widget.splashColor ?? Theme.of(context).splashColor;
    final RectCallback? rectCallback = widget.containedInkWell ? widget.getRectCallback!(referenceBox) : null;
    final BorderRadius? borderRadius = widget.borderRadius;
    final ShapeBorder? customBorder = widget.customBorder;

    InteractiveInkFeature? splash;
    void onRemoved() {
      if (_splashes != null) {
        assert(_splashes!.contains(splash));
        _splashes!.remove(splash);
        if (_currentSplash == splash) {
          _currentSplash = null;
        }
        updateKeepAlive();
      } // else we're probably in deactivate()
    }

    splash = (widget.splashFactory ?? Theme.of(context).splashFactory).create(
      controller: inkController,
      referenceBox: referenceBox,
      position: position,
      color: color,
      containedInkWell: widget.containedInkWell,
      rectCallback: rectCallback,
      radius: widget.radius,
      borderRadius: borderRadius,
      customBorder: customBorder,
      onRemoved: onRemoved,
      textDirection: Directionality.of(context),
    );

    return splash;
  }

  void handleFocusHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted) {
      return;
    }
    setState(() {
      updateFocusHighlights();
    });
  }

  bool get _shouldShowFocus {
    final NavigationMode mode = MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
    switch (mode) {
      case NavigationMode.traditional:
        return enabled && _hasFocus;
      case NavigationMode.directional:
        return _hasFocus;
    }
  }

  void updateFocusHighlights() {
    final bool showFocus;
    switch (FocusManager.instance.highlightMode) {
      case FocusHighlightMode.touch:
        showFocus = false;
      case FocusHighlightMode.traditional:
        showFocus = _shouldShowFocus;
    }
    updateHighlight(_HighlightType.focus, value: showFocus);
  }

  bool _hasFocus = false;
  void handleFocusUpdate(bool hasFocus) {
    _hasFocus = hasFocus;
    // Set here rather than updateHighlight because this widget's
    // (MaterialState) states include MaterialState.focused if
    // the InkWell _has_ the focus, rather than if it's showing
    // the focus per FocusManager.instance.highlightMode.
    statesController.update(MaterialState.focused, hasFocus);
    updateFocusHighlights();
    widget.onFocusChange?.call(hasFocus);
  }

  void handleAnyTapDown(TapDownDetails details) {
    if (_anyChildInkResponsePressed) {
      return;
    }
    _startNewSplash(details: details);
  }

  void handleTapDown(TapDownDetails details) {
    handleAnyTapDown(details);
    widget.onTapDown?.call(details);
  }

  void handleTapUp(TapUpDetails details) {
    widget.onTapUp?.call(details);
  }

  void handleSecondaryTapDown(TapDownDetails details) {
    handleAnyTapDown(details);
    widget.onSecondaryTapDown?.call(details);
  }

  void handleSecondaryTapUp(TapUpDetails details) {
    widget.onSecondaryTapUp?.call(details);
  }

  void _startNewSplash({TapDownDetails? details, BuildContext? context}) {
    assert(details != null || context != null);

    final Offset globalPosition;
    if (context != null) {
      final RenderBox referenceBox = context.findRenderObject()! as RenderBox;
      assert(referenceBox.hasSize, 'InkResponse must be done with layout before starting a splash.');
      globalPosition = referenceBox.localToGlobal(referenceBox.paintBounds.center);
    } else {
      globalPosition = details!.globalPosition;
    }
    statesController.update(MaterialState.pressed, true); // ... before creating the splash
    final InteractiveInkFeature splash = _createSplash(globalPosition);
    _splashes ??= HashSet<InteractiveInkFeature>();
    _splashes!.add(splash);
    _currentSplash?.cancel();
    _currentSplash = splash;
    updateKeepAlive();
    updateHighlight(_HighlightType.pressed, value: true);
  }

  void handleTap() {
    _currentSplash?.confirm();
    _currentSplash = null;
    updateHighlight(_HighlightType.pressed, value: false);
    if (widget.onTap != null) {
      if (widget.enableFeedback) {
        Feedback.forTap(context);
      }
      widget.onTap?.call();
    }
  }

  void handleTapCancel() {
    _currentSplash?.cancel();
    _currentSplash = null;
    widget.onTapCancel?.call();
    updateHighlight(_HighlightType.pressed, value: false);
  }

  void handleDoubleTap() {
    _currentSplash?.confirm();
    _currentSplash = null;
    updateHighlight(_HighlightType.pressed, value: false);
    widget.onDoubleTap?.call();
  }

  void handleLongPress() {
    _currentSplash?.confirm();
    _currentSplash = null;
    if (widget.onLongPress != null) {
      if (widget.enableFeedback) {
        Feedback.forLongPress(context);
      }
      widget.onLongPress!();
    }
  }

  void handleSecondaryTap() {
    _currentSplash?.confirm();
    _currentSplash = null;
    updateHighlight(_HighlightType.pressed, value: false);
    widget.onSecondaryTap?.call();
  }

  void handleSecondaryTapCancel() {
    _currentSplash?.cancel();
    _currentSplash = null;
    widget.onSecondaryTapCancel?.call();
    updateHighlight(_HighlightType.pressed, value: false);
  }

  @override
  void deactivate() {
    if (_splashes != null) {
      final Set<InteractiveInkFeature> splashes = _splashes!;
      _splashes = null;
      for (final InteractiveInkFeature splash in splashes) {
        splash.dispose();
      }
      _currentSplash = null;
    }
    assert(_currentSplash == null);
    for (final _HighlightType highlight in _highlights.keys) {
      _highlights[highlight]?.dispose();
      _highlights[highlight] = null;
    }
    widget.parentState?.markChildInkResponsePressed(this, false);
    super.deactivate();
  }

  bool isWidgetEnabled(_InkResponseStateWidget widget) {
    return _primaryButtonEnabled(widget) || _secondaryButtonEnabled(widget);
  }

  bool _primaryButtonEnabled(_InkResponseStateWidget widget) {
    return widget.onTap != null
      || widget.onDoubleTap != null
      || widget.onLongPress != null
      || widget.onTapUp != null
      || widget.onTapDown != null;
  }

  bool _secondaryButtonEnabled(_InkResponseStateWidget widget) {
    return widget.onSecondaryTap != null
      || widget.onSecondaryTapUp != null
      || widget.onSecondaryTapDown != null;
  }

  bool get enabled => isWidgetEnabled(widget);
  bool get _primaryEnabled => _primaryButtonEnabled(widget);
  bool get _secondaryEnabled => _secondaryButtonEnabled(widget);

  void handleMouseEnter(PointerEnterEvent event) {
    _hovering = true;
    if (enabled) {
      handleHoverChange();
    }
  }

  void handleMouseExit(PointerExitEvent event) {
    _hovering = false;
    // If the exit occurs after we've been disabled, we still
    // want to take down the highlights and run widget.onHover.
    handleHoverChange();
  }

  void handleHoverChange() {
    updateHighlight(_HighlightType.hover, value: _hovering);
  }

  bool get _canRequestFocus {
    final NavigationMode mode = MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
    switch (mode) {
      case NavigationMode.traditional:
        return enabled && widget.canRequestFocus;
      case NavigationMode.directional:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.debugCheckContext(context));
    super.build(context); // See AutomaticKeepAliveClientMixin.

    Color getHighlightColorForType(_HighlightType type) {
      const Set<MaterialState> pressed = <MaterialState>{MaterialState.pressed};
      const Set<MaterialState> focused = <MaterialState>{MaterialState.focused};
      const Set<MaterialState> hovered = <MaterialState>{MaterialState.hovered};

      final ThemeData theme = Theme.of(context);
      switch (type) {
        // The pressed state triggers a ripple (ink splash), per the current
        // Material Design spec. A separate highlight is no longer used.
        // See https://material.io/design/interaction/states.html#pressed
        case _HighlightType.pressed:
          return widget.overlayColor?.resolve(pressed) ?? widget.highlightColor ?? theme.highlightColor;
        case _HighlightType.focus:
          return widget.overlayColor?.resolve(focused) ?? widget.focusColor ?? theme.focusColor;
        case _HighlightType.hover:
          return widget.overlayColor?.resolve(hovered) ?? widget.hoverColor ?? theme.hoverColor;
      }
    }
    for (final _HighlightType type in _highlights.keys) {
      _highlights[type]?.color = getHighlightColorForType(type);
    }

    _currentSplash?.color = widget.overlayColor?.resolve(statesController.value) ?? widget.splashColor ?? Theme.of(context).splashColor;

    final MouseCursor effectiveMouseCursor = MaterialStateProperty.resolveAs<MouseCursor>(
      widget.mouseCursor ?? MaterialStateMouseCursor.clickable,
      statesController.value,
    );

    return _ParentInkResponseProvider(
      state: this,
      child: Actions(
        actions: _actionMap,
        child: Focus(
          focusNode: widget.focusNode,
          canRequestFocus: _canRequestFocus,
          onFocusChange: handleFocusUpdate,
          autofocus: widget.autofocus,
          child: MouseRegion(
            cursor: effectiveMouseCursor,
            onEnter: handleMouseEnter,
            onExit: handleMouseExit,
            child: DefaultSelectionStyle.merge(
              mouseCursor: effectiveMouseCursor,
              child: Semantics(
                onTap: widget.excludeFromSemantics || widget.onTap == null ? null : simulateTap,
                onLongPress: widget.excludeFromSemantics || widget.onLongPress == null ? null : simulateLongPress,
                child: GestureDetector(
                  onTapDown: _primaryEnabled ? handleTapDown : null,
                  onTapUp: _primaryEnabled ? handleTapUp : null,
                  onTap: _primaryEnabled ? handleTap : null,
                  onTapCancel: _primaryEnabled ? handleTapCancel : null,
                  onDoubleTap: widget.onDoubleTap != null ? handleDoubleTap : null,
                  onLongPress: widget.onLongPress != null ? handleLongPress : null,
                  onSecondaryTapDown: _secondaryEnabled ? handleSecondaryTapDown : null,
                  onSecondaryTapUp: _secondaryEnabled ? handleSecondaryTapUp: null,
                  onSecondaryTap: _secondaryEnabled ? handleSecondaryTap : null,
                  onSecondaryTapCancel: _secondaryEnabled ? handleSecondaryTapCancel : null,
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InkWell extends InkResponse {
  const InkWell({
    super.key,
    super.child,
    super.onTap,
    super.onDoubleTap,
    super.onLongPress,
    super.onTapDown,
    super.onTapUp,
    super.onTapCancel,
    super.onSecondaryTap,
    super.onSecondaryTapUp,
    super.onSecondaryTapDown,
    super.onSecondaryTapCancel,
    super.onHighlightChanged,
    super.onHover,
    super.mouseCursor,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.overlayColor,
    super.splashColor,
    super.splashFactory,
    super.radius,
    super.borderRadius,
    super.customBorder,
    bool? enableFeedback = true,
    super.excludeFromSemantics,
    super.focusNode,
    super.canRequestFocus,
    super.onFocusChange,
    super.autofocus,
    super.statesController,
    super.hoverDuration,
  }) : super(
    containedInkWell: true,
    highlightShape: BoxShape.rectangle,
    enableFeedback: enableFeedback ?? true,
  );
}