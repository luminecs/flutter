
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

class CupertinoTextMagnifier extends StatefulWidget {
  const CupertinoTextMagnifier({
    super.key,
    this.animationCurve = Curves.easeOut,
    required this.controller,
    this.dragResistance = 10.0,
    this.hideBelowThreshold = 48.0,
    this.horizontalScreenEdgePadding = 10.0,
    required this.magnifierInfo,
  });

  final Curve animationCurve;

  final MagnifierController controller;

  final double dragResistance;

  final double hideBelowThreshold;

  final double horizontalScreenEdgePadding;

  final ValueNotifier<MagnifierInfo>
      magnifierInfo;

  static const Duration _kDragAnimationDuration = Duration(milliseconds: 45);

  @override
  State<CupertinoTextMagnifier> createState() =>
      _CupertinoTextMagnifierState();
}

class _CupertinoTextMagnifierState extends State<CupertinoTextMagnifier>
    with SingleTickerProviderStateMixin {
  // Initialize to dummy values for the event that the initial call to
  // _determineMagnifierPositionAndFocalPoint calls hide, and thus does not
  // set these values.
  Offset _currentAdjustedMagnifierPosition = Offset.zero;
  double _verticalFocalPointAdjustment = 0;
  late AnimationController _ioAnimationController;
  late Animation<double> _ioAnimation;

  @override
  void initState() {
    super.initState();
    _ioAnimationController = AnimationController(
      value: 0,
      vsync: this,
      duration: CupertinoMagnifier._kInOutAnimationDuration,
    )..addListener(() => setState(() {}));

    widget.controller.animationController = _ioAnimationController;
    widget.magnifierInfo
        .addListener(_determineMagnifierPositionAndFocalPoint);

    _ioAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ioAnimationController,
      curve: widget.animationCurve,
    ));
  }

  @override
  void dispose() {
    widget.controller.animationController = null;
    _ioAnimationController.dispose();
    widget.magnifierInfo
        .removeListener(_determineMagnifierPositionAndFocalPoint);
    super.dispose();
  }

  @override
  void didUpdateWidget(CupertinoTextMagnifier oldWidget) {
    if (oldWidget.magnifierInfo != widget.magnifierInfo) {
      oldWidget.magnifierInfo.removeListener(_determineMagnifierPositionAndFocalPoint);
      widget.magnifierInfo.addListener(_determineMagnifierPositionAndFocalPoint);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    _determineMagnifierPositionAndFocalPoint();
    super.didChangeDependencies();
  }

  void _determineMagnifierPositionAndFocalPoint() {
    final MagnifierInfo textEditingContext =
        widget.magnifierInfo.value;

    // The exact Y of the center of the current line.
    final double verticalCenterOfCurrentLine =
        textEditingContext.caretRect.center.dy;

    // If the magnifier is currently showing, but we have dragged out of threshold,
    // we should hide it.
    if (verticalCenterOfCurrentLine -
            textEditingContext.globalGesturePosition.dy <
        -widget.hideBelowThreshold) {
      // Only signal a hide if we are currently showing.
      if (widget.controller.shown) {
        widget.controller.hide(removeFromOverlay: false);
      }
      return;
    }

    // If we are gone, but got to this point, we shouldn't be: show.
    if (!widget.controller.shown) {
      _ioAnimationController.forward();
    }

    // Never go above the center of the line, but have some resistance
    // going downward if the drag goes too far.
    final double verticalPositionOfLens = math.max(
        verticalCenterOfCurrentLine,
        verticalCenterOfCurrentLine -
            (verticalCenterOfCurrentLine -
                    textEditingContext.globalGesturePosition.dy) /
                widget.dragResistance);

    // The raw position, tracking the gesture directly.
    final Offset rawMagnifierPosition = Offset(
      textEditingContext.globalGesturePosition.dx -
          CupertinoMagnifier.kDefaultSize.width / 2,
      verticalPositionOfLens -
          (CupertinoMagnifier.kDefaultSize.height -
              CupertinoMagnifier.kMagnifierAboveFocalPoint),
    );

    final Rect screenRect = Offset.zero & MediaQuery.sizeOf(context);

    // Adjust the magnifier position so that it never exists outside the horizontal
    // padding.
    final Offset adjustedMagnifierPosition = MagnifierController.shiftWithinBounds(
      bounds: Rect.fromLTRB(
          screenRect.left + widget.horizontalScreenEdgePadding,
          // iOS doesn't reposition for Y, so we should expand the threshold
          // so we can send the whole magnifier out of bounds if need be.
          screenRect.top -
              (CupertinoMagnifier.kDefaultSize.height +
                  CupertinoMagnifier.kMagnifierAboveFocalPoint),
          screenRect.right - widget.horizontalScreenEdgePadding,
          screenRect.bottom +
              (CupertinoMagnifier.kDefaultSize.height +
                  CupertinoMagnifier.kMagnifierAboveFocalPoint)),
      rect: rawMagnifierPosition & CupertinoMagnifier.kDefaultSize,
    ).topLeft;

    setState(() {
      _currentAdjustedMagnifierPosition = adjustedMagnifierPosition;
      // The lens should always point to the center of the line.
      _verticalFocalPointAdjustment =
          verticalCenterOfCurrentLine - verticalPositionOfLens;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: CupertinoTextMagnifier._kDragAnimationDuration,
      curve: widget.animationCurve,
      left: _currentAdjustedMagnifierPosition.dx,
      top: _currentAdjustedMagnifierPosition.dy,
      child: CupertinoMagnifier(
        inOutAnimation: _ioAnimation,
        additionalFocalPointOffset: Offset(0, _verticalFocalPointAdjustment),
      ),
    );
  }
}

class CupertinoMagnifier extends StatelessWidget {
  const CupertinoMagnifier({
    super.key,
    this.size = kDefaultSize,
    this.borderRadius = const BorderRadius.all(Radius.elliptical(60, 50)),
    this.additionalFocalPointOffset = Offset.zero,
    this.shadows = const <BoxShadow>[
      BoxShadow(
        color: Color.fromARGB(25, 0, 0, 0),
        blurRadius: 11,
        spreadRadius: 0.2,
      ),
    ],
    this.borderSide =
        const BorderSide(color: Color.fromARGB(255, 232, 232, 232)),
    this.inOutAnimation,
  });

  final List<BoxShadow> shadows;

  final BorderSide borderSide;

  @visibleForTesting
  static const double kMagnifierAboveFocalPoint = -26;

  @visibleForTesting
  static const Size kDefaultSize = Size(80, 47.5);

  static const Duration _kInOutAnimationDuration = Duration(milliseconds: 150);

  final Size size;

  final BorderRadius borderRadius;

  final Animation<double>? inOutAnimation;

  final Offset additionalFocalPointOffset;

  @override
  Widget build(BuildContext context) {
    Offset focalPointOffset =
        Offset(0, (kDefaultSize.height / 2) - kMagnifierAboveFocalPoint);
    focalPointOffset.scale(1, inOutAnimation?.value ?? 1);
    focalPointOffset += additionalFocalPointOffset;

    return Transform.translate(
      offset: Offset.lerp(
        const Offset(0, -kMagnifierAboveFocalPoint),
        Offset.zero,
        inOutAnimation?.value ?? 1,
      )!,
      child: RawMagnifier(
        size: size,
        focalPointOffset: focalPointOffset,
        decoration: MagnifierDecoration(
          opacity: inOutAnimation?.value ?? 1,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: borderSide,
          ),
          shadows: shadows,
        ),
      ),
    );
  }
}