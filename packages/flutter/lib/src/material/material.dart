import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'constants.dart';
import 'elevation_overlay.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

typedef RectCallback = Rect Function();

enum MaterialType {
  canvas,

  card,

  circle,

  button,

  transparency
}

const Map<MaterialType, BorderRadius?> kMaterialEdges = <MaterialType, BorderRadius?>{
  MaterialType.canvas: null,
  MaterialType.card: BorderRadius.all(Radius.circular(2.0)),
  MaterialType.circle: null,
  MaterialType.button: BorderRadius.all(Radius.circular(2.0)),
  MaterialType.transparency: null,
};

abstract class MaterialInkController {
  Color? get color;

  TickerProvider get vsync;

  void addInkFeature(InkFeature feature);

  void markNeedsPaint();
}

class Material extends StatefulWidget {
  const Material({
    super.key,
    this.type = MaterialType.canvas,
    this.elevation = 0.0,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.textStyle,
    this.borderRadius,
    this.shape,
    this.borderOnForeground = true,
    this.clipBehavior = Clip.none,
    this.animationDuration = kThemeChangeDuration,
    this.child,
  }) : assert(elevation >= 0.0),
       assert(!(shape != null && borderRadius != null)),
       assert(!(identical(type, MaterialType.circle) && (borderRadius != null || shape != null)));

  final Widget? child;

  final MaterialType type;

  final double elevation;

  final Color? color;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final TextStyle? textStyle;

  final ShapeBorder? shape;

  final bool borderOnForeground;

  final Clip clipBehavior;

  final Duration animationDuration;

  final BorderRadiusGeometry? borderRadius;

  static MaterialInkController? maybeOf(BuildContext context) {
    return LookupBoundary.findAncestorRenderObjectOfType<_RenderInkFeatures>(context);
  }

  static MaterialInkController of(BuildContext context) {
    final MaterialInkController? controller = maybeOf(context);
    assert(() {
      if (controller == null) {
        if (LookupBoundary.debugIsHidingAncestorRenderObjectOfType<_RenderInkFeatures>(context)) {
          throw FlutterError(
            'Material.of() was called with a context that does not have access to a Material widget.\n'
            'The context provided to Material.of() does have a Material widget ancestor, but it is '
            'hidden by a LookupBoundary. This can happen because you are using a widget that looks '
            'for a Material ancestor, but no such ancestor exists within the closest LookupBoundary.\n'
            'The context used was:\n'
            '  $context',
          );
        }
        throw FlutterError(
          'Material.of() was called with a context that does not contain a Material widget.\n'
          'No Material widget ancestor could be found starting from the context that was passed to '
          'Material.of(). This can happen because you are using a widget that looks for a Material '
          'ancestor, but no such ancestor exists.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return controller!;
  }

  @override
  State<Material> createState() => _MaterialState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<MaterialType>('type', type));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: 0.0));
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    textStyle?.debugFillProperties(properties, prefix: 'textStyle.');
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('borderOnForeground', borderOnForeground, defaultValue: true));
    properties.add(DiagnosticsProperty<BorderRadiusGeometry>('borderRadius', borderRadius, defaultValue: null));
  }

  static const double defaultSplashRadius = 35.0;
}

class _MaterialState extends State<Material> with TickerProviderStateMixin {
  final GlobalKey _inkFeatureRenderer = GlobalKey(debugLabel: 'ink renderer');

