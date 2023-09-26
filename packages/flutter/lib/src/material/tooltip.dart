import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'feedback.dart';
import 'text_theme.dart';
import 'theme.dart';
import 'tooltip_theme.dart';
import 'tooltip_visibility.dart';

typedef TooltipTriggeredCallback = void Function();

class _ExclusiveMouseRegion extends MouseRegion {
  const _ExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
    super.child,
  });

  @override
  _RenderExclusiveMouseRegion createRenderObject(BuildContext context) {
    return _RenderExclusiveMouseRegion(
      onEnter: onEnter,
      onExit: onExit,
    );
  }
}

class _RenderExclusiveMouseRegion extends RenderMouseRegion {
  _RenderExclusiveMouseRegion({
    super.onEnter,
    super.onExit,
  });

  static bool isOutermostMouseRegion = true;
  static bool foundInnermostMouseRegion = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    bool isHit = false;
    final bool outermost = isOutermostMouseRegion;
    isOutermostMouseRegion = false;
    if (size.contains(position)) {
      isHit =
          hitTestChildren(result, position: position) || hitTestSelf(position);
      if ((isHit || behavior == HitTestBehavior.translucent) &&
          !foundInnermostMouseRegion) {
        foundInnermostMouseRegion = true;
        result.add(BoxHitTestEntry(this, position));
      }
    }

    if (outermost) {
      // The outermost region resets the global states.
      isOutermostMouseRegion = true;
      foundInnermostMouseRegion = false;
    }
    return isHit;
  }
}

class Tooltip extends StatefulWidget {
  const Tooltip({
    super.key,
    this.message,
    this.richMessage,
    this.height,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
    this.showDuration,
    this.triggerMode,
    this.enableFeedback,
    this.onTriggered,
    this.child,
  })  : assert((message == null) != (richMessage == null),
            'Either `message` or `richMessage` must be specified'),
        assert(
          richMessage == null || textStyle == null,
          'If `richMessage` is specified, `textStyle` will have no effect. '
          'If you wish to provide a `textStyle` for a rich tooltip, add the '
          '`textStyle` directly to the `richMessage` InlineSpan.',
        );

  final String? message;

  final InlineSpan? richMessage;

  final double? height;

  final EdgeInsetsGeometry? padding;

  final EdgeInsetsGeometry? margin;

  final double? verticalOffset;

  final bool? preferBelow;

  final bool? excludeFromSemantics;

  final Widget? child;

  final Decoration? decoration;

  final TextStyle? textStyle;

  final TextAlign? textAlign;

  final Duration? waitDuration;

  final Duration? showDuration;

  final TooltipTriggerMode? triggerMode;

  final bool? enableFeedback;

  final TooltipTriggeredCallback? onTriggered;

  static final List<TooltipState> _openedTooltips = <TooltipState>[];

  static bool dismissAllToolTips() {
    if (_openedTooltips.isNotEmpty) {
      // Avoid concurrent modification.
      final List<TooltipState> openedTooltips = _openedTooltips.toList();
      for (final TooltipState state in openedTooltips) {
        assert(state.mounted);
        state._scheduleDismissTooltip(withDelay: Duration.zero);
      }
      return true;
    }
    return false;
  }

  @override
  State<Tooltip> createState() => TooltipState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty(
      'message',
      message,
      showName: message == null,
      defaultValue: message == null ? null : kNoDefaultValue,
    ));
    properties.add(StringProperty(
      'richMessage',
      richMessage?.toPlainText(),
      showName: richMessage == null,
      defaultValue: richMessage == null ? null : kNoDefaultValue,
    ));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('margin', margin,
        defaultValue: null));
    properties.add(
        DoubleProperty('vertical offset', verticalOffset, defaultValue: null));
    properties.add(FlagProperty('position',
        value: preferBelow, ifTrue: 'below', ifFalse: 'above', showName: true));
    properties.add(FlagProperty('semantics',
        value: excludeFromSemantics, ifTrue: 'excluded', showName: true));
    properties.add(DiagnosticsProperty<Duration>('wait duration', waitDuration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('show duration', showDuration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TooltipTriggerMode>(
        'triggerMode', triggerMode,
        defaultValue: null));
    properties.add(FlagProperty('enableFeedback',
        value: enableFeedback, ifTrue: 'true', showName: true));
    properties.add(DiagnosticsProperty<TextAlign>('textAlign', textAlign,
        defaultValue: null));
  }
}

