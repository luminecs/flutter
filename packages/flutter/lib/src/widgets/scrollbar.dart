import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'binding.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'media_query.dart';
import 'notification_listener.dart';
import 'primary_scroll_controller.dart';
import 'scroll_configuration.dart';
import 'scroll_controller.dart';
import 'scroll_metrics.dart';
import 'scroll_notification.dart';
import 'scroll_position.dart';
import 'scrollable.dart';
import 'scrollable_helpers.dart';
import 'ticker_provider.dart';

const double _kMinThumbExtent = 18.0;
const double _kMinInteractiveSize = 48.0;
const double _kScrollbarThickness = 6.0;
const Duration _kScrollbarFadeDuration = Duration(milliseconds: 300);
const Duration _kScrollbarTimeToFade = Duration(milliseconds: 600);

enum ScrollbarOrientation {
  left,

  right,

  top,

  bottom,
}

class ScrollbarPainter extends ChangeNotifier implements CustomPainter {
  ScrollbarPainter({
    required Color color,
    required this.fadeoutOpacityAnimation,
    Color trackColor = const Color(0x00000000),
    Color trackBorderColor = const Color(0x00000000),
    TextDirection? textDirection,
    double thickness = _kScrollbarThickness,
    EdgeInsets padding = EdgeInsets.zero,
    double mainAxisMargin = 0.0,
    double crossAxisMargin = 0.0,
    Radius? radius,
    Radius? trackRadius,
    OutlinedBorder? shape,
    double minLength = _kMinThumbExtent,
    double? minOverscrollLength,
    ScrollbarOrientation? scrollbarOrientation,
    bool ignorePointer = false,
  })  : assert(radius == null || shape == null),
        assert(minLength >= 0),
        assert(minOverscrollLength == null || minOverscrollLength <= minLength),
        assert(minOverscrollLength == null || minOverscrollLength >= 0),
        assert(padding.isNonNegative),
        _color = color,
        _textDirection = textDirection,
        _thickness = thickness,
        _radius = radius,
        _shape = shape,
        _padding = padding,
        _mainAxisMargin = mainAxisMargin,
        _crossAxisMargin = crossAxisMargin,
        _minLength = minLength,
        _trackColor = trackColor,
        _trackBorderColor = trackBorderColor,
        _trackRadius = trackRadius,
        _scrollbarOrientation = scrollbarOrientation,
        _minOverscrollLength = minOverscrollLength ?? minLength,
        _ignorePointer = ignorePointer {
    fadeoutOpacityAnimation.addListener(notifyListeners);
  }

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (color == value) {
      return;
    }