  Color? _getBackgroundColor(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Color? color = widget.color;
    if (color == null) {
      switch (widget.type) {
        case MaterialType.canvas:
          color = theme.canvasColor;
        case MaterialType.card:
          color = theme.cardColor;
        case MaterialType.button:
        case MaterialType.circle:
        case MaterialType.transparency:
          break;
      }
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? backgroundColor = _getBackgroundColor(context);
    final Color modelShadowColor = widget.shadowColor ?? (theme.useMaterial3 ? theme.colorScheme.shadow : theme.shadowColor);
    // If no shadow color is specified, use 0 for elevation in the model so a drop shadow won't be painted.
    final double modelElevation = widget.elevation;
    assert(
      backgroundColor != null || widget.type == MaterialType.transparency,
      'If Material type is not MaterialType.transparency, a color must '
      'either be passed in through the `color` property, or be defined '
      'in the theme (ex. canvasColor != null if type is set to '
      'MaterialType.canvas)',
    );
    Widget? contents = widget.child;
    if (contents != null) {
      contents = AnimatedDefaultTextStyle(
        style: widget.textStyle ?? Theme.of(context).textTheme.bodyMedium!,
        duration: widget.animationDuration,
        child: contents,
      );
    }
    contents = NotificationListener<LayoutChangedNotification>(
      onNotification: (LayoutChangedNotification notification) {
        final _RenderInkFeatures renderer = _inkFeatureRenderer.currentContext!.findRenderObject()! as _RenderInkFeatures;
        renderer._didChangeLayout();
        return false;
      },
      child: _InkFeatures(
        key: _inkFeatureRenderer,
        absorbHitTest: widget.type != MaterialType.transparency,
        color: backgroundColor,
        vsync: this,
        child: contents,
      ),
    );

    // PhysicalModel has a temporary workaround for a performance issue that
    // speeds up rectangular non transparent material (the workaround is to
    // skip the call to ui.Canvas.saveLayer if the border radius is 0).
    // Until the saveLayer performance issue is resolved, we're keeping this
    // special case here for canvas material type that is using the default
    // shape (rectangle). We could go down this fast path for explicitly
    // specified rectangles (e.g shape RoundedRectangleBorder with radius 0, but
    // we choose not to as we want the change from the fast-path to the
    // slow-path to be noticeable in the construction site of Material.
    if (widget.type == MaterialType.canvas && widget.shape == null && widget.borderRadius == null) {
      final Color color = Theme.of(context).useMaterial3
        ? ElevationOverlay.applySurfaceTint(backgroundColor!, widget.surfaceTintColor, widget.elevation)
        : ElevationOverlay.applyOverlay(context, backgroundColor!, widget.elevation);

      return AnimatedPhysicalModel(
        curve: Curves.fastOutSlowIn,
        duration: widget.animationDuration,
        shape: BoxShape.rectangle,
        clipBehavior: widget.clipBehavior,
        elevation: modelElevation,
        color: color,
        shadowColor: modelShadowColor,
        animateColor: false,
        child: contents,
      );
    }

    final ShapeBorder shape = _getShape();

    if (widget.type == MaterialType.transparency) {
      return _transparentInterior(
        context: context,
        shape: shape,
        clipBehavior: widget.clipBehavior,
        contents: contents,
      );
    }

    return _MaterialInterior(
      curve: Curves.fastOutSlowIn,
      duration: widget.animationDuration,
      shape: shape,
      borderOnForeground: widget.borderOnForeground,
      clipBehavior: widget.clipBehavior,
      elevation: widget.elevation,
      color: backgroundColor!,
      shadowColor: modelShadowColor,
      surfaceTintColor: widget.surfaceTintColor,
      child: contents,
    );
  }

  static Widget _transparentInterior({
    required BuildContext context,
    required ShapeBorder shape,
    required Clip clipBehavior,
    required Widget contents,
  }) {
    final _ShapeBorderPaint child = _ShapeBorderPaint(
      shape: shape,
      child: contents,
    );
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: shape,
        textDirection: Directionality.maybeOf(context),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }

  // Determines the shape for this Material.
  //
  // If a shape was specified, it will determine the shape.
  // If a borderRadius was specified, the shape is a rounded
  // rectangle.
  // Otherwise, the shape is determined by the widget type as described in the
  // Material class documentation.
  ShapeBorder _getShape() {
    if (widget.shape != null) {
      return widget.shape!;
    }
    if (widget.borderRadius != null) {
      return RoundedRectangleBorder(borderRadius: widget.borderRadius!);
    }
    switch (widget.type) {
      case MaterialType.canvas:
      case MaterialType.transparency:
        return const RoundedRectangleBorder();

      case MaterialType.card:
      case MaterialType.button:
        return RoundedRectangleBorder(
          borderRadius: widget.borderRadius ?? kMaterialEdges[widget.type]!,
        );

      case MaterialType.circle:
        return const CircleBorder();
    }
  }
}

class _RenderInkFeatures extends RenderProxyBox implements MaterialInkController {
  _RenderInkFeatures({
    RenderBox? child,
    required this.vsync,
    required this.absorbHitTest,
    this.color,
  }) : super(child);

  // This class should exist in a 1:1 relationship with a MaterialState object,
  // since there's no current support for dynamically changing the ticker
  // provider.
  @override
  final TickerProvider vsync;

  // This is here to satisfy the MaterialInkController contract.
  // The actual painting of this color is done by a Container in the
  // MaterialState build method.
  @override
  Color? color;

  bool absorbHitTest;

  @visibleForTesting
  List<InkFeature>? get debugInkFeatures {
    if (kDebugMode) {
      return _inkFeatures;
    }
    return null;
  }
  List<InkFeature>? _inkFeatures;