class TooltipState extends State<Tooltip> with SingleTickerProviderStateMixin {
  static const double _defaultVerticalOffset = 24.0;
  static const bool _defaultPreferBelow = true;
  static const EdgeInsetsGeometry _defaultMargin = EdgeInsets.zero;
  static const Duration _fadeInDuration = Duration(milliseconds: 150);
  static const Duration _fadeOutDuration = Duration(milliseconds: 75);
  static const Duration _defaultShowDuration = Duration(milliseconds: 1500);
  static const Duration _defaultHoverShowDuration = Duration(milliseconds: 100);
  static const Duration _defaultWaitDuration = Duration.zero;
  static const bool _defaultExcludeFromSemantics = false;
  static const TooltipTriggerMode _defaultTriggerMode =
      TooltipTriggerMode.longPress;
  static const bool _defaultEnableFeedback = true;
  static const TextAlign _defaultTextAlign = TextAlign.start;

  final OverlayPortalController _overlayController = OverlayPortalController();

  // From InheritedWidgets
  late bool _visible;
  late TooltipThemeData _tooltipTheme;

  Duration get _showDuration =>
      widget.showDuration ?? _tooltipTheme.showDuration ?? _defaultShowDuration;
  Duration get _hoverShowDuration =>
      widget.showDuration ??
      _tooltipTheme.showDuration ??
      _defaultHoverShowDuration;
  Duration get _waitDuration =>
      widget.waitDuration ?? _tooltipTheme.waitDuration ?? _defaultWaitDuration;
  TooltipTriggerMode get _triggerMode =>
      widget.triggerMode ?? _tooltipTheme.triggerMode ?? _defaultTriggerMode;
  bool get _enableFeedback =>
      widget.enableFeedback ??
      _tooltipTheme.enableFeedback ??
      _defaultEnableFeedback;

  String get _tooltipMessage =>
      widget.message ?? widget.richMessage!.toPlainText();

