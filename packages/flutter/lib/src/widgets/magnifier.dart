import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'container.dart';
import 'framework.dart';
import 'inherited_theme.dart';
import 'navigator.dart';
import 'overlay.dart';

typedef MagnifierBuilder = Widget? Function(
    BuildContext context,
    MagnifierController controller,
    ValueNotifier<MagnifierInfo> magnifierInfo,
);

@immutable
class MagnifierInfo {
  const MagnifierInfo({
    required this.globalGesturePosition,
    required this.caretRect,
    required this.fieldBounds,
    required this.currentLineBoundaries,
  });

  static const MagnifierInfo empty = MagnifierInfo(
    globalGesturePosition: Offset.zero,
    caretRect: Rect.zero,
    currentLineBoundaries: Rect.zero,
    fieldBounds: Rect.zero,
  );

  final Offset globalGesturePosition;

  final Rect currentLineBoundaries;

  final Rect caretRect;

  final Rect fieldBounds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MagnifierInfo
        && other.globalGesturePosition == globalGesturePosition
        && other.caretRect == caretRect
        && other.currentLineBoundaries == currentLineBoundaries
        && other.fieldBounds == fieldBounds;
  }

  @override
  int get hashCode => Object.hash(
    globalGesturePosition,
    caretRect,
    fieldBounds,
    currentLineBoundaries,
  );
}

class TextMagnifierConfiguration {
  const TextMagnifierConfiguration({
    MagnifierBuilder? magnifierBuilder,
    this.shouldDisplayHandlesInMagnifier = true
  }) : _magnifierBuilder = magnifierBuilder;

  final MagnifierBuilder? _magnifierBuilder;

  MagnifierBuilder get magnifierBuilder => _magnifierBuilder ?? (_, __, ___) => null;

  final bool shouldDisplayHandlesInMagnifier;

  static const TextMagnifierConfiguration disabled = TextMagnifierConfiguration();
}

// TODO(antholeole): This whole paradigm can be removed once portals
// lands - then the magnifier can be controlled though a widget in the tree.
// https://github.com/flutter/flutter/pull/105335
class MagnifierController {
  MagnifierController({this.animationController}) {
    animationController?.value = 0;
  }

  AnimationController? animationController;

  OverlayEntry? get overlayEntry => _overlayEntry;
  OverlayEntry? _overlayEntry;

  bool get shown {
    if (overlayEntry == null) {
      return false;
    }

    if (animationController != null) {
      return animationController!.status == AnimationStatus.completed ||
          animationController!.status == AnimationStatus.forward;
    }

    return true;
  }

  Future<void> show({
    required BuildContext context,
    required WidgetBuilder builder,
    Widget? debugRequiredFor,
    OverlayEntry? below,
  }) async {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();

    final OverlayState overlayState = Overlay.of(
      context,
      rootOverlay: true,
      debugRequiredFor: debugRequiredFor,
    );

    final CapturedThemes capturedThemes = InheritedTheme.capture(
      from: context,
      to: Navigator.maybeOf(context)?.context,
    );

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => capturedThemes.wrap(builder(context)),
    );
    overlayState.insert(overlayEntry!, below: below);

    if (animationController != null) {
      await animationController?.forward();
    }
  }

  Future<void> hide({bool removeFromOverlay = true}) async {
    if (overlayEntry == null) {
      return;
    }

    if (animationController != null) {
      await animationController?.reverse();
    }

    if (removeFromOverlay) {
      this.removeFromOverlay();
    }
  }

  @visibleForTesting
  void removeFromOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  static Rect shiftWithinBounds({
    required Rect rect,
    required Rect bounds,
  }) {
    assert(rect.width <= bounds.width,
        'attempted to shift $rect within $bounds, but the rect has a greater width.');
    assert(rect.height <= bounds.height,
        'attempted to shift $rect within $bounds, but the rect has a greater height.');

    Offset rectShift = Offset.zero;
    if (rect.left < bounds.left) {
      rectShift += Offset(bounds.left - rect.left, 0);
    } else if (rect.right > bounds.right) {
      rectShift += Offset(bounds.right - rect.right, 0);
    }

    if (rect.top < bounds.top) {
      rectShift += Offset(0, bounds.top - rect.top);
    } else if (rect.bottom > bounds.bottom) {
      rectShift += Offset(0, bounds.bottom - rect.bottom);
    }

    return rect.shift(rectShift);
  }
}

class MagnifierDecoration extends ShapeDecoration {
  const MagnifierDecoration({
    this.opacity = 1,
    super.shadows,
    super.shape = const RoundedRectangleBorder(),
  });

  final double opacity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return super == other && other is MagnifierDecoration && other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, opacity);
}

class RawMagnifier extends StatelessWidget {
  const RawMagnifier({
      super.key,
      this.child,
      this.decoration = const MagnifierDecoration(),
      this.focalPointOffset = Offset.zero,
      this.magnificationScale = 1,
      required this.size,
      }) : assert(magnificationScale != 0,
            'Magnification scale of 0 results in undefined behavior.');