  @override
  void addInkFeature(InkFeature feature) {
    assert(!feature._debugDisposed);
    assert(feature._controller == this);
    _inkFeatures ??= <InkFeature>[];
    assert(!_inkFeatures!.contains(feature));
    _inkFeatures!.add(feature);
    markNeedsPaint();
  }

  void _removeFeature(InkFeature feature) {
    assert(_inkFeatures != null);
    _inkFeatures!.remove(feature);
    markNeedsPaint();
  }

  void _didChangeLayout() {
    if (_inkFeatures?.isNotEmpty ?? false) {
      markNeedsPaint();
    }
  }

  @override
  bool hitTestSelf(Offset position) => absorbHitTest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final List<InkFeature>? inkFeatures = _inkFeatures;
    if (inkFeatures != null && inkFeatures.isNotEmpty) {
      final Canvas canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.clipRect(Offset.zero & size);
      for (final InkFeature inkFeature in inkFeatures) {
        inkFeature._paint(canvas);
      }
      canvas.restore();
    }
    assert(inkFeatures == _inkFeatures);
    super.paint(context, offset);
  }
}

class _InkFeatures extends SingleChildRenderObjectWidget {
  const _InkFeatures({
    super.key,
    this.color,
    required this.vsync,
    required this.absorbHitTest,
    super.child,
  });

  // This widget must be owned by a MaterialState, which must be provided as the vsync.
  // This relationship must be 1:1 and cannot change for the lifetime of the MaterialState.

  final Color? color;

  final TickerProvider vsync;

  final bool absorbHitTest;

  @override
  _RenderInkFeatures createRenderObject(BuildContext context) {
    return _RenderInkFeatures(
      color: color,
      absorbHitTest: absorbHitTest,
      vsync: vsync,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderInkFeatures renderObject) {
    renderObject..color = color
                ..absorbHitTest = absorbHitTest;
    assert(vsync == renderObject.vsync);
  }
}

abstract class InkFeature {
  InkFeature({
    required MaterialInkController controller,
    required this.referenceBox,
    this.onRemoved,
  }) : _controller = controller as _RenderInkFeatures;

  MaterialInkController get controller => _controller;
  final _RenderInkFeatures _controller;

  final RenderBox referenceBox;

  final VoidCallback? onRemoved;

  bool _debugDisposed = false;

  @mustCallSuper
  void dispose() {
    assert(!_debugDisposed);
    assert(() {
      _debugDisposed = true;
      return true;
    }());
    _controller._removeFeature(this);
    onRemoved?.call();
  }

  // Returns the paint transform that allows `fromRenderObject` to perform paint
  // in `toRenderObject`'s coordinate space.
  //
  // Returns null if either `fromRenderObject` or `toRenderObject` is not in the
  // same render tree, or either of them is in an offscreen subtree (see
  // RenderObject.paintsChild).
  static Matrix4? _getPaintTransform(
    RenderObject fromRenderObject,
    RenderObject toRenderObject,
  ) {
    // The paths to fromRenderObject and toRenderObject's common ancestor.
    final List<RenderObject> fromPath = <RenderObject>[fromRenderObject];
    final List<RenderObject> toPath = <RenderObject>[toRenderObject];

    RenderObject from = fromRenderObject;
    RenderObject to = toRenderObject;

    while (!identical(from, to)) {
      final int fromDepth = from.depth;
      final int toDepth = to.depth;

      if (fromDepth >= toDepth) {
        final RenderObject? fromParent = from.parent;
        // Return early if the 2 render objects are not in the same render tree,
        // or either of them is offscreen and thus won't get painted.
        if (fromParent is! RenderObject || !fromParent.paintsChild(from)) {
          return null;
        }
        fromPath.add(fromParent);
        from = fromParent;
      }

      if (fromDepth <= toDepth) {
        final RenderObject? toParent = to.parent;
        if (toParent is! RenderObject || !toParent.paintsChild(to)) {
          return null;
        }
        toPath.add(toParent);
        to = toParent;
      }
    }
    assert(identical(from, to));

    final Matrix4 transform = Matrix4.identity();
    final Matrix4 inverseTransform = Matrix4.identity();

    for (int index = toPath.length - 1; index > 0; index -= 1) {
      toPath[index].applyPaintTransform(toPath[index - 1], transform);
    }
    for (int index = fromPath.length - 1; index > 0; index -= 1) {
      fromPath[index].applyPaintTransform(fromPath[index - 1], inverseTransform);
    }

    final double det = inverseTransform.invert();
    return det != 0 ? (inverseTransform..multiply(transform)) : null;
  }