    _color = value;
    notifyListeners();
  }

  Color get trackColor => _trackColor;
  Color _trackColor;
  set trackColor(Color value) {
    if (trackColor == value) {
      return;
    }

    _trackColor = value;
    notifyListeners();
  }

  Color get trackBorderColor => _trackBorderColor;
  Color _trackBorderColor;
  set trackBorderColor(Color value) {
    if (trackBorderColor == value) {
      return;
    }

    _trackBorderColor = value;
    notifyListeners();
  }

  Radius? get trackRadius => _trackRadius;
  Radius? _trackRadius;
  set trackRadius(Radius? value) {
    if (trackRadius == value) {
      return;
    }

    _trackRadius = value;
    notifyListeners();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    assert(value != null);
    if (textDirection == value) {
      return;
    }

    _textDirection = value;
    notifyListeners();
  }

  double get thickness => _thickness;
  double _thickness;
  set thickness(double value) {
    if (thickness == value) {
      return;
    }

    _thickness = value;
    notifyListeners();
  }

  final Animation<double> fadeoutOpacityAnimation;

  double get mainAxisMargin => _mainAxisMargin;
  double _mainAxisMargin;
  set mainAxisMargin(double value) {
    if (mainAxisMargin == value) {
      return;
    }

    _mainAxisMargin = value;
    notifyListeners();
  }

  double get crossAxisMargin => _crossAxisMargin;
  double _crossAxisMargin;
  set crossAxisMargin(double value) {
    if (crossAxisMargin == value) {
      return;
    }

    _crossAxisMargin = value;
    notifyListeners();
  }

  Radius? get radius => _radius;
  Radius? _radius;
  set radius(Radius? value) {
    assert(shape == null || value == null);
    if (radius == value) {
      return;
    }

    _radius = value;
    notifyListeners();
  }

  OutlinedBorder? get shape => _shape;
  OutlinedBorder? _shape;
  set shape(OutlinedBorder? value) {
    assert(radius == null || value == null);
    if (shape == value) {
      return;
    }

    _shape = value;
    notifyListeners();
  }

  EdgeInsets get padding => _padding;
  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (padding == value) {
      return;
    }

    _padding = value;
    notifyListeners();
  }

  double get minLength => _minLength;
  double _minLength;
  set minLength(double value) {
    if (minLength == value) {
      return;
    }

    _minLength = value;
    notifyListeners();
  }

  double get minOverscrollLength => _minOverscrollLength;
  double _minOverscrollLength;
  set minOverscrollLength(double value) {
    if (minOverscrollLength == value) {
      return;
    }

    _minOverscrollLength = value;
    notifyListeners();
  }

  ScrollbarOrientation? get scrollbarOrientation => _scrollbarOrientation;
  ScrollbarOrientation? _scrollbarOrientation;
  set scrollbarOrientation(ScrollbarOrientation? value) {
    if (scrollbarOrientation == value) {
      return;
    }

    _scrollbarOrientation = value;
    notifyListeners();
  }

  bool get ignorePointer => _ignorePointer;
  bool _ignorePointer;
  set ignorePointer(bool value) {
    if (ignorePointer == value) {
      return;
    }

    _ignorePointer = value;
    notifyListeners();
  }

  // - Scrollbar Details

  Rect? _trackRect;
  // The full painted length of the track
  double get _trackExtent =>
      _lastMetrics!.viewportDimension - _totalTrackMainAxisOffsets;
  // The full length of the track that the thumb can travel
  double get _traversableTrackExtent => _trackExtent - (2 * mainAxisMargin);
  // Track Offsets
  // The track is offset by only padding.
  double get _totalTrackMainAxisOffsets =>
      _isVertical ? padding.vertical : padding.horizontal;
  double get _leadingTrackMainAxisOffset {
    switch (_resolvedOrientation) {
      case ScrollbarOrientation.left:
      case ScrollbarOrientation.right:
        return padding.top;
      case ScrollbarOrientation.top:
      case ScrollbarOrientation.bottom:
        return padding.left;
    }
  }

  Rect? _thumbRect;
  // The current scroll position + _leadingThumbMainAxisOffset
  late double _thumbOffset;
  // The fraction visible in relation to the traversable length of the track.
  late double _thumbExtent;
  // Thumb Offsets
  // The thumb is offset by padding and margins.
  double get _leadingThumbMainAxisOffset {
    switch (_resolvedOrientation) {
      case ScrollbarOrientation.left:
      case ScrollbarOrientation.right:
        return padding.top + mainAxisMargin;
      case ScrollbarOrientation.top:
      case ScrollbarOrientation.bottom:
        return padding.left + mainAxisMargin;
    }
  }

  void _setThumbExtent() {
    // Thumb extent reflects fraction of content visible, as long as this
    // isn't less than the absolute minimum size.
    // _totalContentExtent >= viewportDimension, so (_totalContentExtent - _mainAxisPadding) > 0
    final double fractionVisible = clampDouble(
      (_lastMetrics!.extentInside - _totalTrackMainAxisOffsets) /
          (_totalContentExtent - _totalTrackMainAxisOffsets),
      0.0,
      1.0,
    );

    final double thumbExtent = math.max(
      math.min(_traversableTrackExtent, minOverscrollLength),
      _traversableTrackExtent * fractionVisible,
    );

    final double fractionOverscrolled =
        1.0 - _lastMetrics!.extentInside / _lastMetrics!.viewportDimension;
    final double safeMinLength = math.min(minLength, _traversableTrackExtent);
    final double newMinLength = (_beforeExtent > 0 && _afterExtent > 0)
        // Thumb extent is no smaller than minLength if scrolling normally.
        ? safeMinLength
        // User is overscrolling. Thumb extent can be less than minLength
        // but no smaller than minOverscrollLength. We can't use the
        // fractionVisible to produce intermediate values between minLength and
        // minOverscrollLength when the user is transitioning from regular
        // scrolling to overscrolling, so we instead use the percentage of the
        // content that is still in the viewport to determine the size of the
        // thumb. iOS behavior appears to have the thumb reach its minimum size
        // with ~20% of overscroll. We map the percentage of minLength from
        // [0.8, 1.0] to [0.0, 1.0], so 0% to 20% of overscroll will produce
        // values for the thumb that range between minLength and the smallest
        // possible value, minOverscrollLength.
        : safeMinLength *
            (1.0 - clampDouble(fractionOverscrolled, 0.0, 0.2) / 0.2);

    // The `thumbExtent` should be no greater than `trackSize`, otherwise
    // the scrollbar may scroll towards the wrong direction.
    _thumbExtent =
        clampDouble(thumbExtent, newMinLength, _traversableTrackExtent);
  }

  // - Scrollable Details

  ScrollMetrics? _lastMetrics;
  bool get _lastMetricsAreScrollable =>
      _lastMetrics!.minScrollExtent != _lastMetrics!.maxScrollExtent;
  AxisDirection? _lastAxisDirection;

  bool get _isVertical =>
      _lastAxisDirection == AxisDirection.down ||
      _lastAxisDirection == AxisDirection.up;
  bool get _isReversed =>
      _lastAxisDirection == AxisDirection.up ||
      _lastAxisDirection == AxisDirection.left;
  // The amount of scroll distance before and after the current position.
  double get _beforeExtent =>
      _isReversed ? _lastMetrics!.extentAfter : _lastMetrics!.extentBefore;
  double get _afterExtent =>
      _isReversed ? _lastMetrics!.extentBefore : _lastMetrics!.extentAfter;

  // The total size of the scrollable content.
  double get _totalContentExtent {
    return _lastMetrics!.maxScrollExtent -
        _lastMetrics!.minScrollExtent +
        _lastMetrics!.viewportDimension;
  }

  ScrollbarOrientation get _resolvedOrientation {
    if (scrollbarOrientation == null) {
      if (_isVertical) {
        return textDirection == TextDirection.ltr
            ? ScrollbarOrientation.right
            : ScrollbarOrientation.left;
      }
      return ScrollbarOrientation.bottom;
    }
    return scrollbarOrientation!;
  }

  void _debugAssertIsValidOrientation(ScrollbarOrientation orientation) {
    assert(() {
      bool isVerticalOrientation(ScrollbarOrientation orientation) =>
          orientation == ScrollbarOrientation.left ||
          orientation == ScrollbarOrientation.right;
      return (_isVertical && isVerticalOrientation(orientation)) ||
          (!_isVertical && !isVerticalOrientation(orientation));
    }(),
        'The given ScrollbarOrientation: $orientation is incompatible with the '
        'current AxisDirection: $_lastAxisDirection.');
  }

  // - Updating

  void update(
    ScrollMetrics metrics,
    AxisDirection axisDirection,
  ) {
    if (_lastMetrics != null &&
        _lastMetrics!.extentBefore == metrics.extentBefore &&
        _lastMetrics!.extentInside == metrics.extentInside &&
        _lastMetrics!.extentAfter == metrics.extentAfter &&
        _lastAxisDirection == axisDirection) {
      return;
    }

    final ScrollMetrics? oldMetrics = _lastMetrics;
    _lastMetrics = metrics;
    _lastAxisDirection = axisDirection;

    bool needPaint(ScrollMetrics? metrics) =>
        metrics != null && metrics.maxScrollExtent > metrics.minScrollExtent;
    if (!needPaint(oldMetrics) && !needPaint(metrics)) {
      return;
    }
    notifyListeners();
  }

  void updateThickness(double nextThickness, Radius nextRadius) {
    thickness = nextThickness;
    radius = nextRadius;
  }

  // - Painting

  Paint get _paintThumb {
    return Paint()
      ..color =
          color.withOpacity(color.opacity * fadeoutOpacityAnimation.value);
  }

  Paint _paintTrack({bool isBorder = false}) {
    if (isBorder) {
      return Paint()
        ..color = trackBorderColor.withOpacity(
            trackBorderColor.opacity * fadeoutOpacityAnimation.value)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
    }
    return Paint()
      ..color = trackColor
          .withOpacity(trackColor.opacity * fadeoutOpacityAnimation.value);
  }

  void _paintScrollbar(Canvas canvas, Size size) {
    assert(
      textDirection != null,
      'A TextDirection must be provided before a Scrollbar can be painted.',
    );

    final double x, y;
    final Size thumbSize, trackSize;
    final Offset trackOffset, borderStart, borderEnd;
    _debugAssertIsValidOrientation(_resolvedOrientation);
    switch (_resolvedOrientation) {
      case ScrollbarOrientation.left:
        thumbSize = Size(thickness, _thumbExtent);
        trackSize = Size(thickness + 2 * crossAxisMargin, _trackExtent);
        x = crossAxisMargin + padding.left;
        y = _thumbOffset;
        trackOffset = Offset(x - crossAxisMargin, _leadingTrackMainAxisOffset);
        borderStart = trackOffset + Offset(trackSize.width, 0.0);
        borderEnd = Offset(
            trackOffset.dx + trackSize.width, trackOffset.dy + _trackExtent);
      case ScrollbarOrientation.right:
        thumbSize = Size(thickness, _thumbExtent);
        trackSize = Size(thickness + 2 * crossAxisMargin, _trackExtent);
        x = size.width - thickness - crossAxisMargin - padding.right;
        y = _thumbOffset;
        trackOffset = Offset(x - crossAxisMargin, _leadingTrackMainAxisOffset);
        borderStart = trackOffset;
        borderEnd = Offset(trackOffset.dx, trackOffset.dy + _trackExtent);
      case ScrollbarOrientation.top:
        thumbSize = Size(_thumbExtent, thickness);
        trackSize = Size(_trackExtent, thickness + 2 * crossAxisMargin);
        x = _thumbOffset;
        y = crossAxisMargin + padding.top;
        trackOffset = Offset(_leadingTrackMainAxisOffset, y - crossAxisMargin);
        borderStart = trackOffset + Offset(0.0, trackSize.height);
        borderEnd = Offset(
            trackOffset.dx + _trackExtent, trackOffset.dy + trackSize.height);
      case ScrollbarOrientation.bottom:
        thumbSize = Size(_thumbExtent, thickness);
        trackSize = Size(_trackExtent, thickness + 2 * crossAxisMargin);
        x = _thumbOffset;
        y = size.height - thickness - crossAxisMargin - padding.bottom;
        trackOffset = Offset(_leadingTrackMainAxisOffset, y - crossAxisMargin);
        borderStart = trackOffset;
        borderEnd = Offset(trackOffset.dx + _trackExtent, trackOffset.dy);
    }

    // Whether we paint or not, calculating these rects allows us to hit test
    // when the scrollbar is transparent.
    _trackRect = trackOffset & trackSize;
    _thumbRect = Offset(x, y) & thumbSize;

    // Paint if the opacity dictates visibility
    if (fadeoutOpacityAnimation.value != 0.0) {
      // Track
      if (trackRadius == null) {
        canvas.drawRect(_trackRect!, _paintTrack());
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(_trackRect!, trackRadius!), _paintTrack());
      }
      // Track Border
      canvas.drawLine(borderStart, borderEnd, _paintTrack(isBorder: true));
      if (radius != null) {
        // Rounded rect thumb
        canvas.drawRRect(
            RRect.fromRectAndRadius(_thumbRect!, radius!), _paintThumb);
        return;
      }
      if (shape == null) {
        // Square thumb
        canvas.drawRect(_thumbRect!, _paintThumb);
        return;
      }
      // Custom-shaped thumb
      final Path outerPath = shape!.getOuterPath(_thumbRect!);
      canvas.drawPath(outerPath, _paintThumb);
      shape!.paint(canvas, _thumbRect!);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_lastAxisDirection == null ||
        _lastMetrics == null ||
        _lastMetrics!.maxScrollExtent <= _lastMetrics!.minScrollExtent) {
      return;
    }
    // Skip painting if there's not enough space.
    if (_traversableTrackExtent <= 0) {
      return;
    }
    // Do not paint a scrollbar if the scroll view is infinitely long.
    // TODO(Piinks): Special handling for infinite scroll views,
    //  https://github.com/flutter/flutter/issues/41434
    if (_lastMetrics!.maxScrollExtent.isInfinite) {
      return;
    }

    _setThumbExtent();
    final double thumbPositionOffset =
        _getScrollToTrack(_lastMetrics!, _thumbExtent);
    _thumbOffset = thumbPositionOffset + _leadingThumbMainAxisOffset;

    return _paintScrollbar(canvas, size);
  }

  // - Scroll Position Conversion

  double getTrackToScroll(double thumbOffsetLocal) {
    final double scrollableExtent =
        _lastMetrics!.maxScrollExtent - _lastMetrics!.minScrollExtent;
    final double thumbMovableExtent = _traversableTrackExtent - _thumbExtent;

    return scrollableExtent * thumbOffsetLocal / thumbMovableExtent;
  }

  double getThumbScrollOffset() {
    final double scrollableExtent =
        _lastMetrics!.maxScrollExtent - _lastMetrics!.minScrollExtent;

    final double fractionPast = (scrollableExtent > 0)
        ? clampDouble(_lastMetrics!.pixels / scrollableExtent, 0.0, 1.0)
        : 0;

    return fractionPast * (_traversableTrackExtent - _thumbExtent);
  }

  // Converts between a scroll position and the corresponding position in the
  // thumb track.
  double _getScrollToTrack(ScrollMetrics metrics, double thumbExtent) {
    final double scrollableExtent =
        metrics.maxScrollExtent - metrics.minScrollExtent;

    final double fractionPast = (scrollableExtent > 0)
        ? clampDouble(
            (metrics.pixels - metrics.minScrollExtent) / scrollableExtent,
            0.0,
            1.0)
        : 0;

    return (_isReversed ? 1 - fractionPast : fractionPast) *
        (_traversableTrackExtent - thumbExtent);
  }

  // - Hit Testing

  @override
  bool? hitTest(Offset? position) {
    // There is nothing painted to hit.
    if (_thumbRect == null) {
      return null;
    }

    // Interaction disabled.
    if (ignorePointer
        // The thumb is not able to be hit when transparent.
        ||
        fadeoutOpacityAnimation.value == 0.0
        // Not scrollable
        ||
        !_lastMetricsAreScrollable) {
      return false;
    }

    return _trackRect!.contains(position!);
  }

  bool hitTestInteractive(Offset position, PointerDeviceKind kind,
      {bool forHover = false}) {
    if (_trackRect == null) {
      // We have not computed the scrollbar position yet.
      return false;
    }
    if (ignorePointer) {
      return false;
    }

    if (!_lastMetricsAreScrollable) {
      return false;
    }

    final Rect interactiveRect = _trackRect!;
    final Rect paddedRect = interactiveRect.expandToInclude(
      Rect.fromCircle(
          center: _thumbRect!.center, radius: _kMinInteractiveSize / 2),
    );

    // The scrollbar is not able to be hit when transparent - except when
    // hovering with a mouse. This should bring the scrollbar into view so the
    // mouse can interact with it.
    if (fadeoutOpacityAnimation.value == 0.0) {
      if (forHover && kind == PointerDeviceKind.mouse) {
        return paddedRect.contains(position);
      }
      return false;
    }

    switch (kind) {
      case PointerDeviceKind.touch:
      case PointerDeviceKind.trackpad:
        return paddedRect.contains(position);
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
      case PointerDeviceKind.unknown:
        return interactiveRect.contains(position);
    }
  }

  bool hitTestOnlyThumbInteractive(Offset position, PointerDeviceKind kind) {
    if (_thumbRect == null) {
      return false;
    }
    if (ignorePointer) {
      return false;
    }
    // The thumb is not able to be hit when transparent.
    if (fadeoutOpacityAnimation.value == 0.0) {
      return false;
    }

    if (!_lastMetricsAreScrollable) {
      return false;
    }

    switch (kind) {
      case PointerDeviceKind.touch:
      case PointerDeviceKind.trackpad:
        final Rect touchThumbRect = _thumbRect!.expandToInclude(
          Rect.fromCircle(
              center: _thumbRect!.center, radius: _kMinInteractiveSize / 2),
        );
        return touchThumbRect.contains(position);
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
      case PointerDeviceKind.unknown:
        return _thumbRect!.contains(position);
    }
  }

  @override
  bool shouldRepaint(ScrollbarPainter oldDelegate) {
    // Should repaint if any properties changed.
    return color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor ||
        trackBorderColor != oldDelegate.trackBorderColor ||
        textDirection != oldDelegate.textDirection ||
        thickness != oldDelegate.thickness ||
        fadeoutOpacityAnimation != oldDelegate.fadeoutOpacityAnimation ||
        mainAxisMargin != oldDelegate.mainAxisMargin ||
        crossAxisMargin != oldDelegate.crossAxisMargin ||
        radius != oldDelegate.radius ||
        trackRadius != oldDelegate.trackRadius ||
        shape != oldDelegate.shape ||
        padding != oldDelegate.padding ||
        minLength != oldDelegate.minLength ||
        minOverscrollLength != oldDelegate.minOverscrollLength ||
        scrollbarOrientation != oldDelegate.scrollbarOrientation ||
        ignorePointer != oldDelegate.ignorePointer;
  }

  @override
  bool shouldRebuildSemantics(CustomPainter oldDelegate) => false;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  String toString() => describeIdentity(this);

  @override
  void dispose() {
    fadeoutOpacityAnimation.removeListener(notifyListeners);
    super.dispose();
  }
}