  Timer? _timer;
  AnimationController? _backingController;
  AnimationController get _controller {
    return _backingController ??= AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChanged);
  }

  LongPressGestureRecognizer? _longPressRecognizer;
  TapGestureRecognizer? _tapRecognizer;

  // The ids of mouse devices that are keeping the tooltip from being dismissed.
  //
  // Device ids are added to this set in _handleMouseEnter, and removed in
  // _handleMouseExit. The set is cleared in _handleTapToDismiss, typically when
  // a PointerDown event interacts with some other UI component.
  final Set<int> _activeHoveringPointerDevices = <int>{};

  static bool _isTooltipVisible(AnimationStatus status) {
    return switch (status) {
      AnimationStatus.completed ||
      AnimationStatus.forward ||
      AnimationStatus.reverse =>
        true,
      AnimationStatus.dismissed => false,
    };
  }

  AnimationStatus _animationStatus = AnimationStatus.dismissed;
  void _handleStatusChanged(AnimationStatus status) {
    assert(mounted);
    switch ((_isTooltipVisible(_animationStatus), _isTooltipVisible(status))) {
      case (true, false):
        Tooltip._openedTooltips.remove(this);
        _overlayController.hide();
      case (false, true):
        _overlayController.show();
        Tooltip._openedTooltips.add(this);
        SemanticsService.tooltip(_tooltipMessage);
      case (true, true) || (false, false):
        break;
    }
    _animationStatus = status;
  }

  void _scheduleShowTooltip(
      {required Duration withDelay, Duration? showDuration}) {
    assert(mounted);
    void show() {
      assert(mounted);
      if (!_visible) {
        return;
      }
      _controller.forward();
      _timer?.cancel();
      _timer = showDuration == null
          ? null
          : Timer(showDuration, _controller.reverse);
    }

    assert(
      !(_timer?.isActive ?? false) ||
          _controller.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );
    switch (_controller.status) {
      case AnimationStatus.dismissed when withDelay.inMicroseconds > 0:
        _timer ??= Timer(withDelay, show);
      // If the tooltip is already fading in or fully visible, skip the
      // animation and show the tooltip immediately.
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        show();
    }
  }

  void _scheduleDismissTooltip({required Duration withDelay}) {
    assert(mounted);
    assert(
      !(_timer?.isActive ?? false) ||
          _backingController?.status != AnimationStatus.reverse,
      'timer must not be active when the tooltip is fading out',
    );

    _timer?.cancel();
    _timer = null;
    // Use _backingController instead of _controller to prevent the lazy getter
    // from instaniating an AnimationController unnecessarily.
    switch (_backingController?.status) {
      case null:
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        break;
      // Dismiss when the tooltip is fading in: if there's a dismiss delay we'll
      // allow the fade in animation to continue until the delay timer fires.
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        if (withDelay.inMicroseconds > 0) {
          _timer = Timer(withDelay, _controller.reverse);
        } else {
          _controller.reverse();
        }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    assert(mounted);
    // PointerDeviceKinds that don't support hovering.
    const Set<PointerDeviceKind> triggerModeDeviceKinds = <PointerDeviceKind>{
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.stylus,
      PointerDeviceKind.touch,
      PointerDeviceKind.unknown,
      // MouseRegion only tracks PointerDeviceKind == mouse.
      PointerDeviceKind.trackpad,
    };
    switch (_triggerMode) {
      case TooltipTriggerMode.longPress:
        final LongPressGestureRecognizer recognizer =
            _longPressRecognizer ??= LongPressGestureRecognizer(
          debugOwner: this,
          supportedDevices: triggerModeDeviceKinds,
        );
        recognizer
          ..onLongPressCancel = _handleTapToDismiss
          ..onLongPress = _handleLongPress
          ..onLongPressUp = _handlePressUp
          ..addPointer(event);
      case TooltipTriggerMode.tap:
        final TapGestureRecognizer recognizer = _tapRecognizer ??=
            TapGestureRecognizer(
                debugOwner: this, supportedDevices: triggerModeDeviceKinds);
        recognizer
          ..onTapCancel = _handleTapToDismiss
          ..onTap = _handleTap
          ..addPointer(event);
      case TooltipTriggerMode.manual:
        break;
    }
  }

  // For PointerDownEvents, this method will be called after _handlePointerDown.
  void _handleGlobalPointerEvent(PointerEvent event) {
    assert(mounted);
    if (_tapRecognizer?.primaryPointer == event.pointer ||
        _longPressRecognizer?.primaryPointer == event.pointer) {
      // This is a pointer of interest specified by the trigger mode, since it's
      // picked up by the recognizer.
      //
      // The recognizer will later determine if this is indeed a "trigger"
      // gesture and dismiss the tooltip if that's not the case. However there's
      // still a chance that the PointerEvent was cancelled before the gesture
      // recognizer gets to emit a tap/longPress down, in which case the onCancel
      // callback (_handleTapToDismiss) will not be called.
      return;
    }
    if ((_timer == null && _controller.status == AnimationStatus.dismissed) ||
        event is! PointerDownEvent) {
      return;
    }
    _handleTapToDismiss();
  }

  // The primary pointer is not part of a "trigger" gesture so the tooltip
  // should be dismissed.
  void _handleTapToDismiss() {
    _scheduleDismissTooltip(withDelay: Duration.zero);
    _activeHoveringPointerDevices.clear();
  }

  void _handleTap() {
    if (!_visible) {
      return;
    }
    final bool tooltipCreated = _controller.status == AnimationStatus.dismissed;
    if (tooltipCreated && _enableFeedback) {
      assert(_triggerMode == TooltipTriggerMode.tap);
      Feedback.forTap(context);
    }
    widget.onTriggered?.call();
    _scheduleShowTooltip(
      withDelay: Duration.zero,
      // _activeHoveringPointerDevices keep the tooltip visible.
      showDuration:
          _activeHoveringPointerDevices.isEmpty ? _showDuration : null,
    );
  }

  // When a "trigger" gesture is recognized and the pointer down even is a part
  // of it.
  void _handleLongPress() {
    if (!_visible) {
      return;
    }
    final bool tooltipCreated =
        _visible && _controller.status == AnimationStatus.dismissed;
    if (tooltipCreated && _enableFeedback) {
      assert(_triggerMode == TooltipTriggerMode.longPress);
      Feedback.forLongPress(context);
    }
    widget.onTriggered?.call();
    _scheduleShowTooltip(withDelay: Duration.zero);
  }

  void _handlePressUp() {
    if (_activeHoveringPointerDevices.isNotEmpty) {
      return;
    }
    _scheduleDismissTooltip(withDelay: _showDuration);
  }

  // # Current Hovering Behavior:
  // 1. Hovered tooltips don't show more than one at a time, for each mouse
  //    device. For example, a chip with a delete icon typically shouldn't show
  //    both the delete icon tooltip and the chip tooltip at the same time.
  // 2. Hovered tooltips are dismissed when:
  //    i. [dismissAllToolTips] is called, even these tooltips are still hovered
  //    ii. a unrecognized PointerDownEvent occured withint the application
  //    (even these tooltips are still hovered),
  //    iii. The last hovering device leaves the tooltip.
  void _handleMouseEnter(PointerEnterEvent event) {
    // _handleMouseEnter is only called when the mouse starts to hover over this
    // tooltip (including the actual tooltip it shows on the overlay), and this
    // tooltip is the first to be hit in the widget tree's hit testing order.
    // See also _ExclusiveMouseRegion for the exact behavior.
    _activeHoveringPointerDevices.add(event.device);
    final List<TooltipState> openedTooltips = Tooltip._openedTooltips.toList();
    bool otherTooltipsDismissed = false;
    for (final TooltipState tooltip in openedTooltips) {
      assert(tooltip.mounted);
      final Set<int> hoveringDevices = tooltip._activeHoveringPointerDevices;
      final bool shouldDismiss = tooltip != this &&
          (hoveringDevices.length == 1 &&
              hoveringDevices.single == event.device);
      if (shouldDismiss) {
        otherTooltipsDismissed = true;
        tooltip._scheduleDismissTooltip(withDelay: Duration.zero);
      }
    }
    _scheduleShowTooltip(
        withDelay: otherTooltipsDismissed ? Duration.zero : _waitDuration);
  }

  void _handleMouseExit(PointerExitEvent event) {
    if (_activeHoveringPointerDevices.isEmpty) {
      return;
    }
    _activeHoveringPointerDevices.remove(event.device);
    if (_activeHoveringPointerDevices.isEmpty) {
      _scheduleDismissTooltip(withDelay: _hoverShowDuration);
    }
  }

  bool ensureTooltipVisible() {
    if (!_visible) {
      return false;
    }

    _timer?.cancel();
    _timer = null;
    switch (_controller.status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.reverse:
        _scheduleShowTooltip(withDelay: Duration.zero);
        return true;
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen to global pointer events so that we can hide a tooltip immediately
    // if some other control is clicked on. Pointer events are dispatched to
    // global routes **after** other routes.
    GestureBinding.instance.pointerRouter
        .addGlobalRoute(_handleGlobalPointerEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TooltipVisibility.of(context);
    _tooltipTheme = TooltipTheme.of(context);
  }

  // https://material.io/components/tooltips#specs
  double _getDefaultTooltipHeight() {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        24.0,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        32.0,
    };
  }

  EdgeInsets _getDefaultPadding() {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    };
  }

  static double _getDefaultFontSize(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        12.0,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        14.0,
    };
  }

  Widget _buildTooltipOverlay(BuildContext context) {
    final OverlayState overlayState =
        Overlay.of(context, debugRequiredFor: widget);
    final RenderBox box = this.context.findRenderObject()! as RenderBox;
    final Offset target = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: overlayState.context.findRenderObject(),
    );

    final (TextStyle defaultTextStyle, BoxDecoration defaultDecoration) =
        switch (Theme.of(context)) {
      ThemeData(
        brightness: Brightness.dark,
        :final TextTheme textTheme,
        :final TargetPlatform platform
      ) =>
        (
          textTheme.bodyMedium!.copyWith(
              color: Colors.black, fontSize: _getDefaultFontSize(platform)),
          BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: const BorderRadius.all(Radius.circular(4))),
        ),
      ThemeData(
        brightness: Brightness.light,
        :final TextTheme textTheme,
        :final TargetPlatform platform
      ) =>
        (
          textTheme.bodyMedium!.copyWith(
              color: Colors.white, fontSize: _getDefaultFontSize(platform)),
          BoxDecoration(
              color: Colors.grey[700]!.withOpacity(0.9),
              borderRadius: const BorderRadius.all(Radius.circular(4))),
        ),
    };

    final TooltipThemeData tooltipTheme = _tooltipTheme;
    final _TooltipOverlay overlayChild = _TooltipOverlay(
      richMessage: widget.richMessage ?? TextSpan(text: widget.message),
      height:
          widget.height ?? tooltipTheme.height ?? _getDefaultTooltipHeight(),
      padding: widget.padding ?? tooltipTheme.padding ?? _getDefaultPadding(),
      margin: widget.margin ?? tooltipTheme.margin ?? _defaultMargin,
      onEnter: _handleMouseEnter,
      onExit: _handleMouseExit,
      decoration:
          widget.decoration ?? tooltipTheme.decoration ?? defaultDecoration,
      textStyle: widget.textStyle ?? tooltipTheme.textStyle ?? defaultTextStyle,
      textAlign:
          widget.textAlign ?? tooltipTheme.textAlign ?? _defaultTextAlign,
      animation:
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
      target: target,
      verticalOffset: widget.verticalOffset ??
          tooltipTheme.verticalOffset ??
          _defaultVerticalOffset,
      preferBelow:
          widget.preferBelow ?? tooltipTheme.preferBelow ?? _defaultPreferBelow,
    );

    return SelectionContainer.maybeOf(context) == null
        ? overlayChild
        : SelectionContainer.disabled(child: overlayChild);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handleGlobalPointerEvent);
    Tooltip._openedTooltips.remove(this);
    // _longPressRecognizer.dispose() and _tapRecognizer.dispose() may call
    // their registered onCancel callbacks if there's a gesture in progress.
    // Remove the onCancel callbacks to prevent the registered callbacks from
    // triggering unnecessary side effects (such as animations).
    _longPressRecognizer?.onLongPressCancel = null;
    _longPressRecognizer?.dispose();
    _tapRecognizer?.onTapCancel = null;
    _tapRecognizer?.dispose();
    _timer?.cancel();
    _backingController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If message is empty then no need to create a tooltip overlay to show
    // the empty black container so just return the wrapped child as is or
    // empty container if child is not specified.
    if (_tooltipMessage.isEmpty) {
      return widget.child ?? const SizedBox.shrink();
    }
    assert(debugCheckHasOverlay(context));
    final bool excludeFromSemantics = widget.excludeFromSemantics ??
        _tooltipTheme.excludeFromSemantics ??
        _defaultExcludeFromSemantics;
    Widget result = Semantics(
      tooltip: excludeFromSemantics ? null : _tooltipMessage,
      child: widget.child,
    );

    // Only check for gestures if tooltip should be visible.
    if (_visible) {
      result = _ExclusiveMouseRegion(
        onEnter: _handleMouseEnter,
        onExit: _handleMouseExit,
        child: Listener(
          onPointerDown: _handlePointerDown,
          behavior: HitTestBehavior.opaque,
          child: result,
        ),
      );
    }
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildTooltipOverlay,
      child: result,
    );
  }
}

