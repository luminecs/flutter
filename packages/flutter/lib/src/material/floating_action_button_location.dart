// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'scaffold.dart';

const double kFloatingActionButtonMargin = 16.0;

const Duration kFloatingActionButtonSegue = Duration(milliseconds: 200);

const double kFloatingActionButtonTurnInterval = 0.125;

const double kMiniButtonOffsetAdjustment = 4.0;

abstract class FloatingActionButtonLocation {
  const FloatingActionButtonLocation();

  static const FloatingActionButtonLocation startTop = _StartTopFabLocation();

  static const FloatingActionButtonLocation miniStartTop = _MiniStartTopFabLocation();

  static const FloatingActionButtonLocation centerTop = _CenterTopFabLocation();

  static const FloatingActionButtonLocation miniCenterTop = _MiniCenterTopFabLocation();

  static const FloatingActionButtonLocation endTop = _EndTopFabLocation();

  static const FloatingActionButtonLocation miniEndTop = _MiniEndTopFabLocation();

  static const FloatingActionButtonLocation startFloat = _StartFloatFabLocation();

  static const FloatingActionButtonLocation miniStartFloat = _MiniStartFloatFabLocation();

  static const FloatingActionButtonLocation centerFloat = _CenterFloatFabLocation();

  static const FloatingActionButtonLocation miniCenterFloat = _MiniCenterFloatFabLocation();

  static const FloatingActionButtonLocation endFloat = _EndFloatFabLocation();

  static const FloatingActionButtonLocation miniEndFloat = _MiniEndFloatFabLocation();

  static const FloatingActionButtonLocation startDocked = _StartDockedFabLocation();

  static const FloatingActionButtonLocation miniStartDocked = _MiniStartDockedFabLocation();

  static const FloatingActionButtonLocation centerDocked = _CenterDockedFabLocation();

  static const FloatingActionButtonLocation miniCenterDocked = _MiniCenterDockedFabLocation();

  static const FloatingActionButtonLocation endDocked = _EndDockedFabLocation();

  static const FloatingActionButtonLocation miniEndDocked = _MiniEndDockedFabLocation();

  static const FloatingActionButtonLocation endContained = _EndContainedFabLocation();

  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry);

  @override
  String toString() => objectRuntimeType(this, 'FloatingActionButtonLocation');
}

abstract class StandardFabLocation extends FloatingActionButtonLocation {
  const StandardFabLocation();

  double getOffsetX(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment);

  double getOffsetY(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment);

  bool isMini () => false;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double adjustment = isMini() ? kMiniButtonOffsetAdjustment : 0.0;
    return Offset(
      getOffsetX(scaffoldGeometry, adjustment),
      getOffsetY(scaffoldGeometry, adjustment),
    );
  }

  static double _leftOffsetX(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    return kFloatingActionButtonMargin
        + scaffoldGeometry.minInsets.left
        - adjustment;
  }

  static double _rightOffsetX(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    return scaffoldGeometry.scaffoldSize.width
        - kFloatingActionButtonMargin
        - scaffoldGeometry.minInsets.right
        - scaffoldGeometry.floatingActionButtonSize.width
        + adjustment;
  }


}

mixin FabTopOffsetY on StandardFabLocation {
  @override
  double getOffsetY(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    if (scaffoldGeometry.contentTop > scaffoldGeometry.minViewPadding.top) {
      final double fabHalfHeight = scaffoldGeometry.floatingActionButtonSize.height / 2.0;
      return scaffoldGeometry.contentTop - fabHalfHeight;
    }
    // Otherwise, ensure we are placed within the bounds of a safe area.
    return scaffoldGeometry.minViewPadding.top;
  }
}

mixin FabFloatOffsetY on StandardFabLocation {
  @override
  double getOffsetY(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double bottomContentHeight = scaffoldGeometry.scaffoldSize.height - contentBottom;
    final double bottomSheetHeight = scaffoldGeometry.bottomSheetSize.height;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final double snackBarHeight = scaffoldGeometry.snackBarSize.height;
    final double safeMargin = math.max(
      kFloatingActionButtonMargin,
      scaffoldGeometry.minViewPadding.bottom - bottomContentHeight + kFloatingActionButtonMargin,
    );

    double fabY = contentBottom - fabHeight - safeMargin;
    if (snackBarHeight > 0.0) {
      fabY = math.min(fabY, contentBottom - snackBarHeight - fabHeight - kFloatingActionButtonMargin);
    }
    if (bottomSheetHeight > 0.0) {
      fabY = math.min(fabY, contentBottom - bottomSheetHeight - fabHeight / 2.0);
    }
    return fabY + adjustment;
  }
}