class RawScrollbar extends StatefulWidget {
  const RawScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.shape,
    this.radius,
    this.thickness,
    this.thumbColor,
    this.minThumbLength = _kMinThumbExtent,
    this.minOverscrollLength,
    this.trackVisibility,
    this.trackRadius,
    this.trackColor,
    this.trackBorderColor,
    this.fadeDuration = _kScrollbarFadeDuration,
    this.timeToFade = _kScrollbarTimeToFade,
    this.pressDuration = Duration.zero,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.interactive,
    this.scrollbarOrientation,
    this.mainAxisMargin = 0.0,
    this.crossAxisMargin = 0.0,
    this.padding,
  })  : assert(
          !(thumbVisibility == false && (trackVisibility ?? false)),
          'A scrollbar track cannot be drawn without a scrollbar thumb.',
        ),
        assert(minThumbLength >= 0),
        assert(minOverscrollLength == null ||
            minOverscrollLength <= minThumbLength),
        assert(minOverscrollLength == null || minOverscrollLength >= 0),
        assert(radius == null || shape == null);

  final Widget child;

  final ScrollController? controller;

  final bool? thumbVisibility;

  final OutlinedBorder? shape;

  final Radius? radius;

  final double? thickness;

  final Color? thumbColor;

  final double minThumbLength;

  final double? minOverscrollLength;

  final bool? trackVisibility;

  final Radius? trackRadius;

  final Color? trackColor;

  final Color? trackBorderColor;

  final Duration fadeDuration;

  final Duration timeToFade;

  final Duration pressDuration;

  final ScrollNotificationPredicate notificationPredicate;

  final bool? interactive;

  final ScrollbarOrientation? scrollbarOrientation;

  final double mainAxisMargin;

  final double crossAxisMargin;

  final EdgeInsets? padding;

  @override
  RawScrollbarState<RawScrollbar> createState() =>
      RawScrollbarState<RawScrollbar>();
}

