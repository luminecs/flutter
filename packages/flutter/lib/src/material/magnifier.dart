
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class TextMagnifier extends StatefulWidget {
  const TextMagnifier({
    super.key,
    required this.magnifierInfo,
  });

  static TextMagnifierConfiguration adaptiveMagnifierConfiguration = TextMagnifierConfiguration(
    shouldDisplayHandlesInMagnifier: defaultTargetPlatform == TargetPlatform.iOS,
    magnifierBuilder: (
      BuildContext context,
      MagnifierController controller,
      ValueNotifier<MagnifierInfo> magnifierInfo,
    ) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          return CupertinoTextMagnifier(
            controller: controller,
            magnifierInfo: magnifierInfo,
          );
        case TargetPlatform.android:
          return TextMagnifier(
              magnifierInfo: magnifierInfo,
          );
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          return null;
      }
    }
  );

  @visibleForTesting
  static const Duration jumpBetweenLinesAnimationDuration =
      Duration(milliseconds: 70);

  final ValueNotifier<MagnifierInfo>
      magnifierInfo;

  @override
  State<TextMagnifier> createState() => _TextMagnifierState();
}

class _TextMagnifierState extends State<TextMagnifier> {
  // Should _only_ be null on construction. This is because of the animation logic.
  //
  // Animations are added when `last_build_y != current_build_y`. This condition
  // is true on the initial render, which would mean that the initial
  // build would be animated - this is undesired. Thus, this is null for the
  // first frame and the condition becomes `magnifierPosition != null && last_build_y != this_build_y`.
  Offset? _magnifierPosition;

  // A timer that unsets itself after an animation duration.
  // If the timer exists, then the magnifier animates its position -
  // if this timer does not exist, the magnifier tracks the gesture (with respect
  // to the positioning rules) directly.
  Timer? _positionShouldBeAnimatedTimer;
  bool get _positionShouldBeAnimated => _positionShouldBeAnimatedTimer != null;