mixin FabDockedOffsetY on StandardFabLocation {
  @override
  double getOffsetY(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double contentMargin = scaffoldGeometry.scaffoldSize.height - contentBottom;
    final double bottomViewPadding = scaffoldGeometry.minViewPadding.bottom;
    final double bottomSheetHeight = scaffoldGeometry.bottomSheetSize.height;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final double snackBarHeight = scaffoldGeometry.snackBarSize.height;
    final double bottomMinInset = scaffoldGeometry.minInsets.bottom;

    double safeMargin;

    if (contentMargin > bottomMinInset + fabHeight / 2.0) {
      // If contentMargin is higher than bottomMinInset enough to display the
      // FAB without clipping, don't provide a margin
      safeMargin = 0.0;
    } else if (bottomMinInset == 0.0) {
      // If bottomMinInset is zero(the software keyboard is not on the screen)
      // provide bottomViewPadding as margin
      safeMargin = bottomViewPadding;
    } else {
      // Provide a margin that would shift the FAB enough so that it stays away
      // from the keyboard
      safeMargin = fabHeight / 2.0 + kFloatingActionButtonMargin;
    }

    double fabY = contentBottom - fabHeight / 2.0 - safeMargin;
    // The FAB should sit with a margin between it and the snack bar.
    if (snackBarHeight > 0.0) {
      fabY = math.min(fabY, contentBottom - snackBarHeight - fabHeight - kFloatingActionButtonMargin);
    }
    // The FAB should sit with its center in front of the top of the bottom sheet.
    if (bottomSheetHeight > 0.0) {
      fabY = math.min(fabY, contentBottom - bottomSheetHeight - fabHeight / 2.0);
    }
    final double maxFabY = scaffoldGeometry.scaffoldSize.height - fabHeight - safeMargin;
    return math.min(maxFabY, fabY);
  }
}

mixin FabContainedOffsetY on StandardFabLocation {
  @override
  double getOffsetY(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double contentMargin = scaffoldGeometry.scaffoldSize.height - contentBottom;
    final double bottomViewPadding = scaffoldGeometry.minViewPadding.bottom;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;

    double safeMargin;
    if (contentMargin > bottomViewPadding + fabHeight) {
      // If contentMargin is higher than bottomViewPadding enough to display the
      // FAB without clipping, don't provide a margin
      safeMargin = 0.0;
    } else {
      safeMargin = bottomViewPadding;
    }

    // This is to compute the distance between the content bottom to the top edge
    // of the floating action button. This can be negative if content margin is
    // too small.
    final double contentBottomToFabTop = (contentMargin - bottomViewPadding - fabHeight) / 2.0;
    final double fabY = contentBottom + contentBottomToFabTop;
    final double maxFabY = scaffoldGeometry.scaffoldSize.height - fabHeight - safeMargin;

    return math.min(maxFabY, fabY);
  }
}

mixin FabStartOffsetX on StandardFabLocation {
  @override
  double getOffsetX(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    switch (scaffoldGeometry.textDirection) {
      case TextDirection.rtl:
        return StandardFabLocation._rightOffsetX(scaffoldGeometry, adjustment);
      case TextDirection.ltr:
        return StandardFabLocation._leftOffsetX(scaffoldGeometry, adjustment);
    }
  }
}

mixin FabCenterOffsetX on StandardFabLocation {
  @override
  double getOffsetX(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    return (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2.0;
  }
}

mixin FabEndOffsetX on StandardFabLocation {
  @override
  double getOffsetX(ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    switch (scaffoldGeometry.textDirection) {
      case TextDirection.rtl:
        return StandardFabLocation._leftOffsetX(scaffoldGeometry, adjustment);
      case TextDirection.ltr:
        return StandardFabLocation._rightOffsetX(scaffoldGeometry, adjustment);
    }
  }
}

mixin FabMiniOffsetAdjustment on StandardFabLocation {
  @override
  bool isMini () => true;
}

class _StartTopFabLocation extends StandardFabLocation
    with FabStartOffsetX, FabTopOffsetY {
  const _StartTopFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.startTop';
}

class _MiniStartTopFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabStartOffsetX, FabTopOffsetY {
  const _MiniStartTopFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniStartTop';
}

class _CenterTopFabLocation extends StandardFabLocation
    with FabCenterOffsetX, FabTopOffsetY {
  const _CenterTopFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.centerTop';
}

class _MiniCenterTopFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabCenterOffsetX, FabTopOffsetY {
  const _MiniCenterTopFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniCenterTop';
}

class _EndTopFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabTopOffsetY {
  const _EndTopFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.endTop';
}

class _MiniEndTopFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabEndOffsetX, FabTopOffsetY {
  const _MiniEndTopFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniEndTop';
}

class _StartFloatFabLocation extends StandardFabLocation
    with FabStartOffsetX, FabFloatOffsetY {
  const _StartFloatFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.startFloat';
}

class _MiniStartFloatFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabStartOffsetX, FabFloatOffsetY {
  const _MiniStartFloatFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniStartFloat';
}

class _CenterFloatFabLocation extends StandardFabLocation
    with FabCenterOffsetX, FabFloatOffsetY {
  const _CenterFloatFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.centerFloat';
}

class _MiniCenterFloatFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabCenterOffsetX, FabFloatOffsetY {
  const _MiniCenterFloatFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniCenterFloat';
}

class _EndFloatFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  const _EndFloatFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.endFloat';
}