  final Widget? child;

  final MagnifierDecoration decoration;


  final Offset focalPointOffset;

  final double magnificationScale;

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        ClipPath.shape(
          shape: decoration.shape,
          child: Opacity(
            opacity: decoration.opacity,
            child: _Magnifier(
              shape: decoration.shape,
              focalPointOffset: focalPointOffset,
              magnificationScale: magnificationScale,
              child: SizedBox.fromSize(
                size: size,
                child: child,
              ),
            ),
          ),
        ),
        // Because `BackdropFilter` will filter any widgets before it, we should
        // apply the style after (i.e. in a younger sibling) to avoid the magnifier
        // from seeing its own styling.
        Opacity(
          opacity: decoration.opacity,
          child: _MagnifierStyle(
            decoration,
            size: size,
          ),
        )
      ],
    );
  }
}

class _MagnifierStyle extends StatelessWidget {
  const _MagnifierStyle(this.decoration, {required this.size});

  final MagnifierDecoration decoration;
  final Size size;

  @override
  Widget build(BuildContext context) {
    double largestShadow = 0;
    for (final BoxShadow shadow in decoration.shadows ?? <BoxShadow>[]) {
      largestShadow = math.max(
          largestShadow,
          (shadow.blurRadius + shadow.spreadRadius) +
              math.max(shadow.offset.dy.abs(), shadow.offset.dx.abs()));
    }

    return ClipPath(
      clipBehavior: Clip.hardEdge,
      clipper: _DonutClip(
        shape: decoration.shape,
        spreadRadius: largestShadow,
      ),
      child: DecoratedBox(
        decoration: decoration,
        child: SizedBox.fromSize(
          size: size,
        ),
      ),
    );
  }
}

class _DonutClip extends CustomClipper<Path> {
  _DonutClip({required this.shape, required this.spreadRadius});

  final double spreadRadius;
  final ShapeBorder shape;

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final Rect rect = Offset.zero & size;

    path.fillType = PathFillType.evenOdd;
    path.addPath(shape.getOuterPath(rect.inflate(spreadRadius)), Offset.zero);
    path.addPath(shape.getInnerPath(rect), Offset.zero);
    return path;
  }

  @override
  bool shouldReclip(_DonutClip oldClipper) => oldClipper.shape != shape;
}

class _Magnifier extends SingleChildRenderObjectWidget {
  const _Magnifier({
    super.child,
    required this.shape,
    this.magnificationScale = 1,
    this.focalPointOffset = Offset.zero,
  });

  // The Offset that the center of the _Magnifier points to, relative
  // to the center of the magnifier.
  final Offset focalPointOffset;

  // The enlarge multiplier of the magnification.
  //
  // If equal to 1.0, the content in the magnifier is true to its real size.
  // If greater than 1.0, the content appears bigger in the magnifier.
  final double magnificationScale;

  // Shape of the magnifier.
  final ShapeBorder shape;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMagnification(focalPointOffset, magnificationScale, shape);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderMagnification renderObject) {
    renderObject
      ..focalPointOffset = focalPointOffset
      ..shape = shape
      ..magnificationScale = magnificationScale;
  }
}

class _RenderMagnification extends RenderProxyBox {
  _RenderMagnification(
    this._focalPointOffset,
    this._magnificationScale,
    this._shape, {
    RenderBox? child,
  }) : super(child);

  Offset get focalPointOffset => _focalPointOffset;
  Offset _focalPointOffset;
  set focalPointOffset(Offset value) {
    if (_focalPointOffset == value) {
      return;
    }
    _focalPointOffset = value;
    markNeedsPaint();
  }

  double get magnificationScale => _magnificationScale;
  double _magnificationScale;
  set magnificationScale(double value) {
    if (_magnificationScale == value) {
      return;
    }
    _magnificationScale = value;
    markNeedsPaint();
  }

  ShapeBorder get shape => _shape;
  ShapeBorder _shape;
  set shape(ShapeBorder value) {
    if (_shape == value) {
      return;
    }
    _shape = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    final Offset thisCenter = Alignment.center.alongSize(size) + offset;
    final Matrix4 matrix = Matrix4.identity()
      ..translate(
          magnificationScale * ((focalPointOffset.dx * -1) - thisCenter.dx) + thisCenter.dx,
          magnificationScale * ((focalPointOffset.dy * -1) - thisCenter.dy) + thisCenter.dy)
      ..scale(magnificationScale);
    final ImageFilter filter = ImageFilter.matrix(matrix.storage, filterQuality: FilterQuality.high);

    if (layer == null) {
      layer = BackdropFilterLayer(
        filter: filter,
      );
    } else {
      layer!.filter = filter;
    }

    context.pushLayer(layer!, super.paint, offset);
  }
}