  void _paint(Canvas canvas) {
    assert(referenceBox.attached);
    assert(!_debugDisposed);
    // determine the transform that gets our coordinate system to be like theirs
    final Matrix4? transform = _getPaintTransform(_controller, referenceBox);
    if (transform != null) {
      paintFeature(canvas, transform);
    }
  }

  @protected
  void paintFeature(Canvas canvas, Matrix4 transform);

  @override
  String toString() => describeIdentity(this);
}

class ShapeBorderTween extends Tween<ShapeBorder?> {
  ShapeBorderTween({super.begin, super.end});

  @override
  ShapeBorder? lerp(double t) {
    return ShapeBorder.lerp(begin, end, t);
  }
}

class _MaterialInterior extends ImplicitlyAnimatedWidget {
  const _MaterialInterior({
    required this.child,
    required this.shape,
    this.borderOnForeground = true,
    this.clipBehavior = Clip.none,
    required this.elevation,
    required this.color,
    required this.shadowColor,
    required this.surfaceTintColor,
    super.curve,
    required super.duration,
  }) : assert(elevation >= 0.0);

  final Widget child;

  final ShapeBorder shape;

  final bool borderOnForeground;

  final Clip clipBehavior;

  final double elevation;

  final Color color;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  @override
  _MaterialInteriorState createState() => _MaterialInteriorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<ShapeBorder>('shape', shape));
    description.add(DoubleProperty('elevation', elevation));
    description.add(ColorProperty('color', color));
    description.add(ColorProperty('shadowColor', shadowColor));
  }
}

class _MaterialInteriorState extends AnimatedWidgetBaseState<_MaterialInterior> {
  Tween<double>? _elevation;
  ColorTween? _surfaceTintColor;
  ColorTween? _shadowColor;
  ShapeBorderTween? _border;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _elevation = visitor(
      _elevation,
      widget.elevation,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
    _shadowColor =  widget.shadowColor != null
      ? visitor(
          _shadowColor,
          widget.shadowColor,
          (dynamic value) => ColorTween(begin: value as Color),
        ) as ColorTween?
      : null;
    _surfaceTintColor = widget.surfaceTintColor != null
      ? visitor(
          _surfaceTintColor,
          widget.surfaceTintColor,
              (dynamic value) => ColorTween(begin: value as Color),
        ) as ColorTween?
      : null;
    _border = visitor(
      _border,
      widget.shape,
      (dynamic value) => ShapeBorderTween(begin: value as ShapeBorder),
    ) as ShapeBorderTween?;
  }

  @override
  Widget build(BuildContext context) {
    final ShapeBorder shape = _border!.evaluate(animation)!;
    final double elevation = _elevation!.evaluate(animation);
    final Color color = Theme.of(context).useMaterial3
      ? ElevationOverlay.applySurfaceTint(widget.color, _surfaceTintColor?.evaluate(animation), elevation)
      : ElevationOverlay.applyOverlay(context, widget.color, elevation);
    // If no shadow color is specified, use 0 for elevation in the model so a drop shadow won't be painted.
    final double modelElevation = widget.shadowColor != null ? elevation : 0;
    final Color shadowColor = _shadowColor?.evaluate(animation) ?? const Color(0x00000000);
    return PhysicalShape(
      clipper: ShapeBorderClipper(
        shape: shape,
        textDirection: Directionality.maybeOf(context),
      ),
      clipBehavior: widget.clipBehavior,
      elevation: modelElevation,
      color: color,
      shadowColor: shadowColor,
      child: _ShapeBorderPaint(
        shape: shape,
        borderOnForeground: widget.borderOnForeground,
        child: widget.child,
      ),
    );
  }
}

class _ShapeBorderPaint extends StatelessWidget {
  const _ShapeBorderPaint({
    required this.child,
    required this.shape,
    this.borderOnForeground = true,
  });

  final Widget child;
  final ShapeBorder shape;
  final bool borderOnForeground;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: borderOnForeground ? null : _ShapeBorderPainter(shape, Directionality.maybeOf(context)),
      foregroundPainter: borderOnForeground ? _ShapeBorderPainter(shape, Directionality.maybeOf(context)) : null,
      child: child,
    );
  }
}

class _ShapeBorderPainter extends CustomPainter {
  _ShapeBorderPainter(this.border, this.textDirection);
  final ShapeBorder border;
  final TextDirection? textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    border.paint(canvas, Offset.zero & size, textDirection: textDirection);
  }

  @override
  bool shouldRepaint(_ShapeBorderPainter oldDelegate) {
    return oldDelegate.border != border;
  }
}