class _MiniEndFloatFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabEndOffsetX, FabFloatOffsetY {
  const _MiniEndFloatFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniEndFloat';
}

class _StartDockedFabLocation extends StandardFabLocation
    with FabStartOffsetX, FabDockedOffsetY {
  const _StartDockedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.startDocked';
}

class _MiniStartDockedFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabStartOffsetX, FabDockedOffsetY {
  const _MiniStartDockedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniStartDocked';
}

class _CenterDockedFabLocation extends StandardFabLocation
    with FabCenterOffsetX, FabDockedOffsetY {
  const _CenterDockedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.centerDocked';
}

class _MiniCenterDockedFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabCenterOffsetX, FabDockedOffsetY {
  const _MiniCenterDockedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniCenterDocked';
}

class _EndDockedFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabDockedOffsetY {
  const _EndDockedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.endDocked';
}

class _MiniEndDockedFabLocation extends StandardFabLocation
    with FabMiniOffsetAdjustment, FabEndOffsetX, FabDockedOffsetY {
  const _MiniEndDockedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.miniEndDocked';
}

class _EndContainedFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabContainedOffsetY {
  const _EndContainedFabLocation();

  @override
  String toString() => 'FloatingActionButtonLocation.endContained';
}

abstract class FloatingActionButtonAnimator {
  const FloatingActionButtonAnimator();

  static const FloatingActionButtonAnimator scaling = _ScalingFabMotionAnimator();

  Offset getOffset({ required Offset begin, required Offset end, required double progress });

  Animation<double> getScaleAnimation({ required Animation<double> parent });

  Animation<double> getRotationAnimation({ required Animation<double> parent });

  double getAnimationRestart(double previousValue) => 0.0;

  @override
  String toString() => objectRuntimeType(this, 'FloatingActionButtonAnimator');
}

class _ScalingFabMotionAnimator extends FloatingActionButtonAnimator {
  const _ScalingFabMotionAnimator();

  @override
  Offset getOffset({ required Offset begin, required Offset end, required double progress }) {
    if (progress < 0.5) {
      return begin;
    } else {
      return end;
    }
  }

  @override
  Animation<double> getScaleAnimation({ required Animation<double> parent }) {
    // Animate the scale down from 1 to 0 in the first half of the animation
    // then from 0 back to 1 in the second half.
    const Curve curve = Interval(0.5, 1.0, curve: Curves.ease);
    return _AnimationSwap<double>(
      ReverseAnimation(parent.drive(CurveTween(curve: curve.flipped))),
      parent.drive(CurveTween(curve: curve)),
      parent,
      0.5,
    );
  }

  // Because we only see the last half of the rotation tween,
  // it needs to go twice as far.
  static final Animatable<double> _rotationTween = Tween<double>(
    begin: 1.0 - kFloatingActionButtonTurnInterval * 2.0,
    end: 1.0,
  );

  static final Animatable<double> _thresholdCenterTween = CurveTween(curve: const Threshold(0.5));

  @override
  Animation<double> getRotationAnimation({ required Animation<double> parent }) {
    // This rotation will turn on the way in, but not on the way out.
    return _AnimationSwap<double>(
      parent.drive(_rotationTween),
      ReverseAnimation(parent.drive(_thresholdCenterTween)),
      parent,
      0.5,
    );
  }

  // If the animation was just starting, we'll continue from where we left off.
  // If the animation was finishing, we'll treat it as if we were starting at that point in reverse.
  // This avoids a size jump during the animation.
  @override
  double getAnimationRestart(double previousValue) => math.min(1.0 - previousValue, previousValue);
}

class _AnimationSwap<T> extends CompoundAnimation<T> {
  _AnimationSwap(Animation<T> first, Animation<T> next, this.parent, this.swapThreshold) : super(first: first, next: next);

  final Animation<double> parent;
  final double swapThreshold;

  @override
  T get value => parent.value < swapThreshold ? first.value : next.value;
}