class RawScrollbarState<T extends RawScrollbar> extends State<T>
    with TickerProviderStateMixin<T> {
  Offset? _startDragScrollbarAxisOffset;
  Offset? _lastDragUpdateOffset;
  double? _startDragThumbOffset;
  ScrollController? _cachedController;
  Timer? _fadeoutTimer;
  late AnimationController _fadeoutAnimationController;
  late Animation<double> _fadeoutOpacityAnimation;
  final GlobalKey _scrollbarPainterKey = GlobalKey();
  bool _hoverIsActive = false;
  bool _thumbDragging = false;

  ScrollController? get _effectiveScrollController =>
      widget.controller ?? PrimaryScrollController.maybeOf(context);

  @protected
  late final ScrollbarPainter scrollbarPainter;

  @protected
  bool get showScrollbar => widget.thumbVisibility ?? false;

  bool get _showTrack => showScrollbar && (widget.trackVisibility ?? false);

  @protected
  bool get enableGestures => widget.interactive ?? true;

  @override
  void initState() {
    super.initState();
    _fadeoutAnimationController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    )..addStatusListener(_validateInteractions);
    _fadeoutOpacityAnimation = CurvedAnimation(
      parent: _fadeoutAnimationController,
      curve: Curves.fastOutSlowIn,
    );
    scrollbarPainter = ScrollbarPainter(
      color: widget.thumbColor ?? const Color(0x66BCBCBC),
      fadeoutOpacityAnimation: _fadeoutOpacityAnimation,
      thickness: widget.thickness ?? _kScrollbarThickness,
      radius: widget.radius,
      trackRadius: widget.trackRadius,
      scrollbarOrientation: widget.scrollbarOrientation,
      mainAxisMargin: widget.mainAxisMargin,
      shape: widget.shape,
      crossAxisMargin: widget.crossAxisMargin,
      minLength: widget.minThumbLength,
      minOverscrollLength: widget.minOverscrollLength ?? widget.minThumbLength,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(_debugScheduleCheckHasValidScrollPosition());
  }

  bool _debugScheduleCheckHasValidScrollPosition() {
    if (!showScrollbar) {
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      assert(_debugCheckHasValidScrollPosition());
    });
    return true;
  }

  void _validateInteractions(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      assert(_fadeoutOpacityAnimation.value == 0.0);
      // We do not check for a valid scroll position if the scrollbar is not
      // visible, because it cannot be interacted with.
    } else if (_effectiveScrollController != null && enableGestures) {
      // Interactive scrollbars need to be properly configured. If it is visible
      // for interaction, ensure we are set up properly.
      assert(_debugCheckHasValidScrollPosition());
    }
  }

  bool _debugCheckHasValidScrollPosition() {
    if (!mounted) {
      return true;
    }
    final ScrollController? scrollController = _effectiveScrollController;
    final bool tryPrimary = widget.controller == null;
    final String controllerForError =
        tryPrimary ? 'PrimaryScrollController' : 'provided ScrollController';

    String when = '';
    if (widget.thumbVisibility ?? false) {
      when = 'Scrollbar.thumbVisibility is true';
    } else if (enableGestures) {
      when = 'the scrollbar is interactive';
    } else {
      when = 'using the Scrollbar';
    }

    assert(
      scrollController != null,
      'A ScrollController is required when $when. '
      '${tryPrimary ? 'The Scrollbar was not provided a ScrollController, '
          'and attempted to use the PrimaryScrollController, but none was found.' : ''}',
    );
    assert(() {
      if (!scrollController!.hasClients) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            "The Scrollbar's ScrollController has no ScrollPosition attached.",
          ),
          ErrorDescription(
            'A Scrollbar cannot be painted without a ScrollPosition. ',
          ),
          ErrorHint(
            'The Scrollbar attempted to use the $controllerForError. This '
            'ScrollController should be associated with the ScrollView that '
            'the Scrollbar is being applied to.'
            '${tryPrimary ? 'When ScrollView.scrollDirection is Axis.vertical on mobile '
                'platforms will automatically use the '
                'PrimaryScrollController if the user has not provided a '
                'ScrollController. To use the PrimaryScrollController '
                'explicitly, set ScrollView.primary to true for the Scrollable '
                'widget.' : 'When providing your own ScrollController, ensure both the '
                'Scrollbar and the Scrollable widget use the same one.'}',
          ),
        ]);
      }
      return true;
    }());
    assert(() {
      try {
        scrollController!.position;
      } catch (error) {
        if (scrollController == null ||
            scrollController.positions.length <= 1) {
          rethrow;
        }
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'The $controllerForError is currently attached to more than one '
            'ScrollPosition.',
          ),
          ErrorDescription(
            'The Scrollbar requires a single ScrollPosition in order to be painted.',
          ),
          ErrorHint(
            'When $when, the associated ScrollController must only have one '
            'ScrollPosition attached.'
            '${tryPrimary ? 'If a ScrollController has not been provided, the '
                'PrimaryScrollController is used by default on mobile platforms '
                'for ScrollViews with an Axis.vertical scroll direction. More '
                'than one ScrollView may have tried to use the '
                'PrimaryScrollController of the current context. '
                'ScrollView.primary can override this behavior.' : 'The provided ScrollController must be unique to one '
                'ScrollView widget.'}',
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  @protected
  void updateScrollbarPainter() {
    scrollbarPainter
      ..color = widget.thumbColor ?? const Color(0x66BCBCBC)
      ..trackRadius = widget.trackRadius
      ..trackColor = _showTrack
          ? widget.trackColor ?? const Color(0x08000000)
          : const Color(0x00000000)
      ..trackBorderColor = _showTrack
          ? widget.trackBorderColor ?? const Color(0x1a000000)
          : const Color(0x00000000)
      ..textDirection = Directionality.of(context)
      ..thickness = widget.thickness ?? _kScrollbarThickness
      ..radius = widget.radius
      ..padding = widget.padding ?? MediaQuery.paddingOf(context)
      ..scrollbarOrientation = widget.scrollbarOrientation
      ..mainAxisMargin = widget.mainAxisMargin
      ..shape = widget.shape
      ..crossAxisMargin = widget.crossAxisMargin
      ..minLength = widget.minThumbLength
      ..minOverscrollLength =
          widget.minOverscrollLength ?? widget.minThumbLength
      ..ignorePointer = !enableGestures;
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thumbVisibility != oldWidget.thumbVisibility) {
      if (widget.thumbVisibility ?? false) {
        assert(_debugScheduleCheckHasValidScrollPosition());
        _fadeoutTimer?.cancel();
        _fadeoutAnimationController.animateTo(1.0);
      } else {
        _fadeoutAnimationController.reverse();
      }
    }
  }

  void _updateScrollPosition(Offset updatedOffset) {
    assert(_cachedController != null);
    assert(_startDragScrollbarAxisOffset != null);
    assert(_lastDragUpdateOffset != null);
    assert(_startDragThumbOffset != null);

    final ScrollPosition position = _cachedController!.position;
    late double primaryDeltaFromDragStart;
    late double primaryDeltaFromLastDragUpdate;
    switch (position.axisDirection) {
      case AxisDirection.up:
        primaryDeltaFromDragStart =
            _startDragScrollbarAxisOffset!.dy - updatedOffset.dy;
        primaryDeltaFromLastDragUpdate =
            _lastDragUpdateOffset!.dy - updatedOffset.dy;
      case AxisDirection.right:
        primaryDeltaFromDragStart =
            updatedOffset.dx - _startDragScrollbarAxisOffset!.dx;
        primaryDeltaFromLastDragUpdate =
            updatedOffset.dx - _lastDragUpdateOffset!.dx;
      case AxisDirection.down:
        primaryDeltaFromDragStart =
            updatedOffset.dy - _startDragScrollbarAxisOffset!.dy;
        primaryDeltaFromLastDragUpdate =
            updatedOffset.dy - _lastDragUpdateOffset!.dy;
      case AxisDirection.left:
        primaryDeltaFromDragStart =
            _startDragScrollbarAxisOffset!.dx - updatedOffset.dx;
        primaryDeltaFromLastDragUpdate =
            _lastDragUpdateOffset!.dx - updatedOffset.dx;
    }

    // Convert primaryDelta, the amount that the scrollbar moved since the last
    // time when drag started or last updated, into the coordinate space of the scroll
    // position, and jump to that position.
    double scrollOffsetGlobal = scrollbarPainter
        .getTrackToScroll(primaryDeltaFromDragStart + _startDragThumbOffset!);
    if (primaryDeltaFromDragStart > 0 && scrollOffsetGlobal < position.pixels ||
        primaryDeltaFromDragStart < 0 && scrollOffsetGlobal > position.pixels) {
      // Adjust the position value if the scrolling direction conflicts with
      // the dragging direction due to scroll metrics shrink.
      scrollOffsetGlobal = position.pixels +
          scrollbarPainter.getTrackToScroll(primaryDeltaFromLastDragUpdate);
    }
    if (scrollOffsetGlobal != position.pixels) {
      // Ensure we don't drag into overscroll if the physics do not allow it.
      final double physicsAdjustment = position.physics
          .applyBoundaryConditions(position, scrollOffsetGlobal);
      double newPosition = scrollOffsetGlobal - physicsAdjustment;

      // The physics may allow overscroll when actually *scrolling*, but
      // dragging on the scrollbar does not always allow us to enter overscroll.
      switch (ScrollConfiguration.of(context).getPlatform(context)) {
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          newPosition = clampDouble(
              newPosition, position.minScrollExtent, position.maxScrollExtent);
        case TargetPlatform.iOS:
        case TargetPlatform.android:
          // We can only drag the scrollbar into overscroll on mobile
          // platforms, and only then if the physics allow it.
          break;
      }
      position.jumpTo(newPosition);
    }
  }

  void _maybeStartFadeoutTimer() {
    if (!showScrollbar) {
      _fadeoutTimer?.cancel();
      _fadeoutTimer = Timer(widget.timeToFade, () {
        _fadeoutAnimationController.reverse();
        _fadeoutTimer = null;
      });
    }
  }

  @protected
  Axis? getScrollbarDirection() {
    assert(_cachedController != null);
    if (_cachedController!.hasClients) {
      return _cachedController!.position.axis;
    }
    return null;
  }

  @protected
  @mustCallSuper
  void handleThumbPress() {
    assert(_debugCheckHasValidScrollPosition());
    if (getScrollbarDirection() == null) {
      return;
    }
    _fadeoutTimer?.cancel();
  }

  @protected
  @mustCallSuper
  void handleThumbPressStart(Offset localPosition) {
    assert(_debugCheckHasValidScrollPosition());
    _cachedController = _effectiveScrollController;
    final Axis? direction = getScrollbarDirection();
    if (direction == null) {
      return;
    }
    _fadeoutTimer?.cancel();
    _fadeoutAnimationController.forward();
    _startDragScrollbarAxisOffset = localPosition;
    _lastDragUpdateOffset = localPosition;
    _startDragThumbOffset = scrollbarPainter.getThumbScrollOffset();
    _thumbDragging = true;
  }

  @protected
  @mustCallSuper
  void handleThumbPressUpdate(Offset localPosition) {
    assert(_debugCheckHasValidScrollPosition());
    if (_lastDragUpdateOffset == localPosition) {
      return;
    }
    final ScrollPosition position = _cachedController!.position;
    if (!position.physics.shouldAcceptUserOffset(position)) {
      return;
    }
    final Axis? direction = getScrollbarDirection();
    if (direction == null) {
      return;
    }
    _updateScrollPosition(localPosition);
    _lastDragUpdateOffset = localPosition;
  }

  @protected
  @mustCallSuper
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    assert(_debugCheckHasValidScrollPosition());
    _thumbDragging = false;
    final Axis? direction = getScrollbarDirection();
    if (direction == null) {
      return;
    }
    _maybeStartFadeoutTimer();
    _startDragScrollbarAxisOffset = null;
    _lastDragUpdateOffset = null;
    _startDragThumbOffset = null;
    _cachedController = null;
  }

  void _handleTrackTapDown(TapDownDetails details) {
    // The Scrollbar should page towards the position of the tap on the track.
    assert(_debugCheckHasValidScrollPosition());
    _cachedController = _effectiveScrollController;

    final ScrollPosition position = _cachedController!.position;
    if (!position.physics.shouldAcceptUserOffset(position)) {
      return;
    }

    // Determines the scroll direction.
    final AxisDirection scrollDirection;

    switch (position.axisDirection) {
      case AxisDirection.up:
      case AxisDirection.down:
        if (details.localPosition.dy > scrollbarPainter._thumbOffset) {
          scrollDirection = AxisDirection.down;
        } else {
          scrollDirection = AxisDirection.up;
        }
      case AxisDirection.left:
      case AxisDirection.right:
        if (details.localPosition.dx > scrollbarPainter._thumbOffset) {
          scrollDirection = AxisDirection.right;
        } else {
          scrollDirection = AxisDirection.left;
        }
    }

    final ScrollableState? state =
        Scrollable.maybeOf(position.context.notificationContext!);
    final ScrollIntent intent = ScrollIntent(
        direction: scrollDirection, type: ScrollIncrementType.page);
    assert(state != null);
    final double scrollIncrement =
        ScrollAction.getDirectionalIncrement(state!, intent);

    _cachedController!.position.moveTo(
      _cachedController!.position.pixels + scrollIncrement,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
  }

  // ScrollController takes precedence over ScrollNotification
  bool _shouldUpdatePainter(Axis notificationAxis) {
    final ScrollController? scrollController = _effectiveScrollController;
    // Only update the painter of this scrollbar if the notification
    // metrics do not conflict with the information we have from the scroll
    // controller.

    // We do not have a scroll controller dictating axis.
    if (scrollController == null) {
      return true;
    }
    // Has more than one attached positions.
    if (scrollController.positions.length > 1) {
      return false;
    }

    return
        // The scroll controller is not attached to a position.
        !scrollController.hasClients
            // The notification matches the scroll controller's axis.
            ||
            scrollController.position.axis == notificationAxis;
  }

  bool _handleScrollMetricsNotification(
      ScrollMetricsNotification notification) {
    if (!widget.notificationPredicate(notification.asScrollUpdate())) {
      return false;
    }

    if (showScrollbar) {
      if (_fadeoutAnimationController.status != AnimationStatus.forward &&
          _fadeoutAnimationController.status != AnimationStatus.completed) {
        _fadeoutAnimationController.forward();
      }
    }

    final ScrollMetrics metrics = notification.metrics;
    if (_shouldUpdatePainter(metrics.axis)) {
      scrollbarPainter.update(metrics, metrics.axisDirection);
    }
    return false;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }

    final ScrollMetrics metrics = notification.metrics;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) {
      // Hide the bar when the Scrollable widget has no space to scroll.
      if (_fadeoutAnimationController.status != AnimationStatus.dismissed &&
          _fadeoutAnimationController.status != AnimationStatus.reverse) {
        _fadeoutAnimationController.reverse();
      }

      if (_shouldUpdatePainter(metrics.axis)) {
        scrollbarPainter.update(metrics, metrics.axisDirection);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      // Any movements always makes the scrollbar start showing up.
      if (_fadeoutAnimationController.status != AnimationStatus.forward &&
          _fadeoutAnimationController.status != AnimationStatus.completed) {
        _fadeoutAnimationController.forward();
      }

      _fadeoutTimer?.cancel();

      if (_shouldUpdatePainter(metrics.axis)) {
        scrollbarPainter.update(metrics, metrics.axisDirection);
      }
    } else if (notification is ScrollEndNotification) {
      if (_startDragScrollbarAxisOffset == null) {
        _maybeStartFadeoutTimer();
      }
    }
    return false;
  }

  Map<Type, GestureRecognizerFactory> get _gestures {
    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};
    if (_effectiveScrollController == null || !enableGestures) {
      return gestures;
    }

    gestures[_ThumbPressGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<_ThumbPressGestureRecognizer>(
      () => _ThumbPressGestureRecognizer(
        debugOwner: this,
        customPaintKey: _scrollbarPainterKey,
        duration: widget.pressDuration,
      ),
      (_ThumbPressGestureRecognizer instance) {
        instance.onLongPress = handleThumbPress;
        instance.onLongPressStart = (LongPressStartDetails details) =>
            handleThumbPressStart(details.localPosition);
        instance.onLongPressMoveUpdate = (LongPressMoveUpdateDetails details) =>
            handleThumbPressUpdate(details.localPosition);
        instance.onLongPressEnd = (LongPressEndDetails details) =>
            handleThumbPressEnd(details.localPosition, details.velocity);
      },
    );

    gestures[_TrackTapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<_TrackTapGestureRecognizer>(
      () => _TrackTapGestureRecognizer(
        debugOwner: this,
        customPaintKey: _scrollbarPainterKey,
      ),
      (_TrackTapGestureRecognizer instance) {
        instance.onTapDown = _handleTrackTapDown;
      },
    );

    return gestures;
  }

  @protected
  bool isPointerOverTrack(Offset position, PointerDeviceKind kind) {
    if (_scrollbarPainterKey.currentContext == null) {
      return false;
    }
    final Offset localOffset = _getLocalOffset(_scrollbarPainterKey, position);
    return scrollbarPainter.hitTestInteractive(localOffset, kind) &&
        !scrollbarPainter.hitTestOnlyThumbInteractive(localOffset, kind);
  }

  @protected
  bool isPointerOverThumb(Offset position, PointerDeviceKind kind) {
    if (_scrollbarPainterKey.currentContext == null) {
      return false;
    }
    final Offset localOffset = _getLocalOffset(_scrollbarPainterKey, position);
    return scrollbarPainter.hitTestOnlyThumbInteractive(localOffset, kind);
  }

  @protected
  bool isPointerOverScrollbar(Offset position, PointerDeviceKind kind,
      {bool forHover = false}) {
    if (_scrollbarPainterKey.currentContext == null) {
      return false;
    }
    final Offset localOffset = _getLocalOffset(_scrollbarPainterKey, position);
    return scrollbarPainter.hitTestInteractive(localOffset, kind,
        forHover: true);
  }

  @protected
  @mustCallSuper
  void handleHover(PointerHoverEvent event) {
    // Check if the position of the pointer falls over the painted scrollbar
    if (isPointerOverScrollbar(event.position, event.kind, forHover: true)) {
      _hoverIsActive = true;
      // Bring the scrollbar back into view if it has faded or started to fade
      // away.
      _fadeoutAnimationController.forward();
      _fadeoutTimer?.cancel();
    } else if (_hoverIsActive) {
      // Pointer is not over painted scrollbar.
      _hoverIsActive = false;
      _maybeStartFadeoutTimer();
    }
  }

  @protected
  @mustCallSuper
  void handleHoverExit(PointerExitEvent event) {
    _hoverIsActive = false;
    _maybeStartFadeoutTimer();
  }

  // Returns the delta that should result from applying [event] with axis and
  // direction taken into account.
  double _pointerSignalEventDelta(PointerScrollEvent event) {
    assert(_cachedController != null);
    double delta = _cachedController!.position.axis == Axis.horizontal
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;

    if (axisDirectionIsReversed(_cachedController!.position.axisDirection)) {
      delta *= -1;
    }
    return delta;
  }

  // Returns the offset that should result from applying [event] to the current
  // position, taking min/max scroll extent into account.
  double _targetScrollOffsetForPointerScroll(double delta) {
    assert(_cachedController != null);
    return math.min(
      math.max(_cachedController!.position.pixels + delta,
          _cachedController!.position.minScrollExtent),
      _cachedController!.position.maxScrollExtent,
    );
  }

  void _handlePointerScroll(PointerEvent event) {
    assert(event is PointerScrollEvent);
    _cachedController = _effectiveScrollController;
    final double delta = _pointerSignalEventDelta(event as PointerScrollEvent);
    final double targetScrollOffset =
        _targetScrollOffsetForPointerScroll(delta);
    if (delta != 0.0 &&
        targetScrollOffset != _cachedController!.position.pixels) {
      _cachedController!.position.pointerScroll(delta);
    }
  }

  void _receivedPointerSignal(PointerSignalEvent event) {
    _cachedController = _effectiveScrollController;
    // Only try to scroll if the bar absorb the hit test.
    if ((scrollbarPainter.hitTest(event.localPosition) ?? false) &&
        _cachedController != null &&
        _cachedController!.hasClients &&
        (!_thumbDragging || kIsWeb)) {
      final ScrollPosition position = _cachedController!.position;
      if (event is PointerScrollEvent) {
        if (!position.physics.shouldAcceptUserOffset(position)) {
          return;
        }
        final double delta = _pointerSignalEventDelta(event);
        final double targetScrollOffset =
            _targetScrollOffsetForPointerScroll(delta);
        if (delta != 0.0 && targetScrollOffset != position.pixels) {
          GestureBinding.instance.pointerSignalResolver
              .register(event, _handlePointerScroll);
        }
      } else if (event is PointerScrollInertiaCancelEvent) {
        position.jumpTo(position.pixels);
        // Don't use the pointer signal resolver, all hit-tested scrollables should stop.
      }
    }
  }

  @override
  void dispose() {
    _fadeoutAnimationController.dispose();
    _fadeoutTimer?.cancel();
    scrollbarPainter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    updateScrollbarPainter();

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _handleScrollMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: RepaintBoundary(
          child: Listener(
            onPointerSignal: _receivedPointerSignal,
            child: RawGestureDetector(
              gestures: _gestures,
              child: MouseRegion(
                onExit: (PointerExitEvent event) {
                  switch (event.kind) {
                    case PointerDeviceKind.mouse:
                    case PointerDeviceKind.trackpad:
                      if (enableGestures) {
                        handleHoverExit(event);
                      }
                    case PointerDeviceKind.stylus:
                    case PointerDeviceKind.invertedStylus:
                    case PointerDeviceKind.unknown:
                    case PointerDeviceKind.touch:
                      break;
                  }
                },
                onHover: (PointerHoverEvent event) {
                  switch (event.kind) {
                    case PointerDeviceKind.mouse:
                    case PointerDeviceKind.trackpad:
                      if (enableGestures) {
                        handleHover(event);
                      }
                    case PointerDeviceKind.stylus:
                    case PointerDeviceKind.invertedStylus:
                    case PointerDeviceKind.unknown:
                    case PointerDeviceKind.touch:
                      break;
                  }
                },
                child: CustomPaint(
                  key: _scrollbarPainterKey,
                  foregroundPainter: scrollbarPainter,
                  child: RepaintBoundary(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A long press gesture detector that only responds to events on the scrollbar's
// thumb and ignores everything else.
class _ThumbPressGestureRecognizer extends LongPressGestureRecognizer {
  _ThumbPressGestureRecognizer({
    required Object super.debugOwner,
    required GlobalKey customPaintKey,
    required super.duration,
  }) : _customPaintKey = customPaintKey;

  final GlobalKey _customPaintKey;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (!_hitTestInteractive(_customPaintKey, event.position, event.kind)) {
      return false;
    }
    return super.isPointerAllowed(event);
  }

  bool _hitTestInteractive(
      GlobalKey customPaintKey, Offset offset, PointerDeviceKind kind) {
    if (customPaintKey.currentContext == null) {
      return false;
    }
    final CustomPaint customPaint =
        customPaintKey.currentContext!.widget as CustomPaint;
    final ScrollbarPainter painter =
        customPaint.foregroundPainter! as ScrollbarPainter;
    final Offset localOffset = _getLocalOffset(customPaintKey, offset);
    return painter.hitTestOnlyThumbInteractive(localOffset, kind);
  }
}

// A tap gesture detector that only responds to events on the scrollbar's
// track and ignores everything else, including the thumb.
class _TrackTapGestureRecognizer extends TapGestureRecognizer {
  _TrackTapGestureRecognizer({
    required super.debugOwner,
    required GlobalKey customPaintKey,
  }) : _customPaintKey = customPaintKey;

  final GlobalKey _customPaintKey;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (!_hitTestInteractive(_customPaintKey, event.position, event.kind)) {
      return false;
    }
    return super.isPointerAllowed(event);
  }

  bool _hitTestInteractive(
      GlobalKey customPaintKey, Offset offset, PointerDeviceKind kind) {
    if (customPaintKey.currentContext == null) {
      return false;
    }
    final CustomPaint customPaint =
        customPaintKey.currentContext!.widget as CustomPaint;
    final ScrollbarPainter painter =
        customPaint.foregroundPainter! as ScrollbarPainter;
    final Offset localOffset = _getLocalOffset(customPaintKey, offset);
    // We only receive track taps that are not on the thumb.
    return painter.hitTestInteractive(localOffset, kind) &&
        !painter.hitTestOnlyThumbInteractive(localOffset, kind);
  }
}

Offset _getLocalOffset(GlobalKey scrollbarPainterKey, Offset position) {
  final RenderBox renderBox =
      scrollbarPainterKey.currentContext!.findRenderObject()! as RenderBox;
  return renderBox.globalToLocal(position);
}