class _TooltipPositionDelegate extends SingleChildLayoutDelegate {
  _TooltipPositionDelegate({
    required this.target,
    required this.verticalOffset,
    required this.preferBelow,
  });

  final Offset target;

  final double verticalOffset;

  final bool preferBelow;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return positionDependentBox(
      size: size,
      childSize: childSize,
      target: target,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
    );
  }

  @override
  bool shouldRelayout(_TooltipPositionDelegate oldDelegate) {
    return target != oldDelegate.target ||
        verticalOffset != oldDelegate.verticalOffset ||
        preferBelow != oldDelegate.preferBelow;
  }
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.height,
    required this.richMessage,
    this.padding,
    this.margin,
    this.decoration,
    this.textStyle,
    this.textAlign,
    required this.animation,
    required this.target,
    required this.verticalOffset,
    required this.preferBelow,
    this.onEnter,
    this.onExit,
  });

  final InlineSpan richMessage;
  final double height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final TextAlign? textAlign;
  final Animation<double> animation;
  final Offset target;
  final double verticalOffset;
  final bool preferBelow;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;

  @override
  Widget build(BuildContext context) {
    Widget result = FadeTransition(
      opacity: animation,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: Container(
            decoration: decoration,
            padding: padding,
            margin: margin,
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: Text.rich(
                richMessage,
                style: textStyle,
                textAlign: textAlign,
              ),
            ),
          ),
        ),
      ),
    );
    if (onEnter != null || onExit != null) {
      result = _ExclusiveMouseRegion(
        onEnter: onEnter,
        onExit: onExit,
        child: result,
      );
    }
    return Positioned.fill(
      bottom: MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0.0,
      child: CustomSingleChildLayout(
        delegate: _TooltipPositionDelegate(
          target: target,
          verticalOffset: verticalOffset,
          preferBelow: preferBelow,
        ),
        child: result,
      ),
    );
  }
}
