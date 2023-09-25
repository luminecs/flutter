
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState;

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'media_query.dart';

class DisplayFeatureSubScreen extends StatelessWidget {
  const DisplayFeatureSubScreen({
    super.key,
    this.anchorPoint,
    required this.child,
  });

  final Offset? anchorPoint;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(anchorPoint != null || debugCheckHasDirectionality(
        context,
        why: 'to determine which sub-screen DisplayFeatureSubScreen uses',
        alternative: "Alternatively, consider specifying the 'anchorPoint' argument on the DisplayFeatureSubScreen.",
    ));
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size parentSize = mediaQuery.size;
    final Rect wantedBounds = Offset.zero & parentSize;
    final Offset resolvedAnchorPoint = _capOffset(anchorPoint ?? _fallbackAnchorPoint(context), parentSize);
    final Iterable<Rect> subScreens = subScreensInBounds(wantedBounds, avoidBounds(mediaQuery));
    final Rect closestSubScreen = _closestToAnchorPoint(subScreens, resolvedAnchorPoint);

    return Padding(
      padding: EdgeInsets.only(
        left: closestSubScreen.left,
        top: closestSubScreen.top,
        right: parentSize.width - closestSubScreen.right,
        bottom: parentSize.height - closestSubScreen.bottom,
      ),
      child: MediaQuery(
        data: mediaQuery.removeDisplayFeatures(closestSubScreen),
        child: child,
      ),
    );
  }

  static Offset _fallbackAnchorPoint(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    switch (textDirection) {
      case TextDirection.rtl:
        return const Offset(double.maxFinite, 0);
      case TextDirection.ltr:
        return Offset.zero;
    }
  }

  static Iterable<Rect> avoidBounds(MediaQueryData mediaQuery) {
    return mediaQuery.displayFeatures
        .where((DisplayFeature d) => d.bounds.shortestSide > 0 ||
            d.state == DisplayFeatureState.postureHalfOpened)
        .map((DisplayFeature d) => d.bounds);
  }

  static Rect _closestToAnchorPoint(Iterable<Rect> subScreens, Offset anchorPoint) {
    Rect closestScreen = subScreens.first;
    double closestDistance = _distanceFromPointToRect(anchorPoint, closestScreen);
    for (final Rect screen in subScreens) {
      final double subScreenDistance = _distanceFromPointToRect(anchorPoint, screen);
      if (subScreenDistance < closestDistance) {
        closestScreen = screen;
        closestDistance = subScreenDistance;
      }
    }
    return closestScreen;
  }

  static double _distanceFromPointToRect(Offset point, Rect rect) {
    // Cases for point position relative to rect:
    // 1  2  3
    // 4 [R] 5
    // 6  7  8
    if (point.dx < rect.left) {
      if (point.dy < rect.top) {
        // Case 1
        return (point - rect.topLeft).distance;
      } else if (point.dy > rect.bottom) {
        // Case 6
        return (point - rect.bottomLeft).distance;
      } else {
        // Case 4
        return rect.left - point.dx;
      }
    } else if (point.dx > rect.right) {
      if (point.dy < rect.top) {
        // Case 3
        return (point - rect.topRight).distance;
      } else if (point.dy > rect.bottom) {
        // Case 8
        return (point - rect.bottomRight).distance;
      } else {
        // Case 5
        return point.dx - rect.right;
      }
    } else {
      if (point.dy < rect.top) {
        // Case 2
        return rect.top - point.dy;
      } else if (point.dy > rect.bottom) {
        // Case 7
        return point.dy - rect.bottom;
      } else {
        // Case R
        return 0;
      }
    }
  }

  static Iterable<Rect> subScreensInBounds(Rect wantedBounds, Iterable<Rect> avoidBounds) {
    Iterable<Rect> subScreens = <Rect>[wantedBounds];
    for (final Rect bounds in avoidBounds) {
      final List<Rect> newSubScreens = <Rect>[];
      for (final Rect screen in subScreens) {
        if (screen.top >= bounds.top && screen.bottom <= bounds.bottom) {
          // Display feature splits the screen vertically
          if (screen.left < bounds.left) {
            // There is a smaller sub-screen, left of the display feature
            newSubScreens.add(Rect.fromLTWH(
              screen.left,
              screen.top,
              bounds.left - screen.left,
              screen.height,
            ));
          }
          if (screen.right > bounds.right) {
            // There is a smaller sub-screen, right of the display feature
            newSubScreens.add(Rect.fromLTWH(
              bounds.right,
              screen.top,
              screen.right - bounds.right,
              screen.height,
            ));
          }
        } else if (screen.left >= bounds.left && screen.right <= bounds.right) {
          // Display feature splits the sub-screen horizontally
          if (screen.top < bounds.top) {
            // There is a smaller sub-screen, above the display feature
            newSubScreens.add(Rect.fromLTWH(
              screen.left,
              screen.top,
              screen.width,
              bounds.top - screen.top,
            ));
          }
          if (screen.bottom > bounds.bottom) {
            // There is a smaller sub-screen, below the display feature
            newSubScreens.add(Rect.fromLTWH(
              screen.left,
              bounds.bottom,
              screen.width,
              screen.bottom - bounds.bottom,
            ));
          }
        } else {
          newSubScreens.add(screen);
        }
      }
      subScreens = newSubScreens;
    }
    return subScreens;
  }

  static Offset _capOffset(Offset offset, Size maximum) {
    if (offset.dx >= 0 && offset.dx <= maximum.width
        && offset.dy >=0 && offset.dy <= maximum.height) {
      return offset;
    } else {
      return Offset(
        math.min(math.max(0, offset.dx), maximum.width),
        math.min(math.max(0, offset.dy), maximum.height),
      );
    }
  }
}