  Offset _extraFocalPointOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.magnifierInfo
        .addListener(_determineMagnifierPositionAndFocalPoint);
  }

  @override
  void dispose() {
    widget.magnifierInfo
        .removeListener(_determineMagnifierPositionAndFocalPoint);
    _positionShouldBeAnimatedTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _determineMagnifierPositionAndFocalPoint();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(TextMagnifier oldWidget) {
    if (oldWidget.magnifierInfo != widget.magnifierInfo) {
      oldWidget.magnifierInfo.removeListener(_determineMagnifierPositionAndFocalPoint);
      widget.magnifierInfo.addListener(_determineMagnifierPositionAndFocalPoint);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _determineMagnifierPositionAndFocalPoint() {
    final MagnifierInfo selectionInfo =
        widget.magnifierInfo.value;
    final Rect screenRect = Offset.zero & MediaQuery.sizeOf(context);

    // Since by default we draw at the top left corner, this offset
    // shifts the magnifier so we draw at the center, and then also includes
    // the "above touch point" shift.
    final Offset basicMagnifierOffset = Offset(
        Magnifier.kDefaultMagnifierSize.width / 2,
        Magnifier.kDefaultMagnifierSize.height +
            Magnifier.kStandardVerticalFocalPointShift);

    // Since the magnifier should not go past the edges of the line,
    // but must track the gesture otherwise, constrain the X of the magnifier
    // to always stay between line start and end.
    final double magnifierX = clampDouble(
        selectionInfo.globalGesturePosition.dx,
        selectionInfo.currentLineBoundaries.left,
        selectionInfo.currentLineBoundaries.right);

    // Place the magnifier at the previously calculated X, and the Y should be
    // exactly at the center of the handle.
    final Rect unadjustedMagnifierRect =
        Offset(magnifierX, selectionInfo.caretRect.center.dy) - basicMagnifierOffset &
            Magnifier.kDefaultMagnifierSize;

    // Shift the magnifier so that, if we are ever out of the screen, we become in bounds.
    // This probably won't have much of an effect on the X, since it is already bound
    // to the currentLineBoundaries, but will shift vertically if the magnifier is out of bounds.
    final Rect screenBoundsAdjustedMagnifierRect =
        MagnifierController.shiftWithinBounds(
            bounds: screenRect, rect: unadjustedMagnifierRect);

    // Done with the magnifier position!
    final Offset finalMagnifierPosition = screenBoundsAdjustedMagnifierRect.topLeft;

    // The insets, from either edge, that the focal point should not point
    // past lest the magnifier displays something out of bounds.
    final double horizontalMaxFocalPointEdgeInsets =
        (Magnifier.kDefaultMagnifierSize.width / 2) / Magnifier._magnification;

    // Adjust the focal point horizontally such that none of the magnifier
    // ever points to anything out of bounds.
    final double newGlobalFocalPointX;

    // If the text field is so narrow that we must show out of bounds,
    // then settle for pointing to the center all the time.
    if (selectionInfo.fieldBounds.width <
        horizontalMaxFocalPointEdgeInsets * 2) {
      newGlobalFocalPointX = selectionInfo.fieldBounds.center.dx;
    } else {
      // Otherwise, we can clamp the focal point to always point in bounds.
      newGlobalFocalPointX = clampDouble(
          screenBoundsAdjustedMagnifierRect.center.dx,
          selectionInfo.fieldBounds.left + horizontalMaxFocalPointEdgeInsets,
          selectionInfo.fieldBounds.right - horizontalMaxFocalPointEdgeInsets);
    }

    // Since the previous value is now a global offset (i.e. `newGlobalFocalPoint`
    // is now a global offset), we must subtract the magnifier's global offset
    // to obtain the relative shift in the focal point.
    final double newRelativeFocalPointX =
        newGlobalFocalPointX - screenBoundsAdjustedMagnifierRect.center.dx;

    // The Y component means that if we are pressed up against the top of the screen,
    // then we should adjust the focal point such that it now points to how far we moved
    // the magnifier. screenBoundsAdjustedMagnifierRect.top == unadjustedMagnifierRect.top for most cases,
    // but when pressed up against the top of the screen, we adjust the focal point by
    // the amount that we shifted from our "natural" position.
    final Offset focalPointAdjustmentForScreenBoundsAdjustment = Offset(
        newRelativeFocalPointX,
        unadjustedMagnifierRect.top - screenBoundsAdjustedMagnifierRect.top,
    );

    Timer? positionShouldBeAnimated = _positionShouldBeAnimatedTimer;

    if (_magnifierPosition != null && finalMagnifierPosition.dy != _magnifierPosition!.dy) {
      if (_positionShouldBeAnimatedTimer != null &&
          _positionShouldBeAnimatedTimer!.isActive) {
        _positionShouldBeAnimatedTimer!.cancel();
      }

      // Create a timer that deletes itself when the timer is complete.
      // This is `mounted` safe, since the timer is canceled in `dispose`.
      positionShouldBeAnimated = Timer(
          TextMagnifier.jumpBetweenLinesAnimationDuration,
          () => setState(() {
                _positionShouldBeAnimatedTimer = null;
              }));
    }

    setState(() {
      _magnifierPosition = finalMagnifierPosition;
      _positionShouldBeAnimatedTimer = positionShouldBeAnimated;
      _extraFocalPointOffset = focalPointAdjustmentForScreenBoundsAdjustment;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(_magnifierPosition != null,
        'Magnifier position should only be null before the first build.');

    return AnimatedPositioned(
      top: _magnifierPosition!.dy,
      left: _magnifierPosition!.dx,
      // Material magnifier typically does not animate, unless we jump between lines,
      // in which case we animate between lines.
      duration: _positionShouldBeAnimated
          ? TextMagnifier.jumpBetweenLinesAnimationDuration
          : Duration.zero,
      child: Magnifier(
        additionalFocalPointOffset: _extraFocalPointOffset,
      ),
    );
  }
}

class Magnifier extends StatelessWidget {
  const Magnifier({
    super.key,
    this.additionalFocalPointOffset = Offset.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(_borderRadius)),
    this.filmColor = const Color.fromARGB(8, 158, 158, 158),
    this.shadows = const <BoxShadow>[
      BoxShadow(
          blurRadius: 1.5,
          offset: Offset(0, 2),
          spreadRadius: 0.75,
          color: Color.fromARGB(25, 0, 0, 0))
    ],
    this.size = Magnifier.kDefaultMagnifierSize,
  });

  @visibleForTesting
  static const Size kDefaultMagnifierSize = Size(77.37, 37.9);

  @visibleForTesting
  static const double kStandardVerticalFocalPointShift = 22;

  static const double _borderRadius = 40;
  static const double _magnification = 1.25;

  final Offset additionalFocalPointOffset;

  final BorderRadius borderRadius;

  final Color filmColor;

  final List<BoxShadow> shadows;

  final Size size;

  @override
  Widget build(BuildContext context) {
    return RawMagnifier(
      decoration: MagnifierDecoration(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        shadows: shadows,
      ),
      magnificationScale: _magnification,
      focalPointOffset: additionalFocalPointOffset +
          Offset(0, kStandardVerticalFocalPointShift + kDefaultMagnifierSize.height / 2),
      size: size,
      child: ColoredBox(
        color: filmColor,
      ),
    );
  }
}